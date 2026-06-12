#property strict
#property script_show_inputs

#include <MOHY/Domain/Config.mqh>
#include <MOHY/Runtime/RuntimeCommon.mqh>
#include <MOHY/Runtime/RuntimeStore.mqh>

input string VerificationRunId = "";
input string VerificationSymbol = "";
input string VerificationScopeTag = "";
input ENUM_TIMEFRAMES VerificationHTF = PERIOD_H1;
input ENUM_TIMEFRAMES VerificationLTF = PERIOD_M15;
input int RuntimeMagicNumber = 26021601;
input string VerificationOutputDirectory = "MOHY\\verification\\runtime_lifecycle";
input bool VerificationWriteDetailsCsv = true;
input bool VerificationWriteAssertionsCsv = true;

struct MohyRlLifecycleEventRow
  {
   string schema_version;
   long   sequence_no;
   datetime timestamp;
   long   chart_id;
   string symbol;
   string context_timeframe;
   string execution_timeframe;
   string scope_tag;
   string config_hash;
   string setup_key;
   string impulse_id;
   string direction;
   int    execution_mode;
   string lifecycle_state;
   string setup_phase;
   string trade_phase;
   string last_event_type;
   string last_reason_code;
   datetime last_event_time;
   datetime waiting_since;
   datetime opened_time;
   datetime resolved_time;
   double trigger_price;
   double entry_price;
   double resolution_price;
   int    pending_ticket;
   int    position_ticket;
   bool   break_even_active;
   bool   post_be_started;
   double partial_progress_percent;
   string last_management_action;
   string resolution_event_type;
   string resolution_reason_code;
   string resolution_diagnostics;
   string source;
  };

struct MohyRlAssertionRow
  {
   string rule_id;
   bool   pass;
   int    violation_count;
   string sample;
  };

struct MohyRlDetailRow
  {
   string setup_key;
   string impulse_id;
   string state_lifecycle_state;
   string state_last_event_type;
   string state_last_reason_code;
   datetime state_last_event_time;
   datetime state_waiting_since;
   datetime state_opened_time;
   datetime state_resolved_time;
   int    event_count;
   long   latest_event_sequence_no;
   string latest_event_lifecycle_state;
   string latest_event_last_event_type;
   datetime latest_event_timestamp;
   bool   latest_event_match;
   bool   waiting_file_match;
   bool   position_file_match;
   string notes;
  };

string TrimText(const string value)
  {
   return MohyRuntimeTrim(value);
  }

string TimeText(const datetime value)
  {
   if(value <= 0)
      return "";
   return TimeToString(value, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
  }

string BuildTimestampToken(const datetime value)
  {
   string out = TimeToString(value, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
   StringReplace(out, ".", "");
   StringReplace(out, ":", "");
   StringReplace(out, " ", "_");
   return out;
  }

bool DoubleNear(const double left,
                const double right,
                const double epsilon = 1e-8)
  {
   return (MathAbs(left - right) <= epsilon);
  }

void SkipFields(const int handle,
                const int count)
  {
   for(int i = 0; i < count && !FileIsEnding(handle); ++i)
      FileReadString(handle);
  }

void AppendAssertion(MohyRlAssertionRow &io_rows[],
                     const string rule_id,
                     const bool pass,
                     const int violation_count,
                     const string sample)
  {
   const int size = ArraySize(io_rows);
   ArrayResize(io_rows, size + 1);
   io_rows[size].rule_id = rule_id;
   io_rows[size].pass = pass;
   io_rows[size].violation_count = violation_count;
   io_rows[size].sample = sample;
  }

void AppendDetail(MohyRlDetailRow &io_rows[],
                  const MohyRlDetailRow &row)
  {
   const int size = ArraySize(io_rows);
   ArrayResize(io_rows, size + 1);
   io_rows[size] = row;
  }

bool LoadLifecycleEvents(const string scope_tag,
                         MohyRlLifecycleEventRow &out_rows[])
  {
   ArrayResize(out_rows, 0);

   if(scope_tag == "")
      return false;

   const string path = MohyRuntimeBuildRuntimePath(scope_tag, "lifecycle_events.csv");
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
         SkipFields(handle, 34);
         continue;
        }

      const int size = ArraySize(out_rows);
      ArrayResize(out_rows, size + 1);
      out_rows[size].schema_version = schema_version;
      out_rows[size].sequence_no = !FileIsEnding(handle) ? (long)StringToInteger(FileReadString(handle)) : 0;
      out_rows[size].timestamp = !FileIsEnding(handle) ? (datetime)StringToInteger(FileReadString(handle)) : 0;
      out_rows[size].chart_id = !FileIsEnding(handle) ? (long)StringToInteger(FileReadString(handle)) : 0;
      out_rows[size].symbol = !FileIsEnding(handle) ? FileReadString(handle) : "";
      out_rows[size].context_timeframe = !FileIsEnding(handle) ? FileReadString(handle) : "";
      out_rows[size].execution_timeframe = !FileIsEnding(handle) ? FileReadString(handle) : "";
      out_rows[size].scope_tag = !FileIsEnding(handle) ? FileReadString(handle) : "";
      out_rows[size].config_hash = !FileIsEnding(handle) ? FileReadString(handle) : "";
      out_rows[size].setup_key = !FileIsEnding(handle) ? FileReadString(handle) : "";
      out_rows[size].impulse_id = !FileIsEnding(handle) ? FileReadString(handle) : "";
      out_rows[size].direction = !FileIsEnding(handle) ? FileReadString(handle) : "";
      out_rows[size].execution_mode = !FileIsEnding(handle) ? (int)StringToInteger(FileReadString(handle)) : 0;
      out_rows[size].lifecycle_state = !FileIsEnding(handle) ? FileReadString(handle) : "";
      out_rows[size].setup_phase = !FileIsEnding(handle) ? FileReadString(handle) : "";
      out_rows[size].trade_phase = !FileIsEnding(handle) ? FileReadString(handle) : "";
      out_rows[size].last_event_type = !FileIsEnding(handle) ? FileReadString(handle) : "";
      out_rows[size].last_reason_code = !FileIsEnding(handle) ? FileReadString(handle) : "";
      out_rows[size].last_event_time = !FileIsEnding(handle) ? (datetime)StringToInteger(FileReadString(handle)) : 0;
      out_rows[size].waiting_since = !FileIsEnding(handle) ? (datetime)StringToInteger(FileReadString(handle)) : 0;
      out_rows[size].opened_time = !FileIsEnding(handle) ? (datetime)StringToInteger(FileReadString(handle)) : 0;
      out_rows[size].resolved_time = !FileIsEnding(handle) ? (datetime)StringToInteger(FileReadString(handle)) : 0;
      out_rows[size].trigger_price = !FileIsEnding(handle) ? StringToDouble(FileReadString(handle)) : 0.0;
      out_rows[size].entry_price = !FileIsEnding(handle) ? StringToDouble(FileReadString(handle)) : 0.0;
      out_rows[size].resolution_price = !FileIsEnding(handle) ? StringToDouble(FileReadString(handle)) : 0.0;
      out_rows[size].pending_ticket = !FileIsEnding(handle) ? (int)StringToInteger(FileReadString(handle)) : 0;
      out_rows[size].position_ticket = !FileIsEnding(handle) ? (int)StringToInteger(FileReadString(handle)) : 0;
      out_rows[size].break_even_active = (!FileIsEnding(handle) && FileReadString(handle) == "1");
      out_rows[size].post_be_started = (!FileIsEnding(handle) && FileReadString(handle) == "1");
      out_rows[size].partial_progress_percent = !FileIsEnding(handle) ? StringToDouble(FileReadString(handle)) : 0.0;
      out_rows[size].last_management_action = !FileIsEnding(handle) ? FileReadString(handle) : "";
      out_rows[size].resolution_event_type = !FileIsEnding(handle) ? FileReadString(handle) : "";
      out_rows[size].resolution_reason_code = !FileIsEnding(handle) ? FileReadString(handle) : "";
      out_rows[size].resolution_diagnostics = !FileIsEnding(handle) ? FileReadString(handle) : "";
      out_rows[size].source = !FileIsEnding(handle) ? FileReadString(handle) : "";
     }

   FileClose(handle);
   return (ArraySize(out_rows) > 0);
  }

