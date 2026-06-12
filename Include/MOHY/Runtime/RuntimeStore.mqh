#ifndef __MOHY_RUNTIME_STORE_MQH__
#define __MOHY_RUNTIME_STORE_MQH__

#include <MOHY/Runtime/RuntimeCommon.mqh>
#include <MOHY/Domain/Contracts.mqh>

struct MohyRuntimeConsumedImpulse
  {
   string                     impulse_id;
   MohyImpulseConsumptionReason reason;
   datetime                   updated_at;
   string                     setup_key;
  };

class CMohyRuntimeStore
  {
private:
   string m_scope_tag;

   string PausePath() const
     {
      return MohyRuntimeBuildRuntimePath(m_scope_tag, "pause_flag.csv");
     }

   string PositionPath() const
     {
      return MohyRuntimeBuildRuntimePath(m_scope_tag, "tracked_position.csv");
     }

   string WaitingPath() const
     {
      return MohyRuntimeBuildRuntimePath(m_scope_tag, "waiting_state.csv");
     }

   string ConsumedPath() const
     {
      return MohyRuntimeBuildRuntimePath(m_scope_tag, "consumed_impulses.csv");
     }

   string LifecyclePath() const
     {
      return MohyRuntimeBuildRuntimePath(m_scope_tag, "lifecycle_state.csv");
     }

   void SkipFields(const int handle,
                   const int count) const
     {
      for(int i = 0; i < count && !FileIsEnding(handle); ++i)
         FileReadString(handle);
     }

   bool EnsureRuntimeDirectory() const
     {
      return MohyRuntimeEnsureDirectory(MohyRuntimeBuildRuntimeDirectory(m_scope_tag));
     }

public:
            CMohyRuntimeStore()
              {
               m_scope_tag = "";
              }

   void     Configure(const string scope_tag)
     {
      m_scope_tag = MohyRuntimeSanitizeToken(scope_tag);
     }

   bool     LoadPauseFlag(bool &out_paused) const
     {
      out_paused = false;
      if(m_scope_tag == "")
         return false;

      const string path = PausePath();
      if(!FileIsExist(path))
         return false;

      const int handle = FileOpen(path, FILE_READ | FILE_CSV | FILE_ANSI, ',');
      if(handle == INVALID_HANDLE)
         return false;

      if(!FileIsEnding(handle))
      {
         FileReadString(handle);
         if(!FileIsEnding(handle))
            out_paused = (FileReadString(handle) == "1");
      }
      FileClose(handle);
      return true;
     }

   bool     SavePauseFlag(const bool paused) const
     {
      if(m_scope_tag == "" || !EnsureRuntimeDirectory())
         return false;

      const int handle = FileOpen(PausePath(), FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
      if(handle == INVALID_HANDLE)
         return false;
      FileWrite(handle, "paused", paused ? "1" : "0");
      FileClose(handle);
      return true;
     }

   bool     LoadTrackedPosition(PositionManagementState &out_state) const
      {
       MohyResetManagementState(out_state);
       if(m_scope_tag == "")
          return false;

      const string path = PositionPath();
      if(!FileIsExist(path))
         return false;

      const int handle = FileOpen(path, FILE_READ | FILE_CSV | FILE_ANSI, ',');
      if(handle == INVALID_HANDLE)
         return false;

       if(!FileIsEnding(handle))
         {
          const string schema = FileReadString(handle);
          if(schema == "phase3")
            {
             if(!FileIsEnding(handle))
                out_state.ticket = (int)StringToInteger(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.setup_key = FileReadString(handle);
             if(!FileIsEnding(handle))
                out_state.impulse_id = FileReadString(handle);
             if(!FileIsEnding(handle))
                out_state.direction = (MohyDirection)StringToInteger(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.execution_mode = (MohyEntryExecutionMode)StringToInteger(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.trade_phase = (MohyTradePhase)StringToInteger(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.recovered = (FileReadString(handle) == "1");
             if(!FileIsEnding(handle))
                out_state.break_even_armed = (FileReadString(handle) == "1");
             if(!FileIsEnding(handle))
                out_state.break_even_active = (FileReadString(handle) == "1");
             if(!FileIsEnding(handle))
                out_state.break_even_level = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.break_even_applied_to_broker = (FileReadString(handle) == "1");
             if(!FileIsEnding(handle))
                out_state.break_even_retry_count = (int)StringToInteger(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.virtual_stop_active = (FileReadString(handle) == "1");
             if(!FileIsEnding(handle))
                out_state.virtual_stop_level = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.post_be_profile = (MohyPostBEProfile)StringToInteger(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.post_be_started = (FileReadString(handle) == "1");
             if(!FileIsEnding(handle))
                out_state.post_be_started_time = (datetime)StringToInteger(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.post_be_start_reason = (MohyPostBEStartReason)StringToInteger(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.partial_1_done = (FileReadString(handle) == "1");
             if(!FileIsEnding(handle))
                out_state.partial_2_done = (FileReadString(handle) == "1");
             if(!FileIsEnding(handle))
                out_state.partial_3_done = (FileReadString(handle) == "1");
             if(!FileIsEnding(handle))
                out_state.partial_progress_percent = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.entry_price = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.initial_lots = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.initial_stop_loss = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.target_price = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.initial_risk_points = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.impulse_extreme_reference = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.anchors_ready = (FileReadString(handle) == "1");
             if(!FileIsEnding(handle))
                out_state.impulse_high_anchor = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.impulse_low_anchor = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.correction_high_anchor = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.correction_low_anchor = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.runner_trail_only_active = (FileReadString(handle) == "1");
             if(!FileIsEnding(handle))
                out_state.runner_tp_removed = (FileReadString(handle) == "1");
             if(!FileIsEnding(handle))
                out_state.last_trail_update_time = (datetime)StringToInteger(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.last_favorable_extreme = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.opened_time = (datetime)StringToInteger(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.last_management_action_time = (datetime)StringToInteger(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.last_management_action = FileReadString(handle);
            }
          else if(schema == "phase2")
            {
             if(!FileIsEnding(handle))
                out_state.ticket = (int)StringToInteger(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.setup_key = FileReadString(handle);
             if(!FileIsEnding(handle))
                out_state.impulse_id = FileReadString(handle);
             if(!FileIsEnding(handle))
                out_state.direction = (MohyDirection)StringToInteger(FileReadString(handle));
             out_state.execution_mode = MOHY_ENTRY_VIRTUAL_TRIGGER;
             if(!FileIsEnding(handle))
                out_state.trade_phase = (MohyTradePhase)StringToInteger(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.recovered = (FileReadString(handle) == "1");
             if(!FileIsEnding(handle))
                out_state.break_even_armed = (FileReadString(handle) == "1");
             if(!FileIsEnding(handle))
                out_state.break_even_active = (FileReadString(handle) == "1");
             if(!FileIsEnding(handle))
                out_state.break_even_level = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.break_even_applied_to_broker = (FileReadString(handle) == "1");
             if(!FileIsEnding(handle))
                out_state.break_even_retry_count = (int)StringToInteger(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.virtual_stop_active = (FileReadString(handle) == "1");
             if(!FileIsEnding(handle))
                out_state.virtual_stop_level = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.post_be_profile = (MohyPostBEProfile)StringToInteger(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.post_be_started = (FileReadString(handle) == "1");
             if(!FileIsEnding(handle))
                out_state.post_be_started_time = (datetime)StringToInteger(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.post_be_start_reason = (MohyPostBEStartReason)StringToInteger(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.partial_1_done = (FileReadString(handle) == "1");
             if(!FileIsEnding(handle))
                out_state.partial_2_done = (FileReadString(handle) == "1");
             if(!FileIsEnding(handle))
                out_state.partial_3_done = (FileReadString(handle) == "1");
             if(!FileIsEnding(handle))
                out_state.partial_progress_percent = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.entry_price = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.initial_lots = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.initial_stop_loss = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.target_price = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.initial_risk_points = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.impulse_extreme_reference = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.anchors_ready = (FileReadString(handle) == "1");
             if(!FileIsEnding(handle))
                out_state.impulse_high_anchor = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.impulse_low_anchor = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.correction_high_anchor = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.correction_low_anchor = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.runner_trail_only_active = (FileReadString(handle) == "1");
             if(!FileIsEnding(handle))
                out_state.runner_tp_removed = (FileReadString(handle) == "1");
             if(!FileIsEnding(handle))
                out_state.last_trail_update_time = (datetime)StringToInteger(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.last_favorable_extreme = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.opened_time = (datetime)StringToInteger(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.last_management_action_time = (datetime)StringToInteger(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.last_management_action = FileReadString(handle);
            }
          else
            {
             if(schema == "ticket")
               {
                if(!FileIsEnding(handle))
                   out_state.ticket = (int)StringToInteger(FileReadString(handle));
               }
             else
                out_state.ticket = (int)StringToInteger(schema);
             if(!FileIsEnding(handle))
                out_state.setup_key = FileReadString(handle);
             if(!FileIsEnding(handle))
                out_state.impulse_id = FileReadString(handle);
             if(!FileIsEnding(handle))
                out_state.direction = (MohyDirection)StringToInteger(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.trade_phase = (MohyTradePhase)StringToInteger(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.recovered = (FileReadString(handle) == "1");
             if(!FileIsEnding(handle))
                out_state.entry_price = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.initial_lots = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.initial_stop_loss = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.target_price = StringToDouble(FileReadString(handle));
             if(!FileIsEnding(handle))
                out_state.opened_time = (datetime)StringToInteger(FileReadString(handle));
            }
          out_state.has_open_trade = (out_state.ticket > 0);
         }
       FileClose(handle);
       return out_state.has_open_trade;
      }

   bool     SaveTrackedPosition(const PositionManagementState &state) const
     {
      if(m_scope_tag == "" || !EnsureRuntimeDirectory())
         return false;

      const int handle = FileOpen(PositionPath(), FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
      if(handle == INVALID_HANDLE)
         return false;
       FileWrite(handle,
                 "phase3",
                 IntegerToString(state.ticket),
                 state.setup_key,
                 state.impulse_id,
                 IntegerToString((int)state.direction),
                 IntegerToString((int)state.execution_mode),
                 IntegerToString((int)state.trade_phase),
                 state.recovered ? "1" : "0",
                 state.break_even_armed ? "1" : "0",
                 state.break_even_active ? "1" : "0",
                 DoubleToString(state.break_even_level, 10),
                 state.break_even_applied_to_broker ? "1" : "0",
                 IntegerToString(state.break_even_retry_count),
                 state.virtual_stop_active ? "1" : "0",
                 DoubleToString(state.virtual_stop_level, 10),
                 IntegerToString((int)state.post_be_profile),
                 state.post_be_started ? "1" : "0",
                 IntegerToString((int)state.post_be_started_time),
                 IntegerToString((int)state.post_be_start_reason),
                 state.partial_1_done ? "1" : "0",
                 state.partial_2_done ? "1" : "0",
                 state.partial_3_done ? "1" : "0",
                 DoubleToString(state.partial_progress_percent, 10),
                 DoubleToString(state.entry_price, 10),
                 DoubleToString(state.initial_lots, 10),
                 DoubleToString(state.initial_stop_loss, 10),
                 DoubleToString(state.target_price, 10),
                 DoubleToString(state.initial_risk_points, 10),
                 DoubleToString(state.impulse_extreme_reference, 10),
                 state.anchors_ready ? "1" : "0",
                 DoubleToString(state.impulse_high_anchor, 10),
                 DoubleToString(state.impulse_low_anchor, 10),
                 DoubleToString(state.correction_high_anchor, 10),
                 DoubleToString(state.correction_low_anchor, 10),
                 state.runner_trail_only_active ? "1" : "0",
                 state.runner_tp_removed ? "1" : "0",
                 IntegerToString((int)state.last_trail_update_time),
                 DoubleToString(state.last_favorable_extreme, 10),
                 IntegerToString((int)state.opened_time),
                 IntegerToString((int)state.last_management_action_time),
                 state.last_management_action);
       FileClose(handle);
       return true;
      }

   bool     ClearTrackedPosition() const
     {
      if(m_scope_tag == "")
         return false;
      const string path = PositionPath();
      if(FileIsExist(path))
         return FileDelete(path);
      return true;
     }

   bool     LoadWaitingState(SetupState &out_state) const
     {
      MohyResetSetupState(out_state);
      if(m_scope_tag == "")
         return false;

      const string path = WaitingPath();
      if(!FileIsExist(path))
         return false;

      const int handle = FileOpen(path, FILE_READ | FILE_CSV | FILE_ANSI, ',');
      if(handle == INVALID_HANDLE)
         return false;

      if(!FileIsEnding(handle))
        {
         const string schema = FileReadString(handle);
         if(schema == "phase3_waiting")
           {
            if(!FileIsEnding(handle))
               out_state.setup_key = FileReadString(handle);
            if(!FileIsEnding(handle))
               out_state.impulse_id = FileReadString(handle);
            if(!FileIsEnding(handle))
               out_state.direction = (MohyDirection)StringToInteger(FileReadString(handle));
            if(!FileIsEnding(handle))
               out_state.lifecycle_phase = (MohySetupPhase)StringToInteger(FileReadString(handle));
            if(!FileIsEnding(handle))
               out_state.pre_entry_invalidation_mode = (MohyPreEntryInvalidationMode)StringToInteger(FileReadString(handle));
            if(!FileIsEnding(handle))
               out_state.invalidation_reason = (MohyInvalidationReason)StringToInteger(FileReadString(handle));
            if(!FileIsEnding(handle))
               out_state.blocked_impulse_id = FileReadString(handle);
            if(!FileIsEnding(handle))
               out_state.blocked_impulse_reason = (MohyImpulseConsumptionReason)StringToInteger(FileReadString(handle));
            if(!FileIsEnding(handle))
               out_state.blocked_since = (datetime)StringToInteger(FileReadString(handle));
            if(!FileIsEnding(handle))
               out_state.trigger_mode = (MohyEntryExecutionMode)StringToInteger(FileReadString(handle));
            if(!FileIsEnding(handle))
               out_state.trigger_price = StringToDouble(FileReadString(handle));
            if(!FileIsEnding(handle))
               out_state.trigger_initialized = (FileReadString(handle) == "1");
            if(!FileIsEnding(handle))
               out_state.trigger_last_adjust_time = (datetime)StringToInteger(FileReadString(handle));
            if(!FileIsEnding(handle))
               out_state.waiting_since = (datetime)StringToInteger(FileReadString(handle));
            if(!FileIsEnding(handle))
               out_state.paused_entries = (FileReadString(handle) == "1");
            if(!FileIsEnding(handle))
               out_state.pending_placed = (FileReadString(handle) == "1");
            if(!FileIsEnding(handle))
               out_state.pending_ticket = (int)StringToInteger(FileReadString(handle));
            if(!FileIsEnding(handle))
               out_state.rr_state = (FileReadString(handle) == "1");
            if(!FileIsEnding(handle))
               out_state.spread_gate_state = (FileReadString(handle) == "1");
            if(!FileIsEnding(handle))
               out_state.last_reject_reason = (MohyRejectReason)StringToInteger(FileReadString(handle));
            if(!FileIsEnding(handle))
               out_state.last_transition_time = (datetime)StringToInteger(FileReadString(handle));
            if(!FileIsEnding(handle))
               out_state.last_transition_cause = FileReadString(handle);
            if(!FileIsEnding(handle))
               out_state.failed_touches = (int)StringToInteger(FileReadString(handle));
            if(!FileIsEnding(handle))
               out_state.entry_touched_once = (FileReadString(handle) == "1");
           }
        }

      FileClose(handle);
      return (out_state.setup_key != "");
     }

   bool     SaveWaitingState(const SetupState &state) const
     {
      if(m_scope_tag == "" || !EnsureRuntimeDirectory())
         return false;

      const int handle = FileOpen(WaitingPath(), FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
      if(handle == INVALID_HANDLE)
         return false;

      FileWrite(handle,
                "phase3_waiting",
                state.setup_key,
                state.impulse_id,
                IntegerToString((int)state.direction),
                IntegerToString((int)state.lifecycle_phase),
                IntegerToString((int)state.pre_entry_invalidation_mode),
                IntegerToString((int)state.invalidation_reason),
                state.blocked_impulse_id,
                IntegerToString((int)state.blocked_impulse_reason),
                IntegerToString((int)state.blocked_since),
                IntegerToString((int)state.trigger_mode),
                DoubleToString(state.trigger_price, 10),
                state.trigger_initialized ? "1" : "0",
                IntegerToString((int)state.trigger_last_adjust_time),
                IntegerToString((int)state.waiting_since),
                state.paused_entries ? "1" : "0",
                state.pending_placed ? "1" : "0",
                IntegerToString(state.pending_ticket),
                state.rr_state ? "1" : "0",
                state.spread_gate_state ? "1" : "0",
                IntegerToString((int)state.last_reject_reason),
                IntegerToString((int)state.last_transition_time),
                state.last_transition_cause,
                IntegerToString(state.failed_touches),
                state.entry_touched_once ? "1" : "0");
      FileClose(handle);
      return true;
     }

   bool     ClearWaitingState() const
     {
      if(m_scope_tag == "")
         return false;
      const string path = WaitingPath();
      if(FileIsExist(path))
         return FileDelete(path);
      return true;
     }

   bool     LoadConsumedImpulses(MohyRuntimeConsumedImpulse &out_rows[]) const
     {
      ArrayResize(out_rows, 0);
      if(m_scope_tag == "")
         return false;

      const string path = ConsumedPath();
      if(!FileIsExist(path))
         return false;

      const int handle = FileOpen(path, FILE_READ | FILE_CSV | FILE_ANSI, ',');
      if(handle == INVALID_HANDLE)
         return false;

      while(!FileIsEnding(handle))
        {
         const string impulse_id = FileReadString(handle);
         if(impulse_id == "" || impulse_id == "impulse_id")
           {
            if(FileIsEnding(handle))
               break;
            FileReadString(handle);
            FileReadString(handle);
            FileReadString(handle);
            continue;
           }

         const int size = ArraySize(out_rows);
         ArrayResize(out_rows, size + 1);
         out_rows[size].impulse_id = impulse_id;
         out_rows[size].reason = (MohyImpulseConsumptionReason)StringToInteger(FileReadString(handle));
         out_rows[size].updated_at = (datetime)StringToInteger(FileReadString(handle));
         out_rows[size].setup_key = FileReadString(handle);
        }

      FileClose(handle);
      return (ArraySize(out_rows) > 0);
     }

   bool     SaveConsumedImpulses(const MohyRuntimeConsumedImpulse &rows[]) const
     {
      if(m_scope_tag == "" || !EnsureRuntimeDirectory())
         return false;

      const int handle = FileOpen(ConsumedPath(), FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
      if(handle == INVALID_HANDLE)
         return false;
      FileWrite(handle, "impulse_id", "reason", "updated_at", "setup_key");
      for(int i = 0; i < ArraySize(rows); ++i)
         FileWrite(handle,
                   rows[i].impulse_id,
                   IntegerToString((int)rows[i].reason),
                   IntegerToString((int)rows[i].updated_at),
                   rows[i].setup_key);
      FileClose(handle);
      return true;
     }

   int      FindConsumedImpulse(const MohyRuntimeConsumedImpulse &rows[],
                                const string impulse_id) const
     {
      for(int i = 0; i < ArraySize(rows); ++i)
         if(rows[i].impulse_id == impulse_id)
            return i;
      return -1;
     }

   bool     UpsertConsumedImpulse(MohyRuntimeConsumedImpulse &io_rows[],
                                  const string impulse_id,
                                  const MohyImpulseConsumptionReason reason,
                                  const datetime updated_at,
                                  const string setup_key) const
     {
      if(impulse_id == "")
         return false;

      int index = FindConsumedImpulse(io_rows, impulse_id);
      if(index < 0)
        {
         index = ArraySize(io_rows);
         ArrayResize(io_rows, index + 1);
        }

      io_rows[index].impulse_id = impulse_id;
      io_rows[index].reason = reason;
      io_rows[index].updated_at = updated_at;
      io_rows[index].setup_key = setup_key;
      return SaveConsumedImpulses(io_rows);
     }

   bool     LoadLifecycleRecords(MohyRuntimeLifecycleRecord &out_rows[]) const
     {
      ArrayResize(out_rows, 0);
      if(m_scope_tag == "")
         return false;

      const string path = LifecyclePath();
      if(!FileIsExist(path))
         return false;

      const int handle = FileOpen(path, FILE_READ | FILE_CSV | FILE_ANSI, ',');
      if(handle == INVALID_HANDLE)
         return false;

      while(!FileIsEnding(handle))
        {
         const string schema_version = FileReadString(handle);
         if(schema_version == "")
            break;

         if(schema_version == "schema_version")
           {
            SkipFields(handle, 45);
            continue;
           }

         const int size = ArraySize(out_rows);
         ArrayResize(out_rows, size + 1);
         MohyResetRuntimeLifecycleRecord(out_rows[size]);
         out_rows[size].schema_version = schema_version;
         if(!FileIsEnding(handle))
            out_rows[size].setup_key = FileReadString(handle);
         if(!FileIsEnding(handle))
            out_rows[size].impulse_id = FileReadString(handle);
         if(!FileIsEnding(handle))
            out_rows[size].symbol = FileReadString(handle);
         if(!FileIsEnding(handle))
            out_rows[size].scope_tag = FileReadString(handle);
         if(!FileIsEnding(handle))
            out_rows[size].context_timeframe = FileReadString(handle);
         if(!FileIsEnding(handle))
            out_rows[size].execution_timeframe = FileReadString(handle);
         if(!FileIsEnding(handle))
            out_rows[size].config_hash = FileReadString(handle);
         if(!FileIsEnding(handle))
            out_rows[size].direction = (MohyDirection)StringToInteger(FileReadString(handle));
         if(!FileIsEnding(handle))
            out_rows[size].execution_mode = (MohyEntryExecutionMode)StringToInteger(FileReadString(handle));
         if(!FileIsEnding(handle))
            out_rows[size].lifecycle_state = (MohyRuntimeLifecycleState)StringToInteger(FileReadString(handle));
         if(!FileIsEnding(handle))
            out_rows[size].setup_phase = (MohySetupPhase)StringToInteger(FileReadString(handle));
         if(!FileIsEnding(handle))
            out_rows[size].trade_phase = (MohyTradePhase)StringToInteger(FileReadString(handle));
         if(!FileIsEnding(handle))
            out_rows[size].recovered = (FileReadString(handle) == "1");
         if(!FileIsEnding(handle))
            out_rows[size].last_event_type = (MohyEngineEventType)StringToInteger(FileReadString(handle));
         if(!FileIsEnding(handle))
            out_rows[size].last_reason_code = FileReadString(handle);
         if(!FileIsEnding(handle))
            out_rows[size].last_event_time = (datetime)StringToInteger(FileReadString(handle));
         if(!FileIsEnding(handle))
            out_rows[size].waiting_since = (datetime)StringToInteger(FileReadString(handle));
         if(!FileIsEnding(handle))
            out_rows[size].trigger_price = StringToDouble(FileReadString(handle));
         if(!FileIsEnding(handle))
            out_rows[size].pending_placed = (FileReadString(handle) == "1");
         if(!FileIsEnding(handle))
            out_rows[size].pending_ticket = (int)StringToInteger(FileReadString(handle));
         if(!FileIsEnding(handle))
            out_rows[size].opened_time = (datetime)StringToInteger(FileReadString(handle));
         if(!FileIsEnding(handle))
            out_rows[size].position_ticket = (int)StringToInteger(FileReadString(handle));
         if(!FileIsEnding(handle))
            out_rows[size].entry_price = StringToDouble(FileReadString(handle));
         if(!FileIsEnding(handle))
            out_rows[size].initial_stop_loss = StringToDouble(FileReadString(handle));
         if(!FileIsEnding(handle))
            out_rows[size].target_price = StringToDouble(FileReadString(handle));
         if(!FileIsEnding(handle))
            out_rows[size].break_even_armed = (FileReadString(handle) == "1");
         if(!FileIsEnding(handle))
            out_rows[size].break_even_active = (FileReadString(handle) == "1");
         if(!FileIsEnding(handle))
            out_rows[size].break_even_activated_time = (datetime)StringToInteger(FileReadString(handle));
         if(!FileIsEnding(handle))
            out_rows[size].break_even_level = StringToDouble(FileReadString(handle));
         if(!FileIsEnding(handle))
            out_rows[size].post_be_started = (FileReadString(handle) == "1");
         if(!FileIsEnding(handle))
            out_rows[size].post_be_started_time = (datetime)StringToInteger(FileReadString(handle));
         if(!FileIsEnding(handle))
            out_rows[size].post_be_start_reason = (MohyPostBEStartReason)StringToInteger(FileReadString(handle));
         if(!FileIsEnding(handle))
            out_rows[size].partial_1_done = (FileReadString(handle) == "1");
         if(!FileIsEnding(handle))
            out_rows[size].partial_2_done = (FileReadString(handle) == "1");
         if(!FileIsEnding(handle))
            out_rows[size].partial_3_done = (FileReadString(handle) == "1");
         if(!FileIsEnding(handle))
            out_rows[size].partial_progress_percent = StringToDouble(FileReadString(handle));
         if(!FileIsEnding(handle))
            out_rows[size].runner_trail_only_active = (FileReadString(handle) == "1");
         if(!FileIsEnding(handle))
            out_rows[size].runner_tp_removed = (FileReadString(handle) == "1");
         if(!FileIsEnding(handle))
            out_rows[size].last_trail_update_time = (datetime)StringToInteger(FileReadString(handle));
         if(!FileIsEnding(handle))
            out_rows[size].last_management_action = FileReadString(handle);
         if(!FileIsEnding(handle))
            out_rows[size].resolved_time = (datetime)StringToInteger(FileReadString(handle));
         if(!FileIsEnding(handle))
            out_rows[size].resolution_event_type = (MohyEngineEventType)StringToInteger(FileReadString(handle));
         if(!FileIsEnding(handle))
            out_rows[size].resolution_reason_code = FileReadString(handle);
         if(!FileIsEnding(handle))
            out_rows[size].resolution_price = StringToDouble(FileReadString(handle));
         if(!FileIsEnding(handle))
            out_rows[size].resolution_diagnostics = FileReadString(handle);
        }

      FileClose(handle);
      return (ArraySize(out_rows) > 0);
     }

   bool     SaveLifecycleRecords(const MohyRuntimeLifecycleRecord &rows[]) const
     {
      if(m_scope_tag == "" || !EnsureRuntimeDirectory())
         return false;

      const int handle = FileOpen(LifecyclePath(), FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
      if(handle == INVALID_HANDLE)
         return false;

      FileWrite(handle,
                "schema_version",
                "setup_key",
                "impulse_id",
                "symbol",
                "scope_tag",
                "context_timeframe",
                "execution_timeframe",
                "config_hash",
                "direction",
                "execution_mode",
                "lifecycle_state",
                "setup_phase",
                "trade_phase",
                "recovered",
                "last_event_type",
                "last_reason_code",
                "last_event_time",
                "waiting_since",
                "trigger_price",
                "pending_placed",
                "pending_ticket",
                "opened_time",
                "position_ticket",
                "entry_price",
                "initial_stop_loss",
                "target_price",
                "break_even_armed",
                "break_even_active",
                "break_even_activated_time",
                "break_even_level",
                "post_be_started",
                "post_be_started_time",
                "post_be_start_reason",
                "partial_1_done",
                "partial_2_done",
                "partial_3_done",
                "partial_progress_percent",
                "runner_trail_only_active",
                "runner_tp_removed",
                "last_trail_update_time",
                "last_management_action",
                "resolved_time",
                "resolution_event_type",
                "resolution_reason_code",
                "resolution_price",
                "resolution_diagnostics");

      for(int i = 0; i < ArraySize(rows); ++i)
         FileWrite(handle,
                   rows[i].schema_version,
                   rows[i].setup_key,
                   rows[i].impulse_id,
                   rows[i].symbol,
                   rows[i].scope_tag,
                   rows[i].context_timeframe,
                   rows[i].execution_timeframe,
                   rows[i].config_hash,
                   IntegerToString((int)rows[i].direction),
                   IntegerToString((int)rows[i].execution_mode),
                   IntegerToString((int)rows[i].lifecycle_state),
                   IntegerToString((int)rows[i].setup_phase),
                   IntegerToString((int)rows[i].trade_phase),
                   rows[i].recovered ? "1" : "0",
                   IntegerToString((int)rows[i].last_event_type),
                   rows[i].last_reason_code,
                   IntegerToString((int)rows[i].last_event_time),
                   IntegerToString((int)rows[i].waiting_since),
                   DoubleToString(rows[i].trigger_price, 10),
                   rows[i].pending_placed ? "1" : "0",
                   IntegerToString(rows[i].pending_ticket),
                   IntegerToString((int)rows[i].opened_time),
                   IntegerToString(rows[i].position_ticket),
                   DoubleToString(rows[i].entry_price, 10),
                   DoubleToString(rows[i].initial_stop_loss, 10),
                   DoubleToString(rows[i].target_price, 10),
                   rows[i].break_even_armed ? "1" : "0",
                   rows[i].break_even_active ? "1" : "0",
                   IntegerToString((int)rows[i].break_even_activated_time),
                   DoubleToString(rows[i].break_even_level, 10),
                   rows[i].post_be_started ? "1" : "0",
                   IntegerToString((int)rows[i].post_be_started_time),
                   IntegerToString((int)rows[i].post_be_start_reason),
                   rows[i].partial_1_done ? "1" : "0",
                   rows[i].partial_2_done ? "1" : "0",
                   rows[i].partial_3_done ? "1" : "0",
                   DoubleToString(rows[i].partial_progress_percent, 10),
                   rows[i].runner_trail_only_active ? "1" : "0",
                   rows[i].runner_tp_removed ? "1" : "0",
                   IntegerToString((int)rows[i].last_trail_update_time),
                   rows[i].last_management_action,
                   IntegerToString((int)rows[i].resolved_time),
                   IntegerToString((int)rows[i].resolution_event_type),
                   rows[i].resolution_reason_code,
                   DoubleToString(rows[i].resolution_price, 10),
                   rows[i].resolution_diagnostics);
      FileClose(handle);
      return true;
     }

   int      FindLifecycleRecord(const MohyRuntimeLifecycleRecord &rows[],
                                const string setup_key) const
     {
      if(setup_key == "")
         return -1;
      for(int i = 0; i < ArraySize(rows); ++i)
         if(rows[i].setup_key == setup_key)
            return i;
      return -1;
     }

   bool     UpsertLifecycleRecord(MohyRuntimeLifecycleRecord &io_rows[],
                                  const MohyRuntimeLifecycleRecord &record) const
     {
      if(record.setup_key == "")
         return false;

      int index = FindLifecycleRecord(io_rows, record.setup_key);
      if(index < 0)
        {
         index = ArraySize(io_rows);
         ArrayResize(io_rows, index + 1);
        }

      io_rows[index] = record;
      return SaveLifecycleRecords(io_rows);
     }
  };

#endif

