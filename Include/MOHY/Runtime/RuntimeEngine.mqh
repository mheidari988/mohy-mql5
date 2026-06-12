#ifndef __MOHY_RUNTIME_ENGINE_MQH__
#define __MOHY_RUNTIME_ENGINE_MQH__

#include <Trade/Trade.mqh>
#include <MOHY/Core/PriceActionKernel.mqh>
#include <MOHY/Core/Builders/TradeSetupPlanner.mqh>
#include <MOHY/Core/Compat/TerminalSeries.mqh>
#include <MOHY/Core/Domain/SnapshotSelectors.mqh>
#include <MOHY/Runtime/RuntimeIdentity.mqh>
#include <MOHY/Runtime/RuntimeStore.mqh>
#include <MOHY/Runtime/RuntimeLogger.mqh>
#include <MOHY/Runtime/RuntimeAudit.mqh>
#include <MOHY/Runtime/RuntimePanel.mqh>

class CMohyRuntimeEngine
  {
private:
   StrategyConfig            m_cfg;
   string                    m_symbol;
   int                       m_lookback_bars;
   bool                      m_panel_enabled;
   int                       m_panel_corner;
   int                       m_panel_x;
   int                       m_panel_y;
   string                    m_scope_tag;
   bool                      m_paused;
   bool                      m_blocked_multi_position;
   string                    m_last_action_result;
   datetime                  m_last_closed_bar_time;
   bool                      m_initialized;
   UiActionIntent            m_pending_ui_action;
   MohyUiActionId            m_last_dangerous_action_id;
   datetime                  m_last_dangerous_action_time;
   string                    m_last_panel_snapshot_hash;
   uint                      m_last_panel_redraw_ms;
   bool                      m_multi_position_alerted;
   MohyRuntimeRoleMode       m_runtime_role;

   SetupState                m_waiting_state;
   PositionManagementState   m_position_state;
   MohyRuntimeConsumedImpulse m_consumed_impulses[];
   MohyRuntimeLifecycleRecord m_lifecycle_records[];

   CMohyPriceActionKernel    m_kernel;
   CMohyTradeSetupPlanner    m_planner;
   CTrade                    m_trade;
   CMohyRuntimeStore          m_store;
   CMohyRuntimeLogger         m_logger;
   CMohyRuntimeAudit          m_audit;
   CMohyRuntimePanel          m_panel;

   double Eps() const
     {
      return 1e-10;
     }

   double SymbolPoint() const
     {
      double point = 0.0;
      if(SymbolInfoDouble(m_symbol, SYMBOL_POINT, point) && point > 0.0)
         return point;
      return 0.00001;
     }

   double NormalizePrice(const double price) const
     {
      long digits = 5;
      if(SymbolInfoInteger(m_symbol, SYMBOL_DIGITS, digits) && digits >= 0)
         return NormalizeDouble(price, (int)digits);
      return price;
     }

   bool ReadTick(MqlTick &out_tick) const
     {
      ZeroMemory(out_tick);
      return SymbolInfoTick(m_symbol, out_tick);
     }

   double ResolveReferencePrice(const MohyDirection direction,
                                const MqlTick &tick) const
     {
      if(direction == MOHY_DIR_BEAR)
         return tick.bid;
      return tick.bid;
     }

   double ResolveExitPrice(const MohyDirection direction,
                           const MqlTick &tick) const
     {
      if(direction == MOHY_DIR_BEAR)
         return tick.ask;
      return tick.bid;
     }

   void CopyManagementFields(PositionManagementState &dst,
                             const PositionManagementState &src) const
     {
       dst.execution_mode = src.execution_mode;
      dst.break_even_armed = src.break_even_armed;
      dst.break_even_active = src.break_even_active;
      dst.break_even_level = src.break_even_level;
      dst.break_even_applied_to_broker = src.break_even_applied_to_broker;
      dst.break_even_retry_count = src.break_even_retry_count;
      dst.virtual_stop_active = src.virtual_stop_active;
      dst.virtual_stop_level = src.virtual_stop_level;
      dst.post_be_profile = src.post_be_profile;
      dst.post_be_started = src.post_be_started;
      dst.post_be_started_time = src.post_be_started_time;
      dst.post_be_start_reason = src.post_be_start_reason;
       dst.partial_1_done = src.partial_1_done;
       dst.partial_2_done = src.partial_2_done;
       dst.partial_3_done = src.partial_3_done;
       dst.partial_progress_percent = src.partial_progress_percent;
       dst.entry_price = src.entry_price;
       dst.initial_lots = src.initial_lots;
       dst.initial_stop_loss = src.initial_stop_loss;
       dst.target_price = src.target_price;
       dst.initial_risk_points = src.initial_risk_points;
       dst.impulse_extreme_reference = src.impulse_extreme_reference;
       dst.anchors_ready = src.anchors_ready;
      dst.impulse_high_anchor = src.impulse_high_anchor;
      dst.impulse_low_anchor = src.impulse_low_anchor;
      dst.correction_high_anchor = src.correction_high_anchor;
      dst.correction_low_anchor = src.correction_low_anchor;
      dst.runner_trail_only_active = src.runner_trail_only_active;
       dst.runner_tp_removed = src.runner_tp_removed;
       dst.last_trail_update_time = src.last_trail_update_time;
       dst.last_favorable_extreme = src.last_favorable_extreme;
       dst.opened_time = src.opened_time;
       dst.last_management_action_time = src.last_management_action_time;
       dst.last_management_action = src.last_management_action;
      }

   void StampManagementAction(const string action)
     {
      m_position_state.last_management_action_time = TimeCurrent();
      m_position_state.last_management_action = action;
      PersistTrackedPosition();
     }

   void SetLastAction(const string value)
     {
      m_last_action_result = value;
     }

   void ResetPendingUiAction()
     {
      m_pending_ui_action.action_id = MOHY_UI_ACTION_NONE;
      m_pending_ui_action.correlation_id = "";
      m_pending_ui_action.pre_state_hash = "";
      m_pending_ui_action.accepted_at = 0;
     }

   bool PendingUiActionActive() const
     {
      return (m_pending_ui_action.action_id != MOHY_UI_ACTION_NONE);
     }

   int UiActionWindowSeconds() const
     {
      return MathMax(1, m_cfg.ui.dangerous_action_cooldown_seconds);
     }

   bool IsDangerousUiAction(const MohyUiActionId action_id) const
     {
      return (action_id == MOHY_UI_ACTION_CANCEL_WAITING_ENTRIES ||
              action_id == MOHY_UI_ACTION_CLOSE_STRATEGY_TRADES ||
              action_id == MOHY_UI_ACTION_EMERGENCY_FLATTEN);
     }

   int PendingUiActionRemainingSeconds() const
     {
      if(!PendingUiActionActive() || m_pending_ui_action.accepted_at <= 0)
         return 0;

      const int elapsed = (int)(TimeCurrent() - m_pending_ui_action.accepted_at);
      return MathMax(0, UiActionWindowSeconds() - elapsed);
     }

   int DangerousActionCooldownRemainingSeconds() const
     {
      if(m_last_dangerous_action_id == MOHY_UI_ACTION_NONE ||
         m_last_dangerous_action_time <= 0)
         return 0;

      const int elapsed = (int)(TimeCurrent() - m_last_dangerous_action_time);
      return MathMax(0, UiActionWindowSeconds() - elapsed);
     }

   void MarkDangerousActionAttempted(const MohyUiActionId action_id)
     {
      m_last_dangerous_action_id = action_id;
      m_last_dangerous_action_time = TimeCurrent();
     }

   string BuildUiStateHash() const
     {
      uint hash = MohyRuntimeHashBegin();
      hash = MohyRuntimeHashUpdate(hash, m_scope_tag);
      hash = MohyRuntimeHashUpdate(hash, m_symbol);
      hash = MohyRuntimeHashUpdate(hash, m_paused ? "paused" : "active");
      hash = MohyRuntimeHashUpdate(hash, m_blocked_multi_position ? "blocked" : "normal");
      hash = MohyRuntimeHashUpdate(hash, m_waiting_state.setup_key);
      hash = MohyRuntimeHashUpdate(hash, m_waiting_state.impulse_id);
      hash = MohyRuntimeHashUpdate(hash, IntegerToString((int)m_waiting_state.lifecycle_phase));
      hash = MohyRuntimeHashUpdate(hash, DoubleToString(m_waiting_state.trigger_price, 10));
      hash = MohyRuntimeHashUpdate(hash, IntegerToString(m_waiting_state.pending_ticket));
      hash = MohyRuntimeHashUpdate(hash, IntegerToString((int)m_waiting_state.invalidation_reason));
      hash = MohyRuntimeHashUpdate(hash, m_position_state.has_open_trade ? "trade" : "flat");
      hash = MohyRuntimeHashUpdate(hash, IntegerToString(m_position_state.ticket));
      hash = MohyRuntimeHashUpdate(hash, m_position_state.setup_key);
      hash = MohyRuntimeHashUpdate(hash, m_position_state.impulse_id);
      hash = MohyRuntimeHashUpdate(hash, IntegerToString((int)m_position_state.trade_phase));
      hash = MohyRuntimeHashUpdate(hash, MohyRuntimeBoolToString(m_position_state.break_even_active));
      hash = MohyRuntimeHashUpdate(hash, MohyRuntimeBoolToString(m_position_state.post_be_started));
      hash = MohyRuntimeHashUpdate(hash, MohyRuntimeBoolToString(m_position_state.partial_1_done));
      hash = MohyRuntimeHashUpdate(hash, MohyRuntimeBoolToString(m_position_state.partial_2_done));
      hash = MohyRuntimeHashUpdate(hash, MohyRuntimeBoolToString(m_position_state.partial_3_done));
      hash = MohyRuntimeHashUpdate(hash, DoubleToString(m_position_state.partial_progress_percent, 10));
      hash = MohyRuntimeHashUpdate(hash, MohyRuntimeBoolToString(m_position_state.runner_trail_only_active));
      hash = MohyRuntimeHashUpdate(hash, m_position_state.last_management_action);
      hash = MohyRuntimeHashUpdate(hash, m_last_action_result);
      return MohyRuntimeHashHex(hash);
     }

   string BuildUiCorrelationId(const MohyUiActionId action_id,
                               const string pre_state_hash) const
     {
      uint hash = MohyRuntimeHashBegin();
      hash = MohyRuntimeHashUpdate(hash, MohyUiActionIdToString(action_id));
      hash = MohyRuntimeHashUpdate(hash, IntegerToString((int)TimeCurrent()));
      hash = MohyRuntimeHashUpdate(hash, pre_state_hash);
      return StringFormat("%s_%d_%s",
                          MohyUiActionIdToString(action_id),
                          (int)TimeCurrent(),
                          MohyRuntimeHashHex(hash));
     }

   string BuildPanelHash(const UiRuntimeSnapshot &snapshot) const
     {
      uint hash = MohyRuntimeHashBegin();
      hash = MohyRuntimeHashUpdate(hash, snapshot.symbol);
      hash = MohyRuntimeHashUpdate(hash, snapshot.execution_mode);
      hash = MohyRuntimeHashUpdate(hash, snapshot.pause_state);
      hash = MohyRuntimeHashUpdate(hash, snapshot.setup_key);
      hash = MohyRuntimeHashUpdate(hash, snapshot.impulse_id);
      hash = MohyRuntimeHashUpdate(hash, snapshot.strategy_phase);
      hash = MohyRuntimeHashUpdate(hash, snapshot.position_state);
      hash = MohyRuntimeHashUpdate(hash, snapshot.trigger_state);
      hash = MohyRuntimeHashUpdate(hash, snapshot.break_even_state);
      hash = MohyRuntimeHashUpdate(hash, snapshot.trailing_state);
      hash = MohyRuntimeHashUpdate(hash, snapshot.partial_progress_state);
      hash = MohyRuntimeHashUpdate(hash, snapshot.potential_impulse_state);
      hash = MohyRuntimeHashUpdate(hash, snapshot.potential_correction_state);
      hash = MohyRuntimeHashUpdate(hash, snapshot.confirmation_state);
      hash = MohyRuntimeHashUpdate(hash, snapshot.last_management_action_result);
      hash = MohyRuntimeHashUpdate(hash, snapshot.last_action_result);
      return MohyRuntimeHashHex(hash);
     }

   void RecordUiAudit(const string stage,
                      const MohyUiActionId action_id,
                      const string correlation_id,
                      const string pre_state_hash,
                      const string post_state_hash,
                      const MohyUiResultCode result_code,
                      const MohyUiAlertEventType severity,
                      const int broker_error,
                      const string message)
     {
      m_audit.LogUiAction(m_cfg,
                          m_symbol,
                          stage,
                          action_id,
                          correlation_id,
                          pre_state_hash,
                          post_state_hash,
                          result_code,
                          severity,
                          broker_error,
                          message,
                          "RuntimeEngine");
     }

   void EmitRuntimeAlert(const MohyUiAlertEventType severity,
                         const string alert_key,
                         const string message)
     {
      m_audit.EmitAlert(severity, alert_key, message);
     }

   void ExpirePendingUiActionIfNeeded()
     {
      if(!PendingUiActionActive() || PendingUiActionRemainingSeconds() > 0)
         return;

      RecordUiAudit("Expired",
                    m_pending_ui_action.action_id,
                    m_pending_ui_action.correlation_id,
                    m_pending_ui_action.pre_state_hash,
                    BuildUiStateHash(),
                    MOHY_UI_RESULT_CONFIRMATION_EXPIRED,
                    MohyUiSeverityFromResultCode(MOHY_UI_RESULT_CONFIRMATION_EXPIRED),
                    0,
                    "ConfirmationExpired");
      SetLastAction(StringFormat("%sExpired",
                                 MohyUiActionIdToString(m_pending_ui_action.action_id)));
      ResetPendingUiAction();
     }

   string ResolveConfirmationState() const
     {
      if(PendingUiActionActive())
         return StringFormat("Confirm %s (%ds)",
                             MohyUiActionIdToString(m_pending_ui_action.action_id),
                             PendingUiActionRemainingSeconds());

      const int cooldown_remaining = DangerousActionCooldownRemainingSeconds();
      if(cooldown_remaining > 0 && m_last_dangerous_action_id != MOHY_UI_ACTION_NONE)
         return StringFormat("Cooldown %s (%ds)",
                             MohyUiActionIdToString(m_last_dangerous_action_id),
                             cooldown_remaining);

      return "Ready";
     }

   bool HasWaitingState() const
     {
      return (m_waiting_state.setup_key != "");
     }

   bool IsExecutionAuthorityEnabled() const
     {
      return (m_runtime_role == MOHY_RUNTIME_ROLE_GLOBAL_LIVE);
     }

   void PersistPauseFlag()
     {
      m_store.SavePauseFlag(m_paused);
     }

   void PersistTrackedPosition()
     {
      if(m_position_state.has_open_trade)
         m_store.SaveTrackedPosition(m_position_state);
      else
         m_store.ClearTrackedPosition();
     }

   void PersistWaitingState()
     {
      if(HasWaitingState())
         m_store.SaveWaitingState(m_waiting_state);
      else
         m_store.ClearWaitingState();
     }

   bool ResolveLifecycleRecord(const string setup_key,
                               MohyRuntimeLifecycleRecord &out_record) const
     {
      MohyResetRuntimeLifecycleRecord(out_record);
      if(setup_key == "")
         return false;

      const int index = m_store.FindLifecycleRecord(m_lifecycle_records, setup_key);
      if(index < 0)
         return false;

      out_record = m_lifecycle_records[index];
      return true;
     }

   void PopulateLifecycleMetadata(MohyRuntimeLifecycleRecord &record,
                                  const string setup_key,
                                  const string impulse_id,
                                  const MohyDirection direction,
                                  const MohyEntryExecutionMode execution_mode) const
     {
      if(record.schema_version == "")
         MohyResetRuntimeLifecycleRecord(record);

      record.schema_version = "runtime_lifecycle_v1";
      record.setup_key = setup_key;
      record.impulse_id = impulse_id;
      record.symbol = m_symbol;
      record.scope_tag = m_scope_tag;
      record.context_timeframe = MohyTimeframeToString(m_cfg.context_timeframe);
      record.execution_timeframe = MohyTimeframeToString(m_cfg.execution_timeframe);
      record.config_hash = MohyRuntimeBuildConfigHash(m_cfg);
      record.direction = direction;
      record.execution_mode = execution_mode;
     }

   string CombineDiagnostics(const string primary,
                             const string secondary) const
     {
      if(primary == "")
         return secondary;
      if(secondary == "")
         return primary;
      return StringFormat("%s | %s", primary, secondary);
     }

   bool ResolveExitDeal(const int position_ticket,
                        const datetime opened_time,
                        datetime &out_time,
                        double &out_price,
                        string &out_diagnostics) const
     {
      out_time = 0;
      out_price = 0.0;
      out_diagnostics = "";
      if(position_ticket <= 0)
         return false;

      datetime from_time = TimeCurrent() - 2592000;
      if(opened_time > 0)
         from_time = MathMax((datetime)0, opened_time - 300);
      if(!HistorySelect(from_time, TimeCurrent() + 60))
         return false;

      const int total = (int)HistoryDealsTotal();
      for(int i = total - 1; i >= 0; --i)
        {
         const ulong deal_ticket = HistoryDealGetTicket(i);
         if(deal_ticket == 0)
            continue;
         if(HistoryDealGetString(deal_ticket, DEAL_SYMBOL) != m_symbol)
            continue;
         if((int)HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID) != position_ticket)
            continue;

         const long entry = HistoryDealGetInteger(deal_ticket, DEAL_ENTRY);
         if(entry != DEAL_ENTRY_OUT &&
            entry != DEAL_ENTRY_OUT_BY &&
            entry != DEAL_ENTRY_INOUT)
            continue;

         out_time = (datetime)HistoryDealGetInteger(deal_ticket, DEAL_TIME);
         out_price = HistoryDealGetDouble(deal_ticket, DEAL_PRICE);
         out_diagnostics = StringFormat("ExitDeal#%I64u", deal_ticket);
         return true;
        }

      return false;
     }

   void PublishLifecycleRecord(const MohyRuntimeLifecycleRecord &record)
     {
      if(record.setup_key == "")
         return;
      if(!m_store.UpsertLifecycleRecord(m_lifecycle_records, record))
         return;
      m_logger.LogLifecycleRecord(m_cfg, record, "RuntimeEngine");
     }

   void PublishWaitingLifecycle(const MohyEngineEventType event_type,
                                const string reason_code,
                                const datetime event_time,
                                const double trigger_price,
                                const string diagnostics)
     {
      if(!HasWaitingState() || m_waiting_state.setup_key == "")
         return;

      MohyRuntimeLifecycleRecord record;
      ResolveLifecycleRecord(m_waiting_state.setup_key, record);
      PopulateLifecycleMetadata(record,
                                m_waiting_state.setup_key,
                                m_waiting_state.impulse_id,
                                m_waiting_state.direction,
                                m_waiting_state.trigger_mode);
      record.lifecycle_state = MOHY_RUNTIME_LIFECYCLE_WAITING;
      record.setup_phase = m_waiting_state.lifecycle_phase;
      record.trade_phase = MOHY_TRADE_PHASE_NONE;
      record.recovered = false;
      record.last_event_type = event_type;
      record.last_reason_code = reason_code;
      record.last_event_time = (event_time > 0) ? event_time : TimeCurrent();
      record.waiting_since = m_waiting_state.waiting_since;
      record.trigger_price = (m_waiting_state.trigger_price > 0.0)
                             ? m_waiting_state.trigger_price
                             : trigger_price;
      record.pending_placed = m_waiting_state.pending_placed;
      record.pending_ticket = m_waiting_state.pending_ticket;
      record.opened_time = 0;
      record.position_ticket = -1;
      record.entry_price = 0.0;
      record.initial_stop_loss = 0.0;
      record.target_price = 0.0;
      record.break_even_armed = false;
      record.break_even_active = false;
      record.break_even_activated_time = 0;
      record.break_even_level = 0.0;
      record.post_be_started = false;
      record.post_be_started_time = 0;
      record.post_be_start_reason = MOHY_POST_BE_START_REASON_NONE;
      record.partial_1_done = false;
      record.partial_2_done = false;
      record.partial_3_done = false;
      record.partial_progress_percent = 0.0;
      record.runner_trail_only_active = false;
      record.runner_tp_removed = false;
      record.last_trail_update_time = 0;
      record.last_management_action = "";
      record.resolved_time = 0;
      record.resolution_event_type = MOHY_ENGINE_EVENT_NONE;
      record.resolution_reason_code = "";
      record.resolution_price = 0.0;
      record.resolution_diagnostics = diagnostics;
      PublishLifecycleRecord(record);
     }

   void PublishOpenLifecycle(const MohyEngineEventType event_type,
                             const string reason_code,
                             const datetime event_time,
                             const string diagnostics)
     {
      if(!m_position_state.has_open_trade || m_position_state.setup_key == "")
         return;

      MohyRuntimeLifecycleRecord record;
      ResolveLifecycleRecord(m_position_state.setup_key, record);
      const bool had_break_even_active = record.break_even_active;
      PopulateLifecycleMetadata(record,
                                m_position_state.setup_key,
                                m_position_state.impulse_id,
                                m_position_state.direction,
                                m_position_state.execution_mode);
      record.lifecycle_state = MOHY_RUNTIME_LIFECYCLE_OPEN;
      record.setup_phase = MOHY_SETUP_ENTERED;
      record.trade_phase = m_position_state.trade_phase;
      record.recovered = m_position_state.recovered;
      record.last_event_type = event_type;
      record.last_reason_code = reason_code;
      record.last_event_time = (event_time > 0) ? event_time : TimeCurrent();
      if(record.waiting_since <= 0 &&
         HasWaitingState() &&
         m_waiting_state.setup_key == m_position_state.setup_key)
         record.waiting_since = m_waiting_state.waiting_since;
      if(record.trigger_price <= 0.0 &&
         HasWaitingState() &&
         m_waiting_state.setup_key == m_position_state.setup_key)
         record.trigger_price = m_waiting_state.trigger_price;
      record.pending_placed = false;
      record.pending_ticket = -1;
      record.opened_time = m_position_state.opened_time;
      record.position_ticket = m_position_state.ticket;
      record.entry_price = m_position_state.entry_price;
      record.initial_stop_loss = m_position_state.initial_stop_loss;
      record.target_price = m_position_state.target_price;
      record.break_even_armed = m_position_state.break_even_armed;
      record.break_even_active = m_position_state.break_even_active;
      if(!had_break_even_active &&
         m_position_state.break_even_active &&
         event_type == MOHY_ENGINE_EVENT_BREAK_EVEN_ACTIVATED)
         record.break_even_activated_time = record.last_event_time;
      record.break_even_level = m_position_state.break_even_level;
      record.post_be_started = m_position_state.post_be_started;
      record.post_be_started_time = m_position_state.post_be_started_time;
      record.post_be_start_reason = m_position_state.post_be_start_reason;
      record.partial_1_done = m_position_state.partial_1_done;
      record.partial_2_done = m_position_state.partial_2_done;
      record.partial_3_done = m_position_state.partial_3_done;
      record.partial_progress_percent = m_position_state.partial_progress_percent;
      record.runner_trail_only_active = m_position_state.runner_trail_only_active;
      record.runner_tp_removed = m_position_state.runner_tp_removed;
      record.last_trail_update_time = m_position_state.last_trail_update_time;
      record.last_management_action = m_position_state.last_management_action;
      record.resolved_time = 0;
      record.resolution_event_type = MOHY_ENGINE_EVENT_NONE;
      record.resolution_reason_code = "";
      record.resolution_price = 0.0;
      record.resolution_diagnostics = diagnostics;
      PublishLifecycleRecord(record);
     }

   void PublishResolvedWaitingLifecycle(const MohyEngineEventType event_type,
                                        const string reason_code,
                                        const datetime resolved_time,
                                        const double resolution_price,
                                        const string diagnostics)
     {
      if(!HasWaitingState() || m_waiting_state.setup_key == "")
         return;

      MohyRuntimeLifecycleRecord record;
      ResolveLifecycleRecord(m_waiting_state.setup_key, record);
      PopulateLifecycleMetadata(record,
                                m_waiting_state.setup_key,
                                m_waiting_state.impulse_id,
                                m_waiting_state.direction,
                                m_waiting_state.trigger_mode);
      const datetime resolved_at = (resolved_time > 0) ? resolved_time : TimeCurrent();
      record.lifecycle_state = MOHY_RUNTIME_LIFECYCLE_RESOLVED;
      record.setup_phase = MOHY_SETUP_INVALIDATED;
      record.trade_phase = MOHY_TRADE_PHASE_NONE;
      record.recovered = false;
      record.last_event_type = event_type;
      record.last_reason_code = reason_code;
      record.last_event_time = resolved_at;
      record.waiting_since = m_waiting_state.waiting_since;
      record.trigger_price = m_waiting_state.trigger_price;
      record.pending_placed = m_waiting_state.pending_placed;
      record.pending_ticket = m_waiting_state.pending_ticket;
      record.opened_time = 0;
      record.position_ticket = -1;
      record.entry_price = 0.0;
      record.initial_stop_loss = 0.0;
      record.target_price = 0.0;
      record.break_even_armed = false;
      record.break_even_active = false;
      record.break_even_activated_time = 0;
      record.break_even_level = 0.0;
      record.post_be_started = false;
      record.post_be_started_time = 0;
      record.post_be_start_reason = MOHY_POST_BE_START_REASON_NONE;
      record.partial_1_done = false;
      record.partial_2_done = false;
      record.partial_3_done = false;
      record.partial_progress_percent = 0.0;
      record.runner_trail_only_active = false;
      record.runner_tp_removed = false;
      record.last_trail_update_time = 0;
      record.last_management_action = "";
      record.resolved_time = resolved_at;
      record.resolution_event_type = event_type;
      record.resolution_reason_code = reason_code;
      record.resolution_price = (resolution_price > 0.0) ? resolution_price : m_waiting_state.trigger_price;
      record.resolution_diagnostics = diagnostics;
      PublishLifecycleRecord(record);
     }

   void PublishResolvedPositionLifecycle(const PositionManagementState &state,
                                         const MohyEngineEventType event_type,
                                         const string reason_code,
                                         const double fallback_resolution_price,
                                         const string diagnostics)
     {
      if(state.setup_key == "")
         return;

      MohyRuntimeLifecycleRecord record;
      ResolveLifecycleRecord(state.setup_key, record);
      PopulateLifecycleMetadata(record,
                                state.setup_key,
                                state.impulse_id,
                                state.direction,
                                state.execution_mode);

      datetime resolved_at = TimeCurrent();
      double resolved_price = fallback_resolution_price;
      string exit_note = "";
      ResolveExitDeal(state.ticket, state.opened_time, resolved_at, resolved_price, exit_note);
      const string resolved_diagnostics = CombineDiagnostics(diagnostics, exit_note);

      record.lifecycle_state = MOHY_RUNTIME_LIFECYCLE_RESOLVED;
      record.setup_phase = MOHY_SETUP_ENTERED;
      record.trade_phase = MOHY_TRADE_PHASE_EXITED;
      record.recovered = state.recovered;
      record.last_event_type = event_type;
      record.last_reason_code = reason_code;
      record.last_event_time = resolved_at;
      record.opened_time = state.opened_time;
      record.position_ticket = state.ticket;
      record.entry_price = state.entry_price;
      record.initial_stop_loss = state.initial_stop_loss;
      record.target_price = state.target_price;
      record.break_even_armed = state.break_even_armed;
      record.break_even_active = state.break_even_active;
      record.break_even_level = state.break_even_level;
      record.post_be_started = state.post_be_started;
      record.post_be_started_time = state.post_be_started_time;
      record.post_be_start_reason = state.post_be_start_reason;
      record.partial_1_done = state.partial_1_done;
      record.partial_2_done = state.partial_2_done;
      record.partial_3_done = state.partial_3_done;
      record.partial_progress_percent = state.partial_progress_percent;
      record.runner_trail_only_active = state.runner_trail_only_active;
      record.runner_tp_removed = state.runner_tp_removed;
      record.last_trail_update_time = state.last_trail_update_time;
      record.last_management_action = state.last_management_action;
      record.pending_placed = false;
      record.pending_ticket = -1;
      record.resolved_time = resolved_at;
      record.resolution_event_type = event_type;
      record.resolution_reason_code = reason_code;
      record.resolution_price = (resolved_price > 0.0) ? resolved_price : fallback_resolution_price;
      record.resolution_diagnostics = resolved_diagnostics;
      PublishLifecycleRecord(record);
     }

   string BuildExecutionComment(const string setup_key) const
     {
      return StringFormat("MOHY_RT_%s",
                          MohyRuntimeHashHex(MohyRuntimeHashUpdate(MohyRuntimeHashBegin(), setup_key)));
     }

   double ResolveVolumeStep() const
     {
      double step = 0.0;
      if(SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP, step) && step > 0.0)
         return step;
      return 0.01;
     }

   bool LotsRequireReplacement(const double current_lots,
                               const double new_lots) const
     {
      return (MathAbs(current_lots - new_lots) + Eps() >= ResolveVolumeStep());
     }

   bool IsPendingOrderType(const ENUM_ORDER_TYPE type) const
     {
      return (type == ORDER_TYPE_BUY_LIMIT ||
              type == ORDER_TYPE_BUY_STOP ||
              type == ORDER_TYPE_SELL_LIMIT ||
              type == ORDER_TYPE_SELL_STOP);
     }

   bool ResolvePendingOrderType(const MohyTradeSetupPlanFact &plan,
                                const MqlTick &tick,
                                ENUM_ORDER_TYPE &out_type) const
     {
      out_type = ORDER_TYPE_BUY_LIMIT;
      if(plan.trigger_price <= 0.0)
         return false;

      if(plan.direction == MOHY_DIR_BULL)
        {
         out_type = (plan.trigger_price <= tick.ask + Eps())
                    ? ORDER_TYPE_BUY_LIMIT
                    : ORDER_TYPE_BUY_STOP;
         return true;
        }
      if(plan.direction == MOHY_DIR_BEAR)
        {
         out_type = (plan.trigger_price >= tick.bid - Eps())
                    ? ORDER_TYPE_SELL_LIMIT
                    : ORDER_TYPE_SELL_STOP;
         return true;
        }
      return false;
     }

   bool HasPendingPlacementRoom(const ENUM_ORDER_TYPE order_type,
                                const double trigger_price,
                                string &out_reason) const
     {
      out_reason = "";
      long stops_level = 0;
      long freeze_level = 0;
      SymbolInfoInteger(m_symbol, SYMBOL_TRADE_STOPS_LEVEL, stops_level);
      SymbolInfoInteger(m_symbol, SYMBOL_TRADE_FREEZE_LEVEL, freeze_level);

      const double min_distance_points = (double)MathMax(stops_level, freeze_level);
      if(min_distance_points <= 0.0)
         return true;

      MqlTick tick;
      if(!ReadTick(tick))
         return false;

      const double point = SymbolPoint();
      const double reference_price = (order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_BUY_STOP)
                                     ? tick.ask
                                     : tick.bid;
      if(MathAbs(trigger_price - reference_price) / point + Eps() < min_distance_points)
        {
         out_reason = StringFormat("PendingDistanceBlocked %.1f", min_distance_points);
         return false;
        }
      return true;
     }

   bool SelectMatchingPendingOrderByTicket(const int ticket,
                                           ENUM_ORDER_TYPE &out_type,
                                           double &out_volume,
                                           double &out_price,
                                           double &out_sl,
                                           double &out_tp) const
     {
      out_type = ORDER_TYPE_BUY_LIMIT;
      out_volume = 0.0;
      out_price = 0.0;
      out_sl = 0.0;
      out_tp = 0.0;
      if(ticket <= 0 || !OrderSelect((ulong)ticket))
         return false;

      const ENUM_ORDER_STATE state = (ENUM_ORDER_STATE)OrderGetInteger(ORDER_STATE);
      if(state == ORDER_STATE_FILLED ||
         state == ORDER_STATE_CANCELED ||
         state == ORDER_STATE_REJECTED ||
         state == ORDER_STATE_EXPIRED)
         return false;

      const string symbol = OrderGetString(ORDER_SYMBOL);
      const long magic = OrderGetInteger(ORDER_MAGIC);
      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(symbol != m_symbol ||
         (m_cfg.risk.magic_number > 0 && magic != (long)m_cfg.risk.magic_number) ||
         !IsPendingOrderType(type))
         return false;

      out_type = type;
      out_volume = OrderGetDouble(ORDER_VOLUME_CURRENT);
      out_price = OrderGetDouble(ORDER_PRICE_OPEN);
      out_sl = OrderGetDouble(ORDER_SL);
      out_tp = OrderGetDouble(ORDER_TP);
      return true;
     }

   bool FindPendingOrderBySetupKey(const string setup_key,
                                   int &out_ticket,
                                   ENUM_ORDER_TYPE &out_type,
                                   double &out_volume,
                                   double &out_price,
                                   double &out_sl,
                                   double &out_tp) const
     {
      out_ticket = -1;
      out_type = ORDER_TYPE_BUY_LIMIT;
      out_volume = 0.0;
      out_price = 0.0;
      out_sl = 0.0;
      out_tp = 0.0;

      const string expected_comment = BuildExecutionComment(setup_key);
      const int total = OrdersTotal();
      for(int i = 0; i < total; ++i)
        {
         const ulong ticket = OrderGetTicket(i);
         if(ticket == 0 || !OrderSelect(ticket))
            continue;

         const string symbol = OrderGetString(ORDER_SYMBOL);
         const long magic = OrderGetInteger(ORDER_MAGIC);
         const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         const string comment = OrderGetString(ORDER_COMMENT);
         if(symbol != m_symbol)
            continue;
         if(m_cfg.risk.magic_number > 0 && magic != (long)m_cfg.risk.magic_number)
            continue;
         if(!IsPendingOrderType(type) || comment != expected_comment)
            continue;

         out_ticket = (int)ticket;
         out_type = type;
         out_volume = OrderGetDouble(ORDER_VOLUME_CURRENT);
         out_price = OrderGetDouble(ORDER_PRICE_OPEN);
         out_sl = OrderGetDouble(ORDER_SL);
         out_tp = OrderGetDouble(ORDER_TP);
         return true;
        }

      return false;
     }

   bool DeletePendingOrder(const int ticket,
                           const string action_reason)
     {
      if(ticket <= 0)
         return true;

      m_trade.SetExpertMagicNumber((ulong)MathMax(0, m_cfg.risk.magic_number));
      if(!m_trade.OrderDelete((ulong)ticket))
        {
         SetLastAction(StringFormat("%sFailed %d", action_reason, (int)m_trade.ResultRetcode()));
         return false;
        }
      return true;
     }

   int FindSelectedPlanIndex(const CMohyPriceActionSnapshot &snapshot) const
     {
      return MohyFindSelectedTradeSetupPlanIndex(snapshot, false);
     }

   int FindPotentialImpulseIndexByRuntimeImpulseId(const CMohyPriceActionSnapshot &snapshot,
                                                   const string impulse_id) const
     {
      return MohyFindPotentialImpulseIndexByRuntimeImpulseId(snapshot, impulse_id);
     }

   int SelectPotentialImpulseIndex(const CMohyPriceActionSnapshot &snapshot) const
     {
      return MohySelectPotentialImpulseIndex(snapshot);
     }

   int FindPotentialCorrectionIndexByRuntimeImpulseId(const CMohyPriceActionSnapshot &snapshot,
                                                      const string impulse_id,
                                                      const bool active_only) const
     {
      return MohyFindPotentialCorrectionIndexByRuntimeImpulseId(snapshot,
                                                                impulse_id,
                                                                active_only);
     }

   int SelectPotentialCorrectionIndex(const CMohyPriceActionSnapshot &snapshot,
                                      const bool active_only) const
     {
      return MohySelectPotentialCorrectionIndex(snapshot, active_only);
     }

   string ResolvePotentialImpulsePanelState(const CMohyPriceActionSnapshot &snapshot,
                                            const string selected_impulse_id,
                                            const bool has_selected_plan,
                                            const MohyTradeSetupPlanFact &selected_plan) const
     {
      int impulse_index = -1;
      if(has_selected_plan &&
         selected_plan.linked_potential_impulse_index >= 0 &&
         selected_plan.linked_potential_impulse_index < ArraySize(snapshot.potential_impulses))
         impulse_index = selected_plan.linked_potential_impulse_index;
      else if(selected_impulse_id != "")
         impulse_index = FindPotentialImpulseIndexByRuntimeImpulseId(snapshot, selected_impulse_id);
      else
         impulse_index = SelectPotentialImpulseIndex(snapshot);

      if(impulse_index < 0 || impulse_index >= ArraySize(snapshot.potential_impulses))
         return "n/a";

      const MohyPotentialImpulseFact fact = snapshot.potential_impulses[impulse_index];
      if(!fact.valid)
         return "n/a";

      return StringFormat("%s %s/%s",
                          fact.confirmed ? "Confirmed" : "Live",
                          MohyBreakStateToString(fact.break_state),
                          MohyBreakoutCertaintyToString(fact.swing_breakout_certainty));
     }

   string ResolvePotentialCorrectionPanelState(const CMohyPriceActionSnapshot &snapshot,
                                               const string selected_impulse_id,
                                               const bool has_selected_plan,
                                               const MohyTradeSetupPlanFact &selected_plan) const
     {
      int correction_index = -1;
      if(has_selected_plan &&
         selected_plan.linked_potential_correction_index >= 0 &&
         selected_plan.linked_potential_correction_index < ArraySize(snapshot.potential_corrections))
         correction_index = selected_plan.linked_potential_correction_index;
      else if(selected_impulse_id != "")
        {
         correction_index = FindPotentialCorrectionIndexByRuntimeImpulseId(snapshot, selected_impulse_id, true);
         if(correction_index < 0)
            correction_index = FindPotentialCorrectionIndexByRuntimeImpulseId(snapshot, selected_impulse_id, false);
        }
      else
        {
         correction_index = SelectPotentialCorrectionIndex(snapshot, true);
         if(correction_index < 0)
            correction_index = SelectPotentialCorrectionIndex(snapshot, false);
        }

      if(correction_index < 0 || correction_index >= ArraySize(snapshot.potential_corrections))
         return "n/a";

      const MohyPotentialCorrectionFact fact = snapshot.potential_corrections[correction_index];
      if(!fact.valid)
         return "n/a";

      if(fact.state == MOHY_POT_CORR_STATE_INVALIDATED)
         return StringFormat("%s %s",
                             MohyPotentialCorrectionStateToString(fact.state),
                             MohyPotentialCorrectionTerminationReasonToString(fact.termination_reason));

      return StringFormat("%s Depth=%.3f OppICI=%d/%d",
                          MohyPotentialCorrectionStateToString(fact.state),
                          fact.retrace_depth,
                          fact.opposite_ici_count,
                          fact.min_opposite_ici_count);
     }

   int FindMatchingPlanIndexBySetupKey(const CMohyPriceActionSnapshot &snapshot,
                                       const string setup_key,
                                       string &out_impulse_id) const
     {
      out_impulse_id = "";
      for(int i = 0; i < ArraySize(snapshot.trade_setup_plans); ++i)
        {
         const MohyTradeSetupPlanFact plan = snapshot.trade_setup_plans[i];
         if(!plan.valid)
            continue;

         string plan_impulse_id = "";
         string plan_setup_key = "";
         if(!MohyRuntimeResolveIdentity(m_symbol, snapshot, plan, plan_impulse_id, plan_setup_key))
            continue;
         if(plan_setup_key == setup_key)
           {
            out_impulse_id = plan_impulse_id;
            return i;
           }
        }
      return -1;
     }

   bool ResolvePlanCorrection(const CMohyPriceActionSnapshot &snapshot,
                              const MohyTradeSetupPlanFact &plan,
                              MohyPotentialCorrectionFact &out_correction,
                              string &out_error) const
     {
      out_error = "";
      const int correction_index = plan.linked_potential_correction_index;
      if(correction_index < 0 || correction_index >= ArraySize(snapshot.potential_corrections))
        {
         out_error = StringFormat("LinkedCorrectionMissing idx=%d total=%d",
                                  correction_index,
                                  ArraySize(snapshot.potential_corrections));
         return false;
        }

      out_correction = snapshot.potential_corrections[correction_index];
      return true;
     }

   bool BuildExecutionSnapshot(CMohyPriceActionSnapshot &out_snapshot)
     {
      m_kernel.Configure(m_cfg,
                         m_cfg.execution_timeframe,
                         m_cfg.context_timeframe,
                         m_cfg.execution_timeframe);
      if(!m_kernel.BuildRecent(m_symbol, m_lookback_bars, out_snapshot, true))
        {
         SetLastAction("SnapshotBuildFailed");
         return false;
        }
      if(!out_snapshot.publishes_execution_stage_facts)
        {
         SetLastAction("ExecutionFactsUnavailable");
         return false;
        }
      return true;
     }

   string BuildImpulseContextKey(const string impulse_id) const
     {
      if(impulse_id == "")
         return "";

      string parts[];
      const int part_count = StringSplit(impulse_id, '|', parts);
      if(part_count < 6)
         return impulse_id;

      return StringFormat("%s|%s|%s|%s|%s|%s",
                          parts[0],
                          parts[1],
                          parts[2],
                          parts[3],
                          parts[4],
                          parts[5]);
     }

   bool IsConsumedImpulse(const string impulse_id) const
     {
      if(impulse_id == "")
         return false;

      if(m_store.FindConsumedImpulse(m_consumed_impulses, impulse_id) >= 0)
         return true;

      const string context_key = BuildImpulseContextKey(impulse_id);
      if(context_key == "")
         return false;

      for(int i = 0; i < ArraySize(m_consumed_impulses); ++i)
        {
         const string consumed_impulse_id = m_consumed_impulses[i].impulse_id;
         if(consumed_impulse_id == "")
            continue;
         if(BuildImpulseContextKey(consumed_impulse_id) == context_key)
            return true;
        }

      return false;
     }

   bool MarkConsumedImpulse(const string impulse_id,
                            const string setup_key,
                            const MohyImpulseConsumptionReason reason,
                            const string diagnostics)
     {
      if(impulse_id == "")
         return false;

      if(!m_store.UpsertConsumedImpulse(m_consumed_impulses,
                                        impulse_id,
                                        reason,
                                        TimeCurrent(),
                                        setup_key))
         return false;

      m_logger.LogEvent(m_cfg,
                        m_symbol,
                        setup_key,
                        impulse_id,
                        m_waiting_state.direction,
                        m_waiting_state.lifecycle_phase,
                        m_position_state.trade_phase,
                        (reason == MOHY_IMPULSE_CONSUMED_EXITED)
                        ? MOHY_ENGINE_EVENT_EXIT_RESOLVED
                        : MOHY_ENGINE_EVENT_INVALIDATION,
                        MohyImpulseConsumptionReasonToString(reason),
                        TimeCurrent(),
                        0,
                        0.0,
                        0.0,
                        0.0,
                        diagnostics,
                        "RuntimeEngine");
      return true;
     }

   int CountMatchingPositions(int &out_ticket,
                              long &out_type,
                              double &out_volume,
                              double &out_entry_price,
                              double &out_stop_price,
                              double &out_target_price,
                              datetime &out_open_time) const
     {
      out_ticket = -1;
      out_type = -1;
      out_volume = 0.0;
      out_entry_price = 0.0;
      out_stop_price = 0.0;
      out_target_price = 0.0;
      out_open_time = 0;

      int count = 0;
      const int total = PositionsTotal();
      for(int i = 0; i < total; ++i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;

         const string symbol = PositionGetString(POSITION_SYMBOL);
         const long magic = PositionGetInteger(POSITION_MAGIC);
         if(symbol != m_symbol)
            continue;
         if(m_cfg.risk.magic_number > 0 && magic != (long)m_cfg.risk.magic_number)
            continue;

         count++;
         out_ticket = (int)ticket;
         out_type = PositionGetInteger(POSITION_TYPE);
         out_volume = PositionGetDouble(POSITION_VOLUME);
         out_entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
         out_stop_price = PositionGetDouble(POSITION_SL);
         out_target_price = PositionGetDouble(POSITION_TP);
         out_open_time = (datetime)PositionGetInteger(POSITION_TIME);
        }

      return count;
     }

   void BindOpenPosition(const int ticket,
                         const long type,
                         const double volume,
                         const double entry_price,
                         const double stop_price,
                         const double target_price,
                         const datetime open_time,
                         const string setup_key,
                         const string impulse_id,
                         const bool recovered)
      {
       PositionManagementState previous = m_position_state;
       const bool preserve_management = previous.has_open_trade &&
                                        previous.ticket == ticket &&
                                        previous.setup_key == setup_key &&
                                        previous.impulse_id == impulse_id;
       MohyResetManagementState(m_position_state);
       m_position_state.has_open_trade = (ticket > 0);
       m_position_state.ticket = ticket;
       m_position_state.setup_key = setup_key;
       m_position_state.impulse_id = impulse_id;
      m_position_state.direction = (type == POSITION_TYPE_SELL) ? MOHY_DIR_BEAR : MOHY_DIR_BULL;
      m_position_state.trade_phase = m_position_state.has_open_trade ? MOHY_TRADE_PHASE_OPENED : MOHY_TRADE_PHASE_NONE;
      m_position_state.recovered = recovered;
       m_position_state.entry_price = entry_price;
       m_position_state.initial_lots = volume;
       m_position_state.initial_stop_loss = stop_price;
       m_position_state.target_price = target_price;
       m_position_state.opened_time = open_time;
       if(preserve_management)
          CopyManagementFields(m_position_state, previous);
       PersistTrackedPosition();
      }

   bool SeedManagementFromPlan(const MohyTradeSetupPlanFact &plan,
                               const MohyPotentialCorrectionFact &correction)
     {
      if(!m_position_state.has_open_trade)
         return false;

      const double point = SymbolPoint();
      const double net_cost_points = MathMax(0.0, plan.total_entry_cost_points);
      m_position_state.execution_mode = plan.execution_mode;
      m_position_state.break_even_armed = (m_cfg.management.enable_break_even_on_impulse_extreme &&
                                           correction.impulse_extreme_price > 0.0);
      m_position_state.break_even_active = false;
      m_position_state.break_even_applied_to_broker = false;
      m_position_state.break_even_retry_count = 0;
      m_position_state.virtual_stop_active = (m_position_state.execution_mode == MOHY_ENTRY_VIRTUAL_TRIGGER &&
                                              m_position_state.initial_stop_loss > 0.0);
      m_position_state.virtual_stop_level = m_position_state.virtual_stop_active
                                            ? m_position_state.initial_stop_loss
                                            : 0.0;
      m_position_state.post_be_profile = plan.post_be_profile;
      m_position_state.post_be_started = false;
      m_position_state.post_be_started_time = 0;
      m_position_state.post_be_start_reason = MOHY_POST_BE_START_REASON_NONE;
      m_position_state.partial_1_done = false;
      m_position_state.partial_2_done = false;
      m_position_state.partial_3_done = false;
      m_position_state.partial_progress_percent = 0.0;
      m_position_state.runner_trail_only_active = false;
      m_position_state.runner_tp_removed = false;
      m_position_state.last_trail_update_time = 0;
      m_position_state.last_favorable_extreme = 0.0;
      m_position_state.trade_phase = m_position_state.break_even_armed
                                     ? MOHY_TRADE_PHASE_BE_ARMED
                                     : MOHY_TRADE_PHASE_OPENED;
      m_position_state.initial_risk_points = (point > Eps())
                                             ? (MathAbs(m_position_state.entry_price - m_position_state.initial_stop_loss) / point)
                                             : 0.0;
      m_position_state.impulse_extreme_reference = correction.impulse_extreme_price;
      m_position_state.anchors_ready = (correction.impulse_origin_price > 0.0 &&
                                        correction.impulse_extreme_price > 0.0);
      m_position_state.impulse_high_anchor = MathMax(correction.impulse_origin_price,
                                                     correction.impulse_extreme_price);
      m_position_state.impulse_low_anchor = MathMin(correction.impulse_origin_price,
                                                    correction.impulse_extreme_price);
      m_position_state.correction_high_anchor = MathMax(correction.reference_begin_price,
                                                        correction.end_price);
      m_position_state.correction_low_anchor = MathMin(correction.reference_begin_price,
                                                       correction.end_price);
      if(m_position_state.direction == MOHY_DIR_BULL)
         m_position_state.break_even_level = NormalizePrice(m_position_state.entry_price + net_cost_points * point);
      else if(m_position_state.direction == MOHY_DIR_BEAR)
         m_position_state.break_even_level = NormalizePrice(m_position_state.entry_price - net_cost_points * point);
      else
         m_position_state.break_even_level = m_position_state.entry_price;

      StampManagementAction(m_position_state.break_even_armed ? "BreakEvenArmed" : "BreakEvenDisabled");
      return true;
     }

   void ClearWaitingState(const string cause)
     {
      MohyResetSetupState(m_waiting_state);
      m_waiting_state.last_transition_cause = cause;
      m_waiting_state.last_transition_time = TimeCurrent();
      PersistWaitingState();
     }

   void StartWaitingState(const MohyTradeSetupPlanFact &plan,
                          const string setup_key,
                          const string impulse_id)
     {
      MohyResetSetupState(m_waiting_state);
      m_waiting_state.setup_key = setup_key;
      m_waiting_state.impulse_id = impulse_id;
      m_waiting_state.direction = plan.direction;
      m_waiting_state.lifecycle_phase = MOHY_SETUP_WAITING_ENTRY;
      m_waiting_state.pre_entry_invalidation_mode = m_cfg.entry.pre_entry_invalidation_mode;
      m_waiting_state.trigger_mode = plan.execution_mode;
      m_waiting_state.trigger_price = plan.trigger_price;
      m_waiting_state.trigger_initialized = (plan.trigger_price > 0.0);
      m_waiting_state.trigger_last_adjust_time = TimeCurrent();
      m_waiting_state.waiting_since = TimeCurrent();
      m_waiting_state.paused_entries = m_paused;
      m_waiting_state.rr_state = (plan.reward_to_risk + plan.rr_tolerance >= plan.min_rr);
      m_waiting_state.spread_gate_state = plan.spread_pass;
      m_waiting_state.last_reject_reason = plan.reject_reason;
      m_waiting_state.last_transition_time = TimeCurrent();
      m_waiting_state.last_transition_cause = "WaitingStarted";
      PersistWaitingState();

      SetLastAction(StringFormat("WaitingStarted %s", setup_key));
      m_logger.LogEvent(m_cfg,
                        m_symbol,
                        setup_key,
                        impulse_id,
                        plan.direction,
                        m_waiting_state.lifecycle_phase,
                        m_position_state.trade_phase,
                        MOHY_ENGINE_EVENT_WAITING_STARTED,
                        "WaitingStarted",
                        plan.setup_time,
                        0,
                        plan.trigger_price,
                        0.0,
                        plan.reward_to_risk,
                        plan.diagnostics,
                        "RuntimeEngine");
      PublishWaitingLifecycle(MOHY_ENGINE_EVENT_WAITING_STARTED,
                              "WaitingStarted",
                              plan.setup_time,
                              plan.trigger_price,
                              plan.diagnostics);
     }

   void RefreshWaitingState(const MohyTradeSetupPlanFact &plan)
     {
      if(!HasWaitingState())
         return;

      m_waiting_state.paused_entries = m_paused;
      m_waiting_state.rr_state = (plan.reward_to_risk + plan.rr_tolerance >= plan.min_rr);
      m_waiting_state.spread_gate_state = plan.spread_pass;
      m_waiting_state.last_reject_reason = plan.reject_reason;

      if(plan.trigger_price > 0.0 &&
         MathAbs(plan.trigger_price - m_waiting_state.trigger_price) > Eps() &&
         (plan.adjust_min_seconds <= 0 ||
          (TimeCurrent() - m_waiting_state.trigger_last_adjust_time) >= plan.adjust_min_seconds))
        {
         m_waiting_state.trigger_price = plan.trigger_price;
         m_waiting_state.trigger_last_adjust_time = TimeCurrent();
         m_waiting_state.last_transition_time = TimeCurrent();
         m_waiting_state.last_transition_cause = "TriggerAdjusted";
         PersistWaitingState();
         SetLastAction(StringFormat("TriggerAdjusted %.5f", plan.trigger_price));
          m_logger.LogEvent(m_cfg,
                            m_symbol,
                            m_waiting_state.setup_key,
                            m_waiting_state.impulse_id,
                           plan.direction,
                           m_waiting_state.lifecycle_phase,
                           m_position_state.trade_phase,
                           MOHY_ENGINE_EVENT_TRIGGER_ADJUSTED,
                           "TriggerAdjusted",
                           TimeCurrent(),
                           0,
                           plan.trigger_price,
                           0.0,
                            plan.reward_to_risk,
                            plan.diagnostics,
                            "RuntimeEngine");
          PublishWaitingLifecycle(MOHY_ENGINE_EVENT_TRIGGER_ADJUSTED,
                                  "TriggerAdjusted",
                                  TimeCurrent(),
                                  plan.trigger_price,
                                  plan.diagnostics);
         }
      else
         PersistWaitingState();
     }

   bool IsTradeAllowedNow(string &out_reason) const
     {
      out_reason = "";
      if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
        {
         out_reason = "TerminalTradeDisabled";
         return false;
        }
      if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
        {
         out_reason = "MqlTradeDisabled";
         return false;
        }
      if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
        {
         out_reason = "AccountTradeDisabled";
         return false;
        }

      long trade_mode = SYMBOL_TRADE_MODE_DISABLED;
      if(!SymbolInfoInteger(m_symbol, SYMBOL_TRADE_MODE, trade_mode))
        {
         out_reason = "SymbolTradeModeUnknown";
         return false;
        }
      if(trade_mode == SYMBOL_TRADE_MODE_DISABLED)
        {
         out_reason = "SymbolTradeDisabled";
         return false;
        }
      return true;
     }

   bool PlacePendingOrder(const MohyTradeSetupPlanFact &plan,
                          const string setup_key,
                          const string impulse_id,
                          const string reason_code)
     {
      string trade_guard = "";
      if(!IsTradeAllowedNow(trade_guard))
        {
         SetLastAction(trade_guard);
         return false;
        }
      if(plan.lots_normalized <= 0.0 || !plan.spread_pass || !plan.exposure_pass)
        {
         SetLastAction("PendingPlanGuardsFailed");
         return false;
        }

      MqlTick tick;
      if(!ReadTick(tick))
        {
         SetLastAction("TickUnavailable");
         return false;
        }

      ENUM_ORDER_TYPE order_type;
      if(!ResolvePendingOrderType(plan, tick, order_type))
        {
         SetLastAction("PendingOrderTypeInvalid");
         return false;
        }

      string distance_reason = "";
      if(!HasPendingPlacementRoom(order_type, plan.trigger_price, distance_reason))
        {
         SetLastAction(distance_reason != "" ? distance_reason : "PendingBrokerConstraint");
         return false;
        }

      m_trade.SetExpertMagicNumber((ulong)MathMax(0, m_cfg.risk.magic_number));
      m_trade.SetDeviationInPoints(MathMax(0, m_cfg.risk.slippage_points));
      const string comment = BuildExecutionComment(setup_key);

      bool sent = false;
      if(order_type == ORDER_TYPE_BUY_LIMIT)
         sent = m_trade.BuyLimit(plan.lots_normalized, plan.trigger_price, m_symbol, plan.stop_price, plan.target_price, ORDER_TIME_GTC, 0, comment);
      else if(order_type == ORDER_TYPE_BUY_STOP)
         sent = m_trade.BuyStop(plan.lots_normalized, plan.trigger_price, m_symbol, plan.stop_price, plan.target_price, ORDER_TIME_GTC, 0, comment);
      else if(order_type == ORDER_TYPE_SELL_LIMIT)
         sent = m_trade.SellLimit(plan.lots_normalized, plan.trigger_price, m_symbol, plan.stop_price, plan.target_price, ORDER_TIME_GTC, 0, comment);
      else if(order_type == ORDER_TYPE_SELL_STOP)
         sent = m_trade.SellStop(plan.lots_normalized, plan.trigger_price, m_symbol, plan.stop_price, plan.target_price, ORDER_TIME_GTC, 0, comment);

      if(!sent)
        {
         SetLastAction(StringFormat("PendingPlaceFailed %d", (int)m_trade.ResultRetcode()));
         m_logger.LogEvent(m_cfg,
                           m_symbol,
                           setup_key,
                           impulse_id,
                           plan.direction,
                           m_waiting_state.lifecycle_phase,
                           m_position_state.trade_phase,
                           MOHY_ENGINE_EVENT_PLAN_REJECTED,
                           "PendingPlacementFailed",
                           TimeCurrent(),
                           0,
                           plan.trigger_price,
                           0.0,
                           plan.reward_to_risk,
                           m_trade.ResultRetcodeDescription(),
                           "RuntimeEngine");
         return false;
        }

      const int ticket = (int)m_trade.ResultOrder();
      m_waiting_state.pending_placed = (ticket > 0);
      m_waiting_state.pending_ticket = ticket;
      m_waiting_state.trigger_price = plan.trigger_price;
      m_waiting_state.trigger_initialized = true;
      m_waiting_state.trigger_last_adjust_time = TimeCurrent();
      m_waiting_state.last_transition_time = TimeCurrent();
      m_waiting_state.last_transition_cause = reason_code;
      PersistWaitingState();

      SetLastAction(StringFormat("PendingPlaced %d", ticket));
      m_logger.LogEvent(m_cfg,
                        m_symbol,
                        setup_key,
                        impulse_id,
                        plan.direction,
                        m_waiting_state.lifecycle_phase,
                        m_position_state.trade_phase,
                        MOHY_ENGINE_EVENT_WAITING_STARTED,
                        reason_code,
                        TimeCurrent(),
                        0,
                        plan.trigger_price,
                        0.0,
                        plan.reward_to_risk,
                        plan.diagnostics,
                        "RuntimeEngine");
      PublishWaitingLifecycle(MOHY_ENGINE_EVENT_WAITING_STARTED,
                              reason_code,
                              TimeCurrent(),
                              plan.trigger_price,
                              plan.diagnostics);
      return true;
     }

   bool ModifyPendingOrder(const MohyTradeSetupPlanFact &plan,
                           const int ticket,
                           const string reason_code)
     {
      if(ticket <= 0)
         return false;

      m_trade.SetExpertMagicNumber((ulong)MathMax(0, m_cfg.risk.magic_number));
      if(!m_trade.OrderModify((ulong)ticket,
                              plan.trigger_price,
                              plan.stop_price,
                              plan.target_price,
                              ORDER_TIME_GTC,
                              0))
        {
         if(m_trade.ResultRetcode() == TRADE_RETCODE_NO_CHANGES)
            return true;
         SetLastAction(StringFormat("PendingModifyFailed %d", (int)m_trade.ResultRetcode()));
         return false;
        }

      m_waiting_state.pending_placed = true;
      m_waiting_state.pending_ticket = ticket;
      m_waiting_state.trigger_price = plan.trigger_price;
      m_waiting_state.trigger_initialized = true;
      m_waiting_state.trigger_last_adjust_time = TimeCurrent();
      m_waiting_state.last_transition_time = TimeCurrent();
      m_waiting_state.last_transition_cause = reason_code;
      PersistWaitingState();
      SetLastAction(StringFormat("PendingModified %d", ticket));
      PublishWaitingLifecycle(MOHY_ENGINE_EVENT_TRIGGER_ADJUSTED,
                              reason_code,
                              TimeCurrent(),
                              plan.trigger_price,
                              "");
      return true;
     }

   bool ReplacePendingOrder(const MohyTradeSetupPlanFact &plan,
                            const int ticket,
                            const string setup_key,
                            const string impulse_id,
                            const string reason_code)
     {
      if(ticket > 0 && !DeletePendingOrder(ticket, "PendingReplaceDelete"))
         return false;
      m_waiting_state.pending_placed = false;
      m_waiting_state.pending_ticket = -1;
      PersistWaitingState();
      return PlacePendingOrder(plan, setup_key, impulse_id, reason_code);
     }

   bool SyncPendingOrder(const MohyTradeSetupPlanFact &plan,
                         const string setup_key,
                         const string impulse_id)
     {
      if(plan.execution_mode != MOHY_ENTRY_REAL_PENDING_ORDER || !HasWaitingState())
         return false;

      if(m_paused)
         return false;

      ENUM_ORDER_TYPE order_type;
      double existing_volume = 0.0;
      double existing_price = 0.0;
      double existing_sl = 0.0;
      double existing_tp = 0.0;
      bool has_ticket = SelectMatchingPendingOrderByTicket(m_waiting_state.pending_ticket,
                                                           order_type,
                                                           existing_volume,
                                                           existing_price,
                                                           existing_sl,
                                                           existing_tp);
      if(!has_ticket)
        {
         has_ticket = FindPendingOrderBySetupKey(setup_key,
                                                m_waiting_state.pending_ticket,
                                                order_type,
                                                existing_volume,
                                                existing_price,
                                                existing_sl,
                                                existing_tp);
         m_waiting_state.pending_placed = has_ticket;
         if(has_ticket)
            PersistWaitingState();
        }

      if(!has_ticket)
         return PlacePendingOrder(plan, setup_key, impulse_id, "PendingPlaced");

      const bool can_adjust = (plan.adjust_min_seconds <= 0 ||
                               (TimeCurrent() - m_waiting_state.trigger_last_adjust_time) >= plan.adjust_min_seconds);
      if(!plan.pending_auto_modify_enabled || !can_adjust)
         return true;

      if(LotsRequireReplacement(existing_volume, plan.lots_normalized))
         return ReplacePendingOrder(plan,
                                    m_waiting_state.pending_ticket,
                                    setup_key,
                                    impulse_id,
                                    "PendingReplaced");

      if(MathAbs(existing_price - plan.trigger_price) <= Eps() &&
         MathAbs(existing_sl - plan.stop_price) <= Eps() &&
         MathAbs(existing_tp - plan.target_price) <= Eps())
         return true;

      return ModifyPendingOrder(plan, m_waiting_state.pending_ticket, "PendingModified");
     }

   bool EvaluateWaitingCross(const MohyTradeSetupPlanFact &plan) const
     {
      const int bars = MohyIBars(m_symbol, m_cfg.execution_timeframe);
      if(bars < 3)
         return false;

      const double prev_spread = m_planner.ResolveSpreadEstimatePoints(m_symbol, 2);
      const double curr_spread = m_planner.ResolveSpreadEstimatePoints(m_symbol, 1);
      const double previous_close = m_planner.ResolveObservedClose(m_symbol,
                                                                   plan.direction,
                                                                   2,
                                                                   plan.trigger_touch_side,
                                                                   prev_spread);
      const double current_close = m_planner.ResolveObservedClose(m_symbol,
                                                                  plan.direction,
                                                                  1,
                                                                  plan.trigger_touch_side,
                                                                  curr_spread);
      return m_planner.IsVirtualTriggerCross(plan.direction,
                                             previous_close,
                                             current_close,
                                             plan.trigger_price);
     }

   bool ResolveManagedFullExit(const string reason_code,
                               const double trigger_price,
                               const string diagnostics)
     {
      if(!CloseOpenTrade(reason_code, trigger_price, diagnostics))
         return false;

      const PositionManagementState closed_state = m_position_state;
      const string closed_impulse_id = closed_state.impulse_id;
      const string closed_setup_key = closed_state.setup_key;
      const int closed_ticket = closed_state.ticket;
      if(StringFind(reason_code, "Fallback") >= 0)
         EmitRuntimeAlert(MOHY_UI_ALERT_CRITICAL,
                          StringFormat("ManagedExitFallback_%d_%s", closed_ticket, reason_code),
                          StringFormat("%s forced a managed market exit on ticket %d.", reason_code, closed_ticket));
      else if(reason_code == "VirtualStopExit")
         EmitRuntimeAlert(MOHY_UI_ALERT_WARNING,
                          StringFormat("ManagedExitVirtualStop_%d", closed_ticket),
                          StringFormat("Virtual stop exit resolved on ticket %d.", closed_ticket));
      PublishResolvedPositionLifecycle(closed_state,
                                       MOHY_ENGINE_EVENT_EXIT_RESOLVED,
                                       reason_code,
                                       trigger_price,
                                       diagnostics);
      MarkConsumedImpulse(closed_impulse_id,
                          closed_setup_key,
                          MOHY_IMPULSE_CONSUMED_EXITED,
                          reason_code);
      MohyResetManagementState(m_position_state);
      PersistTrackedPosition();
      SetLastAction(reason_code);
      return true;
     }

   double ResolveCurrentSpreadPoints(const MqlTick &tick) const
     {
      const double point = SymbolPoint();
      if(point <= Eps())
         return 0.0;
      if(tick.ask > tick.bid + Eps())
         return (tick.ask - tick.bid) / point;

      long spread_points = 0;
      if(SymbolInfoInteger(m_symbol, SYMBOL_SPREAD, spread_points) && spread_points >= 0)
         return (double)spread_points;
      return 0.0;
     }

   double NormalizeVolumeDown(const double volume) const
     {
      double volume_min = 0.0;
      double volume_max = 0.0;
      double volume_step = 0.0;
      if(!SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN, volume_min) || volume_min <= 0.0)
         volume_min = 0.01;
      if(!SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX, volume_max) || volume_max <= 0.0)
         volume_max = volume_min;
      if(!SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP, volume_step) || volume_step <= 0.0)
         volume_step = volume_min;

      double normalized = MathFloor(volume / volume_step + Eps()) * volume_step;
      normalized = MathMin(volume_max, normalized);
      if(normalized < volume_min - Eps())
         return 0.0;
      return normalized;
     }

   bool LoadTrackedPositionQuotes(double &out_volume,
                                  double &out_stop,
                                  double &out_target) const
     {
      out_volume = 0.0;
      out_stop = 0.0;
      out_target = 0.0;
      if(!m_position_state.has_open_trade || m_position_state.ticket <= 0)
         return false;
      if(!PositionSelectByTicket((ulong)m_position_state.ticket))
         return false;

      out_volume = PositionGetDouble(POSITION_VOLUME);
      out_stop = PositionGetDouble(POSITION_SL);
      out_target = PositionGetDouble(POSITION_TP);
      return (out_volume > Eps());
     }

   double ResolveCurrentManagedStop() const
     {
      if(m_position_state.execution_mode == MOHY_ENTRY_REAL_PENDING_ORDER)
        {
         double volume = 0.0;
         double stop = 0.0;
         double target = 0.0;
         if(LoadTrackedPositionQuotes(volume, stop, target) && stop > 0.0)
            return stop;
        }

      if(m_position_state.virtual_stop_active && m_position_state.virtual_stop_level > 0.0)
         return m_position_state.virtual_stop_level;
      return m_position_state.initial_stop_loss;
     }

   bool IsStopMoreProtective(const double candidate_stop,
                             const double current_stop) const
     {
      if(candidate_stop <= 0.0)
         return false;
      if(current_stop <= 0.0)
         return true;

      if(m_position_state.direction == MOHY_DIR_BULL)
         return (candidate_stop > current_stop + Eps());
      if(m_position_state.direction == MOHY_DIR_BEAR)
         return (candidate_stop < current_stop - Eps());
      return false;
     }

   double ClampProtectiveStop(const double candidate_stop,
                              const MqlTick &tick) const
     {
      const double point = SymbolPoint();
      if(point <= Eps() || candidate_stop <= 0.0)
         return candidate_stop;

      if(m_position_state.direction == MOHY_DIR_BULL)
         return NormalizePrice(MathMin(candidate_stop, tick.bid - point));
      if(m_position_state.direction == MOHY_DIR_BEAR)
         return NormalizePrice(MathMax(candidate_stop, tick.ask + point));
      return NormalizePrice(candidate_stop);
     }

   bool ManagementFiltersPass(const MqlTick &tick,
                              string &out_reason) const
     {
      out_reason = "";
      if(!m_cfg.risk.apply_exec_filters_to_management)
         return true;
      if(!m_cfg.entry.enable_spread_filter)
         return true;

      const double spread_points = ResolveCurrentSpreadPoints(tick);
      if(spread_points <= m_cfg.entry.max_spread_points + Eps())
         return true;

      out_reason = StringFormat("ManagementSpreadBlocked %.1f", spread_points);
      return false;
     }

   bool IsPartialProfileEnabled() const
     {
      return (m_position_state.post_be_profile == MOHY_POST_BE_PARTIAL_ONLY ||
              m_position_state.post_be_profile == MOHY_POST_BE_HYBRID);
     }

   bool IsTrailingProfileEnabled() const
     {
      return (m_position_state.post_be_profile == MOHY_POST_BE_TRAIL_ONLY ||
              m_position_state.post_be_profile == MOHY_POST_BE_HYBRID ||
              m_position_state.runner_trail_only_active);
     }

   double ResolvePartialPercent(const int leg_index) const
     {
      if(leg_index == 1)
         return MathMax(0.0, m_cfg.management.partial_percent_1);
      if(leg_index == 2)
         return MathMax(0.0, m_cfg.management.partial_percent_2);
      if(leg_index == 3)
         return MathMax(0.0, m_cfg.management.partial_percent_3);
      return 0.0;
     }

   double ResolvePartialRMultiple(const int leg_index) const
     {
      if(leg_index == 1)
         return MathMax(0.0, m_cfg.management.partial_r_multiple_1);
      if(leg_index == 2)
         return MathMax(0.0, m_cfg.management.partial_r_multiple_2);
      if(leg_index == 3)
         return MathMax(0.0, m_cfg.management.partial_r_multiple_3);
      return 0.0;
     }

   double ResolvePartialFibLevel(const int leg_index) const
     {
      if(leg_index == 1)
         return m_cfg.management.partial_fib_level_1;
      if(leg_index == 2)
         return m_cfg.management.partial_fib_level_2;
      if(leg_index == 3)
         return m_cfg.management.partial_fib_level_3;
      return 0.0;
     }

   MohyPartialTargetMode ResolvePartialTargetMode(const int leg_index) const
     {
      if(m_cfg.management.partial_model == MOHY_PARTIAL_R_MULTIPLE)
         return MOHY_PARTIAL_TARGET_R_MULTIPLE;
      if(m_cfg.management.partial_model == MOHY_PARTIAL_FIB_LEVELS)
         return MOHY_PARTIAL_TARGET_FIB_LEVEL;

      if(leg_index == 1)
         return m_cfg.management.partial_target_mode_1;
      if(leg_index == 2)
         return m_cfg.management.partial_target_mode_2;
      if(leg_index == 3)
         return m_cfg.management.partial_target_mode_3;
      return MOHY_PARTIAL_TARGET_R_MULTIPLE;
     }

   bool IsPartialLegDone(const int leg_index) const
     {
      if(leg_index == 1)
         return m_position_state.partial_1_done;
      if(leg_index == 2)
         return m_position_state.partial_2_done;
      if(leg_index == 3)
         return m_position_state.partial_3_done;
      return true;
     }

   void MarkPartialLegDone(const int leg_index)
     {
      if(leg_index == 1)
         m_position_state.partial_1_done = true;
      else if(leg_index == 2)
         m_position_state.partial_2_done = true;
      else if(leg_index == 3)
         m_position_state.partial_3_done = true;

      m_position_state.partial_progress_percent = MathMin(100.0,
                                                          m_position_state.partial_progress_percent +
                                                          ResolvePartialPercent(leg_index));
      PersistTrackedPosition();
     }

   void LogManagementEvent(const MohyEngineEventType event_type,
                           const string reason_code,
                           const double price_a,
                           const double price_b,
                           const double rr_value,
                           const string diagnostics)
     {
      if(event_type == MOHY_ENGINE_EVENT_NONE || !m_position_state.has_open_trade)
         return;

      m_logger.LogEvent(m_cfg,
                        m_symbol,
                        m_position_state.setup_key,
                        m_position_state.impulse_id,
                        m_position_state.direction,
                        MOHY_SETUP_ENTERED,
                        m_position_state.trade_phase,
                        event_type,
                        reason_code,
                        TimeCurrent(),
                        0,
                        price_a,
                         price_b,
                         rr_value,
                         diagnostics,
                         "RuntimeEngine");
      PublishOpenLifecycle(event_type,
                           reason_code,
                           TimeCurrent(),
                           diagnostics);
     }

   double ResolveOpenR(const MqlTick &tick) const
     {
      const double point = SymbolPoint();
      if(point <= Eps() || m_position_state.initial_risk_points <= Eps())
         return 0.0;

      const double risk_distance = m_position_state.initial_risk_points * point;
      if(risk_distance <= Eps())
         return 0.0;

      if(m_position_state.direction == MOHY_DIR_BULL)
         return (tick.bid - m_position_state.entry_price) / risk_distance;
      if(m_position_state.direction == MOHY_DIR_BEAR)
         return (m_position_state.entry_price - tick.ask) / risk_distance;
      return 0.0;
     }

   double ResolveFavorablePrice(const MqlTick &tick) const
     {
      if(m_position_state.direction == MOHY_DIR_BEAR)
         return tick.ask;
      return tick.bid;
     }

   bool UpdateFavorableExtreme(const MqlTick &tick)
     {
      if(!m_position_state.has_open_trade)
         return false;

      const double favorable_price = ResolveFavorablePrice(tick);
      bool improved = false;
      if(m_position_state.last_favorable_extreme <= 0.0)
         improved = true;
      else if(m_position_state.direction == MOHY_DIR_BULL)
         improved = (favorable_price > m_position_state.last_favorable_extreme + Eps());
      else if(m_position_state.direction == MOHY_DIR_BEAR)
         improved = (favorable_price < m_position_state.last_favorable_extreme - Eps());

      if(improved)
        {
         m_position_state.last_favorable_extreme = favorable_price;
         PersistTrackedPosition();
        }
      return improved;
     }

   bool ShouldStartPostBEManagement(const MqlTick &tick,
                                    MohyPostBEStartReason &out_reason) const
     {
      out_reason = MOHY_POST_BE_START_REASON_NONE;
      if(!m_position_state.has_open_trade ||
         m_position_state.post_be_started ||
         m_position_state.post_be_profile == MOHY_POST_BE_OFF)
         return false;

      if(m_cfg.management.post_be_start_mode == MOHY_POST_BE_START_IMMEDIATE)
        {
         out_reason = MOHY_POST_BE_START_REASON_IMMEDIATE;
         return true;
        }

      if(m_cfg.management.post_be_start_mode == MOHY_POST_BE_START_AFTER_BE)
        {
         if(m_position_state.break_even_active)
           {
            out_reason = MOHY_POST_BE_START_REASON_AFTER_BREAK_EVEN;
            return true;
           }
         return false;
        }

      if(m_cfg.management.post_be_start_mode == MOHY_POST_BE_START_AT_R_MULTIPLE &&
         ResolveOpenR(tick) + Eps() >= MathMax(0.0, m_cfg.management.post_be_start_r))
        {
         out_reason = MOHY_POST_BE_START_REASON_AT_R_MULTIPLE;
         return true;
        }

      return false;
     }

   bool StartPostBEManagement(const MohyPostBEStartReason reason,
                              const double reference_price,
                              const double open_r)
     {
      if(!m_position_state.has_open_trade ||
         m_position_state.post_be_started ||
         m_position_state.post_be_profile == MOHY_POST_BE_OFF)
         return false;

      m_position_state.post_be_started = true;
      m_position_state.post_be_started_time = TimeCurrent();
      m_position_state.post_be_start_reason = reason;
      m_position_state.trade_phase = MOHY_TRADE_PHASE_POST_BE_ACTIVE;

      if(m_position_state.execution_mode == MOHY_ENTRY_VIRTUAL_TRIGGER &&
         !m_position_state.virtual_stop_active &&
         m_position_state.initial_stop_loss > 0.0)
        {
         m_position_state.virtual_stop_active = true;
         m_position_state.virtual_stop_level = m_position_state.initial_stop_loss;
        }
      if(m_position_state.last_favorable_extreme <= 0.0)
         m_position_state.last_favorable_extreme = m_position_state.entry_price;

      const string start_reason = MohyPostBEStartReasonToString(reason);
      StampManagementAction(StringFormat("PostBEStarted%s", start_reason));
      SetLastAction(StringFormat("PostBEStarted %s", start_reason));
      LogManagementEvent(MOHY_ENGINE_EVENT_TRAILING_UPDATED,
                         StringFormat("PostBEStarted%s", start_reason),
                         reference_price,
                         ResolveCurrentManagedStop(),
                         open_r,
                         StringFormat("Profile=%s",
                                      MohyPostBEProfileToString(m_position_state.post_be_profile)));
      return true;
     }

   bool ModifyBrokerPositionWithRetry(const double stop_price,
                                      const double target_price,
                                      int &out_retcode,
                                      string &out_retcode_description)
     {
      out_retcode = 0;
      out_retcode_description = "";
      if(!m_position_state.has_open_trade || m_position_state.ticket <= 0)
         return false;

      m_trade.SetExpertMagicNumber((ulong)MathMax(0, m_cfg.risk.magic_number));
      const int attempts = MathMax(1, m_cfg.management.management_retry_count);
      for(int attempt = 0; attempt < attempts; ++attempt)
        {
         if(m_trade.PositionModify((ulong)m_position_state.ticket, stop_price, target_price))
            return true;
         out_retcode = (int)m_trade.ResultRetcode();
         out_retcode_description = m_trade.ResultRetcodeDescription();
        }
      return false;
     }

   bool ApplyManagedStopCandidate(const MqlTick &tick,
                                  const double raw_stop,
                                  const string action_code,
                                  const MohyEngineEventType event_type,
                                  const double reference_price,
                                  const double rr_value,
                                  const string diagnostics,
                                  bool &out_position_closed)
     {
      out_position_closed = false;
      if(!m_position_state.has_open_trade)
         return false;

      const double candidate_stop = ClampProtectiveStop(raw_stop, tick);
      if(candidate_stop <= 0.0)
         return false;

      const double current_stop = ResolveCurrentManagedStop();
      if(!IsStopMoreProtective(candidate_stop, current_stop))
         return false;

      string filter_reason = "";
      if(!ManagementFiltersPass(tick, filter_reason))
        {
         SetLastAction(filter_reason);
         return false;
        }

      if(m_position_state.execution_mode == MOHY_ENTRY_VIRTUAL_TRIGGER)
        {
         m_position_state.virtual_stop_active = true;
         m_position_state.virtual_stop_level = candidate_stop;
         m_position_state.trade_phase = (m_position_state.post_be_started || m_position_state.runner_trail_only_active)
                                        ? MOHY_TRADE_PHASE_POST_BE_ACTIVE
                                        : (m_position_state.break_even_active
                                           ? MOHY_TRADE_PHASE_BE_RISK_FREE
                                           : m_position_state.trade_phase);
         StampManagementAction(action_code);
         SetLastAction(StringFormat("%s %.5f", action_code, candidate_stop));
         LogManagementEvent(event_type,
                            action_code,
                            reference_price,
                            candidate_stop,
                            rr_value,
                            diagnostics);
         return true;
        }

      double volume = 0.0;
      double broker_stop = 0.0;
      double broker_target = 0.0;
      if(!LoadTrackedPositionQuotes(volume, broker_stop, broker_target))
         broker_target = m_position_state.target_price;

      int retcode = 0;
      string retcode_description = "";
      if(ModifyBrokerPositionWithRetry(candidate_stop,
                                      broker_target,
                                      retcode,
                                      retcode_description))
        {
         m_position_state.trade_phase = (m_position_state.post_be_started || m_position_state.runner_trail_only_active)
                                        ? MOHY_TRADE_PHASE_POST_BE_ACTIVE
                                        : (m_position_state.break_even_active
                                           ? MOHY_TRADE_PHASE_BE_RISK_FREE
                                           : m_position_state.trade_phase);
         StampManagementAction(action_code);
         SetLastAction(StringFormat("%s %.5f", action_code, candidate_stop));
         LogManagementEvent(event_type,
                            action_code,
                            reference_price,
                            candidate_stop,
                            rr_value,
                            diagnostics);
         return true;
        }

      StampManagementAction(StringFormat("%sRetryExhausted", action_code));
      SetLastAction(StringFormat("%sFailed %d", action_code, retcode));
      if(m_cfg.management.management_retry_then_market_close)
        {
         const string fallback_reason = StringFormat("%sFallbackClose", action_code);
         out_position_closed = ResolveManagedFullExit(fallback_reason,
                                                      reference_price,
                                                      retcode_description != "" ? retcode_description : diagnostics);
         return out_position_closed;
        }
      return false;
     }

   bool ApplyBrokerTargetUpdate(const MqlTick &tick,
                                const double target_price,
                                const string action_code,
                                const MohyEngineEventType event_type,
                                const double reference_price,
                                const double rr_value,
                                const string diagnostics,
                                bool &out_position_closed)
     {
      out_position_closed = false;
      if(!m_position_state.has_open_trade || m_position_state.ticket <= 0)
         return false;

      string filter_reason = "";
      if(!ManagementFiltersPass(tick, filter_reason))
        {
         SetLastAction(filter_reason);
         return false;
        }

      double volume = 0.0;
      double broker_stop = 0.0;
      double broker_target = 0.0;
      if(!LoadTrackedPositionQuotes(volume, broker_stop, broker_target))
         return false;
      if(MathAbs(broker_target - target_price) <= Eps())
         return false;

      int retcode = 0;
      string retcode_description = "";
      if(ModifyBrokerPositionWithRetry(broker_stop,
                                      target_price,
                                      retcode,
                                      retcode_description))
        {
         StampManagementAction(action_code);
         SetLastAction(StringFormat("%s %.5f", action_code, target_price));
         LogManagementEvent(event_type,
                            action_code,
                            reference_price,
                            target_price,
                            rr_value,
                            diagnostics);
         return true;
        }

      StampManagementAction(StringFormat("%sRetryExhausted", action_code));
      SetLastAction(StringFormat("%sFailed %d", action_code, retcode));
      if(m_cfg.management.management_retry_then_market_close)
        {
         const string fallback_reason = StringFormat("%sFallbackClose", action_code);
         out_position_closed = ResolveManagedFullExit(fallback_reason,
                                                      reference_price,
                                                      retcode_description != "" ? retcode_description : diagnostics);
         return out_position_closed;
        }
      return false;
     }

   bool ResolveStructureTrailCandidate(const CMohyPriceActionSnapshot &snapshot,
                                       double &out_stop) const
     {
      out_stop = 0.0;
      const int target_rank = MathMax(1, m_cfg.management.trail_structure_swing_index);
      int previous_shift = -1;
      for(int rank = 1; rank <= target_rank; ++rank)
        {
         int best_shift = 2147483647;
         double best_price = 0.0;
         bool found = false;
         for(int i = 0; i < ArraySize(snapshot.elements); ++i)
           {
            const MohyElementFact element = snapshot.elements[i];
            if(!element.confirmed || element.shift < 1 || element.pivot_price <= 0.0)
               continue;
            if(m_position_state.direction == MOHY_DIR_BULL && element.type != MOHY_ELEMENT_VALLEY)
               continue;
            if(m_position_state.direction == MOHY_DIR_BEAR && element.type != MOHY_ELEMENT_PEAK)
               continue;
            if(previous_shift >= 0 && element.shift <= previous_shift)
               continue;
            if(element.shift < best_shift)
              {
               best_shift = element.shift;
               best_price = element.pivot_price;
               found = true;
              }
           }
         if(!found)
            return false;
         previous_shift = best_shift;
         out_stop = best_price;
        }

      out_stop = NormalizePrice(out_stop);
      return (out_stop > 0.0);
     }

   bool ResolveAtrTrailCandidate(const MqlTick &tick,
                                 double &out_stop) const
     {
      out_stop = 0.0;
      const int handle = iATR(m_symbol,
                              (ENUM_TIMEFRAMES)m_cfg.execution_timeframe,
                              MathMax(1, m_cfg.management.trail_atr_period));
      if(handle == INVALID_HANDLE)
         return false;

      double buffer[1];
      const int copied = CopyBuffer(handle, 0, 1, 1, buffer);
      IndicatorRelease(handle);
      if(copied != 1 || buffer[0] <= 0.0)
         return false;

      const double trail_distance = m_cfg.management.trail_atr_multiplier * buffer[0];
      if(m_position_state.direction == MOHY_DIR_BULL)
         out_stop = tick.bid - trail_distance;
      else if(m_position_state.direction == MOHY_DIR_BEAR)
         out_stop = tick.ask + trail_distance;
      return (out_stop > 0.0);
     }

   bool ResolveMaTrailCandidate(const MqlTick &tick,
                                double &out_stop) const
     {
      out_stop = 0.0;
      const int handle = iMA(m_symbol,
                             (ENUM_TIMEFRAMES)m_cfg.execution_timeframe,
                             MathMax(1, m_cfg.management.trail_ma_period),
                             0,
                             (ENUM_MA_METHOD)m_cfg.management.trail_ma_method,
                             (ENUM_APPLIED_PRICE)m_cfg.management.trail_ma_price);
      if(handle == INVALID_HANDLE)
         return false;

      double buffer[1];
      const int copied = CopyBuffer(handle, 0, 1, 1, buffer);
      IndicatorRelease(handle);
      if(copied != 1 || buffer[0] <= 0.0)
         return false;

      const double buffer_points = m_cfg.management.trail_ma_buffer_points * SymbolPoint();
      if(m_position_state.direction == MOHY_DIR_BULL)
         out_stop = buffer[0] - buffer_points;
      else if(m_position_state.direction == MOHY_DIR_BEAR)
         out_stop = buffer[0] + buffer_points;
      return (out_stop > 0.0);
     }

   bool ResolveTrailCandidate(const CMohyPriceActionSnapshot &snapshot,
                              const bool has_snapshot,
                              const MqlTick &tick,
                              double &out_stop,
                              string &out_diagnostics) const
     {
      out_stop = 0.0;
      out_diagnostics = "";
      if(m_cfg.management.trail_model == MOHY_TRAIL_FIXED_POINTS)
        {
         const double distance = MathMax(0.0, m_cfg.management.trail_fixed_points) * SymbolPoint();
         if(distance <= Eps())
            return false;
         out_stop = (m_position_state.direction == MOHY_DIR_BEAR)
                    ? (tick.ask + distance)
                    : (tick.bid - distance);
         out_diagnostics = "TrailModel=FixedPoints";
         return true;
        }

      if(m_cfg.management.trail_model == MOHY_TRAIL_ATR_BASED)
        {
         if(!ResolveAtrTrailCandidate(tick, out_stop))
            return false;
         out_diagnostics = "TrailModel=ATRBased";
         return true;
        }

      if(m_cfg.management.trail_model == MOHY_TRAIL_MA_BASED)
        {
         if(!ResolveMaTrailCandidate(tick, out_stop))
            return false;
         out_diagnostics = "TrailModel=MABased";
         return true;
        }

      if(!has_snapshot)
        {
         out_diagnostics = "BlockedByGuard MissingSnapshot";
         return false;
        }
      if(!ResolveStructureTrailCandidate(snapshot, out_stop))
        {
         out_diagnostics = "BlockedByGuard MissingStructure";
         return false;
        }
      out_diagnostics = "TrailModel=StructureBased";
      return true;
     }

   bool ResolvePartialTarget(const int leg_index,
                             double &out_target,
                             string &out_diagnostics) const
     {
      out_target = 0.0;
      out_diagnostics = "";

      const MohyPartialTargetMode target_mode = ResolvePartialTargetMode(leg_index);
      const double point = SymbolPoint();
      if(target_mode == MOHY_PARTIAL_TARGET_R_MULTIPLE)
        {
         const double distance = ResolvePartialRMultiple(leg_index) * m_position_state.initial_risk_points * point;
         if(distance <= Eps())
           {
            out_diagnostics = "BlockedByGuard InvalidRMultiple";
            return false;
           }
         if(m_position_state.direction == MOHY_DIR_BULL)
            out_target = m_position_state.entry_price + distance;
         else if(m_position_state.direction == MOHY_DIR_BEAR)
            out_target = m_position_state.entry_price - distance;
         out_diagnostics = StringFormat("PartialTarget=%s",
                                        MohyPartialTargetModeToString(target_mode));
         return true;
        }

      if(!m_position_state.anchors_ready)
        {
         out_diagnostics = "BlockedByGuard MissingAnchors";
         return false;
        }

      const double fib_level = ResolvePartialFibLevel(leg_index);
      if(m_position_state.direction == MOHY_DIR_BULL)
         out_target = m_position_state.impulse_high_anchor +
                      fib_level * (m_position_state.impulse_high_anchor - m_position_state.correction_low_anchor);
      else if(m_position_state.direction == MOHY_DIR_BEAR)
         out_target = m_position_state.impulse_low_anchor -
                      fib_level * (m_position_state.correction_high_anchor - m_position_state.impulse_low_anchor);
      out_target = NormalizePrice(out_target);
      out_diagnostics = StringFormat("PartialTarget=%s",
                                     MohyPartialTargetModeToString(target_mode));
      return (out_target > 0.0);
     }

   double ResolvePartialCloseVolume(const int leg_index,
                                    const double current_volume) const
     {
      const int active_count = MathMax(1, MathMin(3, m_cfg.management.partial_count));
      if(leg_index >= active_count)
         return current_volume;

      double close_volume = NormalizeVolumeDown(m_position_state.initial_lots *
                                                ResolvePartialPercent(leg_index) / 100.0);
      if(close_volume <= Eps())
         return current_volume;

      close_volume = MathMin(current_volume, close_volume);
      if(current_volume - close_volume < ResolveVolumeStep() - Eps())
         close_volume = current_volume;
      return close_volume;
     }

   bool ActivateBreakEven(const double reference_price)
     {
      if(!m_position_state.has_open_trade || m_position_state.break_even_active)
         return false;

      const double current_stop = ResolveCurrentManagedStop();
      if(m_position_state.execution_mode == MOHY_ENTRY_REAL_PENDING_ORDER)
        {
         double volume = 0.0;
         double broker_stop = 0.0;
         double broker_target = 0.0;
         LoadTrackedPositionQuotes(volume, broker_stop, broker_target);
         if(IsStopMoreProtective(current_stop, m_position_state.break_even_level) ||
            MathAbs(broker_stop - m_position_state.break_even_level) <= Eps())
           {
            m_position_state.break_even_active = true;
            m_position_state.break_even_applied_to_broker = true;
            m_position_state.break_even_retry_count = 0;
            m_position_state.trade_phase = m_position_state.post_be_started
                                           ? MOHY_TRADE_PHASE_POST_BE_ACTIVE
                                           : MOHY_TRADE_PHASE_BE_RISK_FREE;
            StampManagementAction("BreakEvenBrokerConfirmed");
            SetLastAction(StringFormat("BreakEvenBrokerConfirmed %.5f", m_position_state.break_even_level));
            LogManagementEvent(MOHY_ENGINE_EVENT_BREAK_EVEN_ACTIVATED,
                               "ImpulseExtremeTouched",
                               reference_price,
                               MathMax(broker_stop, m_position_state.break_even_level),
                               0.0,
                               "BreakEvenAlreadyProtective");
            EmitRuntimeAlert(MOHY_UI_ALERT_INFO,
                             StringFormat("BreakEvenActive_%d", m_position_state.ticket),
                             StringFormat("Break-even active for ticket %d.", m_position_state.ticket));
            return true;
           }

         m_trade.SetExpertMagicNumber((ulong)MathMax(0, m_cfg.risk.magic_number));
         if(m_trade.PositionModify((ulong)m_position_state.ticket,
                                   m_position_state.break_even_level,
                                   broker_target))
           {
            m_position_state.break_even_active = true;
            m_position_state.break_even_applied_to_broker = true;
            m_position_state.break_even_retry_count = 0;
            m_position_state.virtual_stop_active = false;
            m_position_state.virtual_stop_level = 0.0;
            m_position_state.trade_phase = m_position_state.post_be_started
                                           ? MOHY_TRADE_PHASE_POST_BE_ACTIVE
                                           : MOHY_TRADE_PHASE_BE_RISK_FREE;
            StampManagementAction("BreakEvenBrokerMoved");
            SetLastAction(StringFormat("BreakEvenBrokerMoved %.5f", m_position_state.break_even_level));
            LogManagementEvent(MOHY_ENGINE_EVENT_BREAK_EVEN_ACTIVATED,
                               "ImpulseExtremeTouched",
                               reference_price,
                               m_position_state.break_even_level,
                               0.0,
                               "BreakEvenBrokerMove");
            EmitRuntimeAlert(MOHY_UI_ALERT_INFO,
                             StringFormat("BreakEvenActive_%d", m_position_state.ticket),
                             StringFormat("Break-even active for ticket %d.", m_position_state.ticket));
            return true;
           }

         m_position_state.break_even_retry_count++;
         StampManagementAction("BreakEvenBrokerRetry");
         SetLastAction(StringFormat("BreakEvenRetry %d", m_position_state.break_even_retry_count));
         if(m_position_state.break_even_retry_count >= MathMax(1, m_cfg.management.be_retry_ticks))
            return ResolveManagedFullExit("BreakEvenMoveFallback",
                                          reference_price,
                                          m_trade.ResultRetcodeDescription());
         return false;
        }

      m_position_state.break_even_active = true;
      m_position_state.virtual_stop_active = true;
      m_position_state.virtual_stop_level = IsStopMoreProtective(m_position_state.break_even_level, current_stop)
                                            ? m_position_state.break_even_level
                                            : current_stop;
      if(m_position_state.virtual_stop_level <= 0.0)
         m_position_state.virtual_stop_level = m_position_state.break_even_level;
      m_position_state.trade_phase = m_position_state.post_be_started
                                     ? MOHY_TRADE_PHASE_POST_BE_ACTIVE
                                     : MOHY_TRADE_PHASE_BE_RISK_FREE;
      StampManagementAction("BreakEvenActivated");
      SetLastAction(StringFormat("BreakEvenActivated %.5f", m_position_state.break_even_level));
      LogManagementEvent(MOHY_ENGINE_EVENT_BREAK_EVEN_ACTIVATED,
                         "ImpulseExtremeTouched",
                         reference_price,
                         m_position_state.virtual_stop_level,
                         0.0,
                         "BreakEvenVirtual");
      EmitRuntimeAlert(MOHY_UI_ALERT_INFO,
                       StringFormat("BreakEvenActive_%d", m_position_state.ticket),
                       StringFormat("Break-even active for ticket %d.", m_position_state.ticket));
      return true;
     }

   bool CloseOpenTrade(const string reason_code,
                       const double trigger_price,
                       const string diagnostics)
     {
      if(!m_position_state.has_open_trade || m_position_state.ticket <= 0)
         return false;

      m_trade.SetExpertMagicNumber((ulong)MathMax(0, m_cfg.risk.magic_number));
      m_trade.SetDeviationInPoints(MathMax(0, m_cfg.risk.slippage_points));
      if(!m_trade.PositionClose((ulong)m_position_state.ticket))
        {
         SetLastAction(StringFormat("%sFailed %d", reason_code, (int)m_trade.ResultRetcode()));
         return false;
        }

      datetime resolved_at = TimeCurrent();
      double resolved_price = trigger_price;
      string exit_note = "";
      ResolveExitDeal(m_position_state.ticket,
                      m_position_state.opened_time,
                      resolved_at,
                      resolved_price,
                      exit_note);

      m_logger.LogEvent(m_cfg,
                        m_symbol,
                        m_position_state.setup_key,
                        m_position_state.impulse_id,
                        m_position_state.direction,
                        MOHY_SETUP_ENTERED,
                        MOHY_TRADE_PHASE_EXITED,
                        MOHY_ENGINE_EVENT_EXIT_RESOLVED,
                        reason_code,
                        resolved_at,
                        0,
                        (resolved_price > 0.0) ? resolved_price : trigger_price,
                        m_position_state.break_even_level,
                        0.0,
                        CombineDiagnostics(diagnostics, exit_note),
                        "RuntimeEngine");
      return true;
     }

   bool RemoveRunnerTargetIfNeeded(const MqlTick &tick,
                                   bool &out_position_closed)
     {
      out_position_closed = false;
      if(!m_position_state.has_open_trade ||
         m_cfg.management.runner_target_mode != MOHY_RUNNER_TRAIL_ONLY)
         return false;

      double volume = 0.0;
      double broker_stop = 0.0;
      double broker_target = 0.0;
      if(!LoadTrackedPositionQuotes(volume, broker_stop, broker_target) || volume <= Eps())
         return false;

      m_position_state.runner_trail_only_active = true;
      if(broker_target <= Eps())
        {
         if(!m_position_state.runner_tp_removed)
           {
            m_position_state.runner_tp_removed = true;
            PersistTrackedPosition();
           }
         return false;
        }

      const bool changed = ApplyBrokerTargetUpdate(tick,
                                                   0.0,
                                                   "RunnerTPRemoved",
                                                   MOHY_ENGINE_EVENT_TRAILING_UPDATED,
                                                   ResolveReferencePrice(m_position_state.direction, tick),
                                                   ResolveOpenR(tick),
                                                   "RunnerTargetMode=TrailOnlyRunner",
                                                   out_position_closed);
      if(changed && m_position_state.has_open_trade)
        {
         m_position_state.runner_tp_removed = true;
         PersistTrackedPosition();
        }
      return changed;
     }

   bool ProcessTrailing(const CMohyPriceActionSnapshot &snapshot,
                        const bool has_snapshot,
                        const MqlTick &tick,
                        const bool has_new_closed_bar,
                        const bool force_now,
                        bool &out_position_closed)
     {
      out_position_closed = false;
      if(!m_position_state.has_open_trade ||
         !m_position_state.post_be_started ||
         !IsTrailingProfileEnabled())
         return false;

      const bool favorable_improved = UpdateFavorableExtreme(tick);
      bool cadence_pass = force_now;
      if(!cadence_pass)
        {
         if(m_cfg.management.trail_update_cadence == MOHY_TRAIL_EVERY_TICK)
            cadence_pass = true;
         else if(m_cfg.management.trail_update_cadence == MOHY_TRAIL_LTF_CLOSE)
            cadence_pass = has_new_closed_bar;
         else
            cadence_pass = (has_new_closed_bar || favorable_improved);
        }
      if(!cadence_pass)
         return false;

      double trail_candidate = 0.0;
      string diagnostics = "";
      if(!ResolveTrailCandidate(snapshot, has_snapshot, tick, trail_candidate, diagnostics))
        {
         if(force_now)
            SetLastAction(diagnostics != "" ? diagnostics : "TrailBlocked");
         return false;
        }

      const bool changed = ApplyManagedStopCandidate(tick,
                                                     trail_candidate,
                                                     force_now ? "TrailAppliedNow" : "TrailingUpdated",
                                                     MOHY_ENGINE_EVENT_TRAILING_UPDATED,
                                                     ResolveReferencePrice(m_position_state.direction, tick),
                                                     ResolveOpenR(tick),
                                                     diagnostics,
                                                     out_position_closed);
      if(changed && m_position_state.has_open_trade)
        {
         m_position_state.last_trail_update_time = TimeCurrent();
         PersistTrackedPosition();
        }
      return changed;
     }

   bool ApplyPostPartialStopAction(const CMohyPriceActionSnapshot &snapshot,
                                   const bool has_snapshot,
                                   const MqlTick &tick,
                                   bool &out_position_closed)
     {
      out_position_closed = false;
      if(!m_position_state.has_open_trade)
         return false;

      if(m_cfg.management.post_partial_stop_action == MOHY_POST_PARTIAL_KEEP)
         return false;

      const double reference_price = ResolveReferencePrice(m_position_state.direction, tick);
      const double rr_value = ResolveOpenR(tick);
      if(m_cfg.management.post_partial_stop_action == MOHY_POST_PARTIAL_MOVE_TO_BE_OR_BE_PLUS)
        {
         const double offset = m_cfg.management.post_partial_be_plus_points * SymbolPoint();
         const double candidate = (m_position_state.direction == MOHY_DIR_BEAR)
                                  ? (m_position_state.break_even_level - offset)
                                  : (m_position_state.break_even_level + offset);
         return ApplyManagedStopCandidate(tick,
                                          candidate,
                                          "PostPartialMoveToBE",
                                          MOHY_ENGINE_EVENT_TRAILING_UPDATED,
                                          reference_price,
                                          rr_value,
                                          "PostPartialStop=MoveToBEorBEPlus",
                                          out_position_closed);
        }

      if(m_cfg.management.post_partial_stop_action == MOHY_POST_PARTIAL_MOVE_TO_STRUCTURE)
        {
         double structure_stop = 0.0;
         if(!has_snapshot || !ResolveStructureTrailCandidate(snapshot, structure_stop))
           {
            SetLastAction("BlockedByGuard MoveToStructure");
            return false;
           }
         return ApplyManagedStopCandidate(tick,
                                          structure_stop,
                                          "PostPartialMoveToStructure",
                                          MOHY_ENGINE_EVENT_TRAILING_UPDATED,
                                          reference_price,
                                          rr_value,
                                          "PostPartialStop=MoveToStructure",
                                          out_position_closed);
        }

      return ProcessTrailing(snapshot,
                             has_snapshot,
                             tick,
                             true,
                             true,
                             out_position_closed);
     }

   bool ExecutePartialLeg(const CMohyPriceActionSnapshot &snapshot,
                          const bool has_snapshot,
                          const int leg_index,
                          const MqlTick &tick,
                          bool &out_position_closed)
     {
      out_position_closed = false;
      if(!m_position_state.has_open_trade || IsPartialLegDone(leg_index))
         return false;

      double target_price = 0.0;
      string target_diagnostics = "";
      if(!ResolvePartialTarget(leg_index, target_price, target_diagnostics))
         return false;

      const double exit_price = ResolveExitPrice(m_position_state.direction, tick);
      const bool target_hit = ((m_position_state.direction == MOHY_DIR_BULL &&
                                exit_price >= target_price - Eps()) ||
                               (m_position_state.direction == MOHY_DIR_BEAR &&
                                exit_price <= target_price + Eps()));
      if(!target_hit)
         return false;

      string filter_reason = "";
      if(!ManagementFiltersPass(tick, filter_reason))
        {
         SetLastAction(filter_reason);
         return false;
        }

      double current_volume = 0.0;
      double broker_stop = 0.0;
      double broker_target = 0.0;
      if(!LoadTrackedPositionQuotes(current_volume, broker_stop, broker_target) || current_volume <= Eps())
         return false;

      const double close_volume = ResolvePartialCloseVolume(leg_index, current_volume);
      if(close_volume <= Eps())
         return false;

      if(close_volume >= current_volume - ResolveVolumeStep() / 2.0)
        {
         LogManagementEvent(MOHY_ENGINE_EVENT_PARTIAL_EXECUTED,
                            StringFormat("Partial%dExit", leg_index),
                            target_price,
                            close_volume,
                            ResolveOpenR(tick),
                            target_diagnostics);
         out_position_closed = ResolveManagedFullExit(StringFormat("Partial%dExit", leg_index),
                                                      exit_price,
                                                      target_diagnostics);
         return out_position_closed;
        }

      m_trade.SetExpertMagicNumber((ulong)MathMax(0, m_cfg.risk.magic_number));
      m_trade.SetDeviationInPoints(MathMax(0, m_cfg.risk.slippage_points));
      const int attempts = MathMax(1, m_cfg.management.management_retry_count);
      bool closed = false;
      int retcode = 0;
      string retcode_description = "";
      for(int attempt = 0; attempt < attempts; ++attempt)
        {
         if(m_trade.PositionClosePartial((ulong)m_position_state.ticket, close_volume))
           {
            closed = true;
            break;
           }
         retcode = (int)m_trade.ResultRetcode();
         retcode_description = m_trade.ResultRetcodeDescription();
        }

      if(!closed)
        {
         StampManagementAction(StringFormat("Partial%dRetryExhausted", leg_index));
         SetLastAction(StringFormat("Partial%dFailed %d", leg_index, retcode));
         if(m_cfg.management.management_retry_then_market_close)
           {
            out_position_closed = ResolveManagedFullExit(StringFormat("Partial%dFallbackClose", leg_index),
                                                         exit_price,
                                                         retcode_description != "" ? retcode_description : target_diagnostics);
            return out_position_closed;
           }
         return false;
        }

      MarkPartialLegDone(leg_index);
      StampManagementAction(StringFormat("Partial%dExecuted", leg_index));
      SetLastAction(StringFormat("Partial%dExecuted %.5f", leg_index, target_price));
      LogManagementEvent(MOHY_ENGINE_EVENT_PARTIAL_EXECUTED,
                         StringFormat("Partial%dExecuted", leg_index),
                         target_price,
                         close_volume,
                         ResolveOpenR(tick),
                         target_diagnostics);

      double remaining_volume = 0.0;
      double remaining_stop = 0.0;
      double remaining_target = 0.0;
      if(!LoadTrackedPositionQuotes(remaining_volume, remaining_stop, remaining_target) || remaining_volume <= Eps())
         return true;

      if(m_cfg.management.runner_target_mode == MOHY_RUNNER_TRAIL_ONLY)
        {
         m_position_state.runner_trail_only_active = true;
         PersistTrackedPosition();
         if(RemoveRunnerTargetIfNeeded(tick, out_position_closed) && out_position_closed)
            return true;
         if(out_position_closed)
            return true;
        }

      bool stop_closed = false;
      ApplyPostPartialStopAction(snapshot, has_snapshot, tick, stop_closed);
      if(stop_closed)
         out_position_closed = true;
      return true;
     }

   bool ProcessPartials(const CMohyPriceActionSnapshot &snapshot,
                        const bool has_snapshot,
                        const MqlTick &tick,
                        bool &out_position_closed)
     {
      out_position_closed = false;
      if(!m_position_state.has_open_trade ||
         !m_position_state.post_be_started ||
         !IsPartialProfileEnabled())
         return false;

      bool changed = false;
      const int active_count = MathMax(1, MathMin(3, m_cfg.management.partial_count));
      for(int leg_index = 1; leg_index <= active_count; ++leg_index)
        {
         bool leg_closed = false;
         if(ExecutePartialLeg(snapshot, has_snapshot, leg_index, tick, leg_closed))
           {
            changed = true;
            if(leg_closed || !m_position_state.has_open_trade)
              {
               out_position_closed = true;
               return true;
              }
           }
        }
      return changed;
     }

   bool ManageOpenPosition(const CMohyPriceActionSnapshot &snapshot,
                           const bool has_snapshot,
                           const bool has_new_closed_bar)
     {
      if(!m_position_state.has_open_trade || m_blocked_multi_position)
         return false;

      MqlTick tick;
      if(!ReadTick(tick))
         return false;

      bool state_changed = false;
      const double reference_price = ResolveReferencePrice(m_position_state.direction, tick);

      // Deterministic management order follows the strategy contract:
      // BE activation -> post-BE start -> partials -> post-partial stop action -> trailing.
      if(m_position_state.break_even_armed &&
         !m_position_state.break_even_active &&
         m_position_state.impulse_extreme_reference > 0.0)
        {
         const bool touched = ((m_position_state.direction == MOHY_DIR_BULL &&
                                reference_price >= m_position_state.impulse_extreme_reference - Eps()) ||
                               (m_position_state.direction == MOHY_DIR_BEAR &&
                                reference_price <= m_position_state.impulse_extreme_reference + Eps()));
         if(touched && ActivateBreakEven(reference_price))
           {
            state_changed = true;
            if(!m_position_state.has_open_trade)
               return true;
           }
        }

      MohyPostBEStartReason start_reason = MOHY_POST_BE_START_REASON_NONE;
      const double open_r = ResolveOpenR(tick);
      if(ShouldStartPostBEManagement(tick, start_reason) &&
         StartPostBEManagement(start_reason, reference_price, open_r))
         state_changed = true;

      bool position_closed = false;
      if(ProcessPartials(snapshot, has_snapshot, tick, position_closed))
         state_changed = true;
      if(position_closed || !m_position_state.has_open_trade)
         return true;

      if(ProcessTrailing(snapshot,
                         has_snapshot,
                         tick,
                         has_new_closed_bar,
                         false,
                         position_closed))
         state_changed = true;
      if(position_closed || !m_position_state.has_open_trade)
         return true;

      if(m_position_state.virtual_stop_active && m_position_state.virtual_stop_level > 0.0)
        {
         const double exit_price = ResolveExitPrice(m_position_state.direction, tick);
         const bool stop_hit = ((m_position_state.direction == MOHY_DIR_BULL &&
                                 exit_price <= m_position_state.virtual_stop_level + Eps()) ||
                                (m_position_state.direction == MOHY_DIR_BEAR &&
                                 exit_price >= m_position_state.virtual_stop_level - Eps()));
         if(stop_hit)
            return ResolveManagedFullExit("VirtualStopExit", exit_price, "VirtualStopHit");
        }

      return state_changed;
     }

   void DropPendingState(const string cause)
     {
      m_waiting_state.pending_placed = false;
      m_waiting_state.pending_ticket = -1;
      m_waiting_state.last_transition_time = TimeCurrent();
      m_waiting_state.last_transition_cause = cause;
      PersistWaitingState();
      PublishWaitingLifecycle(MOHY_ENGINE_EVENT_TRIGGER_ADJUSTED,
                              cause,
                              m_waiting_state.last_transition_time,
                              m_waiting_state.trigger_price,
                              "");
     }

   bool HasRuntimeOwnedPendingOrders() const
     {
      const int total = OrdersTotal();
      for(int i = 0; i < total; ++i)
        {
         const ulong ticket = OrderGetTicket(i);
         if(ticket == 0 || !OrderSelect(ticket))
            continue;

         const string symbol = OrderGetString(ORDER_SYMBOL);
         const long magic = OrderGetInteger(ORDER_MAGIC);
         const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if(symbol != m_symbol)
            continue;
         if(m_cfg.risk.magic_number > 0 && magic != (long)m_cfg.risk.magic_number)
            continue;
         if(IsPendingOrderType(type))
            return true;
        }

      return false;
     }

   bool HasRuntimeOwnedExposure() const
     {
      if(HasWaitingState() || m_position_state.has_open_trade || HasRuntimeOwnedPendingOrders())
         return true;

      int ticket = -1;
      long type = -1;
      double volume = 0.0;
      double entry_price = 0.0;
      double stop_price = 0.0;
      double target_price = 0.0;
      datetime open_time = 0;
      return (CountMatchingPositions(ticket,
                                     type,
                                     volume,
                                     entry_price,
                                     stop_price,
                                     target_price,
                                     open_time) > 0);
     }

   UiActionOutcome BuildUiOutcome(const MohyUiActionId action_id,
                                  const string correlation_id,
                                  const MohyUiResultCode result_code,
                                  const string message,
                                  const int broker_error) const
     {
      UiActionOutcome outcome;
      outcome.action_id = action_id;
      outcome.correlation_id = correlation_id;
      outcome.result_code = result_code;
      outcome.message = message;
      outcome.broker_error = broker_error;
      outcome.severity = MohyUiSeverityFromResultCode(result_code);
      return outcome;
     }

   bool CanStageDangerousAction(const MohyUiActionId action_id,
                                string &out_message) const
     {
      out_message = "";
      if(action_id == MOHY_UI_ACTION_CANCEL_WAITING_ENTRIES)
        {
         if(HasWaitingState())
            return true;
         out_message = "NoWaitingEntry";
         return false;
        }

      if(action_id == MOHY_UI_ACTION_CLOSE_STRATEGY_TRADES)
        {
         if(m_blocked_multi_position)
           {
            out_message = "BlockedMultiplePositions";
            return false;
           }
         if(m_position_state.has_open_trade && m_position_state.ticket > 0)
            return true;
         out_message = "NoTrackedTrade";
         return false;
        }

      if(action_id == MOHY_UI_ACTION_EMERGENCY_FLATTEN)
        {
         if(HasRuntimeOwnedExposure())
            return true;
         out_message = "EmergencyFlattenNoop";
         return false;
        }

      return true;
     }

   UiActionOutcome ExecutePauseEntriesAction(const string correlation_id)
     {
      if(m_paused)
        {
         SetLastAction("AlreadyPaused");
         return BuildUiOutcome(MOHY_UI_ACTION_PAUSE_ENTRIES,
                               correlation_id,
                               MOHY_UI_RESULT_BLOCKED_BY_GUARD,
                               "AlreadyPaused",
                               0);
        }

      m_paused = true;
      m_waiting_state.paused_entries = true;
      if(HasWaitingState() &&
         m_waiting_state.trigger_mode == MOHY_ENTRY_REAL_PENDING_ORDER &&
         m_waiting_state.pending_placed &&
         m_waiting_state.pending_ticket > 0 &&
         !DeletePendingOrder(m_waiting_state.pending_ticket, "PausedPendingDelete"))
        {
         m_paused = false;
         m_waiting_state.paused_entries = false;
         const int broker_error = (int)m_trade.ResultRetcode();
         return BuildUiOutcome(MOHY_UI_ACTION_PAUSE_ENTRIES,
                               correlation_id,
                               broker_error > 0 ? MOHY_UI_RESULT_BROKER_REJECT : MOHY_UI_RESULT_FAILED,
                               m_last_action_result,
                               broker_error);
        }

      if(HasWaitingState() &&
         m_waiting_state.trigger_mode == MOHY_ENTRY_REAL_PENDING_ORDER &&
         m_waiting_state.pending_placed &&
         m_waiting_state.pending_ticket > 0)
         DropPendingState("PausedPendingSuspended");
      PersistPauseFlag();
      PersistWaitingState();
      SetLastAction("Paused");
      return BuildUiOutcome(MOHY_UI_ACTION_PAUSE_ENTRIES,
                            correlation_id,
                            MOHY_UI_RESULT_SUCCESS,
                            "Paused",
                            0);
     }

   UiActionOutcome ExecuteResumeEntriesAction(const string correlation_id)
     {
      if(!m_paused)
        {
         SetLastAction("AlreadyActive");
         return BuildUiOutcome(MOHY_UI_ACTION_RESUME_ENTRIES,
                               correlation_id,
                               MOHY_UI_RESULT_BLOCKED_BY_GUARD,
                               "AlreadyActive",
                               0);
        }

      m_paused = false;
      m_waiting_state.paused_entries = false;
      PersistPauseFlag();
      PersistWaitingState();
      SetLastAction("Resumed");
      return BuildUiOutcome(MOHY_UI_ACTION_RESUME_ENTRIES,
                            correlation_id,
                            MOHY_UI_RESULT_SUCCESS,
                            "Resumed",
                            0);
     }

   UiActionOutcome ExecuteCancelWaitingAction(const string correlation_id)
     {
      if(!HasWaitingState())
        {
         SetLastAction("NoWaitingEntry");
         return BuildUiOutcome(MOHY_UI_ACTION_CANCEL_WAITING_ENTRIES,
                               correlation_id,
                               MOHY_UI_RESULT_BLOCKED_BY_GUARD,
                               "NoWaitingEntry",
                               0);
        }

      if(CancelWaitingEntry("ManualCancelWaiting", true))
         return BuildUiOutcome(MOHY_UI_ACTION_CANCEL_WAITING_ENTRIES,
                               correlation_id,
                               MOHY_UI_RESULT_SUCCESS,
                               m_last_action_result,
                               0);

      const int broker_error = (int)m_trade.ResultRetcode();
      return BuildUiOutcome(MOHY_UI_ACTION_CANCEL_WAITING_ENTRIES,
                            correlation_id,
                            broker_error > 0 ? MOHY_UI_RESULT_BROKER_REJECT : MOHY_UI_RESULT_FAILED,
                            m_last_action_result,
                            broker_error);
     }

   UiActionOutcome ExecuteCloseTrackedTradeAction(const string correlation_id)
     {
      if(!m_position_state.has_open_trade || m_position_state.ticket <= 0)
        {
         SetLastAction("NoTrackedTrade");
         return BuildUiOutcome(MOHY_UI_ACTION_CLOSE_STRATEGY_TRADES,
                               correlation_id,
                               MOHY_UI_RESULT_BLOCKED_BY_GUARD,
                               "NoTrackedTrade",
                               0);
        }
      if(m_blocked_multi_position)
        {
         SetLastAction("BlockedMultiplePositions");
         return BuildUiOutcome(MOHY_UI_ACTION_CLOSE_STRATEGY_TRADES,
                               correlation_id,
                               MOHY_UI_RESULT_BLOCKED_BY_GUARD,
                               "BlockedMultiplePositions",
                               0);
        }

      if(CloseTrackedTrade("ManualCloseTrade", "OperatorCloseStrategyTrades"))
         return BuildUiOutcome(MOHY_UI_ACTION_CLOSE_STRATEGY_TRADES,
                               correlation_id,
                               MOHY_UI_RESULT_SUCCESS,
                               m_last_action_result,
                               0);

      const int broker_error = (int)m_trade.ResultRetcode();
      return BuildUiOutcome(MOHY_UI_ACTION_CLOSE_STRATEGY_TRADES,
                            correlation_id,
                            broker_error > 0 ? MOHY_UI_RESULT_BROKER_REJECT : MOHY_UI_RESULT_FAILED,
                            m_last_action_result,
                            broker_error);
     }

   UiActionOutcome ExecuteEmergencyFlattenAction(const string correlation_id)
     {
      if(!HasRuntimeOwnedExposure())
        {
         SetLastAction("EmergencyFlattenNoop");
         return BuildUiOutcome(MOHY_UI_ACTION_EMERGENCY_FLATTEN,
                               correlation_id,
                               MOHY_UI_RESULT_BLOCKED_BY_GUARD,
                               "EmergencyFlattenNoop",
                               0);
        }

      if(EmergencyFlattenAll())
         return BuildUiOutcome(MOHY_UI_ACTION_EMERGENCY_FLATTEN,
                               correlation_id,
                               MOHY_UI_RESULT_SUCCESS,
                               m_last_action_result,
                               0);

      const int broker_error = (int)m_trade.ResultRetcode();
      return BuildUiOutcome(MOHY_UI_ACTION_EMERGENCY_FLATTEN,
                            correlation_id,
                            broker_error > 0 ? MOHY_UI_RESULT_BROKER_REJECT : MOHY_UI_RESULT_FAILED,
                            m_last_action_result,
                            broker_error);
     }

   UiActionOutcome ExecuteImmediateUiAction(const MohyUiActionId action_id,
                                            const string correlation_id)
     {
      if(action_id == MOHY_UI_ACTION_PAUSE_ENTRIES)
         return ExecutePauseEntriesAction(correlation_id);
      if(action_id == MOHY_UI_ACTION_RESUME_ENTRIES)
         return ExecuteResumeEntriesAction(correlation_id);
      if(action_id == MOHY_UI_ACTION_CANCEL_WAITING_ENTRIES)
         return ExecuteCancelWaitingAction(correlation_id);
      if(action_id == MOHY_UI_ACTION_CLOSE_STRATEGY_TRADES)
         return ExecuteCloseTrackedTradeAction(correlation_id);
      if(action_id == MOHY_UI_ACTION_EMERGENCY_FLATTEN)
         return ExecuteEmergencyFlattenAction(correlation_id);

      return BuildUiOutcome(action_id,
                            correlation_id,
                            MOHY_UI_RESULT_FAILED,
                            "UnknownUiAction",
                            0);
     }

   void HandleUiAction(const MohyUiActionId action_id)
     {
      ExpirePendingUiActionIfNeeded();

      const string action_name = MohyUiActionIdToString(action_id);
      const string pre_state_hash = BuildUiStateHash();

      if(IsDangerousUiAction(action_id))
        {
         const int cooldown_remaining = DangerousActionCooldownRemainingSeconds();
         if(cooldown_remaining > 0)
           {
            const string correlation_id = BuildUiCorrelationId(action_id, pre_state_hash);
            const UiActionOutcome outcome = BuildUiOutcome(action_id,
                                                           correlation_id,
                                                           MOHY_UI_RESULT_COOLDOWN_ACTIVE,
                                                           StringFormat("CooldownActive %ds", cooldown_remaining),
                                                           0);
            SetLastAction(outcome.message);
            RecordUiAudit("Outcome",
                          action_id,
                          correlation_id,
                          pre_state_hash,
                          pre_state_hash,
                          outcome.result_code,
                          outcome.severity,
                          outcome.broker_error,
                          outcome.message);
            EmitRuntimeAlert(outcome.severity,
                             StringFormat("UI_%s_%s", action_name, MohyUiResultCodeToString(outcome.result_code)),
                             StringFormat("%s: %s", action_name, outcome.message));
            return;
           }

         if(PendingUiActionActive() && m_pending_ui_action.action_id != action_id)
           {
            RecordUiAudit("Expired",
                          m_pending_ui_action.action_id,
                          m_pending_ui_action.correlation_id,
                          m_pending_ui_action.pre_state_hash,
                          pre_state_hash,
                          MOHY_UI_RESULT_CONFIRMATION_EXPIRED,
                          MohyUiSeverityFromResultCode(MOHY_UI_RESULT_CONFIRMATION_EXPIRED),
                          0,
                          "SupersededByNewAction");
            ResetPendingUiAction();
           }

         if(!PendingUiActionActive())
           {
            string stage_guard = "";
            if(!CanStageDangerousAction(action_id, stage_guard))
              {
               const string correlation_id = BuildUiCorrelationId(action_id, pre_state_hash);
               const UiActionOutcome outcome = BuildUiOutcome(action_id,
                                                              correlation_id,
                                                              MOHY_UI_RESULT_BLOCKED_BY_GUARD,
                                                              stage_guard,
                                                              0);
               SetLastAction(outcome.message);
               RecordUiAudit("Outcome",
                             action_id,
                             correlation_id,
                             pre_state_hash,
                             pre_state_hash,
                             outcome.result_code,
                             outcome.severity,
                             outcome.broker_error,
                             outcome.message);
               EmitRuntimeAlert(outcome.severity,
                                StringFormat("UI_%s_%s", action_name, MohyUiResultCodeToString(outcome.result_code)),
                                StringFormat("%s: %s", action_name, outcome.message));
               return;
              }

            m_pending_ui_action.action_id = action_id;
            m_pending_ui_action.correlation_id = BuildUiCorrelationId(action_id, pre_state_hash);
            m_pending_ui_action.pre_state_hash = pre_state_hash;
            m_pending_ui_action.accepted_at = TimeCurrent();
            SetLastAction(StringFormat("Confirm %s", action_name));
            RecordUiAudit("Intent",
                          action_id,
                          m_pending_ui_action.correlation_id,
                          pre_state_hash,
                          pre_state_hash,
                          MOHY_UI_RESULT_SUCCESS,
                          MohyUiSeverityFromResultCode(MOHY_UI_RESULT_SUCCESS),
                          0,
                          "IntentAccepted");
            return;
           }

         RecordUiAudit("Confirmed",
                       action_id,
                       m_pending_ui_action.correlation_id,
                       m_pending_ui_action.pre_state_hash,
                       pre_state_hash,
                       MOHY_UI_RESULT_SUCCESS,
                       MohyUiSeverityFromResultCode(MOHY_UI_RESULT_SUCCESS),
                       0,
                       "ConfirmationAccepted");
        }

      const string correlation_id = PendingUiActionActive()
                                    ? m_pending_ui_action.correlation_id
                                    : BuildUiCorrelationId(action_id, pre_state_hash);
      if(!PendingUiActionActive())
         RecordUiAudit("Intent",
                       action_id,
                       correlation_id,
                       pre_state_hash,
                       pre_state_hash,
                       MOHY_UI_RESULT_SUCCESS,
                       MohyUiSeverityFromResultCode(MOHY_UI_RESULT_SUCCESS),
                       0,
                       "IntentAccepted");

      if(IsDangerousUiAction(action_id))
         ResetPendingUiAction();

      const UiActionOutcome outcome = ExecuteImmediateUiAction(action_id, correlation_id);
      if(IsDangerousUiAction(action_id) &&
         outcome.result_code != MOHY_UI_RESULT_BLOCKED_BY_GUARD &&
         outcome.result_code != MOHY_UI_RESULT_COOLDOWN_ACTIVE &&
         outcome.result_code != MOHY_UI_RESULT_CONFIRMATION_EXPIRED)
         MarkDangerousActionAttempted(action_id);

      RecordUiAudit("Outcome",
                    action_id,
                    correlation_id,
                    pre_state_hash,
                    BuildUiStateHash(),
                    outcome.result_code,
                    outcome.severity,
                    outcome.broker_error,
                    outcome.message);
      EmitRuntimeAlert(outcome.severity,
                       StringFormat("UI_%s_%s", action_name, MohyUiResultCodeToString(outcome.result_code)),
                       StringFormat("%s: %s", action_name, outcome.message));
     }

   bool CancelWaitingEntry(const string reason_code,
                           const bool mark_consumed)
     {
      if(!HasWaitingState())
        {
         SetLastAction("NoWaitingEntry");
         return false;
        }

      if(m_waiting_state.pending_placed &&
         m_waiting_state.pending_ticket > 0 &&
         !DeletePendingOrder(m_waiting_state.pending_ticket, "CancelWaiting"))
         return false;

      if(mark_consumed)
        {
         PublishResolvedWaitingLifecycle(MOHY_ENGINE_EVENT_INVALIDATION,
                                         reason_code,
                                         TimeCurrent(),
                                         m_waiting_state.trigger_price,
                                         reason_code);
         MarkConsumedImpulse(m_waiting_state.impulse_id,
                             m_waiting_state.setup_key,
                             MOHY_IMPULSE_CONSUMED_MANUAL_CANCELLED,
                             reason_code);
        }
      SetLastAction(reason_code);
      ClearWaitingState(reason_code);
      return true;
     }

   bool CloseTrackedTrade(const string reason_code,
                         const string diagnostics)
     {
      if(!m_position_state.has_open_trade || m_position_state.ticket <= 0)
        {
         SetLastAction("NoTrackedTrade");
         return false;
        }
      if(m_blocked_multi_position)
        {
         SetLastAction("BlockedMultiplePositions");
         return false;
        }

       if(!CloseOpenTrade(reason_code, 0.0, diagnostics))
          return false;

       const PositionManagementState closed_state = m_position_state;
       const string impulse_id = closed_state.impulse_id;
       const string setup_key = closed_state.setup_key;
       PublishResolvedPositionLifecycle(closed_state,
                                        MOHY_ENGINE_EVENT_EXIT_RESOLVED,
                                        reason_code,
                                        0.0,
                                        diagnostics);
       MarkConsumedImpulse(impulse_id,
                           setup_key,
                           MOHY_IMPULSE_CONSUMED_EXITED,
                           diagnostics);
      MohyResetManagementState(m_position_state);
      PersistTrackedPosition();
      SetLastAction(reason_code);
      return true;
     }

   bool EmergencyFlattenAll()
     {
      bool changed = false;
      bool failed = false;
      const PositionManagementState tracked_state = m_position_state;
      const string tracked_impulse_id = tracked_state.impulse_id;
      const string tracked_setup_key = tracked_state.setup_key;

      const int total_orders = OrdersTotal();
      for(int i = total_orders - 1; i >= 0; --i)
        {
         const ulong ticket = OrderGetTicket(i);
         if(ticket == 0 || !OrderSelect(ticket))
            continue;

         const string symbol = OrderGetString(ORDER_SYMBOL);
         const long magic = OrderGetInteger(ORDER_MAGIC);
         const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if(symbol != m_symbol)
            continue;
         if(m_cfg.risk.magic_number > 0 && magic != (long)m_cfg.risk.magic_number)
            continue;
         if(!IsPendingOrderType(type))
            continue;

         changed = true;
         if(!DeletePendingOrder((int)ticket, "EmergencyFlattenOrder"))
            failed = true;
        }

      const int total_positions = PositionsTotal();
      for(int i = total_positions - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;

         const string symbol = PositionGetString(POSITION_SYMBOL);
         const long magic = PositionGetInteger(POSITION_MAGIC);
         if(symbol != m_symbol)
            continue;
         if(m_cfg.risk.magic_number > 0 && magic != (long)m_cfg.risk.magic_number)
            continue;

         changed = true;
         m_trade.SetExpertMagicNumber((ulong)MathMax(0, m_cfg.risk.magic_number));
         m_trade.SetDeviationInPoints(MathMax(0, m_cfg.risk.slippage_points));
         if(!m_trade.PositionClose(ticket))
            failed = true;
        }

       if(HasWaitingState())
         {
          PublishResolvedWaitingLifecycle(MOHY_ENGINE_EVENT_INVALIDATION,
                                          "EmergencyFlatten",
                                          TimeCurrent(),
                                          m_waiting_state.trigger_price,
                                          "EmergencyFlatten");
          MarkConsumedImpulse(m_waiting_state.impulse_id,
                              m_waiting_state.setup_key,
                              MOHY_IMPULSE_CONSUMED_MANUAL_CANCELLED,
                              "EmergencyFlatten");
         ClearWaitingState("EmergencyFlatten");
         changed = true;
        }

       if(tracked_impulse_id != "")
        {
         PublishResolvedPositionLifecycle(tracked_state,
                                          MOHY_ENGINE_EVENT_EXIT_RESOLVED,
                                          "EmergencyFlatten",
                                          0.0,
                                          "EmergencyFlatten");
         m_logger.LogEvent(m_cfg,
                           m_symbol,
                           tracked_setup_key,
                           tracked_impulse_id,
                           tracked_state.direction,
                           MOHY_SETUP_ENTERED,
                           MOHY_TRADE_PHASE_EXITED,
                           MOHY_ENGINE_EVENT_EXIT_RESOLVED,
                           "EmergencyFlatten",
                           TimeCurrent(),
                           0,
                           0.0,
                           tracked_state.break_even_level,
                           0.0,
                           "EmergencyFlatten",
                           "RuntimeEngine");
         MarkConsumedImpulse(tracked_impulse_id,
                             tracked_setup_key,
                             MOHY_IMPULSE_CONSUMED_EXITED,
                             "EmergencyFlatten");
        }

      MohyResetManagementState(m_position_state);
      PersistTrackedPosition();
      if(failed)
        {
         SetLastAction("EmergencyFlattenPartialFailure");
         return false;
        }

      SetLastAction(changed ? "EmergencyFlattened" : "EmergencyFlattenNoop");
      return changed;
     }

   bool ExecutePlan(const MohyTradeSetupPlanFact &plan,
                    const MohyPotentialCorrectionFact &correction,
                    const string setup_key,
                    const string impulse_id,
                    const string cause);

   bool UpdateOpenPositionState();

   bool HasNewClosedBar()
     {
      const datetime latest_closed_bar = MohyITime(m_symbol, m_cfg.execution_timeframe, 1);
      if(latest_closed_bar <= 0)
         return false;
      if(m_last_closed_bar_time == 0)
        {
         m_last_closed_bar_time = latest_closed_bar;
         return false;
        }
      if(latest_closed_bar != m_last_closed_bar_time)
        {
         m_last_closed_bar_time = latest_closed_bar;
         return true;
        }
      return false;
     }

   void BuildPanelSnapshot(const string selected_setup_key,
                           const string selected_impulse_id,
                           const bool has_selected_plan,
                           const MohyTradeSetupPlanFact &selected_plan,
                           const CMohyPriceActionSnapshot &snapshot);

   void ProcessSelectedPlan(const CMohyPriceActionSnapshot &snapshot,
                            const int selected_plan_index,
                            const bool has_new_closed_bar);
   void RenderReadOnlyPanel();

