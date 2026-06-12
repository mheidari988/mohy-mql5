#ifndef __MOHY_DOMAIN_STATE_IDS_MQH__
#define __MOHY_DOMAIN_STATE_IDS_MQH__

#include <MOHY/Domain/Enums.mqh>
#include <MOHY/Domain/Contracts.mqh>

string MohyDirectionToString(const MohyDirection direction)
  {
   if(direction == MOHY_DIR_BULL)
      return "Bull";
   if(direction == MOHY_DIR_BEAR)
      return "Bear";
   return "None";
  }

string MohyRetracementModelToString(const MohyRetracementModel model)
  {
   switch(model)
     {
      case MOHY_RETRACE_MODEL_STRENGTH_EFF_BASELINE: return "StrengthEfficiencyBaseline";
      case MOHY_RETRACE_MODEL_CADENCE_SLOPE: return "CadenceSlope";
      case MOHY_RETRACE_MODEL_VOLATILITY_CONTRACTION: return "VolatilityContraction";
      case MOHY_RETRACE_MODEL_STRUCTURE_STEP: return "StructureStep";
      case MOHY_RETRACE_MODEL_VOLUME_PROFILE: return "VolumeProfile";
      case MOHY_RETRACE_MODEL_HYBRID_SCORE: return "HybridScore";
     }
   return "Unknown";
  }

string MohyEqualSwingClassificationModeToString(const MohyEqualSwingClassificationMode mode)
  {
   switch(mode)
     {
      case MOHY_EQUAL_SWING_CLASSIFY_WEAKER: return "EqualAsWeaker";
      case MOHY_EQUAL_SWING_CLASSIFY_STRONGER: return "EqualAsStronger";
     }
   return "Unknown";
  }

string MohySetupPhaseToString(const MohySetupPhase phase)
  {
   switch(phase)
     {
      case MOHY_SETUP_IDLE: return "Idle";
      case MOHY_SETUP_H1_CONTEXT_READY: return "H1ContextReady";
      case MOHY_SETUP_RETRACEMENT_VALID: return "RetracementValid";
      case MOHY_SETUP_CONTINUATION_CONFIRMED: return "ContinuationConfirmed";
      case MOHY_SETUP_WAITING_ENTRY: return "WaitingEntry";
      case MOHY_SETUP_ENTERED: return "Entered";
      case MOHY_SETUP_INVALIDATED: return "Invalidated";
     }
   return "Unknown";
  }

string MohyTradePhaseToString(const MohyTradePhase phase)
  {
   switch(phase)
     {
      case MOHY_TRADE_PHASE_NONE: return "None";
      case MOHY_TRADE_PHASE_OPENED: return "Opened";
      case MOHY_TRADE_PHASE_BE_ARMED: return "BEArmed";
      case MOHY_TRADE_PHASE_BE_RISK_FREE: return "BERiskFree";
      case MOHY_TRADE_PHASE_POST_BE_ACTIVE: return "PostBEActive";
      case MOHY_TRADE_PHASE_EXITED: return "Exited";
     }
   return "Unknown";
  }

string MohyImpulseConsumptionReasonToString(const MohyImpulseConsumptionReason reason)
  {
   switch(reason)
     {
      case MOHY_IMPULSE_CONSUMED_NONE: return "None";
      case MOHY_IMPULSE_CONSUMED_ENTERED: return "Entered";
      case MOHY_IMPULSE_CONSUMED_INVALIDATED_PRE_ENTRY: return "InvalidatedPreEntry";
      case MOHY_IMPULSE_CONSUMED_MANUAL_CANCELLED: return "ManualCancelled";
      case MOHY_IMPULSE_CONSUMED_EXITED: return "Exited";
     }
   return "Unknown";
  }

