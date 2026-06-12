#ifndef __MOHY_RUNTIME_LOGGER_MQH__
#define __MOHY_RUNTIME_LOGGER_MQH__

#include <MOHY/Runtime/RuntimeCommon.mqh>
#include <MOHY/Domain/Contracts.mqh>

class CMohyRuntimeLogger
  {
private:
   string m_scope_tag;
   long   m_chart_id;
   long   m_next_sequence;
   long   m_next_lifecycle_sequence;

   string EventsPath() const
     {
     return MohyRuntimeBuildRuntimePath(m_scope_tag, "engine_events.csv");
     }

   string LifecycleEventsPath() const
     {
      return MohyRuntimeBuildRuntimePath(m_scope_tag, "lifecycle_events.csv");
     }

   void     SkipFields(const int handle,
                       const int count)
     {
      for(int i = 0; i < count && !FileIsEnding(handle); ++i)
         FileReadString(handle);
     }

   long     ResolveLastSequenceForPath(const string path,
                                       const int trailing_fields)
     {
      if(m_scope_tag == "")
         return 0;
      if(!FileIsExist(path))
         return 0;

      const int handle = FileOpen(path, FILE_READ | FILE_CSV | FILE_ANSI, ',');
      if(handle == INVALID_HANDLE)
         return 0;

      long last_sequence = 0;
      while(!FileIsEnding(handle))
        {
         const string schema = FileReadString(handle);
         if(schema == "")
            break;

         const string sequence_text = !FileIsEnding(handle) ? FileReadString(handle) : "0";
         if(schema != "schema_version")
            last_sequence = (long)StringToInteger(sequence_text);

         SkipFields(handle, trailing_fields);
        }

      FileClose(handle);
      return last_sequence;
     }

   long     ResolveLastSequence()
     {
      return ResolveLastSequenceForPath(EventsPath(), 22);
     }

   long     NextSequence()
     {
      if(m_next_sequence <= 0)
         m_next_sequence = ResolveLastSequence();
      m_next_sequence++;
      return m_next_sequence;
     }

   long     NextLifecycleSequence()
     {
      if(m_next_lifecycle_sequence <= 0)
         m_next_lifecycle_sequence = ResolveLastSequenceForPath(LifecycleEventsPath(), 33);
      m_next_lifecycle_sequence++;
      return m_next_lifecycle_sequence;
     }

public:
            CMohyRuntimeLogger()
              {
               m_scope_tag = "";
               m_chart_id = 0;
               m_next_sequence = 0;
               m_next_lifecycle_sequence = 0;
              }

   void     Configure(const string scope_tag,
                      const long chart_id)
     {
      m_scope_tag = MohyRuntimeSanitizeToken(scope_tag);
      m_chart_id = chart_id;
      m_next_sequence = 0;
      m_next_lifecycle_sequence = 0;
     }

   bool     LogEvent(const StrategyConfig &cfg,
                     const string symbol,
                     const string setup_key,
                     const string impulse_id,
                     const MohyDirection direction,
                     const MohySetupPhase setup_phase,
                     const MohyTradePhase trade_phase,
                     const MohyEngineEventType event_type,
                     const string reason_code,
                     const datetime time_a,
                     const datetime time_b,
                     const double price_a,
                     const double price_b,
                     const double rr_value,
                     const string diagnostics,
                     const string source)
     {
      if(m_scope_tag == "")
         return false;
      if(!MohyRuntimeEnsureDirectory(MohyRuntimeBuildRuntimeDirectory(m_scope_tag)))
         return false;

      const string path = EventsPath();
      const bool exists = FileIsExist(path);
      const int handle = FileOpen(path,
                                  FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI,
                                  ',');
      if(handle == INVALID_HANDLE)
         return false;

      if(!exists)
        {
         FileWrite(handle,
                   "schema_version",
                   "sequence_no",
                   "timestamp",
                   "chart_id",
                   "symbol",
                   "context_timeframe",
                   "execution_timeframe",
                   "scope_tag",
                   "config_hash",
                   "config_layers",
                   "setup_key",
                   "impulse_id",
                   "direction",
                   "setup_phase",
                   "trade_phase",
                   "event_type",
                   "reason_code",
                   "time_a",
                   "time_b",
                   "price_a",
                   "price_b",
                   "rr_value",
                   "diagnostics",
                   "source");
        }
      else
         FileSeek(handle, 0, SEEK_END);

      const long sequence_no = NextSequence();
      FileWrite(handle,
                "runtime_v1",
                IntegerToString((int)sequence_no),
                IntegerToString((int)TimeCurrent()),
                IntegerToString((int)m_chart_id),
                symbol,
                MohyTimeframeToString(cfg.context_timeframe),
                MohyTimeframeToString(cfg.execution_timeframe),
                m_scope_tag,
                MohyRuntimeBuildConfigHash(cfg),
                "inputs",
                setup_key,
                impulse_id,
                MohyDirectionToString(direction),
                MohySetupPhaseToString(setup_phase),
                MohyTradePhaseToString(trade_phase),
                MohyEngineEventTypeToString(event_type),
                reason_code,
                IntegerToString((int)time_a),
                IntegerToString((int)time_b),
                DoubleToString(price_a, 10),
                DoubleToString(price_b, 10),
                DoubleToString(rr_value, 10),
                diagnostics,
                source);
      FileClose(handle);
      return true;
     }

   bool     LogLifecycleRecord(const StrategyConfig &cfg,
                               const MohyRuntimeLifecycleRecord &record,
                               const string source)
     {
      if(m_scope_tag == "" || record.setup_key == "")
         return false;
      if(!MohyRuntimeEnsureDirectory(MohyRuntimeBuildRuntimeDirectory(m_scope_tag)))
         return false;

      const string path = LifecycleEventsPath();
      const bool exists = FileIsExist(path);
      const int handle = FileOpen(path,
                                  FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI,
                                  ',');
      if(handle == INVALID_HANDLE)
         return false;

      if(!exists)
        {
         FileWrite(handle,
                   "schema_version",
                   "sequence_no",
                   "timestamp",
                   "chart_id",
                   "symbol",
                   "context_timeframe",
                   "execution_timeframe",
                   "scope_tag",
                   "config_hash",
                   "setup_key",
                   "impulse_id",
                   "direction",
                   "execution_mode",
                   "lifecycle_state",
                   "setup_phase",
                   "trade_phase",
                   "last_event_type",
                   "last_reason_code",
                   "last_event_time",
                   "waiting_since",
                   "opened_time",
                   "resolved_time",
                   "trigger_price",
                   "entry_price",
                   "resolution_price",
                   "pending_ticket",
                   "position_ticket",
                   "break_even_active",
                   "post_be_started",
                   "partial_progress_percent",
                   "last_management_action",
                   "resolution_event_type",
                   "resolution_reason_code",
                   "resolution_diagnostics",
                   "source");
        }
      else
         FileSeek(handle, 0, SEEK_END);

      const long sequence_no = NextLifecycleSequence();
      FileWrite(handle,
                "runtime_lifecycle_v1",
                IntegerToString((int)sequence_no),
                IntegerToString((int)TimeCurrent()),
                IntegerToString((int)m_chart_id),
                record.symbol,
                MohyTimeframeToString(cfg.context_timeframe),
                MohyTimeframeToString(cfg.execution_timeframe),
                m_scope_tag,
                record.config_hash,
                record.setup_key,
                record.impulse_id,
                MohyDirectionToString(record.direction),
                IntegerToString((int)record.execution_mode),
                MohyRuntimeLifecycleStateToString(record.lifecycle_state),
                MohySetupPhaseToString(record.setup_phase),
                MohyTradePhaseToString(record.trade_phase),
                MohyEngineEventTypeToString(record.last_event_type),
                record.last_reason_code,
                IntegerToString((int)record.last_event_time),
                IntegerToString((int)record.waiting_since),
                IntegerToString((int)record.opened_time),
                IntegerToString((int)record.resolved_time),
                DoubleToString(record.trigger_price, 10),
                DoubleToString(record.entry_price, 10),
                DoubleToString(record.resolution_price, 10),
                IntegerToString(record.pending_ticket),
                IntegerToString(record.position_ticket),
                record.break_even_active ? "1" : "0",
                record.post_be_started ? "1" : "0",
                DoubleToString(record.partial_progress_percent, 10),
                record.last_management_action,
                MohyEngineEventTypeToString(record.resolution_event_type),
                record.resolution_reason_code,
                record.resolution_diagnostics,
                source);
      FileClose(handle);
      return true;
     }
  };

#endif