public:
            CMohyRuntimeEngine();

   void     Configure(const StrategyConfig &cfg,
                      const string symbol,
                      const int lookback_bars,
                      const bool panel_enabled,
                      const int panel_corner,
                      const int panel_x,
                      const int panel_y,
                      const MohyRuntimeRoleMode runtime_role = MOHY_RUNTIME_ROLE_GLOBAL_LIVE);

   bool     Initialize();
   void     Shutdown();
   void     OnTick();
   void     OnChartEvent(const int id,
                         const long &lparam,
                         const double &dparam,
                         const string &sparam);
  };

CMohyRuntimeEngine::CMohyRuntimeEngine()
  {
   MohySetDefaultStrategyConfig(m_cfg);
   m_symbol = Symbol();
   m_lookback_bars = 1600;
   m_panel_enabled = true;
   m_panel_corner = CORNER_RIGHT_UPPER;
   m_panel_x = 20;
   m_panel_y = 20;
   m_scope_tag = "";
   m_paused = false;
   m_blocked_multi_position = false;
   m_last_action_result = "Idle";
   m_last_closed_bar_time = 0;
   m_initialized = false;
   m_last_dangerous_action_id = MOHY_UI_ACTION_NONE;
   m_last_dangerous_action_time = 0;
   m_last_panel_snapshot_hash = "";
   m_last_panel_redraw_ms = 0;
   m_multi_position_alerted = false;
   m_runtime_role = MOHY_RUNTIME_ROLE_GLOBAL_LIVE;
   ResetPendingUiAction();
   MohyResetSetupState(m_waiting_state);
   MohyResetManagementState(m_position_state);
   ArrayResize(m_consumed_impulses, 0);
   ArrayResize(m_lifecycle_records, 0);
  }

