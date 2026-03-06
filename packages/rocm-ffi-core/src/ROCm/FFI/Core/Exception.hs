module ROCm.FFI.Core.Exception
  ( FFIError(..)
  , throwFFIError
  , ArgumentError(..)
  , throwArgumentError
  ) where

import Control.Exception (Exception(..), throwIO)
import GHC.Stack (CallStack, HasCallStack, callStack, prettyCallStack)

-- | A structured exception for status-code based C FFI APIs.
--
-- The intent is to surface:
--
-- - which library failed
-- - which C call failed
-- - the numeric status code
-- - the best-effort textual message
-- - a Haskell call stack
--
-- This is meant for low-level bindings where most functions are in @IO@ and
-- failures are expected to be handled via exceptions or explicit status checks.

data FFIError = FFIError
  { ffiLibrary :: !String
  , ffiCall :: !String
  , ffiStatus :: !Int
  , ffiMessage :: !String
  , ffiCallStack :: !String
  }
  deriving (Eq, Show)

instance Exception FFIError where
  displayException e =
    unlines
      [ ffiLibrary e <> ": " <> ffiCall e <> " failed"
      , "status: " <> show (ffiStatus e) <> " (" <> ffiMessage e <> ")"
      , "call stack:\n" <> ffiCallStack e
      ]

throwFFIError :: HasCallStack => String -> String -> Int -> String -> IO a
throwFFIError lib callName status msg =
  throwIO
    FFIError
      { ffiLibrary = lib
      , ffiCall = callName
      , ffiStatus = status
      , ffiMessage = msg
      , ffiCallStack = prettyCallStack (callStack :: CallStack)
      }

-- | Signals incorrect usage of the binding layer (e.g. invalid dimensions,
-- empty buffer list, negative sizes after conversions).
--
-- These are errors we can and should detect before crossing the FFI boundary.

data ArgumentError = ArgumentError
  { argFunction :: !String
  , argMessage :: !String
  , argCallStack :: !String
  }
  deriving (Eq, Show)

instance Exception ArgumentError where
  displayException e =
    unlines
      [ "invalid argument: " <> argFunction e
      , argMessage e
      , "call stack:\n" <> argCallStack e
      ]

throwArgumentError :: HasCallStack => String -> String -> IO a
throwArgumentError fun msg =
  throwIO
    ArgumentError
      { argFunction = fun
      , argMessage = msg
      , argCallStack = prettyCallStack (callStack :: CallStack)
      }