string ResolveScopeTag(string &out_symbol,
                       string &out_error)
  {
   out_symbol = TrimText(VerificationSymbol);
   out_error = "";

   const string explicit_scope = TrimText(VerificationScopeTag);
   if(explicit_scope != "")
     {
      if(out_symbol == "")
         out_symbol = _Symbol;
      return MohyRuntimeSanitizeToken(explicit_scope);
     }

   if(out_symbol == "")
      out_symbol = _Symbol;
   if(out_symbol == "")
     {
      out_error = "VerificationScopeTag or VerificationSymbol is required.";
      return "";
     }

   const int htf = (int)VerificationHTF;
   const int ltf = (int)VerificationLTF;
   if(!MohyValidateTimeframePair(htf, ltf))
     {
      out_error = StringFormat("Invalid timeframe pair HTF=%s LTF=%s. Allowed: H1/M15, H2/M30, H4/H1, D1/H4.",
                               MohyTimeframeToString(htf),
                               MohyTimeframeToString(ltf));
      return "";
     }

   return MohyRuntimeBuildScopeTag(out_symbol, htf, ltf, RuntimeMagicNumber);
  }

int FindLatestEventIndexBySetupKey(const MohyRlLifecycleEventRow &rows[],
                                   const string setup_key)
  {
   if(setup_key == "")
      return -1;

   int selected_index = -1;
   for(int i = 0; i < ArraySize(rows); ++i)
     {
      if(rows[i].setup_key != setup_key)
         continue;
      if(selected_index < 0 || rows[i].sequence_no > rows[selected_index].sequence_no)
         selected_index = i;
     }
   return selected_index;
  }

int CountEventsForSetupKey(const MohyRlLifecycleEventRow &rows[],
                           const string setup_key)
  {
   int count = 0;
   for(int i = 0; i < ArraySize(rows); ++i)
      if(rows[i].setup_key == setup_key)
         count++;
   return count;
  }

int CountStateRowsByLifecycle(const MohyRuntimeLifecycleRecord &rows[],
                              const MohyRuntimeLifecycleState lifecycle_state)
  {
   int count = 0;
   for(int i = 0; i < ArraySize(rows); ++i)
      if(rows[i].lifecycle_state == lifecycle_state)
         count++;
   return count;
  }

int FindStateIndexBySetupKeyAndLifecycle(const MohyRuntimeLifecycleRecord &rows[],
                                         const string setup_key,
                                         const MohyRuntimeLifecycleState lifecycle_state)
  {
   for(int i = 0; i < ArraySize(rows); ++i)
     {
      if(rows[i].setup_key != setup_key)
         continue;
      if(rows[i].lifecycle_state != lifecycle_state)
         continue;
      return i;
     }
   return -1;
  }

