#ifndef __MOHY_CORE_BUILDERS_ELEMENT_BUILDER_MQH__
#define __MOHY_CORE_BUILDERS_ELEMENT_BUILDER_MQH__

#include <MOHY/Domain/Config.mqh>
#include <MOHY/Core/Domain/PriceActionContracts.mqh>
#include <MOHY/Core/Compat/TerminalSeries.mqh>

struct MohyCorePivotPoint
  {
   bool            is_high;
   bool            confirmed;
   int             shift;
   datetime        time;
   double          price;
  };

class CMohyElementBuilder
  {
private:
   DetectionConfig   m_cfg;
   int               m_timeframe;

   double  Eps() const
     {
      return 1e-10;
     }

   bool    PriceGreater(const double left,
                        const double right) const
     {
      return (left > right + Eps());
     }

   bool    PriceLess(const double left,
                     const double right) const
     {
      return (left < right - Eps());
     }

   bool    HasBar(const string symbol,
                  const int shift) const
     {
      if(shift < 0)
         return false;
      return (MohyITime(symbol, m_timeframe, shift) > 0);
     }

   int     ResolveLowerTimeframeForDualPivotOrder() const
     {
      if(m_timeframe == PERIOD_D1)
         return PERIOD_H4;
      if(m_timeframe == PERIOD_H4)
         return PERIOD_H1;
      if(m_timeframe == PERIOD_H2)
         return PERIOD_M30;
      if(m_timeframe == PERIOD_H1)
         return PERIOD_M15;
      return 0;
     }

   bool    ResolveDualPivotOrderFromLowerTimeframe(const string symbol,
                                                   const int shift,
                                                   const double high_price,
                                                   const double low_price,
                                                   bool &out_first_is_high) const
     {
      out_first_is_high = false;
      if(high_price <= 0.0 || low_price <= 0.0)
         return false;

      const int lower_timeframe = ResolveLowerTimeframeForDualPivotOrder();
      if(lower_timeframe <= 0 || lower_timeframe >= m_timeframe)
         return false;

      const datetime parent_open_time = MohyITime(symbol, m_timeframe, shift);
      if(parent_open_time <= 0)
         return false;

      datetime parent_next_open_time = MohyITime(symbol, m_timeframe, shift - 1);
      if(parent_next_open_time <= parent_open_time)
        {
         const int timeframe_minutes = MohyTimeframeToMinutes(m_timeframe);
         if(timeframe_minutes <= 0)
            return false;
         parent_next_open_time = parent_open_time + timeframe_minutes * 60;
        }
      if(parent_next_open_time <= parent_open_time)
         return false;

      int oldest_lower_shift = MohyIBarShift(symbol, lower_timeframe, parent_open_time, true);
      if(oldest_lower_shift < 0)
         oldest_lower_shift = MohyIBarShift(symbol, lower_timeframe, parent_open_time, false);

      int newest_lower_shift = MohyIBarShift(symbol, lower_timeframe, parent_next_open_time - 1, false);
      if(oldest_lower_shift < 0 || newest_lower_shift < 0)
         return false;

      if(oldest_lower_shift < newest_lower_shift)
        {
         const int swap_shift = oldest_lower_shift;
         oldest_lower_shift = newest_lower_shift;
         newest_lower_shift = swap_shift;
        }

      bool found_high = false;
      bool found_low = false;
      int first_high_shift = -1;
      int first_low_shift = -1;

      for(int lower_shift = oldest_lower_shift; lower_shift >= newest_lower_shift; --lower_shift)
        {
         const datetime lower_time = MohyITime(symbol, lower_timeframe, lower_shift);
         if(lower_time < parent_open_time || lower_time >= parent_next_open_time)
            continue;

         const double lower_high = MohyIHigh(symbol, lower_timeframe, lower_shift);
         const double lower_low = MohyILow(symbol, lower_timeframe, lower_shift);
         const bool hit_high = (lower_high >= high_price - Eps());
         const bool hit_low = (lower_low <= low_price + Eps());

         if(hit_high && !found_high)
           {
            found_high = true;
            first_high_shift = lower_shift;
           }
         if(hit_low && !found_low)
           {
            found_low = true;
            first_low_shift = lower_shift;
           }

         if(!found_high || !found_low)
            continue;

         if(first_high_shift != first_low_shift)
           {
            out_first_is_high = (first_high_shift > first_low_shift);
            return true;
           }

         const double lower_open = MohyIOpen(symbol, lower_timeframe, lower_shift);
         const double lower_close = MohyIClose(symbol, lower_timeframe, lower_shift);
         out_first_is_high = (lower_close < lower_open);
         return true;
        }

      return false;
     }

   bool    IsSwingHigh(const string symbol,
                       const int shift) const
     {
      if(!HasBar(symbol, shift))
         return false;
      const double pivot = MohyIHigh(symbol, m_timeframe, shift);
      if(pivot <= 0.0)
         return false;

      for(int i = 1; i <= m_cfg.swing_left_bars; ++i)
        {
         if(!HasBar(symbol, shift + i))
            return false;
         if(MohyIHigh(symbol, m_timeframe, shift + i) >= pivot)
            return false;
        }
      for(int i = 1; i <= m_cfg.swing_right_bars; ++i)
        {
         if(!HasBar(symbol, shift - i))
            return false;
         if(MohyIHigh(symbol, m_timeframe, shift - i) > pivot)
            return false;
        }
      return true;
     }

   bool    IsSwingLow(const string symbol,
                      const int shift) const
     {
      if(!HasBar(symbol, shift))
         return false;
      const double pivot = MohyILow(symbol, m_timeframe, shift);
      if(pivot <= 0.0)
         return false;

      for(int i = 1; i <= m_cfg.swing_left_bars; ++i)
        {
         if(!HasBar(symbol, shift + i))
            return false;
         if(MohyILow(symbol, m_timeframe, shift + i) <= pivot)
            return false;
        }
      for(int i = 1; i <= m_cfg.swing_right_bars; ++i)
        {
         if(!HasBar(symbol, shift - i))
            return false;
         if(MohyILow(symbol, m_timeframe, shift - i) < pivot)
            return false;
        }
      return true;
     }

   bool    IsProvisionalSwingHigh(const string symbol,
                                  const int shift) const
     {
      if(!HasBar(symbol, shift))
         return false;
      const double pivot = MohyIHigh(symbol, m_timeframe, shift);
      if(pivot <= 0.0)
         return false;

      for(int i = 1; i <= m_cfg.swing_left_bars; ++i)
        {
         if(!HasBar(symbol, shift + i))
            return false;
         if(MohyIHigh(symbol, m_timeframe, shift + i) >= pivot)
            return false;
        }

      for(int i = 1; i <= m_cfg.swing_right_bars; ++i)
        {
         const int right_shift = shift - i;
         if(right_shift < 0)
            break;
         if(!HasBar(symbol, right_shift))
            break;
         if(MohyIHigh(symbol, m_timeframe, right_shift) > pivot)
            return false;
        }
      return true;
     }

   bool    IsProvisionalSwingLow(const string symbol,
                                 const int shift) const
     {
      if(!HasBar(symbol, shift))
         return false;
      const double pivot = MohyILow(symbol, m_timeframe, shift);
      if(pivot <= 0.0)
         return false;

      for(int i = 1; i <= m_cfg.swing_left_bars; ++i)
        {
         if(!HasBar(symbol, shift + i))
            return false;
         if(MohyILow(symbol, m_timeframe, shift + i) <= pivot)
            return false;
        }

      for(int i = 1; i <= m_cfg.swing_right_bars; ++i)
        {
         const int right_shift = shift - i;
         if(right_shift < 0)
            break;
         if(!HasBar(symbol, right_shift))
            break;
         if(MohyILow(symbol, m_timeframe, right_shift) < pivot)
            return false;
        }
      return true;
     }

   void    AppendPivotPoint(MohyCorePivotPoint &points[],
                            const MohyCorePivotPoint &point) const
     {
      const int n = ArraySize(points);
      ArrayResize(points, n + 1);
      points[n] = point;
     }

   void    UpsertAlternatingPivotPoint(MohyCorePivotPoint &points[],
                                       const MohyCorePivotPoint &candidate) const
     {
      const int n = ArraySize(points);
      if(n <= 0)
        {
         AppendPivotPoint(points, candidate);
         return;
        }

      MohyCorePivotPoint latest = points[n - 1];
      if(latest.is_high != candidate.is_high)
        {
         AppendPivotPoint(points, candidate);
         return;
        }

      bool should_replace = false;
      if(candidate.is_high)
         should_replace = PriceGreater(candidate.price, latest.price) ||
                          (MathAbs(candidate.price - latest.price) <= Eps() &&
                           candidate.shift < latest.shift);
      else
         should_replace = PriceLess(candidate.price, latest.price) ||
                          (MathAbs(candidate.price - latest.price) <= Eps() &&
                           candidate.shift < latest.shift);

      if(should_replace)
         points[n - 1] = candidate;
     }

   int     BuildAlternatingPivotStream(const string symbol,
                                       const int from_shift,
                                       const int max_shift,
                                       const bool include_provisional_latest,
                                       MohyCorePivotPoint &out_points[]) const
     {
      ArrayResize(out_points, 0);
      if(max_shift < from_shift)
         return 0;

      const int start_shift = MathMax(from_shift, m_cfg.swing_right_bars + 1);
      for(int shift = max_shift; shift >= start_shift; --shift)
        {
         const bool has_high = IsSwingHigh(symbol, shift);
         const bool has_low = IsSwingLow(symbol, shift);
         if(!has_high && !has_low)
            continue;

         const double high_price = has_high ? MohyIHigh(symbol, m_timeframe, shift) : 0.0;
         const double low_price = has_low ? MohyILow(symbol, m_timeframe, shift) : 0.0;
         const datetime high_time = has_high ? MohyITime(symbol, m_timeframe, shift) : 0;
         const datetime low_time = has_low ? MohyITime(symbol, m_timeframe, shift) : 0;

         if(has_high && has_low)
           {
            bool first_is_high = false;
            if(!ResolveDualPivotOrderFromLowerTimeframe(symbol, shift, high_price, low_price, first_is_high))
              {
               const double candle_open = MohyIOpen(symbol, m_timeframe, shift);
               const double candle_close = MohyIClose(symbol, m_timeframe, shift);
               // Strategy fallback when lower-timeframe evidence is unavailable:
               // bearish candle -> High then Low, bullish/doji -> Low then High.
               first_is_high = (candle_close < candle_open);
              }

            MohyCorePivotPoint first_point;
            first_point.is_high = first_is_high;
            first_point.confirmed = true;
            first_point.shift = shift;
            first_point.time = first_is_high ? high_time : low_time;
            first_point.price = first_is_high ? high_price : low_price;
            UpsertAlternatingPivotPoint(out_points, first_point);

            MohyCorePivotPoint second_point;
            second_point.is_high = !first_is_high;
            second_point.confirmed = true;
            second_point.shift = shift;
            second_point.time = second_point.is_high ? high_time : low_time;
            second_point.price = second_point.is_high ? high_price : low_price;
            UpsertAlternatingPivotPoint(out_points, second_point);
            continue;
           }

         MohyCorePivotPoint point;
         point.is_high = has_high;
         point.confirmed = true;
         point.shift = shift;
         point.time = has_high ? high_time : low_time;
         point.price = has_high ? high_price : low_price;
         UpsertAlternatingPivotPoint(out_points, point);
        }

      if(include_provisional_latest)
        {
         const int bars = MohyIBars(symbol, m_timeframe);
         if(bars > m_cfg.swing_left_bars + 1)
           {
            const int oldest_provisional_shift = MathMin(m_cfg.swing_right_bars, bars - m_cfg.swing_left_bars - 1);
            for(int shift = oldest_provisional_shift; shift >= 0; --shift)
              {
               const bool has_high = IsProvisionalSwingHigh(symbol, shift);
               const bool has_low = IsProvisionalSwingLow(symbol, shift);
               if(!has_high && !has_low)
                  continue;

               const double high_price = has_high ? MohyIHigh(symbol, m_timeframe, shift) : 0.0;
               const double low_price = has_low ? MohyILow(symbol, m_timeframe, shift) : 0.0;
               const datetime high_time = has_high ? MohyITime(symbol, m_timeframe, shift) : 0;
               const datetime low_time = has_low ? MohyITime(symbol, m_timeframe, shift) : 0;

               if(has_high && has_low)
                 {
                  bool first_is_high = false;
                  if(!ResolveDualPivotOrderFromLowerTimeframe(symbol, shift, high_price, low_price, first_is_high))
                    {
                     const double candle_open = MohyIOpen(symbol, m_timeframe, shift);
                     const double candle_close = MohyIClose(symbol, m_timeframe, shift);
                     // Strategy fallback when lower-timeframe evidence is unavailable:
                     // bearish candle -> High then Low, bullish/doji -> Low then High.
                     first_is_high = (candle_close < candle_open);
                    }

                  MohyCorePivotPoint first_point;
                  first_point.is_high = first_is_high;
                  first_point.confirmed = false;
                  first_point.shift = shift;
                  first_point.time = first_is_high ? high_time : low_time;
                  first_point.price = first_is_high ? high_price : low_price;
                  UpsertAlternatingPivotPoint(out_points, first_point);

                  MohyCorePivotPoint second_point;
                  second_point.is_high = !first_is_high;
                  second_point.confirmed = false;
                  second_point.shift = shift;
                  second_point.time = second_point.is_high ? high_time : low_time;
                  second_point.price = second_point.is_high ? high_price : low_price;
                  UpsertAlternatingPivotPoint(out_points, second_point);
                  continue;
                 }

               MohyCorePivotPoint point;
               point.is_high = has_high;
               point.confirmed = false;
               point.shift = shift;
               point.time = has_high ? high_time : low_time;
               point.price = has_high ? high_price : low_price;
               UpsertAlternatingPivotPoint(out_points, point);
              }
           }
        }

      return ArraySize(out_points);
     }

   MohyDirection ResolveCandleMomentum(const double open_price,
                                       const double close_price) const
     {
      if(close_price > open_price)
         return MOHY_DIR_BULL;
      if(close_price < open_price)
         return MOHY_DIR_BEAR;
      return MOHY_DIR_NONE;
     }

public:
            CMohyElementBuilder()
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
                  const int from_shift,
                  const int max_shift,
                  MohyElementFact &out_elements[],
                  const bool include_provisional_latest = false) const
     {
      ArrayResize(out_elements, 0);
      if(symbol == "")
         return 0;
      if(max_shift < from_shift)
         return 0;

      MohyCorePivotPoint points[];
      const int point_count = BuildAlternatingPivotStream(symbol,
                                                          from_shift,
                                                          max_shift,
                                                          include_provisional_latest,
                                                          points);
      if(point_count <= 0)
         return 0;

      ArrayResize(out_elements, point_count);
      for(int i = 0; i < point_count; ++i)
        {
         const int shift = points[i].shift;
         const double open_price = MohyIOpen(symbol, m_timeframe, shift);
         const double high_price = MohyIHigh(symbol, m_timeframe, shift);
         const double low_price = MohyILow(symbol, m_timeframe, shift);
         const double close_price = MohyIClose(symbol, m_timeframe, shift);
         const bool prev_same_shift = (i > 0 && points[i - 1].shift == shift);
         const bool next_same_shift = (i + 1 < point_count && points[i + 1].shift == shift);

         out_elements[i].index = i;
         out_elements[i].shift = shift;
         out_elements[i].time = points[i].time;
         out_elements[i].type = points[i].is_high ? MOHY_ELEMENT_PEAK : MOHY_ELEMENT_VALLEY;
         out_elements[i].confirmed = points[i].confirmed;
         out_elements[i].candle_momentum = ResolveCandleMomentum(open_price, close_price);
         out_elements[i].open_price = open_price;
         out_elements[i].high_price = high_price;
         out_elements[i].low_price = low_price;
         out_elements[i].close_price = close_price;
         out_elements[i].pivot_price = points[i].price;
         out_elements[i].dual_pivot = (prev_same_shift || next_same_shift);
         if(!out_elements[i].dual_pivot)
            out_elements[i].dual_order = 0;
         else if(prev_same_shift)
            out_elements[i].dual_order = 2;
         else
            out_elements[i].dual_order = 1;
        }

      return point_count;
     }
  };

#endif


