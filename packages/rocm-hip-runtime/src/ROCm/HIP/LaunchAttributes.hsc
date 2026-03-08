{-# LANGUAGE CPP #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE PatternSynonyms #-}

module ROCm.HIP.LaunchAttributes
  ( HipLaunchAttributeID(..)
  , HipLaunchAttributeStorage
  , pattern HipLaunchAttributeCooperative
  , pattern HipLaunchAttributePriority
  , HipLaunchAttributeValue(..)
  , HipLaunchAttribute(..)
  , hipLaunchAttributeCooperative
  , hipLaunchAttributePriority
  , withHipLaunchAttributes
  , withHipLaunchAttributeValue
  , peekHipLaunchAttributeValue
  ) where

#include <hip/hip_runtime_api.h>

import Data.Word (Word32)
import Foreign.C.Types (CInt)
import Foreign.Marshal.Alloc (allocaBytes)
import Foreign.Marshal.Array (withArray)
import Foreign.Marshal.Utils (copyBytes, fillBytes)
import Foreign.Ptr (Ptr, castPtr, nullPtr, plusPtr)
import Foreign.Storable (Storable(..), peekByteOff, pokeByteOff)

newtype HipLaunchAttributeID = HipLaunchAttributeID {unHipLaunchAttributeID :: CInt}
  deriving newtype (Eq, Ord, Show, Storable)

pattern HipLaunchAttributeCooperative :: HipLaunchAttributeID
pattern HipLaunchAttributeCooperative = HipLaunchAttributeID #{const hipLaunchAttributeCooperative}

pattern HipLaunchAttributePriority :: HipLaunchAttributeID
pattern HipLaunchAttributePriority = HipLaunchAttributeID #{const hipLaunchAttributePriority}

data HipLaunchAttributeStorage

data HipLaunchAttributeValue
  = HipLaunchAttributeValueCooperative !Bool
  | HipLaunchAttributeValuePriority !Int
  deriving stock (Eq, Show)

data HipLaunchAttribute = HipLaunchAttribute
  { hipLaunchAttributeId :: !HipLaunchAttributeID
  , hipLaunchAttributeValue :: !HipLaunchAttributeValue
  }
  deriving stock (Eq, Show)

hipLaunchAttributeCooperative :: Bool -> HipLaunchAttribute
hipLaunchAttributeCooperative enabled =
  HipLaunchAttribute HipLaunchAttributeCooperative (HipLaunchAttributeValueCooperative enabled)

hipLaunchAttributePriority :: Int -> HipLaunchAttribute
hipLaunchAttributePriority prio =
  HipLaunchAttribute HipLaunchAttributePriority (HipLaunchAttributeValuePriority prio)

instance Storable HipLaunchAttribute where
  sizeOf _ = #{size hipLaunchAttribute}
  alignment _ = #{alignment hipLaunchAttribute}

  peek p = do
    attrId <- peekByteOff p #{offset hipLaunchAttribute, id}
    value <- peekHipLaunchAttributeValue attrId (plusValuePtr p)
    pure HipLaunchAttribute {hipLaunchAttributeId = attrId, hipLaunchAttributeValue = value}

  poke p attr = do
    fillBytes p 0 (sizeOf attr)
    pokeByteOff p #{offset hipLaunchAttribute, id} (hipLaunchAttributeId attr)
    withHipLaunchAttributeValue (hipLaunchAttributeId attr) (hipLaunchAttributeValue attr) $ \pValue ->
      copyValueBytes (plusValuePtr p) pValue

withHipLaunchAttributes :: [HipLaunchAttribute] -> (Ptr HipLaunchAttribute -> Word32 -> IO a) -> IO a
withHipLaunchAttributes [] k = k nullPtr 0
withHipLaunchAttributes attrs k =
  withArray attrs $ \pAttrs ->
    k pAttrs (fromIntegral (length attrs))

withHipLaunchAttributeValue :: HipLaunchAttributeID -> HipLaunchAttributeValue -> (Ptr HipLaunchAttributeStorage -> IO a) -> IO a
withHipLaunchAttributeValue attrId value k =
  allocaBytes #{size hipLaunchAttributeValue} $ \pValue -> do
    fillBytes pValue 0 #{size hipLaunchAttributeValue}
    pokeValue attrId value pValue
    k pValue

peekHipLaunchAttributeValue :: HipLaunchAttributeID -> Ptr HipLaunchAttributeStorage -> IO HipLaunchAttributeValue
peekHipLaunchAttributeValue attrId pValue
  | attrId == HipLaunchAttributeCooperative = do
      cooperative <- peekByteOff pValue #{offset hipLaunchAttributeValue, cooperative} :: IO CInt
      pure (HipLaunchAttributeValueCooperative (cooperative /= 0))
  | attrId == HipLaunchAttributePriority = do
      priority <- peekByteOff pValue #{offset hipLaunchAttributeValue, priority} :: IO CInt
      pure (HipLaunchAttributeValuePriority (fromIntegral priority))
  | otherwise =
      fail ("Unsupported hipLaunchAttributeID in peekHipLaunchAttributeValue: " <> show attrId)

pokeValue :: HipLaunchAttributeID -> HipLaunchAttributeValue -> Ptr HipLaunchAttributeStorage -> IO ()
pokeValue attrId value pValue
  | attrId == HipLaunchAttributeCooperative =
      case value of
        HipLaunchAttributeValueCooperative enabled ->
          pokeByteOff pValue #{offset hipLaunchAttributeValue, cooperative} (if enabled then (1 :: CInt) else 0)
        _ -> fail mismatched
  | attrId == HipLaunchAttributePriority =
      case value of
        HipLaunchAttributeValuePriority prio ->
          pokeByteOff pValue #{offset hipLaunchAttributeValue, priority} (fromIntegral prio :: CInt)
        _ -> fail mismatched
  | otherwise =
      fail ("Unsupported hipLaunchAttributeID in pokeValue: " <> show attrId)
  where
    mismatched =
      "Mismatched hipLaunchAttributeID/value pair: id="
        <> show attrId
        <> ", value="
        <> show value

plusValuePtr :: Ptr HipLaunchAttribute -> Ptr HipLaunchAttributeStorage
plusValuePtr p = castPtr (p `plusPtr` #{offset hipLaunchAttribute, value})

copyValueBytes :: Ptr HipLaunchAttributeStorage -> Ptr HipLaunchAttributeStorage -> IO ()
copyValueBytes dst src =
  copyBytes dst src #{size hipLaunchAttributeValue}
