{-# LANGUAGE ForeignFunctionInterface #-}

module Main (main) where

import Control.Exception (bracket)
import Foreign.C.Types (CFloat(..), CInt(..), CSize)
import Foreign.Marshal.Alloc (free)
import Foreign.Marshal.Array (mallocArray, peekArray, pokeArray, withArray)
import Foreign.Marshal.Utils (with)
import Foreign.Ptr (FunPtr, Ptr, castPtr)
import Foreign.Storable (sizeOf)
import System.Directory (createDirectoryIfMissing, findExecutable, getTemporaryDirectory)
import System.Exit (ExitCode(..))
import System.FilePath ((</>))
import System.Posix.DynamicLinker (RTLDFlags(RTLD_LOCAL, RTLD_NOW), dlclose, dlopen, dlsym)
import System.Process (readProcessWithExitCode)
import ROCm.FFI.Core.Types (DevicePtr(..), HostPtr(..))
import ROCm.HIP
  ( HipDim3(..)
  , HipFunctionAddress(..)
  , HipLaunchConfig(..)
  , hipFree
  , hipLaunchAttributeCooperative
  , hipLaunchKernelExC
  , hipMallocBytes
  , hipMemcpyD2H
  , hipMemcpyH2D
  , hipStreamCreate
  , hipStreamDestroy
  , hipStreamSynchronize
  , withHipLaunchAttributes
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
  bracket (mallocArray n) free $ \hIn ->
    bracket (mallocArray n) free $ \hOut -> do
      pokeArray hIn input
      bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dIn ->
        bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dOut ->
          bracket hipStreamCreate hipStreamDestroy $ \stream ->
            withDirectAddOneKernelAddress "hip_launch_kernel_exc_cooperative_attr_example" $ \kernelAddress ->
              withHipLaunchAttributes [hipLaunchAttributeCooperative True] $ \pAttrs attrCount -> do
                hipMemcpyH2D dIn (HostPtr hIn) bytes
                let DevicePtr pIn = dIn
                    DevicePtr pOut = dOut
                    nArg = fromIntegral n :: CInt
                    config =
                      HipLaunchConfig
                        { hipLaunchConfigGridDim = grid
                        , hipLaunchConfigBlockDim = block
                        , hipLaunchConfigDynamicSmemBytes = 0
                        , hipLaunchConfigStream = Just stream
                        , hipLaunchConfigAttrs = castPtr pAttrs
                        , hipLaunchConfigNumAttrs = attrCount
                        }
                with pOut $ \pArgOut ->
                  with pIn $ \pArgIn ->
                    with nArg $ \pArgN ->
                      withArray [castPtr pArgOut, castPtr pArgIn, castPtr pArgN] $ \kernelParams -> do
                        hipLaunchKernelExC config kernelAddress kernelParams
                        hipStreamSynchronize stream
                        hipMemcpyD2H (HostPtr hOut) dOut bytes
                        output <- peekArray n hOut
                        if output == expected
                          then putStrLn "hip launch kernel exc cooperative attr: OK"
                          else error ("hip launch kernel exc cooperative attr mismatch: expected=" <> show expected <> ", got=" <> show output)

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
            <> " while building cooperative hipLaunchKernelExC helper\nstdout:\n"
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