string MohyPostBEStartReasonToString(const MohyPostBEStartReason reason)
  {
   switch(reason)
     {
      case MOHY_POST_BE_START_REASON_NONE: return "None";
      case MOHY_POST_BE_START_REASON_IMMEDIATE: return "Immediate";
      case MOHY_POST_BE_START_REASON_AFTER_BREAK_EVEN: return "AfterBreakEven";
      case MOHY_POST_BE_START_REASON_AT_R_MULTIPLE: return "AtRMultiple";
     }
   return "Unknown";
  }

string MohyPostBEProfileToString(const MohyPostBEProfile profile)
  {
   switch(profile)
     {
      case MOHY_POST_BE_OFF: return "Off";
      case MOHY_POST_BE_TRAIL_ONLY: return "TrailOnly";
      case MOHY_POST_BE_PARTIAL_ONLY: return "PartialOnly";
      case MOHY_POST_BE_HYBRID: return "Hybrid";
     }
   return "Unknown";
  }

string MohyPartialTargetModeToString(const MohyPartialTargetMode mode)
  {
   switch(mode)
     {
      case MOHY_PARTIAL_TARGET_R_MULTIPLE: return "RMultiple";
      case MOHY_PARTIAL_TARGET_FIB_LEVEL: return "FibLevel";
     }
   return "Unknown";
  }

string MohyInvalidationReasonToString(const MohyInvalidationReason reason)
  {
   switch(reason)
     {
      case MOHY_INVALIDATION_NONE: return "None";
      case MOHY_INVALIDATION_RETRACE_MAX_BREACH: return "RetraceMaxBreach";
      case MOHY_INVALIDATION_IMPULSE_ORIGIN_BROKEN: return "ImpulseOriginBroken";
      case MOHY_INVALIDATION_PRE_ENTRY_IMPULSE_EXTREME: return "PreEntryImpulseExtreme";
      case MOHY_INVALIDATION_MANUAL_CANCEL: return "ManualCancel";
      case MOHY_INVALIDATION_SETUP_REPLACED: return "SetupReplaced";
     }
   return "Unknown";
  }

string MohyUiAlertEventTypeToString(const MohyUiAlertEventType severity)
  {
   switch(severity)
     {
      case MOHY_UI_ALERT_INFO: return "Info";
      case MOHY_UI_ALERT_WARNING: return "Warning";
      case MOHY_UI_ALERT_CRITICAL: return "Critical";
     }
   return "Unknown";
  }

string MohyUiResultCodeToString(const MohyUiResultCode code)
  {
   switch(code)
     {
      case MOHY_UI_RESULT_SUCCESS: return "Success";
      case MOHY_UI_RESULT_BLOCKED_BY_GUARD: return "BlockedByGuard";
      case MOHY_UI_RESULT_DENIED_BY_AUTHORITY: return "DeniedByAuthority";
      case MOHY_UI_RESULT_COOLDOWN_ACTIVE: return "CooldownActive";
      case MOHY_UI_RESULT_CONFIRMATION_EXPIRED: return "ConfirmationExpired";
      case MOHY_UI_RESULT_BROKER_REJECT: return "BrokerReject";
      case MOHY_UI_RESULT_RETRYING: return "Retrying";
      case MOHY_UI_RESULT_FALLBACK_EXECUTED: return "FallbackExecuted";
      case MOHY_UI_RESULT_FAILED: return "Failed";
     }
   return "Failed";
  }

MohyUiAlertEventType MohyUiSeverityFromResultCode(const MohyUiResultCode code)
  {
   if(code == MOHY_UI_RESULT_SUCCESS)
      return MOHY_UI_ALERT_INFO;
   if(code == MOHY_UI_RESULT_BROKER_REJECT || code == MOHY_UI_RESULT_FAILED)
      return MOHY_UI_ALERT_CRITICAL;
   return MOHY_UI_ALERT_WARNING;
  }

