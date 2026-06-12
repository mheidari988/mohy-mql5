#ifndef __MOHY_DOMAIN_CONTRACTS_MQH__
#define __MOHY_DOMAIN_CONTRACTS_MQH__

#include <MOHY/Domain/Enums.mqh>

string MohyIdentityPriceToString(const double price,
                                 const string symbol)
  {
   long digits = 10;
   if(symbol != "" && SymbolInfoInteger(symbol, SYMBOL_DIGITS, digits) && digits >= 0)
      return DoubleToString(price, (int)digits);
   return DoubleToString(price, 10);
  }

string MohyIdentityDirectionToString(const MohyDirection direction)
  {
   if(direction == MOHY_DIR_BULL)
      return "Bull";
   if(direction == MOHY_DIR_BEAR)
      return "Bear";
   return "None";
  }

bool MohyBuildRuntimeImpulseId(const string symbol,
                               const int context_timeframe,
                               const int execution_timeframe,
                               const MohyDirection direction,
                               const datetime begin_time,
                               const datetime end_time,
                               const double begin_price,
                               const double end_price,
                               string &out_impulse_id)
  {
   out_impulse_id = "";
   if(symbol == "" || context_timeframe <= 0 || execution_timeframe <= 0)
      return false;
   if(direction != MOHY_DIR_BULL && direction != MOHY_DIR_BEAR)
      return false;
   if(begin_time <= 0 || end_time <= 0 || begin_price <= 0.0 || end_price <= 0.0)
      return false;

   out_impulse_id = StringFormat("%s|%s|%s|%s|%I64d|%I64d|%s|%s",
                                 symbol,
                                 MohyTimeframeToString(context_timeframe),
                                 MohyTimeframeToString(execution_timeframe),
                                 MohyIdentityDirectionToString(direction),
                                 begin_time,
                                 end_time,
                                 MohyIdentityPriceToString(begin_price, symbol),
                                 MohyIdentityPriceToString(end_price, symbol));
   return true;
  }

bool MohyBuildRuntimeSetupKey(const string impulse_id,
                              const datetime correction_anchor_time,
                              const datetime signal_time,
                              string &out_setup_key)
  {
   out_setup_key = "";
   if(impulse_id == "" || correction_anchor_time <= 0 || signal_time <= 0)
      return false;

   out_setup_key = StringFormat("%s|%I64d|%I64d",
                                impulse_id,
                                correction_anchor_time,
                                signal_time);
   return true;
  }

struct ImpulseContext
  {
   bool             valid;
   string           impulse_id;
   MohyDirection    direction;
   datetime         signal_time_h1;
   datetime         impulse_origin_time;
   datetime         impulse_extreme_time;
   double           impulse_origin;
   double           impulse_extreme;
   double           atr_value;
   double           impulse_range_points;
   int              impulse_candles;
   double           impulse_strength;
   double           impulse_efficiency;
   int              broken_structures_count;
   double           relative_volume;
   bool             atr_gate_pass;
   bool             structure_depth_pass;
   int              structure_start_shift_h1;
   int              structure_break_shift_h1;
   int              structure_end_shift_h1;
   datetime         structure_end_close_time_h1;
   int              break_shift_h1;
   int              break_ref_shift_h1;
   datetime         break_ref_time_h1;
   double           break_ref_price;
   string           break_ref_label;
   bool             purity_pass;
   int              impurity_break_shift_h1;
   datetime         impurity_break_time_h1;
   double           impurity_break_ref_price;
   string           diagnostics;
  };

struct RetracementContext
  {
   bool             valid;
   string           impulse_id;
   MohyRetracementModel retracement_model;
   datetime         eval_time_ltf;
   double           retrace_extreme;
   datetime         retrace_extreme_time;
   double           retrace_depth;
   double           retrace_min_level;
   double           retrace_max_level;
   MohyRetraceInvalidationMode retrace_invalidation_mode;
   double           retracement_strength;
   double           retracement_efficiency;
   double           impulse_strength;
   double           impulse_efficiency;
   double           retracement_step_ratio;
   double           retracement_atr_ratio;
   int              retrace_swing_count;
   double           retrace_dominant_candle_share;
   bool             retrace_structure_continuity_pass;
   double           retrace_relative_volume;
   double           retracement_score;
   bool             ma_filter_pass;
   string           model_name;
   bool             model_pass;
   string           diagnostics;

   double           correction_high;
   double           correction_low;
   int              correction_start_shift;
   int              correction_end_shift;
   int              retracement_window_start_shift;
   int              retracement_window_end_shift;
   int              continuation_ref_shift;
   datetime         continuation_ref_time;
   bool             continuation_ref_is_swing_high;
  };

