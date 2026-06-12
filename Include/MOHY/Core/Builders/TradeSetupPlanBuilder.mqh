#ifndef __MOHY_CORE_BUILDERS_TRADE_SETUP_PLAN_BUILDER_MQH__
#define __MOHY_CORE_BUILDERS_TRADE_SETUP_PLAN_BUILDER_MQH__

#include <MOHY/Domain/Config.mqh>
#include <MOHY/Core/Domain/PriceActionContracts.mqh>
#include <MOHY/Core/Compat/TerminalSeries.mqh>
#include <MOHY/Core/Builders/TradeSetupPlanner.mqh>

class CMohyTradeSetupPlanBuilder
  {
private:
   StrategyConfig          m_cfg;
   int                     m_timeframe;
   int                     m_execution_timeframe;
   CMohyTradeSetupPlanner  m_planner;

   double Eps() const
     {
      return 1e-10;
     }

   double ResolvePoint(const string symbol) const
     {
      double point = 0.0;
      if(!SymbolInfoDouble(symbol, SYMBOL_POINT, point) || point <= 0.0)
         point = _Point;
      return MathMax(Eps(), point);
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
         return (ask - bid) / point;

      return 0.0;
     }

   double ResolveCurrentBid(const string symbol) const
     {
      double bid = 0.0;
      if(SymbolInfoDouble(symbol, SYMBOL_BID, bid) && bid > 0.0)
         return bid;
      bid = MohyIClose(symbol, m_execution_timeframe, 0);
      if(bid > 0.0)
         return bid;
      return 0.0;
     }

   double ResolveCurrentAsk(const string symbol,
                            const double bid,
                            const double spread_points,
                            const double point) const
     {
      double ask = 0.0;
      if(SymbolInfoDouble(symbol, SYMBOL_ASK, ask) && ask > 0.0)
         return ask;
      if(bid > 0.0)
         return bid + spread_points * point;
      return 0.0;
     }

   double ResolveMoneyPerLot(const string symbol,
                             const double entry_price,
                             const double stop_price) const
     {
      const double distance = MathAbs(entry_price - stop_price);
      if(distance <= Eps())
         return 0.0;

      double tick_size = 0.0;
      double tick_value = 0.0;
      if(!SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE, tick_size) || tick_size <= 0.0)
         tick_size = ResolvePoint(symbol);
      if(!SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE, tick_value) || tick_value <= 0.0)
         tick_value = 0.0;
      if(tick_size <= Eps() || tick_value <= Eps())
         return 0.0;

      return (distance / tick_size) * tick_value;
     }

   bool IsTrackedOpenPosition() const
     {
      if(m_cfg.risk.magic_number <= 0)
         return true;

      const long magic = PositionGetInteger(POSITION_MAGIC);
      return (magic == (long)m_cfg.risk.magic_number);
     }

   double ResolveOpenPositionWorstCaseStopRiskMoney() const
     {
      double open_risk_money = 0.0;
      const int total = PositionsTotal();
      for(int i = 0; i < total; ++i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(!IsTrackedOpenPosition())
            continue;

         const string symbol = PositionGetString(POSITION_SYMBOL);
         const long type = PositionGetInteger(POSITION_TYPE);
         const double volume = PositionGetDouble(POSITION_VOLUME);
         const double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
         const double stop_price = PositionGetDouble(POSITION_SL);
         if(symbol == "" || volume <= Eps() || entry_price <= 0.0 || stop_price <= 0.0)
            continue;

         double effective_stop = 0.0;
         if(type == POSITION_TYPE_BUY)
           {
            if(stop_price >= entry_price - Eps())
               continue;
            effective_stop = stop_price;
           }
         else if(type == POSITION_TYPE_SELL)
           {
            if(stop_price <= entry_price + Eps())
               continue;
            effective_stop = stop_price;
           }
         else
            continue;

         const double money_per_lot = ResolveMoneyPerLot(symbol, entry_price, effective_stop);
         if(money_per_lot <= Eps())
            continue;

         open_risk_money += money_per_lot * volume;
        }

      return open_risk_money;
     }

   double ResolveRiskBaseAmount(const MohyRiskBase risk_base,
                                const double open_risk_money) const
     {
      if(risk_base == MOHY_RISK_BASE_EQUITY)
         return AccountInfoDouble(ACCOUNT_EQUITY);
      if(risk_base == MOHY_RISK_BASE_BALANCE)
         return AccountInfoDouble(ACCOUNT_BALANCE);
      return MathMax(0.0, AccountInfoDouble(ACCOUNT_BALANCE) - open_risk_money);
     }

   double ResolveExposureBaseAmount(const MohyExposureBase exposure_base,
                                    const double open_risk_money) const
     {
      if(exposure_base == MOHY_EXPOSURE_BASE_EQUITY)
         return AccountInfoDouble(ACCOUNT_EQUITY);
      if(exposure_base == MOHY_EXPOSURE_BASE_BALANCE)
         return AccountInfoDouble(ACCOUNT_BALANCE);
      return MathMax(0.0, AccountInfoDouble(ACCOUNT_BALANCE) - open_risk_money);
     }

   double NormalizeLotsDown(const string symbol,
                            const double lots_raw) const
     {
      double volume_min = 0.0;
      double volume_max = 0.0;
      double volume_step = 0.0;
      if(!SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN, volume_min) || volume_min <= 0.0)
         volume_min = 0.01;
      if(!SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX, volume_max) || volume_max <= 0.0)
         volume_max = volume_min;
      if(!SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP, volume_step) || volume_step <= 0.0)
         volume_step = volume_min;

      double normalized = MathFloor(lots_raw / volume_step + Eps()) * volume_step;
      normalized = MathMin(volume_max, normalized);
      if(normalized < volume_min - Eps())
         return 0.0;
      return normalized;
     }

   void ResolveLots(const string symbol,
                    const double entry_price,
                    const double stop_price,
                    const double open_risk_money,
                    double &out_risk_money,
                    double &out_lots_raw,
                    double &out_lots_normalized) const
     {
      out_risk_money = 0.0;
      out_lots_raw = 0.0;
      out_lots_normalized = 0.0;

      const double base_amount = ResolveRiskBaseAmount(m_cfg.risk.risk_base, open_risk_money);
      if(base_amount <= 0.0 || m_cfg.risk.risk_percent <= 0.0)
         return;

      const double money_per_lot = ResolveMoneyPerLot(symbol, entry_price, stop_price);
      if(money_per_lot <= Eps())
         return;

      const double risk_budget_money = base_amount * (m_cfg.risk.risk_percent / 100.0);
      if(risk_budget_money <= Eps())
         return;

      out_lots_raw = risk_budget_money / money_per_lot;
      out_lots_normalized = NormalizeLotsDown(symbol, out_lots_raw);
      if(out_lots_normalized <= Eps())
         return;

      out_risk_money = out_lots_normalized * money_per_lot;
     }

   bool ResolveExposurePass(const double open_risk_money,
                            const double candidate_risk_money) const
     {
      if(m_cfg.risk.max_concurrent_risk_percent <= 0.0)
         return false;

      const double exposure_base_amount = ResolveExposureBaseAmount(m_cfg.risk.exposure_base, open_risk_money);
      if(exposure_base_amount <= Eps())
         return false;

      const double max_allowed_risk_money = exposure_base_amount * (m_cfg.risk.max_concurrent_risk_percent / 100.0);
      if(max_allowed_risk_money <= Eps())
         return false;

      return (open_risk_money + candidate_risk_money <= max_allowed_risk_money + Eps());
     }

   int StateSelectionScore(const MohyTradeSetupPlanState state) const
     {
      if(state == MOHY_TRADE_SETUP_PLAN_ELIGIBLE_NOW)
         return 0;
      if(state == MOHY_TRADE_SETUP_PLAN_WAITING_FOR_PULLBACK)
         return 1;
      if(state == MOHY_TRADE_SETUP_PLAN_INELIGIBLE)
         return 2;
      if(state == MOHY_TRADE_SETUP_PLAN_INVALIDATED)
         return 3;
      return 4;
     }

   bool IsPlanPreferredForSelection(const MohyTradeSetupPlanFact &candidate,
                                    const MohyTradeSetupPlanFact &best) const
     {
      if(candidate.linked_correction_is_active != best.linked_correction_is_active)
         return candidate.linked_correction_is_active;

      if(candidate.linked_correction_recency_rank != best.linked_correction_recency_rank)
         return (candidate.linked_correction_recency_rank < best.linked_correction_recency_rank);

      const int candidate_score = StateSelectionScore(candidate.plan_state);
      const int best_score = StateSelectionScore(best.plan_state);
      if(candidate_score != best_score)
         return (candidate_score < best_score);

      if(candidate.linked_potential_continuation_signal_index != best.linked_potential_continuation_signal_index)
         return (candidate.linked_potential_continuation_signal_index >
                 best.linked_potential_continuation_signal_index);

      return (candidate.index > best.index);
     }

   void PopulateSelectionFacts(MohyTradeSetupPlanFact &io_facts[]) const
     {
      const int count = ArraySize(io_facts);
      for(int i = 0; i < count; ++i)
        {
         io_facts[i].selection_rank = -1;
         io_facts[i].is_selected = false;
        }

      int selected_index = -1;
      for(int i = 0; i < count; ++i)
        {
         if(!io_facts[i].valid)
            continue;
         if(selected_index < 0 || IsPlanPreferredForSelection(io_facts[i], io_facts[selected_index]))
            selected_index = i;
        }

      for(int i = 0; i < count; ++i)
        {
         if(!io_facts[i].valid)
            continue;

         int better_count = 0;
         for(int j = 0; j < count; ++j)
           {
            if(i == j || !io_facts[j].valid)
               continue;
            if(IsPlanPreferredForSelection(io_facts[j], io_facts[i]))
               better_count++;
           }
         io_facts[i].selection_rank = better_count;
        }

      if(selected_index >= 0 && selected_index < count)
         io_facts[selected_index].is_selected = true;
     }

