#ifndef __MOHY_DOMAIN_CONFIG_MQH__
#define __MOHY_DOMAIN_CONFIG_MQH__

#include <MOHY/Domain/Enums.mqh>

int MohyTimeframeToMinutes(const int timeframe)
  {
   if(timeframe == PERIOD_M15) return 15;
   if(timeframe == PERIOD_M30) return 30;
   if(timeframe == PERIOD_H1) return 60;
   if(timeframe == PERIOD_H2) return 120;
   if(timeframe == PERIOD_H4) return 240;
   if(timeframe == PERIOD_D1) return 1440;
   return 0;
  }

string MohyTimeframeToString(const int timeframe)
  {
   if(timeframe == PERIOD_M15) return "M15";
   if(timeframe == PERIOD_M30) return "M30";
   if(timeframe == PERIOD_H1) return "H1";
   if(timeframe == PERIOD_H2) return "H2";
   if(timeframe == PERIOD_H4) return "H4";
   if(timeframe == PERIOD_D1) return "D1";
   return StringFormat("TF%d", timeframe);
  }

bool MohyResolveTimeframePair(const MohyTimeframePair pair,
                              int &out_context_timeframe,
                              int &out_execution_timeframe)
  {
   if(pair == MOHY_TF_PAIR_H1_M15)
     {
      out_context_timeframe = PERIOD_H1;
      out_execution_timeframe = PERIOD_M15;
      return true;
     }
   if(pair == MOHY_TF_PAIR_H2_M30)
     {
      out_context_timeframe = PERIOD_H2;
      out_execution_timeframe = PERIOD_M30;
      return true;
     }
   if(pair == MOHY_TF_PAIR_H4_H1)
     {
      out_context_timeframe = PERIOD_H4;
      out_execution_timeframe = PERIOD_H1;
      return true;
     }
   if(pair == MOHY_TF_PAIR_D1_H4)
     {
      out_context_timeframe = PERIOD_D1;
      out_execution_timeframe = PERIOD_H4;
      return true;
     }

   out_context_timeframe = PERIOD_H1;
   out_execution_timeframe = PERIOD_M15;
   return false;
  }

bool MohyResolveTimeframePairFromFrames(const int context_timeframe,
                                        const int execution_timeframe,
                                        MohyTimeframePair &out_pair)
  {
   if(context_timeframe == PERIOD_H1 && execution_timeframe == PERIOD_M15)
     {
      out_pair = MOHY_TF_PAIR_H1_M15;
      return true;
     }
   if(context_timeframe == PERIOD_H2 && execution_timeframe == PERIOD_M30)
     {
      out_pair = MOHY_TF_PAIR_H2_M30;
      return true;
     }
   if(context_timeframe == PERIOD_H4 && execution_timeframe == PERIOD_H1)
     {
      out_pair = MOHY_TF_PAIR_H4_H1;
      return true;
     }
   if(context_timeframe == PERIOD_D1 && execution_timeframe == PERIOD_H4)
     {
      out_pair = MOHY_TF_PAIR_D1_H4;
      return true;
     }
   return false;
  }

bool MohyIsAllowedTimeframePair(const int context_timeframe,
                                const int execution_timeframe)
  {
   if(context_timeframe == PERIOD_H1 && execution_timeframe == PERIOD_M15)
      return true;
   if(context_timeframe == PERIOD_H2 && execution_timeframe == PERIOD_M30)
      return true;
   if(context_timeframe == PERIOD_H4 && execution_timeframe == PERIOD_H1)
      return true;
   if(context_timeframe == PERIOD_D1 && execution_timeframe == PERIOD_H4)
      return true;
   return false;
  }

bool MohyValidateTimeframePair(const int context_timeframe,
                               const int execution_timeframe)
  {
   if(!MohyIsAllowedTimeframePair(context_timeframe, execution_timeframe))
      return false;

   const int context_minutes = MohyTimeframeToMinutes(context_timeframe);
   const int execution_minutes = MohyTimeframeToMinutes(execution_timeframe);
   if(context_minutes <= 0 || execution_minutes <= 0)
      return false;

   return (context_minutes > execution_minutes);
  }

double MohyPotentialCorrectionMinFibLevelToValue(const MohyPotentialCorrectionMinFibLevel level)
  {
   switch(level)
     {
      case MOHY_POT_CORR_MIN_FIB_0500: return 0.5;
      case MOHY_POT_CORR_MIN_FIB_0618: return 0.618;
      case MOHY_POT_CORR_MIN_FIB_0382:
      default:
         return 0.382;
     }
  }

