#ifndef __MOHY_CORE_DOMAIN_PRICE_ACTION_CONTRACTS_MQH__
#define __MOHY_CORE_DOMAIN_PRICE_ACTION_CONTRACTS_MQH__

#include <MOHY/Domain/Contracts.mqh>
#include <MOHY/Core/Domain/PriceActionEnums.mqh>

struct MohyElementFact
  {
   int             index;
   int             shift;
   datetime        time;
   MohyElementType type;
   bool            confirmed;
   MohyDirection   candle_momentum;
   double          open_price;
   double          high_price;
   double          low_price;
   double          close_price;
   double          pivot_price;
   bool            dual_pivot;
   int             dual_order;
  };

struct MohyLegFact
  {
   int             index;
   int             begin_element_index;
   int             end_element_index;
   MohyLegType     type;
   MohyDirection   direction;
   bool            confirmed;
   int             begin_shift;
   datetime        begin_time;
   double          begin_price;
   int             end_shift;
   datetime        end_time;
   double          end_price;
   int             candle_count;
  };

struct MohySwing3Fact
  {
   int                  index;
   int                  leg1_index;
   int                  leg2_index;
   int                  leg3_index;
   MohyDirection        direction;
   bool                 confirmed;
   MohySwing3PatternType pattern_type;
   MohyBreakState       break_state;
   MohyBreakoutCertainty breakout_certainty;
   MohyCorrectionState  correction_state;
   int                  breakout_close_count;
   int                  lower_low_element_index;
   int                  higher_low_element_index;
   int                  lower_high_element_index;
   int                  higher_high_element_index;
  };

struct MohyPotentialImpulseFact
  {
   int                  index;
   bool                 valid;
   int                  swing3_index;
   int                  leg_index;
   MohyDirection        direction;
   bool                 confirmed;
   MohySwing3PatternType pattern_type;
   MohyBreakState       break_state;
   MohyBreakoutCertainty swing_breakout_certainty;
   int                  swing_breakout_close_count;
   double               leg_break_reference_price;
   int                  leg_breakout_close_count;
   int                  first_leg_breakout_shift;
   datetime             first_leg_breakout_time;
   int                  begin_shift;
   datetime             begin_time;
   double               begin_price;
   int                  end_shift;
   datetime             end_time;
   double               end_price;
   string               runtime_impulse_id;
   string               diagnostics;
  };

struct MohyPotentialCorrectionTimelineFact
  {
   int                  timeline_end_shift;
   datetime             timeline_end_time;
   int                  extreme_shift;
   datetime             extreme_time;
   double               extreme_price;
   int                  forming_end_shift;
   datetime             forming_end_time;
   double               forming_end_price;
   bool                 has_confirmed_segment;
   int                  confirmed_begin_shift;
   datetime             confirmed_begin_time;
   double               confirmed_begin_price;
   int                  confirmed_end_shift;
   datetime             confirmed_end_time;
   double               confirmed_end_price;
   bool                 has_invalidated_segment;
   int                  invalid_begin_shift;
   datetime             invalid_begin_time;
   double               invalid_begin_price;
   int                  invalid_end_shift;
   datetime             invalid_end_time;
   double               invalid_end_price;
  };

struct MohyPotentialCorrectionFact
  {
   int                  index;
   bool                 valid;
   int                  linked_potential_impulse_index;
   int                  linked_potential_impulse_swing3_index;
   MohyDirection        impulse_direction;
   bool                 confirmed;
   MohyPotentialCorrectionState state;
   MohyPotentialCorrectionTerminationReason termination_reason;
   int                  begin_shift;
   datetime             begin_time;
   double               begin_price;
   int                  reference_begin_shift;
   datetime             reference_begin_time;
   double               reference_begin_price;
   int                  visual_begin_shift;
   datetime             visual_begin_time;
   double               visual_begin_price;
   int                  end_shift;
   datetime             end_time;
   double               end_price;
   double               impulse_origin_price;
   double               impulse_extreme_price;
   double               retrace_depth;
   double               min_fib_level;
   double               max_fib_level;
   MohyLevelTriggerMode min_fib_trigger_mode;
   MohyLevelTriggerMode max_fib_trigger_mode;
   int                  opposite_ici_count;
   int                  min_opposite_ici_count;
   bool                 min_fib_gate_pass;
   bool                 opposite_ici_gate_pass;
   int                  confirmed_shift;
   datetime             confirmed_time;
   int                  invalidated_shift;
   datetime             invalidated_time;
   int                  recency_rank;
   bool                 is_active;
   bool                 is_selected;
   string               runtime_impulse_id;
   MohyPotentialCorrectionTimelineFact timeline_full;
   MohyPotentialCorrectionTimelineFact timeline_trimmed;
   string               diagnostics;
  };