public:
            CMohyTradeSetupPlanBuilder()
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
                  const MohyPotentialCorrectionFact &potential_corrections[],
                  const MohyPotentialContinuationSignalFact &continuation_signals[],
                  MohyTradeSetupPlanFact &out_facts[]) const
     {
      ArrayResize(out_facts, 0);

      if(symbol == "")
         return 0;
      if(m_timeframe != m_execution_timeframe)
         return 0;
      if(ArraySize(continuation_signals) <= 0 || ArraySize(potential_corrections) <= 0)
         return 0;

      const double point = ResolvePoint(symbol);
      const double spread_points = ResolveCurrentSpreadPoints(symbol, point);
      const double current_bid = ResolveCurrentBid(symbol);
      const double current_ask = ResolveCurrentAsk(symbol, current_bid, spread_points, point);
      const double open_risk_money = ResolveOpenPositionWorstCaseStopRiskMoney();
      const bool spread_pass = (!m_cfg.entry.enable_spread_filter ||
                                spread_points <= m_cfg.entry.max_spread_points + Eps());

      const int signal_count = ArraySize(continuation_signals);
      ArrayResize(out_facts, signal_count);
      int fact_count = 0;
      for(int i = 0; i < signal_count; ++i)
        {
         const MohyPotentialContinuationSignalFact signal = continuation_signals[i];
         if(!signal.valid)
            continue;
         if(signal.linked_potential_correction_index < 0 ||
            signal.linked_potential_correction_index >= ArraySize(potential_corrections))
            continue;

         const MohyPotentialCorrectionFact correction =
            potential_corrections[signal.linked_potential_correction_index];
         const double executable_price = (signal.direction == MOHY_DIR_BULL) ? current_ask : current_bid;

         MohyTradeSetupPlanFact fact;
         if(!m_planner.BuildPlan(symbol,
                                 execution_legs,
                                 correction,
                                 signal,
                                 executable_price,
                                 0,
                                 spread_points,
                                 spread_pass,
                                 fact))
            continue;

         fact.index = fact_count;

         if(correction.state == MOHY_POT_CORR_STATE_INVALIDATED ||
            signal.linked_correction_state == MOHY_POT_CORR_STATE_INVALIDATED)
           {
            fact.plan_state = MOHY_TRADE_SETUP_PLAN_INVALIDATED;
            fact.reject_reason = MOHY_REJECT_PRE_ENTRY_INVALIDATED;
            fact.diagnostics = "CorrectionInvalidated";
            out_facts[fact_count++] = fact;
            continue;
           }

         const int oldest_scan_shift = MathMax(0, signal.signal_shift - 1);
         if(signal.signal_shift > 0 && m_planner.IsPlanStateActionable(fact.plan_state))
           {
            int invalidated_shift = -1;
            datetime invalidated_time = 0;
            double invalidated_price = 0.0;
            if(m_planner.FindPreEntryInvalidation(symbol,
                                                  signal.direction,
                                                  correction,
                                                  0,
                                                  oldest_scan_shift,
                                                  invalidated_shift,
                                                  invalidated_time,
                                                  invalidated_price))
              {
               fact.plan_state = MOHY_TRADE_SETUP_PLAN_INVALIDATED;
               fact.reject_reason = MOHY_REJECT_PRE_ENTRY_INVALIDATED;
               fact.diagnostics = StringFormat("PreEntryInvalidated|Shift=%d|Time=%I64d|Price=%.5f",
                                               invalidated_shift,
                                               invalidated_time,
                                               invalidated_price);
               out_facts[fact_count++] = fact;
               continue;
              }
           }

         if(m_planner.IsPlanStateActionable(fact.plan_state))
           {
            const double risk_entry_price = (fact.expected_fill_price > 0.0)
                                            ? fact.expected_fill_price
                                            : fact.proposed_entry_price;
            ResolveLots(symbol,
                        risk_entry_price,
                        fact.stop_price,
                        open_risk_money,
                        fact.risk_money,
                        fact.lots_raw,
                        fact.lots_normalized);

            if(fact.lots_normalized <= 0.0)
              {
               fact.plan_state = MOHY_TRADE_SETUP_PLAN_INELIGIBLE;
               fact.reject_reason = MOHY_REJECT_LOT_NORMALIZATION_FAILED;
              }

            fact.exposure_pass = ResolveExposurePass(open_risk_money, fact.risk_money);
            if(!fact.exposure_pass)
              {
               fact.plan_state = MOHY_TRADE_SETUP_PLAN_INELIGIBLE;
               fact.reject_reason = MOHY_REJECT_EXPOSURE_LIMIT_EXCEEDED;
              }
           }

         fact.diagnostics = StringFormat("%s|Mode=%s|Touch=%s|Trigger=%.5f|ExpFill=%.5f|Recheck=%s|Cadence=%s|ExposurePass=%s|OpenRisk=%.2f|PlanRisk=%.2f|Lots=%.2f",
                                         fact.diagnostics,
                                         (fact.execution_mode == MOHY_ENTRY_REAL_PENDING_ORDER) ? "Pending" : "Virtual",
                                         MohyTouchSideToString(fact.trigger_touch_side),
                                         fact.trigger_price,
                                         fact.expected_fill_price,
                                         MohyRecheckModeToString(fact.recheck_mode),
                                         MohyAdjustCadenceToString(fact.adjust_cadence),
                                         fact.exposure_pass ? "Yes" : "No",
                                         open_risk_money,
                                         fact.risk_money,
                                         fact.lots_normalized);
         out_facts[fact_count++] = fact;
        }

      ArrayResize(out_facts, fact_count);
      for(int i = 0; i < fact_count; ++i)
         out_facts[i].index = i;
      PopulateSelectionFacts(out_facts);
      return fact_count;
     }
  };

#endif