double MohyPotentialCorrectionMaxFibLevelToValue(const MohyPotentialCorrectionMaxFibLevel level)
  {
   switch(level)
     {
      case MOHY_POT_CORR_MAX_FIB_0618: return 0.618;
      case MOHY_POT_CORR_MAX_FIB_0886: return 0.886;
      case MOHY_POT_CORR_MAX_FIB_1000: return 1.0;
      case MOHY_POT_CORR_MAX_FIB_0786:
      default:
         return 0.786;
     }
  }

bool MohyIsPotentialCorrectionFibRangeValid(const MohyPotentialCorrectionMinFibLevel min_level,
                                            const MohyPotentialCorrectionMaxFibLevel max_level)
  {
   const double min_value = MohyPotentialCorrectionMinFibLevelToValue(min_level);
   const double max_value = MohyPotentialCorrectionMaxFibLevelToValue(max_level);
   return (max_value > min_value + 1e-10);
  }

struct DetectionConfig
  {
   int      atr_period;
   MohyEqualSwingClassificationMode equal_swing_classification_mode;

   MohyRetracementModel retracement_model;
   double   retrace_min_level;
   double   retrace_max_level;
   MohyRetraceInvalidationMode retrace_invalidation_mode;
   int      retrace_atr_period;
   double   max_retracement_step_ratio;
   double   max_retracement_atr_ratio;
   int      min_retrace_swing_count;
   double   max_retrace_dominant_candle_share;
   double   max_retrace_relative_volume;
   double   retrace_hybrid_weight_cadence;
   double   retrace_hybrid_weight_volatility;
   double   retrace_hybrid_weight_structure;
   double   retrace_hybrid_weight_volume;
   double   min_retracement_score;

   bool     enable_retrace_shock_filter;
   bool     enable_retrace_sideways_filter;
   bool     enable_retrace_volume_filter;
   bool     enable_retrace_structure_filter;

   bool     enable_retrace_ma_filter;
   int      retrace_ma_fast_period;
   int      retrace_ma_slow_period;
   int      retrace_ma_method;
   int      retrace_ma_price;

   int      swing_left_bars;
   int      swing_right_bars;
   int      continuation_swing_ref_index;
   MohyContinuationPlanningStartMode continuation_planning_start_mode;
   double   break_buffer_points;

   bool     enable_continuation_ma_confirmation;
   bool     enable_continuation_momentum_confirmation;
   bool     enable_continuation_volume_confirmation;
   int      continuation_momentum_atr_period;
   double   min_continuation_momentum_atr;
   int      continuation_volume_lookback;
   double   min_continuation_relative_volume;
   MohyContinuationConfirmLogic continuation_confirm_logic;

   bool     enable_potential_impulse;
   int      potential_impulse_min_swing_breakout_closes;
   bool     potential_impulse_require_leg_breakout;
   int      potential_impulse_min_leg_breakout_closes;
   bool     potential_impulse_require_directional_candles;
   bool     potential_impulse_validate_endpoint_candles;
   int      potential_impulse_allow_opposite_begin_candles;
   int      potential_impulse_allow_opposite_end_candles;
   int      potential_impulse_max_opposite_middle_candles;
   bool     potential_impulse_allow_any_opposite_before_leg_breakout;
   double   potential_impulse_doji_epsilon_points;

   bool     enable_potential_correction;
   int      potential_correction_min_opposite_ici_count;
   MohyPotentialCorrectionMinFibLevel potential_correction_min_fib_level;
   MohyLevelTriggerMode potential_correction_min_fib_trigger_mode;
   MohyPotentialCorrectionMaxFibLevel potential_correction_max_fib_level;
   MohyLevelTriggerMode potential_correction_max_fib_trigger_mode;
   double   potential_correction_extreme_touch_epsilon_points;
   int      potential_correction_extreme_touch_min_count;
   MohyPotentialCorrectionSupersedeDirectionMode potential_correction_supersede_direction_mode;
   MohyPotentialCorrectionSupersedeScope potential_correction_supersede_scope;
  };