void CMohyRuntimeEngine::Configure(const StrategyConfig &cfg,
                                   const string symbol,
                                   const int lookback_bars,
                                   const bool panel_enabled,
                                   const int panel_corner,
                                   const int panel_x,
                                   const int panel_y,
                                   const MohyRuntimeRoleMode runtime_role)
  {
   m_cfg = cfg;
   m_symbol = symbol;
   m_lookback_bars = MathMax(100, lookback_bars);
   m_runtime_role = runtime_role;
   m_panel_enabled = panel_enabled;
   m_panel_corner = panel_corner;
   m_panel_x = panel_x;
   m_panel_y = panel_y;
   m_scope_tag = MohyRuntimeBuildScopeTag(m_symbol,
                                         m_cfg.context_timeframe,
                                         m_cfg.execution_timeframe,
                                         m_cfg.risk.magic_number);
   m_planner.Configure(m_cfg, m_cfg.execution_timeframe);
   m_store.Configure(m_scope_tag);
   m_logger.Configure(m_scope_tag, ChartID());
   m_audit.Configure(m_scope_tag,
                     ChartID(),
                     m_cfg.ui.enable_file_audit,
                     m_cfg.ui.enable_terminal_alerts);
   m_panel.Configure(ChartID(),
                     StringFormat("MOHY_EA_%I64d_", ChartID()),
                     m_panel_enabled,
                     m_panel_corner,
                     m_panel_x,
                     m_panel_y);
  }