bool MatchStateToEvent(const MohyRuntimeLifecycleRecord &state,
                       const MohyRlLifecycleEventRow &event_row,
                       string &out_reason)
  {
   out_reason = "";

   if(state.setup_key != event_row.setup_key)
      out_reason = "setup_key";
   else if(state.impulse_id != event_row.impulse_id)
      out_reason = "impulse_id";
   else if(state.symbol != event_row.symbol)
      out_reason = "symbol";
   else if(state.scope_tag != event_row.scope_tag)
      out_reason = "scope_tag";
   else if(state.context_timeframe != event_row.context_timeframe)
      out_reason = "context_timeframe";
   else if(state.execution_timeframe != event_row.execution_timeframe)
      out_reason = "execution_timeframe";
   else if(state.config_hash != event_row.config_hash)
      out_reason = "config_hash";
   else if(MohyDirectionToString(state.direction) != event_row.direction)
      out_reason = "direction";
   else if((int)state.execution_mode != event_row.execution_mode)
      out_reason = "execution_mode";
   else if(MohyRuntimeLifecycleStateToString(state.lifecycle_state) != event_row.lifecycle_state)
      out_reason = "lifecycle_state";
   else if(MohySetupPhaseToString(state.setup_phase) != event_row.setup_phase)
      out_reason = "setup_phase";
   else if(MohyTradePhaseToString(state.trade_phase) != event_row.trade_phase)
      out_reason = "trade_phase";
   else if(MohyEngineEventTypeToString(state.last_event_type) != event_row.last_event_type)
      out_reason = "last_event_type";
   else if(state.last_reason_code != event_row.last_reason_code)
      out_reason = "last_reason_code";
   else if(state.last_event_time != event_row.last_event_time)
      out_reason = "last_event_time";
   else if(state.waiting_since != event_row.waiting_since)
      out_reason = "waiting_since";
   else if(state.opened_time != event_row.opened_time)
      out_reason = "opened_time";
   else if(state.resolved_time != event_row.resolved_time)
      out_reason = "resolved_time";
   else if(!DoubleNear(state.trigger_price, event_row.trigger_price))
      out_reason = "trigger_price";
   else if(!DoubleNear(state.entry_price, event_row.entry_price))
      out_reason = "entry_price";
   else if(!DoubleNear(state.resolution_price, event_row.resolution_price))
      out_reason = "resolution_price";
   else if(state.pending_ticket != event_row.pending_ticket)
      out_reason = "pending_ticket";
   else if(state.position_ticket != event_row.position_ticket)
      out_reason = "position_ticket";
   else if(state.break_even_active != event_row.break_even_active)
      out_reason = "break_even_active";
   else if(state.post_be_started != event_row.post_be_started)
      out_reason = "post_be_started";
   else if(!DoubleNear(state.partial_progress_percent, event_row.partial_progress_percent))
      out_reason = "partial_progress_percent";
   else if(state.last_management_action != event_row.last_management_action)
      out_reason = "last_management_action";
   else if(MohyEngineEventTypeToString(state.resolution_event_type) != event_row.resolution_event_type)
      out_reason = "resolution_event_type";
   else if(state.resolution_reason_code != event_row.resolution_reason_code)
      out_reason = "resolution_reason_code";
   else if(state.resolution_diagnostics != event_row.resolution_diagnostics)
      out_reason = "resolution_diagnostics";

   return (out_reason == "");
  }

bool MatchWaitingStateToLifecycle(const SetupState &waiting_state,
                                  const MohyRuntimeLifecycleRecord &row,
                                  string &out_reason)
  {
   out_reason = "";
   if(row.lifecycle_state != MOHY_RUNTIME_LIFECYCLE_WAITING)
      out_reason = "lifecycle_state";
   else if(waiting_state.setup_key != row.setup_key)
      out_reason = "setup_key";
   else if(waiting_state.impulse_id != row.impulse_id)
      out_reason = "impulse_id";
   else if(waiting_state.direction != row.direction)
      out_reason = "direction";
   else if(waiting_state.trigger_mode != row.execution_mode)
      out_reason = "execution_mode";
   else if(waiting_state.lifecycle_phase != row.setup_phase)
      out_reason = "setup_phase";
   else if(waiting_state.waiting_since != row.waiting_since)
      out_reason = "waiting_since";
   else if(!DoubleNear(waiting_state.trigger_price, row.trigger_price))
      out_reason = "trigger_price";
   else if(waiting_state.pending_placed != row.pending_placed)
      out_reason = "pending_placed";
   else if(waiting_state.pending_ticket != row.pending_ticket)
      out_reason = "pending_ticket";
   return (out_reason == "");
  }