// Deprecated compatibility contract from the pre-kernel execution model.
// Active runtime code should use MohyPotentialContinuationSignalFact instead.
struct ContinuationSignal
  {
   bool             valid;
   string           impulse_id;
   MohyDirection    direction;
   datetime         confirm_time_ltf;
   int              swing_ref_index;
   double           break_buffer_points;
   double           break_level;
   MohyContinuationConfirmLogic confirm_logic;
   bool             structure_break_pass;
   bool             ma_confirm_pass;
   bool             momentum_confirm_pass;
   bool             volume_confirm_pass;
   double           momentum_confirm_value;
   double           volume_confirm_value;
   bool             confirm_pass;
   string           diagnostics;
  };

struct RRSnapshot
  {
   double           current_rr;
   double           min_rr;
   double           tolerance;
   bool             pass;
   double           executable_price;
   double           required_entry_price;
   double           spread_points;
   bool             spread_pass;
  };

struct RiskSnapshot
  {
   double           risk_base_amount;
   double           exposure_base_amount;
   double           risk_money;
   double           stop_distance_points;
   double           lots_raw;
   double           lots_normalized;
   double           current_open_risk_percent;
   double           projected_open_risk_percent;
   bool             exposure_pass;
  };

// Deprecated compatibility contract from the pre-kernel execution model.
// Active runtime code should use MohyTradeSetupPlanFact instead.
struct TradePlan
  {
   bool             valid;
   MohyDirection    direction;
   MohyEntryExecutionMode execution_mode;
   string           impulse_id;
   string           setup_key;

   double           entry_price;
   double           required_entry_price;
   double           virtual_trigger_price;

   double           stop_loss;
   double           broker_stop_loss;
   double           take_profit;

   MohySLMode       sl_mode;
   MohyTPMode       tp_mode;

   double           risk_percent;
   double           lots;

   MohyRejectReason reject_reason;
   string           comment;

   RRSnapshot       rr_snapshot;
   RiskSnapshot     risk_snapshot;
  };

struct ExecutionResult
  {
   bool             success;
   MohyExecutionResultCode result_code;
   MohyRejectReason reject_reason;
   int              ticket;
   int              broker_error;
   int              retry_count;
   bool             fallback_applied;
   string           message;
  };

struct SetupState
  {
    string           setup_key;
    string           impulse_id;
    MohyDirection    direction;
    MohySetupPhase   lifecycle_phase;
   MohyPreEntryInvalidationMode pre_entry_invalidation_mode;
   MohyInvalidationReason invalidation_reason;
   string           blocked_impulse_id;
   MohyImpulseConsumptionReason blocked_impulse_reason;
   datetime         blocked_since;

   MohyEntryExecutionMode trigger_mode;
   double           trigger_price;
   bool             trigger_initialized;
   datetime         trigger_last_adjust_time;
   datetime         waiting_since;

   bool             paused_entries;

   bool             pending_placed;
   int              pending_ticket;

    bool             rr_state;
    bool             spread_gate_state;
    MohyRejectReason last_reject_reason;

    datetime         last_transition_time;
    string           last_transition_cause;

   int              failed_touches;
   bool             entry_touched_once;
  };

struct PositionManagementState
  {
    bool             has_open_trade;
    int              ticket;
    string           setup_key;
    string           impulse_id;
    MohyDirection    direction;
    MohyEntryExecutionMode execution_mode;
    MohyTradePhase   trade_phase;
    bool             recovered;

    bool             break_even_armed;
   bool             break_even_active;
   double           break_even_level;
   bool             break_even_applied_to_broker;
   int              break_even_retry_count;

   bool             virtual_stop_active;
   double           virtual_stop_level;

   MohyPostBEProfile post_be_profile;
   bool             post_be_started;
   datetime         post_be_started_time;
   MohyPostBEStartReason post_be_start_reason;

   bool             partial_1_done;
   bool             partial_2_done;
   bool             partial_3_done;
   double           partial_progress_percent;

    double           entry_price;
    double           initial_lots;
    double           initial_stop_loss;
    double           target_price;
    double           initial_risk_points;
   double           impulse_extreme_reference;
   bool             anchors_ready;
   double           impulse_high_anchor;
   double           impulse_low_anchor;
   double           correction_high_anchor;
   double           correction_low_anchor;
   bool             runner_trail_only_active;
   bool             runner_tp_removed;

   datetime         last_trail_update_time;
   double           last_favorable_extreme;

   datetime         opened_time;
   datetime         last_management_action_time;
   string           last_management_action;
  };

struct UiRuntimeSnapshot
  {
    string           symbol;
    string           scope_tag;
    string           timeframe;
    string           context_timeframe;
    string           execution_timeframe;
    string           execution_mode;
    string           pause_state;
    string           setup_key;
    string           impulse_id;
    string           strategy_phase;
    string           setup_validity;
    string           position_state;
    string           trigger_state;
    string           rr_state;
   string           spread_gate_state;
   string           open_risk_state;
   string           exposure_state;
   string           sl_mode;
   string           tp_mode;
   string           break_even_state;
   string           post_be_profile_state;
   string           pre_entry_invalidation_state;
   string           trailing_state;
   string           partial_progress_state;
   string           potential_impulse_state;
   string           potential_correction_state;
   string           confirmation_state;
   string           last_management_action_result;
   string           last_action_result;
  };

