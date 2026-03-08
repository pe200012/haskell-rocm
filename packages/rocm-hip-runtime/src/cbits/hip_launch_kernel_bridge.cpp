#include <hip/hip_runtime_api.h>

extern "C" hipError_t hs_rocm_hipLaunchKernel(const void* function_address,
                                               unsigned int gridDimX,
                                               unsigned int gridDimY,
                                               unsigned int gridDimZ,
                                               unsigned int blockDimX,
                                               unsigned int blockDimY,
                                               unsigned int blockDimZ,
                                               void** args,
                                               size_t sharedMemBytes,
                                               hipStream_t stream) {
  return hipLaunchKernel(function_address,
                         dim3(gridDimX, gridDimY, gridDimZ),
                         dim3(blockDimX, blockDimY, blockDimZ),
                         args,
                         sharedMemBytes,
                         stream);
}