struct EntryConfig
  {
   double   min_rr;
   double   rr_tolerance;
   bool     enable_spread_filter;
   double   max_spread_points;

   MohyEntryExecutionMode execution_mode;
   MohyRecheckMode recheck_mode;
   MohyAdjustCadence adjust_cadence;
   int      adjust_min_seconds;

   bool     recheck_rr_at_trigger;
   MohyTouchSide sell_trigger_touch_side;
   MohyTouchSide buy_trigger_touch_side;

   int      spread_ema_period;
   double   fixed_slippage_points;
   double   slippage_spread_multiplier;
   double   fixed_commission_points;

   double   min_trigger_move_points;
   bool     enable_trigger_freeze;
   double   freeze_spread_multiplier;
   double   min_stop_distance_points;

   MohyPreEntryInvalidationMode pre_entry_invalidation_mode;
   double   pre_entry_invalidation_buffer_points;

   bool     enable_pending_auto_modify;
  };

struct RiskConfig
  {
   double   risk_percent;
   MohyRiskBase risk_base;

   double   max_concurrent_risk_percent;
   MohyExposureBase exposure_base;

   int      magic_number;
   int      slippage_points;

   bool     apply_exec_filters_to_management;
  };

struct ManagementConfig
  {
   bool     enable_break_even_on_impulse_extreme;
   int      be_retry_ticks;

   MohyPostBEProfile post_be_profile;
   MohyPostBEStartMode post_be_start_mode;
   double   post_be_start_r;

   MohyTrailModel trail_model;
   MohyTrailUpdateCadence trail_update_cadence;
   bool     trail_one_way_ratchet;
   int      trail_structure_swing_index;
   double   trail_fixed_points;
   int      trail_atr_period;
   double   trail_atr_multiplier;
   int      trail_ma_period;
   int      trail_ma_method;
   int      trail_ma_price;
   double   trail_ma_buffer_points;

   MohyPartialModel partial_model;
   int      partial_count;
   double   partial_percent_1;
   double   partial_percent_2;
   double   partial_percent_3;
   double   partial_r_multiple_1;
   double   partial_r_multiple_2;
   double   partial_r_multiple_3;
   double   partial_fib_level_1;
   double   partial_fib_level_2;
   double   partial_fib_level_3;
   MohyPartialTargetMode partial_target_mode_1;
   MohyPartialTargetMode partial_target_mode_2;
   MohyPartialTargetMode partial_target_mode_3;

   MohyPostPartialStopAction post_partial_stop_action;
   double   post_partial_be_plus_points;
   MohyRunnerTargetMode runner_target_mode;

   int      management_retry_count;
   bool     management_retry_then_market_close;

   bool     enable_safeguard_sl;
   double   safeguard_sl_multiplier;
  };

struct UiOpsConfig
  {
   bool     enable_ui;
   int      dangerous_action_cooldown_seconds;
   int      redraw_throttle_ms;
   bool     enable_terminal_alerts;
   bool     enable_file_audit;
  };

struct StrategyConfig
  {
   MohyTimeframePair timeframe_pair;
   int              context_timeframe;
   int              execution_timeframe;

   DetectionConfig  detection;
   EntryConfig      entry;
   RiskConfig       risk;
   ManagementConfig management;
   UiOpsConfig      ui;

   MohySLMode       sl_mode;
   double           outer_sl_buffer_points;
   double           inner_sl_buffer_points;
   int              inner_stop_swing_index;

   MohyTPMode       tp_mode;
   double           fib_target_level;
   double           target_rr;

   string           symbol;
  };

