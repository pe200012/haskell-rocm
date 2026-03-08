{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Control.Exception (bracket, bracket_)
import Data.Word (Word8)
import Foreign.C.Types (CSize)
import Foreign.Marshal.Alloc (free)
import Foreign.Marshal.Array (mallocArray, peekArray)
import Foreign.Ptr (Ptr, castPtr)
import ROCm.FFI.Core.Types (DevicePtr(..))
import ROCm.HIP
  ( HipMemsetParams(..)
  , hipFree
  , hipGraphAddMemcpyNode1D
  , hipGraphAddMemsetNode
  , hipGraphCreate
  , hipGraphDestroy
  , hipGraphExecDestroy
  , hipGraphExecMemsetNodeSetParams
  , hipGraphInstantiate
  , hipGraphLaunch
  , hipGraphMemsetNodeGetParams
  , hipGraphMemsetNodeSetParams
  , hipMallocBytes
  , hipStreamCreate
  , hipStreamDestroy
  , hipStreamSynchronize
  , pattern HipMemcpyDeviceToHost
  )

main :: IO ()
main = do
  let bytesCount = 32 :: Int
      bytes = fromIntegral bytesCount :: CSize
      paramsFor dst value =
        HipMemsetParams
          { hipMemsetDst = dst
          , hipMemsetElementSize = 1
          , hipMemsetHeight = 1
          , hipMemsetPitch = bytes
          , hipMemsetValue = fromIntegral value
          , hipMemsetWidth = bytes
          }
  bracket (mallocArray bytesCount :: IO (Ptr Word8)) free $ \hOut ->
    bracket (hipMallocBytes bytes :: IO (DevicePtr Word8)) hipFree $ \dBuf ->
      bracket hipStreamCreate hipStreamDestroy $ \stream ->
        bracket (hipGraphCreate 0) hipGraphDestroy $ \graph -> do
          let DevicePtr pBuf = dBuf
              params1 = paramsFor (castPtr pBuf) (0x11 :: Word8)
              params2 = paramsFor (castPtr pBuf) (0x22 :: Word8)
              params3 = paramsFor (castPtr pBuf) (0x33 :: Word8)
          memsetNode <- hipGraphAddMemsetNode graph [] params1
          gotParams <- hipGraphMemsetNodeGetParams memsetNode
          if gotParams /= params1
            then error ("hip graph memset node get-params mismatch: got=" <> show gotParams)
            else pure ()
          hipGraphMemsetNodeSetParams memsetNode params2
          _ <- hipGraphAddMemcpyNode1D graph [memsetNode] (castPtr hOut) (castPtr pBuf) bytes HipMemcpyDeviceToHost
          execGraph <- hipGraphInstantiate graph
          bracket_ (pure ()) (hipGraphExecDestroy execGraph) $ do
            hipGraphExecMemsetNodeSetParams execGraph memsetNode params3
            hipGraphLaunch execGraph stream
            hipStreamSynchronize stream
            output <- peekArray bytesCount hOut
            if output == replicate bytesCount 0x33
              then putStrLn "hip graph memset node: OK"
              else error ("hip graph memset node mismatch: expected all 0x33, got=" <> show output)
