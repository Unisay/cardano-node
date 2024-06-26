{-# LANGUAGE CPP #-}

#if defined(linux_HOST_OS)
#define LINUX
#endif

#ifdef LINUX
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedStrings #-}
#endif

module Cardano.Tracer.Handlers.Logs.Journal
  ( writeTraceObjectsToJournal
  ) where

#ifdef LINUX
import qualified Cardano.Logging as L
#endif
import           Cardano.Logging (TraceObject (..))
import           Cardano.Tracer.Types (NodeName)

#ifdef LINUX
import           Data.Char (isDigit)
import qualified Data.HashMap.Strict as HM
import qualified Data.Text as T
import           Data.Text.Encoding (encodeUtf8)
import           Data.Time.Format (defaultTimeLocale, formatTime)

import           Systemd.Journal (Priority (..), message, mkJournalField, priority,
                   sendJournalFields, syslogIdentifier)

-- | Store 'TraceObject's in Linux systemd's journal service.
writeTraceObjectsToJournal :: NodeName -> [TraceObject] -> IO ()
writeTraceObjectsToJournal nodeName = mapM_ (sendJournalFields . mkJournalFields)
 where
  mkJournalFields trOb@TraceObject{toHuman, toMachine} =
    case (toHuman, toMachine) of
      (Nothing,          msgForMachine) -> mkJournalFields' trOb msgForMachine
      (Just _,           msgForMachine) -> mkJournalFields' trOb msgForMachine

  mkJournalFields' TraceObject{toSeverity, toNamespace, toThreadId, toTimestamp} msg =
       syslogIdentifier nodeName
    <> message msg
    <> priority (mkPriority toSeverity)
    <> HM.fromList
         [ (namespace, encodeUtf8 $ mkName toNamespace)
         , (thread,    encodeUtf8 $ T.filter isDigit toThreadId)
         , (time,      encodeUtf8 $ formatAsIso8601 toTimestamp)
         ]

  mkName [] = "noname"
  mkName names = T.intercalate "." names

  namespace = mkJournalField "namespace"
  thread    = mkJournalField "thread"
  time      = mkJournalField "time"

  formatAsIso8601 = T.pack . formatTime defaultTimeLocale "%F %T%12QZ"

  mkPriority L.Debug     = Debug
  mkPriority L.Info      = Info
  mkPriority L.Notice    = Notice
  mkPriority L.Warning   = Warning
  mkPriority L.Error     = Error
  mkPriority L.Critical  = Critical
  mkPriority L.Alert     = Alert
  mkPriority L.Emergency = Emergency
#else
-- It works on Linux only.
writeTraceObjectsToJournal :: NodeName -> [TraceObject] -> IO ()
writeTraceObjectsToJournal _ _ = return ()
#endif