void MohySetDefaultDetectionConfig(DetectionConfig &cfg)
  {
   cfg.atr_period = 14;
   cfg.equal_swing_classification_mode = MOHY_EQUAL_SWING_CLASSIFY_WEAKER;

   cfg.retracement_model = MOHY_RETRACE_MODEL_STRENGTH_EFF_BASELINE;
   cfg.retrace_min_level = 0.382;
   cfg.retrace_max_level = 0.786;
   cfg.retrace_invalidation_mode = MOHY_RETRACE_INVALIDATE_TOUCH;
   cfg.retrace_atr_period = 14;
   cfg.max_retracement_step_ratio = 0.85;
   cfg.max_retracement_atr_ratio = 0.90;
   cfg.min_retrace_swing_count = 2;
   cfg.max_retrace_dominant_candle_share = 0.60;
   cfg.max_retrace_relative_volume = 1.10;
   cfg.retrace_hybrid_weight_cadence = 0.25;
   cfg.retrace_hybrid_weight_volatility = 0.25;
   cfg.retrace_hybrid_weight_structure = 0.25;
   cfg.retrace_hybrid_weight_volume = 0.25;
   cfg.min_retracement_score = 0.70;

   cfg.enable_retrace_shock_filter = true;
   cfg.enable_retrace_sideways_filter = true;
   cfg.enable_retrace_volume_filter = true;
   cfg.enable_retrace_structure_filter = true;

   cfg.enable_retrace_ma_filter = true;
   cfg.retrace_ma_fast_period = 10;
   cfg.retrace_ma_slow_period = 20;
   cfg.retrace_ma_method = MODE_EMA;
   cfg.retrace_ma_price = PRICE_CLOSE;

   cfg.swing_left_bars = 1;
   cfg.swing_right_bars = 1;
   cfg.continuation_swing_ref_index = 1;
   cfg.continuation_planning_start_mode = MOHY_CONT_PLAN_START_P_OR_P_STAR;
   cfg.break_buffer_points = 0.0;

   cfg.enable_continuation_ma_confirmation = true;
   cfg.enable_continuation_momentum_confirmation = false;
   cfg.enable_continuation_volume_confirmation = false;
   cfg.continuation_momentum_atr_period = 14;
   cfg.min_continuation_momentum_atr = 0.20;
   cfg.continuation_volume_lookback = 20;
   cfg.min_continuation_relative_volume = 1.00;
   cfg.continuation_confirm_logic = MOHY_CONT_CONFIRM_AND;

   cfg.enable_potential_impulse = true;
   cfg.potential_impulse_min_swing_breakout_closes = 1;
   cfg.potential_impulse_require_leg_breakout = true;
   cfg.potential_impulse_min_leg_breakout_closes = 1;
   cfg.potential_impulse_require_directional_candles = true;
   cfg.potential_impulse_validate_endpoint_candles = false;
   cfg.potential_impulse_allow_opposite_begin_candles = 0;
   cfg.potential_impulse_allow_opposite_end_candles = 0;
   cfg.potential_impulse_max_opposite_middle_candles = 0;
   cfg.potential_impulse_allow_any_opposite_before_leg_breakout = true;
   cfg.potential_impulse_doji_epsilon_points = 0.1;

   cfg.enable_potential_correction = true;
   cfg.potential_correction_min_opposite_ici_count = 1;
   cfg.potential_correction_min_fib_level = MOHY_POT_CORR_MIN_FIB_0382;
   cfg.potential_correction_min_fib_trigger_mode = MOHY_LEVEL_TRIGGER_TOUCH;
   cfg.potential_correction_max_fib_level = MOHY_POT_CORR_MAX_FIB_0786;
   cfg.potential_correction_max_fib_trigger_mode = MOHY_LEVEL_TRIGGER_TOUCH;
   cfg.potential_correction_extreme_touch_epsilon_points = 0.0;
   cfg.potential_correction_extreme_touch_min_count = 1;
   cfg.potential_correction_supersede_direction_mode = MOHY_POT_CORR_SUPERSEDE_DIR_ANY;
   cfg.potential_correction_supersede_scope = MOHY_POT_CORR_SUPERSEDE_SCOPE_FORMING_ONLY;
  }

void MohySetDefaultEntryConfig(EntryConfig &cfg)
  {
   cfg.min_rr = 2.0;
   cfg.rr_tolerance = 0.02;
   cfg.enable_spread_filter = true;
   cfg.max_spread_points = 40.0;

   cfg.execution_mode = MOHY_ENTRY_VIRTUAL_TRIGGER;
   cfg.recheck_mode = MOHY_RECHECK_ADJUST_ON_FAIL;
   cfg.adjust_cadence = MOHY_ADJUST_CADENCE_TICK_WITH_THROTTLE;
   cfg.adjust_min_seconds = 1;

   cfg.recheck_rr_at_trigger = true;
   cfg.sell_trigger_touch_side = MOHY_TOUCH_LOW_COST;
   cfg.buy_trigger_touch_side = MOHY_TOUCH_LOW_COST;

   cfg.spread_ema_period = 20;
   cfg.fixed_slippage_points = 1.0;
   cfg.slippage_spread_multiplier = 0.25;
   cfg.fixed_commission_points = 0.0;

   cfg.min_trigger_move_points = 1.0;
   cfg.enable_trigger_freeze = true;
   cfg.freeze_spread_multiplier = 0.5;
   cfg.min_stop_distance_points = 25.0;

   cfg.pre_entry_invalidation_mode = MOHY_PRE_ENTRY_INVALIDATE_TOUCH;
   cfg.pre_entry_invalidation_buffer_points = 0.0;

   cfg.enable_pending_auto_modify = true;
  }

