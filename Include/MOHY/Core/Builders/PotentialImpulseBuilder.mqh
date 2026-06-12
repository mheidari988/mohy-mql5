#ifndef __MOHY_CORE_BUILDERS_POTENTIAL_IMPULSE_BUILDER_MQH__
#define __MOHY_CORE_BUILDERS_POTENTIAL_IMPULSE_BUILDER_MQH__

#include <MOHY/Domain/Config.mqh>
#include <MOHY/Core/Domain/PriceActionContracts.mqh>
#include <MOHY/Core/Compat/TerminalSeries.mqh>

class CMohyPotentialImpulseBuilder
  {
private:
   DetectionConfig m_cfg;
   int             m_timeframe;

   double  Eps() const
     {
      return 1e-10;
     }

   double  ResolveDojiEpsilon(const string symbol) const
     {
      double point = 0.0;
      if(!SymbolInfoDouble(symbol, SYMBOL_POINT, point) || point <= 0.0)
         point = Eps();
      const double scale_points = MathMax(Eps(), m_cfg.potential_impulse_doji_epsilon_points);
      return MathMax(Eps(), point * scale_points);
     }

   int     ResolvePotentialImpulseLegIndex(const MohySwing3Fact &swing) const
     {
      switch(swing.pattern_type)
        {
         case MOHY_SWING3_PATTERN_BULLISH_ICI:
         case MOHY_SWING3_PATTERN_BULLISH_CII:
         case MOHY_SWING3_PATTERN_BEARISH_ICI:
         case MOHY_SWING3_PATTERN_BEARISH_CII:
            return swing.leg3_index;
         case MOHY_SWING3_PATTERN_BULLISH_CIC:
         case MOHY_SWING3_PATTERN_BEARISH_CIC:
            return swing.leg2_index;
         case MOHY_SWING3_PATTERN_BULLISH_ICC:
         case MOHY_SWING3_PATTERN_BEARISH_ICC:
            return swing.leg1_index;
         default:
            return -1;
        }
     }

   bool    ResolveLegBreakReference(const MohyElementFact &elements[],
                                    const MohyLegFact &leg,
                                    double &out_reference_price) const
     {
      out_reference_price = 0.0;
      const int element_count = ArraySize(elements);
      if(element_count <= 0)
         return false;
      if(leg.begin_element_index <= 0 || leg.begin_element_index >= element_count)
         return false;

      const int previous_element_index = leg.begin_element_index - 1;
      if(previous_element_index < 0 || previous_element_index >= element_count)
         return false;

      const MohyElementFact previous_element = elements[previous_element_index];
      if(previous_element.pivot_price <= 0.0)
         return false;

      if(leg.direction == MOHY_DIR_BULL && previous_element.type != MOHY_ELEMENT_PEAK)
         return false;
      if(leg.direction == MOHY_DIR_BEAR && previous_element.type != MOHY_ELEMENT_VALLEY)
         return false;

      out_reference_price = previous_element.pivot_price;
      return true;
     }

   bool    IsBreakoutClose(const MohyDirection direction,
                           const double close_price,
                           const double reference_price,
                           const double eps) const
     {
      if(direction == MOHY_DIR_BULL)
         return (close_price > reference_price + eps);
      if(direction == MOHY_DIR_BEAR)
         return (close_price < reference_price - eps);
      return false;
     }

   int     CountLegBreakoutCloses(const string symbol,
                                  const MohyLegFact &leg,
                                  const double reference_price,
                                  const double eps,
                                  int &out_first_breakout_shift,
                                  datetime &out_first_breakout_time) const
     {
      out_first_breakout_shift = -1;
      out_first_breakout_time = 0;
      if(symbol == "" || m_timeframe <= 0)
         return 0;

      const int older_shift = MathMax(leg.begin_shift, leg.end_shift);
      const int newer_shift = MathMin(leg.begin_shift, leg.end_shift);
      int breakout_close_count = 0;
      for(int shift = older_shift; shift >= newer_shift; --shift)
        {
         if(MohyITime(symbol, m_timeframe, shift) <= 0)
            continue;

         const double close_price = MohyIClose(symbol, m_timeframe, shift);
         if(close_price <= 0.0)
            continue;

         if(!IsBreakoutClose(leg.direction, close_price, reference_price, eps))
            continue;

         breakout_close_count++;
         if(out_first_breakout_shift < 0)
           {
            out_first_breakout_shift = shift;
            out_first_breakout_time = MohyITime(symbol, m_timeframe, shift);
           }
        }
      return breakout_close_count;
     }

   bool    IsOppositeDirectionalCandle(const MohyDirection impulse_direction,
                                       const double open_price,
                                       const double close_price,
                                       const double doji_eps) const
     {
      if(MathAbs(close_price - open_price) <= doji_eps)
         return false;

      if(impulse_direction == MOHY_DIR_BULL)
         return (close_price < open_price - doji_eps);
      if(impulse_direction == MOHY_DIR_BEAR)
         return (close_price > open_price + doji_eps);
      return false;
     }

   bool    PassDirectionalCandlePolicy(const string symbol,
                                       const MohyLegFact &leg,
                                       const MohyDirection impulse_direction,
                                       const int first_breakout_shift,
                                       const double doji_eps) const
     {
      if(!m_cfg.potential_impulse_require_directional_candles)
         return true;
      if(symbol == "" || m_timeframe <= 0)
         return false;
      if(impulse_direction != MOHY_DIR_BULL && impulse_direction != MOHY_DIR_BEAR)
         return false;

      const int older_shift = MathMax(leg.begin_shift, leg.end_shift);
      const int newer_shift = MathMin(leg.begin_shift, leg.end_shift);
      if(older_shift - newer_shift <= 1 && !m_cfg.potential_impulse_validate_endpoint_candles)
         return true;

      const int allow_begin = MathMax(0, m_cfg.potential_impulse_allow_opposite_begin_candles);
      const int allow_end = MathMax(0, m_cfg.potential_impulse_allow_opposite_end_candles);
      const int max_opposite_middle = MathMax(0, m_cfg.potential_impulse_max_opposite_middle_candles);
      int opposite_middle_count = 0;

      for(int shift = older_shift; shift >= newer_shift; --shift)
        {
         if(!m_cfg.potential_impulse_validate_endpoint_candles &&
            (shift == older_shift || shift == newer_shift))
            continue;

         if(MohyITime(symbol, m_timeframe, shift) <= 0)
            return false;

         const double open_price = MohyIOpen(symbol, m_timeframe, shift);
         const double close_price = MohyIClose(symbol, m_timeframe, shift);
         if(open_price <= 0.0 || close_price <= 0.0)
            return false;

         if(!IsOppositeDirectionalCandle(impulse_direction, open_price, close_price, doji_eps))
            continue;

         const int from_begin = older_shift - shift;
         const int from_end = shift - newer_shift;
         bool exempt = (from_begin < allow_begin || from_end < allow_end);
         if(!exempt &&
            m_cfg.potential_impulse_allow_any_opposite_before_leg_breakout &&
            first_breakout_shift >= 0 &&
            shift > first_breakout_shift)
            exempt = true;

         if(exempt)
            continue;

         opposite_middle_count++;
         if(opposite_middle_count > max_opposite_middle)
            return false;
        }

      return true;
     }

   string  BoolText(const bool value) const
     {
      return value ? "1" : "0";
     }

   string  DirectionCode(const MohyDirection direction) const
     {
      if(direction == MOHY_DIR_BULL)
         return "Bull";
      if(direction == MOHY_DIR_BEAR)
         return "Bear";
      return "None";
     }

   string  GateCode(const bool gate_required) const
     {
      return gate_required ? "PASS" : "OFF";
     }

   string  LegContextCode(const bool context_evaluated,
                          const bool has_context) const
     {
      if(!context_evaluated)
         return "NA";
      return has_context ? "OK" : "MISS";
     }

   string  BuildDiagnostics(const MohySwing3Fact &swing,
                            const MohyLegFact &leg,
                            const int min_swing_breakout_closes,
                            const int min_leg_breakout_closes,
                            const bool leg_breakout_required,
                            const bool leg_break_context_evaluated,
                            const bool has_leg_break_context,
                            const int leg_breakout_close_count,
                            const int first_breakout_shift) const
     {
      return StringFormat("Reason=PI_OK|Swing3=%d|Leg=%d|Dir=%s|Pattern=%s|SwingGate=%s|SwingMin=%d|SwingCount=%d|SwingBreak=%s|LegGate=%s|LegMin=%d|LegCount=%d|LegCtx=%s|FirstLegBreakShift=%d|DirGate=PASS|AllowAnyBeforeLegBreak=%s",
                          swing.index,
                          leg.index,
                          DirectionCode(swing.direction),
                          MohySwing3PatternTypeToString(swing.pattern_type),
                          GateCode(min_swing_breakout_closes > 0),
                          min_swing_breakout_closes,
                          swing.breakout_close_count,
                          MohyBreakStateToString(swing.break_state),
                          GateCode(leg_breakout_required),
                          min_leg_breakout_closes,
                          leg_breakout_close_count,
                          LegContextCode(leg_break_context_evaluated, has_leg_break_context),
                          first_breakout_shift,
                          BoolText(m_cfg.potential_impulse_allow_any_opposite_before_leg_breakout));
     }

   void    AppendFact(const MohyPotentialImpulseFact &fact,
                      MohyPotentialImpulseFact &io_facts[],
                      int &io_count) const
     {
      ArrayResize(io_facts, io_count + 1);
      io_facts[io_count] = fact;
      io_facts[io_count].index = io_count;
      io_count++;
     }

public:
            CMohyPotentialImpulseBuilder()
              {
               MohySetDefaultDetectionConfig(m_cfg);
               m_timeframe = PERIOD_H1;
              }

   void     Configure(const DetectionConfig &cfg,
                      const int timeframe)
     {
      m_cfg = cfg;
      m_timeframe = timeframe;
     }

   int      Build(const string symbol,
                  const MohyElementFact &elements[],
                  const MohyLegFact &legs[],
                  const MohySwing3Fact &swings3[],
                  MohyPotentialImpulseFact &out_facts[]) const
     {
      ArrayResize(out_facts, 0);
      if(!m_cfg.enable_potential_impulse)
         return 0;
      if(symbol == "" || m_timeframe <= 0)
         return 0;

      const int leg_count = ArraySize(legs);
      const int swing_count = ArraySize(swings3);
      if(leg_count <= 0 || swing_count <= 0)
         return 0;

      const double doji_eps = ResolveDojiEpsilon(symbol);
      const int min_swing_breakout_closes = MathMax(0, m_cfg.potential_impulse_min_swing_breakout_closes);
      const int min_leg_breakout_closes = MathMax(1, m_cfg.potential_impulse_min_leg_breakout_closes);
      const bool require_leg_breakout = m_cfg.potential_impulse_require_leg_breakout;
      const bool allow_any_before_leg_breakout = m_cfg.potential_impulse_allow_any_opposite_before_leg_breakout;
      int fact_count = 0;
      for(int i = 0; i < swing_count; ++i)
        {
         const MohySwing3Fact swing = swings3[i];
         if(swing.direction == MOHY_DIR_NONE)
            continue;

         if(min_swing_breakout_closes > 0)
           {
            if(swing.break_state != MOHY_BREAK_STATE_BREAKOUT)
               continue;
            if(swing.breakout_close_count < min_swing_breakout_closes)
               continue;
           }

         const int leg_index = ResolvePotentialImpulseLegIndex(swing);
         if(leg_index < 0 || leg_index >= leg_count)
            continue;

         const MohyLegFact leg = legs[leg_index];
         if(leg.direction != swing.direction)
            continue;

         double reference_price = 0.0;
          int first_breakout_shift = -1;
          datetime first_breakout_time = 0;
          int leg_breakout_close_count = 0;
          bool leg_break_context_evaluated = false;
          bool has_leg_break_context = false;
          if(require_leg_breakout || allow_any_before_leg_breakout)
            {
             leg_break_context_evaluated = true;
             has_leg_break_context = ResolveLegBreakReference(elements, leg, reference_price);
             if(has_leg_break_context)
                leg_breakout_close_count = CountLegBreakoutCloses(symbol,
                                                                  leg,
                                                                  reference_price,
                                                                 doji_eps,
                                                                 first_breakout_shift,
                                                                 first_breakout_time);
            }

          if(require_leg_breakout)
            {
             if(!has_leg_break_context)
                continue;
             if(leg_breakout_close_count < min_leg_breakout_closes)
                continue;
           }

         if(!PassDirectionalCandlePolicy(symbol,
                                         leg,
                                         swing.direction,
                                         first_breakout_shift,
                                         doji_eps))
            continue;

         MohyPotentialImpulseFact fact;
         fact.index = -1;
         fact.valid = true;
         fact.swing3_index = swing.index;
         fact.leg_index = leg.index;
         fact.direction = swing.direction;
         fact.confirmed = (swing.confirmed && leg.confirmed);
         fact.pattern_type = swing.pattern_type;
         fact.break_state = swing.break_state;
         fact.swing_breakout_certainty = swing.breakout_certainty;
         fact.swing_breakout_close_count = swing.breakout_close_count;
         fact.leg_break_reference_price = reference_price;
         fact.leg_breakout_close_count = leg_breakout_close_count;
         fact.first_leg_breakout_shift = first_breakout_shift;
         fact.first_leg_breakout_time = first_breakout_time;
         fact.begin_shift = leg.begin_shift;
         fact.begin_time = leg.begin_time;
          fact.begin_price = leg.begin_price;
          fact.end_shift = leg.end_shift;
          fact.end_time = leg.end_time;
          fact.end_price = leg.end_price;
          fact.diagnostics = BuildDiagnostics(swing,
                                              leg,
                                              min_swing_breakout_closes,
                                              min_leg_breakout_closes,
                                              require_leg_breakout,
                                              leg_break_context_evaluated,
                                              has_leg_break_context,
                                              leg_breakout_close_count,
                                              first_breakout_shift);
          AppendFact(fact, out_facts, fact_count);
         }

      return fact_count;
     }
  };

#endif
