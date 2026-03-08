{-# LANGUAGE PatternSynonyms #-}

module ROCm.HIP
  ( module ROCm.HIP.Types
  , module ROCm.HIP.Device
  , module ROCm.HIP.Error
  , module ROCm.HIP.LaunchConfig
  , module ROCm.HIP.LaunchAttributes
  , module ROCm.HIP.GraphTypes
  , module ROCm.HIP.KernelNodeParams

    -- * Memory
  , hipMallocBytes
  , hipFree
  , hipHostMallocBytes
  , hipHostMallocBytesWithFlags
  , hipHostFree
  , hipHostRegister
  , hipHostUnregister

    -- * Memcpy
  , hipMemcpy
  , hipMemcpyAsync
  , hipMemcpyWithStream
  , hipMemset
  , hipMemsetAsync
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
  , hipDeviceReset

    -- * Device/runtime control
  , hipSetDevice
  , hipRuntimeGetVersion
  , hipDriverGetVersion

    -- * Streams
  , hipStreamCreate
  , hipStreamCreateWithFlags
  , hipStreamCreateWithPriority
  , hipStreamDestroy
  , hipStreamQuery
  , hipStreamSynchronize
  , hipStreamWaitEvent
  , hipStreamBeginCapture
  , hipStreamEndCapture
  , hipStreamGetCaptureInfo
  , hipStreamIsCapturing

    -- * Events
  , hipEventCreate
  , hipEventCreateWithFlags
  , hipEventDestroy
  , hipEventRecord
  , hipEventRecordWithFlags
  , hipEventSynchronize
  , hipEventQuery
  , hipEventElapsedTime
  , withHipEvent

    -- * Callbacks
  , hipStreamAddCallback
  , withHipHostNodeCallback

    -- * Modules
  , hipModuleLoad
  , hipModuleLoadData
  , hipModuleUnload
  , withHipModule
  , withHipModuleData
  , hipModuleGetFunction
  , hipModuleLaunchKernel
  , hipModuleLaunchKernelWithConfigBuffer

    -- * Direct kernel launch
  , hipLaunchKernel
  , hipLaunchKernelExC

    -- * Graphs
  , hipGraphCreate
  , hipGraphDestroy
  , withHipGraph
  , hipGraphInstantiate
  , hipGraphInstantiateWithFlags
  , hipGraphExecDestroy
  , withHipGraphExec
  , withHipGraphExecWithFlags
  , hipGraphLaunch
  , hipGraphAddMemcpyNode1D
  , hipGraphAddKernelNode
  , hipGraphKernelNodeGetParams
  , hipGraphKernelNodeSetParams
  , hipGraphExecKernelNodeSetParams
  , hipGraphKernelNodeSetAttribute
  , hipGraphKernelNodeGetAttribute
  , hipGraphKernelNodeCopyAttributes
  , hipGraphAddHostNode
  , hipGraphHostNodeGetParams
  , hipGraphHostNodeSetParams
  , hipGraphExecHostNodeSetParams
  , hipGraphAddMemsetNode
  , hipGraphMemsetNodeGetParams
  , hipGraphMemsetNodeSetParams
  , hipGraphExecMemsetNodeSetParams
  , hipGraphClone
  , withHipGraphClone
  , hipGraphNodeFindInClone
  , hipGraphExecUpdate
  , hipGraphDebugDotPrint
  , hipGraphAddChildGraphNode
  , hipGraphChildGraphNodeGetGraph
  , hipGraphAddEventRecordNode
  , hipGraphEventRecordNodeGetEvent
  , hipGraphEventRecordNodeSetEvent
  , hipGraphExecEventRecordNodeSetEvent
  , hipGraphAddEventWaitNode
  , hipGraphEventWaitNodeGetEvent
  , hipGraphEventWaitNodeSetEvent
  , hipGraphExecEventWaitNodeSetEvent

    -- * Error state
  , hipGetLastError
  , hipPeekAtLastError
  ) where

import Control.Exception (SomeException, bracket, displayException, try)
import qualified Data.ByteString as BS
import Data.Word (Word32, Word64)
import Foreign.C.String (withCString)
import Foreign.C.Types (CFloat(..), CInt(..), CSize, CUInt(..))
import Foreign.Marshal.Alloc (alloca)
import Foreign.Marshal.Array (withArray)
import Foreign.Marshal.Utils (with)
import Foreign.Ptr (FunPtr, Ptr, WordPtr, castPtr, freeHaskellFunPtr, nullPtr, wordPtrToPtr)
import Foreign.StablePtr (StablePtr, castPtrToStablePtr, castStablePtrToPtr, deRefStablePtr, freeStablePtr, newStablePtr)
import Foreign.Storable (peek, poke)
import GHC.Stack (HasCallStack)
import System.IO (hPutStrLn, stderr)
import ROCm.FFI.Core.Types
  ( DevicePtr(..)
  , HipEvent(..)
  , HipFunction(..)
  , HipGraph(..)
  , HipGraphExec(..)
  , HipGraphNode(..)
  , HipModule(..)
  , HipStream(..)
  , HipStreamTag
  , HostPtr(..)
  , PinnedHostPtr(..)
  )
import ROCm.HIP.Device
import ROCm.HIP.Error (checkHip)
import ROCm.HIP.GraphTypes
import ROCm.HIP.KernelNodeParams
  ( HipKernelNodeParams(..)
  )
import ROCm.HIP.LaunchAttributes
import ROCm.HIP.LaunchConfig
import ROCm.HIP.Raw
  ( c_hipDeviceReset
  , c_hipDeviceSynchronize
  , c_hipLaunchKernel
  , c_hipLaunchKernelExC
  , c_hipDriverGetVersion
  , c_hipEventCreate
  , c_hipEventCreateWithFlags
  , c_hipEventDestroy
  , c_hipEventElapsedTime
  , c_hipEventQuery
  , c_hipEventRecord
  , c_hipEventRecordWithFlags
  , c_hipEventSynchronize
  , c_hipFree
  , c_hipGetLastError
  , c_hipHostFree
  , c_hipHostMalloc
  , c_hipHostRegister
  , c_hipHostUnregister
  , c_hipMalloc
  , c_hipMemcpy
  , c_hipMemcpyAsync
  , c_hipMemcpyWithStream
  , c_hipMemset
  , c_hipMemsetAsync
  , c_hipPeekAtLastError
  , c_hipRuntimeGetVersion
  , c_hipSetDevice
  , c_hipGraphAddChildGraphNode
  , c_hipGraphAddEventRecordNode
  , c_hipGraphAddEventWaitNode
  , c_hipGraphAddHostNode
  , c_hipGraphAddKernelNode
  , c_hipGraphAddMemcpyNode1D
  , c_hipGraphAddMemsetNode
  , c_hipGraphChildGraphNodeGetGraph
  , c_hipGraphClone
  , c_hipGraphCreate
  , c_hipGraphDebugDotPrint
  , c_hipGraphDestroy
  , c_hipGraphEventRecordNodeGetEvent
  , c_hipGraphEventRecordNodeSetEvent
  , c_hipGraphEventWaitNodeGetEvent
  , c_hipGraphEventWaitNodeSetEvent
  , c_hipGraphExecDestroy
  , c_hipGraphExecEventRecordNodeSetEvent
  , c_hipGraphExecEventWaitNodeSetEvent
  , c_hipGraphExecHostNodeSetParams
  , c_hipGraphExecKernelNodeSetParams
  , c_hipGraphExecMemsetNodeSetParams
  , c_hipGraphExecUpdate
  , c_hipGraphHostNodeGetParams
  , c_hipGraphHostNodeSetParams
  , c_hipGraphInstantiate
  , c_hipGraphInstantiateWithFlags
  , c_hipGraphKernelNodeCopyAttributes
  , c_hipGraphKernelNodeGetAttribute
  , c_hipGraphKernelNodeGetParams
  , c_hipGraphKernelNodeSetAttribute
  , c_hipGraphKernelNodeSetParams
  , c_hipGraphLaunch
  , c_hipGraphMemsetNodeGetParams
  , c_hipGraphMemsetNodeSetParams
  , c_hipGraphNodeFindInClone
  , c_hipModuleGetFunction
  , c_hipModuleLaunchKernel
  , c_hipModuleLoad
  , c_hipModuleLoadData
  , c_hipModuleUnload
  , c_hipStreamAddCallback
  , c_hipStreamBeginCapture
  , c_hipStreamCreate
  , c_hipStreamCreateWithFlags
  , c_hipStreamCreateWithPriority
  , c_hipStreamDestroy
  , c_hipStreamEndCapture
  , c_hipStreamGetCaptureInfo
  , c_hipStreamIsCapturing
  , c_hipStreamQuery
  , c_hipStreamSynchronize
  , c_hipStreamWaitEvent
  , mkHipHostNodeCallback
  , mkHipStreamCallback
  )
import ROCm.HIP.Types
  ( HipDim3(..)
  , HipError
  , HipFunctionAddress(..)
  , HipEventFlags
  , HipEventRecordFlags
  , HipHostMallocFlags
  , HipHostRegisterFlags
  , HipMemcpyKind
  , HipStreamFlags
  , pattern HipErrorNotReady
  , pattern HipEventBlockingSync
  , pattern HipEventRecordDefault
  , pattern HipEventRecordExternal
  , pattern HipHostMallocDefault
  , pattern HipHostMallocPortable
  , pattern HipHostRegisterDefault
  , pattern HipHostRegisterMapped
  , pattern HipStreamDefault
  , pattern HipStreamNonBlocking
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

hipHostRegister :: HasCallStack => HostPtr a -> CSize -> HipHostRegisterFlags -> IO ()
hipHostRegister (HostPtr p) bytes flags =
  checkHip "hipHostRegister" =<< c_hipHostRegister (castPtr p) bytes flags

hipHostUnregister :: HasCallStack => HostPtr a -> IO ()
hipHostUnregister (HostPtr p) = checkHip "hipHostUnregister" =<< c_hipHostUnregister (castPtr p)

-- Memcpy --------------------------------------------------------------------

hipMemcpy :: HasCallStack => Ptr () -> Ptr () -> CSize -> HipMemcpyKind -> IO ()
hipMemcpy dst src bytes kind = checkHip "hipMemcpy" =<< c_hipMemcpy dst src bytes kind

hipMemcpyAsync :: HasCallStack => Ptr () -> Ptr () -> CSize -> HipMemcpyKind -> HipStream -> IO ()
hipMemcpyAsync dst src bytes kind (HipStream stream) =
  checkHip "hipMemcpyAsync" =<< c_hipMemcpyAsync dst src bytes kind stream

hipMemcpyWithStream :: HasCallStack => Ptr () -> Ptr () -> CSize -> HipMemcpyKind -> HipStream -> IO ()
hipMemcpyWithStream dst src bytes kind (HipStream stream) =
  checkHip "hipMemcpyWithStream" =<< c_hipMemcpyWithStream dst src bytes kind stream

hipMemset :: HasCallStack => DevicePtr a -> Int -> CSize -> IO ()
hipMemset (DevicePtr dst) value bytes =
  checkHip "hipMemset" =<< c_hipMemset (castPtr dst) (fromIntegral value) bytes

hipMemsetAsync :: HasCallStack => DevicePtr a -> Int -> CSize -> HipStream -> IO ()
hipMemsetAsync (DevicePtr dst) value bytes (HipStream stream) =
  checkHip "hipMemsetAsync" =<< c_hipMemsetAsync (castPtr dst) (fromIntegral value) bytes stream

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

hipDeviceReset :: HasCallStack => IO ()
hipDeviceReset = checkHip "hipDeviceReset" =<< c_hipDeviceReset

hipSetDevice :: HasCallStack => Int -> IO ()
hipSetDevice deviceId = checkHip "hipSetDevice" =<< c_hipSetDevice (fromIntegral deviceId)

hipRuntimeGetVersion :: HasCallStack => IO Int
hipRuntimeGetVersion =
  alloca $ \pVersion -> do
    checkHip "hipRuntimeGetVersion" =<< c_hipRuntimeGetVersion pVersion
    fromIntegral <$> (peek pVersion :: IO CInt)

hipDriverGetVersion :: HasCallStack => IO Int
hipDriverGetVersion =
  alloca $ \pVersion -> do
    checkHip "hipDriverGetVersion" =<< c_hipDriverGetVersion pVersion
    fromIntegral <$> (peek pVersion :: IO CInt)

-- Streams -------------------------------------------------------------------

hipStreamCreate :: HasCallStack => IO HipStream
hipStreamCreate =
  alloca $ \pStream -> do
    checkHip "hipStreamCreate" =<< c_hipStreamCreate pStream
    HipStream <$> peek pStream

hipStreamCreateWithFlags :: HasCallStack => HipStreamFlags -> IO HipStream
hipStreamCreateWithFlags flags =
  alloca $ \pStream -> do
    checkHip "hipStreamCreateWithFlags" =<< c_hipStreamCreateWithFlags pStream flags
    HipStream <$> peek pStream

hipStreamCreateWithPriority :: HasCallStack => HipStreamFlags -> Int -> IO HipStream
hipStreamCreateWithPriority flags priority =
  alloca $ \pStream -> do
    checkHip "hipStreamCreateWithPriority" =<< c_hipStreamCreateWithPriority pStream flags (fromIntegral priority)
    HipStream <$> peek pStream

hipStreamDestroy :: HasCallStack => HipStream -> IO ()
hipStreamDestroy (HipStream s) = checkHip "hipStreamDestroy" =<< c_hipStreamDestroy s

hipStreamQuery :: HasCallStack => HipStream -> IO Bool
hipStreamQuery (HipStream s) = do
  st <- c_hipStreamQuery s
  if st == HipErrorNotReady
    then pure False
    else checkHip "hipStreamQuery" st >> pure True

hipStreamSynchronize :: HasCallStack => HipStream -> IO ()
hipStreamSynchronize (HipStream s) = checkHip "hipStreamSynchronize" =<< c_hipStreamSynchronize s

hipStreamWaitEvent :: HasCallStack => HipStream -> HipEvent -> CUInt -> IO ()
hipStreamWaitEvent (HipStream stream) (HipEvent ev) flags =
  checkHip "hipStreamWaitEvent" =<< c_hipStreamWaitEvent stream ev flags

hipStreamBeginCapture :: HasCallStack => HipStream -> HipStreamCaptureMode -> IO ()
hipStreamBeginCapture (HipStream stream) mode =
  checkHip "hipStreamBeginCapture" =<< c_hipStreamBeginCapture stream (unHipStreamCaptureMode mode)

hipStreamEndCapture :: HasCallStack => HipStream -> IO HipGraph
hipStreamEndCapture (HipStream stream) =
  alloca $ \pGraph -> do
    checkHip "hipStreamEndCapture" =<< c_hipStreamEndCapture stream pGraph
    HipGraph <$> peek pGraph

hipStreamGetCaptureInfo :: HasCallStack => HipStream -> IO (HipStreamCaptureStatus, Word64)
hipStreamGetCaptureInfo (HipStream stream) =
  alloca $ \pStatus ->
    alloca $ \pId -> do
      checkHip "hipStreamGetCaptureInfo" =<< c_hipStreamGetCaptureInfo stream pStatus pId
      status <- peek pStatus
      captureId <- peek pId
      pure (status, captureId)

hipStreamIsCapturing :: HasCallStack => HipStream -> IO HipStreamCaptureStatus
hipStreamIsCapturing (HipStream stream) =
  alloca $ \pStatus -> do
    checkHip "hipStreamIsCapturing" =<< c_hipStreamIsCapturing stream pStatus
    peek pStatus

-- Events --------------------------------------------------------------------

hipEventCreate :: HasCallStack => IO HipEvent
hipEventCreate =
  alloca $ \pEvent -> do
    checkHip "hipEventCreate" =<< c_hipEventCreate pEvent
    HipEvent <$> peek pEvent

hipEventCreateWithFlags :: HasCallStack => HipEventFlags -> IO HipEvent
hipEventCreateWithFlags flags =
  alloca $ \pEvent -> do
    checkHip "hipEventCreateWithFlags" =<< c_hipEventCreateWithFlags pEvent flags
    HipEvent <$> peek pEvent

hipEventDestroy :: HasCallStack => HipEvent -> IO ()
hipEventDestroy (HipEvent ev) = checkHip "hipEventDestroy" =<< c_hipEventDestroy ev

hipEventRecord :: HasCallStack => HipEvent -> HipStream -> IO ()
hipEventRecord (HipEvent ev) (HipStream stream) =
  checkHip "hipEventRecord" =<< c_hipEventRecord ev stream

hipEventRecordWithFlags :: HasCallStack => HipEvent -> HipStream -> HipEventRecordFlags -> IO ()
hipEventRecordWithFlags (HipEvent ev) (HipStream stream) flags =
  checkHip "hipEventRecordWithFlags" =<< c_hipEventRecordWithFlags ev stream flags

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

data HipHostNodeCallbackPayload = HipHostNodeCallbackPayload
  { hipHostNodeCallbackUser :: IO ()
  , hipHostNodeCallbackFunPtr :: FunPtr HipHostNodeFun
  }

withHipHostNodeCallback :: HasCallStack => IO () -> (HipHostNodeParams -> IO a) -> IO a
withHipHostNodeCallback userCb = bracket acquire release
  where
    acquire = do
      funPtr <- mkHipHostNodeCallback hipHostNodeCallbackEntry
      stable <- newStablePtr HipHostNodeCallbackPayload
        { hipHostNodeCallbackUser = userCb
        , hipHostNodeCallbackFunPtr = funPtr
        }
      pure
        HipHostNodeParams
          { hipHostNodeFn = funPtr
          , hipHostNodeUserData = castStablePtrToPtr stable
          }
    release params = do
      freeHaskellFunPtr (hipHostNodeFn params)
      freeStablePtr (castPtrToStablePtr (hipHostNodeUserData params) :: StablePtr HipHostNodeCallbackPayload)

hipHostNodeCallbackEntry :: Ptr () -> IO ()
hipHostNodeCallbackEntry userData = do
  let stable = castPtrToStablePtr userData :: StablePtr HipHostNodeCallbackPayload
  payload <- deRefStablePtr stable
  result <- try (hipHostNodeCallbackUser payload) :: IO (Either SomeException ())
  case result of
    Left e -> hPutStrLn stderr ("Exception escaped hipGraph host node callback: " <> displayException e)
    Right () -> pure ()

-- Modules -------------------------------------------------------------------

hipModuleLoad :: HasCallStack => FilePath -> IO HipModule
hipModuleLoad path =
  alloca $ \pModule ->
    withCString path $ \cPath -> do
      checkHip "hipModuleLoad" =<< c_hipModuleLoad pModule cPath
      HipModule <$> peek pModule

hipModuleLoadData :: HasCallStack => BS.ByteString -> IO HipModule
hipModuleLoadData code =
  alloca $ \pModule ->
    BS.useAsCString code $ \pCode -> do
      checkHip "hipModuleLoadData" =<< c_hipModuleLoadData pModule (castPtr pCode)
      HipModule <$> peek pModule

hipModuleUnload :: HasCallStack => HipModule -> IO ()
hipModuleUnload (HipModule modu) = checkHip "hipModuleUnload" =<< c_hipModuleUnload modu

withHipModule :: HasCallStack => FilePath -> (HipModule -> IO a) -> IO a
withHipModule path = bracket (hipModuleLoad path) hipModuleUnload

withHipModuleData :: HasCallStack => BS.ByteString -> (HipModule -> IO a) -> IO a
withHipModuleData code = bracket (hipModuleLoadData code) hipModuleUnload

hipModuleGetFunction :: HasCallStack => HipModule -> String -> IO HipFunction
hipModuleGetFunction (HipModule modu) name =
  alloca $ \pFunction ->
    withCString name $ \cName -> do
      checkHip "hipModuleGetFunction" =<< c_hipModuleGetFunction pFunction modu cName
      HipFunction <$> peek pFunction

hipModuleLaunchKernel ::
  HasCallStack =>
  HipFunction ->
  HipDim3 ->
  HipDim3 ->
  Word32 ->
  Maybe HipStream ->
  Ptr (Ptr ()) ->
  Ptr (Ptr ()) ->
  IO ()
hipModuleLaunchKernel (HipFunction fun) grid block sharedMemBytes mStream kernelParams extra =
  checkHip "hipModuleLaunchKernel" =<<
    c_hipModuleLaunchKernel
      fun
      (fromIntegral (hipDim3X grid))
      (fromIntegral (hipDim3Y grid))
      (fromIntegral (hipDim3Z grid))
      (fromIntegral (hipDim3X block))
      (fromIntegral (hipDim3Y block))
      (fromIntegral (hipDim3Z block))
      (fromIntegral sharedMemBytes)
      (maybe nullPtr (\(HipStream s) -> s) mStream)
      kernelParams
      extra

hipModuleLaunchKernelWithConfigBuffer ::
  HasCallStack =>
  HipFunction ->
  HipDim3 ->
  HipDim3 ->
  Word32 ->
  Maybe HipStream ->
  Ptr () ->
  CSize ->
  IO ()
hipModuleLaunchKernelWithConfigBuffer fun grid block sharedMemBytes mStream argBuffer argBufferSize =
  alloca $ \pArgBufferSize -> do
    poke pArgBufferSize argBufferSize
    withArray
      [ hipLaunchParamBufferPointer
      , argBuffer
      , hipLaunchParamBufferSize
      , castPtr pArgBufferSize
      , hipLaunchParamEnd
      ]
      $ \pExtra ->
        hipModuleLaunchKernel fun grid block sharedMemBytes mStream nullPtr pExtra

hipLaunchParamBufferPointer :: Ptr ()
hipLaunchParamBufferPointer = wordPtrToPtr (0x01 :: WordPtr)

hipLaunchParamBufferSize :: Ptr ()
hipLaunchParamBufferSize = wordPtrToPtr (0x02 :: WordPtr)

hipLaunchParamEnd :: Ptr ()
hipLaunchParamEnd = wordPtrToPtr (0x03 :: WordPtr)

-- Direct kernel launch -------------------------------------------------------

hipLaunchKernel ::
  HasCallStack =>
  HipFunctionAddress ->
  HipDim3 ->
  HipDim3 ->
  Ptr (Ptr ()) ->
  Word32 ->
  Maybe HipStream ->
  IO ()
hipLaunchKernel functionAddress grid block kernelParams sharedMemBytes mStream =
  checkHip "hipLaunchKernel" =<<
    c_hipLaunchKernel
      functionAddress
      (fromIntegral (hipDim3X grid))
      (fromIntegral (hipDim3Y grid))
      (fromIntegral (hipDim3Z grid))
      (fromIntegral (hipDim3X block))
      (fromIntegral (hipDim3Y block))
      (fromIntegral (hipDim3Z block))
      kernelParams
      (fromIntegral sharedMemBytes)
      (maybe nullPtr (\(HipStream s) -> s) mStream)

hipLaunchKernelExC ::
  HasCallStack =>
  HipLaunchConfig ->
  HipFunctionAddress ->
  Ptr (Ptr ()) ->
  IO ()
hipLaunchKernelExC config functionAddress kernelParams =
  with config $ \pConfig ->
    checkHip "hipLaunchKernelExC" =<< c_hipLaunchKernelExC pConfig functionAddress kernelParams

-- Graphs --------------------------------------------------------------------

hipGraphCreate :: HasCallStack => Word32 -> IO HipGraph
hipGraphCreate flags =
  alloca $ \pGraph -> do
    checkHip "hipGraphCreate" =<< c_hipGraphCreate pGraph (fromIntegral flags)
    HipGraph <$> peek pGraph

hipGraphDestroy :: HasCallStack => HipGraph -> IO ()
hipGraphDestroy (HipGraph graph) = checkHip "hipGraphDestroy" =<< c_hipGraphDestroy graph

withHipGraph :: HasCallStack => Word32 -> (HipGraph -> IO a) -> IO a
withHipGraph flags = bracket (hipGraphCreate flags) hipGraphDestroy

hipGraphInstantiate :: HasCallStack => HipGraph -> IO HipGraphExec
hipGraphInstantiate (HipGraph graph) =
  alloca $ \pExec -> do
    checkHip "hipGraphInstantiate" =<< c_hipGraphInstantiate pExec graph nullPtr nullPtr 0
    HipGraphExec <$> peek pExec

hipGraphInstantiateWithFlags :: HasCallStack => HipGraph -> HipGraphInstantiateFlags -> IO HipGraphExec
hipGraphInstantiateWithFlags (HipGraph graph) flags =
  alloca $ \pExec -> do
    checkHip "hipGraphInstantiateWithFlags" =<< c_hipGraphInstantiateWithFlags pExec graph (unHipGraphInstantiateFlags flags)
    HipGraphExec <$> peek pExec

hipGraphExecDestroy :: HasCallStack => HipGraphExec -> IO ()
hipGraphExecDestroy (HipGraphExec execGraph) = checkHip "hipGraphExecDestroy" =<< c_hipGraphExecDestroy execGraph

withHipGraphExec :: HasCallStack => HipGraph -> (HipGraphExec -> IO a) -> IO a
withHipGraphExec graph = bracket (hipGraphInstantiate graph) hipGraphExecDestroy

withHipGraphExecWithFlags :: HasCallStack => HipGraph -> HipGraphInstantiateFlags -> (HipGraphExec -> IO a) -> IO a
withHipGraphExecWithFlags graph flags = bracket (hipGraphInstantiateWithFlags graph flags) hipGraphExecDestroy

hipGraphLaunch :: HasCallStack => HipGraphExec -> HipStream -> IO ()
hipGraphLaunch (HipGraphExec execGraph) (HipStream stream) =
  checkHip "hipGraphLaunch" =<< c_hipGraphLaunch execGraph stream

hipGraphAddMemcpyNode1D ::
  HasCallStack =>
  HipGraph ->
  [HipGraphNode] ->
  Ptr () ->
  Ptr () ->
  CSize ->
  HipMemcpyKind ->
  IO HipGraphNode
hipGraphAddMemcpyNode1D (HipGraph graph) deps dst src bytes kind =
  alloca $ \pNode ->
    withGraphDependencies deps $ \pDeps depCount -> do
      checkHip "hipGraphAddMemcpyNode1D" =<< c_hipGraphAddMemcpyNode1D pNode graph pDeps depCount dst src bytes kind
      HipGraphNode <$> peek pNode

hipGraphAddKernelNode ::
  HasCallStack =>
  HipGraph ->
  [HipGraphNode] ->
  HipKernelNodeParams ->
  IO HipGraphNode
hipGraphAddKernelNode (HipGraph graph) deps params =
  alloca $ \pNode ->
    withGraphDependencies deps $ \pDeps depCount ->
      with params $ \pParams -> do
        checkHip "hipGraphAddKernelNode" =<< c_hipGraphAddKernelNode pNode graph pDeps depCount pParams
        HipGraphNode <$> peek pNode

hipGraphKernelNodeGetParams :: HasCallStack => HipGraphNode -> IO HipKernelNodeParams
hipGraphKernelNodeGetParams (HipGraphNode node) =
  alloca $ \pParams -> do
    checkHip "hipGraphKernelNodeGetParams" =<< c_hipGraphKernelNodeGetParams node pParams
    peek pParams

hipGraphKernelNodeSetParams :: HasCallStack => HipGraphNode -> HipKernelNodeParams -> IO ()
hipGraphKernelNodeSetParams (HipGraphNode node) params =
  with params $ \pParams ->
    checkHip "hipGraphKernelNodeSetParams" =<< c_hipGraphKernelNodeSetParams node pParams

hipGraphExecKernelNodeSetParams :: HasCallStack => HipGraphExec -> HipGraphNode -> HipKernelNodeParams -> IO ()
hipGraphExecKernelNodeSetParams (HipGraphExec execGraph) (HipGraphNode node) params =
  with params $ \pParams ->
    checkHip "hipGraphExecKernelNodeSetParams" =<< c_hipGraphExecKernelNodeSetParams execGraph node pParams

hipGraphKernelNodeSetAttribute :: HasCallStack => HipGraphNode -> HipLaunchAttributeID -> HipLaunchAttributeValue -> IO ()
hipGraphKernelNodeSetAttribute (HipGraphNode node) attrId value =
  withHipLaunchAttributeValue attrId value $ \pValue ->
    checkHip "hipGraphKernelNodeSetAttribute" =<< c_hipGraphKernelNodeSetAttribute node (unHipLaunchAttributeID attrId) pValue

hipGraphKernelNodeGetAttribute :: HasCallStack => HipGraphNode -> HipLaunchAttributeID -> IO HipLaunchAttributeValue
hipGraphKernelNodeGetAttribute (HipGraphNode node) attrId =
  withHipLaunchAttributeValue attrId (defaultHipLaunchAttributeValue attrId) $ \pValue -> do
    checkHip "hipGraphKernelNodeGetAttribute" =<< c_hipGraphKernelNodeGetAttribute node (unHipLaunchAttributeID attrId) pValue
    peekHipLaunchAttributeValue attrId pValue

hipGraphKernelNodeCopyAttributes :: HasCallStack => HipGraphNode -> HipGraphNode -> IO ()
hipGraphKernelNodeCopyAttributes (HipGraphNode src) (HipGraphNode dst) =
  checkHip "hipGraphKernelNodeCopyAttributes" =<< c_hipGraphKernelNodeCopyAttributes src dst

hipGraphAddHostNode ::
  HasCallStack =>
  HipGraph ->
  [HipGraphNode] ->
  HipHostNodeParams ->
  IO HipGraphNode
hipGraphAddHostNode (HipGraph graph) deps params =
  alloca $ \pNode ->
    withGraphDependencies deps $ \pDeps depCount ->
      with params $ \pParams -> do
        checkHip "hipGraphAddHostNode" =<< c_hipGraphAddHostNode pNode graph pDeps depCount pParams
        HipGraphNode <$> peek pNode

hipGraphHostNodeGetParams :: HasCallStack => HipGraphNode -> IO HipHostNodeParams
hipGraphHostNodeGetParams (HipGraphNode node) =
  alloca $ \pParams -> do
    checkHip "hipGraphHostNodeGetParams" =<< c_hipGraphHostNodeGetParams node pParams
    peek pParams

hipGraphHostNodeSetParams :: HasCallStack => HipGraphNode -> HipHostNodeParams -> IO ()
hipGraphHostNodeSetParams (HipGraphNode node) params =
  with params $ \pParams ->
    checkHip "hipGraphHostNodeSetParams" =<< c_hipGraphHostNodeSetParams node pParams

hipGraphExecHostNodeSetParams :: HasCallStack => HipGraphExec -> HipGraphNode -> HipHostNodeParams -> IO ()
hipGraphExecHostNodeSetParams (HipGraphExec execGraph) (HipGraphNode node) params =
  with params $ \pParams ->
    checkHip "hipGraphExecHostNodeSetParams" =<< c_hipGraphExecHostNodeSetParams execGraph node pParams

hipGraphAddMemsetNode ::
  HasCallStack =>
  HipGraph ->
  [HipGraphNode] ->
  HipMemsetParams ->
  IO HipGraphNode
hipGraphAddMemsetNode (HipGraph graph) deps params =
  alloca $ \pNode ->
    withGraphDependencies deps $ \pDeps depCount ->
      with params $ \pParams -> do
        checkHip "hipGraphAddMemsetNode" =<< c_hipGraphAddMemsetNode pNode graph pDeps depCount pParams
        HipGraphNode <$> peek pNode

hipGraphMemsetNodeGetParams :: HasCallStack => HipGraphNode -> IO HipMemsetParams
hipGraphMemsetNodeGetParams (HipGraphNode node) =
  alloca $ \pParams -> do
    checkHip "hipGraphMemsetNodeGetParams" =<< c_hipGraphMemsetNodeGetParams node pParams
    peek pParams

hipGraphMemsetNodeSetParams :: HasCallStack => HipGraphNode -> HipMemsetParams -> IO ()
hipGraphMemsetNodeSetParams (HipGraphNode node) params =
  with params $ \pParams ->
    checkHip "hipGraphMemsetNodeSetParams" =<< c_hipGraphMemsetNodeSetParams node pParams

hipGraphExecMemsetNodeSetParams :: HasCallStack => HipGraphExec -> HipGraphNode -> HipMemsetParams -> IO ()
hipGraphExecMemsetNodeSetParams (HipGraphExec execGraph) (HipGraphNode node) params =
  with params $ \pParams ->
    checkHip "hipGraphExecMemsetNodeSetParams" =<< c_hipGraphExecMemsetNodeSetParams execGraph node pParams

hipGraphClone :: HasCallStack => HipGraph -> IO HipGraph
hipGraphClone (HipGraph graph) =
  alloca $ \pGraphClone -> do
    checkHip "hipGraphClone" =<< c_hipGraphClone pGraphClone graph
    HipGraph <$> peek pGraphClone

withHipGraphClone :: HasCallStack => HipGraph -> (HipGraph -> IO a) -> IO a
withHipGraphClone graph = bracket (hipGraphClone graph) hipGraphDestroy

hipGraphNodeFindInClone :: HasCallStack => HipGraphNode -> HipGraph -> IO HipGraphNode
hipGraphNodeFindInClone (HipGraphNode originalNode) (HipGraph graphClone) =
  alloca $ \pNode -> do
    checkHip "hipGraphNodeFindInClone" =<< c_hipGraphNodeFindInClone pNode originalNode graphClone
    HipGraphNode <$> peek pNode

hipGraphExecUpdate :: HasCallStack => HipGraphExec -> HipGraph -> IO HipGraphExecUpdateInfo
hipGraphExecUpdate (HipGraphExec execGraph) (HipGraph graph) =
  alloca $ \pErrorNode ->
    alloca $ \pUpdateResult -> do
      checkHip "hipGraphExecUpdate" =<< c_hipGraphExecUpdate execGraph graph pErrorNode pUpdateResult
      errorNodePtr <- peek pErrorNode
      updateResult <- peek pUpdateResult
      pure
        HipGraphExecUpdateInfo
          { hipGraphExecUpdateErrorNode = if errorNodePtr == nullPtr then Nothing else Just (HipGraphNode errorNodePtr)
          , hipGraphExecUpdateResult = updateResult
          }

hipGraphDebugDotPrint :: HasCallStack => HipGraph -> FilePath -> HipGraphDebugDotFlags -> IO ()
hipGraphDebugDotPrint (HipGraph graph) path flags =
  withCString path $ \cPath ->
    checkHip "hipGraphDebugDotPrint" =<< c_hipGraphDebugDotPrint graph cPath (unHipGraphDebugDotFlags flags)

hipGraphAddChildGraphNode ::
  HasCallStack =>
  HipGraph ->
  [HipGraphNode] ->
  HipGraph ->
  IO HipGraphNode
hipGraphAddChildGraphNode (HipGraph graph) deps (HipGraph childGraph) =
  alloca $ \pNode ->
    withGraphDependencies deps $ \pDeps depCount -> do
      checkHip "hipGraphAddChildGraphNode" =<< c_hipGraphAddChildGraphNode pNode graph pDeps depCount childGraph
      HipGraphNode <$> peek pNode

hipGraphChildGraphNodeGetGraph :: HasCallStack => HipGraphNode -> IO HipGraph
hipGraphChildGraphNodeGetGraph (HipGraphNode node) =
  alloca $ \pGraph -> do
    checkHip "hipGraphChildGraphNodeGetGraph" =<< c_hipGraphChildGraphNodeGetGraph node pGraph
    HipGraph <$> peek pGraph

hipGraphAddEventRecordNode ::
  HasCallStack =>
  HipGraph ->
  [HipGraphNode] ->
  HipEvent ->
  IO HipGraphNode
hipGraphAddEventRecordNode (HipGraph graph) deps (HipEvent event) =
  alloca $ \pNode ->
    withGraphDependencies deps $ \pDeps depCount -> do
      checkHip "hipGraphAddEventRecordNode" =<< c_hipGraphAddEventRecordNode pNode graph pDeps depCount event
      HipGraphNode <$> peek pNode

hipGraphEventRecordNodeGetEvent :: HasCallStack => HipGraphNode -> IO HipEvent
hipGraphEventRecordNodeGetEvent (HipGraphNode node) =
  alloca $ \pEvent -> do
    checkHip "hipGraphEventRecordNodeGetEvent" =<< c_hipGraphEventRecordNodeGetEvent node pEvent
    HipEvent <$> peek pEvent

hipGraphEventRecordNodeSetEvent :: HasCallStack => HipGraphNode -> HipEvent -> IO ()
hipGraphEventRecordNodeSetEvent (HipGraphNode node) (HipEvent event) =
  checkHip "hipGraphEventRecordNodeSetEvent" =<< c_hipGraphEventRecordNodeSetEvent node event

hipGraphExecEventRecordNodeSetEvent :: HasCallStack => HipGraphExec -> HipGraphNode -> HipEvent -> IO ()
hipGraphExecEventRecordNodeSetEvent (HipGraphExec execGraph) (HipGraphNode node) (HipEvent event) =
  checkHip "hipGraphExecEventRecordNodeSetEvent" =<< c_hipGraphExecEventRecordNodeSetEvent execGraph node event

hipGraphAddEventWaitNode ::
  HasCallStack =>
  HipGraph ->
  [HipGraphNode] ->
  HipEvent ->
  IO HipGraphNode
hipGraphAddEventWaitNode (HipGraph graph) deps (HipEvent event) =
  alloca $ \pNode ->
    withGraphDependencies deps $ \pDeps depCount -> do
      checkHip "hipGraphAddEventWaitNode" =<< c_hipGraphAddEventWaitNode pNode graph pDeps depCount event
      HipGraphNode <$> peek pNode

hipGraphEventWaitNodeGetEvent :: HasCallStack => HipGraphNode -> IO HipEvent
hipGraphEventWaitNodeGetEvent (HipGraphNode node) =
  alloca $ \pEvent -> do
    checkHip "hipGraphEventWaitNodeGetEvent" =<< c_hipGraphEventWaitNodeGetEvent node pEvent
    HipEvent <$> peek pEvent

hipGraphEventWaitNodeSetEvent :: HasCallStack => HipGraphNode -> HipEvent -> IO ()
hipGraphEventWaitNodeSetEvent (HipGraphNode node) (HipEvent event) =
  checkHip "hipGraphEventWaitNodeSetEvent" =<< c_hipGraphEventWaitNodeSetEvent node event

hipGraphExecEventWaitNodeSetEvent :: HasCallStack => HipGraphExec -> HipGraphNode -> HipEvent -> IO ()
hipGraphExecEventWaitNodeSetEvent (HipGraphExec execGraph) (HipGraphNode node) (HipEvent event) =
  checkHip "hipGraphExecEventWaitNodeSetEvent" =<< c_hipGraphExecEventWaitNodeSetEvent execGraph node event

withGraphDependencies :: [HipGraphNode] -> (Ptr (Ptr tag) -> CSize -> IO a) -> IO a
withGraphDependencies [] k = k nullPtr 0
withGraphDependencies deps k =
  withArray (map (\(HipGraphNode p) -> castPtr p) deps) $ \pDeps ->
    k pDeps (fromIntegral (length deps))

defaultHipLaunchAttributeValue :: HipLaunchAttributeID -> HipLaunchAttributeValue
defaultHipLaunchAttributeValue attrId
  | attrId == HipLaunchAttributeCooperative = HipLaunchAttributeValueCooperative False
  | attrId == HipLaunchAttributePriority = HipLaunchAttributeValuePriority 0
  | otherwise = error ("Unsupported hipLaunchAttributeID in defaultHipLaunchAttributeValue: " <> show attrId)

-- Error state ---------------------------------------------------------------

hipGetLastError :: IO HipError
hipGetLastError = c_hipGetLastError

hipPeekAtLastError :: IO HipError
hipPeekAtLastError = c_hipPeekAtLastError