bool CMohyRuntimeEngine::Initialize()
  {
   if(IsExecutionAuthorityEnabled())
     {
      m_blocked_multi_position = false;
      m_multi_position_alerted = false;
      MohyResetSetupState(m_waiting_state);
      MohyResetManagementState(m_position_state);
      ArrayResize(m_consumed_impulses, 0);
      ArrayResize(m_lifecycle_records, 0);
      m_store.LoadPauseFlag(m_paused);
      m_store.LoadConsumedImpulses(m_consumed_impulses);
      m_store.LoadLifecycleRecords(m_lifecycle_records);
      m_store.LoadWaitingState(m_waiting_state);
      // Runtime instances are recreated per scanner cycle in TradeEA; restore the
      // persisted tracked position first so closed trades are consumed deterministically.
      m_store.LoadTrackedPosition(m_position_state);
      m_waiting_state.paused_entries = m_paused;
     }
   else
     {
      m_paused = false;
      m_blocked_multi_position = false;
      MohyResetSetupState(m_waiting_state);
      MohyResetManagementState(m_position_state);
      ArrayResize(m_consumed_impulses, 0);
      ArrayResize(m_lifecycle_records, 0);
      SetLastAction(StringFormat("Mode=%s", MohyRuntimeRoleModeToString(m_runtime_role)));
     }
   ResetPendingUiAction();
   if(IsExecutionAuthorityEnabled())
      UpdateOpenPositionState();
   m_last_closed_bar_time = MohyITime(m_symbol, m_cfg.execution_timeframe, 1);
   MohyTradeSetupPlanFact empty_plan;
   empty_plan.valid = false;
   CMohyPriceActionSnapshot empty_snapshot;
   empty_snapshot.Reset();
   BuildPanelSnapshot("", "", false, empty_plan, empty_snapshot);
   m_initialized = true;
   return true;
  }

