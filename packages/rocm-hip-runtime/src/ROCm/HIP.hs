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

    -- * Modules
  , hipModuleLoad
  , hipModuleLoadData
  , hipModuleUnload
  , withHipModule
  , withHipModuleData
  , hipModuleGetFunction
  , hipModuleLaunchKernel
  , hipModuleLaunchKernelWithConfigBuffer

    -- * Graphs
  , hipGraphCreate
  , hipGraphDestroy
  , withHipGraph
  , hipGraphInstantiate
  , hipGraphExecDestroy
  , withHipGraphExec
  , hipGraphLaunch
  , hipGraphAddMemcpyNode1D

    -- * Error state
  , hipGetLastError
  , hipPeekAtLastError
  ) where

import Control.Exception (SomeException, bracket, displayException, try)
import qualified Data.ByteString as BS
import Data.Word (Word32)
import Foreign.C.String (withCString)
import Foreign.C.Types (CFloat(..), CInt(..), CSize, CUInt(..))
import Foreign.Marshal.Alloc (alloca)
import Foreign.Marshal.Array (withArray)
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
import ROCm.HIP.Raw
  ( c_hipDeviceReset
  , c_hipDeviceSynchronize
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
  , c_hipGraphAddMemcpyNode1D
  , c_hipGraphCreate
  , c_hipGraphDestroy
  , c_hipGraphExecDestroy
  , c_hipGraphInstantiate
  , c_hipGraphLaunch
  , c_hipModuleGetFunction
  , c_hipModuleLaunchKernel
  , c_hipModuleLoad
  , c_hipModuleLoadData
  , c_hipModuleUnload
  , c_hipStreamAddCallback
  , c_hipStreamCreate
  , c_hipStreamCreateWithFlags
  , c_hipStreamCreateWithPriority
  , c_hipStreamDestroy
  , c_hipStreamQuery
  , c_hipStreamSynchronize
  , c_hipStreamWaitEvent
  , mkHipStreamCallback
  )
import ROCm.HIP.Types
  ( HipDim3(..)
  , HipError
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

hipGraphExecDestroy :: HasCallStack => HipGraphExec -> IO ()
hipGraphExecDestroy (HipGraphExec execGraph) = checkHip "hipGraphExecDestroy" =<< c_hipGraphExecDestroy execGraph

withHipGraphExec :: HasCallStack => HipGraph -> (HipGraphExec -> IO a) -> IO a
withHipGraphExec graph = bracket (hipGraphInstantiate graph) hipGraphExecDestroy

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

withGraphDependencies :: [HipGraphNode] -> (Ptr (Ptr tag) -> CSize -> IO a) -> IO a
withGraphDependencies [] k = k nullPtr 0
withGraphDependencies deps k =
  withArray (map (\(HipGraphNode p) -> castPtr p) deps) $ \pDeps ->
    k pDeps (fromIntegral (length deps))

-- Error state ---------------------------------------------------------------

hipGetLastError :: IO HipError
hipGetLastError = c_hipGetLastError

hipPeekAtLastError :: IO HipError
hipPeekAtLastError = c_hipPeekAtLastError
