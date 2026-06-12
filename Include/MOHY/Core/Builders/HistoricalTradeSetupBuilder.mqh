#ifndef __MOHY_CORE_BUILDERS_HISTORICAL_TRADE_SETUP_BUILDER_MQH__
#define __MOHY_CORE_BUILDERS_HISTORICAL_TRADE_SETUP_BUILDER_MQH__

#include <MOHY/Domain/Config.mqh>
#include <MOHY/Core/Domain/PriceActionContracts.mqh>
#include <MOHY/Core/Compat/TerminalSeries.mqh>
#include <MOHY/Core/Builders/TradeSetupPlanner.mqh>

class CMohyHistoricalTradeSetupBuilder
  {
private:
   StrategyConfig         m_cfg;
   int                    m_timeframe;
   int                    m_execution_timeframe;
   CMohyTradeSetupPlanner m_planner;

   double Eps() const
     {
      return 1e-10;
     }

   int FindLinkedPlanIndex(const MohyPotentialContinuationSignalFact &signal,
                           const MohyTradeSetupPlanFact &plans[]) const
     {
      const int count = ArraySize(plans);
      for(int i = 0; i < count; ++i)
        {
         if(!plans[i].valid)
            continue;
         if(plans[i].linked_potential_continuation_signal_index == signal.index)
            return i;
        }
      return -1;
     }

   bool ResolveCorrectionExtremeAtShift(const string symbol,
                                        const MohyDirection impulse_direction,
                                        const int begin_shift,
                                        const int end_shift,
                                        const double fallback_price,
                                        int &out_shift,
                                        datetime &out_time,
                                        double &out_price) const
     {
      out_shift = begin_shift;
      out_time = MohyITime(symbol, m_execution_timeframe, begin_shift);
      out_price = fallback_price;

      if(symbol == "" || begin_shift < 0 || end_shift < 0 || begin_shift < end_shift)
         return false;

      bool initialized = false;
      for(int shift = begin_shift; shift >= end_shift; --shift)
        {
         const datetime bar_time = MohyITime(symbol, m_execution_timeframe, shift);
         if(bar_time <= 0)
            continue;

         double candidate_price = 0.0;
         if(impulse_direction == MOHY_DIR_BULL)
            candidate_price = MohyILow(symbol, m_execution_timeframe, shift);
         else if(impulse_direction == MOHY_DIR_BEAR)
            candidate_price = MohyIHigh(symbol, m_execution_timeframe, shift);
         else
            return false;

         if(candidate_price <= 0.0)
            continue;

         const bool is_better = !initialized ||
                                (impulse_direction == MOHY_DIR_BULL
                                 ? (candidate_price < out_price - Eps())
                                 : (candidate_price > out_price + Eps())) ||
                                (MathAbs(candidate_price - out_price) <= Eps() && shift < out_shift);
         if(!is_better)
            continue;

         initialized = true;
         out_shift = shift;
         out_time = bar_time;
         out_price = candidate_price;
        }

      return initialized;
     }

   bool BuildSignalTimeCorrection(const string symbol,
                                  const MohyPotentialCorrectionFact &correction,
                                  const int setup_shift,
                                  MohyPotentialCorrectionFact &out_correction) const
     {
      out_correction = correction;
      if(symbol == "" || !correction.valid || correction.begin_shift < 0 || setup_shift < 0)
         return false;

      const int capped_end_shift = MathMax(0, MathMin(correction.begin_shift, setup_shift));
      int end_shift = capped_end_shift;
      datetime end_time = MohyITime(symbol, m_execution_timeframe, capped_end_shift);
      double end_price = correction.begin_price;
      ResolveCorrectionExtremeAtShift(symbol,
                                      correction.impulse_direction,
                                      correction.begin_shift,
                                      capped_end_shift,
                                      correction.begin_price,
                                      end_shift,
                                      end_time,
                                      end_price);

      out_correction.end_shift = end_shift;
      out_correction.end_time = end_time;
      out_correction.end_price = end_price;

      const double impulse_range = MathAbs(correction.impulse_extreme_price -
                                           correction.impulse_origin_price);
      out_correction.retrace_depth = (impulse_range > Eps())
                                     ? MathAbs(end_price - correction.impulse_extreme_price) / impulse_range
                                     : 0.0;

      const bool confirmed_at_setup = (correction.confirmed_shift >= capped_end_shift &&
                                       correction.confirmed_shift <= correction.begin_shift);
      const bool invalidated_at_setup = (correction.invalidated_shift >= capped_end_shift &&
                                         correction.invalidated_shift <= correction.begin_shift);

      if(invalidated_at_setup)
        {
         out_correction.state = MOHY_POT_CORR_STATE_INVALIDATED;
         out_correction.termination_reason = correction.termination_reason;
         out_correction.confirmed = false;
        }
      else if(confirmed_at_setup)
        {
         out_correction.state = MOHY_POT_CORR_STATE_CONFIRMED;
         out_correction.termination_reason = MOHY_POT_CORR_TERM_CONFIRMED;
         out_correction.confirmed = true;
        }
      else
        {
         out_correction.state = MOHY_POT_CORR_STATE_FORMING;
         out_correction.termination_reason = MOHY_POT_CORR_TERM_NONE;
         out_correction.confirmed = false;
         out_correction.confirmed_shift = -1;
         out_correction.confirmed_time = 0;
        }

      if(!invalidated_at_setup)
        {
         out_correction.invalidated_shift = -1;
         out_correction.invalidated_time = 0;
        }

      return true;
     }

   MohyHistoricalTradeSetupOutcome ResolvePostEntryOutcome(const string symbol,
                                                           const MohyDirection direction,
                                                           const MohyTradeSetupPlanFact &plan,
                                                           const int entry_shift,
                                                           int &out_exit_shift,
                                                           datetime &out_exit_time,
                                                           double &out_exit_price) const
     {
      out_exit_shift = -1;
      out_exit_time = 0;
      out_exit_price = 0.0;

      const int start_shift = MathMax(0, entry_shift - 1);
      for(int shift = start_shift; shift >= 0; --shift)
        {
         const double high_price = MohyIHigh(symbol, m_execution_timeframe, shift);
         const double low_price = MohyILow(symbol, m_execution_timeframe, shift);
         const bool target_hit = (direction == MOHY_DIR_BULL)
                                 ? (high_price >= plan.target_price - Eps())
                                 : (low_price <= plan.target_price + Eps());
         const bool stop_hit = (direction == MOHY_DIR_BULL)
                               ? (low_price <= plan.stop_price + Eps())
                               : (high_price >= plan.stop_price - Eps());
         if(!target_hit && !stop_hit)
            continue;

         out_exit_shift = shift;
         out_exit_time = MohyITime(symbol, m_execution_timeframe, shift);
         if(stop_hit)
           {
            out_exit_price = plan.stop_price;
            return MOHY_HIST_SETUP_OUTCOME_STOP_HIT;
           }

         out_exit_price = plan.target_price;
         return MOHY_HIST_SETUP_OUTCOME_TARGET_HIT;
        }

      return MOHY_HIST_SETUP_OUTCOME_OPEN;
     }

public:
            CMohyHistoricalTradeSetupBuilder()
              {
               MohySetDefaultStrategyConfig(m_cfg);
               m_timeframe = PERIOD_M15;
               m_execution_timeframe = PERIOD_M15;
               m_planner.Configure(m_cfg, m_execution_timeframe);
              }

   void     Configure(const StrategyConfig &cfg,
                      const int timeframe,
                      const int execution_timeframe)
     {
      m_cfg = cfg;
      m_timeframe = timeframe;
      m_execution_timeframe = execution_timeframe;
      m_planner.Configure(m_cfg, m_execution_timeframe);
     }

   int      Build(const string symbol,
                  const MohyLegFact &execution_legs[],
                  const MohyPotentialCorrectionFact &corrections[],
                  const MohyPotentialContinuationSignalFact &signals[],
                  const MohyTradeSetupPlanFact &plans[],
                  MohyHistoricalTradeSetupFact &out_facts[]) const
     {
      ArrayResize(out_facts, 0);
      if(symbol == "")
         return 0;
      if(m_timeframe != m_execution_timeframe)
         return 0;
      if(ArraySize(signals) <= 0 || ArraySize(corrections) <= 0)
         return 0;

      int fact_count = 0;
      for(int i = 0; i < ArraySize(signals); ++i)
        {
         const MohyPotentialContinuationSignalFact signal = signals[i];
         if(!signal.valid)
            continue;
         if(signal.linked_potential_correction_index < 0 ||
            signal.linked_potential_correction_index >= ArraySize(corrections))
            continue;

         const int setup_shift = MathMax(0, signal.signal_shift - 1);
         const datetime setup_time = MohyITime(symbol, m_execution_timeframe, setup_shift);
         if(setup_time <= 0)
            continue;

         MohyPotentialCorrectionFact signal_correction;
         if(!BuildSignalTimeCorrection(symbol,
                                       corrections[signal.linked_potential_correction_index],
                                       setup_shift,
                                       signal_correction))
            continue;

         const double setup_spread_points = m_planner.ResolveSpreadPointsAtShift(symbol, setup_shift);
         const double setup_spread_est_points = m_planner.ResolveSpreadEstimatePoints(symbol, setup_shift);
         const double setup_exec_price = m_planner.ResolveExecutableClosePrice(symbol,
                                                                               signal.direction,
                                                                               setup_shift,
                                                                               setup_spread_est_points);
         const bool spread_pass = (!m_cfg.entry.enable_spread_filter ||
                                   setup_spread_points <= m_cfg.entry.max_spread_points + Eps());
         if(setup_exec_price <= 0.0)
            continue;

         MohyTradeSetupPlanFact setup_plan;
         if(!m_planner.BuildPlan(symbol,
                                 execution_legs,
                                 signal_correction,
                                 signal,
                                 setup_exec_price,
                                 setup_shift,
                                 setup_spread_points,
                                 spread_pass,
                                 setup_plan))
            continue;

         if(!m_planner.IsPlanStateActionable(setup_plan.plan_state))
            continue;

         MohyHistoricalTradeSetupFact fact;
         fact.index = fact_count;
         fact.valid = true;
         fact.linked_trade_setup_plan_index = FindLinkedPlanIndex(signal, plans);
         fact.linked_potential_continuation_signal_index = signal.index;
         fact.linked_potential_correction_index = signal.linked_potential_correction_index;
         fact.linked_potential_impulse_index = signal.linked_potential_impulse_index;
         fact.direction = setup_plan.direction;
         fact.initial_plan_state = setup_plan.plan_state;
         fact.outcome = MOHY_HIST_SETUP_OUTCOME_WAITING;
         fact.entered = false;
         fact.setup_shift = setup_shift;
         fact.setup_time = setup_time;
         fact.planned_entry_price = (setup_plan.proposed_entry_price > 0.0)
                                    ? setup_plan.proposed_entry_price
                                    : setup_plan.trigger_price;
         fact.stop_price = setup_plan.stop_price;
         fact.target_price = setup_plan.target_price;
         fact.entry_shift = -1;
         fact.entry_time = 0;
         fact.entry_price = 0.0;
         fact.exit_shift = -1;
         fact.exit_time = 0;
         fact.exit_price = 0.0;
         fact.diagnostics = "";

         if(fact.initial_plan_state == MOHY_TRADE_SETUP_PLAN_ELIGIBLE_NOW)
           {
            fact.entered = true;
            fact.entry_shift = setup_shift;
            fact.entry_time = setup_time;
            fact.entry_price = (setup_plan.expected_fill_price > 0.0)
                               ? setup_plan.expected_fill_price
                               : setup_exec_price;
           }
         else
           {
            const int oldest_scan_shift = MathMax(0, setup_shift - 1);
            for(int shift = oldest_scan_shift; shift >= 0; --shift)
              {
               double invalidated_price = 0.0;
               if(m_planner.IsPreEntryInvalidatedAtShift(symbol,
                                                        fact.direction,
                                                        signal_correction,
                                                        shift,
                                                        invalidated_price))
                 {
                  fact.outcome = MOHY_HIST_SETUP_OUTCOME_MISSED;
                  fact.exit_shift = shift;
                  fact.exit_time = MohyITime(symbol, m_execution_timeframe, shift);
                  fact.exit_price = invalidated_price;
                  break;
                 }

               const double shift_spread_est_points = m_planner.ResolveSpreadEstimatePoints(symbol, shift);
               if(setup_plan.execution_mode == MOHY_ENTRY_REAL_PENDING_ORDER)
                 {
                  double touched_price = 0.0;
                  if(!m_planner.IsPendingTriggerTouched(symbol,
                                                       fact.direction,
                                                       setup_plan.trigger_price,
                                                       shift,
                                                       setup_plan.trigger_touch_side,
                                                       shift_spread_est_points,
                                                       touched_price))
                     continue;

                  fact.entered = true;
                  fact.entry_shift = shift;
                  fact.entry_time = MohyITime(symbol, m_execution_timeframe, shift);
                  fact.entry_price = (setup_plan.expected_fill_price > 0.0)
                                     ? setup_plan.expected_fill_price
                                     : touched_price;
                  break;
                 }

               const double previous_close = m_planner.ResolveObservedClose(symbol,
                                                                           fact.direction,
                                                                           shift + 1,
                                                                           setup_plan.trigger_touch_side,
                                                                           m_planner.ResolveSpreadEstimatePoints(symbol, shift + 1));
               const double current_close = m_planner.ResolveObservedClose(symbol,
                                                                          fact.direction,
                                                                          shift,
                                                                          setup_plan.trigger_touch_side,
                                                                          shift_spread_est_points);
               if(!m_planner.IsVirtualTriggerCross(fact.direction,
                                                   previous_close,
                                                   current_close,
                                                   setup_plan.trigger_price))
                  continue;

               fact.entered = true;
               fact.entry_shift = shift;
               fact.entry_time = MohyITime(symbol, m_execution_timeframe, shift);
               fact.entry_price = m_planner.ResolveExecutableClosePrice(symbol,
                                                                       fact.direction,
                                                                       shift,
                                                                       shift_spread_est_points);
               if(fact.entry_price <= 0.0)
                  fact.entry_price = current_close;
               break;
              }
           }

         if(fact.entered)
           {
            setup_plan.proposed_entry_price = fact.entry_price;
            if(setup_plan.expected_fill_price <= 0.0)
               setup_plan.expected_fill_price = fact.entry_price;
            fact.outcome = ResolvePostEntryOutcome(symbol,
                                                   fact.direction,
                                                   setup_plan,
                                                   fact.entry_shift,
                                                   fact.exit_shift,
                                                   fact.exit_time,
                                                   fact.exit_price);
            if(fact.outcome == MOHY_HIST_SETUP_OUTCOME_OPEN)
              {
               fact.exit_shift = 0;
               fact.exit_time = MohyITime(symbol, m_execution_timeframe, 0);
               fact.exit_price = MohyIClose(symbol, m_execution_timeframe, 0);
              }
           }
         else if(fact.outcome == MOHY_HIST_SETUP_OUTCOME_WAITING)
           {
            fact.exit_shift = 0;
            fact.exit_time = MohyITime(symbol, m_execution_timeframe, 0);
            fact.exit_price = fact.planned_entry_price;
           }

         fact.diagnostics = StringFormat("Plan=%d|Mode=%s|Init=%s|Outcome=%s|SetupShift=%d|Trigger=%.5f|ExpFill=%.5f|EntryShift=%d|ExitShift=%d",
                                         fact.linked_trade_setup_plan_index,
                                         (setup_plan.execution_mode == MOHY_ENTRY_REAL_PENDING_ORDER) ? "Pending" : "Virtual",
                                         MohyTradeSetupPlanStateToString(fact.initial_plan_state),
                                         MohyHistoricalTradeSetupOutcomeToString(fact.outcome),
                                         fact.setup_shift,
                                         setup_plan.trigger_price,
                                         setup_plan.expected_fill_price,
                                         fact.entry_shift,
                                         fact.exit_shift);

         ArrayResize(out_facts, fact_count + 1);
         out_facts[fact_count] = fact;
         fact_count++;
        }

      return fact_count;
     }
  };

#endif
