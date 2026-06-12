#ifndef __MOHY_CORE_BUILDERS_LEG_BUILDER_MQH__
#define __MOHY_CORE_BUILDERS_LEG_BUILDER_MQH__

#include <MOHY/Core/Domain/PriceActionContracts.mqh>

class CMohyLegBuilder
  {
private:
   MohyLegType ResolveLegType(const MohyElementType begin_type,
                              const MohyElementType end_type) const
     {
      if(begin_type == MOHY_ELEMENT_VALLEY && end_type == MOHY_ELEMENT_PEAK)
         return MOHY_LEG_BULL;
      if(begin_type == MOHY_ELEMENT_PEAK && end_type == MOHY_ELEMENT_VALLEY)
         return MOHY_LEG_BEAR;
      return MOHY_LEG_NONE;
     }

   MohyDirection ResolveDirection(const MohyLegType leg_type) const
     {
      if(leg_type == MOHY_LEG_BULL)
         return MOHY_DIR_BULL;
      if(leg_type == MOHY_LEG_BEAR)
         return MOHY_DIR_BEAR;
      return MOHY_DIR_NONE;
     }

public:
   int Build(const MohyElementFact &elements[],
             MohyLegFact &out_legs[]) const
     {
      ArrayResize(out_legs, 0);
      const int element_count = ArraySize(elements);
      if(element_count < 2)
         return 0;

      int leg_count = 0;
      for(int i = 1; i < element_count; ++i)
        {
         const MohyLegType leg_type = ResolveLegType(elements[i - 1].type, elements[i].type);
         if(leg_type == MOHY_LEG_NONE)
            continue;

         ArrayResize(out_legs, leg_count + 1);
         out_legs[leg_count].index = leg_count;
         out_legs[leg_count].begin_element_index = i - 1;
         out_legs[leg_count].end_element_index = i;
         out_legs[leg_count].type = leg_type;
         out_legs[leg_count].direction = ResolveDirection(leg_type);
         out_legs[leg_count].confirmed = (elements[i - 1].confirmed && elements[i].confirmed);
         out_legs[leg_count].begin_shift = elements[i - 1].shift;
         out_legs[leg_count].begin_time = elements[i - 1].time;
         out_legs[leg_count].begin_price = elements[i - 1].pivot_price;
         out_legs[leg_count].end_shift = elements[i].shift;
         out_legs[leg_count].end_time = elements[i].time;
         out_legs[leg_count].end_price = elements[i].pivot_price;
         out_legs[leg_count].candle_count = MathAbs(elements[i - 1].shift - elements[i].shift) + 1;
         leg_count++;
        }

      return leg_count;
     }
  };

#endif
