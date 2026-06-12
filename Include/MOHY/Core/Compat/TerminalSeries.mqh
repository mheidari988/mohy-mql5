#ifndef __MOHY_CORE_COMPAT_TERMINAL_SERIES_MQH__
#define __MOHY_CORE_COMPAT_TERMINAL_SERIES_MQH__

datetime MohyITime(const string symbol,
                   const int timeframe,
                   const int shift)
  {
   return iTime(symbol, (ENUM_TIMEFRAMES)timeframe, shift);
  }

double MohyIOpen(const string symbol,
                 const int timeframe,
                 const int shift)
  {
   return iOpen(symbol, (ENUM_TIMEFRAMES)timeframe, shift);
  }

double MohyIHigh(const string symbol,
                 const int timeframe,
                 const int shift)
  {
   return iHigh(symbol, (ENUM_TIMEFRAMES)timeframe, shift);
  }

double MohyILow(const string symbol,
                const int timeframe,
                const int shift)
  {
   return iLow(symbol, (ENUM_TIMEFRAMES)timeframe, shift);
  }

double MohyIClose(const string symbol,
                  const int timeframe,
                  const int shift)
  {
   return iClose(symbol, (ENUM_TIMEFRAMES)timeframe, shift);
  }

int MohyIBars(const string symbol,
              const int timeframe)
  {
   return iBars(symbol, (ENUM_TIMEFRAMES)timeframe);
  }

int MohyISpread(const string symbol,
                const int timeframe,
                const int shift)
  {
   return iSpread(symbol, (ENUM_TIMEFRAMES)timeframe, shift);
  }

int MohyIBarShift(const string symbol,
                  const int timeframe,
                  const datetime time,
                  const bool exact)
  {
   return iBarShift(symbol, (ENUM_TIMEFRAMES)timeframe, time, exact);
  }

int MohyIHighest(const string symbol,
                 const int timeframe,
                 const int type,
                 const int count,
                 const int start)
  {
   return iHighest(symbol, (ENUM_TIMEFRAMES)timeframe, (ENUM_SERIESMODE)type, count, start);
  }

int MohyILowest(const string symbol,
                const int timeframe,
                const int type,
                const int count,
                const int start)
  {
   return iLowest(symbol, (ENUM_TIMEFRAMES)timeframe, (ENUM_SERIESMODE)type, count, start);
  }

int MohyPeriodSeconds(const int timeframe)
  {
   return PeriodSeconds((ENUM_TIMEFRAMES)timeframe);
  }

double MohyChartPriceMin(const long chart_id = 0,
                         const int sub_window = 0)
  {
   double value = 0.0;
   if(!ChartGetDouble(chart_id, CHART_PRICE_MIN, sub_window, value))
      return 0.0;
   return value;
  }

double MohyChartPriceMax(const long chart_id = 0,
                         const int sub_window = 0)
  {
   double value = 0.0;
   if(!ChartGetDouble(chart_id, CHART_PRICE_MAX, sub_window, value))
      return 0.0;
   return value;
  }

#endif
