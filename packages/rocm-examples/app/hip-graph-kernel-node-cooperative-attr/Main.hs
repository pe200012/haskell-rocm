{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE ForeignFunctionInterface #-}

module Main (main) where

import Control.Exception (bracket)
import Foreign.C.Types (CFloat, CInt(..), CSize)
import Foreign.Marshal.Array (withArray)
import Foreign.Marshal.Utils (with)
import Foreign.Ptr (FunPtr, Ptr, castPtr, nullPtr)
import Foreign.Storable (sizeOf)
import System.Directory (createDirectoryIfMissing, findExecutable, getTemporaryDirectory)
import System.Exit (ExitCode(..))
import System.FilePath ((</>))
import System.Posix.DynamicLinker (RTLDFlags(RTLD_LOCAL, RTLD_NOW), dlclose, dlopen, dlsym)
import System.Process (readProcessWithExitCode)
import ROCm.FFI.Core.Types (DevicePtr(..))
import ROCm.HIP
  ( HipDim3(..)
  , HipFunctionAddress(..)
  , HipKernelNodeParams(..)
  , HipLaunchAttributeValue(..)
  , hipFree
  , hipGraphAddKernelNode
  , hipGraphCreate
  , hipGraphDestroy
  , hipGraphKernelNodeCopyAttributes
  , hipGraphKernelNodeGetAttribute
  , hipGraphKernelNodeSetAttribute
  , hipMallocBytes
  , pattern HipLaunchAttributeCooperative
  )

foreign import ccall "dynamic"
  mkKernelAddressGetter :: FunPtr (IO (Ptr ())) -> IO (Ptr ())

main :: IO ()
main = do
  let n = 64 :: Int
      bytes = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
      grid = HipDim3 1 1 1
      block = HipDim3 64 1 1
  bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dIn ->
    bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dOut ->
      withDirectAddOneKernelAddress "hip_graph_kernel_node_cooperative_attr_example" $ \kernelAddress -> do
        let DevicePtr pIn = dIn
            DevicePtr pOut = dOut
            nArg = fromIntegral n :: CInt
        with pOut $ \pArgOut ->
          with pIn $ \pArgIn ->
            with nArg $ \pArgN ->
              withArray [castPtr pArgOut, castPtr pArgIn, castPtr pArgN] $ \kernelParams ->
                bracket (hipGraphCreate 0) hipGraphDestroy $ \graph -> do
                  let params =
                        HipKernelNodeParams
                          { hipKernelNodeBlockDim = block
                          , hipKernelNodeExtra = nullPtr
                          , hipKernelNodeFunc = kernelAddress
                          , hipKernelNodeGridDim = grid
                          , hipKernelNodeKernelParams = kernelParams
                          , hipKernelNodeSharedMemBytes = 0
                          }
                  node1 <- hipGraphAddKernelNode graph [] params
                  node2 <- hipGraphAddKernelNode graph [] params
                  hipGraphKernelNodeSetAttribute node1 HipLaunchAttributeCooperative (HipLaunchAttributeValueCooperative True)
                  value1 <- hipGraphKernelNodeGetAttribute node1 HipLaunchAttributeCooperative
                  if value1 /= HipLaunchAttributeValueCooperative True
                    then error ("hip graph kernel node cooperative attr get mismatch: got=" <> show value1)
                    else pure ()
                  hipGraphKernelNodeCopyAttributes node1 node2
                  value2 <- hipGraphKernelNodeGetAttribute node2 HipLaunchAttributeCooperative
                  if value2 /= HipLaunchAttributeValueCooperative True
                    then error ("hip graph kernel node cooperative attr copy mismatch: got=" <> show value2)
                    else putStrLn "hip graph kernel node cooperative attr: OK"

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
            <> " while building kernel-node cooperative-attr helper\nstdout:\n"
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