string MohyRejectReasonToString(const MohyRejectReason reason)
  {
   switch(reason)
     {
      case MOHY_REJECT_NONE: return "None";
      case MOHY_REJECT_NO_VALID_IMPULSE_CONTEXT: return "NoValidImpulseContext";
      case MOHY_REJECT_RETRACEMENT_INVALID: return "RetracementInvalid";
      case MOHY_REJECT_CONTINUATION_NOT_CONFIRMED: return "ContinuationNotConfirmed";
      case MOHY_REJECT_PRE_ENTRY_INVALIDATED: return "PreEntryInvalidated";
      case MOHY_REJECT_SPREAD_FILTER_FAILED: return "SpreadFilterFailed";
      case MOHY_REJECT_MIN_RR_NOT_SATISFIED: return "MinRRNotSatisfied";
      case MOHY_REJECT_STOP_DISTANCE_INVALID: return "StopDistanceInvalid";
      case MOHY_REJECT_LOT_NORMALIZATION_FAILED: return "LotNormalizationFailed";
      case MOHY_REJECT_EXPOSURE_LIMIT_EXCEEDED: return "ExposureLimitExceeded";
      case MOHY_REJECT_PENDING_PLACEMENT_REJECTED: return "PendingPlacementRejected";
      case MOHY_REJECT_EXECUTION_FAILED: return "ExecutionFailed";
      case MOHY_REJECT_BROKER_CONSTRAINT: return "BrokerConstraint";
      case MOHY_REJECT_INVALID_PLAN: return "InvalidPlan";
     }
  return "Unknown";
  }

string MohyExecutionResultCodeToString(const MohyExecutionResultCode code)
  {
   switch(code)
     {
      case MOHY_EXEC_SUCCESS: return "Success";
      case MOHY_EXEC_BLOCKED_BY_GUARD: return "BlockedByGuard";
      case MOHY_EXEC_BROKER_REJECT: return "BrokerReject";
      case MOHY_EXEC_RETRYING: return "Retrying";
      case MOHY_EXEC_FALLBACK_EXECUTED: return "FallbackExecuted";
      case MOHY_EXEC_FAILED: return "Failed";
     }
   return "Unknown";
  }

string MohyUiActionIdToString(const MohyUiActionId action_id)
  {
   switch(action_id)
     {
      case MOHY_UI_ACTION_NONE: return "None";
      case MOHY_UI_ACTION_PAUSE_ENTRIES: return "PauseEntries";
      case MOHY_UI_ACTION_RESUME_ENTRIES: return "ResumeEntries";
      case MOHY_UI_ACTION_CANCEL_WAITING_ENTRIES: return "CancelWaitingEntries";
      case MOHY_UI_ACTION_CLOSE_STRATEGY_TRADES: return "CloseStrategyTrades";
      case MOHY_UI_ACTION_EMERGENCY_FLATTEN: return "EmergencyFlatten";
     }
   return "Unknown";
  }

string MohyEngineEventTypeToString(const MohyEngineEventType event_type)
  {
   switch(event_type)
     {
      case MOHY_ENGINE_EVENT_NONE: return "None";
      case MOHY_ENGINE_EVENT_IMPULSE_DETECTED: return "ImpulseDetected";
      case MOHY_ENGINE_EVENT_RETRACEMENT_VALID: return "RetracementValid";
      case MOHY_ENGINE_EVENT_CONTINUATION_CONFIRMED: return "ContinuationConfirmed";
      case MOHY_ENGINE_EVENT_PLAN_REJECTED: return "PlanRejected";
      case MOHY_ENGINE_EVENT_WAITING_STARTED: return "WaitingStarted";
      case MOHY_ENGINE_EVENT_TRIGGER_ADJUSTED: return "TriggerAdjusted";
      case MOHY_ENGINE_EVENT_INVALIDATION: return "Invalidation";
      case MOHY_ENGINE_EVENT_ENTRY_EXECUTED: return "EntryExecuted";
      case MOHY_ENGINE_EVENT_BREAK_EVEN_ACTIVATED: return "BreakEvenActivated";
      case MOHY_ENGINE_EVENT_TRAILING_UPDATED: return "TrailingUpdated";
      case MOHY_ENGINE_EVENT_PARTIAL_EXECUTED: return "PartialExecuted";
      case MOHY_ENGINE_EVENT_EXIT_RESOLVED: return "ExitResolved";
     }
   return "Unknown";
  }

