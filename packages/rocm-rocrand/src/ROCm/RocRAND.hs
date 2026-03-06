module ROCm.RocRAND
  ( module ROCm.RocRAND.Types
  , module ROCm.RocRAND.Error
  , rocrandCreateGenerator
  , rocrandDestroyGenerator
  , withRocRandGenerator
  , rocrandSetStream
  , rocrandSetSeed
  , rocrandGetVersion
  , rocrandGenerateUniform
  , rocrandGenerateUniformDouble
  , rocrandGenerateNormal
  , rocrandGenerateNormalDouble
  ) where

import Control.Exception (bracket)
import Data.Word (Word64)
import Foreign.C.Types (CDouble(..), CFloat(..), CSize)
import Foreign.Marshal.Alloc (alloca)
import Foreign.Ptr (castPtr)
import Foreign.Storable (peek)
import GHC.Stack (HasCallStack)
import ROCm.FFI.Core.Types (DevicePtr(..), HipStream(..), RocRandGenerator(..))
import ROCm.RocRAND.Error (checkRocRand)
import ROCm.RocRAND.Raw
  ( c_rocrand_create_generator
  , c_rocrand_destroy_generator
  , c_rocrand_generate_normal
  , c_rocrand_generate_normal_double
  , c_rocrand_generate_uniform
  , c_rocrand_generate_uniform_double
  , c_rocrand_get_version
  , c_rocrand_set_seed
  , c_rocrand_set_stream
  )
import ROCm.RocRAND.Types

rocrandCreateGenerator :: HasCallStack => RocRandRngType -> IO RocRandGenerator
rocrandCreateGenerator rngType =
  alloca $ \pGen -> do
    checkRocRand "rocrand_create_generator" =<< c_rocrand_create_generator pGen rngType
    RocRandGenerator <$> peek pGen

rocrandDestroyGenerator :: HasCallStack => RocRandGenerator -> IO ()
rocrandDestroyGenerator (RocRandGenerator gen) =
  checkRocRand "rocrand_destroy_generator" =<< c_rocrand_destroy_generator gen

withRocRandGenerator :: HasCallStack => RocRandRngType -> (RocRandGenerator -> IO a) -> IO a
withRocRandGenerator rngType = bracket (rocrandCreateGenerator rngType) rocrandDestroyGenerator

rocrandSetStream :: HasCallStack => RocRandGenerator -> HipStream -> IO ()
rocrandSetStream (RocRandGenerator gen) (HipStream stream) =
  checkRocRand "rocrand_set_stream" =<< c_rocrand_set_stream gen stream

rocrandSetSeed :: HasCallStack => RocRandGenerator -> Word64 -> IO ()
rocrandSetSeed (RocRandGenerator gen) seed =
  checkRocRand "rocrand_set_seed" =<< c_rocrand_set_seed gen (fromIntegral seed)

rocrandGetVersion :: HasCallStack => IO Int
rocrandGetVersion =
  alloca $ \pVersion -> do
    checkRocRand "rocrand_get_version" =<< c_rocrand_get_version pVersion
    fromIntegral <$> peek pVersion

rocrandGenerateUniform :: HasCallStack => RocRandGenerator -> DevicePtr CFloat -> CSize -> IO ()
rocrandGenerateUniform (RocRandGenerator gen) (DevicePtr out) n =
  checkRocRand "rocrand_generate_uniform" =<< c_rocrand_generate_uniform gen (castPtr out) n

rocrandGenerateUniformDouble :: HasCallStack => RocRandGenerator -> DevicePtr CDouble -> CSize -> IO ()
rocrandGenerateUniformDouble (RocRandGenerator gen) (DevicePtr out) n =
  checkRocRand "rocrand_generate_uniform_double" =<< c_rocrand_generate_uniform_double gen (castPtr out) n

rocrandGenerateNormal :: HasCallStack => RocRandGenerator -> DevicePtr CFloat -> CSize -> Float -> Float -> IO ()
rocrandGenerateNormal (RocRandGenerator gen) (DevicePtr out) n mean stddev =
  checkRocRand "rocrand_generate_normal" =<< c_rocrand_generate_normal gen (castPtr out) n (CFloat mean) (CFloat stddev)

rocrandGenerateNormalDouble :: HasCallStack => RocRandGenerator -> DevicePtr CDouble -> CSize -> Double -> Double -> IO ()
rocrandGenerateNormalDouble (RocRandGenerator gen) (DevicePtr out) n mean stddev =
  checkRocRand "rocrand_generate_normal_double" =<< c_rocrand_generate_normal_double gen (castPtr out) n (CDouble mean) (CDouble stddev)
