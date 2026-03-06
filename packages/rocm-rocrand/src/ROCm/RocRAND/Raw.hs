{-# LANGUAGE ForeignFunctionInterface #-}

module ROCm.RocRAND.Raw
  ( c_rocrand_create_generator
  , c_rocrand_destroy_generator
  , c_rocrand_set_stream
  , c_rocrand_set_seed
  , c_rocrand_get_version
  , c_rocrand_generate_uniform
  , c_rocrand_generate_uniform_double
  , c_rocrand_generate_normal
  , c_rocrand_generate_normal_double
  ) where

import Foreign.C.Types (CDouble(..), CFloat(..), CInt(..), CSize(..), CULLong(..))
import Foreign.Ptr (Ptr)
import ROCm.FFI.Core.Types (HipStreamTag, RocRandGeneratorTag)
import ROCm.RocRAND.Types (RocRandRngType(..), RocRandStatus(..))

foreign import ccall safe "rocrand_create_generator"
  c_rocrand_create_generator :: Ptr (Ptr RocRandGeneratorTag) -> RocRandRngType -> IO RocRandStatus

foreign import ccall safe "rocrand_destroy_generator"
  c_rocrand_destroy_generator :: Ptr RocRandGeneratorTag -> IO RocRandStatus

foreign import ccall safe "rocrand_set_stream"
  c_rocrand_set_stream :: Ptr RocRandGeneratorTag -> Ptr HipStreamTag -> IO RocRandStatus

foreign import ccall safe "rocrand_set_seed"
  c_rocrand_set_seed :: Ptr RocRandGeneratorTag -> CULLong -> IO RocRandStatus

foreign import ccall safe "rocrand_get_version"
  c_rocrand_get_version :: Ptr CInt -> IO RocRandStatus

foreign import ccall safe "rocrand_generate_uniform"
  c_rocrand_generate_uniform :: Ptr RocRandGeneratorTag -> Ptr CFloat -> CSize -> IO RocRandStatus

foreign import ccall safe "rocrand_generate_uniform_double"
  c_rocrand_generate_uniform_double :: Ptr RocRandGeneratorTag -> Ptr CDouble -> CSize -> IO RocRandStatus

foreign import ccall safe "rocrand_generate_normal"
  c_rocrand_generate_normal :: Ptr RocRandGeneratorTag -> Ptr CFloat -> CSize -> CFloat -> CFloat -> IO RocRandStatus

foreign import ccall safe "rocrand_generate_normal_double"
  c_rocrand_generate_normal_double :: Ptr RocRandGeneratorTag -> Ptr CDouble -> CSize -> CDouble -> CDouble -> IO RocRandStatus