void MohySetDefaultRiskConfig(RiskConfig &cfg)
  {
   cfg.risk_percent = 1.0;
   cfg.risk_base = MOHY_RISK_BASE_CALCULATED_BALANCE;
   cfg.max_concurrent_risk_percent = 3.0;
   cfg.exposure_base = MOHY_EXPOSURE_BASE_CALCULATED_BALANCE;
   cfg.magic_number = 26021601;
   cfg.slippage_points = 30;
   cfg.apply_exec_filters_to_management = true;
  }

void MohySetDefaultManagementConfig(ManagementConfig &cfg)
  {
   cfg.enable_break_even_on_impulse_extreme = true;
   cfg.be_retry_ticks = 5;

   cfg.post_be_profile = MOHY_POST_BE_HYBRID;
   cfg.post_be_start_mode = MOHY_POST_BE_START_AFTER_BE;
   cfg.post_be_start_r = 1.0;

   cfg.trail_model = MOHY_TRAIL_STRUCTURE_BASED;
   cfg.trail_update_cadence = MOHY_TRAIL_HYBRID_INTRABAR;
   cfg.trail_one_way_ratchet = true;
   cfg.trail_structure_swing_index = 1;
   cfg.trail_fixed_points = 150.0;
   cfg.trail_atr_period = 14;
   cfg.trail_atr_multiplier = 1.0;
   cfg.trail_ma_period = 20;
   cfg.trail_ma_method = MODE_EMA;
   cfg.trail_ma_price = PRICE_CLOSE;
   cfg.trail_ma_buffer_points = 0.0;

   cfg.partial_model = MOHY_PARTIAL_R_MULTIPLE;
   cfg.partial_count = 2;
   cfg.partial_percent_1 = 50.0;
   cfg.partial_percent_2 = 50.0;
   cfg.partial_percent_3 = 0.0;
   cfg.partial_r_multiple_1 = 1.0;
   cfg.partial_r_multiple_2 = 2.0;
   cfg.partial_r_multiple_3 = 3.0;
   cfg.partial_fib_level_1 = 0.272;
   cfg.partial_fib_level_2 = 0.618;
   cfg.partial_fib_level_3 = 1.0;
   cfg.partial_target_mode_1 = MOHY_PARTIAL_TARGET_R_MULTIPLE;
   cfg.partial_target_mode_2 = MOHY_PARTIAL_TARGET_R_MULTIPLE;
   cfg.partial_target_mode_3 = MOHY_PARTIAL_TARGET_R_MULTIPLE;

   cfg.post_partial_stop_action = MOHY_POST_PARTIAL_MOVE_TO_BE_OR_BE_PLUS;
   cfg.post_partial_be_plus_points = 0.0;
   cfg.runner_target_mode = MOHY_RUNNER_KEEP_EXISTING_TP;

   cfg.management_retry_count = 3;
   cfg.management_retry_then_market_close = true;

   cfg.enable_safeguard_sl = true;
   cfg.safeguard_sl_multiplier = 2.0;
  }

void MohySetDefaultUiOpsConfig(UiOpsConfig &cfg)
  {
   cfg.enable_ui = true;
   cfg.dangerous_action_cooldown_seconds = 5;
   cfg.redraw_throttle_ms = 250;
   cfg.enable_terminal_alerts = true;
   cfg.enable_file_audit = true;
  }

void MohySetDefaultStrategyConfig(StrategyConfig &cfg)
  {
   cfg.timeframe_pair = MOHY_TF_PAIR_H1_M15;
   MohyResolveTimeframePair(cfg.timeframe_pair,
                            cfg.context_timeframe,
                            cfg.execution_timeframe);

   MohySetDefaultDetectionConfig(cfg.detection);
   MohySetDefaultEntryConfig(cfg.entry);
   MohySetDefaultRiskConfig(cfg.risk);
   MohySetDefaultManagementConfig(cfg.management);
   MohySetDefaultUiOpsConfig(cfg.ui);

   cfg.sl_mode = MOHY_SL_OUTER_CORRECTION_EXTREME;
   cfg.outer_sl_buffer_points = 0.0;
   cfg.inner_sl_buffer_points = 0.0;
   cfg.inner_stop_swing_index = 1;

   cfg.tp_mode = MOHY_TP_FIB_NEG_EXTENSION;
   cfg.fib_target_level = 0.272;
   cfg.target_rr = 2.0;

   cfg.symbol = Symbol();
  }

#endif
