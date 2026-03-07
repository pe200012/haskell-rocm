{-# LANGUAGE CPP #-}

module HeaderConstants where

import Foreign.C.Types (CInt, CUInt)

#include <hip/amd_detail/amd_hip_fp16.h>
#include <hip/hip_runtime.h>
#include <hip/hip_runtime_api.h>
#include <hip/driver_types.h>
#include <rocblas/internal/rocblas-types.h>
#include <rocsolver/rocsolver-extra-types.h>
#include <rocfft/rocfft.h>
#include <rocsparse/rocsparse-types.h>

hipSuccessHeader :: CInt
hipSuccessHeader = #{const hipSuccess}

hipErrorInvalidValueHeader :: CInt
hipErrorInvalidValueHeader = #{const hipErrorInvalidValue}

hipErrorNotReadyHeader :: CInt
hipErrorNotReadyHeader = #{const hipErrorNotReady}

hipHostMallocPortableHeader :: CUInt
hipHostMallocPortableHeader = #{const hipHostMallocPortable}

hipStreamNonBlockingHeader :: CUInt
hipStreamNonBlockingHeader = #{const hipStreamNonBlocking}

hipEventBlockingSyncHeader :: CUInt
hipEventBlockingSyncHeader = #{const hipEventBlockingSync}

hipEventDisableTimingHeader :: CUInt
hipEventDisableTimingHeader = #{const hipEventDisableTiming}

hipEventRecordExternalHeader :: CUInt
hipEventRecordExternalHeader = #{const hipEventRecordExternal}

hipHostRegisterMappedHeader :: CUInt
hipHostRegisterMappedHeader = #{const hipHostRegisterMapped}

hipMemcpyHostToDeviceHeader :: CInt
hipMemcpyHostToDeviceHeader = #{const hipMemcpyHostToDevice}

hipMemcpyDeviceToDeviceNoCUHeader :: CInt
hipMemcpyDeviceToDeviceNoCUHeader = #{const hipMemcpyDeviceToDeviceNoCU}

rocblasFillLowerHeader :: CInt
rocblasFillLowerHeader = #{const rocblas_fill_lower}

rocblasOperationNoneHeader :: CInt
rocblasOperationNoneHeader = #{const rocblas_operation_none}

rocblasEvectOriginalHeader :: CInt
rocblasEvectOriginalHeader = #{const rocblas_evect_original}

rocblasSvectSingularHeader :: CInt
rocblasSvectSingularHeader = #{const rocblas_svect_singular}

rocblasInPlaceHeader :: CInt
rocblasInPlaceHeader = #{const rocblas_inplace}

rocblasSrangeValueHeader :: CInt
rocblasSrangeValueHeader = #{const rocblas_srange_value}

rocblasSrangeIndexHeader :: CInt
rocblasSrangeIndexHeader = #{const rocblas_srange_index}

rocfftStatusSuccessHeader :: CInt
rocfftStatusSuccessHeader = #{const rocfft_status_success}

rocfftTransformTypeComplexForwardHeader :: CInt
rocfftTransformTypeComplexForwardHeader = #{const rocfft_transform_type_complex_forward}

rocfftTransformTypeRealForwardHeader :: CInt
rocfftTransformTypeRealForwardHeader = #{const rocfft_transform_type_real_forward}

rocfftTransformTypeRealInverseHeader :: CInt
rocfftTransformTypeRealInverseHeader = #{const rocfft_transform_type_real_inverse}

rocfftPrecisionSingleHeader :: CInt
rocfftPrecisionSingleHeader = #{const rocfft_precision_single}

rocfftPlacementInplaceHeader :: CInt
rocfftPlacementInplaceHeader = #{const rocfft_placement_inplace}

rocfftPlacementNotInplaceHeader :: CInt
rocfftPlacementNotInplaceHeader = #{const rocfft_placement_notinplace}

rocfftArrayTypeComplexInterleavedHeader :: CInt
rocfftArrayTypeComplexInterleavedHeader = #{const rocfft_array_type_complex_interleaved}

rocfftArrayTypeRealHeader :: CInt
rocfftArrayTypeRealHeader = #{const rocfft_array_type_real}

rocfftArrayTypeHermitianInterleavedHeader :: CInt
rocfftArrayTypeHermitianInterleavedHeader = #{const rocfft_array_type_hermitian_interleaved}

rocfftArrayTypeUnsetHeader :: CInt
rocfftArrayTypeUnsetHeader = #{const rocfft_array_type_unset}

rocsparseStatusSuccessHeader :: CInt
rocsparseStatusSuccessHeader = #{const rocsparse_status_success}

rocsparseOperationNoneHeader :: CInt
rocsparseOperationNoneHeader = #{const rocsparse_operation_none}

rocsparseIndexBaseZeroHeader :: CInt
rocsparseIndexBaseZeroHeader = #{const rocsparse_index_base_zero}

rocsparseMatrixTypeGeneralHeader :: CInt
rocsparseMatrixTypeGeneralHeader = #{const rocsparse_matrix_type_general}

rocsparseIndexTypeI32Header :: CInt
rocsparseIndexTypeI32Header = #{const rocsparse_indextype_i32}

rocsparseDataTypeF32RHeader :: CInt
rocsparseDataTypeF32RHeader = #{const rocsparse_datatype_f32_r}

rocsparseV2SpMVStageAnalysisHeader :: CInt
rocsparseV2SpMVStageAnalysisHeader = #{const rocsparse_v2_spmv_stage_analysis}

rocsparseSpMVAlgCsrAdaptiveHeader :: CInt
rocsparseSpMVAlgCsrAdaptiveHeader = #{const rocsparse_spmv_alg_csr_adaptive}

rocsparseSpMVAlgCsrRowsplitHeader :: CInt
rocsparseSpMVAlgCsrRowsplitHeader = #{const rocsparse_spmv_alg_csr_rowsplit}
