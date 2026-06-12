#ifndef __MOHY_CORE_BUILDERS_TRADE_SETUP_PLANNER_MQH__
#define __MOHY_CORE_BUILDERS_TRADE_SETUP_PLANNER_MQH__

#include <MOHY/Domain/Config.mqh>
#include <MOHY/Core/Domain/PriceActionContracts.mqh>
#include <MOHY/Core/Compat/TerminalSeries.mqh>

class CMohyTradeSetupPlanner
  {
private:
   StrategyConfig m_cfg;
   int            m_execution_timeframe;

   double Eps() const
     {
      return 1e-10;
     }

   int ResolveDigits(const string symbol) const
     {
      long digits = 0;
      if(!SymbolInfoInteger(symbol, SYMBOL_DIGITS, digits) || digits < 0)
         digits = _Digits;
      return (int)digits;
     }

   double ResolvePoint(const string symbol) const
     {
      double point = 0.0;
      if(!SymbolInfoDouble(symbol, SYMBOL_POINT, point) || point <= 0.0)
         point = _Point;
      return MathMax(Eps(), point);
     }

   double ResolveTickSize(const string symbol) const
     {
      double tick_size = 0.0;
      if(!SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE, tick_size) || tick_size <= 0.0)
         tick_size = ResolvePoint(symbol);
      return MathMax(Eps(), tick_size);
     }

   double NormalizePrice(const string symbol,
                         const double price) const
     {
      if(price <= 0.0)
         return 0.0;

      const double tick_size = ResolveTickSize(symbol);
      const int digits = ResolveDigits(symbol);
      const double normalized = MathRound(price / tick_size) * tick_size;
      return NormalizeDouble(normalized, digits);
     }

   double ResolveCurrentSpreadPoints(const string symbol,
                                     const double point) const
     {
      long spread_points = 0;
      if(SymbolInfoInteger(symbol, SYMBOL_SPREAD, spread_points) && spread_points >= 0)
         return (double)spread_points;

      double bid = 0.0;
      double ask = 0.0;
      if(SymbolInfoDouble(symbol, SYMBOL_BID, bid) &&
         SymbolInfoDouble(symbol, SYMBOL_ASK, ask) &&
         ask > bid + Eps())
         return MathMax(0.0, (ask - bid) / point);

      return 0.0;
     }

   double ResolveBrokerStopConstraintPoints(const string symbol) const
     {
      long stops_level = 0;
      long freeze_level = 0;
      SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL, stops_level);
      SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL, freeze_level);
      return MathMax(0.0, (double)MathMax(stops_level, freeze_level));
     }

   bool ResolveFibTarget(const MohyPotentialCorrectionFact &correction,
                         double &out_target_price) const
     {
      out_target_price = 0.0;
      const double correction_extreme = correction.end_price;
      const double impulse_extreme = correction.impulse_extreme_price;
      if(correction_extreme <= 0.0 || impulse_extreme <= 0.0)
         return false;

      if(correction.impulse_direction == MOHY_DIR_BULL)
        {
         out_target_price = impulse_extreme +
                            m_cfg.fib_target_level * (impulse_extreme - correction_extreme);
         return (out_target_price > impulse_extreme + Eps());
        }
      if(correction.impulse_direction == MOHY_DIR_BEAR)
        {
         out_target_price = impulse_extreme -
                            m_cfg.fib_target_level * (correction_extreme - impulse_extreme);
         return (out_target_price < impulse_extreme - Eps());
        }

      return false;
     }

   void AppendStopCandidate(const double candidate_price,
                            const int anchor_shift,
                            const MohyTradeSetupStopAnchorType anchor_type,
                            double &io_prices[],
                            int &io_shifts[],
                            MohyTradeSetupStopAnchorType &io_anchor_types[],
                            int &io_count) const
     {
      for(int i = 0; i < io_count; ++i)
        {
         if(MathAbs(io_prices[i] - candidate_price) <= Eps())
            return;
        }

      ArrayResize(io_prices, io_count + 1);
      ArrayResize(io_shifts, io_count + 1);
      ArrayResize(io_anchor_types, io_count + 1);
      io_prices[io_count] = candidate_price;
      io_shifts[io_count] = anchor_shift;
      io_anchor_types[io_count] = anchor_type;
      io_count++;
     }

   int CollectInnerStopCandidates(const string symbol,
                                  const MohyDirection direction,
                                  const MohyPotentialCorrectionFact &correction,
                                  const MohyPotentialContinuationSignalFact &signal,
                                  const MohyLegFact &execution_legs[],
                                  const double outer_stop_price,
                                  double &out_prices[],
                                  int &out_anchor_shifts[],
                                  MohyTradeSetupStopAnchorType &out_anchor_types[]) const
     {
      ArrayResize(out_prices, 0);
      ArrayResize(out_anchor_shifts, 0);
      ArrayResize(out_anchor_types, 0);

      const double point = ResolvePoint(symbol);
      const double buffer = MathMax(0.0, m_cfg.inner_sl_buffer_points) * point;
      const double broken_level_price = signal.broken_level_price;
      int count = 0;
      const int leg_count = ArraySize(execution_legs);
      for(int i = 0; i < leg_count; ++i)
        {
         const MohyLegFact leg = execution_legs[i];
         if(!leg.confirmed)
            continue;
         if(leg.end_shift < signal.signal_shift || leg.end_shift > correction.begin_shift)
            continue;

         if(direction == MOHY_DIR_BULL)
           {
            if(leg.direction != MOHY_DIR_BEAR || leg.end_price <= 0.0)
               continue;
            const double candidate_price = leg.end_price - buffer;
            if(candidate_price <= outer_stop_price + Eps())
               continue;
            if(broken_level_price > 0.0 && candidate_price >= broken_level_price - Eps())
               continue;
            AppendStopCandidate(candidate_price,
                                leg.end_shift,
                                MOHY_TRADE_SETUP_STOP_INNER_STRUCTURE,
                                out_prices,
                                out_anchor_shifts,
                                out_anchor_types,
                                count);
           }
         else if(direction == MOHY_DIR_BEAR)
           {
            if(leg.direction != MOHY_DIR_BULL || leg.end_price <= 0.0)
               continue;
            const double candidate_price = leg.end_price + buffer;
            if(candidate_price >= outer_stop_price - Eps())
               continue;
            if(broken_level_price > 0.0 && candidate_price <= broken_level_price + Eps())
               continue;
            AppendStopCandidate(candidate_price,
                                leg.end_shift,
                                MOHY_TRADE_SETUP_STOP_INNER_STRUCTURE,
                                out_prices,
                                out_anchor_shifts,
                                out_anchor_types,
                                count);
           }
        }

      for(int i = 0; i < count - 1; ++i)
        {
         int best = i;
         double best_distance = MathAbs(out_prices[i] - outer_stop_price);
         for(int j = i + 1; j < count; ++j)
           {
            const double distance = MathAbs(out_prices[j] - outer_stop_price);
            if(distance < best_distance - Eps() ||
               (MathAbs(distance - best_distance) <= Eps() && out_anchor_shifts[j] > out_anchor_shifts[best]))
              {
               best = j;
               best_distance = distance;
              }
           }

         if(best != i)
           {
            const double tmp_price = out_prices[i];
            out_prices[i] = out_prices[best];
            out_prices[best] = tmp_price;

            const int tmp_shift = out_anchor_shifts[i];
            out_anchor_shifts[i] = out_anchor_shifts[best];
            out_anchor_shifts[best] = tmp_shift;

            const MohyTradeSetupStopAnchorType tmp_anchor = out_anchor_types[i];
            out_anchor_types[i] = out_anchor_types[best];
            out_anchor_types[best] = tmp_anchor;
           }
        }

      return count;
     }

