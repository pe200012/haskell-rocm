module ROCm.HIP.DeviceProp
  ( HipDeviceProp
  , hipDevicePropSize
  , hipDevicePropNameOffset
  , hipDevicePropGcnArchNameOffset
  ) where

#include <hip/hip_runtime_api.h>

data HipDeviceProp

hipDevicePropSize :: Int
hipDevicePropSize = #{size hipDeviceProp_t}

hipDevicePropNameOffset :: Int
hipDevicePropNameOffset = #{offset hipDeviceProp_t, name}

hipDevicePropGcnArchNameOffset :: Int
hipDevicePropGcnArchNameOffset = #{offset hipDeviceProp_t, gcnArchName}
