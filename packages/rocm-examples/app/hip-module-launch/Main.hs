module Main (main) where

import Control.Exception (bracket)
import Foreign.C.Types (CFloat(..), CInt(..), CSize)
import Foreign.Marshal.Alloc (free)
import Foreign.Marshal.Array (mallocArray, peekArray, pokeArray, withArray)
import Foreign.Marshal.Utils (with)
import Foreign.Ptr (castPtr, nullPtr)
import Foreign.Storable (sizeOf)
import ROCm.FFI.Core.Types (DevicePtr(..), HostPtr(..))
import ROCm.HIP
  ( HipDim3(..)
  , hipFree
  , hipGetCurrentDeviceGcnArchName
  , hipMallocBytes
  , hipMemcpyD2H
  , hipMemcpyH2D
  , hipModuleGetFunction
  , hipModuleLaunchKernel
  , hipStreamCreate
  , hipStreamDestroy
  , hipStreamSynchronize
  , withHipModuleData
  )
import ROCm.HIP.RTC
  ( hiprtcCompileProgram
  , hiprtcGetCode
  , withHiprtcProgram
  )

main :: IO ()
main = do
  let n = 256 :: Int
      threads = 64 :: Int
      blocks = (n + threads - 1) `div` threads
      input = fmap (CFloat . fromIntegral) [0 .. n - 1]
      expected = fmap (\(CFloat x) -> CFloat (x + 1)) input
      bytes = fromIntegral (n * sizeOf (undefined :: CFloat)) :: CSize
  arch <- normalizeHiprtcArch <$> hipGetCurrentDeviceGcnArchName
  bracket (mallocArray n) free $ \hIn ->
    bracket (mallocArray n) free $ \hOut -> do
      pokeArray hIn input
      bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dIn ->
        bracket (hipMallocBytes bytes :: IO (DevicePtr CFloat)) hipFree $ \dOut ->
          bracket hipStreamCreate hipStreamDestroy $ \stream -> do
            hipMemcpyH2D dIn (HostPtr hIn) bytes
            withHiprtcProgram hipModuleLaunchSource "hip_module_launch.hip" $ \prog -> do
              hiprtcCompileProgram prog ["--offload-arch=" ++ arch, "-O2"]
              codeObject <- hiprtcGetCode prog
              withHipModuleData codeObject $ \modu -> do
                fun <- hipModuleGetFunction modu "add_one"
                let DevicePtr pIn = dIn
                    DevicePtr pOut = dOut
                    grid = HipDim3 (fromIntegral blocks) 1 1
                    block = HipDim3 (fromIntegral threads) 1 1
                    nArg = fromIntegral n :: CInt
                with pOut $ \pArgOut ->
                  with pIn $ \pArgIn ->
                    with nArg $ \pArgN -> do
                      let kernelParams = [castPtr pArgOut, castPtr pArgIn, castPtr pArgN]
                      withArray kernelParams $ \pKernelParams -> do
                        hipModuleLaunchKernel fun grid block 0 (Just stream) pKernelParams nullPtr
                        hipStreamSynchronize stream
                        hipMemcpyD2H (HostPtr hOut) dOut bytes
                        output <- peekArray n hOut
                        if output == expected
                          then putStrLn "hip module launch: OK"
                          else error ("hip module launch mismatch: expected=" <> show expected <> ", got=" <> show output)

normalizeHiprtcArch :: String -> String
normalizeHiprtcArch = takeWhile (/= ':')

hipModuleLaunchSource :: String
hipModuleLaunchSource = unlines
  [ "extern \"C\" __global__ void add_one(float* out, const float* in, int n) {"
  , "  int i = blockIdx.x * blockDim.x + threadIdx.x;"
  , "  if (i < n) out[i] = in[i] + 1.0f;"
  , "}"
  ]
