#ifndef __MOHY_CORE_PRICE_ACTION_KERNEL_MQH__
#define __MOHY_CORE_PRICE_ACTION_KERNEL_MQH__

#include <MOHY/Domain/Config.mqh>
#include <MOHY/Core/Compat/TerminalSeries.mqh>
#include <MOHY/Core/Domain/PriceActionContracts.mqh>
#include <MOHY/Core/Builders/ElementBuilder.mqh>
#include <MOHY/Core/Builders/LegBuilder.mqh>
#include <MOHY/Core/Builders/Swing3Builder.mqh>
#include <MOHY/Core/Builders/PotentialImpulseBuilder.mqh>
#include <MOHY/Core/Builders/PotentialCorrectionBuilder.mqh>
#include <MOHY/Core/Builders/PotentialContinuationBuilder.mqh>
#include <MOHY/Core/Builders/TradeSetupPlanBuilder.mqh>
#include <MOHY/Core/Builders/HistoricalTradeSetupBuilder.mqh>

class CMohyPriceActionKernel
  {
private:
   DetectionConfig     m_cfg;
   StrategyConfig      m_strategy_cfg;
   int                 m_timeframe;
   CMohyElementBuilder m_element_builder;
   CMohyLegBuilder     m_leg_builder;
   CMohySwing3Builder  m_swing3_builder;
   CMohyPotentialImpulseBuilder m_potential_impulse_builder;
   CMohyPotentialCorrectionBuilder m_potential_correction_builder;
   CMohyPotentialContinuationBuilder m_potential_continuation_builder;
   CMohyTradeSetupPlanBuilder m_trade_setup_plan_builder;
   CMohyHistoricalTradeSetupBuilder m_historical_trade_setup_builder;
   int                 m_context_timeframe;
   int                 m_execution_timeframe;

   void     ResetRuntimeIdentityFacts(CMohyPriceActionSnapshot &io_snapshot) const
     {
      for(int i = 0; i < ArraySize(io_snapshot.potential_impulses); ++i)
         io_snapshot.potential_impulses[i].runtime_impulse_id = "";
      for(int i = 0; i < ArraySize(io_snapshot.potential_corrections); ++i)
         io_snapshot.potential_corrections[i].runtime_impulse_id = "";
      for(int i = 0; i < ArraySize(io_snapshot.potential_continuation_signals); ++i)
        {
         io_snapshot.potential_continuation_signals[i].runtime_impulse_id = "";
         io_snapshot.potential_continuation_signals[i].runtime_setup_key = "";
        }
      for(int i = 0; i < ArraySize(io_snapshot.trade_setup_plans); ++i)
        {
         io_snapshot.trade_setup_plans[i].runtime_impulse_id = "";
         io_snapshot.trade_setup_plans[i].runtime_setup_key = "";
        }
      for(int i = 0; i < ArraySize(io_snapshot.historical_trade_setups); ++i)
        {
         io_snapshot.historical_trade_setups[i].runtime_impulse_id = "";
         io_snapshot.historical_trade_setups[i].runtime_setup_key = "";
        }
     }

   void     PopulateRuntimeIdentityFacts(CMohyPriceActionSnapshot &io_snapshot) const
     {
      ResetRuntimeIdentityFacts(io_snapshot);

      const string symbol = io_snapshot.symbol;
      const int context_timeframe = io_snapshot.context_timeframe;
      const int execution_timeframe = io_snapshot.execution_timeframe;

      for(int i = 0; i < ArraySize(io_snapshot.potential_impulses); ++i)
        {
         string impulse_id = "";
         if(MohyBuildRuntimeImpulseId(symbol,
                                      context_timeframe,
                                      execution_timeframe,
                                      io_snapshot.potential_impulses[i].direction,
                                      io_snapshot.potential_impulses[i].begin_time,
                                      io_snapshot.potential_impulses[i].end_time,
                                      io_snapshot.potential_impulses[i].begin_price,
                                      io_snapshot.potential_impulses[i].end_price,
                                      impulse_id))
            io_snapshot.potential_impulses[i].runtime_impulse_id = impulse_id;
        }

      for(int i = 0; i < ArraySize(io_snapshot.potential_corrections); ++i)
        {
         const int impulse_index = io_snapshot.potential_corrections[i].linked_potential_impulse_index;
         if(impulse_index < 0 || impulse_index >= ArraySize(io_snapshot.potential_impulses))
            continue;
         io_snapshot.potential_corrections[i].runtime_impulse_id =
            io_snapshot.potential_impulses[impulse_index].runtime_impulse_id;
        }

      for(int i = 0; i < ArraySize(io_snapshot.potential_continuation_signals); ++i)
        {
         string impulse_id = "";
         const int impulse_index = io_snapshot.potential_continuation_signals[i].linked_potential_impulse_index;
         if(impulse_index >= 0 && impulse_index < ArraySize(io_snapshot.potential_impulses))
            impulse_id = io_snapshot.potential_impulses[impulse_index].runtime_impulse_id;
         io_snapshot.potential_continuation_signals[i].runtime_impulse_id = impulse_id;

         datetime correction_anchor_time = 0;
         const int correction_index =
            io_snapshot.potential_continuation_signals[i].linked_potential_correction_index;
         if(correction_index >= 0 && correction_index < ArraySize(io_snapshot.potential_corrections))
           {
            const MohyPotentialCorrectionFact correction = io_snapshot.potential_corrections[correction_index];
            correction_anchor_time = correction.confirmed_time;
            if(correction_anchor_time <= 0)
               correction_anchor_time = correction.reference_begin_time;
            if(correction_anchor_time <= 0)
               correction_anchor_time = correction.begin_time;
           }

         string setup_key = "";
         if(MohyBuildRuntimeSetupKey(impulse_id,
                                     correction_anchor_time,
                                     io_snapshot.potential_continuation_signals[i].signal_time,
                                     setup_key))
            io_snapshot.potential_continuation_signals[i].runtime_setup_key = setup_key;
        }

      for(int i = 0; i < ArraySize(io_snapshot.trade_setup_plans); ++i)
        {
         const int signal_index = io_snapshot.trade_setup_plans[i].linked_potential_continuation_signal_index;
         if(signal_index < 0 || signal_index >= ArraySize(io_snapshot.potential_continuation_signals))
            continue;
         io_snapshot.trade_setup_plans[i].runtime_impulse_id =
            io_snapshot.potential_continuation_signals[signal_index].runtime_impulse_id;
         io_snapshot.trade_setup_plans[i].runtime_setup_key =
            io_snapshot.potential_continuation_signals[signal_index].runtime_setup_key;
        }

      for(int i = 0; i < ArraySize(io_snapshot.historical_trade_setups); ++i)
        {
         const int plan_index = io_snapshot.historical_trade_setups[i].linked_trade_setup_plan_index;
         if(plan_index >= 0 && plan_index < ArraySize(io_snapshot.trade_setup_plans))
           {
            io_snapshot.historical_trade_setups[i].runtime_impulse_id =
               io_snapshot.trade_setup_plans[plan_index].runtime_impulse_id;
            io_snapshot.historical_trade_setups[i].runtime_setup_key =
               io_snapshot.trade_setup_plans[plan_index].runtime_setup_key;
            continue;
           }

         const int signal_index =
            io_snapshot.historical_trade_setups[i].linked_potential_continuation_signal_index;
         if(signal_index < 0 || signal_index >= ArraySize(io_snapshot.potential_continuation_signals))
            continue;
         io_snapshot.historical_trade_setups[i].runtime_impulse_id =
            io_snapshot.potential_continuation_signals[signal_index].runtime_impulse_id;
         io_snapshot.historical_trade_setups[i].runtime_setup_key =
            io_snapshot.potential_continuation_signals[signal_index].runtime_setup_key;
        }
     }

public:
            CMohyPriceActionKernel()
              {
               MohySetDefaultStrategyConfig(m_strategy_cfg);
               MohySetDefaultDetectionConfig(m_cfg);
               m_timeframe = PERIOD_H1;
               MohyResolveTimeframePair(MOHY_TF_PAIR_H1_M15,
                                        m_context_timeframe,
                                        m_execution_timeframe);
               m_element_builder.Configure(m_cfg, m_timeframe);
               m_potential_impulse_builder.Configure(m_cfg, m_timeframe);
               m_potential_correction_builder.Configure(m_cfg,
                                                        m_timeframe,
                                                        m_context_timeframe,
                                                        m_execution_timeframe);
               m_potential_continuation_builder.Configure(m_cfg,
                                                          m_timeframe,
                                                          m_execution_timeframe);
               m_trade_setup_plan_builder.Configure(m_strategy_cfg,
                                                   m_timeframe,
                                                   m_execution_timeframe);
               m_historical_trade_setup_builder.Configure(m_strategy_cfg,
                                                          m_timeframe,
                                                          m_execution_timeframe);
              }

   void     Configure(const DetectionConfig &cfg,
                      const int timeframe,
                      const int context_timeframe = 0,
                      const int execution_timeframe = 0)
     {
      MohySetDefaultStrategyConfig(m_strategy_cfg);
      m_strategy_cfg.detection = cfg;
      m_cfg = cfg;
      m_timeframe = timeframe;
      if(MohyValidateTimeframePair(context_timeframe, execution_timeframe))
        {
         m_context_timeframe = context_timeframe;
         m_execution_timeframe = execution_timeframe;
        }
      m_strategy_cfg.context_timeframe = m_context_timeframe;
      m_strategy_cfg.execution_timeframe = m_execution_timeframe;
      m_element_builder.Configure(m_cfg, m_timeframe);
      m_potential_impulse_builder.Configure(m_cfg, m_timeframe);
      m_potential_correction_builder.Configure(m_cfg,
                                               m_timeframe,
                                               m_context_timeframe,
                                               m_execution_timeframe);
      m_potential_continuation_builder.Configure(m_cfg,
                                                 m_timeframe,
                                                 m_execution_timeframe);
      m_trade_setup_plan_builder.Configure(m_strategy_cfg,
                                           m_timeframe,
                                           m_execution_timeframe);
      m_historical_trade_setup_builder.Configure(m_strategy_cfg,
                                                 m_timeframe,
                                                 m_execution_timeframe);
     }

   void     Configure(const StrategyConfig &cfg,
                      const int timeframe,
                      const int context_timeframe = 0,
                      const int execution_timeframe = 0)
     {
      m_strategy_cfg = cfg;
      m_cfg = cfg.detection;
      m_timeframe = timeframe;
      if(MohyValidateTimeframePair(context_timeframe, execution_timeframe))
        {
         m_context_timeframe = context_timeframe;
         m_execution_timeframe = execution_timeframe;
        }
      else if(MohyValidateTimeframePair(cfg.context_timeframe, cfg.execution_timeframe))
        {
         m_context_timeframe = cfg.context_timeframe;
         m_execution_timeframe = cfg.execution_timeframe;
        }
      m_strategy_cfg.context_timeframe = m_context_timeframe;
      m_strategy_cfg.execution_timeframe = m_execution_timeframe;
      m_element_builder.Configure(m_cfg, m_timeframe);
      m_potential_impulse_builder.Configure(m_cfg, m_timeframe);
      m_potential_correction_builder.Configure(m_cfg,
                                               m_timeframe,
                                               m_context_timeframe,
                                               m_execution_timeframe);
      m_potential_continuation_builder.Configure(m_cfg,
                                                 m_timeframe,
                                                 m_execution_timeframe);
      m_trade_setup_plan_builder.Configure(m_strategy_cfg,
                                           m_timeframe,
                                           m_execution_timeframe);
      m_historical_trade_setup_builder.Configure(m_strategy_cfg,
                                                 m_timeframe,
                                                 m_execution_timeframe);
     }

   bool     Build(const string symbol,
                  const int from_shift,
                  const int max_shift,
                  CMohyPriceActionSnapshot &out_snapshot,
                  const bool include_provisional_latest = true)
     {
      out_snapshot.Reset();
      out_snapshot.symbol = symbol;
      out_snapshot.timeframe = m_timeframe;
      out_snapshot.context_timeframe = m_context_timeframe;
      out_snapshot.execution_timeframe = m_execution_timeframe;
      out_snapshot.from_shift = from_shift;
      out_snapshot.max_shift = max_shift;
      out_snapshot.built_at = TimeCurrent();
      out_snapshot.source_is_context_timeframe = (m_timeframe == m_context_timeframe);
      out_snapshot.source_is_execution_timeframe = (m_timeframe == m_execution_timeframe);
      out_snapshot.publishes_execution_stage_facts = (m_timeframe == m_execution_timeframe);

      if(symbol == "")
         return false;
      if(max_shift < from_shift)
         return false;

      // Provisional publication lock policy:
      // kernel snapshots always include provisional-latest stream.
      // Caller flag is retained for backward-compatible signatures only.
      const bool effective_include_provisional_latest = true;
      if(!include_provisional_latest)
        {
         // Compatibility no-op: explicit false requests do not disable
         // provisional publication in runtime snapshots.
        }

      m_element_builder.Build(symbol,
                             from_shift,
                             max_shift,
                             out_snapshot.elements,
                             effective_include_provisional_latest);
      m_leg_builder.Build(out_snapshot.elements, out_snapshot.legs);
      m_swing3_builder.Build(symbol,
                             m_timeframe,
                             out_snapshot.elements,
                             out_snapshot.legs,
                             out_snapshot.swings3);
      if(out_snapshot.publishes_execution_stage_facts)
         m_potential_correction_builder.BuildContextImpulses(symbol,
                                                             max_shift,
                                                             out_snapshot.potential_impulses);
      else
         m_potential_impulse_builder.Build(symbol,
                                           out_snapshot.elements,
                                           out_snapshot.legs,
                                           out_snapshot.swings3,
                                           out_snapshot.potential_impulses);
      m_potential_correction_builder.Build(symbol,
                                           max_shift,
                                           out_snapshot.legs,
                                           out_snapshot.swings3,
                                           out_snapshot.potential_corrections);
      m_potential_continuation_builder.Build(out_snapshot.legs,
                                             out_snapshot.swings3,
                                             out_snapshot.potential_corrections,
                                             out_snapshot.potential_continuation_signals);
      m_trade_setup_plan_builder.Build(symbol,
                                       out_snapshot.legs,
                                       out_snapshot.potential_corrections,
                                       out_snapshot.potential_continuation_signals,
                                       out_snapshot.trade_setup_plans);
      m_historical_trade_setup_builder.Build(symbol,
                                             out_snapshot.legs,
                                             out_snapshot.potential_corrections,
                                             out_snapshot.potential_continuation_signals,
                                             out_snapshot.trade_setup_plans,
                                             out_snapshot.historical_trade_setups);
      PopulateRuntimeIdentityFacts(out_snapshot);

      return (ArraySize(out_snapshot.elements) > 0);
     }

   bool     BuildRecent(const string symbol,
                        const int lookback_bars,
                        CMohyPriceActionSnapshot &out_snapshot,
                        const bool include_provisional_latest = true)
     {
      const int bars = MohyIBars(symbol, m_timeframe);
      if(bars <= m_cfg.swing_right_bars + 2)
         return false;

      const int from_shift = m_cfg.swing_right_bars + 1;
      const int max_shift = MathMin(bars - m_cfg.swing_right_bars - 2,
                                    MathMax(lookback_bars, 100));
      return Build(symbol,
                   from_shift,
                   max_shift,
                   out_snapshot,
                   include_provisional_latest);
     }
  };

#endif


