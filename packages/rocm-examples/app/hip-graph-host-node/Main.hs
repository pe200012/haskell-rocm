{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Control.Concurrent.MVar (newEmptyMVar, putMVar, takeMVar)
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
  , hipGraphAddHostNode
  , hipGraphAddMemcpyNode1D
  , hipGraphAddMemsetNode
  , hipGraphCreate
  , hipGraphDestroy
  , hipGraphExecDestroy
  , hipGraphExecHostNodeSetParams
  , hipGraphHostNodeGetParams
  , hipGraphHostNodeSetParams
  , hipGraphInstantiate
  , hipGraphLaunch
  , hipMallocBytes
  , hipStreamCreate
  , hipStreamDestroy
  , hipStreamSynchronize
  , withHipHostNodeCallback
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
  callbackMv <- newEmptyMVar
  bracket (mallocArray bytesCount :: IO (Ptr Word8)) free $ \hOut ->
    bracket (hipMallocBytes bytes :: IO (DevicePtr Word8)) hipFree $ \dBuf ->
      bracket hipStreamCreate hipStreamDestroy $ \stream ->
        withHipHostNodeCallback (putMVar callbackMv (1 :: Int)) $ \params1 ->
          withHipHostNodeCallback (putMVar callbackMv (2 :: Int)) $ \params2 ->
            withHipHostNodeCallback (putMVar callbackMv (3 :: Int)) $ \params3 ->
              bracket (hipGraphCreate 0) hipGraphDestroy $ \graph -> do
                let DevicePtr pBuf = dBuf
                    memsetParams = paramsFor (castPtr pBuf) (0x33 :: Word8)
                memsetNode <- hipGraphAddMemsetNode graph [] memsetParams
                hostNode <- hipGraphAddHostNode graph [memsetNode] params1
                gotParams <- hipGraphHostNodeGetParams hostNode
                if gotParams /= params1
                  then error ("hip graph host node get-params mismatch: got=" <> show gotParams)
                  else pure ()
                hipGraphHostNodeSetParams hostNode params2
                _ <- hipGraphAddMemcpyNode1D graph [hostNode] (castPtr hOut) (castPtr pBuf) bytes HipMemcpyDeviceToHost
                execGraph <- hipGraphInstantiate graph
                bracket_ (pure ()) (hipGraphExecDestroy execGraph) $ do
                  hipGraphExecHostNodeSetParams execGraph hostNode params3
                  hipGraphLaunch execGraph stream
                  hipStreamSynchronize stream
                  callbackResult <- takeMVar callbackMv
                  output <- peekArray bytesCount hOut
                  if callbackResult /= 3
                    then error ("hip graph host node callback mismatch: expected 3, got=" <> show callbackResult)
                    else
                      if output == replicate bytesCount 0x33
                        then putStrLn "hip graph host node: OK"
                        else error ("hip graph host node data mismatch: expected all 0x33, got=" <> show output)