void CMohyRuntimeEngine::Shutdown()
  {
   if(IsExecutionAuthorityEnabled())
     {
      ExpirePendingUiActionIfNeeded();
      PersistPauseFlag();
      PersistWaitingState();
      PersistTrackedPosition();
     }
   m_panel.Clear();
   m_initialized = false;
  }

bool CMohyRuntimeEngine::ExecutePlan(const MohyTradeSetupPlanFact &plan,
                                     const MohyPotentialCorrectionFact &correction,
                                     const string setup_key,
                                     const string impulse_id,
                                     const string cause)
  {
   string trade_guard = "";
   if(!IsTradeAllowedNow(trade_guard))
     {
      SetLastAction(trade_guard);
      return false;
     }
   if(plan.lots_normalized <= 0.0)
     {
      SetLastAction("LotsInvalid");
      return false;
     }
   if(!plan.spread_pass || !plan.exposure_pass)
     {
      SetLastAction("PlanGuardsFailed");
      return false;
     }

   m_trade.SetExpertMagicNumber((ulong)MathMax(0, m_cfg.risk.magic_number));
   m_trade.SetDeviationInPoints(MathMax(0, m_cfg.risk.slippage_points));
   const string comment = BuildExecutionComment(setup_key);

   bool sent = false;
   if(plan.direction == MOHY_DIR_BULL)
      sent = m_trade.Buy(plan.lots_normalized, m_symbol, 0.0, plan.stop_price, plan.target_price, comment);
   else if(plan.direction == MOHY_DIR_BEAR)
      sent = m_trade.Sell(plan.lots_normalized, m_symbol, 0.0, plan.stop_price, plan.target_price, comment);

   if(!sent)
     {
      SetLastAction(StringFormat("OrderSendFailed %d", (int)m_trade.ResultRetcode()));
      m_logger.LogEvent(m_cfg,
                        m_symbol,
                        setup_key,
                        impulse_id,
                        plan.direction,
                        HasWaitingState() ? m_waiting_state.lifecycle_phase : MOHY_SETUP_CONTINUATION_CONFIRMED,
                        m_position_state.trade_phase,
                        MOHY_ENGINE_EVENT_PLAN_REJECTED,
                        "ExecutionFailed",
                        TimeCurrent(),
                        0,
                        plan.trigger_price,
                        0.0,
                        plan.reward_to_risk,
                        m_trade.ResultRetcodeDescription(),
                        "RuntimeEngine");
      return false;
     }

   int ticket = -1;
   long type = -1;
   double volume = 0.0;
   double entry_price = 0.0;
   double stop_price = 0.0;
   double target_price = 0.0;
   datetime open_time = 0;
   const int match_count = CountMatchingPositions(ticket,
                                                  type,
                                                  volume,
                                                  entry_price,
                                                  stop_price,
                                                  target_price,
                                                  open_time);
    if(match_count == 1 && ticket > 0)
      {
       BindOpenPosition(ticket,
                        type,
                        volume,
                        entry_price,
                        stop_price,
                        target_price,
                        open_time,
                        setup_key,
                        impulse_id,
                        false);
       SeedManagementFromPlan(plan, correction);
      }

   SetLastAction(StringFormat("EntryExecuted %s", cause));
   m_logger.LogEvent(m_cfg,
                     m_symbol,
                     setup_key,
                     impulse_id,
                     plan.direction,
                     MOHY_SETUP_ENTERED,
                     m_position_state.trade_phase,
                     MOHY_ENGINE_EVENT_ENTRY_EXECUTED,
                     cause,
                     TimeCurrent(),
                     0,
                     plan.trigger_price,
                     plan.target_price,
                     plan.reward_to_risk,
                     plan.diagnostics,
                     "RuntimeEngine");
    EmitRuntimeAlert(MOHY_UI_ALERT_INFO,
                     StringFormat("EntryExecuted_%s", setup_key),
                     StringFormat("Entry executed for %s (%s).",
                                  setup_key,
                                  MohyDirectionToString(plan.direction)));
    PublishOpenLifecycle(MOHY_ENGINE_EVENT_ENTRY_EXECUTED,
                         cause,
                         m_position_state.opened_time > 0 ? m_position_state.opened_time : TimeCurrent(),
                         plan.diagnostics);
    ClearWaitingState("Entered");
    return true;
  }