public:
            CMohyTradeSetupPlanner()
              {
               MohySetDefaultStrategyConfig(m_cfg);
               m_execution_timeframe = PERIOD_M15;
              }

   void     Configure(const StrategyConfig &cfg,
                      const int execution_timeframe)
     {
      m_cfg = cfg;
      m_execution_timeframe = execution_timeframe;
     }

   bool     IsPlanStateActionable(const MohyTradeSetupPlanState state) const
     {
      return (state == MOHY_TRADE_SETUP_PLAN_ELIGIBLE_NOW ||
              state == MOHY_TRADE_SETUP_PLAN_WAITING_FOR_PULLBACK);
     }

   double   ComputeRiskReward(const MohyDirection direction,
                              const double entry_price,
                              const double stop_price,
                              const double target_price) const
     {
      const double risk = (direction == MOHY_DIR_BULL)
                          ? (entry_price - stop_price)
                          : (stop_price - entry_price);
      const double reward = (direction == MOHY_DIR_BULL)
                            ? (target_price - entry_price)
                            : (entry_price - target_price);
      if(risk <= Eps() || reward <= Eps())
         return 0.0;
      return reward / risk;
     }

   bool     IsEntryPriceDirectionalValid(const MohyDirection direction,
                                         const double entry_price,
                                         const double stop_price,
                                         const double target_price) const
     {
      if(direction == MOHY_DIR_BULL)
         return (entry_price > stop_price + Eps() &&
                 target_price > entry_price + Eps());
      if(direction == MOHY_DIR_BEAR)
         return (entry_price < stop_price - Eps() &&
                 target_price < entry_price - Eps());
      return false;
     }

   bool     IsEntryAtOrBetterThanRequired(const MohyDirection direction,
                                          const double current_entry,
                                          const double required_entry) const
     {
      if(direction == MOHY_DIR_BULL)
         return (current_entry <= required_entry + Eps());
      if(direction == MOHY_DIR_BEAR)
         return (current_entry >= required_entry - Eps());
      return false;
     }

   bool     IsWaitingEntryBetterThanCurrent(const MohyDirection direction,
                                            const double current_entry,
                                            const double required_entry) const
     {
      if(direction == MOHY_DIR_BULL)
         return (required_entry < current_entry - Eps());
      if(direction == MOHY_DIR_BEAR)
         return (required_entry > current_entry + Eps());
      return false;
     }

   double   ResolveSpreadPointsAtShift(const string symbol,
                                       const int shift) const
     {
      if(symbol == "" || shift < 0)
         return 0.0;

      const double point = ResolvePoint(symbol);
      if(shift == 0)
         return ResolveCurrentSpreadPoints(symbol, point);

      const int spread_points = MohyISpread(symbol, m_execution_timeframe, shift);
      if(spread_points >= 0)
         return (double)spread_points;

      return ResolveCurrentSpreadPoints(symbol, point);
     }

   double   ResolveSpreadEstimatePoints(const string symbol,
                                        const int shift) const
     {
      if(symbol == "" || shift < 0)
         return 0.0;

      const double current_spread = MathMax(0.0, ResolveSpreadPointsAtShift(symbol, shift));
      const int period = MathMax(1, m_cfg.entry.spread_ema_period);
      const int bars = MohyIBars(symbol, m_execution_timeframe);
      if(bars <= 0)
         return current_spread;

      const int oldest_shift = MathMin(bars - 1, shift + period - 1);
      if(oldest_shift < shift)
         return current_spread;

      const double alpha = 2.0 / (period + 1.0);
      bool seeded = false;
      double ema = 0.0;
      for(int sample_shift = oldest_shift; sample_shift >= shift; --sample_shift)
        {
         const double sample = MathMax(0.0, ResolveSpreadPointsAtShift(symbol, sample_shift));
         if(!seeded)
           {
            ema = sample;
            seeded = true;
           }
         else
            ema = alpha * sample + (1.0 - alpha) * ema;
        }

      if(!seeded)
         return current_spread;
      return MathMax(current_spread, ema);
     }

   double   ResolveSlippageEstimatePoints(const double spread_est_points) const
     {
      return MathMax(MathMax(0.0, m_cfg.entry.fixed_slippage_points),
                     MathMax(0.0, m_cfg.entry.slippage_spread_multiplier) *
                     MathMax(0.0, spread_est_points));
     }

   double   ResolveCommissionEstimatePoints() const
     {
      return MathMax(0.0, m_cfg.entry.fixed_commission_points);
     }

   MohyTouchSide ResolveTriggerTouchSide(const MohyDirection direction) const
     {
      return (direction == MOHY_DIR_BEAR)
             ? m_cfg.entry.sell_trigger_touch_side
             : m_cfg.entry.buy_trigger_touch_side;
     }

   bool     TouchSideUsesAsk(const MohyDirection direction,
                             const MohyTouchSide side) const
     {
      if(side == MOHY_TOUCH_ASK)
         return true;
      if(side == MOHY_TOUCH_BID)
         return false;
      if(side == MOHY_TOUCH_LOW_COST)
         return (direction == MOHY_DIR_BULL);
      return (direction == MOHY_DIR_BULL);
     }

   double   ResolveTriggerPrice(const string symbol,
                                const MohyDirection direction,
                                const double required_entry_price,
                                const MohyTouchSide touch_side,
                                const double spread_est_points,
                                const double slippage_est_points,
                                const double commission_est_points) const
     {
      if(symbol == "" || required_entry_price <= 0.0)
         return 0.0;

      const double point = ResolvePoint(symbol);
      const double cost_points = MathMax(0.0, slippage_est_points) +
                                 MathMax(0.0, commission_est_points);
      double trigger_price = required_entry_price;
      if(direction == MOHY_DIR_BULL)
        {
         trigger_price = required_entry_price - cost_points * point;
         if(!TouchSideUsesAsk(direction, touch_side))
            trigger_price -= MathMax(0.0, spread_est_points) * point;
        }
      else if(direction == MOHY_DIR_BEAR)
        {
         trigger_price = required_entry_price + cost_points * point;
         if(TouchSideUsesAsk(direction, touch_side))
            trigger_price += MathMax(0.0, spread_est_points) * point;
        }
      else
         return 0.0;

      return NormalizePrice(symbol, trigger_price);
     }

   double   ResolveObservedClose(const string symbol,
                                 const MohyDirection direction,
                                 const int shift,
                                 const MohyTouchSide touch_side,
                                 const double spread_est_points) const
     {
      const double close_bid = MohyIClose(symbol, m_execution_timeframe, shift);
      if(close_bid <= 0.0)
         return 0.0;

      if(TouchSideUsesAsk(direction, touch_side))
         return close_bid + MathMax(0.0, spread_est_points) * ResolvePoint(symbol);
      return close_bid;
     }

   double   ResolveObservedClose(const string symbol,
                                 const MohyDirection direction,
                                 const int shift) const
     {
      return ResolveObservedClose(symbol,
                                  direction,
                                  shift,
                                  ResolveTriggerTouchSide(direction),
                                  ResolveSpreadEstimatePoints(symbol, shift));
     }

   double   ResolveExecutableClosePrice(const string symbol,
                                        const MohyDirection direction,
                                        const int shift,
                                        const double spread_est_points) const
     {
      const double close_bid = MohyIClose(symbol, m_execution_timeframe, shift);
      if(close_bid <= 0.0)
         return 0.0;

      if(direction == MOHY_DIR_BULL)
         return close_bid + MathMax(0.0, spread_est_points) * ResolvePoint(symbol);
      if(direction == MOHY_DIR_BEAR)
         return close_bid;
      return 0.0;
     }

   double   ResolveExecutableClosePrice(const string symbol,
                                        const MohyDirection direction,
                                        const int shift) const
     {
      return ResolveExecutableClosePrice(symbol,
                                         direction,
                                         shift,
                                         ResolveSpreadEstimatePoints(symbol, shift));
     }

   bool     IsVirtualTriggerCross(const MohyDirection direction,
                                  const double previous_close,
                                  const double current_close,
                                  const double trigger_price) const
     {
      if(previous_close <= 0.0 || current_close <= 0.0 || trigger_price <= 0.0)
         return false;
      if(direction == MOHY_DIR_BULL)
         return (previous_close > trigger_price + Eps() &&
                 current_close <= trigger_price + Eps());
      if(direction == MOHY_DIR_BEAR)
         return (previous_close < trigger_price - Eps() &&
                 current_close >= trigger_price - Eps());
      return false;
     }

   bool     IsPendingTriggerTouched(const string symbol,
                                    const MohyDirection direction,
                                    const double trigger_price,
                                    const int shift,
                                    const MohyTouchSide touch_side,
                                    const double spread_est_points,
                                    double &out_fill_price) const
     {
      out_fill_price = 0.0;
      if(symbol == "" || trigger_price <= 0.0 || shift < 0)
         return false;

      const double high_bid = MohyIHigh(symbol, m_execution_timeframe, shift);
      const double low_bid = MohyILow(symbol, m_execution_timeframe, shift);
      if(high_bid <= 0.0 || low_bid <= 0.0)
         return false;

      double high_price = high_bid;
      double low_price = low_bid;
      if(TouchSideUsesAsk(direction, touch_side))
        {
         const double spread_price = MathMax(0.0, spread_est_points) * ResolvePoint(symbol);
         high_price += spread_price;
         low_price += spread_price;
        }

      if(direction == MOHY_DIR_BULL)
        {
         if(low_price <= trigger_price + Eps())
           {
            out_fill_price = trigger_price;
            return true;
           }
         return false;
        }
      if(direction == MOHY_DIR_BEAR)
        {
         if(high_price >= trigger_price - Eps())
           {
            out_fill_price = trigger_price;
            return true;
           }
         return false;
        }
      return false;
     }

   bool     IsPendingTriggerTouched(const string symbol,
                                    const MohyDirection direction,
                                    const double trigger_price,
                                    const int shift,
                                    double &out_fill_price) const
     {
      return IsPendingTriggerTouched(symbol,
                                     direction,
                                     trigger_price,
                                     shift,
                                     ResolveTriggerTouchSide(direction),
                                     ResolveSpreadEstimatePoints(symbol, shift),
                                     out_fill_price);
     }

   bool     IsPreEntryInvalidatedAtShift(const string symbol,
                                         const MohyDirection direction,
                                         const MohyPotentialCorrectionFact &correction,
                                         const int shift,
                                         double &out_invalidated_price) const
     {
      out_invalidated_price = 0.0;
      if(shift < 0 || correction.impulse_extreme_price <= 0.0)
         return false;

      const double point = ResolvePoint(symbol);
      const double buffer = MathMax(0.0, m_cfg.entry.pre_entry_invalidation_buffer_points) * point;
      const double threshold = correction.impulse_extreme_price;

      if(m_cfg.entry.pre_entry_invalidation_mode == MOHY_PRE_ENTRY_INVALIDATE_CLOSE_BEYOND)
        {
         const double close_price = MohyIClose(symbol, m_execution_timeframe, shift);
         if(direction == MOHY_DIR_BULL && close_price >= threshold + buffer - Eps())
           {
            out_invalidated_price = close_price;
            return true;
           }
         if(direction == MOHY_DIR_BEAR && close_price <= threshold - buffer + Eps())
           {
            out_invalidated_price = close_price;
            return true;
           }
         return false;
        }

      const double high_price = MohyIHigh(symbol, m_execution_timeframe, shift);
      const double low_price = MohyILow(symbol, m_execution_timeframe, shift);
      if(direction == MOHY_DIR_BULL && high_price >= threshold + buffer - Eps())
        {
         out_invalidated_price = threshold + buffer;
         return true;
        }
      if(direction == MOHY_DIR_BEAR && low_price <= threshold - buffer + Eps())
        {
         out_invalidated_price = threshold - buffer;
         return true;
        }
      return false;
     }

   bool     FindPreEntryInvalidation(const string symbol,
                                     const MohyDirection direction,
                                     const MohyPotentialCorrectionFact &correction,
                                     const int newest_shift,
                                     const int oldest_shift,
                                     int &out_invalidated_shift,
                                     datetime &out_invalidated_time,
                                     double &out_invalidated_price) const
     {
      out_invalidated_shift = -1;
      out_invalidated_time = 0;
      out_invalidated_price = 0.0;

      if(symbol == "" || newest_shift < 0 || oldest_shift < 0 || newest_shift > oldest_shift)
         return false;

      for(int shift = oldest_shift; shift >= newest_shift; --shift)
        {
         double invalidated_price = 0.0;
         if(!IsPreEntryInvalidatedAtShift(symbol,
                                          direction,
                                          correction,
                                          shift,
                                          invalidated_price))
            continue;

         out_invalidated_shift = shift;
         out_invalidated_time = MohyITime(symbol, m_execution_timeframe, shift);
         out_invalidated_price = invalidated_price;
         return true;
        }

      return false;
     }

   bool     BuildPlan(const string symbol,
                      const MohyLegFact &execution_legs[],
                      const MohyPotentialCorrectionFact &correction,
                      const MohyPotentialContinuationSignalFact &signal,
                      const double current_executable_price,
                      const int pricing_shift,
                      const double spread_points,
                      const bool spread_pass,
                      MohyTradeSetupPlanFact &out_fact) const
     {
      out_fact.index = -1;
      out_fact.valid = true;
      out_fact.linked_potential_continuation_signal_index = signal.index;
      out_fact.linked_potential_correction_index = signal.linked_potential_correction_index;
      out_fact.linked_potential_impulse_index = signal.linked_potential_impulse_index;
      out_fact.linked_potential_impulse_swing3_index = signal.linked_potential_impulse_swing3_index;
      out_fact.linked_correction_recency_rank = signal.linked_correction_recency_rank;
      out_fact.linked_correction_is_active = signal.linked_correction_is_active;
      out_fact.direction = signal.direction;
      out_fact.plan_state = MOHY_TRADE_SETUP_PLAN_INELIGIBLE;
      out_fact.reject_reason = MOHY_REJECT_INVALID_PLAN;
      out_fact.execution_mode = m_cfg.entry.execution_mode;
      out_fact.setup_shift = MathMax(0, signal.signal_shift - 1);
      out_fact.setup_time = MohyITime(symbol, m_execution_timeframe, out_fact.setup_shift);
      if(out_fact.setup_time <= 0)
         out_fact.setup_time = signal.signal_time;
      out_fact.post_be_profile = m_cfg.management.post_be_profile;
      out_fact.current_executable_price = NormalizePrice(symbol, current_executable_price);
      out_fact.proposed_entry_price = 0.0;
      out_fact.expected_fill_price = 0.0;
      out_fact.required_entry_price = 0.0;
      out_fact.trigger_price = 0.0;
      out_fact.stop_price = 0.0;
      out_fact.target_price = 0.0;
      out_fact.reward_to_risk = 0.0;
      out_fact.min_rr = m_cfg.entry.min_rr;
      out_fact.rr_tolerance = m_cfg.entry.rr_tolerance;
      out_fact.trigger_touch_side = ResolveTriggerTouchSide(signal.direction);
      out_fact.recheck_mode = m_cfg.entry.recheck_mode;
      out_fact.adjust_cadence = m_cfg.entry.adjust_cadence;
      out_fact.adjust_min_seconds = MathMax(0, m_cfg.entry.adjust_min_seconds);
      out_fact.recheck_rr_at_trigger = m_cfg.entry.recheck_rr_at_trigger;
      out_fact.spread_est_points = ResolveSpreadEstimatePoints(symbol, MathMax(0, pricing_shift));
      out_fact.slippage_est_points = ResolveSlippageEstimatePoints(out_fact.spread_est_points);
      out_fact.commission_est_points = ResolveCommissionEstimatePoints();
      out_fact.total_entry_cost_points = out_fact.slippage_est_points + out_fact.commission_est_points;
      out_fact.min_trigger_move_points = MathMax(0.0, m_cfg.entry.min_trigger_move_points);
      out_fact.trigger_freeze_enabled = m_cfg.entry.enable_trigger_freeze;
      out_fact.trigger_freeze_points = out_fact.trigger_freeze_enabled
                                      ? MathMax(0.0, m_cfg.entry.freeze_spread_multiplier) *
                                        out_fact.spread_est_points
                                      : 0.0;
      out_fact.pending_auto_modify_enabled = m_cfg.entry.enable_pending_auto_modify;
      out_fact.risk_distance_points = 0.0;
      out_fact.risk_money = 0.0;
      out_fact.lots_raw = 0.0;
      out_fact.lots_normalized = 0.0;
      out_fact.spread_points = MathMax(0.0, spread_points);
      out_fact.spread_pass = spread_pass;
      out_fact.exposure_pass = false;
      out_fact.stop_anchor_type = MOHY_TRADE_SETUP_STOP_UNKNOWN;
      out_fact.target_anchor_type = MOHY_TRADE_SETUP_TARGET_UNKNOWN;
      out_fact.stop_anchor_shift = -1;
      out_fact.target_anchor_shift = -1;
      out_fact.selection_rank = -1;
      out_fact.is_selected = false;
      out_fact.diagnostics = "";

      if(symbol == "" || out_fact.current_executable_price <= 0.0)
        {
         out_fact.reject_reason = MOHY_REJECT_INVALID_PLAN;
         out_fact.diagnostics = "ExecutablePriceInvalid";
         return true;
        }

      const double point = ResolvePoint(symbol);
      const double configured_min_stop_points = MathMax(0.0, m_cfg.entry.min_stop_distance_points);
      const double broker_min_stop_points = ResolveBrokerStopConstraintPoints(symbol);
      const double required_min_stop_points = MathMax(configured_min_stop_points, broker_min_stop_points);
      const double outer_buffer = MathMax(0.0, m_cfg.outer_sl_buffer_points) * point;
      const double outer_stop_price = (signal.direction == MOHY_DIR_BULL)
                                      ? (correction.end_price - outer_buffer)
                                      : (correction.end_price + outer_buffer);
      if(outer_stop_price <= 0.0)
        {
         out_fact.reject_reason = MOHY_REJECT_STOP_DISTANCE_INVALID;
         out_fact.diagnostics = "OuterStopInvalid";
         return true;
        }

      double inner_stop_prices[];
      int inner_stop_anchor_shifts[];
      MohyTradeSetupStopAnchorType inner_stop_anchor_types[];
      const int inner_stop_count = CollectInnerStopCandidates(symbol,
                                                              signal.direction,
                                                              correction,
                                                              signal,
                                                              execution_legs,
                                                              outer_stop_price,
                                                              inner_stop_prices,
                                                              inner_stop_anchor_shifts,
                                                              inner_stop_anchor_types);

      double candidate_stop_prices[];
      int candidate_stop_anchor_shifts[];
      MohyTradeSetupStopAnchorType candidate_stop_anchor_types[];
      ArrayResize(candidate_stop_prices, 0);
      ArrayResize(candidate_stop_anchor_shifts, 0);
      ArrayResize(candidate_stop_anchor_types, 0);
      int candidate_count = 0;

      if(m_cfg.sl_mode == MOHY_SL_OUTER_CORRECTION_EXTREME || m_cfg.sl_mode == MOHY_SL_AUTO)
         AppendStopCandidate(outer_stop_price,
                             correction.end_shift,
                             MOHY_TRADE_SETUP_STOP_OUTER_CORRECTION_EXTREME,
                             candidate_stop_prices,
                             candidate_stop_anchor_shifts,
                             candidate_stop_anchor_types,
                             candidate_count);

      if(m_cfg.sl_mode == MOHY_SL_INNER_STRUCTURE)
        {
         const int idx = MathMax(0, m_cfg.inner_stop_swing_index - 1);
         if(idx < inner_stop_count)
            AppendStopCandidate(inner_stop_prices[idx],
                                inner_stop_anchor_shifts[idx],
                                inner_stop_anchor_types[idx],
                                candidate_stop_prices,
                                candidate_stop_anchor_shifts,
                                candidate_stop_anchor_types,
                                candidate_count);
        }
      else if(m_cfg.sl_mode == MOHY_SL_AUTO)
        {
         for(int inner_i = 0; inner_i < inner_stop_count; ++inner_i)
            AppendStopCandidate(inner_stop_prices[inner_i],
                                inner_stop_anchor_shifts[inner_i],
                                inner_stop_anchor_types[inner_i],
                                candidate_stop_prices,
                                candidate_stop_anchor_shifts,
                                candidate_stop_anchor_types,
                                candidate_count);
        }

      if(candidate_count <= 0)
        {
         out_fact.reject_reason = MOHY_REJECT_STOP_DISTANCE_INVALID;
         out_fact.diagnostics = "NoStopCandidate";
         return true;
        }

      bool selected = false;
      for(int candidate_i = 0; candidate_i < candidate_count; ++candidate_i)
        {
         MohyTradeSetupPlanFact candidate_fact = out_fact;
         candidate_fact.stop_price = NormalizePrice(symbol, candidate_stop_prices[candidate_i]);
         candidate_fact.stop_anchor_type = candidate_stop_anchor_types[candidate_i];
         candidate_fact.stop_anchor_shift = candidate_stop_anchor_shifts[candidate_i];

         if(m_cfg.tp_mode == MOHY_TP_FIB_NEG_EXTENSION)
           {
            double target_price = 0.0;
            if(!ResolveFibTarget(correction, target_price))
               continue;

            candidate_fact.target_price = NormalizePrice(symbol, target_price);
            candidate_fact.target_anchor_type = MOHY_TRADE_SETUP_TARGET_FIB_NEG_EXTENSION;
            candidate_fact.target_anchor_shift = correction.end_shift;
            candidate_fact.required_entry_price = NormalizePrice(symbol,
                                                                 (candidate_fact.target_price +
                                                                  m_cfg.entry.min_rr * candidate_fact.stop_price) /
                                                                 (1.0 + m_cfg.entry.min_rr));
            candidate_fact.expected_fill_price = candidate_fact.required_entry_price;
            candidate_fact.trigger_price = ResolveTriggerPrice(symbol,
                                                               signal.direction,
                                                               candidate_fact.required_entry_price,
                                                               candidate_fact.trigger_touch_side,
                                                               candidate_fact.spread_est_points,
                                                               candidate_fact.slippage_est_points,
                                                               candidate_fact.commission_est_points);
            candidate_fact.proposed_entry_price = candidate_fact.trigger_price;

            if(!IsEntryPriceDirectionalValid(signal.direction,
                                             candidate_fact.expected_fill_price,
                                             candidate_fact.stop_price,
                                             candidate_fact.target_price))
               continue;

            if(IsEntryAtOrBetterThanRequired(signal.direction,
                                             candidate_fact.current_executable_price,
                                             candidate_fact.required_entry_price))
              {
               candidate_fact.expected_fill_price = candidate_fact.current_executable_price;
               candidate_fact.trigger_price = candidate_fact.current_executable_price;
               candidate_fact.proposed_entry_price = candidate_fact.current_executable_price;
               candidate_fact.plan_state = spread_pass
                                           ? MOHY_TRADE_SETUP_PLAN_ELIGIBLE_NOW
                                           : MOHY_TRADE_SETUP_PLAN_INELIGIBLE;
               candidate_fact.reject_reason = spread_pass ? MOHY_REJECT_NONE : MOHY_REJECT_SPREAD_FILTER_FAILED;
              }
            else if(IsWaitingEntryBetterThanCurrent(signal.direction,
                                                    candidate_fact.current_executable_price,
                                                    candidate_fact.required_entry_price))
              {
               if(candidate_fact.trigger_price <= 0.0)
                  continue;
               candidate_fact.plan_state = MOHY_TRADE_SETUP_PLAN_WAITING_FOR_PULLBACK;
               candidate_fact.reject_reason = MOHY_REJECT_NONE;
              }
            else
               candidate_fact.reject_reason = MOHY_REJECT_MIN_RR_NOT_SATISFIED;
           }
         else
           {
            const double target_rr = MathMax(0.0, m_cfg.target_rr);
            const double risk_distance = MathAbs(candidate_fact.current_executable_price -
                                                 candidate_fact.stop_price);
            if(risk_distance <= Eps())
               continue;

            candidate_fact.expected_fill_price = candidate_fact.current_executable_price;
            candidate_fact.proposed_entry_price = candidate_fact.current_executable_price;
            candidate_fact.required_entry_price = candidate_fact.current_executable_price;
            candidate_fact.trigger_price = candidate_fact.current_executable_price;
            candidate_fact.target_price = NormalizePrice(symbol,
                                                         (signal.direction == MOHY_DIR_BULL)
                                                         ? (candidate_fact.expected_fill_price +
                                                            target_rr * risk_distance)
                                                         : (candidate_fact.expected_fill_price -
                                                            target_rr * risk_distance));
            candidate_fact.target_anchor_type = MOHY_TRADE_SETUP_TARGET_RISK_REWARD;
            candidate_fact.target_anchor_shift = signal.signal_shift;

            if(!IsEntryPriceDirectionalValid(signal.direction,
                                             candidate_fact.expected_fill_price,
                                             candidate_fact.stop_price,
                                             candidate_fact.target_price))
               continue;

            if(target_rr + m_cfg.entry.rr_tolerance >= m_cfg.entry.min_rr)
              {
               candidate_fact.plan_state = spread_pass
                                           ? MOHY_TRADE_SETUP_PLAN_ELIGIBLE_NOW
                                           : MOHY_TRADE_SETUP_PLAN_INELIGIBLE;
               candidate_fact.reject_reason = spread_pass ? MOHY_REJECT_NONE : MOHY_REJECT_SPREAD_FILTER_FAILED;
              }
            else
               candidate_fact.reject_reason = MOHY_REJECT_MIN_RR_NOT_SATISFIED;
           }

         candidate_fact.reward_to_risk = ComputeRiskReward(signal.direction,
                                                           candidate_fact.expected_fill_price,
                                                           candidate_fact.stop_price,
                                                           candidate_fact.target_price);
         candidate_fact.risk_distance_points = MathAbs(candidate_fact.expected_fill_price -
                                                       candidate_fact.stop_price) / point;
         if(candidate_fact.risk_distance_points + Eps() < required_min_stop_points)
           {
            candidate_fact.plan_state = MOHY_TRADE_SETUP_PLAN_INELIGIBLE;
            candidate_fact.reject_reason = MOHY_REJECT_STOP_DISTANCE_INVALID;
           }

         candidate_fact.diagnostics = StringFormat("State=%s|Stop=%s|Target=%s|RR=%.4f|CurExec=%.5f|ReqExec=%.5f|ExpFill=%.5f|Trigger=%.5f|Touch=%s|Spread=%.1f|SpreadEst=%.1f|SlipEst=%.1f|CommPts=%.1f|CostPts=%.1f|StopPts=%.1f|MinStopCfg=%.1f|MinStopBroker=%.1f|MinStopReq=%.1f|Recheck=%s|Cadence=%s|Freeze=%.1f|SpreadPass=%s",
                                                   MohyTradeSetupPlanStateToString(candidate_fact.plan_state),
                                                   MohyTradeSetupStopAnchorTypeToString(candidate_fact.stop_anchor_type),
                                                   MohyTradeSetupTargetAnchorTypeToString(candidate_fact.target_anchor_type),
                                                   candidate_fact.reward_to_risk,
                                                   candidate_fact.current_executable_price,
                                                   candidate_fact.required_entry_price,
                                                   candidate_fact.expected_fill_price,
                                                   candidate_fact.trigger_price,
                                                   MohyTouchSideToString(candidate_fact.trigger_touch_side),
                                                   candidate_fact.spread_points,
                                                   candidate_fact.spread_est_points,
                                                   candidate_fact.slippage_est_points,
                                                   candidate_fact.commission_est_points,
                                                   candidate_fact.total_entry_cost_points,
                                                   candidate_fact.risk_distance_points,
                                                   configured_min_stop_points,
                                                   broker_min_stop_points,
                                                   required_min_stop_points,
                                                   MohyRecheckModeToString(candidate_fact.recheck_mode),
                                                   MohyAdjustCadenceToString(candidate_fact.adjust_cadence),
                                                   candidate_fact.trigger_freeze_points,
                                                   candidate_fact.spread_pass ? "Yes" : "No");

         if(candidate_fact.plan_state == MOHY_TRADE_SETUP_PLAN_ELIGIBLE_NOW ||
            candidate_fact.plan_state == MOHY_TRADE_SETUP_PLAN_WAITING_FOR_PULLBACK ||
            !selected)
           {
            out_fact = candidate_fact;
            selected = true;
            if(m_cfg.sl_mode == MOHY_SL_AUTO && IsPlanStateActionable(candidate_fact.plan_state))
               break;
           }
        }

      if(!selected)
        {
         out_fact.reject_reason = MOHY_REJECT_INVALID_PLAN;
         out_fact.diagnostics = "NoFeasibleCandidate";
        }

      return true;
     }
  };

#endif