bool MatchPositionStateToLifecycle(const PositionManagementState &position_state,
                                   const MohyRuntimeLifecycleRecord &row,
                                   string &out_reason)
  {
   out_reason = "";
   if(row.lifecycle_state != MOHY_RUNTIME_LIFECYCLE_OPEN)
      out_reason = "lifecycle_state";
   else if(position_state.setup_key != row.setup_key)
      out_reason = "setup_key";
   else if(position_state.impulse_id != row.impulse_id)
      out_reason = "impulse_id";
   else if(position_state.direction != row.direction)
      out_reason = "direction";
   else if(position_state.execution_mode != row.execution_mode)
      out_reason = "execution_mode";
   else if(position_state.trade_phase != row.trade_phase)
      out_reason = "trade_phase";
   else if(position_state.recovered != row.recovered)
      out_reason = "recovered";
   else if(position_state.ticket != row.position_ticket)
      out_reason = "position_ticket";
   else if(position_state.opened_time != row.opened_time)
      out_reason = "opened_time";
   else if(!DoubleNear(position_state.entry_price, row.entry_price))
      out_reason = "entry_price";
   else if(!DoubleNear(position_state.initial_stop_loss, row.initial_stop_loss))
      out_reason = "initial_stop_loss";
   else if(!DoubleNear(position_state.target_price, row.target_price))
      out_reason = "target_price";
   else if(position_state.break_even_armed != row.break_even_armed)
      out_reason = "break_even_armed";
   else if(position_state.break_even_active != row.break_even_active)
      out_reason = "break_even_active";
   else if(position_state.post_be_started != row.post_be_started)
      out_reason = "post_be_started";
   else if(position_state.post_be_started_time != row.post_be_started_time)
      out_reason = "post_be_started_time";
   else if(position_state.post_be_start_reason != row.post_be_start_reason)
      out_reason = "post_be_start_reason";
   else if(position_state.partial_1_done != row.partial_1_done)
      out_reason = "partial_1_done";
   else if(position_state.partial_2_done != row.partial_2_done)
      out_reason = "partial_2_done";
   else if(position_state.partial_3_done != row.partial_3_done)
      out_reason = "partial_3_done";
   else if(!DoubleNear(position_state.partial_progress_percent, row.partial_progress_percent))
      out_reason = "partial_progress_percent";
   else if(position_state.runner_trail_only_active != row.runner_trail_only_active)
      out_reason = "runner_trail_only_active";
   else if(position_state.runner_tp_removed != row.runner_tp_removed)
      out_reason = "runner_tp_removed";
   else if(position_state.last_trail_update_time != row.last_trail_update_time)
      out_reason = "last_trail_update_time";
   else if(position_state.last_management_action != row.last_management_action)
      out_reason = "last_management_action";
   return (out_reason == "");
  }