bool CMohyRuntimeEngine::UpdateOpenPositionState()
  {
   int ticket = -1;
   long type = -1;
   double volume = 0.0;
   double entry_price = 0.0;
   double stop_price = 0.0;
   double target_price = 0.0;
   datetime open_time = 0;
   const int match_count = CountMatchingPositions(ticket,
                                                  type,
                                                  volume,
                                                  entry_price,
                                                  stop_price,
                                                  target_price,
                                                  open_time);
   const bool was_blocked_multi_position = m_blocked_multi_position;
   m_blocked_multi_position = (match_count > 1);
   if(m_blocked_multi_position)
     {
      SetLastAction("BlockedMultiplePositions");
      if(!was_blocked_multi_position || !m_multi_position_alerted)
        {
         EmitRuntimeAlert(MOHY_UI_ALERT_CRITICAL,
                          "RuntimeBlockedMultiPosition",
                          "Multiple matching MOHY positions detected; runtime blocked until manual cleanup.");
         m_multi_position_alerted = true;
        }
      return false;
     }
   m_multi_position_alerted = false;
   if(was_blocked_multi_position)
      EmitRuntimeAlert(MOHY_UI_ALERT_INFO,
                       "RuntimeBlockedMultiPositionCleared",
                       "MOHY multi-position blocked state cleared.");

    if(m_position_state.has_open_trade)
      {
        if(match_count <= 0)
         {
          const PositionManagementState closed_state = m_position_state;
          const string closed_impulse_id = closed_state.impulse_id;
          const string closed_setup_key = closed_state.setup_key;
          datetime resolved_at = TimeCurrent();
          double resolved_price = 0.0;
          string exit_note = "";
          ResolveExitDeal(closed_state.ticket,
                          closed_state.opened_time,
                          resolved_at,
                          resolved_price,
                          exit_note);
          m_logger.LogEvent(m_cfg,
                            m_symbol,
                            closed_setup_key,
                            closed_impulse_id,
                            closed_state.direction,
                            MOHY_SETUP_ENTERED,
                            MOHY_TRADE_PHASE_EXITED,
                            MOHY_ENGINE_EVENT_EXIT_RESOLVED,
                            "BrokerPositionClosed",
                            resolved_at,
                            0,
                            (resolved_price > 0.0) ? resolved_price : closed_state.entry_price,
                            closed_state.target_price,
                            0.0,
                            CombineDiagnostics("PositionClosed", exit_note),
                            "RuntimeEngine");
          PublishResolvedPositionLifecycle(closed_state,
                                           MOHY_ENGINE_EVENT_EXIT_RESOLVED,
                                           "BrokerPositionClosed",
                                           resolved_price,
                                           "PositionClosed");
          MarkConsumedImpulse(closed_impulse_id,
                              closed_setup_key,
                              MOHY_IMPULSE_CONSUMED_EXITED,
                              "BrokerPositionClosed");
         MohyResetManagementState(m_position_state);
         PersistTrackedPosition();
         SetLastAction("PositionClosed");
         return false;
        }

      BindOpenPosition(ticket,
                       type,
                       volume,
                       entry_price,
                       stop_price,
                       target_price,
                       open_time,
                       m_position_state.setup_key,
                       m_position_state.impulse_id,
                       m_position_state.recovered);
      if(HasWaitingState() && m_waiting_state.setup_key == m_position_state.setup_key)
         ClearWaitingState("PositionActive");
      return true;
     }

   if(match_count == 1 && ticket > 0)
     {
       PositionManagementState persisted;
       MohyResetManagementState(persisted);
       m_store.LoadTrackedPosition(persisted);
       BindOpenPosition(ticket,
                        type,
                       volume,
                       entry_price,
                       stop_price,
                       target_price,
                       open_time,
                        persisted.setup_key,
                        persisted.impulse_id,
                        true);
       CopyManagementFields(m_position_state, persisted);
       PersistTrackedPosition();
       if(HasWaitingState() && m_waiting_state.setup_key == m_position_state.setup_key)
          ClearWaitingState("RecoveredPosition");
       SetLastAction("RecoveredOpenTrade");
      m_logger.LogEvent(m_cfg,
                        m_symbol,
                        m_position_state.setup_key,
                        m_position_state.impulse_id,
                        m_position_state.direction,
                        MOHY_SETUP_ENTERED,
                        m_position_state.trade_phase,
                        MOHY_ENGINE_EVENT_ENTRY_EXECUTED,
                        "RecoveredOpenTrade",
                        open_time,
                        0,
                        entry_price,
                        target_price,
                        0.0,
                        "RecoveredFromBrokerPosition",
                        "RuntimeEngine");
      PublishOpenLifecycle(MOHY_ENGINE_EVENT_ENTRY_EXECUTED,
                           "RecoveredOpenTrade",
                           open_time,
                           "RecoveredFromBrokerPosition");
      EmitRuntimeAlert(MOHY_UI_ALERT_INFO,
                       "RecoveredOpenTrade",
                       StringFormat("Recovered open MOHY trade %d.", ticket));
      return true;
     }

   return false;
  }

