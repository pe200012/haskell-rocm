module ROCm.HIP.Device
  ( hipGetDeviceCount
  , hipGetCurrentDevice
  , hipGetDeviceName
  , hipGetDeviceGcnArchName
  , hipGetCurrentDeviceName
  , hipGetCurrentDeviceGcnArchName
  ) where

import Foreign.C.String (peekCString)
import Foreign.C.Types (CInt(..))
import Foreign.Marshal.Alloc (alloca, allocaBytes)
import Foreign.Ptr (Ptr, castPtr, plusPtr)
import Foreign.Storable (peek)
import GHC.Stack (HasCallStack)

import ROCm.HIP.DeviceProp
  ( HipDeviceProp
  , hipDevicePropGcnArchNameOffset
  , hipDevicePropNameOffset
  , hipDevicePropSize
  )
import ROCm.HIP.Error (checkHip)
import ROCm.HIP.Raw
  ( c_hipGetDevice
  , c_hipGetDeviceCount
  , c_hipGetDeviceProperties
  )

hipGetDeviceCount :: HasCallStack => IO Int
hipGetDeviceCount =
  alloca $ \pCount -> do
    checkHip "hipGetDeviceCount" =<< c_hipGetDeviceCount pCount
    fromIntegral <$> (peek pCount :: IO CInt)

hipGetCurrentDevice :: HasCallStack => IO Int
hipGetCurrentDevice =
  alloca $ \pDevice -> do
    checkHip "hipGetDevice" =<< c_hipGetDevice pDevice
    fromIntegral <$> (peek pDevice :: IO CInt)

hipGetDeviceName :: HasCallStack => Int -> IO String
hipGetDeviceName dev = withDeviceProp dev $ \p -> peekCString (plusPtr (castPtr p) hipDevicePropNameOffset)

hipGetDeviceGcnArchName :: HasCallStack => Int -> IO String
hipGetDeviceGcnArchName dev = withDeviceProp dev $ \p -> peekCString (plusPtr (castPtr p) hipDevicePropGcnArchNameOffset)

hipGetCurrentDeviceName :: HasCallStack => IO String
hipGetCurrentDeviceName = hipGetCurrentDevice >>= hipGetDeviceName

hipGetCurrentDeviceGcnArchName :: HasCallStack => IO String
hipGetCurrentDeviceGcnArchName = hipGetCurrentDevice >>= hipGetDeviceGcnArchName

withDeviceProp :: HasCallStack => Int -> (Ptr HipDeviceProp -> IO a) -> IO a
withDeviceProp dev k =
  allocaBytes hipDevicePropSize $ \raw -> do
    checkHip "hipGetDeviceProperties" =<< c_hipGetDeviceProperties (castPtr raw) (fromIntegral dev)
    k (castPtr raw)