void EvaluateAssertions(const string scope_tag,
                        const bool lifecycle_state_file_exists,
                        const bool lifecycle_events_file_exists,
                        const bool waiting_file_exists,
                        const bool position_file_exists,
                        const MohyRuntimeLifecycleRecord &state_rows[],
                        const MohyRlLifecycleEventRow &event_rows[],
                        const bool has_waiting_state,
                        const SetupState &waiting_state,
                        const bool has_position_state,
                        const PositionManagementState &position_state,
                        MohyRlAssertionRow &out_assertions[],
                        MohyRlDetailRow &out_details[])
  {
   ArrayResize(out_assertions, 0);
   ArrayResize(out_details, 0);

   const int state_count = ArraySize(state_rows);
   const int event_count = ArraySize(event_rows);
   const int waiting_rows = CountStateRowsByLifecycle(state_rows, MOHY_RUNTIME_LIFECYCLE_WAITING);
   const int open_rows = CountStateRowsByLifecycle(state_rows, MOHY_RUNTIME_LIFECYCLE_OPEN);
   const int active_rows = waiting_rows + open_rows;

   AppendAssertion(out_assertions,
                   "STATE_ROWS_PRESENT",
                   lifecycle_state_file_exists && state_count > 0,
                   (lifecycle_state_file_exists && state_count > 0) ? 0 : 1,
                   lifecycle_state_file_exists
                   ? ((state_count > 0) ? StringFormat("rows=%d", state_count) : "lifecycle_state.csv empty or unreadable")
                   : "Missing lifecycle_state.csv");
   AppendAssertion(out_assertions,
                   "EVENT_ROWS_PRESENT",
                   lifecycle_events_file_exists && event_count > 0,
                   (lifecycle_events_file_exists && event_count > 0) ? 0 : 1,
                   lifecycle_events_file_exists
                   ? ((event_count > 0) ? StringFormat("rows=%d", event_count) : "lifecycle_events.csv empty or unreadable")
                   : "Missing lifecycle_events.csv");
   AppendAssertion(out_assertions,
                   "ACTIVE_LIFECYCLE_ROWS_LIMITED",
                   (active_rows <= 1),
                   (active_rows <= 1) ? 0 : (active_rows - 1),
                   StringFormat("waiting_rows=%d open_rows=%d", waiting_rows, open_rows));
   AppendAssertion(out_assertions,
                   "ACTIVE_STATE_FILE_EXCLUSIVITY",
                   !(waiting_file_exists && position_file_exists),
                   (waiting_file_exists && position_file_exists) ? 1 : 0,
                   StringFormat("waiting_file=%d position_file=%d",
                                waiting_file_exists ? 1 : 0,
                                position_file_exists ? 1 : 0));

   int state_unique_violations = 0;
   string state_unique_sample = "not-evaluated:no-state-data";
   if(state_count > 0)
     {
      state_unique_sample = "";
      for(int i = 0; i < state_count; ++i)
        {
         if(state_rows[i].setup_key == "")
            continue;
         for(int j = i + 1; j < state_count; ++j)
           {
            if(state_rows[j].setup_key != state_rows[i].setup_key)
               continue;
            state_unique_violations++;
            if(state_unique_sample == "")
               state_unique_sample = StringFormat("duplicate setup_key=%s rows=%d,%d",
                                                  state_rows[i].setup_key,
                                                  i,
                                                  j);
           }
        }
      if(state_unique_sample == "")
         state_unique_sample = "ok";
     }
   AppendAssertion(out_assertions,
                   "STATE_SETUP_KEYS_UNIQUE",
                   (state_unique_violations == 0),
                   state_unique_violations,
                   state_unique_sample);

   int state_scope_violations = 0;
   string state_scope_sample = "not-evaluated:no-state-data";
   if(state_count > 0)
     {
      state_scope_sample = "";
      for(int i = 0; i < state_count; ++i)
        {
         if(state_rows[i].scope_tag == scope_tag)
            continue;
         state_scope_violations++;
         if(state_scope_sample == "")
            state_scope_sample = StringFormat("setup_key=%s state_scope=%s expected=%s",
                                              state_rows[i].setup_key,
                                              state_rows[i].scope_tag,
                                              scope_tag);
        }
      if(state_scope_sample == "")
         state_scope_sample = "ok";
     }
   AppendAssertion(out_assertions,
                   "STATE_SCOPE_MATCH",
                   (state_scope_violations == 0),
                   state_scope_violations,
                   state_scope_sample);

   int state_id_violations = 0;
   string state_id_sample = "not-evaluated:no-state-data";
   if(state_count > 0)
     {
      state_id_sample = "";
      for(int i = 0; i < state_count; ++i)
        {
         if(state_rows[i].setup_key != "" &&
            state_rows[i].impulse_id != "" &&
            state_rows[i].symbol != "" &&
            state_rows[i].context_timeframe != "" &&
            state_rows[i].execution_timeframe != "")
            continue;
         state_id_violations++;
         if(state_id_sample == "")
            state_id_sample = StringFormat("row=%d setup_key=%s impulse_id=%s symbol=%s ctx=%s exe=%s",
                                           i,
                                           state_rows[i].setup_key,
                                           state_rows[i].impulse_id,
                                           state_rows[i].symbol,
                                           state_rows[i].context_timeframe,
                                           state_rows[i].execution_timeframe);
        }
      if(state_id_sample == "")
         state_id_sample = "ok";
     }
   AppendAssertion(out_assertions,
                   "STATE_REQUIRED_IDENTIFIERS",
                   (state_id_violations == 0),
                   state_id_violations,
                   state_id_sample);

   int state_shape_violations = 0;
   string state_shape_sample = "not-evaluated:no-state-data";
   if(state_count > 0)
     {
      state_shape_sample = "";
      for(int i = 0; i < state_count; ++i)
        {
         string reason = "";
         const MohyRuntimeLifecycleRecord row = state_rows[i];
         if(row.lifecycle_state == MOHY_RUNTIME_LIFECYCLE_WAITING)
           {
            if(row.waiting_since <= 0)
               reason = "waiting_since";
            else if(row.opened_time > 0)
               reason = "opened_time";
            else if(row.position_ticket > 0)
               reason = "position_ticket";
            else if(row.resolved_time > 0)
               reason = "resolved_time";
            else if(row.resolution_event_type != MOHY_ENGINE_EVENT_NONE)
               reason = "resolution_event_type";
            else if(row.pending_placed && row.pending_ticket <= 0)
               reason = "pending_ticket";
           }
         else if(row.lifecycle_state == MOHY_RUNTIME_LIFECYCLE_OPEN)
           {
            if(row.opened_time <= 0)
               reason = "opened_time";
            else if(row.position_ticket <= 0)
               reason = "position_ticket";
            else if(row.pending_placed)
               reason = "pending_placed";
            else if(row.pending_ticket > 0)
               reason = "pending_ticket";
            else if(row.resolved_time > 0)
               reason = "resolved_time";
            else if(row.resolution_event_type != MOHY_ENGINE_EVENT_NONE)
               reason = "resolution_event_type";
           }
         else if(row.lifecycle_state == MOHY_RUNTIME_LIFECYCLE_RESOLVED)
           {
            if(row.resolved_time <= 0)
               reason = "resolved_time";
            else if(row.resolution_event_type == MOHY_ENGINE_EVENT_NONE)
               reason = "resolution_event_type";
           }
         else
            reason = "lifecycle_state";

         if(reason == "")
            continue;
         state_shape_violations++;
         if(state_shape_sample == "")
            state_shape_sample = StringFormat("setup_key=%s state=%s field=%s",
                                              row.setup_key,
                                              MohyRuntimeLifecycleStateToString(row.lifecycle_state),
                                              reason);
        }
      if(state_shape_sample == "")
         state_shape_sample = "ok";
     }
   AppendAssertion(out_assertions,
                   "STATE_RUNTIME_SHAPE_VALID",
                   (state_shape_violations == 0),
                   state_shape_violations,
                   state_shape_sample);

   int state_time_violations = 0;
   string state_time_sample = "not-evaluated:no-state-data";
   if(state_count > 0)
     {
      state_time_sample = "";
      for(int i = 0; i < state_count; ++i)
        {
         const MohyRuntimeLifecycleRecord row = state_rows[i];
         string reason = "";
         if(row.waiting_since > 0 && row.opened_time > 0 && row.waiting_since > row.opened_time)
            reason = "waiting_since>opened_time";
         else if(row.waiting_since > 0 && row.resolved_time > 0 && row.waiting_since > row.resolved_time)
            reason = "waiting_since>resolved_time";
         else if(row.opened_time > 0 && row.resolved_time > 0 && row.opened_time > row.resolved_time)
            reason = "opened_time>resolved_time";
         else if(row.lifecycle_state == MOHY_RUNTIME_LIFECYCLE_RESOLVED &&
                 row.last_event_time > 0 &&
                 row.resolved_time > 0 &&
                 row.last_event_time > row.resolved_time)
            reason = "last_event_time>resolved_time";

         if(reason == "")
            continue;
         state_time_violations++;
         if(state_time_sample == "")
            state_time_sample = StringFormat("setup_key=%s reason=%s",
                                             row.setup_key,
                                             reason);
        }
      if(state_time_sample == "")
         state_time_sample = "ok";
     }
   AppendAssertion(out_assertions,
                   "STATE_TIME_ORDER_VALID",
                   (state_time_violations == 0),
                   state_time_violations,
                   state_time_sample);

   int event_sequence_violations = 0;
   string event_sequence_sample = "not-evaluated:no-event-data";
   if(event_count > 0)
     {
      event_sequence_sample = "";
      long previous_sequence = 0;
      for(int i = 0; i < event_count; ++i)
        {
         if(i > 0 && event_rows[i].sequence_no <= previous_sequence)
           {
            event_sequence_violations++;
            if(event_sequence_sample == "")
               event_sequence_sample = StringFormat("row=%d prev=%I64d current=%I64d",
                                                    i,
                                                    previous_sequence,
                                                    event_rows[i].sequence_no);
           }
         previous_sequence = event_rows[i].sequence_no;
        }
      if(event_sequence_sample == "")
         event_sequence_sample = "ok";
     }
   AppendAssertion(out_assertions,
                   "EVENT_SEQUENCE_INCREASING",
                   (event_sequence_violations == 0),
                   event_sequence_violations,
                   event_sequence_sample);

   int event_scope_violations = 0;
   string event_scope_sample = "not-evaluated:no-event-data";
   if(event_count > 0)
     {
      event_scope_sample = "";
      for(int i = 0; i < event_count; ++i)
        {
         if(event_rows[i].scope_tag == scope_tag)
            continue;
         event_scope_violations++;
         if(event_scope_sample == "")
            event_scope_sample = StringFormat("sequence=%I64d event_scope=%s expected=%s",
                                              event_rows[i].sequence_no,
                                              event_rows[i].scope_tag,
                                              scope_tag);
        }
      if(event_scope_sample == "")
         event_scope_sample = "ok";
     }
   AppendAssertion(out_assertions,
                   "EVENT_SCOPE_MATCH",
                   (event_scope_violations == 0),
                   event_scope_violations,
                   event_scope_sample);

   int event_id_violations = 0;
   string event_id_sample = "not-evaluated:no-event-data";
   if(event_count > 0)
     {
      event_id_sample = "";
      for(int i = 0; i < event_count; ++i)
        {
         if(event_rows[i].setup_key != "" &&
            event_rows[i].impulse_id != "" &&
            event_rows[i].symbol != "" &&
            event_rows[i].scope_tag != "")
            continue;
         event_id_violations++;
         if(event_id_sample == "")
            event_id_sample = StringFormat("sequence=%I64d setup_key=%s impulse_id=%s symbol=%s scope=%s",
                                           event_rows[i].sequence_no,
                                           event_rows[i].setup_key,
                                           event_rows[i].impulse_id,
                                           event_rows[i].symbol,
                                           event_rows[i].scope_tag);
        }
      if(event_id_sample == "")
         event_id_sample = "ok";
     }
   AppendAssertion(out_assertions,
                   "EVENT_REQUIRED_IDENTIFIERS",
                   (event_id_violations == 0),
                   event_id_violations,
                   event_id_sample);

   int history_violations = 0;
   string history_sample = "not-evaluated:no-state-data";
   int latest_match_violations = 0;
   string latest_match_sample = "not-evaluated:no-state-data";
   if(state_count > 0)
     {
      history_sample = "";
      latest_match_sample = "";
      for(int i = 0; i < state_count; ++i)
        {
         const MohyRuntimeLifecycleRecord row = state_rows[i];
         const int setup_event_count = CountEventsForSetupKey(event_rows, row.setup_key);
         const int latest_event_index = FindLatestEventIndexBySetupKey(event_rows, row.setup_key);
         string latest_match_reason = "";
         bool latest_match = false;

         if(setup_event_count <= 0 || latest_event_index < 0)
           {
            history_violations++;
            if(history_sample == "")
               history_sample = StringFormat("setup_key=%s has no lifecycle events",
                                             row.setup_key);
           }
         else
            latest_match = MatchStateToEvent(row, event_rows[latest_event_index], latest_match_reason);

         if(setup_event_count > 0 && latest_event_index >= 0 && !latest_match)
           {
            latest_match_violations++;
            if(latest_match_sample == "")
               latest_match_sample = StringFormat("setup_key=%s mismatch=%s sequence=%I64d",
                                                  row.setup_key,
                                                  latest_match_reason,
                                                  event_rows[latest_event_index].sequence_no);
           }

         MohyRlDetailRow detail;
         detail.setup_key = row.setup_key;
         detail.impulse_id = row.impulse_id;
         detail.state_lifecycle_state = MohyRuntimeLifecycleStateToString(row.lifecycle_state);
         detail.state_last_event_type = MohyEngineEventTypeToString(row.last_event_type);
         detail.state_last_reason_code = row.last_reason_code;
         detail.state_last_event_time = row.last_event_time;
         detail.state_waiting_since = row.waiting_since;
         detail.state_opened_time = row.opened_time;
         detail.state_resolved_time = row.resolved_time;
         detail.event_count = setup_event_count;
         detail.latest_event_sequence_no = (latest_event_index >= 0) ? event_rows[latest_event_index].sequence_no : 0;
         detail.latest_event_lifecycle_state = (latest_event_index >= 0) ? event_rows[latest_event_index].lifecycle_state : "";
         detail.latest_event_last_event_type = (latest_event_index >= 0) ? event_rows[latest_event_index].last_event_type : "";
         detail.latest_event_timestamp = (latest_event_index >= 0) ? event_rows[latest_event_index].timestamp : 0;
         detail.latest_event_match = latest_match;
         detail.waiting_file_match = true;
         detail.position_file_match = true;
         detail.notes = (latest_event_index >= 0)
                        ? (latest_match ? "latest_event_match=ok" : ("latest_event_match=" + latest_match_reason))
                        : "latest_event_missing";
         AppendDetail(out_details, detail);
        }
      if(history_sample == "")
         history_sample = "ok";
      if(latest_match_sample == "")
         latest_match_sample = "ok";
     }
   AppendAssertion(out_assertions,
                   "STATE_HAS_EVENT_HISTORY",
                   (history_violations == 0),
                   history_violations,
                   history_sample);
   AppendAssertion(out_assertions,
                   "LATEST_EVENT_MATCHES_STATE",
                   (latest_match_violations == 0),
                   latest_match_violations,
                   latest_match_sample);

   int waiting_violations = 0;
   string waiting_sample = "no-waiting-file";
   if(waiting_file_exists)
     {
      waiting_sample = "";
      if(!has_waiting_state)
        {
         waiting_violations++;
         waiting_sample = "waiting_state.csv unreadable or empty";
        }
      else
        {
         const int waiting_index =
            FindStateIndexBySetupKeyAndLifecycle(state_rows,
                                                 waiting_state.setup_key,
                                                 MOHY_RUNTIME_LIFECYCLE_WAITING);
         if(waiting_index < 0)
           {
            waiting_violations++;
            waiting_sample = StringFormat("waiting_state setup_key=%s missing from lifecycle_state WAITING rows",
                                          waiting_state.setup_key);
           }
         else
           {
            string waiting_reason = "";
            if(!MatchWaitingStateToLifecycle(waiting_state, state_rows[waiting_index], waiting_reason))
              {
               waiting_violations++;
               waiting_sample = StringFormat("setup_key=%s mismatch=%s",
                                             waiting_state.setup_key,
                                             waiting_reason);
              }
            for(int i = 0; i < ArraySize(out_details); ++i)
               if(out_details[i].setup_key == waiting_state.setup_key)
                 {
                  out_details[i].waiting_file_match = (waiting_reason == "");
                  if(waiting_reason != "")
                     out_details[i].notes += "|waiting_file=" + waiting_reason;
                 }
           }
        }
     }
   else if(waiting_rows > 0)
     {
      waiting_violations++;
      waiting_sample = StringFormat("lifecycle_state has %d WAITING row(s) but waiting_state.csv is missing",
                                    waiting_rows);
     }
   AppendAssertion(out_assertions,
                   "WAITING_FILE_PARITY",
                   (waiting_violations == 0),
                   waiting_violations,
                   waiting_sample == "" ? "ok" : waiting_sample);

   int position_violations = 0;
   string position_sample = "no-position-file";
   if(position_file_exists)
     {
      position_sample = "";
      if(!has_position_state)
        {
         position_violations++;
         position_sample = "tracked_position.csv unreadable or does not describe an open trade";
        }
      else
        {
         const int position_index =
            FindStateIndexBySetupKeyAndLifecycle(state_rows,
                                                 position_state.setup_key,
                                                 MOHY_RUNTIME_LIFECYCLE_OPEN);
         if(position_index < 0)
           {
            position_violations++;
            position_sample = StringFormat("tracked_position setup_key=%s missing from lifecycle_state OPEN rows",
                                           position_state.setup_key);
           }
         else
           {
            string position_reason = "";
            if(!MatchPositionStateToLifecycle(position_state, state_rows[position_index], position_reason))
              {
               position_violations++;
               position_sample = StringFormat("setup_key=%s mismatch=%s",
                                              position_state.setup_key,
                                              position_reason);
              }
            for(int i = 0; i < ArraySize(out_details); ++i)
               if(out_details[i].setup_key == position_state.setup_key)
                 {
                  out_details[i].position_file_match = (position_reason == "");
                  if(position_reason != "")
                     out_details[i].notes += "|position_file=" + position_reason;
                 }
           }
        }
     }
   else if(open_rows > 0)
     {
      position_violations++;
      position_sample = StringFormat("lifecycle_state has %d OPEN row(s) but tracked_position.csv is missing",
                                     open_rows);
     }
   AppendAssertion(out_assertions,
                   "POSITION_FILE_PARITY",
                   (position_violations == 0),
                   position_violations,
                   position_sample == "" ? "ok" : position_sample);
  }

