#ifndef __MOHY_CORE_BUILDERS_POTENTIAL_CORRECTION_BUILDER_MQH__
#define __MOHY_CORE_BUILDERS_POTENTIAL_CORRECTION_BUILDER_MQH__

#include <MOHY/Domain/Config.mqh>
#include <MOHY/Core/Domain/PriceActionContracts.mqh>
#include <MOHY/Core/Compat/TerminalSeries.mqh>
#include <MOHY/Core/Builders/ElementBuilder.mqh>
#include <MOHY/Core/Builders/LegBuilder.mqh>
#include <MOHY/Core/Builders/Swing3Builder.mqh>
#include <MOHY/Core/Builders/PotentialImpulseBuilder.mqh>

class CMohyPotentialCorrectionBuilder
  {
private:
   DetectionConfig m_cfg;
   int             m_timeframe;
   int             m_context_timeframe;
   int             m_execution_timeframe;

   double  Eps() const
     {
      return 1e-10;
     }

   bool    IsOppositeIciPattern(const MohyDirection impulse_direction,
                                const MohySwing3PatternType pattern_type) const
     {
      if(impulse_direction == MOHY_DIR_BULL)
         return (pattern_type == MOHY_SWING3_PATTERN_BEARISH_ICI);
      if(impulse_direction == MOHY_DIR_BEAR)
         return (pattern_type == MOHY_SWING3_PATTERN_BULLISH_ICI);
      return false;
     }

   bool    IsTouchThresholdMet(const MohyDirection impulse_direction,
                               const double low_price,
                               const double high_price,
                               const double threshold_price) const
     {
      if(impulse_direction == MOHY_DIR_BULL)
         return (low_price <= threshold_price + Eps());
      if(impulse_direction == MOHY_DIR_BEAR)
         return (high_price >= threshold_price - Eps());
      return false;
     }

   bool    IsCloseThresholdMet(const MohyDirection impulse_direction,
                               const double close_price,
                               const double threshold_price) const
     {
      if(impulse_direction == MOHY_DIR_BULL)
         return (close_price <= threshold_price + Eps());
      if(impulse_direction == MOHY_DIR_BEAR)
         return (close_price >= threshold_price - Eps());
      return false;
     }

   bool    IsStrictTouchBreach(const MohyDirection impulse_direction,
                               const double low_price,
                               const double high_price,
                               const double threshold_price) const
     {
      if(impulse_direction == MOHY_DIR_BULL)
         return (low_price < threshold_price - Eps());
      if(impulse_direction == MOHY_DIR_BEAR)
         return (high_price > threshold_price + Eps());
      return false;
     }

   bool    IsStrictCloseBreach(const MohyDirection impulse_direction,
                               const double close_price,
                               const double threshold_price) const
     {
      if(impulse_direction == MOHY_DIR_BULL)
         return (close_price < threshold_price - Eps());
      if(impulse_direction == MOHY_DIR_BEAR)
         return (close_price > threshold_price + Eps());
      return false;
     }

   bool    IsExtremeTouch(const MohyDirection impulse_direction,
                          const double low_price,
                          const double high_price,
                          const double impulse_extreme_price,
                          const double epsilon_price) const
     {
      if(impulse_direction == MOHY_DIR_BULL)
         return (high_price >= impulse_extreme_price - epsilon_price - Eps());
      if(impulse_direction == MOHY_DIR_BEAR)
         return (low_price <= impulse_extreme_price + epsilon_price + Eps());
      return false;
     }

   int     ResolveContextLookback(const int execution_max_shift) const
     {
      const int context_minutes = MohyTimeframeToMinutes(m_context_timeframe);
      const int execution_minutes = MohyTimeframeToMinutes(m_execution_timeframe);
      if(context_minutes <= 0 || execution_minutes <= 0)
         return MathMax(80, execution_max_shift);

      const int ratio = MathMax(1, context_minutes / execution_minutes);
      return MathMax(80, execution_max_shift / ratio + 8);
     }

   bool    BuildContextArtifacts(const string symbol,
                                 const int execution_max_shift,
                                 MohyLegFact &out_context_legs[],
                                 MohySwing3Fact &out_context_swings3[],
                                 MohyPotentialImpulseFact &out_context_impulses[]) const
     {
      ArrayResize(out_context_legs, 0);
      ArrayResize(out_context_swings3, 0);
      ArrayResize(out_context_impulses, 0);

      if(symbol == "" || m_context_timeframe <= 0)
         return false;

      const int context_bars = MohyIBars(symbol, m_context_timeframe);
      if(context_bars <= m_cfg.swing_right_bars + 2)
         return false;

      const int context_from_shift = m_cfg.swing_right_bars + 1;
      int context_max_shift = context_bars - m_cfg.swing_right_bars - 2;
      context_max_shift = MathMin(context_max_shift, ResolveContextLookback(execution_max_shift));
      if(context_max_shift < context_from_shift)
         return false;

      MohyElementFact context_elements[];
      CMohyElementBuilder element_builder;
      element_builder.Configure(m_cfg, m_context_timeframe);
      element_builder.Build(symbol,
                            context_from_shift,
                            context_max_shift,
                            context_elements,
                            true);
      if(ArraySize(context_elements) <= 0)
         return false;

      CMohyLegBuilder leg_builder;
      leg_builder.Build(context_elements, out_context_legs);

      CMohySwing3Builder swing3_builder;
      swing3_builder.Build(symbol,
                           m_context_timeframe,
                           context_elements,
                           out_context_legs,
                           out_context_swings3);

      CMohyPotentialImpulseBuilder impulse_builder;
      impulse_builder.Configure(m_cfg, m_context_timeframe);
      impulse_builder.Build(symbol,
                            context_elements,
                            out_context_legs,
                            out_context_swings3,
                            out_context_impulses);
      return (ArraySize(out_context_impulses) > 0);
     }

   double  ResolveImpulsePriceEpsilon(const string symbol) const
     {
      double point = 0.0;
      if(!SymbolInfoDouble(symbol, SYMBOL_POINT, point) || point <= 0.0)
         point = Eps();
      const double scale_points = MathMax(1e-10, m_cfg.potential_impulse_doji_epsilon_points);
      return MathMax(1e-10, point * scale_points);
     }

   bool    ResolveImpulseEndAnchorShift(const string symbol,
                                        const MohyDirection impulse_direction,
                                        const datetime impulse_end_time,
                                        const double impulse_end_price,
                                        int &out_shift,
                                        datetime &out_time) const
     {
      out_shift = -1;
      out_time = 0;
      if(symbol == "")
         return false;
      if(m_context_timeframe <= 0)
         return false;
      if(m_execution_timeframe <= 0)
         return false;
      if(impulse_end_time <= 0)
         return false;
      if(impulse_end_price <= 0.0)
         return false;
      if(impulse_direction != MOHY_DIR_BULL && impulse_direction != MOHY_DIR_BEAR)
         return false;

      const int context_seconds = MohyPeriodSeconds(m_context_timeframe);
      if(context_seconds <= 0)
         return false;

      int context_shift = MohyIBarShift(symbol,
                                        m_context_timeframe,
                                        impulse_end_time,
                                        false);
      if(context_shift < 0)
         context_shift = MohyIBarShift(symbol,
                                       m_context_timeframe,
                                       impulse_end_time,
                                       true);
      if(context_shift < 0)
         return false;

      const datetime source_open_time = MohyITime(symbol, m_context_timeframe, context_shift);
      if(source_open_time <= 0)
         return false;

      datetime source_next_open_time = MohyITime(symbol, m_context_timeframe, context_shift - 1);
      if(source_next_open_time <= source_open_time)
         source_next_open_time = source_open_time + context_seconds;
      if(source_next_open_time <= source_open_time)
         return false;

      int oldest_execution_shift = MohyIBarShift(symbol,
                                                 m_execution_timeframe,
                                                 source_open_time,
                                                 true);
      if(oldest_execution_shift < 0)
         oldest_execution_shift = MohyIBarShift(symbol,
                                                m_execution_timeframe,
                                                source_open_time,
                                                false);
      int newest_execution_shift = MohyIBarShift(symbol,
                                                 m_execution_timeframe,
                                                 source_next_open_time - 1,
                                                 false);
      if(oldest_execution_shift < 0 || newest_execution_shift < 0)
         return false;

      if(oldest_execution_shift < newest_execution_shift)
        {
         const int tmp = oldest_execution_shift;
         oldest_execution_shift = newest_execution_shift;
         newest_execution_shift = tmp;
        }

      const bool want_high = (impulse_direction == MOHY_DIR_BULL);
      const double eps = ResolveImpulsePriceEpsilon(symbol);
      for(int shift = oldest_execution_shift; shift >= newest_execution_shift; --shift)
        {
         const datetime t = MohyITime(symbol, m_execution_timeframe, shift);
         if(t < source_open_time || t >= source_next_open_time)
            continue;

         if(want_high)
           {
            const double high_price = MohyIHigh(symbol, m_execution_timeframe, shift);
            if(high_price >= impulse_end_price - eps)
              {
               out_shift = shift;
               out_time = t;
               return true;
              }
           }
         else
           {
            const double low_price = MohyILow(symbol, m_execution_timeframe, shift);
            if(low_price <= impulse_end_price + eps)
              {
               out_shift = shift;
               out_time = t;
               return true;
              }
           }
        }

      const int count = oldest_execution_shift - newest_execution_shift + 1;
      if(count <= 0)
         return false;

      const int extreme_shift = want_high
                                ? MohyIHighest(symbol, m_execution_timeframe, MODE_HIGH, count, newest_execution_shift)
                                : MohyILowest(symbol, m_execution_timeframe, MODE_LOW, count, newest_execution_shift);
      if(extreme_shift < 0)
         return false;

      const datetime resolved_time = MohyITime(symbol, m_execution_timeframe, extreme_shift);
      if(resolved_time <= 0)
         return false;

      out_shift = extreme_shift;
      out_time = resolved_time;
      return true;
     }

   void    BuildOppositeIciHistogram(const MohyDirection impulse_direction,
                                     const int start_shift,
                                     const MohyLegFact &execution_legs[],
                                     const MohySwing3Fact &execution_swings3[],
                                     int &out_histogram[]) const
     {
      ArrayResize(out_histogram, start_shift + 1);
      for(int i = 0; i <= start_shift; ++i)
         out_histogram[i] = 0;

      const int swing_count = ArraySize(execution_swings3);
      const int leg_count = ArraySize(execution_legs);
      for(int i = 0; i < swing_count; ++i)
        {
         const MohySwing3Fact swing = execution_swings3[i];
         if(!swing.confirmed)
            continue;
         if(!IsOppositeIciPattern(impulse_direction, swing.pattern_type))
            continue;
         if(swing.leg3_index < 0 || swing.leg3_index >= leg_count)
            continue;

         const int end_shift = execution_legs[swing.leg3_index].end_shift;
         if(end_shift < 0 || end_shift > start_shift)
            continue;

         out_histogram[end_shift] = out_histogram[end_shift] + 1;
        }
     }

   int     ResolveSupersedeShift(const string symbol,
                                 const MohyDirection impulse_direction,
                                 const datetime impulse_end_time,
                                 const int start_shift,
                                 const MohyLegFact &context_legs[],
                                 const MohySwing3Fact &context_swings3[]) const
     {
      if(symbol == "")
         return -1;

      const bool opposite_only =
         (m_cfg.potential_correction_supersede_direction_mode == MOHY_POT_CORR_SUPERSEDE_DIR_OPPOSITE_ONLY);

      int resolved_shift = -1;
      const int swing_count = ArraySize(context_swings3);
      const int leg_count = ArraySize(context_legs);
      for(int i = 0; i < swing_count; ++i)
        {
         const MohySwing3Fact swing = context_swings3[i];
         if(!swing.confirmed)
            continue;
         if(swing.direction == MOHY_DIR_NONE)
            continue;
         if(opposite_only && swing.direction == impulse_direction)
            continue;
         if(swing.leg3_index < 0 || swing.leg3_index >= leg_count)
            continue;

         const datetime swing_time = context_legs[swing.leg3_index].end_time;
         if(swing_time <= impulse_end_time)
            continue;

         const int mapped_shift = MohyIBarShift(symbol,
                                                m_execution_timeframe,
                                                swing_time,
                                                false);
         if(mapped_shift < 0 || mapped_shift > start_shift)
            continue;

         // Earliest event after correction start is the largest shift <= start_shift.
         if(mapped_shift > resolved_shift)
            resolved_shift = mapped_shift;
        }

      return resolved_shift;
     }

   void    ResetTimelineFact(MohyPotentialCorrectionTimelineFact &out_timeline) const
     {
      out_timeline.timeline_end_shift = -1;
      out_timeline.timeline_end_time = 0;
      out_timeline.extreme_shift = -1;
      out_timeline.extreme_time = 0;
      out_timeline.extreme_price = 0.0;
      out_timeline.forming_end_shift = -1;
      out_timeline.forming_end_time = 0;
      out_timeline.forming_end_price = 0.0;
      out_timeline.has_confirmed_segment = false;
      out_timeline.confirmed_begin_shift = -1;
      out_timeline.confirmed_begin_time = 0;
      out_timeline.confirmed_begin_price = 0.0;
      out_timeline.confirmed_end_shift = -1;
      out_timeline.confirmed_end_time = 0;
      out_timeline.confirmed_end_price = 0.0;
      out_timeline.has_invalidated_segment = false;
      out_timeline.invalid_begin_shift = -1;
      out_timeline.invalid_begin_time = 0;
      out_timeline.invalid_begin_price = 0.0;
      out_timeline.invalid_end_shift = -1;
      out_timeline.invalid_end_time = 0;
      out_timeline.invalid_end_price = 0.0;
     }

   double  ResolveDirectionalPriceAtShift(const string symbol,
                                          const MohyDirection impulse_direction,
                                          const int shift,
                                          const double fallback_price) const
     {
      if(symbol == "" || m_execution_timeframe <= 0 || shift < 0)
         return fallback_price;

      if(impulse_direction == MOHY_DIR_BULL)
        {
         const double low_price = MohyILow(symbol, m_execution_timeframe, shift);
         return (low_price > 0.0) ? low_price : fallback_price;
        }
      if(impulse_direction == MOHY_DIR_BEAR)
        {
         const double high_price = MohyIHigh(symbol, m_execution_timeframe, shift);
         return (high_price > 0.0) ? high_price : fallback_price;
        }

      return fallback_price;
     }

   bool    ResolveWindowExtreme(const string symbol,
                                const MohyDirection impulse_direction,
                                const int begin_shift,
                                const int end_shift,
                                const double fallback_price,
                                int &out_extreme_shift,
                                datetime &out_extreme_time,
                                double &out_extreme_price) const
     {
      out_extreme_shift = begin_shift;
      out_extreme_time = MohyITime(symbol, m_execution_timeframe, begin_shift);
      out_extreme_price = fallback_price;

      if(symbol == "" || m_execution_timeframe <= 0)
         return false;
      if(begin_shift < 0 || end_shift < 0)
         return false;
      if(begin_shift < end_shift)
         return false;
      if(impulse_direction != MOHY_DIR_BULL && impulse_direction != MOHY_DIR_BEAR)
         return false;

      bool initialized = false;
      for(int shift = begin_shift; shift >= end_shift; --shift)
        {
         const datetime t = MohyITime(symbol, m_execution_timeframe, shift);
         if(t <= 0)
            continue;

         const double value = (impulse_direction == MOHY_DIR_BULL)
                              ? MohyILow(symbol, m_execution_timeframe, shift)
                              : MohyIHigh(symbol, m_execution_timeframe, shift);
         if(value <= 0.0)
            continue;

         if(!initialized)
           {
            out_extreme_shift = shift;
            out_extreme_time = t;
            out_extreme_price = value;
            initialized = true;
            continue;
           }

         if(impulse_direction == MOHY_DIR_BULL)
           {
            if(value < out_extreme_price - Eps())
              {
               out_extreme_shift = shift;
               out_extreme_time = t;
               out_extreme_price = value;
              }
           }
         else if(value > out_extreme_price + Eps())
           {
            out_extreme_shift = shift;
            out_extreme_time = t;
            out_extreme_price = value;
           }
        }

      return initialized;
     }

   void    BuildTimelineFact(const string symbol,
                             const MohyPotentialCorrectionFact &fact,
                             const int requested_timeline_end_shift,
                             MohyPotentialCorrectionTimelineFact &out_timeline) const
     {
      ResetTimelineFact(out_timeline);
      if(symbol == "" || m_execution_timeframe <= 0)
         return;
      if(!fact.valid)
         return;
      if(fact.begin_shift < 0 || fact.begin_time <= 0 || fact.begin_price <= 0.0)
         return;

      int timeline_end_shift = MathMax(0, requested_timeline_end_shift);
      timeline_end_shift = MathMin(fact.begin_shift, timeline_end_shift);

      out_timeline.timeline_end_shift = timeline_end_shift;
      out_timeline.timeline_end_time = MohyITime(symbol, m_execution_timeframe, timeline_end_shift);
      if(out_timeline.timeline_end_time <= 0)
         out_timeline.timeline_end_time = fact.begin_time;

      int timeline_extreme_shift = fact.begin_shift;
      datetime timeline_extreme_time = fact.begin_time;
      double timeline_extreme_price = fact.begin_price;
      ResolveWindowExtreme(symbol,
                           fact.impulse_direction,
                           fact.begin_shift,
                           timeline_end_shift,
                           fact.begin_price,
                           timeline_extreme_shift,
                           timeline_extreme_time,
                           timeline_extreme_price);
      out_timeline.extreme_shift = timeline_extreme_shift;
      out_timeline.extreme_time = timeline_extreme_time;
      out_timeline.extreme_price = timeline_extreme_price;

      const bool has_confirmed = (fact.confirmed_shift >= timeline_end_shift &&
                                  fact.confirmed_shift <= fact.begin_shift);
      const bool has_invalidated = (fact.invalidated_shift >= 0 &&
                                    fact.invalidated_shift <= fact.begin_shift);

      int forming_end_shift = timeline_end_shift;
      if(has_confirmed)
         forming_end_shift = fact.confirmed_shift + 1;
      else if(has_invalidated)
         forming_end_shift = fact.invalidated_shift + 1;
      forming_end_shift = MathMax(timeline_end_shift,
                                  MathMin(fact.begin_shift, forming_end_shift));

      int forming_extreme_shift = fact.begin_shift;
      datetime forming_extreme_time = fact.begin_time;
      double forming_extreme_price = fact.begin_price;
      ResolveWindowExtreme(symbol,
                           fact.impulse_direction,
                           fact.begin_shift,
                           forming_end_shift,
                           fact.begin_price,
                           forming_extreme_shift,
                           forming_extreme_time,
                           forming_extreme_price);
      out_timeline.forming_end_shift = forming_extreme_shift;
      out_timeline.forming_end_time = forming_extreme_time;
      out_timeline.forming_end_price = forming_extreme_price;

      if(has_confirmed)
        {
         const int confirmed_start_shift = fact.confirmed_shift;
         int confirmed_end_shift = timeline_end_shift;
         if(has_invalidated)
            confirmed_end_shift = MathMax(timeline_end_shift, fact.invalidated_shift + 1);

         if(confirmed_start_shift >= confirmed_end_shift)
           {
            out_timeline.has_confirmed_segment = true;
            out_timeline.confirmed_begin_shift = confirmed_start_shift;
            out_timeline.confirmed_begin_time = fact.confirmed_time;
            if(out_timeline.confirmed_begin_time <= 0)
               out_timeline.confirmed_begin_time = MohyITime(symbol,
                                                            m_execution_timeframe,
                                                            confirmed_start_shift);
            out_timeline.confirmed_begin_price = ResolveDirectionalPriceAtShift(symbol,
                                                                                fact.impulse_direction,
                                                                                confirmed_start_shift,
                                                                                forming_extreme_price);

            int confirmed_extreme_shift = confirmed_start_shift;
            datetime confirmed_extreme_time = out_timeline.confirmed_begin_time;
            double confirmed_extreme_price = out_timeline.confirmed_begin_price;
            ResolveWindowExtreme(symbol,
                                 fact.impulse_direction,
                                 confirmed_start_shift,
                                 confirmed_end_shift,
                                 out_timeline.confirmed_begin_price,
                                 confirmed_extreme_shift,
                                 confirmed_extreme_time,
                                 confirmed_extreme_price);
            out_timeline.confirmed_end_shift = confirmed_extreme_shift;
            out_timeline.confirmed_end_time = confirmed_extreme_time;
            out_timeline.confirmed_end_price = confirmed_extreme_price;
           }
        }

      if(fact.state == MOHY_POT_CORR_STATE_INVALIDATED && fact.invalidated_shift >= 0)
        {
         int invalid_start_shift = fact.invalidated_shift + 1;
         invalid_start_shift = MathMax(0, MathMin(fact.begin_shift, invalid_start_shift));
         if(invalid_start_shift < fact.invalidated_shift)
            invalid_start_shift = fact.invalidated_shift;

         out_timeline.has_invalidated_segment = true;
         out_timeline.invalid_begin_shift = invalid_start_shift;
         out_timeline.invalid_begin_time = MohyITime(symbol,
                                                     m_execution_timeframe,
                                                     invalid_start_shift);
         if(out_timeline.invalid_begin_time <= 0)
            out_timeline.invalid_begin_time = fact.invalidated_time;

         out_timeline.invalid_end_shift = fact.invalidated_shift;
         out_timeline.invalid_end_time = fact.invalidated_time;
         if(out_timeline.invalid_end_time <= 0)
            out_timeline.invalid_end_time = MohyITime(symbol,
                                                      m_execution_timeframe,
                                                      fact.invalidated_shift);

         out_timeline.invalid_begin_price = ResolveDirectionalPriceAtShift(symbol,
                                                                           fact.impulse_direction,
                                                                           invalid_start_shift,
                                                                           forming_extreme_price);
         out_timeline.invalid_end_price = ResolveDirectionalPriceAtShift(symbol,
                                                                         fact.impulse_direction,
                                                                         fact.invalidated_shift,
                                                                         out_timeline.invalid_begin_price);
        }
     }

   bool    IsFactNewer(const MohyPotentialCorrectionFact &left,
                       const MohyPotentialCorrectionFact &right) const
     {
      return ((left.begin_shift < right.begin_shift) ||
              (left.begin_shift == right.begin_shift &&
               left.begin_time > right.begin_time));
     }

   void    PopulateRecencyAndTimelineFacts(const string symbol,
                                           MohyPotentialCorrectionFact &io_facts[]) const
     {
      const int count = ArraySize(io_facts);
      int active_index = -1;
      for(int i = 0; i < count; ++i)
        {
         io_facts[i].recency_rank = -1;
         io_facts[i].is_active = false;
         io_facts[i].is_selected = false;
         ResetTimelineFact(io_facts[i].timeline_full);
         ResetTimelineFact(io_facts[i].timeline_trimmed);

         if(!io_facts[i].valid || io_facts[i].begin_shift < 0)
            continue;

         if(active_index < 0 || IsFactNewer(io_facts[i], io_facts[active_index]))
            active_index = i;

         int trimmed_end_shift = 0;
         if(io_facts[i].state == MOHY_POT_CORR_STATE_INVALIDATED &&
            io_facts[i].invalidated_shift >= 0)
            trimmed_end_shift = io_facts[i].invalidated_shift + 1;

         BuildTimelineFact(symbol, io_facts[i], 0, io_facts[i].timeline_full);
         BuildTimelineFact(symbol, io_facts[i], trimmed_end_shift, io_facts[i].timeline_trimmed);
        }

      if(active_index >= 0 && active_index < count)
        {
         io_facts[active_index].is_active = true;
         io_facts[active_index].is_selected = true;
        }

      for(int i = 0; i < count; ++i)
        {
         if(!io_facts[i].valid || io_facts[i].begin_shift < 0)
            continue;

         int newer_count = 0;
         for(int j = 0; j < count; ++j)
           {
            if(i == j)
               continue;
            if(!io_facts[j].valid || io_facts[j].begin_shift < 0)
               continue;
            if(IsFactNewer(io_facts[j], io_facts[i]))
               newer_count++;
           }
         io_facts[i].recency_rank = newer_count;
        }
     }

   void    AppendFact(const MohyPotentialCorrectionFact &fact,
                      MohyPotentialCorrectionFact &io_facts[],
                      int &io_count) const
     {
      ArrayResize(io_facts, io_count + 1);
      io_facts[io_count] = fact;
      io_facts[io_count].index = io_count;
      io_count++;
     }

public:
            CMohyPotentialCorrectionBuilder()
              {
               MohySetDefaultDetectionConfig(m_cfg);
               m_timeframe = PERIOD_M15;
               m_context_timeframe = PERIOD_H1;
               m_execution_timeframe = PERIOD_M15;
              }

   void     Configure(const DetectionConfig &cfg,
                      const int timeframe,
                      const int context_timeframe,
                      const int execution_timeframe)
     {
      m_cfg = cfg;
      m_timeframe = timeframe;
      m_context_timeframe = context_timeframe;
      m_execution_timeframe = execution_timeframe;
     }

   int      BuildContextImpulses(const string symbol,
                                 const int execution_max_shift,
                                 MohyPotentialImpulseFact &out_context_impulses[]) const
     {
      MohyLegFact context_legs[];
      MohySwing3Fact context_swings3[];
      ArrayResize(out_context_impulses, 0);
      if(!BuildContextArtifacts(symbol,
                                execution_max_shift,
                                context_legs,
                                context_swings3,
                                out_context_impulses))
         return 0;
      return ArraySize(out_context_impulses);
     }

   int      Build(const string symbol,
                  const int max_shift,
                  const MohyLegFact &execution_legs[],
                  const MohySwing3Fact &execution_swings3[],
                  MohyPotentialCorrectionFact &out_facts[]) const
     {
      ArrayResize(out_facts, 0);
      if(!m_cfg.enable_potential_correction)
         return 0;
      if(symbol == "")
         return 0;
      if(m_timeframe != m_execution_timeframe)
         return 0;
      if(!MohyValidateTimeframePair(m_context_timeframe, m_execution_timeframe))
         return 0;
      if(!MohyIsPotentialCorrectionFibRangeValid(m_cfg.potential_correction_min_fib_level,
                                                 m_cfg.potential_correction_max_fib_level))
         return 0;
      if(ArraySize(execution_legs) <= 0 || ArraySize(execution_swings3) <= 0)
         return 0;

      MohyLegFact context_legs[];
      MohySwing3Fact context_swings3[];
      MohyPotentialImpulseFact context_impulses[];
      if(!BuildContextArtifacts(symbol,
                                max_shift,
                                context_legs,
                                context_swings3,
                                context_impulses))
         return 0;

      const double min_fib_level = MohyPotentialCorrectionMinFibLevelToValue(m_cfg.potential_correction_min_fib_level);
      const double max_fib_level = MohyPotentialCorrectionMaxFibLevelToValue(m_cfg.potential_correction_max_fib_level);
      const int min_opposite_ici_count = MathMax(0, m_cfg.potential_correction_min_opposite_ici_count);
      const int extreme_touch_min_count = MathMax(1, m_cfg.potential_correction_extreme_touch_min_count);
      double point = 0.0;
      if(!SymbolInfoDouble(symbol, SYMBOL_POINT, point) || point <= 0.0)
         point = Eps();
      const double extreme_touch_epsilon_price = MathMax(0.0, m_cfg.potential_correction_extreme_touch_epsilon_points) * point;
      const bool supersede_forming_only =
         (m_cfg.potential_correction_supersede_scope == MOHY_POT_CORR_SUPERSEDE_SCOPE_FORMING_ONLY);

      int fact_count = 0;
      const int impulse_count = ArraySize(context_impulses);
      for(int i = 0; i < impulse_count; ++i)
        {
         const MohyPotentialImpulseFact impulse = context_impulses[i];
         if(!impulse.valid || !impulse.confirmed)
            continue;
         if(impulse.direction != MOHY_DIR_BULL && impulse.direction != MOHY_DIR_BEAR)
            continue;

         int start_shift = -1;
         datetime start_time = 0;
         if(!ResolveImpulseEndAnchorShift(symbol,
                                          impulse.direction,
                                          impulse.end_time,
                                          impulse.end_price,
                                          start_shift,
                                          start_time))
            continue;
         if(start_shift < 0 || start_shift > max_shift)
            continue;

         const int scan_start_shift = start_shift - 1;

         const double impulse_origin = impulse.begin_price;
         const double impulse_extreme = impulse.end_price;
         const double impulse_range = MathAbs(impulse_extreme - impulse_origin);
         if(impulse_range <= Eps())
            continue;

         const double min_threshold = (impulse.direction == MOHY_DIR_BULL)
                                      ? (impulse_extreme - min_fib_level * impulse_range)
                                      : (impulse_extreme + min_fib_level * impulse_range);
         const double max_threshold = (impulse.direction == MOHY_DIR_BULL)
                                      ? (impulse_extreme - max_fib_level * impulse_range)
                                      : (impulse_extreme + max_fib_level * impulse_range);

         int opposite_ici_histogram[];
         BuildOppositeIciHistogram(impulse.direction,
                                   scan_start_shift,
                                   execution_legs,
                                   execution_swings3,
                                   opposite_ici_histogram);

         const int supersede_shift = ResolveSupersedeShift(symbol,
                                                           impulse.direction,
                                                           impulse.end_time,
                                                           scan_start_shift,
                                                           context_legs,
                                                           context_swings3);

         MohyPotentialCorrectionFact fact;
         fact.index = -1;
         fact.valid = true;
         fact.linked_potential_impulse_index = impulse.index;
         fact.linked_potential_impulse_swing3_index = impulse.swing3_index;
         fact.impulse_direction = impulse.direction;
         fact.confirmed = false;
         fact.state = MOHY_POT_CORR_STATE_FORMING;
         fact.termination_reason = MOHY_POT_CORR_TERM_NONE;
         fact.begin_shift = start_shift;
         fact.begin_time = start_time;
         fact.begin_price = impulse_extreme;
         fact.reference_begin_shift = start_shift;
         fact.reference_begin_time = start_time;
         fact.reference_begin_price = impulse_extreme;
         fact.visual_begin_shift = start_shift;
         fact.visual_begin_time = start_time;
         fact.visual_begin_price = impulse_extreme;
         fact.end_shift = start_shift;
         fact.end_time = start_time;
         fact.end_price = impulse_extreme;
         fact.impulse_origin_price = impulse_origin;
         fact.impulse_extreme_price = impulse_extreme;
         fact.retrace_depth = 0.0;
         fact.min_fib_level = min_fib_level;
         fact.max_fib_level = max_fib_level;
         fact.min_fib_trigger_mode = m_cfg.potential_correction_min_fib_trigger_mode;
         fact.max_fib_trigger_mode = m_cfg.potential_correction_max_fib_trigger_mode;
         fact.opposite_ici_count = 0;
         fact.min_opposite_ici_count = min_opposite_ici_count;
         fact.min_fib_gate_pass = false;
         fact.opposite_ici_gate_pass = false;
         fact.confirmed_shift = -1;
         fact.confirmed_time = 0;
         fact.invalidated_shift = -1;
         fact.invalidated_time = 0;
          fact.recency_rank = -1;
          fact.is_active = false;
          fact.is_selected = false;
         ResetTimelineFact(fact.timeline_full);
         ResetTimelineFact(fact.timeline_trimmed);
         fact.diagnostics = "";

         double retrace_extreme_price = impulse_extreme;
         int retrace_extreme_shift = start_shift;
         datetime retrace_extreme_time = start_time;
         bool min_fib_pass = false;
         int opposite_ici_count = 0;
         int extreme_touch_count = 0;
         bool is_confirmed = false;

         for(int shift = scan_start_shift; shift >= 0; --shift)
           {
            const datetime bar_time = MohyITime(symbol, m_execution_timeframe, shift);
            if(bar_time <= 0)
               continue;
            const double high_price = MohyIHigh(symbol, m_execution_timeframe, shift);
            const double low_price = MohyILow(symbol, m_execution_timeframe, shift);
            const double close_price = MohyIClose(symbol, m_execution_timeframe, shift);
            if(high_price <= 0.0 || low_price <= 0.0 || close_price <= 0.0)
               continue;

            if(impulse.direction == MOHY_DIR_BULL)
              {
               if(low_price < retrace_extreme_price - Eps())
                 {
                  retrace_extreme_price = low_price;
                  retrace_extreme_shift = shift;
                  retrace_extreme_time = bar_time;
                 }
              }
            else if(high_price > retrace_extreme_price + Eps())
              {
               retrace_extreme_price = high_price;
               retrace_extreme_shift = shift;
               retrace_extreme_time = bar_time;
              }

            if(shift >= 0 && shift < ArraySize(opposite_ici_histogram))
               opposite_ici_count += opposite_ici_histogram[shift];

            if(shift < 1)
               continue;

            const bool max_fib_breach = (fact.max_fib_trigger_mode == MOHY_LEVEL_TRIGGER_TOUCH)
                                        ? IsStrictTouchBreach(impulse.direction,
                                                              low_price,
                                                              high_price,
                                                              max_threshold)
                                        : IsStrictCloseBreach(impulse.direction,
                                                              close_price,
                                                              max_threshold);
            if(max_fib_breach)
              {
               fact.state = MOHY_POT_CORR_STATE_INVALIDATED;
               fact.termination_reason = MOHY_POT_CORR_TERM_MAX_FIB_INVALIDATED;
               fact.invalidated_shift = shift;
               fact.invalidated_time = bar_time;
               break;
              }

            if(IsExtremeTouch(impulse.direction,
                              low_price,
                              high_price,
                              impulse_extreme,
                              extreme_touch_epsilon_price))
               extreme_touch_count++;

            if(extreme_touch_count >= extreme_touch_min_count)
              {
               fact.state = MOHY_POT_CORR_STATE_INVALIDATED;
               fact.termination_reason = MOHY_POT_CORR_TERM_DOUBLE_EXTREME_INVALIDATED;
               fact.invalidated_shift = shift;
               fact.invalidated_time = bar_time;
               break;
              }

            if(supersede_shift >= 0 && shift == supersede_shift)
              {
               const bool supersede_allowed = (!supersede_forming_only || !is_confirmed);
               if(supersede_allowed)
                 {
                  fact.state = MOHY_POT_CORR_STATE_INVALIDATED;
                  fact.termination_reason = MOHY_POT_CORR_TERM_SUPERSEDED_BY_NEW_HTF_SWING;
                  fact.invalidated_shift = shift;
                  fact.invalidated_time = bar_time;
                  break;
                 }
              }

            if(!min_fib_pass)
              {
               min_fib_pass = (fact.min_fib_trigger_mode == MOHY_LEVEL_TRIGGER_TOUCH)
                              ? IsTouchThresholdMet(impulse.direction,
                                                    low_price,
                                                    high_price,
                                                    min_threshold)
                              : IsCloseThresholdMet(impulse.direction,
                                                    close_price,
                                                    min_threshold);
              }

            if(!is_confirmed && min_fib_pass && opposite_ici_count >= min_opposite_ici_count)
              {
               is_confirmed = true;
               fact.state = MOHY_POT_CORR_STATE_CONFIRMED;
               fact.termination_reason = MOHY_POT_CORR_TERM_CONFIRMED;
               fact.confirmed_shift = shift;
               fact.confirmed_time = bar_time;
              }
           }

         fact.end_shift = retrace_extreme_shift;
         fact.end_time = retrace_extreme_time;
         fact.end_price = retrace_extreme_price;
         fact.retrace_depth = MathAbs(retrace_extreme_price - impulse_extreme) / impulse_range;
         fact.opposite_ici_count = opposite_ici_count;
         fact.min_fib_gate_pass = min_fib_pass;
         fact.opposite_ici_gate_pass = (opposite_ici_count >= min_opposite_ici_count);
         fact.confirmed = (fact.state == MOHY_POT_CORR_STATE_CONFIRMED);

         if(fact.state == MOHY_POT_CORR_STATE_FORMING)
            fact.termination_reason = MOHY_POT_CORR_TERM_NONE;

         fact.diagnostics = StringFormat("State=%s|Term=%s|Depth=%.4f|OppICI=%d/%d|MinFib=%.3f|MaxFib=%.3f|RefStart=%d|VisStart=%d|SupShift=%d",
                                         MohyPotentialCorrectionStateToString(fact.state),
                                         MohyPotentialCorrectionTerminationReasonToString(fact.termination_reason),
                                         fact.retrace_depth,
                                         fact.opposite_ici_count,
                                         fact.min_opposite_ici_count,
                                         fact.min_fib_level,
                                         fact.max_fib_level,
                                         fact.reference_begin_shift,
                                         fact.visual_begin_shift,
                                         supersede_shift);
         AppendFact(fact, out_facts, fact_count);
        }

      PopulateRecencyAndTimelineFacts(symbol, out_facts);
      return fact_count;
     }
  };

#endif