string MohyRuntimeLifecycleStateToString(const MohyRuntimeLifecycleState state)
  {
   switch(state)
     {
      case MOHY_RUNTIME_LIFECYCLE_NONE: return "None";
      case MOHY_RUNTIME_LIFECYCLE_WAITING: return "Waiting";
      case MOHY_RUNTIME_LIFECYCLE_OPEN: return "Open";
      case MOHY_RUNTIME_LIFECYCLE_RESOLVED: return "Resolved";
     }
   return "Unknown";
  }

void MohyResetSetupState(SetupState &state)
  {
   state.setup_key = "";
   state.impulse_id = "";
   state.direction = MOHY_DIR_NONE;
   state.lifecycle_phase = MOHY_SETUP_IDLE;
   state.pre_entry_invalidation_mode = MOHY_PRE_ENTRY_INVALIDATE_TOUCH;
   state.invalidation_reason = MOHY_INVALIDATION_NONE;
   state.blocked_impulse_id = "";
   state.blocked_impulse_reason = MOHY_IMPULSE_CONSUMED_NONE;
   state.blocked_since = 0;
   state.trigger_mode = MOHY_ENTRY_VIRTUAL_TRIGGER;
   state.trigger_price = 0.0;
   state.trigger_initialized = false;
   state.trigger_last_adjust_time = 0;
   state.waiting_since = 0;
   state.paused_entries = false;
   state.pending_placed = false;
   state.pending_ticket = -1;
   state.rr_state = false;
   state.spread_gate_state = false;
   state.last_reject_reason = MOHY_REJECT_NONE;
   state.last_transition_time = TimeCurrent();
   state.last_transition_cause = "Reset";
   state.failed_touches = 0;
   state.entry_touched_once = false;
  }

void MohyResetManagementState(PositionManagementState &state)
  {
   state.has_open_trade = false;
   state.ticket = -1;
   state.setup_key = "";
   state.impulse_id = "";
   state.direction = MOHY_DIR_NONE;
   state.execution_mode = MOHY_ENTRY_VIRTUAL_TRIGGER;
   state.trade_phase = MOHY_TRADE_PHASE_NONE;
   state.recovered = false;
   state.break_even_armed = false;
   state.break_even_active = false;
   state.break_even_level = 0.0;
   state.break_even_applied_to_broker = false;
   state.break_even_retry_count = 0;
   state.virtual_stop_active = false;
   state.virtual_stop_level = 0.0;
   state.post_be_profile = MOHY_POST_BE_OFF;
   state.post_be_started = false;
   state.post_be_started_time = 0;
   state.post_be_start_reason = MOHY_POST_BE_START_REASON_NONE;
   state.partial_1_done = false;
   state.partial_2_done = false;
   state.partial_3_done = false;
   state.partial_progress_percent = 0.0;
   state.entry_price = 0.0;
   state.initial_lots = 0.0;
   state.initial_stop_loss = 0.0;
   state.target_price = 0.0;
   state.initial_risk_points = 0.0;
   state.impulse_extreme_reference = 0.0;
   state.anchors_ready = false;
   state.impulse_high_anchor = 0.0;
   state.impulse_low_anchor = 0.0;
   state.correction_high_anchor = 0.0;
   state.correction_low_anchor = 0.0;
   state.runner_trail_only_active = false;
   state.runner_tp_removed = false;
   state.last_trail_update_time = 0;
   state.last_favorable_extreme = 0.0;
   state.opened_time = 0;
   state.last_management_action_time = 0;
   state.last_management_action = "None";
  }

#endif