void CMohyRuntimeEngine::BuildPanelSnapshot(const string selected_setup_key,
                                            const string selected_impulse_id,
                                            const bool has_selected_plan,
                                            const MohyTradeSetupPlanFact &selected_plan,
                                            const CMohyPriceActionSnapshot &snapshot)
  {
   UiRuntimeSnapshot panel_snapshot;
   panel_snapshot.symbol = m_symbol;
   panel_snapshot.scope_tag = m_scope_tag;
   panel_snapshot.timeframe = MohyTimeframeToString((int)_Period);
   panel_snapshot.context_timeframe = MohyTimeframeToString(m_cfg.context_timeframe);
   panel_snapshot.execution_timeframe = MohyTimeframeToString(m_cfg.execution_timeframe);
   const MohyEntryExecutionMode snapshot_mode = m_position_state.has_open_trade
                                                ? m_position_state.execution_mode
                                                : (HasWaitingState() ? m_waiting_state.trigger_mode
                                                                     : m_cfg.entry.execution_mode);
   panel_snapshot.execution_mode = (snapshot_mode == MOHY_ENTRY_REAL_PENDING_ORDER)
                                   ? "RealPendingOrder"
                                   : "VirtualTrigger";
   panel_snapshot.pause_state = m_paused ? "Paused" : "Active";
   if(!IsExecutionAuthorityEnabled())
      panel_snapshot.pause_state = StringFormat("%s/%s",
                                               panel_snapshot.pause_state,
                                               MohyRuntimeRoleModeToString(m_runtime_role));
   panel_snapshot.setup_key = m_position_state.has_open_trade
                              ? m_position_state.setup_key
                              : ((selected_setup_key != "") ? selected_setup_key : m_waiting_state.setup_key);
   panel_snapshot.impulse_id = m_position_state.has_open_trade
                               ? m_position_state.impulse_id
                               : ((selected_impulse_id != "") ? selected_impulse_id : m_waiting_state.impulse_id);
   panel_snapshot.strategy_phase = m_position_state.has_open_trade
                                   ? MohyTradePhaseToString(m_position_state.trade_phase)
                                   : (HasWaitingState() ? MohySetupPhaseToString(m_waiting_state.lifecycle_phase) : "Idle");
   panel_snapshot.setup_validity = has_selected_plan
                                   ? MohyTradeSetupPlanStateToString(selected_plan.plan_state)
                                   : (HasWaitingState() ? "WaitingForPullback" : "None");
   panel_snapshot.position_state = m_blocked_multi_position
                                   ? "Blocked"
                                   : (m_position_state.has_open_trade
                                      ? (m_position_state.recovered ? "Recovered" : "Open")
                                      : "None");
   if(HasWaitingState() && m_waiting_state.trigger_mode == MOHY_ENTRY_REAL_PENDING_ORDER)
      panel_snapshot.trigger_state = m_waiting_state.pending_placed
                                     ? StringFormat("#%d @ %.5f", m_waiting_state.pending_ticket, m_waiting_state.trigger_price)
                                     : StringFormat("Armed @ %.5f", m_waiting_state.trigger_price);
   else if(HasWaitingState())
      panel_snapshot.trigger_state = StringFormat("%.5f", m_waiting_state.trigger_price);
   else
      panel_snapshot.trigger_state = "None";
   panel_snapshot.rr_state = HasWaitingState() ? (m_waiting_state.rr_state ? "Pass" : "Fail") : "n/a";
   panel_snapshot.spread_gate_state = HasWaitingState() ? (m_waiting_state.spread_gate_state ? "Pass" : "Fail") : "n/a";
   panel_snapshot.open_risk_state = m_position_state.has_open_trade ? "Open" : "Flat";
   panel_snapshot.exposure_state = "KernelPlan";
   panel_snapshot.sl_mode = IntegerToString((int)m_cfg.sl_mode);
   panel_snapshot.tp_mode = IntegerToString((int)m_cfg.tp_mode);
   if(!m_cfg.management.enable_break_even_on_impulse_extreme)
      panel_snapshot.break_even_state = "Disabled";
   else if(m_position_state.has_open_trade && m_position_state.break_even_active)
      panel_snapshot.break_even_state = m_position_state.recovered ? "RiskFreeRecovered" : "RiskFree";
   else if(m_position_state.has_open_trade && m_position_state.break_even_armed)
      panel_snapshot.break_even_state = m_position_state.recovered ? "ArmedRecovered" : "Armed";
   else if(m_position_state.has_open_trade)
      panel_snapshot.break_even_state = "Open";
   else
      panel_snapshot.break_even_state = "Flat";
   const MohyPostBEProfile panel_profile = m_position_state.has_open_trade
                                           ? m_position_state.post_be_profile
                                           : (has_selected_plan ? selected_plan.post_be_profile
                                                                : m_cfg.management.post_be_profile);
   panel_snapshot.post_be_profile_state = MohyPostBEProfileToString(panel_profile);
   panel_snapshot.pre_entry_invalidation_state = MohyInvalidationReasonToString(m_waiting_state.invalidation_reason);
   if(!m_position_state.has_open_trade || !IsTrailingProfileEnabled())
      panel_snapshot.trailing_state = "Off";
   else if(m_position_state.last_trail_update_time > 0)
      panel_snapshot.trailing_state = "Active";
   else if(m_position_state.post_be_started || m_position_state.runner_trail_only_active)
      panel_snapshot.trailing_state = "Ready";
   else
      panel_snapshot.trailing_state = "Armed";

   const int active_partial_count = IsPartialProfileEnabled() ? MathMax(1, MathMin(3, m_cfg.management.partial_count)) : 0;
   const int done_partials = (m_position_state.partial_1_done ? 1 : 0) +
                             (m_position_state.partial_2_done ? 1 : 0) +
                             (m_position_state.partial_3_done ? 1 : 0);
   panel_snapshot.partial_progress_state = m_position_state.has_open_trade
                                           ? StringFormat("%d/%d %.1f%%",
                                                          done_partials,
                                                          active_partial_count,
                                                          m_position_state.partial_progress_percent)
                                           : "0/0 0.0%";
   panel_snapshot.potential_impulse_state = ResolvePotentialImpulsePanelState(snapshot,
                                                                              panel_snapshot.impulse_id,
                                                                              has_selected_plan,
                                                                              selected_plan);
   panel_snapshot.potential_correction_state = ResolvePotentialCorrectionPanelState(snapshot,
                                                                                    panel_snapshot.impulse_id,
                                                                                    has_selected_plan,
                                                                                    selected_plan);
   panel_snapshot.confirmation_state = ResolveConfirmationState();
   panel_snapshot.last_management_action_result = m_position_state.has_open_trade
                                                  ? m_position_state.last_management_action
                                                  : "None";
   panel_snapshot.last_action_result = m_last_action_result;

   const string panel_hash = BuildPanelHash(panel_snapshot);
   const uint now_ms = GetTickCount();
   const int throttle_ms = MathMax(0, m_cfg.ui.redraw_throttle_ms);
   const bool should_render = (panel_hash != m_last_panel_snapshot_hash ||
                               throttle_ms <= 0 ||
                               (now_ms - m_last_panel_redraw_ms) >= (uint)throttle_ms);
   if(!should_render)
      return;

   m_last_panel_snapshot_hash = panel_hash;
   m_last_panel_redraw_ms = now_ms;
   m_panel.Render(panel_snapshot);
  }