struct UiPanelState
  {
   bool             visible;
   bool             collapsed;
   int              dock_corner;
   int              x;
   int              y;
   int              width;
   int              height;
   datetime         refresh_timestamp;
  };

struct UiAuditEvent
  {
   datetime         timestamp;
   long             chart_id;
   string           symbol;
   string           scope_tag;
   MohyUiActionId   action_id;
   string           stage;
   string           confirmation_id;
   string           pre_state_hash;
   string           post_state_hash;
   string           result_code;
   string           message;
  };

struct UiActionIntent
  {
   MohyUiActionId   action_id;
   string           correlation_id;
   string           pre_state_hash;
   datetime         accepted_at;
  };

struct UiActionOutcome
  {
   MohyUiActionId   action_id;
   string           correlation_id;
   MohyUiResultCode result_code;
   string           message;
   int              broker_error;
   MohyUiAlertEventType severity;
  };

struct AuditEventRecord
  {
   long             sequence_no;
   datetime         timestamp;
   long             chart_id;
   string           symbol;
   string           scope_tag;
   string           config_hash;
   string           sink;
   string           stage;
   MohyUiActionId   action_id;
   string           confirmation_id;
   string           pre_state_hash;
   string           post_state_hash;
   string           result_code;
   MohyUiAlertEventType severity;
   string           message;
   int              broker_error;
  };

struct MohyEngineEventRecord
  {
   string           schema_version;
   long             sequence_no;
   datetime         timestamp;
   long             chart_id;
   string           symbol;
   string           context_timeframe;
   string           execution_timeframe;
   string           scope_tag;
   string           config_hash;
   string           config_layers;
   string           setup_key;
   string           impulse_id;
   MohyDirection    direction;
   MohySetupPhase   setup_phase;
   MohyTradePhase   trade_phase;
   MohyEngineEventType event_type;
   string           reason_code;
   datetime         time_a;
   datetime         time_b;
   double           price_a;
   double           price_b;
   double           rr_value;
   string           diagnostics;
   string           source;
  };

struct MohyRuntimeLifecycleRecord
  {
   string           schema_version;
   string           setup_key;
   string           impulse_id;
   string           symbol;
   string           scope_tag;
   string           context_timeframe;
   string           execution_timeframe;
   string           config_hash;
   MohyDirection    direction;
   MohyEntryExecutionMode execution_mode;
   MohyRuntimeLifecycleState lifecycle_state;
   MohySetupPhase   setup_phase;
   MohyTradePhase   trade_phase;
   bool             recovered;
   MohyEngineEventType last_event_type;
   string           last_reason_code;
   datetime         last_event_time;
   datetime         waiting_since;
   double           trigger_price;
   bool             pending_placed;
   int              pending_ticket;
   datetime         opened_time;
   int              position_ticket;
   double           entry_price;
   double           initial_stop_loss;
   double           target_price;
   bool             break_even_armed;
   bool             break_even_active;
   datetime         break_even_activated_time;
   double           break_even_level;
   bool             post_be_started;
   datetime         post_be_started_time;
   MohyPostBEStartReason post_be_start_reason;
   bool             partial_1_done;
   bool             partial_2_done;
   bool             partial_3_done;
   double           partial_progress_percent;
   bool             runner_trail_only_active;
   bool             runner_tp_removed;
   datetime         last_trail_update_time;
   string           last_management_action;
   datetime         resolved_time;
   MohyEngineEventType resolution_event_type;
   string           resolution_reason_code;
   double           resolution_price;
   string           resolution_diagnostics;
  };

void MohyResetRuntimeLifecycleRecord(MohyRuntimeLifecycleRecord &record)
  {
   record.schema_version = "runtime_lifecycle_v1";
   record.setup_key = "";
   record.impulse_id = "";
   record.symbol = "";
   record.scope_tag = "";
   record.context_timeframe = "";
   record.execution_timeframe = "";
   record.config_hash = "";
   record.direction = MOHY_DIR_NONE;
   record.execution_mode = MOHY_ENTRY_VIRTUAL_TRIGGER;
   record.lifecycle_state = MOHY_RUNTIME_LIFECYCLE_NONE;
   record.setup_phase = MOHY_SETUP_IDLE;
   record.trade_phase = MOHY_TRADE_PHASE_NONE;
   record.recovered = false;
   record.last_event_type = MOHY_ENGINE_EVENT_NONE;
   record.last_reason_code = "";
   record.last_event_time = 0;
   record.waiting_since = 0;
   record.trigger_price = 0.0;
   record.pending_placed = false;
   record.pending_ticket = -1;
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
   record.resolution_diagnostics = "";
  }

#endif
