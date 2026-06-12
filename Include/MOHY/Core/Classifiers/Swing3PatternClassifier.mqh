#ifndef __MOHY_CORE_CLASSIFIERS_SWING3_PATTERN_CLASSIFIER_MQH__
#define __MOHY_CORE_CLASSIFIERS_SWING3_PATTERN_CLASSIFIER_MQH__

#include <MOHY/Core/Domain/PriceActionContracts.mqh>
#include <MOHY/Core/Compat/TerminalSeries.mqh>

class CMohySwing3PatternClassifier
  {
private:
   double Eps() const
     {
      return 1e-10;
     }

   bool   PriceGreater(const double left,
                       const double right) const
     {
      return (left > right + Eps());
     }

   bool   PriceLess(const double left,
                    const double right) const
     {
      return (left < right - Eps());
     }

   bool   PriceGreaterOrEqual(const double left,
                              const double right) const
     {
      return (left > right - Eps());
     }

   bool   PriceLessOrEqual(const double left,
                           const double right) const
     {
      return (left < right + Eps());
     }

   MohyDirection DirectionFromPattern(const MohySwing3PatternType pattern) const
     {
      if(pattern == MOHY_SWING3_PATTERN_BULLISH_ICI ||
         pattern == MOHY_SWING3_PATTERN_BULLISH_CIC ||
         pattern == MOHY_SWING3_PATTERN_BULLISH_ICC ||
         pattern == MOHY_SWING3_PATTERN_BULLISH_CII)
         return MOHY_DIR_BULL;

      if(pattern == MOHY_SWING3_PATTERN_BEARISH_ICI ||
         pattern == MOHY_SWING3_PATTERN_BEARISH_CIC ||
         pattern == MOHY_SWING3_PATTERN_BEARISH_ICC ||
         pattern == MOHY_SWING3_PATTERN_BEARISH_CII)
         return MOHY_DIR_BEAR;

      return MOHY_DIR_NONE;
     }

   int    CountClosesBeyond(const string symbol,
                            const int timeframe,
                            const int start_shift,
                            const int end_shift,
                            const double level,
                            const bool want_above) const
     {
      if(symbol == "" || timeframe <= 0)
         return 0;

      const int older_shift = MathMax(start_shift, end_shift);
      const int newer_shift = MathMin(start_shift, end_shift);
      int count = 0;
      for(int shift = older_shift; shift >= newer_shift; --shift)
        {
         const double close_price = MohyIClose(symbol, timeframe, shift);
         if(want_above)
           {
            if(PriceGreater(close_price, level))
               count++;
           }
         else
           {
            if(PriceLess(close_price, level))
               count++;
           }
         }
      return count;
     }

   MohyBreakoutCertainty ResolveBreakoutCertainty(const int breakout_close_count) const
     {
      if(breakout_close_count <= 0)
         return MOHY_BREAKOUT_CERTAINTY_UNKNOWN;
      if(breakout_close_count == 1)
         return MOHY_BREAKOUT_CERTAINTY_UNCERTAIN;
      return MOHY_BREAKOUT_CERTAINTY_CERTAIN;
     }

public:
   void   Classify(const string symbol,
                   const int timeframe,
                   const MohyElementFact &elements[],
                   const MohyLegFact &legs[],
                   const bool has_previous_swing,
                   const MohySwing3Fact &previous_swing,
                   MohySwing3Fact &io_swing) const
     {
      io_swing.pattern_type = MOHY_SWING3_PATTERN_UNKNOWN;
      io_swing.break_state = MOHY_BREAK_STATE_UNKNOWN;
      io_swing.breakout_certainty = MOHY_BREAKOUT_CERTAINTY_UNKNOWN;
      io_swing.correction_state = MOHY_CORRECTION_STATE_UNKNOWN;
      io_swing.breakout_close_count = 0;
      io_swing.direction = MOHY_DIR_NONE;

      if(io_swing.leg1_index < 0 || io_swing.leg2_index < 0 || io_swing.leg3_index < 0)
         return;
      if(io_swing.leg1_index >= ArraySize(legs) ||
         io_swing.leg2_index >= ArraySize(legs) ||
         io_swing.leg3_index >= ArraySize(legs))
         return;

      const MohyLegFact leg1 = legs[io_swing.leg1_index];
      const MohyLegFact leg2 = legs[io_swing.leg2_index];
      const MohyLegFact leg3 = legs[io_swing.leg3_index];
      if(leg1.begin_element_index < 0 || leg1.end_element_index < 0 ||
         leg3.begin_element_index < 0 || leg3.end_element_index < 0)
         return;
      if(leg1.begin_element_index >= ArraySize(elements) ||
         leg1.end_element_index >= ArraySize(elements) ||
         leg3.begin_element_index >= ArraySize(elements) ||
         leg3.end_element_index >= ArraySize(elements))
         return;

      const MohyElementFact leg1_begin = elements[leg1.begin_element_index];
      const MohyElementFact leg1_end = elements[leg1.end_element_index];
      const MohyElementFact leg3_begin = elements[leg3.begin_element_index];
      const MohyElementFact leg3_end = elements[leg3.end_element_index];

      if(leg1.direction == MOHY_DIR_BULL &&
         PriceGreaterOrEqual(leg3_begin.low_price, leg1_begin.low_price) &&
         PriceGreaterOrEqual(leg3_end.high_price, leg1_end.high_price))
         io_swing.pattern_type = MOHY_SWING3_PATTERN_BULLISH_ICI;
      else if(leg1.direction == MOHY_DIR_BEAR &&
              PriceGreaterOrEqual(leg3_begin.high_price, leg1_begin.high_price) &&
              PriceGreaterOrEqual(leg3_end.low_price, leg1_end.low_price))
         io_swing.pattern_type = MOHY_SWING3_PATTERN_BULLISH_CIC;
      else if(leg1.direction == MOHY_DIR_BULL &&
              PriceGreaterOrEqual(leg3_begin.low_price, leg1_begin.low_price) &&
              PriceLessOrEqual(leg3_end.high_price, leg1_end.high_price))
         io_swing.pattern_type = MOHY_SWING3_PATTERN_BULLISH_ICC;
      else if(leg1.direction == MOHY_DIR_BULL &&
              PriceLessOrEqual(leg3_begin.low_price, leg1_begin.low_price) &&
              PriceGreaterOrEqual(leg3_end.high_price, leg1_end.high_price))
         io_swing.pattern_type = MOHY_SWING3_PATTERN_BULLISH_CII;
      else if(leg1.direction == MOHY_DIR_BEAR &&
              PriceLessOrEqual(leg3_begin.high_price, leg1_begin.high_price) &&
              PriceLessOrEqual(leg3_end.low_price, leg1_end.low_price))
         io_swing.pattern_type = MOHY_SWING3_PATTERN_BEARISH_ICI;
      else if(leg1.direction == MOHY_DIR_BULL &&
              PriceLessOrEqual(leg3_begin.low_price, leg1_begin.low_price) &&
              PriceLessOrEqual(leg3_end.high_price, leg1_end.high_price))
         io_swing.pattern_type = MOHY_SWING3_PATTERN_BEARISH_CIC;
      else if(leg1.direction == MOHY_DIR_BEAR &&
              PriceLessOrEqual(leg3_begin.high_price, leg1_begin.high_price) &&
              PriceGreaterOrEqual(leg3_end.low_price, leg1_end.low_price))
         io_swing.pattern_type = MOHY_SWING3_PATTERN_BEARISH_ICC;
      else if(leg1.direction == MOHY_DIR_BEAR &&
              PriceGreaterOrEqual(leg3_begin.high_price, leg1_begin.high_price) &&
              PriceLessOrEqual(leg3_end.low_price, leg1_end.low_price))
         io_swing.pattern_type = MOHY_SWING3_PATTERN_BEARISH_CII;

      io_swing.direction = DirectionFromPattern(io_swing.pattern_type);

      bool has_prev_leg1_begin = false;
      MohyElementFact prev_leg1_begin = leg1_begin;
      if(has_previous_swing &&
         previous_swing.leg1_index >= 0 &&
         previous_swing.leg1_index < ArraySize(legs))
        {
         const MohyLegFact prev_leg1 = legs[previous_swing.leg1_index];
         if(prev_leg1.begin_element_index >= 0 &&
            prev_leg1.begin_element_index < ArraySize(elements))
           {
            prev_leg1_begin = elements[prev_leg1.begin_element_index];
            has_prev_leg1_begin = true;
           }
        }

      // Break-state and certainty resolution are close-count based.
      double breakout_reference_level = 0.0;
      int breakout_start_shift = -1;
      int breakout_end_shift = -1;
      bool want_break_above = true;
      bool has_breakout_reference = false;
      if(io_swing.pattern_type == MOHY_SWING3_PATTERN_BULLISH_ICI)
        {
         breakout_reference_level = leg1_end.high_price;
         breakout_start_shift = leg3.begin_shift;
         breakout_end_shift = leg3.end_shift;
         want_break_above = true;
         has_breakout_reference = true;
        }
      else if(io_swing.pattern_type == MOHY_SWING3_PATTERN_BULLISH_CII)
        {
         breakout_reference_level = leg1_begin.high_price;
         breakout_start_shift = leg3.begin_shift;
         breakout_end_shift = leg3.end_shift;
         want_break_above = true;
         has_breakout_reference = true;
        }
      else if(io_swing.pattern_type == MOHY_SWING3_PATTERN_BULLISH_CIC)
        {
         breakout_reference_level = leg1_begin.high_price;
         breakout_start_shift = leg2.begin_shift;
         breakout_end_shift = leg3.end_shift;
         want_break_above = true;
         has_breakout_reference = true;
        }
      else if(io_swing.pattern_type == MOHY_SWING3_PATTERN_BULLISH_ICC && has_prev_leg1_begin)
        {
         breakout_reference_level = prev_leg1_begin.high_price;
         breakout_start_shift = leg1.begin_shift;
         breakout_end_shift = leg3.end_shift;
         want_break_above = true;
         has_breakout_reference = true;
        }
      else if(io_swing.pattern_type == MOHY_SWING3_PATTERN_BEARISH_ICI)
        {
         breakout_reference_level = leg1_end.low_price;
         breakout_start_shift = leg3.begin_shift;
         breakout_end_shift = leg3.end_shift;
         want_break_above = false;
         has_breakout_reference = true;
        }
      else if(io_swing.pattern_type == MOHY_SWING3_PATTERN_BEARISH_CII)
        {
         breakout_reference_level = leg1_begin.low_price;
         breakout_start_shift = leg3.begin_shift;
         breakout_end_shift = leg3.end_shift;
         want_break_above = false;
         has_breakout_reference = true;
        }
      else if(io_swing.pattern_type == MOHY_SWING3_PATTERN_BEARISH_CIC)
        {
         breakout_reference_level = leg1_begin.low_price;
         breakout_start_shift = leg2.begin_shift;
         breakout_end_shift = leg3.end_shift;
         want_break_above = false;
         has_breakout_reference = true;
        }
      else if(io_swing.pattern_type == MOHY_SWING3_PATTERN_BEARISH_ICC && has_prev_leg1_begin)
        {
         breakout_reference_level = prev_leg1_begin.low_price;
         breakout_start_shift = leg1.begin_shift;
         breakout_end_shift = leg3.end_shift;
         want_break_above = false;
         has_breakout_reference = true;
        }

      has_breakout_reference = (has_breakout_reference &&
                                breakout_reference_level > 0.0 &&
                                breakout_start_shift >= 0 &&
                                breakout_end_shift >= 0);
      if(has_breakout_reference)
        {
         io_swing.breakout_close_count = CountClosesBeyond(symbol,
                                                           timeframe,
                                                           breakout_start_shift,
                                                           breakout_end_shift,
                                                           breakout_reference_level,
                                                           want_break_above);
         if(io_swing.breakout_close_count >= 1)
           {
            io_swing.break_state = MOHY_BREAK_STATE_BREAKOUT;
            io_swing.breakout_certainty = ResolveBreakoutCertainty(io_swing.breakout_close_count);
           }
         else
           {
            io_swing.break_state = MOHY_BREAK_STATE_NO_CLOSE_BREAK;
            io_swing.breakout_certainty = MOHY_BREAKOUT_CERTAINTY_UNKNOWN;
           }
        }

      // Correction state resolution.
      if(io_swing.pattern_type == MOHY_SWING3_PATTERN_BULLISH_CIC)
        {
         if(leg1_begin.candle_momentum == MOHY_DIR_BULL)
           {
            if(PriceLess(leg3_end.close_price, leg1_begin.close_price))
               io_swing.correction_state = MOHY_CORRECTION_STATE_BROKEBACK;
            else if(PriceLessOrEqual(leg3_end.low_price, leg1_begin.high_price))
               io_swing.correction_state = MOHY_CORRECTION_STATE_RETESTED;
            else
               io_swing.correction_state = MOHY_CORRECTION_STATE_NOT_RETESTED;
           }
         else
           {
            if(PriceLess(leg3_end.close_price, leg1_begin.open_price))
               io_swing.correction_state = MOHY_CORRECTION_STATE_BROKEBACK;
            else if(PriceLessOrEqual(leg3_end.low_price, leg1_begin.high_price))
               io_swing.correction_state = MOHY_CORRECTION_STATE_RETESTED;
            else
               io_swing.correction_state = MOHY_CORRECTION_STATE_NOT_RETESTED;
           }
        }
      else if(io_swing.pattern_type == MOHY_SWING3_PATTERN_BEARISH_CIC)
        {
         if(leg1_begin.candle_momentum == MOHY_DIR_BULL)
           {
            if(PriceGreater(leg3_end.close_price, leg1_begin.open_price))
               io_swing.correction_state = MOHY_CORRECTION_STATE_BROKEBACK;
            else if(PriceGreaterOrEqual(leg3_end.high_price, leg1_begin.low_price))
               io_swing.correction_state = MOHY_CORRECTION_STATE_RETESTED;
            else
               io_swing.correction_state = MOHY_CORRECTION_STATE_NOT_RETESTED;
           }
         else
           {
            if(PriceGreater(leg3_end.close_price, leg1_begin.close_price))
               io_swing.correction_state = MOHY_CORRECTION_STATE_BROKEBACK;
            else if(PriceGreaterOrEqual(leg3_end.high_price, leg1_begin.low_price))
               io_swing.correction_state = MOHY_CORRECTION_STATE_RETESTED;
            else
               io_swing.correction_state = MOHY_CORRECTION_STATE_NOT_RETESTED;
           }
        }
      else if(io_swing.pattern_type == MOHY_SWING3_PATTERN_BULLISH_ICC && has_prev_leg1_begin)
        {
         if(prev_leg1_begin.candle_momentum == MOHY_DIR_BULL)
            io_swing.correction_state = PriceGreater(leg3_end.close_price, prev_leg1_begin.close_price)
                                        ? MOHY_CORRECTION_STATE_RETESTED
                                        : MOHY_CORRECTION_STATE_BROKEBACK;
         else
            io_swing.correction_state = PriceGreater(leg3_end.close_price, prev_leg1_begin.open_price)
                                        ? MOHY_CORRECTION_STATE_RETESTED
                                        : MOHY_CORRECTION_STATE_BROKEBACK;
        }
      else if(io_swing.pattern_type == MOHY_SWING3_PATTERN_BEARISH_ICC && has_prev_leg1_begin)
        {
         if(prev_leg1_begin.candle_momentum == MOHY_DIR_BULL)
            io_swing.correction_state = PriceLess(leg3_end.close_price, prev_leg1_begin.open_price)
                                        ? MOHY_CORRECTION_STATE_RETESTED
                                        : MOHY_CORRECTION_STATE_BROKEBACK;
         else
            io_swing.correction_state = PriceLess(leg3_end.close_price, prev_leg1_begin.close_price)
                                        ? MOHY_CORRECTION_STATE_RETESTED
                                        : MOHY_CORRECTION_STATE_BROKEBACK;
        }
     }
  };

#endif


