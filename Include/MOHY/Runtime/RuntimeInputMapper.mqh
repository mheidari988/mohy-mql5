#ifndef __MOHY_RUNTIME_INPUT_MAPPER_MQH__
#define __MOHY_RUNTIME_INPUT_MAPPER_MQH__

#include <MOHY/Domain/Config.mqh>

struct MohyRuntimeInputConfig
  {
   string                                symbol;
   int                                   context_timeframe;
   int                                   execution_timeframe;

   bool                                  potential_impulse_enabled;
   int                                   potential_impulse_min_swing_breakout_closes;
   bool                                  potential_impulse_require_leg_breakout;
   int                                   potential_impulse_min_leg_breakout_closes;
   bool                                  potential_impulse_require_directional_candles;
   bool                                  potential_impulse_validate_endpoint_candles;
   int                                   potential_impulse_allow_opposite_begin_candles;
   int                                   potential_impulse_allow_opposite_end_candles;
   int                                   potential_impulse_max_opposite_middle_candles;
   bool                                  potential_impulse_allow_any_opposite_before_leg_breakout;
   double                                potential_impulse_doji_epsilon_points;

   bool                                  potential_correction_enabled;
   int                                   potential_correction_min_opposite_ici_count;
   MohyPotentialCorrectionMinFibLevel    potential_correction_min_fib_level;
   MohyLevelTriggerMode                  potential_correction_min_fib_trigger_mode;
   MohyPotentialCorrectionMaxFibLevel    potential_correction_max_fib_level;
   MohyLevelTriggerMode                  potential_correction_max_fib_trigger_mode;
   double                                potential_correction_extreme_touch_epsilon_points;
   int                                   potential_correction_extreme_touch_min_count;
   MohyPotentialCorrectionSupersedeDirectionMode potential_correction_supersede_direction_mode;
   MohyPotentialCorrectionSupersedeScope potential_correction_supersede_scope;
   MohyContinuationPlanningStartMode     continuation_planning_start_mode;

   MohyEntryExecutionMode                entry_execution_mode;
   double                                min_rr;
   double                                rr_tolerance;
   bool                                  enable_spread_filter;
   double                                max_spread_points;
   MohyRecheckMode                       recheck_mode;
   MohyAdjustCadence                     adjust_cadence;
   int                                   adjust_min_seconds;
   bool                                  recheck_rr_at_trigger;
   MohyTouchSide                         sell_trigger_touch_side;
   MohyTouchSide                         buy_trigger_touch_side;
   int                                   spread_ema_period;
   double                                fixed_slippage_points;
   double                                slippage_spread_multiplier;
   double                                fixed_commission_points;
   double                                min_trigger_move_points;
   bool                                  enable_trigger_freeze;
   double                                freeze_spread_multiplier;
   double                                min_stop_distance_points;
   MohyPreEntryInvalidationMode          pre_entry_invalidation_mode;
   double                                pre_entry_invalidation_buffer_points;
   bool                                  enable_pending_auto_modify;

   double                                risk_percent;
   MohyRiskBase                          risk_base;
   double                                max_concurrent_risk_percent;
   MohyExposureBase                      exposure_base;
   int                                   magic_number;
   int                                   broker_slippage_points;
   bool                                  apply_exec_filters_to_management;

   MohySLMode                            stop_loss_mode;
   double                                outer_sl_buffer_points;
   double                                inner_sl_buffer_points;
   int                                   inner_stop_swing_index;
   MohyTPMode                            take_profit_mode;
   double                                fib_target_level;
   double                                target_rr;

   MohyPostBEProfile                     post_be_management_profile;
   MohyPostBEStartMode                   post_be_start_mode;
   double                                post_be_start_r;
   bool                                  enable_break_even_on_impulse_extreme;
   int                                   be_retry_ticks;
   MohyTrailModel                        trail_model;
   MohyTrailUpdateCadence                trail_update_cadence;
   bool                                  trail_one_way_ratchet;
   int                                   trail_structure_swing_index;
   double                                trail_fixed_points;
   int                                   trail_atr_period;
   double                                trail_atr_multiplier;
   int                                   trail_ma_method;
   int                                   trail_ma_period;
   int                                   trail_ma_price;
   double                                trail_ma_buffer_points;
   MohyPartialModel                      partial_model;
   int                                   partial_count;
   double                                partial_percent_1;
   double                                partial_percent_2;
   double                                partial_percent_3;
   double                                partial_r_multiple_1;
   double                                partial_r_multiple_2;
   double                                partial_r_multiple_3;
   double                                partial_fib_level_1;
   double                                partial_fib_level_2;
   double                                partial_fib_level_3;
   MohyPartialTargetMode                 partial_target_mode_1;
   MohyPartialTargetMode                 partial_target_mode_2;
   MohyPartialTargetMode                 partial_target_mode_3;
   MohyPostPartialStopAction             post_partial_stop_action;
   double                                post_partial_be_plus_points;
   MohyRunnerTargetMode                  runner_target_mode;
   int                                   management_retry_count;
   bool                                  management_retry_then_market_close;

   bool                                  panel_enabled;
   int                                   dangerous_action_cooldown_seconds;
   int                                   ui_redraw_throttle_ms;
   bool                                  enable_terminal_alerts;
   bool                                  enable_file_audit;
  };

