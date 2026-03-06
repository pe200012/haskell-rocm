{-# LANGUAGE PatternSynonyms #-}

module ROCm.HIP
  ( module ROCm.HIP.Types
  , module ROCm.HIP.Device
  , module ROCm.HIP.Error

    -- * Memory
  , hipMallocBytes
  , hipFree
  , hipHostMallocBytes
  , hipHostMallocBytesWithFlags
  , hipHostFree

    -- * Memcpy
  , hipMemcpy
  , hipMemcpyAsync
  , hipMemcpyWithStream
  , hipMemcpyH2D
  , hipMemcpyD2H
  , hipMemcpyD2D
  , hipMemcpyH2DWithStream
  , hipMemcpyD2HWithStream
  , hipMemcpyD2DWithStream
  , hipMemcpyH2DAsync
  , hipMemcpyD2HAsync
  , hipMemcpyD2DAsync

    -- * Synchronization
  , hipDeviceSynchronize

    -- * Streams
  , hipStreamCreate
  , hipStreamDestroy
  , hipStreamSynchronize

    -- * Events
  , hipEventCreate
  , hipEventDestroy
  , hipEventRecord
  , hipEventSynchronize
  , hipEventQuery
  , hipEventElapsedTime
  , withHipEvent

    -- * Callbacks
  , hipStreamAddCallback

    -- * Error state
  , hipGetLastError
  , hipPeekAtLastError
  ) where

import Control.Exception (SomeException, bracket, displayException, try)
import Foreign.C.Types (CFloat(..), CSize)
import Foreign.Marshal.Alloc (alloca)
import Foreign.Ptr (FunPtr, Ptr, castPtr, freeHaskellFunPtr)
import Foreign.StablePtr (StablePtr, castPtrToStablePtr, castStablePtrToPtr, deRefStablePtr, freeStablePtr, newStablePtr)
import Foreign.Storable (peek)
import GHC.Stack (HasCallStack)
import System.IO (hPutStrLn, stderr)
import ROCm.FFI.Core.Types (DevicePtr(..), HipEvent(..), HipStream(..), HipStreamTag, HostPtr(..), PinnedHostPtr(..))
import ROCm.HIP.Device
import ROCm.HIP.Error (checkHip)
import ROCm.HIP.Raw
  ( c_hipDeviceSynchronize
  , c_hipEventCreate
  , c_hipEventDestroy
  , c_hipEventElapsedTime
  , c_hipEventQuery
  , c_hipEventRecord
  , c_hipEventSynchronize
  , c_hipFree
  , c_hipGetLastError
  , c_hipHostFree
  , c_hipHostMalloc
  , c_hipMalloc
  , c_hipMemcpy
  , c_hipMemcpyAsync
  , c_hipMemcpyWithStream
  , c_hipPeekAtLastError
  , c_hipStreamAddCallback
  , c_hipStreamCreate
  , c_hipStreamDestroy
  , c_hipStreamSynchronize
  , mkHipStreamCallback
  )
import ROCm.HIP.Types
  ( HipError
  , HipHostMallocFlags
  , HipMemcpyKind
  , pattern HipErrorNotReady
  , pattern HipHostMallocDefault
  , pattern HipHostMallocPortable
  , pattern HipSuccess
  , pattern HipMemcpyDeviceToDevice
  , pattern HipMemcpyDeviceToHost
  , pattern HipMemcpyHostToDevice
  )

-- Memory --------------------------------------------------------------------

hipMallocBytes :: HasCallStack => CSize -> IO (DevicePtr a)
hipMallocBytes bytes =
  alloca $ \pp -> do
    checkHip "hipMalloc" =<< c_hipMalloc pp bytes
    p <- peek pp
    pure (DevicePtr (castPtr p))

-- | Free device memory.
--
-- Note: HIP documents that 'hipFree' may implicitly synchronize.
hipFree :: HasCallStack => DevicePtr a -> IO ()
hipFree (DevicePtr p) = checkHip "hipFree" =<< c_hipFree (castPtr p)

hipHostMallocBytes :: HasCallStack => CSize -> IO (PinnedHostPtr a)
hipHostMallocBytes bytes = hipHostMallocBytesWithFlags bytes HipHostMallocDefault

hipHostMallocBytesWithFlags :: HasCallStack => CSize -> HipHostMallocFlags -> IO (PinnedHostPtr a)
hipHostMallocBytesWithFlags bytes flags =
  alloca $ \pp -> do
    checkHip "hipHostMalloc" =<< c_hipHostMalloc pp bytes flags
    p <- peek pp
    pure (PinnedHostPtr (castPtr p))

hipHostFree :: HasCallStack => PinnedHostPtr a -> IO ()
hipHostFree (PinnedHostPtr p) = checkHip "hipHostFree" =<< c_hipHostFree (castPtr p)

-- Memcpy --------------------------------------------------------------------

hipMemcpy :: HasCallStack => Ptr () -> Ptr () -> CSize -> HipMemcpyKind -> IO ()
hipMemcpy dst src bytes kind = checkHip "hipMemcpy" =<< c_hipMemcpy dst src bytes kind

hipMemcpyAsync :: HasCallStack => Ptr () -> Ptr () -> CSize -> HipMemcpyKind -> HipStream -> IO ()
hipMemcpyAsync dst src bytes kind (HipStream stream) =
  checkHip "hipMemcpyAsync" =<< c_hipMemcpyAsync dst src bytes kind stream

hipMemcpyWithStream :: HasCallStack => Ptr () -> Ptr () -> CSize -> HipMemcpyKind -> HipStream -> IO ()
hipMemcpyWithStream dst src bytes kind (HipStream stream) =
  checkHip "hipMemcpyWithStream" =<< c_hipMemcpyWithStream dst src bytes kind stream

hipMemcpyH2D :: HasCallStack => DevicePtr a -> HostPtr b -> CSize -> IO ()
hipMemcpyH2D (DevicePtr dst) (HostPtr src) bytes =
  checkHip "hipMemcpy(H2D)" =<< c_hipMemcpy (castPtr dst) (castPtr src) bytes HipMemcpyHostToDevice

hipMemcpyD2H :: HasCallStack => HostPtr a -> DevicePtr b -> CSize -> IO ()
hipMemcpyD2H (HostPtr dst) (DevicePtr src) bytes =
  checkHip "hipMemcpy(D2H)" =<< c_hipMemcpy (castPtr dst) (castPtr src) bytes HipMemcpyDeviceToHost

hipMemcpyD2D :: HasCallStack => DevicePtr a -> DevicePtr b -> CSize -> IO ()
hipMemcpyD2D (DevicePtr dst) (DevicePtr src) bytes =
  checkHip "hipMemcpy(D2D)" =<< c_hipMemcpy (castPtr dst) (castPtr src) bytes HipMemcpyDeviceToDevice

hipMemcpyH2DWithStream :: HasCallStack => DevicePtr a -> HostPtr b -> CSize -> HipStream -> IO ()
hipMemcpyH2DWithStream (DevicePtr dst) (HostPtr src) bytes stream =
  hipMemcpyWithStream (castPtr dst) (castPtr src) bytes HipMemcpyHostToDevice stream

hipMemcpyD2HWithStream :: HasCallStack => HostPtr a -> DevicePtr b -> CSize -> HipStream -> IO ()
hipMemcpyD2HWithStream (HostPtr dst) (DevicePtr src) bytes stream =
  hipMemcpyWithStream (castPtr dst) (castPtr src) bytes HipMemcpyDeviceToHost stream

hipMemcpyD2DWithStream :: HasCallStack => DevicePtr a -> DevicePtr b -> CSize -> HipStream -> IO ()
hipMemcpyD2DWithStream (DevicePtr dst) (DevicePtr src) bytes stream =
  hipMemcpyWithStream (castPtr dst) (castPtr src) bytes HipMemcpyDeviceToDevice stream

hipMemcpyH2DAsync :: HasCallStack => DevicePtr a -> PinnedHostPtr b -> CSize -> HipStream -> IO ()
hipMemcpyH2DAsync (DevicePtr dst) (PinnedHostPtr src) bytes stream =
  hipMemcpyAsync (castPtr dst) (castPtr src) bytes HipMemcpyHostToDevice stream

hipMemcpyD2HAsync :: HasCallStack => PinnedHostPtr a -> DevicePtr b -> CSize -> HipStream -> IO ()
hipMemcpyD2HAsync (PinnedHostPtr dst) (DevicePtr src) bytes stream =
  hipMemcpyAsync (castPtr dst) (castPtr src) bytes HipMemcpyDeviceToHost stream

hipMemcpyD2DAsync :: HasCallStack => DevicePtr a -> DevicePtr b -> CSize -> HipStream -> IO ()
hipMemcpyD2DAsync (DevicePtr dst) (DevicePtr src) bytes stream =
  hipMemcpyAsync (castPtr dst) (castPtr src) bytes HipMemcpyDeviceToDevice stream

-- Synchronization -----------------------------------------------------------

hipDeviceSynchronize :: HasCallStack => IO ()
hipDeviceSynchronize = checkHip "hipDeviceSynchronize" =<< c_hipDeviceSynchronize

-- Streams -------------------------------------------------------------------

hipStreamCreate :: HasCallStack => IO HipStream
hipStreamCreate =
  alloca $ \pStream -> do
    checkHip "hipStreamCreate" =<< c_hipStreamCreate pStream
    HipStream <$> peek pStream

hipStreamDestroy :: HasCallStack => HipStream -> IO ()
hipStreamDestroy (HipStream s) = checkHip "hipStreamDestroy" =<< c_hipStreamDestroy s

hipStreamSynchronize :: HasCallStack => HipStream -> IO ()
hipStreamSynchronize (HipStream s) = checkHip "hipStreamSynchronize" =<< c_hipStreamSynchronize s

-- Events --------------------------------------------------------------------

hipEventCreate :: HasCallStack => IO HipEvent
hipEventCreate =
  alloca $ \pEvent -> do
    checkHip "hipEventCreate" =<< c_hipEventCreate pEvent
    HipEvent <$> peek pEvent

hipEventDestroy :: HasCallStack => HipEvent -> IO ()
hipEventDestroy (HipEvent ev) = checkHip "hipEventDestroy" =<< c_hipEventDestroy ev

hipEventRecord :: HasCallStack => HipEvent -> HipStream -> IO ()
hipEventRecord (HipEvent ev) (HipStream stream) =
  checkHip "hipEventRecord" =<< c_hipEventRecord ev stream

hipEventSynchronize :: HasCallStack => HipEvent -> IO ()
hipEventSynchronize (HipEvent ev) = checkHip "hipEventSynchronize" =<< c_hipEventSynchronize ev

hipEventQuery :: HasCallStack => HipEvent -> IO Bool
hipEventQuery (HipEvent ev) = do
  st <- c_hipEventQuery ev
  if st == HipErrorNotReady
    then pure False
    else checkHip "hipEventQuery" st >> pure True

hipEventElapsedTime :: HasCallStack => HipEvent -> HipEvent -> IO Float
hipEventElapsedTime (HipEvent start) (HipEvent stop) =
  alloca $ \pMs -> do
    checkHip "hipEventElapsedTime" =<< c_hipEventElapsedTime pMs start stop
    CFloat ms <- peek pMs
    pure ms

withHipEvent :: HasCallStack => (HipEvent -> IO a) -> IO a
withHipEvent = bracket hipEventCreate hipEventDestroy

-- Callbacks -----------------------------------------------------------------

data HipStreamCallbackPayload = HipStreamCallbackPayload
  { hipStreamCallbackUser :: HipStream -> HipError -> IO ()
  , hipStreamCallbackFunPtr :: FunPtr (Ptr HipStreamTag -> HipError -> Ptr () -> IO ())
  }

hipStreamAddCallback :: HasCallStack => HipStream -> (HipStream -> HipError -> IO ()) -> IO ()
hipStreamAddCallback (HipStream stream) userCb = do
  funPtr <- mkHipStreamCallback hipStreamCallbackEntry
  payloadPtr <- newStablePtr HipStreamCallbackPayload
    { hipStreamCallbackUser = userCb
    , hipStreamCallbackFunPtr = funPtr
    }
  st <- c_hipStreamAddCallback stream funPtr (castStablePtrToPtr payloadPtr) 0
  if st == HipSuccess
    then pure ()
    else do
      freeStablePtr payloadPtr
      freeHaskellFunPtr funPtr
      checkHip "hipStreamAddCallback" st

hipStreamCallbackEntry :: Ptr HipStreamTag -> HipError -> Ptr () -> IO ()
hipStreamCallbackEntry streamPtr status userData = do
  let stable = castPtrToStablePtr userData :: StablePtr HipStreamCallbackPayload
  payload <- deRefStablePtr stable
  result <- try (hipStreamCallbackUser payload (HipStream streamPtr) status) :: IO (Either SomeException ())
  case result of
    Left e -> hPutStrLn stderr ("Exception escaped hipStream callback: " <> displayException e)
    Right () -> pure ()
  freeHaskellFunPtr (hipStreamCallbackFunPtr payload)
  freeStablePtr stable

-- Error state ---------------------------------------------------------------

hipGetLastError :: IO HipError
hipGetLastError = c_hipGetLastError

hipPeekAtLastError :: IO HipError
hipPeekAtLastError = c_hipPeekAtLastError
