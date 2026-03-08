{-# LANGUAGE ForeignFunctionInterface #-}
{-# LANGUAGE PatternSynonyms #-}

module Main (main) where

import Control.Exception (bracket, bracket_)
import Foreign.C.Types (CFloat(..), CInt(..), CSize)
import Foreign.Marshal.Alloc (free)
import Foreign.Marshal.Array (mallocArray, peekArray, pokeArray, withArray)
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
  , hipFree
  , hipGraphAddKernelNode
  , hipGraphAddMemcpyNode1D
  , hipGraphCreate
  , hipGraphDestroy
  , hipGraphExecDestroy
  , hipGraphExecKernelNodeSetParams
  , hipGraphInstantiate
  , hipGraphKernelNodeGetParams
  , hipGraphKernelNodeSetParams
  , hipGraphLaunch
  , hipMallocBytes
  , hipStreamCreate
  , hipStreamDestroy
  , hipStreamSynchronize
  , pattern HipMemcpyDeviceToHost
  , pattern HipMemcpyHostToDevice
  )

foreign import ccall "dynamic"
  mkKernelAddressGetter :: FunPtr (IO (Ptr ())) -> IO (Ptr ())

main :: IO ()
main = do
  let n = 128 :: Int
      threads = 64 :: Int
      blocks = (n + threads - 1) `div` threads
      input = fmap (CFloat . fromIntegral . (`mod` 13)) [0 .. n - 1]
      expected = fmap (\(CFloat x) -> CFloat (x + 1)) input
      bytes = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
      grid = HipDim3 (fromIntegral blocks) 1 1
      block = HipDim3 (fromIntegral threads) 1 1
  bracket (mallocArray n) free $ \hIn ->
    bracket (mallocArray n) free $ \hOut -> do
      pokeArray hIn input
      bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dIn ->
        bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dOut ->
          bracket hipStreamCreate hipStreamDestroy $ \stream ->
            withDirectAddOneKernelAddress "hip_graph_kernel_node_example" $ \kernelAddress -> do
              let DevicePtr pIn = dIn
                  DevicePtr pOut = dOut
                  nArg = fromIntegral n :: CInt
              with pOut $ \pArgOut ->
                with pIn $ \pArgIn ->
                  with nArg $ \pArgN ->
                    withArray [castPtr pArgOut, castPtr pArgIn, castPtr pArgN] $ \kernelParams ->
                      bracket (hipGraphCreate 0) hipGraphDestroy $ \graph -> do
                        h2dNode <- hipGraphAddMemcpyNode1D graph [] (castPtr pIn) (castPtr hIn) bytes HipMemcpyHostToDevice
                        let params =
                              HipKernelNodeParams
                                { hipKernelNodeBlockDim = block
                                , hipKernelNodeExtra = nullPtr
                                , hipKernelNodeFunc = kernelAddress
                                , hipKernelNodeGridDim = grid
                                , hipKernelNodeKernelParams = kernelParams
                                , hipKernelNodeSharedMemBytes = 0
                                }
                        kernelNode <- hipGraphAddKernelNode graph [h2dNode] params
                        gotParams <- hipGraphKernelNodeGetParams kernelNode
                        if hipKernelNodeBlockDim gotParams /= block
                          || hipKernelNodeGridDim gotParams /= grid
                          || hipKernelNodeFunc gotParams /= kernelAddress
                          || hipKernelNodeSharedMemBytes gotParams /= 0
                          then error ("hip graph kernel node get-params mismatch: got=" <> show gotParams)
                          else pure ()
                        hipGraphKernelNodeSetParams kernelNode params
                        _ <- hipGraphAddMemcpyNode1D graph [kernelNode] (castPtr hOut) (castPtr pOut) bytes HipMemcpyDeviceToHost
                        execGraph <- hipGraphInstantiate graph
                        bracket_ (pure ()) (hipGraphExecDestroy execGraph) $ do
                          hipGraphExecKernelNodeSetParams execGraph kernelNode params
                          hipGraphLaunch execGraph stream
                          hipStreamSynchronize stream
                          output <- peekArray n hOut
                          if output == expected
                            then putStrLn "hip graph kernel node: OK"
                            else error ("hip graph kernel node mismatch: expected=" <> show expected <> ", got=" <> show output)

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
            <> " while building direct HIP kernel helper\nstdout:\n"
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
