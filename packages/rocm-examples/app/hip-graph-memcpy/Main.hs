{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Control.Exception (bracket, bracket_)
import Foreign.C.Types (CFloat(..), CSize)
import Foreign.Marshal.Alloc (free)
import Foreign.Marshal.Array (mallocArray, peekArray, pokeArray)
import Foreign.Ptr (castPtr)
import Foreign.Storable (sizeOf)
import ROCm.FFI.Core.Types (DevicePtr(..))
import ROCm.HIP
  ( hipFree
  , hipGraphAddMemcpyNode1D
  , hipGraphCreate
  , hipGraphDestroy
  , hipGraphExecDestroy
  , hipGraphInstantiate
  , hipGraphLaunch
  , hipMallocBytes
  , hipStreamCreate
  , hipStreamDestroy
  , hipStreamSynchronize
  , pattern HipMemcpyDeviceToHost
  , pattern HipMemcpyHostToDevice
  )

main :: IO ()
main = do
  let n = 64 :: Int
      input = fmap (CFloat . fromIntegral . (`mod` 11)) [0 .. n - 1]
      bytes = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
  bracket (mallocArray n) free $ \hIn ->
    bracket (mallocArray n) free $ \hOut -> do
      pokeArray hIn input
      bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dBuf ->
        bracket hipStreamCreate hipStreamDestroy $ \stream ->
          bracket (hipGraphCreate 0) hipGraphDestroy $ \graph -> do
            let DevicePtr pBuf = dBuf
            h2dNode <- hipGraphAddMemcpyNode1D graph [] (castPtr pBuf) (castPtr hIn) bytes HipMemcpyHostToDevice
            _ <- hipGraphAddMemcpyNode1D graph [h2dNode] (castPtr hOut) (castPtr pBuf) bytes HipMemcpyDeviceToHost
            execGraph <- hipGraphInstantiate graph
            bracket_ (pure ()) (hipGraphExecDestroy execGraph) $ do
              hipGraphLaunch execGraph stream
              hipStreamSynchronize stream
              output <- peekArray n hOut
              if output == input
                then putStrLn "hip graph memcpy: OK"
                else error ("hip graph memcpy mismatch: expected=" <> show input <> ", got=" <> show output)