bool WriteDetailsCsv(const string path,
                     const string run_id,
                     const string scope_tag,
                     const bool lifecycle_state_file_exists,
                     const bool lifecycle_events_file_exists,
                     const bool waiting_file_exists,
                     const bool position_file_exists,
                     const MohyRlDetailRow &rows[])
  {
   const int handle = FileOpen(path, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("MOHY | RL_PARITY | Failed to open details CSV: %s (err=%d)",
                  path,
                  GetLastError());
      return false;
     }

   FileWrite(handle,
             "run_id",
             "scope_tag",
             "row_type",
             "setup_key",
             "impulse_id",
             "state_lifecycle_state",
             "state_last_event_type",
             "state_last_reason_code",
             "state_last_event_time",
             "state_waiting_since",
             "state_opened_time",
             "state_resolved_time",
             "event_count",
             "latest_event_sequence_no",
             "latest_event_lifecycle_state",
             "latest_event_last_event_type",
             "latest_event_timestamp",
             "latest_event_match",
             "waiting_file_match",
             "position_file_match",
             "notes");

   FileWrite(handle,
             run_id,
             scope_tag,
             "summary",
             "",
             "",
             "",
             "",
             "",
             "",
             "",
             "",
             "",
             ArraySize(rows),
             0,
             "",
             "",
             "",
             lifecycle_state_file_exists ? "1" : "0",
             lifecycle_events_file_exists ? "1" : "0",
             StringFormat("waiting_file=%d position_file=%d",
                          waiting_file_exists ? 1 : 0,
                          position_file_exists ? 1 : 0));

   for(int i = 0; i < ArraySize(rows); ++i)
      FileWrite(handle,
                run_id,
                scope_tag,
                "setup",
                rows[i].setup_key,
                rows[i].impulse_id,
                rows[i].state_lifecycle_state,
                rows[i].state_last_event_type,
                rows[i].state_last_reason_code,
                TimeText(rows[i].state_last_event_time),
                TimeText(rows[i].state_waiting_since),
                TimeText(rows[i].state_opened_time),
                TimeText(rows[i].state_resolved_time),
                rows[i].event_count,
                IntegerToString((int)rows[i].latest_event_sequence_no),
                rows[i].latest_event_lifecycle_state,
                rows[i].latest_event_last_event_type,
                TimeText(rows[i].latest_event_timestamp),
                rows[i].latest_event_match ? "1" : "0",
                rows[i].waiting_file_match ? "1" : "0",
                rows[i].position_file_match ? "1" : "0",
                rows[i].notes);

   FileClose(handle);
   return true;
  }

