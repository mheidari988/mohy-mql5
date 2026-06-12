#ifndef __MOHY_CORE_BUILDERS_SWING3_BUILDER_MQH__
#define __MOHY_CORE_BUILDERS_SWING3_BUILDER_MQH__

#include <MOHY/Core/Domain/PriceActionContracts.mqh>
#include <MOHY/Core/Classifiers/Swing3PatternClassifier.mqh>

class CMohySwing3Builder
  {
private:
   CMohySwing3PatternClassifier m_classifier;

   double Eps() const
     {
      return 1e-10;
     }

   bool ElementComesBeforeByPrice(const MohyElementFact &left,
                                  const MohyElementFact &right) const
     {
      if(left.pivot_price < right.pivot_price - Eps())
         return true;
      if(left.pivot_price > right.pivot_price + Eps())
         return false;

      // Tie-break equal prices by older pivot first for deterministic ordering.
      return (left.shift > right.shift);
     }

   void ResolveLowPair(const MohyElementFact &left_element,
                       const int left_index,
                       const MohyElementFact &right_element,
                       const int right_index,
                       int &out_lower_low_index,
                       int &out_higher_low_index) const
     {
      if(ElementComesBeforeByPrice(left_element, right_element))
        {
         out_lower_low_index = left_index;
         out_higher_low_index = right_index;
        }
      else
        {
         out_lower_low_index = right_index;
         out_higher_low_index = left_index;
        }
     }

   void ResolveHighPair(const MohyElementFact &left_element,
                        const int left_index,
                        const MohyElementFact &right_element,
                        const int right_index,
                        int &out_lower_high_index,
                        int &out_higher_high_index) const
     {
      if(ElementComesBeforeByPrice(left_element, right_element))
        {
         out_lower_high_index = left_index;
         out_higher_high_index = right_index;
        }
      else
        {
         out_lower_high_index = right_index;
         out_higher_high_index = left_index;
        }
     }

public:
   int Build(const string symbol,
             const int timeframe,
             const MohyElementFact &elements[],
             const MohyLegFact &legs[],
             MohySwing3Fact &out_swings[]) const
     {
      ArrayResize(out_swings, 0);
      const int leg_count = ArraySize(legs);
      if(leg_count < 3)
         return 0;

      int swing_count = 0;
      for(int i = 1; i < leg_count - 1; ++i)
        {
         const MohyLegFact leg1 = legs[i - 1];
         const MohyLegFact leg2 = legs[i];
         const MohyLegFact leg3 = legs[i + 1];

         const bool bull_bear_bull = (leg1.direction == MOHY_DIR_BULL &&
                                      leg2.direction == MOHY_DIR_BEAR &&
                                      leg3.direction == MOHY_DIR_BULL);
         const bool bear_bull_bear = (leg1.direction == MOHY_DIR_BEAR &&
                                      leg2.direction == MOHY_DIR_BULL &&
                                      leg3.direction == MOHY_DIR_BEAR);
         if(!bull_bear_bull && !bear_bull_bear)
            continue;

         ArrayResize(out_swings, swing_count + 1);
         out_swings[swing_count].index = swing_count;
         out_swings[swing_count].leg1_index = i - 1;
         out_swings[swing_count].leg2_index = i;
         out_swings[swing_count].leg3_index = i + 1;
         out_swings[swing_count].direction = MOHY_DIR_NONE;
         out_swings[swing_count].confirmed = (leg1.confirmed && leg2.confirmed && leg3.confirmed);
         out_swings[swing_count].pattern_type = MOHY_SWING3_PATTERN_UNKNOWN;
         out_swings[swing_count].break_state = MOHY_BREAK_STATE_UNKNOWN;
         out_swings[swing_count].breakout_certainty = MOHY_BREAKOUT_CERTAINTY_UNKNOWN;
         out_swings[swing_count].correction_state = MOHY_CORRECTION_STATE_UNKNOWN;
         out_swings[swing_count].breakout_close_count = 0;
         out_swings[swing_count].lower_low_element_index = -1;
         out_swings[swing_count].higher_low_element_index = -1;
         out_swings[swing_count].lower_high_element_index = -1;
         out_swings[swing_count].higher_high_element_index = -1;

         const int element_count = ArraySize(elements);
         if(leg1.begin_element_index < 0 || leg1.begin_element_index >= element_count ||
            leg1.end_element_index < 0 || leg1.end_element_index >= element_count ||
            leg3.begin_element_index < 0 || leg3.begin_element_index >= element_count ||
            leg3.end_element_index < 0 || leg3.end_element_index >= element_count)
            continue;

         const MohyElementFact leg1_begin = elements[leg1.begin_element_index];
         const MohyElementFact leg1_end = elements[leg1.end_element_index];
         const MohyElementFact leg3_begin = elements[leg3.begin_element_index];
         const MohyElementFact leg3_end = elements[leg3.end_element_index];

         if(bull_bear_bull)
           {
            ResolveLowPair(leg1_begin,
                           leg1.begin_element_index,
                           leg3_begin,
                           leg3.begin_element_index,
                           out_swings[swing_count].lower_low_element_index,
                           out_swings[swing_count].higher_low_element_index);
            ResolveHighPair(leg1_end,
                            leg1.end_element_index,
                            leg3_end,
                            leg3.end_element_index,
                            out_swings[swing_count].lower_high_element_index,
                            out_swings[swing_count].higher_high_element_index);
           }
         else
           {
            ResolveHighPair(leg1_begin,
                            leg1.begin_element_index,
                            leg3_begin,
                            leg3.begin_element_index,
                            out_swings[swing_count].lower_high_element_index,
                            out_swings[swing_count].higher_high_element_index);
            ResolveLowPair(leg1_end,
                           leg1.end_element_index,
                           leg3_end,
                           leg3.end_element_index,
                           out_swings[swing_count].lower_low_element_index,
                           out_swings[swing_count].higher_low_element_index);
           }

         MohySwing3Fact previous_swing;
         previous_swing.index = -1;
         previous_swing.leg1_index = -1;
         previous_swing.leg2_index = -1;
         previous_swing.leg3_index = -1;
         previous_swing.direction = MOHY_DIR_NONE;
         previous_swing.confirmed = false;
         previous_swing.pattern_type = MOHY_SWING3_PATTERN_UNKNOWN;
         previous_swing.break_state = MOHY_BREAK_STATE_UNKNOWN;
         previous_swing.breakout_certainty = MOHY_BREAKOUT_CERTAINTY_UNKNOWN;
         previous_swing.correction_state = MOHY_CORRECTION_STATE_UNKNOWN;
         previous_swing.breakout_close_count = 0;
         previous_swing.lower_low_element_index = -1;
         previous_swing.higher_low_element_index = -1;
         previous_swing.lower_high_element_index = -1;
         previous_swing.higher_high_element_index = -1;
         bool has_previous_swing = false;
         if(swing_count > 0)
           {
            previous_swing = out_swings[swing_count - 1];
            has_previous_swing = true;
           }

         m_classifier.Classify(symbol,
                               timeframe,
                               elements,
                               legs,
                               has_previous_swing,
                               previous_swing,
                               out_swings[swing_count]);
         swing_count++;
        }

      return swing_count;
     }
  };

#endif
