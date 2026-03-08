{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Control.Exception (bracket, bracket_)
import Data.Word (Word8)
import Foreign.C.Types (CSize)
import Foreign.Marshal.Alloc (free)
import Foreign.Marshal.Array (mallocArray, peekArray)
import Foreign.Ptr (Ptr, castPtr)
import System.Directory (createDirectoryIfMissing, doesFileExist, getTemporaryDirectory)
import System.FilePath ((</>))
import ROCm.FFI.Core.Types (DevicePtr(..))
import ROCm.HIP
  ( HipMemsetParams(..)
  , hipEventCreate
  , hipEventDestroy
  , hipEventRecord
  , hipEventSynchronize
  , hipFree
  , hipGraphAddChildGraphNode
  , hipGraphAddEventRecordNode
  , hipGraphAddEventWaitNode
  , hipGraphAddMemcpyNode1D
  , hipGraphAddMemsetNode
  , hipGraphChildGraphNodeGetGraph
  , hipGraphCreate
  , hipGraphDebugDotPrint
  , hipGraphDestroy
  , hipGraphEventRecordNodeGetEvent
  , hipGraphEventRecordNodeSetEvent
  , hipGraphEventWaitNodeGetEvent
  , hipGraphEventWaitNodeSetEvent
  , hipGraphExecDestroy
  , hipGraphExecEventRecordNodeSetEvent
  , hipGraphExecEventWaitNodeSetEvent
  , hipGraphInstantiate
  , hipGraphLaunch
  , hipMallocBytes
  , hipStreamCreate
  , hipStreamDestroy
  , hipStreamSynchronize
  , pattern HipGraphDebugDotFlagsVerbose
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
  tempDir <- getTemporaryDirectory
  let dotDir = tempDir </> "haskell-rocm-graph-dot"
      childDotPath = dotDir </> "hip_graph_child_graph_example.dot"
  createDirectoryIfMissing True dotDir
  bracket (mallocArray bytesCount :: IO (Ptr Word8)) free $ \hOut ->
    bracket (hipMallocBytes bytes :: IO (DevicePtr Word8)) hipFree $ \dBuf ->
      bracket hipStreamCreate hipStreamDestroy $ \stream ->
        bracket hipStreamCreate hipStreamDestroy $ \readyStream ->
          bracket hipEventCreate hipEventDestroy $ \readyEv1 ->
            bracket hipEventCreate hipEventDestroy $ \readyEv2 ->
              bracket hipEventCreate hipEventDestroy $ \doneEv1 ->
                bracket hipEventCreate hipEventDestroy $ \doneEv2 -> do
                  let DevicePtr pBuf = dBuf
                  bracket (hipGraphCreate 0) hipGraphDestroy $ \childGraph ->
                    bracket (hipGraphCreate 0) hipGraphDestroy $ \parentGraph -> do
                      _ <- hipGraphAddMemsetNode childGraph [] (paramsFor (castPtr pBuf) (0x5a :: Word8))
                      waitNode <- hipGraphAddEventWaitNode parentGraph [] readyEv1
                      waitEv0 <- hipGraphEventWaitNodeGetEvent waitNode
                      if waitEv0 /= readyEv1
                        then error "hipGraphEventWaitNodeGetEvent mismatch before set"
                        else pure ()
                      hipGraphEventWaitNodeSetEvent waitNode readyEv2
                      childNode <- hipGraphAddChildGraphNode parentGraph [waitNode] childGraph
                      embeddedGraph <- hipGraphChildGraphNodeGetGraph childNode
                      hipGraphDebugDotPrint embeddedGraph childDotPath HipGraphDebugDotFlagsVerbose
                      childDotExists <- doesFileExist childDotPath
                      if not childDotExists
                        then error "hipGraphChildGraphNodeGetGraph returned an unusable graph handle"
                        else pure ()
                      recordNode <- hipGraphAddEventRecordNode parentGraph [childNode] doneEv1
                      recordEv0 <- hipGraphEventRecordNodeGetEvent recordNode
                      if recordEv0 /= doneEv1
                        then error "hipGraphEventRecordNodeGetEvent mismatch before set"
                        else pure ()
                      hipGraphEventRecordNodeSetEvent recordNode doneEv2
                      _ <- hipGraphAddMemcpyNode1D parentGraph [recordNode] (castPtr hOut) (castPtr pBuf) bytes HipMemcpyDeviceToHost
                      execGraph <- hipGraphInstantiate parentGraph
                      bracket_ (pure ()) (hipGraphExecDestroy execGraph) $ do
                        hipGraphExecEventWaitNodeSetEvent execGraph waitNode readyEv2
                        hipGraphExecEventRecordNodeSetEvent execGraph recordNode doneEv2
                        hipEventRecord readyEv2 readyStream
                        hipGraphLaunch execGraph stream
                        hipEventSynchronize doneEv2
                        hipStreamSynchronize stream
                        output <- peekArray bytesCount hOut
                        if output == replicate bytesCount 0x5a
                          then putStrLn "hip graph child/event nodes: OK"
                          else error ("hip graph child/event nodes mismatch: expected all 0x5a, got=" <> show output)