void CMohyRuntimeEngine::ProcessSelectedPlan(const CMohyPriceActionSnapshot &snapshot,
                                             const int selected_plan_index,
                                             const bool has_new_closed_bar)
  {
   string selected_setup_key = "";
   string selected_impulse_id = "";
   MohyTradeSetupPlanFact selected_plan;
   selected_plan.valid = false;

   if(selected_plan_index >= 0 && selected_plan_index < ArraySize(snapshot.trade_setup_plans))
     {
      selected_plan = snapshot.trade_setup_plans[selected_plan_index];
      selected_plan.valid = selected_plan.valid &&
                            MohyRuntimeResolveIdentity(m_symbol,
                                                      snapshot,
                                                      selected_plan,
                                                      selected_impulse_id,
                                                      selected_setup_key);
     }

   if(HasWaitingState())
     {
      string matching_impulse_id = "";
      const int waiting_plan_index = FindMatchingPlanIndexBySetupKey(snapshot,
                                                                     m_waiting_state.setup_key,
                                                                     matching_impulse_id);
      if(waiting_plan_index < 0)
        {
         if(m_waiting_state.pending_placed && m_waiting_state.pending_ticket > 0)
            DeletePendingOrder(m_waiting_state.pending_ticket, "WaitingDisappearedDelete");
         PublishResolvedWaitingLifecycle(MOHY_ENGINE_EVENT_INVALIDATION,
                                         "WaitingSetupDisappeared",
                                         TimeCurrent(),
                                         m_waiting_state.trigger_price,
                                         "WaitingSetupDisappeared");
         MarkConsumedImpulse(m_waiting_state.impulse_id,
                             m_waiting_state.setup_key,
                             MOHY_IMPULSE_CONSUMED_INVALIDATED_PRE_ENTRY,
                             "WaitingSetupDisappeared");
         SetLastAction("WaitingInvalidated");
         ClearWaitingState("WaitingInvalidated");
        }
      else
        {
         const MohyTradeSetupPlanFact waiting_plan = snapshot.trade_setup_plans[waiting_plan_index];
         RefreshWaitingState(waiting_plan);

          if(waiting_plan.plan_state == MOHY_TRADE_SETUP_PLAN_INVALIDATED ||
             waiting_plan.plan_state == MOHY_TRADE_SETUP_PLAN_INELIGIBLE)
           {
            if(m_waiting_state.pending_placed && m_waiting_state.pending_ticket > 0)
               DeletePendingOrder(m_waiting_state.pending_ticket, "WaitingRejectedDelete");
            PublishResolvedWaitingLifecycle(MOHY_ENGINE_EVENT_INVALIDATION,
                                            "WaitingRejected",
                                            TimeCurrent(),
                                            m_waiting_state.trigger_price,
                                            waiting_plan.diagnostics);
            MarkConsumedImpulse(m_waiting_state.impulse_id,
                                m_waiting_state.setup_key,
                                MOHY_IMPULSE_CONSUMED_INVALIDATED_PRE_ENTRY,
                                waiting_plan.diagnostics);
            SetLastAction("WaitingRejected");
            ClearWaitingState("WaitingRejected");
           }
         else if(waiting_plan.execution_mode == MOHY_ENTRY_REAL_PENDING_ORDER)
           {
            if(m_paused)
              {
               if(m_waiting_state.pending_placed && m_waiting_state.pending_ticket > 0 &&
                  DeletePendingOrder(m_waiting_state.pending_ticket, "PausedPendingDelete"))
                  DropPendingState("PausedPendingSuspended");
              }
            else if(waiting_plan.plan_state == MOHY_TRADE_SETUP_PLAN_ELIGIBLE_NOW)
              {
               if(m_waiting_state.pending_placed && m_waiting_state.pending_ticket > 0 &&
                  !DeletePendingOrder(m_waiting_state.pending_ticket, "EligibleNowPendingDelete"))
                  SetLastAction("PendingDeleteFailed");
                else
                  {
                   DropPendingState("EligibleNowPendingRemoved");
                  MohyPotentialCorrectionFact waiting_correction;
                  string correction_error = "";
                  if(ResolvePlanCorrection(snapshot, waiting_plan, waiting_correction, correction_error))
                     ExecutePlan(waiting_plan,
                                 waiting_correction,
                                 m_waiting_state.setup_key,
                                 m_waiting_state.impulse_id,
                                 "EligibleNowFromWaiting");
                  else
                     SetLastAction(correction_error);
                  }
              }
            else if(waiting_plan.plan_state == MOHY_TRADE_SETUP_PLAN_WAITING_FOR_PULLBACK)
               SyncPendingOrder(waiting_plan,
                                m_waiting_state.setup_key,
                                m_waiting_state.impulse_id);
           }
         else if(!m_paused && waiting_plan.plan_state == MOHY_TRADE_SETUP_PLAN_ELIGIBLE_NOW)
           {
            MohyPotentialCorrectionFact waiting_correction;
            string correction_error = "";
            if(ResolvePlanCorrection(snapshot, waiting_plan, waiting_correction, correction_error))
               ExecutePlan(waiting_plan,
                           waiting_correction,
                           m_waiting_state.setup_key,
                           m_waiting_state.impulse_id,
                           "EligibleNowFromWaiting");
            else
               SetLastAction(correction_error);
           }
         else if(!m_paused &&
                 has_new_closed_bar &&
                 waiting_plan.plan_state == MOHY_TRADE_SETUP_PLAN_WAITING_FOR_PULLBACK &&
                 EvaluateWaitingCross(waiting_plan))
           {
            MohyPotentialCorrectionFact waiting_correction;
            string correction_error = "";
            if(ResolvePlanCorrection(snapshot, waiting_plan, waiting_correction, correction_error))
               ExecutePlan(waiting_plan,
                           waiting_correction,
                           m_waiting_state.setup_key,
                           m_waiting_state.impulse_id,
                           "VirtualTriggerCross");
            else
               SetLastAction(correction_error);
           }
        }
     }

   if(m_position_state.has_open_trade || m_blocked_multi_position || m_paused)
     {
      BuildPanelSnapshot(selected_setup_key, selected_impulse_id, selected_plan.valid, selected_plan, snapshot);
      return;
     }

   if(selected_plan.valid)
     {
       if(IsConsumedImpulse(selected_impulse_id))
          SetLastAction("ImpulseAlreadyConsumed");
       else if(selected_plan.plan_state == MOHY_TRADE_SETUP_PLAN_ELIGIBLE_NOW)
         {
          MohyPotentialCorrectionFact selected_correction;
          string correction_error = "";
          if(ResolvePlanCorrection(snapshot, selected_plan, selected_correction, correction_error))
             ExecutePlan(selected_plan,
                         selected_correction,
                         selected_setup_key,
                         selected_impulse_id,
                         "EligibleNow");
          else
             SetLastAction(correction_error);
         }
       else if(selected_plan.plan_state == MOHY_TRADE_SETUP_PLAN_WAITING_FOR_PULLBACK && !HasWaitingState())
         {
          if(selected_plan.execution_mode == MOHY_ENTRY_REAL_PENDING_ORDER)
            {
             StartWaitingState(selected_plan, selected_setup_key, selected_impulse_id);
             SyncPendingOrder(selected_plan, selected_setup_key, selected_impulse_id);
            }
          else
            {
              // Consume the first qualifying closed-bar pullback immediately instead of
              // deferring until the next bar-close cycle after waiting-state activation.
              if(has_new_closed_bar && EvaluateWaitingCross(selected_plan))
                {
                 MohyPotentialCorrectionFact selected_correction;
                 string correction_error = "";
                 if(ResolvePlanCorrection(snapshot, selected_plan, selected_correction, correction_error))
                    ExecutePlan(selected_plan,
                                selected_correction,
                                selected_setup_key,
                                selected_impulse_id,
                                "VirtualTriggerCrossOnActivation");
                 else
                    SetLastAction(correction_error);
                }
             else
                StartWaitingState(selected_plan, selected_setup_key, selected_impulse_id);
            }
         }
      else if(selected_plan.plan_state == MOHY_TRADE_SETUP_PLAN_INELIGIBLE)
         SetLastAction(StringFormat("PlanRejected %s", MohyRejectReasonToString(selected_plan.reject_reason)));
      else if(selected_plan.plan_state == MOHY_TRADE_SETUP_PLAN_INVALIDATED)
         SetLastAction("PlanInvalidated");
     }

   BuildPanelSnapshot(selected_setup_key, selected_impulse_id, selected_plan.valid, selected_plan, snapshot);
  }

void CMohyRuntimeEngine::RenderReadOnlyPanel()
  {
   CMohyPriceActionSnapshot snapshot;
   const bool has_snapshot = BuildExecutionSnapshot(snapshot);
   if(!has_snapshot)
     {
      MohyTradeSetupPlanFact empty_plan;
      empty_plan.valid = false;
      CMohyPriceActionSnapshot empty_snapshot;
      empty_snapshot.Reset();
      BuildPanelSnapshot("", "", false, empty_plan, empty_snapshot);
      return;
     }

   MohyTradeSetupPlanFact selected_plan;
   selected_plan.valid = false;
   string selected_setup_key = "";
   string selected_impulse_id = "";

   const int selected_plan_index = FindSelectedPlanIndex(snapshot);
   if(selected_plan_index >= 0 &&
      selected_plan_index < ArraySize(snapshot.trade_setup_plans))
     {
      selected_plan = snapshot.trade_setup_plans[selected_plan_index];
      selected_plan.valid = selected_plan.valid &&
                            MohyRuntimeResolveIdentity(m_symbol,
                                                      snapshot,
                                                      selected_plan,
                                                      selected_impulse_id,
                                                      selected_setup_key);
     }

   BuildPanelSnapshot(selected_setup_key,
                      selected_impulse_id,
                      selected_plan.valid,
                      selected_plan,
                      snapshot);
  }

void CMohyRuntimeEngine::OnTick()
  {
   if(!m_initialized)
      return;

   if(!IsExecutionAuthorityEnabled())
     {
      RenderReadOnlyPanel();
      return;
     }

   ExpirePendingUiActionIfNeeded();
   UpdateOpenPositionState();
   const bool has_new_closed_bar = HasNewClosedBar();

   CMohyPriceActionSnapshot snapshot;
   const bool has_snapshot = BuildExecutionSnapshot(snapshot);
   if(ManageOpenPosition(snapshot, has_snapshot, has_new_closed_bar))
      UpdateOpenPositionState();

   if(!has_snapshot)
     {
      MohyTradeSetupPlanFact empty_plan;
      empty_plan.valid = false;
      CMohyPriceActionSnapshot empty_snapshot;
      empty_snapshot.Reset();
      BuildPanelSnapshot("", "", false, empty_plan, empty_snapshot);
      return;
     }

   const int selected_plan_index = FindSelectedPlanIndex(snapshot);
   ProcessSelectedPlan(snapshot, selected_plan_index, has_new_closed_bar);
  }

void CMohyRuntimeEngine::OnChartEvent(const int id,
                                      const long &lparam,
                                      const double &dparam,
                                      const string &sparam)
  {
   if(!IsExecutionAuthorityEnabled())
     {
      MohyUiActionId action_id = MOHY_UI_ACTION_NONE;
      if(m_panel.HandleChartEvent(id, sparam, action_id))
         SetLastAction("ReadOnlyActionBlocked");
      RenderReadOnlyPanel();
      return;
     }

   MohyUiActionId action_id = MOHY_UI_ACTION_NONE;
   if(!m_panel.HandleChartEvent(id, sparam, action_id))
      return;

   HandleUiAction(action_id);

   MohyTradeSetupPlanFact empty_plan;
   empty_plan.valid = false;
   CMohyPriceActionSnapshot empty_snapshot;
   empty_snapshot.Reset();
   BuildPanelSnapshot("", "", false, empty_plan, empty_snapshot);
  }

#endif