bool WriteAssertionsCsv(const string path,
                        const string run_id,
                        const string scope_tag,
                        const MohyRlAssertionRow &rows[])
  {
   const int handle = FileOpen(path, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("MOHY | RL_PARITY | Failed to open assertions CSV: %s (err=%d)",
                  path,
                  GetLastError());
      return false;
     }

   FileWrite(handle,
             "run_id",
             "scope_tag",
             "rule_id",
             "pass",
             "violation_count",
             "sample");

   for(int i = 0; i < ArraySize(rows); ++i)
      FileWrite(handle,
                run_id,
                scope_tag,
                rows[i].rule_id,
                rows[i].pass ? "1" : "0",
                rows[i].violation_count,
                rows[i].sample);

   FileClose(handle);
   return true;
  }

void OnStart()
  {
   string symbol = "";
   string scope_error = "";
   const string scope_tag = ResolveScopeTag(symbol, scope_error);
   if(scope_tag == "")
     {
      PrintFormat("MOHY | RL_PARITY | Scope resolution failed: %s", scope_error);
      return;
     }

   string run_id = TrimText(VerificationRunId);
   if(run_id == "")
      run_id = StringFormat("RL_PARITY_%s_%s",
                            MohyRuntimeSanitizeToken(scope_tag),
                            BuildTimestampToken(TimeCurrent()));
   run_id = MohyRuntimeSanitizeToken(run_id);

   const string lifecycle_state_path = MohyRuntimeBuildRuntimePath(scope_tag, "lifecycle_state.csv");
   const string lifecycle_events_path = MohyRuntimeBuildRuntimePath(scope_tag, "lifecycle_events.csv");
   const string waiting_path = MohyRuntimeBuildRuntimePath(scope_tag, "waiting_state.csv");
   const string position_path = MohyRuntimeBuildRuntimePath(scope_tag, "tracked_position.csv");

   const bool lifecycle_state_file_exists = FileIsExist(lifecycle_state_path);
   const bool lifecycle_events_file_exists = FileIsExist(lifecycle_events_path);
   const bool waiting_file_exists = FileIsExist(waiting_path);
   const bool position_file_exists = FileIsExist(position_path);

   CMohyRuntimeStore runtime_store;
   runtime_store.Configure(scope_tag);

   MohyRuntimeLifecycleRecord lifecycle_rows[];
   runtime_store.LoadLifecycleRecords(lifecycle_rows);

   MohyRlLifecycleEventRow lifecycle_event_rows[];
   LoadLifecycleEvents(scope_tag, lifecycle_event_rows);

   SetupState waiting_state;
   const bool has_waiting_state = runtime_store.LoadWaitingState(waiting_state);

   PositionManagementState position_state;
   const bool has_position_state = runtime_store.LoadTrackedPosition(position_state);

   MohyRlAssertionRow assertions[];
   MohyRlDetailRow details[];
   EvaluateAssertions(scope_tag,
                      lifecycle_state_file_exists,
                      lifecycle_events_file_exists,
                      waiting_file_exists,
                      position_file_exists,
                      lifecycle_rows,
                      lifecycle_event_rows,
                      has_waiting_state,
                      waiting_state,
                      has_position_state,
                      position_state,
                      assertions,
                      details);

   string details_path = "";
   string assertions_path = "";
   if(VerificationWriteDetailsCsv || VerificationWriteAssertionsCsv)
     {
      const string output_dir = MohyRuntimeNormalizeDirectoryPath(VerificationOutputDirectory);
      if(!MohyRuntimeEnsureDirectory(output_dir))
        {
         PrintFormat("MOHY | RL_PARITY | Failed to ensure output directory: %s", output_dir);
         return;
        }
      details_path = StringFormat("%s\\%s__details.csv", output_dir, run_id);
      assertions_path = StringFormat("%s\\%s__assertions.csv", output_dir, run_id);
     }

   if(VerificationWriteDetailsCsv &&
      !WriteDetailsCsv(details_path,
                       run_id,
                       scope_tag,
                       lifecycle_state_file_exists,
                       lifecycle_events_file_exists,
                       waiting_file_exists,
                       position_file_exists,
                       details))
      return;

   if(VerificationWriteAssertionsCsv &&
      !WriteAssertionsCsv(assertions_path, run_id, scope_tag, assertions))
      return;

   for(int i = 0; i < ArraySize(assertions); ++i)
      PrintFormat("MOHY | RL_PARITY | Assertion %s pass=%s violations=%d sample=%s",
                  assertions[i].rule_id,
                  assertions[i].pass ? "true" : "false",
                  assertions[i].violation_count,
                  assertions[i].sample);

   PrintFormat("MOHY | RL_PARITY | Completed run_id=%s scope=%s symbol=%s state_rows=%d event_rows=%d details_csv=%s assertions_csv=%s",
               run_id,
               scope_tag,
               symbol,
               ArraySize(lifecycle_rows),
               ArraySize(lifecycle_event_rows),
               details_path,
               assertions_path);
  }