struct MohyPotentialContinuationSignalFact
  {
   int                  index;
   bool                 valid;
   int                  linked_potential_correction_index;
   int                  linked_potential_impulse_index;
   int                  linked_potential_impulse_swing3_index;
   int                  linked_correction_recency_rank;
   bool                 linked_correction_is_active;
   MohyPotentialCorrectionState linked_correction_state;
   MohyDirection        direction;
   int                  correction_confirmed_shift;
   datetime             correction_confirmed_time;
   int                  trigger_swing3_index;
   int                  trigger_middle_leg_index;
   int                  trigger_broken_leg_index;
   MohyBreakoutCertainty trigger_breakout_certainty;
   int                  trigger_breakout_close_count;
   int                  broken_leg_begin_shift;
   datetime             broken_leg_begin_time;
   int                  broken_leg_end_shift;
   datetime             broken_leg_end_time;
   int                  signal_shift;
   datetime             signal_time;
   int                  broken_level_shift;
   datetime             broken_level_time;
   double               broken_level_price;
   int                  selection_rank;
   bool                 is_selected;
   string               runtime_impulse_id;
   string               runtime_setup_key;
   string               diagnostics;
  };

struct MohyTradeSetupPlanFact
  {
   int                       index;
   bool                      valid;
   int                       linked_potential_continuation_signal_index;
    int                       linked_potential_correction_index;
    int                       linked_potential_impulse_index;
    int                       linked_potential_impulse_swing3_index;
    int                       linked_correction_recency_rank;
    bool                      linked_correction_is_active;
    MohyDirection             direction;
    MohyTradeSetupPlanState   plan_state;
    MohyRejectReason          reject_reason;
    MohyEntryExecutionMode    execution_mode;
    int                       setup_shift;
    datetime                  setup_time;
    MohyPostBEProfile         post_be_profile;
   double                    current_executable_price;
   double                    proposed_entry_price;
   double                    expected_fill_price;
   double                    required_entry_price;
   double                    trigger_price;
   double                    stop_price;
   double                    target_price;
   double                    reward_to_risk;
   double                    min_rr;
   double                    rr_tolerance;
   MohyTouchSide             trigger_touch_side;
   MohyRecheckMode           recheck_mode;
   MohyAdjustCadence         adjust_cadence;
   int                       adjust_min_seconds;
   bool                      recheck_rr_at_trigger;
   double                    spread_est_points;
   double                    slippage_est_points;
   double                    commission_est_points;
   double                    total_entry_cost_points;
   double                    min_trigger_move_points;
   bool                      trigger_freeze_enabled;
   double                    trigger_freeze_points;
   bool                      pending_auto_modify_enabled;
   double                    risk_distance_points;
   double                    risk_money;
   double                    lots_raw;
   double                    lots_normalized;
   double                    spread_points;
   bool                      spread_pass;
   bool                      exposure_pass;
    MohyTradeSetupStopAnchorType stop_anchor_type;
    MohyTradeSetupTargetAnchorType target_anchor_type;
    int                       stop_anchor_shift;
    int                       target_anchor_shift;
   int                       selection_rank;
   bool                      is_selected;
   string                    runtime_impulse_id;
   string                    runtime_setup_key;
   string                    diagnostics;
  };

struct MohyHistoricalTradeSetupFact
  {
   int                       index;
   bool                      valid;
   int                       linked_trade_setup_plan_index;
   int                       linked_potential_continuation_signal_index;
   int                       linked_potential_correction_index;
   int                       linked_potential_impulse_index;
   string                    runtime_impulse_id;
   string                    runtime_setup_key;
   MohyDirection             direction;
   MohyTradeSetupPlanState   initial_plan_state;
   MohyHistoricalTradeSetupOutcome outcome;
   bool                      entered;
   int                       setup_shift;
   datetime                  setup_time;
   double                    planned_entry_price;
   double                    stop_price;
   double                    target_price;
   int                       entry_shift;
   datetime                  entry_time;
   double                    entry_price;
   int                       exit_shift;
   datetime                  exit_time;
   double                    exit_price;
   string                    diagnostics;
  };

class CMohyPriceActionSnapshot
  {
public:
   string            symbol;
   int               timeframe;
   int               context_timeframe;
   int               execution_timeframe;
   int               from_shift;
   int               max_shift;
   datetime          built_at;
   bool              source_is_context_timeframe;
   bool              source_is_execution_timeframe;
   bool              publishes_execution_stage_facts;
   MohyElementFact   elements[];
   MohyLegFact       legs[];
   MohySwing3Fact    swings3[];
    MohyPotentialImpulseFact potential_impulses[];
    MohyPotentialCorrectionFact potential_corrections[];
    MohyPotentialContinuationSignalFact potential_continuation_signals[];
   MohyTradeSetupPlanFact trade_setup_plans[];
   MohyHistoricalTradeSetupFact historical_trade_setups[];

   void              Reset()
     {
     symbol = "";
     timeframe = 0;
      context_timeframe = 0;
      execution_timeframe = 0;
      from_shift = -1;
      max_shift = -1;
      built_at = 0;
      source_is_context_timeframe = false;
      source_is_execution_timeframe = false;
      publishes_execution_stage_facts = false;
      ArrayResize(elements, 0);
      ArrayResize(legs, 0);
      ArrayResize(swings3, 0);
      ArrayResize(potential_impulses, 0);
      ArrayResize(potential_corrections, 0);
      ArrayResize(potential_continuation_signals, 0);
      ArrayResize(trade_setup_plans, 0);
      ArrayResize(historical_trade_setups, 0);
     }
  };

#endif
