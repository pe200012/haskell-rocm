{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Control.Exception (bracket, bracket_)
import Data.Bits ((.|.))
import Data.Char (isSpace)
import Data.List (isPrefixOf)
import Data.Word (Word8)
import Foreign.C.Types (CSize)
import Foreign.Marshal.Alloc (free)
import Foreign.Marshal.Array (mallocArray, peekArray)
import Foreign.Ptr (Ptr, castPtr)
import System.Directory (createDirectoryIfMissing, doesFileExist, getTemporaryDirectory)
import System.FilePath ((</>))
import ROCm.FFI.Core.Types (DevicePtr(..))
import ROCm.HIP
  ( HipGraphExecUpdateInfo(..)
  , HipMemsetParams(..)
  , hipFree
  , hipGraphAddMemcpyNode1D
  , hipGraphAddMemsetNode
  , hipGraphCreate
  , hipGraphDebugDotPrint
  , hipGraphDestroy
  , hipGraphExecDestroy
  , hipGraphExecUpdate
  , hipGraphInstantiate
  , hipGraphLaunch
  , hipGraphMemsetNodeGetParams
  , hipGraphNodeFindInClone
  , hipMallocBytes
  , hipStreamCreate
  , hipStreamDestroy
  , hipStreamSynchronize
  , withHipGraphClone
  , pattern HipGraphDebugDotFlagsHandles
  , pattern HipGraphDebugDotFlagsMemsetNodeParams
  , pattern HipGraphDebugDotFlagsVerbose
  , pattern HipGraphExecUpdateSuccess
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
      dotPath = dotDir </> "hip_graph_update_clone_debug_example.dot"
  createDirectoryIfMissing True dotDir
  bracket (mallocArray bytesCount :: IO (Ptr Word8)) free $ \hOut ->
    bracket (hipMallocBytes bytes :: IO (DevicePtr Word8)) hipFree $ \dBuf ->
      bracket hipStreamCreate hipStreamDestroy $ \stream -> do
        let DevicePtr pBuf = dBuf
        bracket (hipGraphCreate 0) hipGraphDestroy $ \graph1 ->
          bracket (hipGraphCreate 0) hipGraphDestroy $ \graph2 -> do
            memsetNode1 <- hipGraphAddMemsetNode graph1 [] (paramsFor (castPtr pBuf) (0x11 :: Word8))
            _ <- hipGraphAddMemcpyNode1D graph1 [memsetNode1] (castPtr hOut) (castPtr pBuf) bytes HipMemcpyDeviceToHost
            memsetNode2 <- hipGraphAddMemsetNode graph2 [] (paramsFor (castPtr pBuf) (0x44 :: Word8))
            _ <- hipGraphAddMemcpyNode1D graph2 [memsetNode2] (castPtr hOut) (castPtr pBuf) bytes HipMemcpyDeviceToHost
            withHipGraphClone graph1 $ \graphClone -> do
              cloneNode <- hipGraphNodeFindInClone memsetNode1 graphClone
              _ <- hipGraphMemsetNodeGetParams cloneNode
              hipGraphDebugDotPrint graphClone dotPath (HipGraphDebugDotFlagsVerbose .|. HipGraphDebugDotFlagsMemsetNodeParams .|. HipGraphDebugDotFlagsHandles)
              dotExists <- doesFileExist dotPath
              if not dotExists
                then error "hipGraphDebugDotPrint did not produce the DOT file"
                else pure ()
              dotContents <- readFile dotPath
              if "digraph" `isPrefixOf` dropWhile isSpace dotContents || "digraph" `elem` words dotContents
                then pure ()
                else error ("hipGraphDebugDotPrint output does not look like DOT: " <> take 120 dotContents)
            execGraph <- hipGraphInstantiate graph1
            bracket_ (pure ()) (hipGraphExecDestroy execGraph) $ do
              updateInfo <- hipGraphExecUpdate execGraph graph2
              if hipGraphExecUpdateResult updateInfo /= HipGraphExecUpdateSuccess
                then error ("hipGraphExecUpdate expected success, got=" <> show updateInfo)
                else pure ()
              hipGraphLaunch execGraph stream
              hipStreamSynchronize stream
              output <- peekArray bytesCount hOut
              if output == replicate bytesCount 0x44
                then putStrLn "hip graph update/clone/debug-dot: OK"
                else error ("hip graph update/clone/debug-dot mismatch: expected all 0x44, got=" <> show output)