bool MohyBuildStrategyConfigFromRuntimeInputs(const MohyRuntimeInputConfig &inputs,
                                              StrategyConfig &out_cfg,
                                              string &out_error)
  {
   out_error = "";
   MohySetDefaultStrategyConfig(out_cfg);
   out_cfg.symbol = inputs.symbol;

   const int htf = inputs.context_timeframe;
   const int ltf = inputs.execution_timeframe;
   if(!MohyValidateTimeframePair(htf, ltf))
     {
      out_error = StringFormat("Invalid timeframe pair HTF=%s LTF=%s. Allowed: H1/M15, H2/M30, H4/H1, D1/H4.",
                               MohyTimeframeToString(htf),
                               MohyTimeframeToString(ltf));
      return false;
     }

   MohyTimeframePair pair = MOHY_TF_PAIR_H1_M15;
   if(!MohyResolveTimeframePairFromFrames(htf, ltf, pair))
     {
      out_error = StringFormat("Unsupported timeframe pair HTF=%s LTF=%s",
                               MohyTimeframeToString(htf),
                               MohyTimeframeToString(ltf));
      return false;
     }

   out_cfg.timeframe_pair = pair;
   out_cfg.context_timeframe = htf;
   out_cfg.execution_timeframe = ltf;

   out_cfg.detection.enable_potential_impulse = inputs.potential_impulse_enabled;
   out_cfg.detection.potential_impulse_min_swing_breakout_closes = MathMax(0, inputs.potential_impulse_min_swing_breakout_closes);
   out_cfg.detection.potential_impulse_require_leg_breakout = inputs.potential_impulse_require_leg_breakout;
   out_cfg.detection.potential_impulse_min_leg_breakout_closes = MathMax(1, inputs.potential_impulse_min_leg_breakout_closes);
   out_cfg.detection.potential_impulse_require_directional_candles = inputs.potential_impulse_require_directional_candles;
   out_cfg.detection.potential_impulse_validate_endpoint_candles = inputs.potential_impulse_validate_endpoint_candles;
   out_cfg.detection.potential_impulse_allow_opposite_begin_candles = MathMax(0, inputs.potential_impulse_allow_opposite_begin_candles);
   out_cfg.detection.potential_impulse_allow_opposite_end_candles = MathMax(0, inputs.potential_impulse_allow_opposite_end_candles);
   out_cfg.detection.potential_impulse_max_opposite_middle_candles = MathMax(0, inputs.potential_impulse_max_opposite_middle_candles);
   out_cfg.detection.potential_impulse_allow_any_opposite_before_leg_breakout = inputs.potential_impulse_allow_any_opposite_before_leg_breakout;
   out_cfg.detection.potential_impulse_doji_epsilon_points = MathMax(1e-10, inputs.potential_impulse_doji_epsilon_points);

   out_cfg.detection.enable_potential_correction = inputs.potential_correction_enabled;
   out_cfg.detection.potential_correction_min_opposite_ici_count = MathMax(0, inputs.potential_correction_min_opposite_ici_count);
   out_cfg.detection.potential_correction_min_fib_level = inputs.potential_correction_min_fib_level;
   out_cfg.detection.potential_correction_min_fib_trigger_mode = inputs.potential_correction_min_fib_trigger_mode;
   out_cfg.detection.potential_correction_max_fib_level = inputs.potential_correction_max_fib_level;
   out_cfg.detection.potential_correction_max_fib_trigger_mode = inputs.potential_correction_max_fib_trigger_mode;
   out_cfg.detection.potential_correction_extreme_touch_epsilon_points = MathMax(0.0, inputs.potential_correction_extreme_touch_epsilon_points);
   out_cfg.detection.potential_correction_extreme_touch_min_count = MathMax(1, inputs.potential_correction_extreme_touch_min_count);
   out_cfg.detection.potential_correction_supersede_direction_mode = inputs.potential_correction_supersede_direction_mode;
   out_cfg.detection.potential_correction_supersede_scope = inputs.potential_correction_supersede_scope;
   out_cfg.detection.continuation_planning_start_mode = inputs.continuation_planning_start_mode;

   if(!MohyIsPotentialCorrectionFibRangeValid(out_cfg.detection.potential_correction_min_fib_level,
                                              out_cfg.detection.potential_correction_max_fib_level))
     {
      out_error = "Invalid PotentialCorrection fib range: max fib must be strictly greater than min fib.";
      return false;
     }

   out_cfg.entry.execution_mode = inputs.entry_execution_mode;
   out_cfg.entry.min_rr = inputs.min_rr;
   out_cfg.entry.rr_tolerance = inputs.rr_tolerance;
   out_cfg.entry.enable_spread_filter = inputs.enable_spread_filter;
   out_cfg.entry.max_spread_points = inputs.max_spread_points;
   out_cfg.entry.recheck_mode = inputs.recheck_mode;
   out_cfg.entry.adjust_cadence = inputs.adjust_cadence;
   out_cfg.entry.adjust_min_seconds = MathMax(0, inputs.adjust_min_seconds);
   out_cfg.entry.recheck_rr_at_trigger = inputs.recheck_rr_at_trigger;
   out_cfg.entry.sell_trigger_touch_side = inputs.sell_trigger_touch_side;
   out_cfg.entry.buy_trigger_touch_side = inputs.buy_trigger_touch_side;
   out_cfg.entry.spread_ema_period = MathMax(1, inputs.spread_ema_period);
   out_cfg.entry.fixed_slippage_points = MathMax(0.0, inputs.fixed_slippage_points);
   out_cfg.entry.slippage_spread_multiplier = MathMax(0.0, inputs.slippage_spread_multiplier);
   out_cfg.entry.fixed_commission_points = MathMax(0.0, inputs.fixed_commission_points);
   out_cfg.entry.min_trigger_move_points = MathMax(0.0, inputs.min_trigger_move_points);
   out_cfg.entry.enable_trigger_freeze = inputs.enable_trigger_freeze;
   out_cfg.entry.freeze_spread_multiplier = MathMax(0.0, inputs.freeze_spread_multiplier);
   out_cfg.entry.min_stop_distance_points = MathMax(0.0, inputs.min_stop_distance_points);
   out_cfg.entry.pre_entry_invalidation_mode = inputs.pre_entry_invalidation_mode;
   out_cfg.entry.pre_entry_invalidation_buffer_points = MathMax(0.0, inputs.pre_entry_invalidation_buffer_points);
   out_cfg.entry.enable_pending_auto_modify = inputs.enable_pending_auto_modify;

   out_cfg.risk.risk_percent = MathMax(0.0, inputs.risk_percent);
   out_cfg.risk.risk_base = inputs.risk_base;
   out_cfg.risk.max_concurrent_risk_percent = MathMax(0.0, inputs.max_concurrent_risk_percent);
   out_cfg.risk.exposure_base = inputs.exposure_base;
   out_cfg.risk.magic_number = inputs.magic_number;
   out_cfg.risk.slippage_points = MathMax(0, inputs.broker_slippage_points);
   out_cfg.risk.apply_exec_filters_to_management = inputs.apply_exec_filters_to_management;

   out_cfg.sl_mode = inputs.stop_loss_mode;
   out_cfg.outer_sl_buffer_points = MathMax(0.0, inputs.outer_sl_buffer_points);
   out_cfg.inner_sl_buffer_points = MathMax(0.0, inputs.inner_sl_buffer_points);
   out_cfg.inner_stop_swing_index = MathMax(1, inputs.inner_stop_swing_index);
   out_cfg.tp_mode = inputs.take_profit_mode;
   out_cfg.fib_target_level = MathMax(0.0, inputs.fib_target_level);
   out_cfg.target_rr = MathMax(0.0, inputs.target_rr);

   out_cfg.management.post_be_profile = inputs.post_be_management_profile;
   out_cfg.management.post_be_start_mode = inputs.post_be_start_mode;
   out_cfg.management.post_be_start_r = MathMax(0.0, inputs.post_be_start_r);
   out_cfg.management.enable_break_even_on_impulse_extreme = inputs.enable_break_even_on_impulse_extreme;
   out_cfg.management.be_retry_ticks = MathMax(1, inputs.be_retry_ticks);
   out_cfg.management.trail_model = inputs.trail_model;
   out_cfg.management.trail_update_cadence = inputs.trail_update_cadence;
   out_cfg.management.trail_one_way_ratchet = inputs.trail_one_way_ratchet;
   out_cfg.management.trail_structure_swing_index = MathMax(1, inputs.trail_structure_swing_index);
   out_cfg.management.trail_fixed_points = MathMax(0.0, inputs.trail_fixed_points);
   out_cfg.management.trail_atr_period = MathMax(1, inputs.trail_atr_period);
   out_cfg.management.trail_atr_multiplier = MathMax(0.0, inputs.trail_atr_multiplier);
   out_cfg.management.trail_ma_period = MathMax(1, inputs.trail_ma_period);
   out_cfg.management.trail_ma_method = inputs.trail_ma_method;
   out_cfg.management.trail_ma_price = inputs.trail_ma_price;
   out_cfg.management.trail_ma_buffer_points = MathMax(0.0, inputs.trail_ma_buffer_points);
   out_cfg.management.partial_model = inputs.partial_model;
   out_cfg.management.partial_count = MathMax(1, MathMin(3, inputs.partial_count));
   out_cfg.management.partial_percent_1 = MathMax(0.0, inputs.partial_percent_1);
   out_cfg.management.partial_percent_2 = MathMax(0.0, inputs.partial_percent_2);
   out_cfg.management.partial_percent_3 = MathMax(0.0, inputs.partial_percent_3);
   out_cfg.management.partial_r_multiple_1 = MathMax(0.0, inputs.partial_r_multiple_1);
   out_cfg.management.partial_r_multiple_2 = MathMax(0.0, inputs.partial_r_multiple_2);
   out_cfg.management.partial_r_multiple_3 = MathMax(0.0, inputs.partial_r_multiple_3);
   out_cfg.management.partial_fib_level_1 = inputs.partial_fib_level_1;
   out_cfg.management.partial_fib_level_2 = inputs.partial_fib_level_2;
   out_cfg.management.partial_fib_level_3 = inputs.partial_fib_level_3;
   out_cfg.management.partial_target_mode_1 = inputs.partial_target_mode_1;
   out_cfg.management.partial_target_mode_2 = inputs.partial_target_mode_2;
   out_cfg.management.partial_target_mode_3 = inputs.partial_target_mode_3;
   out_cfg.management.post_partial_stop_action = inputs.post_partial_stop_action;
   out_cfg.management.post_partial_be_plus_points = MathMax(0.0, inputs.post_partial_be_plus_points);
   out_cfg.management.runner_target_mode = inputs.runner_target_mode;
   out_cfg.management.management_retry_count = MathMax(1, inputs.management_retry_count);
   out_cfg.management.management_retry_then_market_close = inputs.management_retry_then_market_close;

   out_cfg.ui.enable_ui = inputs.panel_enabled;
   out_cfg.ui.dangerous_action_cooldown_seconds = MathMax(1, inputs.dangerous_action_cooldown_seconds);
   out_cfg.ui.redraw_throttle_ms = MathMax(0, inputs.ui_redraw_throttle_ms);
   out_cfg.ui.enable_terminal_alerts = inputs.enable_terminal_alerts;
   out_cfg.ui.enable_file_audit = inputs.enable_file_audit;

   if(out_cfg.management.post_be_profile == MOHY_POST_BE_PARTIAL_ONLY ||
      out_cfg.management.post_be_profile == MOHY_POST_BE_HYBRID)
     {
      const double active_partial_sum =
         out_cfg.management.partial_percent_1 +
         ((out_cfg.management.partial_count >= 2) ? out_cfg.management.partial_percent_2 : 0.0) +
         ((out_cfg.management.partial_count >= 3) ? out_cfg.management.partial_percent_3 : 0.0);
      if(MathAbs(active_partial_sum - 100.0) > 0.01)
        {
         out_error = StringFormat("Invalid partial sizing: active partial percents must sum to 100.0, got %.2f.",
                                  active_partial_sum);
         return false;
        }
     }

   return true;
  }

#endif
