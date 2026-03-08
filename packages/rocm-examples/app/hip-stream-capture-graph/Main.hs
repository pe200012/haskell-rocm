{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Control.Exception (bracket, bracket_)
import Foreign.C.Types (CFloat(..), CInt(..), CSize)
import Foreign.Marshal.Array (peekArray, pokeArray, withArray)
import Foreign.Marshal.Utils (with)
import Foreign.Ptr (FunPtr, Ptr, castPtr)
import Foreign.Storable (sizeOf)
import System.Directory (createDirectoryIfMissing, findExecutable, getTemporaryDirectory)
import System.Exit (ExitCode(..))
import System.FilePath ((</>))
import System.Posix.DynamicLinker (RTLDFlags(RTLD_LOCAL, RTLD_NOW), dlclose, dlopen, dlsym)
import System.Process (readProcessWithExitCode)
import ROCm.FFI.Core.Types (DevicePtr(..), PinnedHostPtr(..))
import ROCm.HIP
  ( HipDim3(..)
  , HipFunctionAddress(..)
  , HipGraphInstantiateFlags(..)
  , hipFree
  , hipHostFree
  , hipHostMallocBytes
  , hipLaunchKernel
  , hipMallocBytes
  , hipMemcpyD2HAsync
  , hipMemcpyH2DAsync
  , hipStreamBeginCapture
  , hipStreamCreate
  , hipStreamDestroy
  , hipStreamEndCapture
  , hipStreamGetCaptureInfo
  , hipStreamIsCapturing
  , hipStreamSynchronize
  , hipGraphDestroy
  , hipGraphExecDestroy
  , hipGraphInstantiateWithFlags
  , hipGraphLaunch
  , pattern HipStreamCaptureModeRelaxed
  , pattern HipStreamCaptureStatusActive
  )

foreign import ccall "dynamic"
  mkKernelAddressGetter :: FunPtr (IO (Ptr ())) -> IO (Ptr ())

main :: IO ()
main = do
  let n = 64 :: Int
      input = fmap (CFloat . fromIntegral) [0 .. n - 1]
      expected = fmap (\(CFloat x) -> CFloat (x + 1)) input
      bytes = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
      grid = HipDim3 1 1 1
      block = HipDim3 64 1 1
  bracket (hipHostMallocBytes bytes :: IO (PinnedHostPtr CFloat)) hipHostFree $ \hInPinned ->
    bracket (hipHostMallocBytes bytes :: IO (PinnedHostPtr CFloat)) hipHostFree $ \hOutPinned -> do
      let PinnedHostPtr pInPinned = hInPinned
          PinnedHostPtr pOutPinned = hOutPinned
      pokeArray pInPinned input
      bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dIn ->
        bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dOut ->
          bracket hipStreamCreate hipStreamDestroy $ \stream ->
            withDirectAddOneKernelAddress "hip_stream_capture_graph_example" $ \kernelAddress -> do
              hipStreamBeginCapture stream HipStreamCaptureModeRelaxed
              status1 <- hipStreamIsCapturing stream
              if status1 /= HipStreamCaptureStatusActive
                then error ("hipStreamIsCapturing expected active, got=" <> show status1)
                else pure ()
              (status2, captureId) <- hipStreamGetCaptureInfo stream
              if status2 /= HipStreamCaptureStatusActive || captureId == 0
                then error ("hipStreamGetCaptureInfo mismatch: status=" <> show status2 <> ", id=" <> show captureId)
                else pure ()
              hipMemcpyH2DAsync dIn hInPinned bytes stream
              let DevicePtr pIn = dIn
                  DevicePtr pOut = dOut
                  nArg = fromIntegral n :: CInt
              with pOut $ \pArgOut ->
                with pIn $ \pArgIn ->
                  with nArg $ \pArgN ->
                    withArray [castPtr pArgOut, castPtr pArgIn, castPtr pArgN] $ \kernelParams -> do
                      hipLaunchKernel kernelAddress grid block kernelParams 0 (Just stream)
                      hipMemcpyD2HAsync hOutPinned dOut bytes stream
                      capturedGraph <- hipStreamEndCapture stream
                      bracket (pure capturedGraph) hipGraphDestroy $ \graph -> do
                        execGraph <- hipGraphInstantiateWithFlags graph (HipGraphInstantiateFlags 0)
                        bracket_ (pure ()) (hipGraphExecDestroy execGraph) $ do
                          hipGraphLaunch execGraph stream
                          hipStreamSynchronize stream
                          output <- peekArray n pOutPinned
                          if output == expected
                            then putStrLn "hip stream capture graph: OK"
                            else error ("hip stream capture graph mismatch: expected=" <> show expected <> ", got=" <> show output)

withDirectAddOneKernelAddress :: String -> (HipFunctionAddress -> IO a) -> IO a
withDirectAddOneKernelAddress buildName action = do
  tempDir <- getTemporaryDirectory
  let buildDir = tempDir </> "haskell-rocm-hip-direct-kernels"
      srcPath = buildDir </> (buildName <> ".hip")
      soPath = buildDir </> ("lib" <> buildName <> ".so")
  createDirectoryIfMissing True buildDir
  writeFile srcPath hipDirectAddOneSource
  mHipcc <- findExecutable "hipcc"
  hipcc <- case mHipcc of
    Just path -> pure path
    Nothing -> error "hipcc not found in PATH"
  (exitCode, stdOut, stdErr) <- readProcessWithExitCode hipcc ["-shared", "-fPIC", "-O2", srcPath, "-o", soPath] ""
  case exitCode of
    ExitSuccess ->
      bracket (dlopen soPath [RTLD_NOW, RTLD_LOCAL]) dlclose $ \dl -> do
        getter <- dlsym dl "add_one_kernel_address" :: IO (FunPtr (IO (Ptr ())))
        address <- HipFunctionAddress <$> mkKernelAddressGetter getter
        action address
    ExitFailure code ->
      error
        ( "hipcc failed with exit code "
            <> show code
            <> " while building stream-capture helper\nstdout:\n"
            <> stdOut
            <> "\nstderr:\n"
            <> stdErr
        )

hipDirectAddOneSource :: String
hipDirectAddOneSource = unlines
  [ "#include <hip/hip_runtime.h>"
  , "extern \"C\" __global__ void add_one(float* out, const float* in, int n) {"
  , "  int i = blockIdx.x * blockDim.x + threadIdx.x;"
  , "  if (i < n) out[i] = in[i] + 1.0f;"
  , "}"
  , "extern \"C\" void* add_one_kernel_address() {"
  , "  return (void*)add_one;"
  , "}"
  ]
