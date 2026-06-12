//+------------------------------------------------------------------+
//| MOHY_Visualizer.mq5                                              |
//| General visualizer wrapper (starter: Peak/Valley + Legs)        |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_buffers 0

#include <MOHY/Domain/Config.mqh>
#include <MOHY/Core/Compat/TerminalSeries.mqh>
#include <MOHY/Core/PriceActionKernel.mqh>
#include <MOHY/Core/Domain/SnapshotSelectors.mqh>
#include <MOHY/Runtime/RuntimeStore.mqh>

enum MohyVisualizerRenderScope
  {
   MOHY_VIS_RENDER_PAIR_ONLY = 0,
   MOHY_VIS_RENDER_AUTO = 1,
   MOHY_VIS_RENDER_CHART_NATIVE = 2
  };

enum MohyVisualizerHistoryMode
  {
   MOHY_VIS_HISTORY_CURRENT_POTENTIAL_ONLY = 0,
   MOHY_VIS_HISTORY_LOOKBACK_HISTORY = 1
  };

enum MohyPotentialImpulseRenderMode
  {
   MOHY_POT_IMP_RENDER_HTF_ONLY = 0,
   MOHY_POT_IMP_RENDER_HTF_ON_HTF_LTF = 1,
   MOHY_POT_IMP_RENDER_ANY_TF_GTE_HTF = 2,
   MOHY_POT_IMP_RENDER_CHART_TIMEFRAME = 3
  };

enum MohyPotentialCorrectionRenderMode
  {
   MOHY_POT_CORR_RENDER_SINGLE_PATH = 0,
   MOHY_POT_CORR_RENDER_STATE_SEGMENTS = 1
  };

enum MohyContinuationSignalStartMode
  {
   MOHY_CONT_SIG_START_BROKEN_STRUCTURE = 0,
   MOHY_CONT_SIG_START_BREAKOUT = 1
  };

enum MohyStatusBlockDock
  {
   MOHY_STATUS_BLOCK_TOP_LEFT = 0,
   MOHY_STATUS_BLOCK_TOP_RIGHT = 1,
   MOHY_STATUS_BLOCK_BOTTOM_LEFT = 2,
   MOHY_STATUS_BLOCK_BOTTOM_RIGHT = 3
  };

input ENUM_TIMEFRAMES HTF = (ENUM_TIMEFRAMES)16385;
input ENUM_TIMEFRAMES LTF = (ENUM_TIMEFRAMES)15;
input int      RuntimeMagicNumber = 26021601;
input MohyVisualizerRenderScope RenderScope = MOHY_VIS_RENDER_CHART_NATIVE;
input MohyVisualizerHistoryMode HistoryMode = MOHY_VIS_HISTORY_LOOKBACK_HISTORY;
input int      LookbackBars = 1600;
input bool     ShowStatusBlock = true;
input MohyStatusBlockDock StatusBlockDock = MOHY_STATUS_BLOCK_BOTTOM_RIGHT;
input int      StatusBlockOffsetX = 20;
input color    StatusBlockTextColor = clrBlack;
input int      StatusBlockTextFontSize = 9;

input bool     PeakValleyShowLabels = true;
input string   PeakValleyPeakLabelText = "P";
input string   PeakValleyValleyLabelText = "V";
input int      PeakValleyLabelOffsetPoints = 12;
input int      PeakValleyLabelFontSize = 8;
input color    PeakValleyPeakLabelColor = 8421504;
input color    PeakValleyValleyLabelColor = 8421504;
input bool     PeakValleyShowLegLines = true;
input color    PeakValleyBullLegColor = 8421504;
input color    PeakValleyBearLegColor = 8421504;
input int      PeakValleyLegLineWidth = 1;
input int      PeakValleyLegLineStyle = 2;

input bool     PotentialImpulseEnabled = true;
input color    PotentialImpulseBullColor = 3937500;
input color    PotentialImpulseBearColor = 3937500;
input int      PotentialImpulseLineWidth = 2;
input int      PotentialImpulseLineStyle = STYLE_SOLID;
input MohyPotentialImpulseRenderMode PotentialImpulseRenderMode = MOHY_POT_IMP_RENDER_HTF_ON_HTF_LTF;
input int      PotentialImpulseMinSwingBreakoutCloses = 1;
input bool     PotentialImpulseRequireLegBreakout = true;
input int      PotentialImpulseMinLegBreakoutCloses = 1;
input bool     PotentialImpulseRequireDirectionalCandles = true;
input bool     PotentialImpulseValidateEndpointCandles = false;
input int      PotentialImpulseAllowOppositeBeginCandles = 0;
input int      PotentialImpulseAllowOppositeEndCandles = 0;
input int      PotentialImpulseMaxOppositeMiddleCandles = 0;
input bool     PotentialImpulseAllowAnyOppositeBeforeLegBreakout = true;
input double   PotentialImpulseDojiEpsilonPoints = 0.1;

input bool     PotentialCorrectionEnabled = true;
input int      PotentialCorrectionMinOppositeICICount = 1;
input MohyPotentialCorrectionMinFibLevel PotentialCorrectionMinFibLevel = MOHY_POT_CORR_MIN_FIB_0382;
input MohyLevelTriggerMode PotentialCorrectionMinFibTriggerMode = MOHY_LEVEL_TRIGGER_TOUCH;
input MohyPotentialCorrectionMaxFibLevel PotentialCorrectionMaxFibLevel = MOHY_POT_CORR_MAX_FIB_0786;
input MohyLevelTriggerMode PotentialCorrectionMaxFibTriggerMode = MOHY_LEVEL_TRIGGER_TOUCH;
input double   PotentialCorrectionExtremeTouchEpsilonPoints = 0.0;
input int      PotentialCorrectionExtremeTouchMinCount = 1;
input MohyPotentialCorrectionSupersedeDirectionMode PotentialCorrectionSupersedeDirectionMode = MOHY_POT_CORR_SUPERSEDE_DIR_OPPOSITE_ONLY;
input MohyPotentialCorrectionSupersedeScope PotentialCorrectionSupersedeScope = MOHY_POT_CORR_SUPERSEDE_SCOPE_FORMING_AND_CONFIRMED;
input MohyContinuationPlanningStartMode ContinuationPlanningStartMode = MOHY_CONT_PLAN_START_P_OR_P_STAR;
input bool     PotentialCorrectionShowLines = true;
input color    PotentialCorrectionBullColor = 3937500;
input color    PotentialCorrectionBearColor = 3937500;
input color    PotentialCorrectionInvalidatedColor = 3937500;
input int      PotentialCorrectionLineWidth = 1;
input int      PotentialCorrectionConfirmedLineStyle = 2;
input int      PotentialCorrectionFormingLineStyle = 2;
input int      PotentialCorrectionInvalidatedLineStyle = 2;
input MohyPotentialCorrectionRenderMode PotentialCorrectionRenderMode = MOHY_POT_CORR_RENDER_SINGLE_PATH;

input bool     ContinuationSignalEnabled = false;
input color    ContinuationSignalBullColor = clrGreen;
input color    ContinuationSignalBearColor = 32768;
input MohyContinuationSignalStartMode ContinuationSignalStartMode = MOHY_CONT_SIG_START_BROKEN_STRUCTURE;
input int      ContinuationSignalLineForwardBars = 1;
input int      ContinuationSignalLineWidth = 2;
input int      ContinuationSignalLineStyle = STYLE_SOLID;

input bool     TradeSetupPlanEnabled = true;
input int      TradeSetupPlanLineForwardBars = 20;
input int      TradeSetupPlanLineWidth = 3;
input int      TradeSetupPlanLineStyle = STYLE_SOLID;
input color    TradeSetupPlanEligibleColor = clrDodgerBlue;
input color    TradeSetupPlanWaitingColor = clrOrange;
input color    TradeSetupPlanInvalidColor = clrSilver;
input color    TradeSetupPlanStopColor = clrTomato;
input color    TradeSetupPlanTargetColor = clrSeaGreen;
input bool     TradeSetupPlanShowLabels = true;
input int      TradeSetupPlanLabelFontSize = 9;

input bool     HistoricalTradeSetupEnabled = true;
input bool     HistoricalTradeSetupShowLabels = true;
input int      HistoricalTradeSetupLineWidth = 3;
input int      HistoricalTradeSetupLabelFontSize = 9;
input color    HistoricalTradeSetupWaitingColor = clrOrange;
input color    HistoricalTradeSetupMissedColor = clrSilver;
input color    HistoricalTradeSetupEnteredColor = clrDodgerBlue;
input color    HistoricalTradeSetupTargetHitColor = clrSeaGreen;
input color    HistoricalTradeSetupStopHitColor = clrTomato;
input color    HistoricalTradeSetupOpenColor = clrSlateGray;

input bool     PatternRibbonEnabled = false;
input bool     PatternRibbonHighlightImpulseOnly = true;
input bool     PatternRibbonShowText = true;
input bool     PatternRibbonTextOnPatternChangeOnly = false;
input int      PatternRibbonHeightPercent = 10;
input int      PatternRibbonTextFontSize = 8;
input color    PatternRibbonBullColor = C'210,245,210';
input color    PatternRibbonBearColor = C'245,210,210';
input color    PatternRibbonMutedColor = C'230,230,230';
input color    PatternRibbonTextColor = clrDimGray;
input bool     PatternRibbonConnectorsEnabled = false;
input int      PatternRibbonConnectorWidth = 1;
input int      PatternRibbonConnectorStyle = STYLE_DOT;

input bool     PatternRibbonBullishICIVisible = true;
input bool     PatternRibbonBullishCICVisible = true;
input bool     PatternRibbonBullishICCVisible = true;
input bool     PatternRibbonBullishCIIVisible = true;
input bool     PatternRibbonBearishICIVisible = true;
input bool     PatternRibbonBearishCICVisible = true;
input bool     PatternRibbonBearishICCVisible = true;
input bool     PatternRibbonBearishCIIVisible = true;
input bool     PatternRibbonUnknownVisible = true;

StrategyConfig g_cfg;
int            g_render_timeframe = 0;
string         g_render_touched_objects[];
int            g_render_touched_count = 0;
datetime       g_setup_label_times[];
double         g_setup_label_prices[];
int            g_setup_label_count = 0;

struct MohySwingPoint
  {
   bool            is_high;
   bool            confirmed;
   int             shift;
   datetime        time;
   double          price;
  };

struct MohyRibbonPoint
  {
   datetime               end_time;
   int                    end_shift;
   bool                   confirmed;
   MohySwing3PatternType  pattern_type;
   MohyBreakState         break_state;
   MohyBreakoutCertainty  breakout_certainty;
   MohyDirection          direction;
  };

struct MohyPatternRibbonSegment
  {
   datetime               start_time;
   datetime               end_time;
   datetime               anchor_time;
   bool                   confirmed;
   MohySwing3PatternType  pattern_type;
   MohyBreakState         break_state;
   MohyBreakoutCertainty  breakout_certainty;
   MohyDirection          direction;
  };

struct MohyRenderWindow
  {
   int                    anchor_timeframe;
   int                    anchor_max_shift;
   datetime               start_time;
   datetime               end_time;
  };

struct MohyLifecycleFocus
  {
   bool                   enabled;
   bool                   runtime_joined;
   bool                   matched_snapshot_lineage;
   string                 focus_source;
   string                 scope_tag;
   string                 runtime_setup_key;
   string                 runtime_impulse_id;
   int                    impulse_index;
   int                    correction_index;
   int                    signal_index;
   int                    plan_index;
   int                    historical_index;
   datetime               start_time;
   datetime               end_time;
   datetime               render_start_time;
   datetime               render_end_time;
   MohyRuntimeLifecycleRecord runtime_record;
  };

void ResetLifecycleFocus(MohyLifecycleFocus &focus)
  {
   focus.enabled = false;
   focus.runtime_joined = false;
   focus.matched_snapshot_lineage = false;
   focus.focus_source = "None";
   focus.scope_tag = "";
   focus.runtime_setup_key = "";
   focus.runtime_impulse_id = "";
   focus.impulse_index = -1;
   focus.correction_index = -1;
   focus.signal_index = -1;
   focus.plan_index = -1;
   focus.historical_index = -1;
   focus.start_time = 0;
   focus.end_time = 0;
   focus.render_start_time = 0;
   focus.render_end_time = 0;
   MohyResetRuntimeLifecycleRecord(focus.runtime_record);
  }

bool IsLifecycleFocusMode()
  {
   return IsCurrentPotentialOnlyMode();
  }

bool IsLifecycleFocusActive(const MohyLifecycleFocus &focus)
  {
   return (IsLifecycleFocusMode() && focus.enabled);
  }

bool IsResolvedRuntimeFocusInCurrentOnly(const MohyLifecycleFocus &focus)
  {
   return (IsCurrentPotentialOnlyMode() &&
           IsLifecycleFocusActive(focus) &&
           focus.runtime_joined &&
           focus.runtime_record.lifecycle_state == MOHY_RUNTIME_LIFECYCLE_RESOLVED);
  }

string VisualizerPrefix()
  {
   return StringFormat("MOHY_VIZ_%I64d_GEN_", ChartID());
  }

string TrimText(const string value)
  {
   int start = 0;
   int end = StringLen(value) - 1;
   while(start <= end && StringGetCharacter(value, start) <= 32) start++;
   while(end >= start && StringGetCharacter(value, end) <= 32) end--;
   if(end < start) return "";
   return StringSubstr(value, start, end - start + 1);
  }

double ResolveSymbolPoint(const string symbol)
  {
   double point = 0.0;
   if(!SymbolInfoDouble(symbol, SYMBOL_POINT, point) || point <= 0.0)
      point = _Point;
   return point;
  }

int ResolveSymbolDigits(const string symbol)
  {
   long digits = 0;
   if(!SymbolInfoInteger(symbol, SYMBOL_DIGITS, digits) || digits <= 0)
      digits = _Digits;
   return (int)digits;
  }

void SetObjectText(const string name,
                   const string text,
                   const int font_size,
                   const string font_name,
                   const color text_color)
  {
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, MathMax(6, font_size));
   ObjectSetString(0, name, OBJPROP_FONT, font_name);
   ObjectSetInteger(0, name, OBJPROP_COLOR, text_color);
  }

int ResolveStatusBlockCorner(const MohyStatusBlockDock dock)
  {
   switch(dock)
     {
      case MOHY_STATUS_BLOCK_TOP_RIGHT:
         return CORNER_RIGHT_UPPER;
      case MOHY_STATUS_BLOCK_BOTTOM_LEFT:
         return CORNER_LEFT_LOWER;
      case MOHY_STATUS_BLOCK_BOTTOM_RIGHT:
         return CORNER_RIGHT_LOWER;
      case MOHY_STATUS_BLOCK_TOP_LEFT:
      default:
         return CORNER_LEFT_UPPER;
     }
  }

int ResolveStatusBlockAnchor(const int corner)
  {
   switch(corner)
     {
      case CORNER_RIGHT_UPPER:
         return ANCHOR_RIGHT_UPPER;
      case CORNER_LEFT_LOWER:
         return ANCHOR_LEFT_LOWER;
      case CORNER_RIGHT_LOWER:
         return ANCHOR_RIGHT_LOWER;
      case CORNER_LEFT_UPPER:
      default:
         return ANCHOR_LEFT_UPPER;
     }
  }

bool IsCurrentPotentialOnlyMode()
  {
   return (HistoryMode == MOHY_VIS_HISTORY_CURRENT_POTENTIAL_ONLY);
  }

bool IsImpulseSwing3Pattern(const MohySwing3PatternType pattern_type)
  {
   return (pattern_type == MOHY_SWING3_PATTERN_BULLISH_ICI ||
           pattern_type == MOHY_SWING3_PATTERN_BULLISH_CII ||
           pattern_type == MOHY_SWING3_PATTERN_BEARISH_ICI ||
           pattern_type == MOHY_SWING3_PATTERN_BEARISH_CII);
  }

bool IsBullSwing3Pattern(const MohySwing3PatternType pattern_type)
  {
   return (pattern_type == MOHY_SWING3_PATTERN_BULLISH_ICI ||
           pattern_type == MOHY_SWING3_PATTERN_BULLISH_CIC ||
           pattern_type == MOHY_SWING3_PATTERN_BULLISH_ICC ||
           pattern_type == MOHY_SWING3_PATTERN_BULLISH_CII);
  }

double ResolvePotentialImpulsePriceEpsilon()
  {
   const double point = ResolveSymbolPoint(Symbol());
   const double scale_points = MathMax(1e-10, g_cfg.detection.potential_impulse_doji_epsilon_points);
   return MathMax(1e-10, point * scale_points);
  }

bool ResolvePotentialImpulseEndpointTime(const int source_timeframe,
                                         const int draw_timeframe,
                                         const int source_shift,
                                         const double pivot_price,
                                         const bool want_high,
                                         const datetime fallback_time,
                                         datetime &out_time)
  {
   out_time = fallback_time;
   if(source_timeframe <= 0 || draw_timeframe <= 0 || source_shift < 0)
      return true;
   if(pivot_price <= 0.0 || fallback_time <= 0)
      return true;

   const int source_seconds = ResolveTimeframeSecondsSafe(source_timeframe);
   const int draw_seconds = ResolveTimeframeSecondsSafe(draw_timeframe);
   if(source_seconds <= 0 || draw_seconds <= 0)
      return true;
   if(draw_seconds >= source_seconds)
      return true;

   const datetime source_open_time = MohyITime(Symbol(), source_timeframe, source_shift);
   if(source_open_time <= 0)
      return true;

   datetime source_next_open_time = MohyITime(Symbol(), source_timeframe, source_shift - 1);
   if(source_next_open_time <= source_open_time)
      source_next_open_time = source_open_time + source_seconds;
   if(source_next_open_time <= source_open_time)
      return true;

   int oldest_draw_shift = MohyIBarShift(Symbol(), draw_timeframe, source_open_time, true);
   if(oldest_draw_shift < 0)
      oldest_draw_shift = MohyIBarShift(Symbol(), draw_timeframe, source_open_time, false);
   int newest_draw_shift = MohyIBarShift(Symbol(), draw_timeframe, source_next_open_time - 1, false);
   if(oldest_draw_shift < 0 || newest_draw_shift < 0)
      return true;

   if(oldest_draw_shift < newest_draw_shift)
     {
      const int tmp = oldest_draw_shift;
      oldest_draw_shift = newest_draw_shift;
      newest_draw_shift = tmp;
     }

   const double eps = ResolvePotentialImpulsePriceEpsilon();
   for(int shift = oldest_draw_shift; shift >= newest_draw_shift; --shift)
     {
      const datetime t = MohyITime(Symbol(), draw_timeframe, shift);
      if(t < source_open_time || t >= source_next_open_time)
         continue;

      if(want_high)
        {
         const double h = MohyIHigh(Symbol(), draw_timeframe, shift);
         if(h >= pivot_price - eps)
           {
            out_time = t;
            return true;
           }
        }
      else
        {
         const double l = MohyILow(Symbol(), draw_timeframe, shift);
         if(l <= pivot_price + eps)
           {
            out_time = t;
            return true;
           }
        }
     }

   const int count = oldest_draw_shift - newest_draw_shift + 1;
   if(count > 0)
     {
      const int extreme_shift = want_high
                                ? MohyIHighest(Symbol(), draw_timeframe, MODE_HIGH, count, newest_draw_shift)
                                : MohyILowest(Symbol(), draw_timeframe, MODE_LOW, count, newest_draw_shift);
      if(extreme_shift >= 0)
        {
         const datetime t = MohyITime(Symbol(), draw_timeframe, extreme_shift);
         if(t > 0)
            out_time = t;
        }
     }

   return true;
  }

int ResolvePotentialCorrectionLineStyle(const MohyPotentialCorrectionState state,
                                        const bool is_active)
  {
   if(state == MOHY_POT_CORR_STATE_FORMING)
      return MathMax(0, MathMin(4, PotentialCorrectionFormingLineStyle));
   if(state == MOHY_POT_CORR_STATE_INVALIDATED)
      return MathMax(0, MathMin(4, PotentialCorrectionInvalidatedLineStyle));
   return MathMax(0, MathMin(4, PotentialCorrectionConfirmedLineStyle));
  }

color ResolvePotentialCorrectionLineColor(const MohyPotentialCorrectionFact &fact,
                                          const MohyPotentialCorrectionState draw_state)
  {
   if(draw_state == MOHY_POT_CORR_STATE_INVALIDATED)
      return PotentialCorrectionInvalidatedColor;

   if(fact.impulse_direction == MOHY_DIR_BULL)
      return PotentialCorrectionBullColor;
   if(fact.impulse_direction == MOHY_DIR_BEAR)
      return PotentialCorrectionBearColor;
   return PotentialCorrectionInvalidatedColor;
  }

string Swing3PatternCode(const MohySwing3PatternType pattern_type)
  {
   switch(pattern_type)
     {
      case MOHY_SWING3_PATTERN_BULLISH_ICI:
      case MOHY_SWING3_PATTERN_BEARISH_ICI:
         return "ICI";
      case MOHY_SWING3_PATTERN_BULLISH_CIC:
      case MOHY_SWING3_PATTERN_BEARISH_CIC:
         return "CIC";
      case MOHY_SWING3_PATTERN_BULLISH_ICC:
      case MOHY_SWING3_PATTERN_BEARISH_ICC:
         return "ICC";
      case MOHY_SWING3_PATTERN_BULLISH_CII:
      case MOHY_SWING3_PATTERN_BEARISH_CII:
         return "CII";
      default:
         break;
     }
   return "UNK";
  }

string Swing3PatternLabel(const MohySwing3PatternType pattern_type,
                          const MohyDirection direction)
  {
   const string code = Swing3PatternCode(pattern_type);
   if(code == "UNK")
      return "Unknown";
   if(direction == MOHY_DIR_BULL)
      return StringFormat("Bull %s", code);
   if(direction == MOHY_DIR_BEAR)
      return StringFormat("Bear %s", code);
   return code;
  }

color ResolvePatternRibbonColor(const MohySwing3PatternType pattern_type)
  {
   if(pattern_type == MOHY_SWING3_PATTERN_UNKNOWN)
      return PatternRibbonMutedColor;

   if(PatternRibbonHighlightImpulseOnly && !IsImpulseSwing3Pattern(pattern_type))
      return PatternRibbonMutedColor;

   return IsBullSwing3Pattern(pattern_type) ? PatternRibbonBullColor : PatternRibbonBearColor;
  }

bool IsPatternRibbonPatternVisible(const MohySwing3PatternType pattern_type)
  {
   switch(pattern_type)
     {
      case MOHY_SWING3_PATTERN_BULLISH_ICI:
         return PatternRibbonBullishICIVisible;
      case MOHY_SWING3_PATTERN_BULLISH_CIC:
         return PatternRibbonBullishCICVisible;
      case MOHY_SWING3_PATTERN_BULLISH_ICC:
         return PatternRibbonBullishICCVisible;
      case MOHY_SWING3_PATTERN_BULLISH_CII:
         return PatternRibbonBullishCIIVisible;
      case MOHY_SWING3_PATTERN_BEARISH_ICI:
         return PatternRibbonBearishICIVisible;
      case MOHY_SWING3_PATTERN_BEARISH_CIC:
         return PatternRibbonBearishCICVisible;
      case MOHY_SWING3_PATTERN_BEARISH_ICC:
         return PatternRibbonBearishICCVisible;
      case MOHY_SWING3_PATTERN_BEARISH_CII:
         return PatternRibbonBearishCIIVisible;
      case MOHY_SWING3_PATTERN_UNKNOWN:
         return PatternRibbonUnknownVisible;
      default:
         return true;
     }
  }

bool IsVisualizerObjectName(const string name)
  {
   if(name == "")
      return false;
   return (StringFind(name, VisualizerPrefix(), 0) == 0);
  }

void BeginRenderObjectTracking()
  {
   ArrayResize(g_render_touched_objects, 0);
   g_render_touched_count = 0;
   ArrayResize(g_setup_label_times, 0);
   ArrayResize(g_setup_label_prices, 0);
   g_setup_label_count = 0;
  }

bool IsTouchedRenderObject(const string name)
  {
   for(int i = 0; i < g_render_touched_count; ++i)
      if(g_render_touched_objects[i] == name)
         return true;
   return false;
  }

void TouchRenderObject(const string name)
  {
   if(!IsVisualizerObjectName(name))
      return;
   if(IsTouchedRenderObject(name))
      return;

   ArrayResize(g_render_touched_objects, g_render_touched_count + 1);
   g_render_touched_objects[g_render_touched_count] = name;
   g_render_touched_count++;
  }

void DeleteUntouchedVisualizerObjects()
  {
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; --i)
     {
      const string name = ObjectName(0, i, -1, -1);
      if(!IsVisualizerObjectName(name))
         continue;
      if(!IsTouchedRenderObject(name))
         ObjectDelete(0, name);
     }
  }

void DeleteVisualizerObjects()
  {
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; --i)
     {
      const string name = ObjectName(0, i, -1, -1);
      if(IsVisualizerObjectName(name))
         ObjectDelete(0, name);
     }
  }

bool ResolveTimeframePair(const int htf,
                          const int ltf,
                          MohyTimeframePair &out_pair)
  {
   return MohyResolveTimeframePairFromFrames(htf, ltf, out_pair);
  }

int ResolveRenderTimeframe(const int chart_timeframe,
                           const int htf,
                           const int ltf)
  {
   if(RenderScope == MOHY_VIS_RENDER_PAIR_ONLY)
     {
      if(chart_timeframe == htf || chart_timeframe == ltf)
         return chart_timeframe;
      return 0;
     }

   if(RenderScope == MOHY_VIS_RENDER_CHART_NATIVE)
      return (chart_timeframe > 0) ? chart_timeframe : htf;

   const int chart_seconds = MohyPeriodSeconds(chart_timeframe);
   const int ltf_seconds = MohyPeriodSeconds(ltf);
   const int htf_seconds = MohyPeriodSeconds(htf);
   if(chart_seconds <= 0 || ltf_seconds <= 0 || htf_seconds <= 0)
      return htf;

   if(chart_seconds <= ltf_seconds)
      return ltf;
   if(chart_seconds >= htf_seconds)
      return htf;
   return chart_timeframe;
  }

int ResolveTimeframeSecondsSafe(const int timeframe)
  {
   const int seconds = MohyPeriodSeconds(timeframe);
   if(seconds > 0)
      return seconds;
   const int minutes = MohyTimeframeToMinutes(timeframe);
   if(minutes > 0)
      return minutes * 60;
   return 0;
  }

bool ResolveRenderWindow(const int anchor_timeframe,
                         MohyRenderWindow &out_window)
  {
   out_window.anchor_timeframe = anchor_timeframe;
   out_window.anchor_max_shift = -1;
   out_window.start_time = 0;
   out_window.end_time = 0;
   if(anchor_timeframe <= 0)
      return false;

   const int bars = MohyIBars(Symbol(), anchor_timeframe);
   if(bars <= g_cfg.detection.swing_right_bars + 2)
      return false;

   out_window.anchor_max_shift = MathMin(MathMax(20, LookbackBars), bars - 2);
   if(out_window.anchor_max_shift < 1)
      return false;

   out_window.start_time = MohyITime(Symbol(), anchor_timeframe, out_window.anchor_max_shift);
   out_window.end_time = MohyITime(Symbol(), anchor_timeframe, 0);
   if(out_window.end_time <= 0)
      out_window.end_time = TimeCurrent();
   return (out_window.start_time > 0);
  }

int ResolveSourceMaxShiftFromWindow(const int timeframe,
                                    const MohyRenderWindow &window)
  {
   if(timeframe <= 0)
      return -1;

   const int bars = MohyIBars(Symbol(), timeframe);
   const int from_shift = g_cfg.detection.swing_right_bars + 1;
   const int max_available_shift = bars - g_cfg.detection.swing_right_bars - 2;
   if(max_available_shift < from_shift)
      return -1;

   if(window.start_time <= 0)
      return MathMin(MathMax(20, LookbackBars), max_available_shift);

   int mapped_shift = MohyIBarShift(Symbol(), timeframe, window.start_time, false);
   if(mapped_shift < 0)
      mapped_shift = max_available_shift;

   return MathMin(max_available_shift, MathMax(from_shift, mapped_shift));
  }

datetime ResolveCorrectionDisplayBeginTime(const MohyPotentialCorrectionFact &fact)
  {
   if(fact.visual_begin_time > 0)
      return fact.visual_begin_time;
   if(fact.reference_begin_time > 0)
      return fact.reference_begin_time;
   return fact.begin_time;
  }

string ResolveLifecycleFocusScopeTag()
  {
   return MohyRuntimeBuildScopeTag(Symbol(),
                                   g_cfg.context_timeframe,
                                   g_cfg.execution_timeframe,
                                   g_cfg.risk.magic_number);
  }

int ResolveRuntimeLifecyclePriority(const MohyRuntimeLifecycleRecord &record)
  {
   if(record.lifecycle_state == MOHY_RUNTIME_LIFECYCLE_OPEN)
      return 3;
   if(record.lifecycle_state == MOHY_RUNTIME_LIFECYCLE_WAITING)
      return 2;
   if(record.lifecycle_state == MOHY_RUNTIME_LIFECYCLE_RESOLVED)
      return 1;
   return 0;
  }

datetime ResolveRuntimeLifecycleSortTime(const MohyRuntimeLifecycleRecord &record)
  {
   if(record.lifecycle_state == MOHY_RUNTIME_LIFECYCLE_RESOLVED)
     {
      if(record.resolved_time > 0)
         return record.resolved_time;
      if(record.last_event_time > 0)
         return record.last_event_time;
      if(record.opened_time > 0)
         return record.opened_time;
      return record.waiting_since;
     }

   if(record.lifecycle_state == MOHY_RUNTIME_LIFECYCLE_OPEN)
     {
      if(record.last_event_time > 0)
         return record.last_event_time;
      if(record.opened_time > 0)
         return record.opened_time;
      return record.waiting_since;
     }

   if(record.lifecycle_state == MOHY_RUNTIME_LIFECYCLE_WAITING)
     {
      if(record.last_event_time > 0)
         return record.last_event_time;
      return record.waiting_since;
     }

   return record.last_event_time;
  }

bool SelectBestRuntimeLifecycleRecord(const MohyRuntimeLifecycleRecord &rows[],
                                      MohyRuntimeLifecycleRecord &out_record)
  {
   MohyResetRuntimeLifecycleRecord(out_record);

   bool found = false;
   int best_priority = -1;
   datetime best_time = 0;
   for(int i = 0; i < ArraySize(rows); ++i)
     {
      if(rows[i].setup_key == "")
         continue;

      const int priority = ResolveRuntimeLifecyclePriority(rows[i]);
      const datetime candidate_time = ResolveRuntimeLifecycleSortTime(rows[i]);
      if(!found ||
         priority > best_priority ||
         (priority == best_priority && candidate_time > best_time) ||
         (priority == best_priority &&
          candidate_time == best_time &&
          rows[i].last_event_time > out_record.last_event_time))
        {
         out_record = rows[i];
         best_priority = priority;
         best_time = candidate_time;
         found = true;
        }
     }

   return found;
  }

datetime ResolveHistoricalTradeSetupSortTime(const MohyHistoricalTradeSetupFact &fact)
  {
   if(fact.exit_time > 0)
      return fact.exit_time;
   if(fact.entry_time > 0)
      return fact.entry_time;
   return fact.setup_time;
  }

bool IsTradeSetupPlanStateCurrentPotential(const MohyTradeSetupPlanState state)
  {
   return (state != MOHY_TRADE_SETUP_PLAN_INVALIDATED);
  }

bool IsHistoricalTradeSetupCurrentPotential(const MohyHistoricalTradeSetupFact &fact)
  {
   if(!fact.valid)
      return false;
   if(fact.outcome == MOHY_HIST_SETUP_OUTCOME_WAITING ||
      fact.outcome == MOHY_HIST_SETUP_OUTCOME_OPEN)
      return true;
   if(fact.outcome == MOHY_HIST_SETUP_OUTCOME_ENTERED && fact.exit_time <= 0)
      return true;
   return (fact.entered && fact.exit_time <= 0);
  }

int FindCurrentPotentialHistoricalTradeSetupIndexBySetupKey(const CMohyPriceActionSnapshot &snapshot,
                                                            const string setup_key)
  {
   if(setup_key == "")
      return -1;

   int selected_index = -1;
   for(int i = 0; i < ArraySize(snapshot.historical_trade_setups); ++i)
     {
      const MohyHistoricalTradeSetupFact fact = snapshot.historical_trade_setups[i];
      if(!IsHistoricalTradeSetupCurrentPotential(fact) ||
         fact.runtime_setup_key != setup_key)
         continue;

      if(selected_index < 0 ||
         ResolveHistoricalTradeSetupSortTime(fact) >
         ResolveHistoricalTradeSetupSortTime(snapshot.historical_trade_setups[selected_index]))
         selected_index = i;
     }

   return selected_index;
  }

bool SnapshotHasCurrentPotentialLifecycleEvidence(const CMohyPriceActionSnapshot &snapshot,
                                                  const MohyLifecycleFocus &focus)
  {
   if(focus.correction_index >= 0 &&
      focus.correction_index < ArraySize(snapshot.potential_corrections))
     {
      const MohyPotentialCorrectionFact correction = snapshot.potential_corrections[focus.correction_index];
      if(correction.valid && correction.is_active)
         return true;
     }

   if(focus.plan_index >= 0 &&
      focus.plan_index < ArraySize(snapshot.trade_setup_plans))
     {
      const MohyTradeSetupPlanFact plan = snapshot.trade_setup_plans[focus.plan_index];
      if(plan.valid && IsTradeSetupPlanStateCurrentPotential(plan.plan_state))
         return true;
     }

   if(focus.signal_index >= 0 &&
      focus.signal_index < ArraySize(snapshot.potential_continuation_signals))
     {
      const MohyPotentialContinuationSignalFact signal = snapshot.potential_continuation_signals[focus.signal_index];
      if(signal.valid)
        {
         if(signal.linked_correction_is_active)
            return true;
         if(signal.linked_potential_correction_index >= 0 &&
            signal.linked_potential_correction_index < ArraySize(snapshot.potential_corrections) &&
            snapshot.potential_corrections[signal.linked_potential_correction_index].valid &&
            snapshot.potential_corrections[signal.linked_potential_correction_index].is_active)
            return true;
        }
     }

   if(focus.historical_index >= 0 &&
      focus.historical_index < ArraySize(snapshot.historical_trade_setups) &&
      IsHistoricalTradeSetupCurrentPotential(snapshot.historical_trade_setups[focus.historical_index]))
      return true;

   if(focus.runtime_setup_key != "" &&
      FindCurrentPotentialHistoricalTradeSetupIndexBySetupKey(snapshot,
                                                              focus.runtime_setup_key) >= 0)
      return true;

   if(focus.runtime_impulse_id != "")
     {
      const int active_correction_index = MohyFindPotentialCorrectionIndexByRuntimeImpulseId(snapshot,
                                                                                              focus.runtime_impulse_id,
                                                                                              true);
      if(active_correction_index >= 0 &&
         active_correction_index < ArraySize(snapshot.potential_corrections) &&
         snapshot.potential_corrections[active_correction_index].valid &&
         snapshot.potential_corrections[active_correction_index].is_active)
         return true;
     }

   return false;
  }

int FindPotentialImpulseIndexByRuntimeImpulseId(const CMohyPriceActionSnapshot &snapshot,
                                                const string impulse_id)
  {
   return MohyFindPotentialImpulseIndexByRuntimeImpulseId(snapshot, impulse_id);
  }

int FindPotentialCorrectionIndexByRuntimeImpulseId(const CMohyPriceActionSnapshot &snapshot,
                                                   const string impulse_id)
  {
   return MohyFindPotentialCorrectionIndexByRuntimeImpulseId(snapshot,
                                                             impulse_id,
                                                             false);
  }

int FindPotentialContinuationSignalIndexBySetupKey(const CMohyPriceActionSnapshot &snapshot,
                                                   const string setup_key)
  {
   return MohyFindPotentialContinuationSignalIndexBySetupKey(snapshot, setup_key);
  }

int FindTradeSetupPlanIndexBySetupKey(const CMohyPriceActionSnapshot &snapshot,
                                      const string setup_key)
  {
   return MohyFindTradeSetupPlanIndexBySetupKey(snapshot, setup_key);
  }

int FindHistoricalTradeSetupIndexBySetupKey(const CMohyPriceActionSnapshot &snapshot,
                                            const string setup_key)
  {
   if(setup_key == "")
      return -1;

   int selected_index = -1;
   for(int i = 0; i < ArraySize(snapshot.historical_trade_setups); ++i)
     {
      const MohyHistoricalTradeSetupFact fact = snapshot.historical_trade_setups[i];
      if(!fact.valid || fact.runtime_setup_key != setup_key)
         continue;

      if(selected_index < 0 ||
         ResolveHistoricalTradeSetupSortTime(fact) >
         ResolveHistoricalTradeSetupSortTime(snapshot.historical_trade_setups[selected_index]))
         selected_index = i;
     }

   return selected_index;
  }

int SelectHistoricalTradeSetupIndex(const CMohyPriceActionSnapshot &snapshot,
                                    const int preferred_plan_index,
                                    const int preferred_signal_index,
                                    const int preferred_correction_index)
  {
   int selected_index = -1;
   for(int i = 0; i < ArraySize(snapshot.historical_trade_setups); ++i)
     {
      const MohyHistoricalTradeSetupFact fact = snapshot.historical_trade_setups[i];
      if(!fact.valid)
         continue;
      if(preferred_plan_index >= 0 && fact.linked_trade_setup_plan_index != preferred_plan_index)
         continue;
      if(preferred_signal_index >= 0 &&
         fact.linked_potential_continuation_signal_index != preferred_signal_index)
         continue;
      if(preferred_correction_index >= 0 &&
         fact.linked_potential_correction_index != preferred_correction_index)
         continue;

      if(selected_index < 0 ||
         ResolveHistoricalTradeSetupSortTime(fact) >
         ResolveHistoricalTradeSetupSortTime(snapshot.historical_trade_setups[selected_index]))
         selected_index = i;
     }

   return selected_index;
  }

int ResolveLifecycleImpulseIndex(const CMohyPriceActionSnapshot &snapshot,
                                 const int plan_index,
                                 const int signal_index,
                                 const int historical_index,
                                 const string impulse_id)
  {
   if(plan_index >= 0 &&
      plan_index < ArraySize(snapshot.trade_setup_plans) &&
      snapshot.trade_setup_plans[plan_index].linked_potential_impulse_index >= 0 &&
      snapshot.trade_setup_plans[plan_index].linked_potential_impulse_index < ArraySize(snapshot.potential_impulses))
      return snapshot.trade_setup_plans[plan_index].linked_potential_impulse_index;

   if(historical_index >= 0 &&
      historical_index < ArraySize(snapshot.historical_trade_setups) &&
      snapshot.historical_trade_setups[historical_index].linked_potential_impulse_index >= 0 &&
      snapshot.historical_trade_setups[historical_index].linked_potential_impulse_index < ArraySize(snapshot.potential_impulses))
      return snapshot.historical_trade_setups[historical_index].linked_potential_impulse_index;

   if(signal_index >= 0 &&
      signal_index < ArraySize(snapshot.potential_continuation_signals) &&
      snapshot.potential_continuation_signals[signal_index].linked_potential_impulse_index >= 0 &&
      snapshot.potential_continuation_signals[signal_index].linked_potential_impulse_index < ArraySize(snapshot.potential_impulses))
      return snapshot.potential_continuation_signals[signal_index].linked_potential_impulse_index;

   return FindPotentialImpulseIndexByRuntimeImpulseId(snapshot, impulse_id);
  }

int ResolveLifecycleCorrectionIndex(const CMohyPriceActionSnapshot &snapshot,
                                    const int plan_index,
                                    const int signal_index,
                                    const int historical_index,
                                    const string impulse_id)
  {
   if(plan_index >= 0 &&
      plan_index < ArraySize(snapshot.trade_setup_plans) &&
      snapshot.trade_setup_plans[plan_index].linked_potential_correction_index >= 0 &&
      snapshot.trade_setup_plans[plan_index].linked_potential_correction_index < ArraySize(snapshot.potential_corrections))
      return snapshot.trade_setup_plans[plan_index].linked_potential_correction_index;

   if(historical_index >= 0 &&
      historical_index < ArraySize(snapshot.historical_trade_setups) &&
      snapshot.historical_trade_setups[historical_index].linked_potential_correction_index >= 0 &&
      snapshot.historical_trade_setups[historical_index].linked_potential_correction_index < ArraySize(snapshot.potential_corrections))
      return snapshot.historical_trade_setups[historical_index].linked_potential_correction_index;

   if(signal_index >= 0 &&
      signal_index < ArraySize(snapshot.potential_continuation_signals) &&
      snapshot.potential_continuation_signals[signal_index].linked_potential_correction_index >= 0 &&
      snapshot.potential_continuation_signals[signal_index].linked_potential_correction_index < ArraySize(snapshot.potential_corrections))
      return snapshot.potential_continuation_signals[signal_index].linked_potential_correction_index;

   return FindPotentialCorrectionIndexByRuntimeImpulseId(snapshot, impulse_id);
  }

int SelectPotentialCorrectionIndex(const CMohyPriceActionSnapshot &snapshot,
                                   const bool active_only)
  {
   return MohySelectPotentialCorrectionIndex(snapshot, active_only);
  }

int SelectPotentialImpulseIndex(const CMohyPriceActionSnapshot &snapshot)
  {
   return MohySelectPotentialImpulseIndex(snapshot);
  }

int SelectPotentialContinuationSignalIndex(const CMohyPriceActionSnapshot &snapshot,
                                           const int preferred_correction_index)
  {
   return MohySelectPotentialContinuationSignalIndex(snapshot, preferred_correction_index);
  }

int SelectTradeSetupPlanIndex(const CMohyPriceActionSnapshot &snapshot,
                              const int preferred_correction_index)
  {
   return MohySelectTradeSetupPlanIndex(snapshot, preferred_correction_index);
  }

datetime ResolveCurrentFocusStartTime(const CMohyPriceActionSnapshot &snapshot)
  {
   int correction_index = SelectPotentialCorrectionIndex(snapshot, true);
   if(correction_index < 0)
      correction_index = SelectPotentialCorrectionIndex(snapshot, false);
   if(correction_index >= 0)
      return ResolveCorrectionDisplayBeginTime(snapshot.potential_corrections[correction_index]);

   const int plan_index = SelectTradeSetupPlanIndex(snapshot, -1);
   if(plan_index >= 0)
     {
      const MohyTradeSetupPlanFact plan = snapshot.trade_setup_plans[plan_index];
      if(plan.linked_potential_correction_index >= 0 &&
         plan.linked_potential_correction_index < ArraySize(snapshot.potential_corrections))
         return ResolveCorrectionDisplayBeginTime(snapshot.potential_corrections[plan.linked_potential_correction_index]);

      if(plan.linked_potential_continuation_signal_index >= 0 &&
         plan.linked_potential_continuation_signal_index < ArraySize(snapshot.potential_continuation_signals))
        {
         const MohyPotentialContinuationSignalFact signal =
            snapshot.potential_continuation_signals[plan.linked_potential_continuation_signal_index];
         if(signal.broken_level_time > 0)
            return signal.broken_level_time;
         if(signal.signal_time > 0)
            return signal.signal_time;
        }
     }

   const int signal_index = SelectPotentialContinuationSignalIndex(snapshot, -1);
   if(signal_index >= 0)
     {
      const MohyPotentialContinuationSignalFact signal = snapshot.potential_continuation_signals[signal_index];
      if(signal.broken_level_time > 0)
         return signal.broken_level_time;
      if(signal.signal_time > 0)
         return signal.signal_time;
     }

   const int impulse_index = SelectPotentialImpulseIndex(snapshot);
   if(impulse_index >= 0)
      return snapshot.potential_impulses[impulse_index].begin_time;

   const int swing_count = ArraySize(snapshot.swings3);
   if(swing_count > 0)
     {
      const MohySwing3Fact swing = snapshot.swings3[swing_count - 1];
      if(swing.leg1_index >= 0 && swing.leg1_index < ArraySize(snapshot.legs))
         return snapshot.legs[swing.leg1_index].begin_time;
      if(swing.leg3_index >= 0 && swing.leg3_index < ArraySize(snapshot.legs))
         return snapshot.legs[swing.leg3_index].end_time;
     }

   const int element_count = ArraySize(snapshot.elements);
   if(element_count > 0)
      return snapshot.elements[element_count - 1].time;

   return 0;
  }

datetime ResolveLifecycleStartTimeFromSnapshot(const CMohyPriceActionSnapshot &snapshot,
                                               const MohyLifecycleFocus &focus)
  {
   if(focus.impulse_index >= 0 && focus.impulse_index < ArraySize(snapshot.potential_impulses))
      return snapshot.potential_impulses[focus.impulse_index].begin_time;

   if(focus.correction_index >= 0 && focus.correction_index < ArraySize(snapshot.potential_corrections))
     {
      const MohyPotentialCorrectionFact correction = snapshot.potential_corrections[focus.correction_index];
      if(correction.linked_potential_impulse_index >= 0 &&
         correction.linked_potential_impulse_index < ArraySize(snapshot.potential_impulses))
         return snapshot.potential_impulses[correction.linked_potential_impulse_index].begin_time;
      const datetime correction_begin = ResolveCorrectionDisplayBeginTime(correction);
      if(correction_begin > 0)
         return correction_begin;
     }

   if(focus.historical_index >= 0 && focus.historical_index < ArraySize(snapshot.historical_trade_setups))
     {
      const MohyHistoricalTradeSetupFact fact = snapshot.historical_trade_setups[focus.historical_index];
      if(fact.linked_potential_impulse_index >= 0 &&
         fact.linked_potential_impulse_index < ArraySize(snapshot.potential_impulses))
         return snapshot.potential_impulses[fact.linked_potential_impulse_index].begin_time;
      if(fact.setup_time > 0)
         return fact.setup_time;
     }

   if(focus.plan_index >= 0 && focus.plan_index < ArraySize(snapshot.trade_setup_plans))
     {
      const MohyTradeSetupPlanFact plan = snapshot.trade_setup_plans[focus.plan_index];
      if(plan.linked_potential_impulse_index >= 0 &&
         plan.linked_potential_impulse_index < ArraySize(snapshot.potential_impulses))
         return snapshot.potential_impulses[plan.linked_potential_impulse_index].begin_time;
      if(plan.setup_time > 0)
         return plan.setup_time;
     }

   if(focus.signal_index >= 0 && focus.signal_index < ArraySize(snapshot.potential_continuation_signals))
     {
      const MohyPotentialContinuationSignalFact signal = snapshot.potential_continuation_signals[focus.signal_index];
      if(signal.linked_potential_impulse_index >= 0 &&
         signal.linked_potential_impulse_index < ArraySize(snapshot.potential_impulses))
         return snapshot.potential_impulses[signal.linked_potential_impulse_index].begin_time;
      if(signal.broken_level_time > 0)
         return signal.broken_level_time;
      if(signal.signal_time > 0)
         return signal.signal_time;
     }

   return ResolveCurrentFocusStartTime(snapshot);
  }

datetime ResolveHistoricalLifecycleEndTime(const MohyHistoricalTradeSetupFact &fact,
                                           const MohyRenderWindow &window)
  {
   if(fact.exit_time > 0)
      return fact.exit_time;
   if(fact.outcome == MOHY_HIST_SETUP_OUTCOME_OPEN ||
      fact.outcome == MOHY_HIST_SETUP_OUTCOME_WAITING)
      return (window.end_time > 0) ? window.end_time : TimeCurrent();
   if(fact.entry_time > 0)
      return fact.entry_time;
   return fact.setup_time;
  }

datetime ResolveKernelFallbackLifecycleEndTime(const CMohyPriceActionSnapshot &snapshot,
                                               const MohyLifecycleFocus &focus,
                                               const MohyRenderWindow &window)
  {
   const datetime window_end_time = (window.end_time > 0) ? window.end_time : TimeCurrent();
   if(focus.correction_index >= 0 && focus.correction_index < ArraySize(snapshot.potential_corrections))
     {
      const MohyPotentialCorrectionFact correction = snapshot.potential_corrections[focus.correction_index];
      // Keep current-only focus alive while the selected correction lineage is still active.
      if(correction.is_active)
         return window_end_time;
      if(correction.invalidated_time > 0)
         return correction.invalidated_time;
      if(correction.end_time > 0)
         return correction.end_time;
     }

   if(focus.historical_index >= 0 && focus.historical_index < ArraySize(snapshot.historical_trade_setups))
      return ResolveHistoricalLifecycleEndTime(snapshot.historical_trade_setups[focus.historical_index], window);

   if(focus.plan_index >= 0 && focus.plan_index < ArraySize(snapshot.trade_setup_plans))
     {
      const MohyTradeSetupPlanFact plan = snapshot.trade_setup_plans[focus.plan_index];
      if(plan.plan_state == MOHY_TRADE_SETUP_PLAN_INVALIDATED && plan.setup_time > 0)
         return plan.setup_time;
     }

   if(focus.signal_index >= 0 && focus.signal_index < ArraySize(snapshot.potential_continuation_signals))
     {
      const MohyPotentialContinuationSignalFact signal = snapshot.potential_continuation_signals[focus.signal_index];
      if(signal.signal_time > 0)
         return window_end_time;
     }

   return window_end_time;
  }

void FinalizeLifecycleRenderBounds(MohyLifecycleFocus &focus,
                                   const MohyRenderWindow &window)
  {
   datetime window_start = window.start_time;
   datetime window_end = window.end_time;
   if(window_end <= 0)
      window_end = TimeCurrent();

   focus.render_start_time = window_start;
   if(focus.start_time > 0 && focus.start_time > focus.render_start_time)
      focus.render_start_time = focus.start_time;

   focus.render_end_time = window_end;
   if(focus.end_time > 0 &&
      (focus.render_end_time <= 0 || focus.end_time < focus.render_end_time))
      focus.render_end_time = focus.end_time;

   if(focus.render_end_time > 0 && focus.render_start_time > focus.render_end_time)
      focus.render_start_time = focus.render_end_time;
  }

bool ResolveLifecycleFocus(const CMohyPriceActionSnapshot &snapshot,
                           const MohyRenderWindow &window,
                           MohyLifecycleFocus &out_focus)
  {
   ResetLifecycleFocus(out_focus);
   if(!IsLifecycleFocusMode())
      return false;

   out_focus.scope_tag = ResolveLifecycleFocusScopeTag();

   MohyRuntimeLifecycleRecord runtime_rows[];
   CMohyRuntimeStore runtime_store;
   runtime_store.Configure(out_focus.scope_tag);
   if(runtime_store.LoadLifecycleRecords(runtime_rows) &&
      SelectBestRuntimeLifecycleRecord(runtime_rows, out_focus.runtime_record))
     {
      out_focus.runtime_joined = true;
      out_focus.focus_source = "RuntimeLifecycle";
      out_focus.runtime_setup_key = out_focus.runtime_record.setup_key;
      out_focus.runtime_impulse_id = out_focus.runtime_record.impulse_id;
      const bool runtime_resolved_in_current_only =
         (IsCurrentPotentialOnlyMode() &&
          out_focus.runtime_record.lifecycle_state == MOHY_RUNTIME_LIFECYCLE_RESOLVED);
      if(runtime_resolved_in_current_only)
        {
         // Keep current-only mode anchored to runtime resolution instead of
         // falling back to fresh kernel candidates after invalidation.
         out_focus.plan_index = -1;
         out_focus.signal_index = -1;
         out_focus.historical_index = -1;
         out_focus.impulse_index = -1;
         out_focus.correction_index = -1;
         if(out_focus.runtime_record.waiting_since > 0)
            out_focus.start_time = out_focus.runtime_record.waiting_since;
         else if(out_focus.runtime_record.last_event_time > 0)
            out_focus.start_time = out_focus.runtime_record.last_event_time;
         else
            out_focus.start_time = out_focus.runtime_record.resolved_time;
        }
      else
        {
         out_focus.plan_index = FindTradeSetupPlanIndexBySetupKey(snapshot, out_focus.runtime_setup_key);
         out_focus.signal_index = FindPotentialContinuationSignalIndexBySetupKey(snapshot, out_focus.runtime_setup_key);
         out_focus.historical_index = IsCurrentPotentialOnlyMode()
                                      ? -1
                                      : FindHistoricalTradeSetupIndexBySetupKey(snapshot, out_focus.runtime_setup_key);
         out_focus.impulse_index = ResolveLifecycleImpulseIndex(snapshot,
                                                                out_focus.plan_index,
                                                                out_focus.signal_index,
                                                                out_focus.historical_index,
                                                                out_focus.runtime_impulse_id);
         out_focus.correction_index = ResolveLifecycleCorrectionIndex(snapshot,
                                                                      out_focus.plan_index,
                                                                      out_focus.signal_index,
                                                                      out_focus.historical_index,
                                                                      out_focus.runtime_impulse_id);
         out_focus.start_time = ResolveLifecycleStartTimeFromSnapshot(snapshot, out_focus);
        }

      if(out_focus.runtime_record.lifecycle_state == MOHY_RUNTIME_LIFECYCLE_RESOLVED)
        {
         if(out_focus.runtime_record.resolved_time > 0)
            out_focus.end_time = out_focus.runtime_record.resolved_time;
         else if(out_focus.runtime_record.last_event_time > 0)
            out_focus.end_time = out_focus.runtime_record.last_event_time;
        }
      else if(out_focus.runtime_record.last_event_type == MOHY_ENGINE_EVENT_INVALIDATION &&
              out_focus.runtime_record.last_event_time > 0)
         out_focus.end_time = out_focus.runtime_record.last_event_time;
      else
         out_focus.end_time = (window.end_time > 0) ? window.end_time : TimeCurrent();

      if(IsCurrentPotentialOnlyMode() &&
         !runtime_resolved_in_current_only &&
         !SnapshotHasCurrentPotentialLifecycleEvidence(snapshot, out_focus))
        {
         out_focus.runtime_joined = false;
         out_focus.focus_source = "KernelFallback";
         out_focus.runtime_setup_key = "";
         out_focus.runtime_impulse_id = "";
         out_focus.impulse_index = -1;
         out_focus.correction_index = -1;
         out_focus.signal_index = -1;
         out_focus.plan_index = -1;
         out_focus.historical_index = -1;
         out_focus.start_time = 0;
         out_focus.end_time = 0;
         MohyResetRuntimeLifecycleRecord(out_focus.runtime_record);
        }
     }

   if(out_focus.start_time <= 0)
     {
      out_focus.runtime_joined = false;
      out_focus.focus_source = "KernelFallback";
      if(out_focus.runtime_setup_key == "")
         out_focus.runtime_setup_key = "";

      out_focus.correction_index = SelectPotentialCorrectionIndex(snapshot, true);
      if(!IsCurrentPotentialOnlyMode() && out_focus.correction_index < 0)
         out_focus.correction_index = SelectPotentialCorrectionIndex(snapshot, false);
      out_focus.plan_index = (out_focus.correction_index >= 0)
                             ? SelectTradeSetupPlanIndex(snapshot, out_focus.correction_index)
                             : -1;
      out_focus.signal_index = (out_focus.correction_index >= 0)
                               ? SelectPotentialContinuationSignalIndex(snapshot, out_focus.correction_index)
                               : -1;
      out_focus.historical_index = IsCurrentPotentialOnlyMode()
                                   ? -1
                                   : SelectHistoricalTradeSetupIndex(snapshot,
                                                                      out_focus.plan_index,
                                                                      out_focus.signal_index,
                                                                      out_focus.correction_index);
      out_focus.impulse_index = ResolveLifecycleImpulseIndex(snapshot,
                                                             out_focus.plan_index,
                                                             out_focus.signal_index,
                                                             out_focus.historical_index,
                                                             out_focus.runtime_impulse_id);

      if(out_focus.runtime_setup_key == "" &&
         out_focus.plan_index >= 0 &&
         out_focus.plan_index < ArraySize(snapshot.trade_setup_plans))
         out_focus.runtime_setup_key = snapshot.trade_setup_plans[out_focus.plan_index].runtime_setup_key;
      if(out_focus.runtime_setup_key == "" &&
         out_focus.signal_index >= 0 &&
         out_focus.signal_index < ArraySize(snapshot.potential_continuation_signals))
         out_focus.runtime_setup_key = snapshot.potential_continuation_signals[out_focus.signal_index].runtime_setup_key;
      if(out_focus.runtime_setup_key == "" &&
         out_focus.historical_index >= 0 &&
         out_focus.historical_index < ArraySize(snapshot.historical_trade_setups))
         out_focus.runtime_setup_key = snapshot.historical_trade_setups[out_focus.historical_index].runtime_setup_key;

      if(out_focus.runtime_impulse_id == "" &&
         out_focus.impulse_index >= 0 &&
         out_focus.impulse_index < ArraySize(snapshot.potential_impulses))
         out_focus.runtime_impulse_id = snapshot.potential_impulses[out_focus.impulse_index].runtime_impulse_id;
      if(out_focus.runtime_impulse_id == "" &&
         out_focus.correction_index >= 0 &&
         out_focus.correction_index < ArraySize(snapshot.potential_corrections))
         out_focus.runtime_impulse_id = snapshot.potential_corrections[out_focus.correction_index].runtime_impulse_id;

      if(IsCurrentPotentialOnlyMode() &&
         !SnapshotHasCurrentPotentialLifecycleEvidence(snapshot, out_focus))
        {
         out_focus.runtime_setup_key = "";
         out_focus.runtime_impulse_id = "";
         out_focus.impulse_index = -1;
         out_focus.correction_index = -1;
         out_focus.signal_index = -1;
         out_focus.plan_index = -1;
         out_focus.historical_index = -1;
         out_focus.start_time = 0;
         out_focus.end_time = 0;
        }
      else
        {
         out_focus.start_time = ResolveLifecycleStartTimeFromSnapshot(snapshot, out_focus);
         out_focus.end_time = ResolveKernelFallbackLifecycleEndTime(snapshot, out_focus, window);
        }
     }

   FinalizeLifecycleRenderBounds(out_focus, window);
   out_focus.matched_snapshot_lineage =
      (out_focus.impulse_index >= 0 ||
       out_focus.correction_index >= 0 ||
       out_focus.signal_index >= 0 ||
       out_focus.plan_index >= 0 ||
       out_focus.historical_index >= 0);
   out_focus.enabled = (out_focus.start_time > 0);
   return out_focus.enabled;
  }

bool IsTimeWithinLifecycleFocus(const MohyLifecycleFocus &focus,
                                const datetime event_time)
  {
   if(!IsLifecycleFocusActive(focus))
      return true;
   if(event_time <= 0)
      return false;
   if(focus.render_start_time > 0 && event_time < focus.render_start_time)
      return false;
   if(focus.render_end_time > 0 && event_time > focus.render_end_time)
      return false;
   return true;
  }

bool ClipTimeRangeToLifecycleFocus(const MohyLifecycleFocus &focus,
                                   datetime &io_begin_time,
                                   datetime &io_end_time)
  {
   if(!IsLifecycleFocusActive(focus))
      return (io_end_time >= io_begin_time);

   if(io_end_time <= 0)
      io_end_time = io_begin_time;
   if(io_begin_time <= 0)
      io_begin_time = io_end_time;
   if(io_begin_time <= 0 || io_end_time <= 0)
      return false;

   if(io_end_time < io_begin_time)
     {
      const datetime tmp = io_begin_time;
      io_begin_time = io_end_time;
      io_end_time = tmp;
     }

   if(focus.render_start_time > 0)
     {
      if(io_end_time < focus.render_start_time)
         return false;
      if(io_begin_time < focus.render_start_time)
         io_begin_time = focus.render_start_time;
     }

   if(focus.render_end_time > 0)
     {
      if(io_begin_time > focus.render_end_time)
         return false;
      if(io_end_time > focus.render_end_time)
         io_end_time = focus.render_end_time;
     }

   return (io_end_time >= io_begin_time);
  }

double InterpolatePriceByTime(const datetime begin_time,
                              const double begin_price,
                              const datetime end_time,
                              const double end_price,
                              const datetime target_time)
  {
   if(target_time <= begin_time || end_time <= begin_time)
      return begin_price;
   if(target_time >= end_time)
      return end_price;

   const double total_seconds = (double)(end_time - begin_time);
   if(total_seconds <= 0.0)
      return begin_price;
   const double elapsed_seconds = (double)(target_time - begin_time);
   return begin_price + ((end_price - begin_price) * (elapsed_seconds / total_seconds));
  }

bool ClipLineSegmentToLifecycleFocus(const MohyLifecycleFocus &focus,
                                     datetime &io_begin_time,
                                     double &io_begin_price,
                                     datetime &io_end_time,
                                     double &io_end_price)
  {
   if(!IsLifecycleFocusActive(focus))
      return (io_end_time >= io_begin_time);

   if(io_begin_time <= 0 || io_end_time <= 0)
      return false;
   if(io_end_time < io_begin_time)
     {
      const datetime swap_time = io_begin_time;
      const double swap_price = io_begin_price;
      io_begin_time = io_end_time;
      io_begin_price = io_end_price;
      io_end_time = swap_time;
      io_end_price = swap_price;
     }

   if(focus.render_start_time > 0)
     {
      if(io_end_time < focus.render_start_time)
         return false;
      if(io_begin_time < focus.render_start_time)
        {
         io_begin_price = InterpolatePriceByTime(io_begin_time,
                                                 io_begin_price,
                                                 io_end_time,
                                                 io_end_price,
                                                 focus.render_start_time);
         io_begin_time = focus.render_start_time;
        }
     }

   if(focus.render_end_time > 0)
     {
      if(io_begin_time > focus.render_end_time)
         return false;
      if(io_end_time > focus.render_end_time)
        {
         io_end_price = InterpolatePriceByTime(io_begin_time,
                                               io_begin_price,
                                               io_end_time,
                                               io_end_price,
                                               focus.render_end_time);
         io_end_time = focus.render_end_time;
        }
     }

   return (io_end_time >= io_begin_time);
  }

bool ResolvePotentialImpulseRenderPlan(const int chart_timeframe,
                                       int &out_source_timeframe)
  {
   out_source_timeframe = 0;
   if(chart_timeframe <= 0)
      return false;

   const int htf = g_cfg.context_timeframe;
   const int ltf = g_cfg.execution_timeframe;

   switch(PotentialImpulseRenderMode)
     {
      case MOHY_POT_IMP_RENDER_HTF_ONLY:
         out_source_timeframe = htf;
         return (chart_timeframe == htf);

      case MOHY_POT_IMP_RENDER_HTF_ON_HTF_LTF:
         out_source_timeframe = htf;
         return (chart_timeframe == htf || chart_timeframe == ltf);

      case MOHY_POT_IMP_RENDER_ANY_TF_GTE_HTF:
        {
         const int chart_seconds = ResolveTimeframeSecondsSafe(chart_timeframe);
         const int htf_seconds = ResolveTimeframeSecondsSafe(htf);
         if(chart_seconds <= 0 || htf_seconds <= 0)
            return false;
         out_source_timeframe = chart_timeframe;
         return (chart_seconds >= htf_seconds);
        }

      case MOHY_POT_IMP_RENDER_CHART_TIMEFRAME:
         out_source_timeframe = chart_timeframe;
         return true;

      default:
         out_source_timeframe = chart_timeframe;
         return true;
     }
  }

bool ConfigureFromInputs(string &out_error)
  {
   out_error = "";
   MohySetDefaultStrategyConfig(g_cfg);
   g_cfg.symbol = Symbol();

   const int htf = (int)HTF;
   const int ltf = (int)LTF;
   if(!MohyValidateTimeframePair(htf, ltf))
     {
      out_error = StringFormat("Invalid timeframe pair HTF=%s LTF=%s. Allowed: H1/M15, H2/M30, H4/H1, D1/H4.",
                               MohyTimeframeToString(htf),
                               MohyTimeframeToString(ltf));
      return false;
     }

   MohyTimeframePair pair = MOHY_TF_PAIR_H1_M15;
   if(!ResolveTimeframePair(htf, ltf, pair))
     {
      out_error = StringFormat("Unsupported timeframe pair HTF=%s LTF=%s",
                               MohyTimeframeToString(htf),
                               MohyTimeframeToString(ltf));
      return false;
     }

   g_cfg.timeframe_pair = pair;
   g_cfg.context_timeframe = htf;
   g_cfg.execution_timeframe = ltf;
   g_cfg.risk.magic_number = MathMax(1, RuntimeMagicNumber);
   g_cfg.detection.enable_potential_impulse = PotentialImpulseEnabled;
   g_cfg.detection.potential_impulse_min_swing_breakout_closes = MathMax(0, PotentialImpulseMinSwingBreakoutCloses);
   g_cfg.detection.potential_impulse_require_leg_breakout = PotentialImpulseRequireLegBreakout;
   g_cfg.detection.potential_impulse_min_leg_breakout_closes = MathMax(1, PotentialImpulseMinLegBreakoutCloses);
   g_cfg.detection.potential_impulse_require_directional_candles = PotentialImpulseRequireDirectionalCandles;
   g_cfg.detection.potential_impulse_validate_endpoint_candles = PotentialImpulseValidateEndpointCandles;
   g_cfg.detection.potential_impulse_allow_opposite_begin_candles = MathMax(0, PotentialImpulseAllowOppositeBeginCandles);
   g_cfg.detection.potential_impulse_allow_opposite_end_candles = MathMax(0, PotentialImpulseAllowOppositeEndCandles);
   g_cfg.detection.potential_impulse_max_opposite_middle_candles = MathMax(0, PotentialImpulseMaxOppositeMiddleCandles);
   g_cfg.detection.potential_impulse_allow_any_opposite_before_leg_breakout = PotentialImpulseAllowAnyOppositeBeforeLegBreakout;
   g_cfg.detection.potential_impulse_doji_epsilon_points = MathMax(1e-10, PotentialImpulseDojiEpsilonPoints);
   g_cfg.detection.enable_potential_correction = PotentialCorrectionEnabled;
   g_cfg.detection.potential_correction_min_opposite_ici_count = MathMax(0, PotentialCorrectionMinOppositeICICount);
   g_cfg.detection.potential_correction_min_fib_level = PotentialCorrectionMinFibLevel;
   g_cfg.detection.potential_correction_min_fib_trigger_mode = PotentialCorrectionMinFibTriggerMode;
   g_cfg.detection.potential_correction_max_fib_level = PotentialCorrectionMaxFibLevel;
   g_cfg.detection.potential_correction_max_fib_trigger_mode = PotentialCorrectionMaxFibTriggerMode;
   g_cfg.detection.potential_correction_extreme_touch_epsilon_points = MathMax(0.0, PotentialCorrectionExtremeTouchEpsilonPoints);
   g_cfg.detection.potential_correction_extreme_touch_min_count = MathMax(1, PotentialCorrectionExtremeTouchMinCount);
   g_cfg.detection.potential_correction_supersede_direction_mode = PotentialCorrectionSupersedeDirectionMode;
   g_cfg.detection.potential_correction_supersede_scope = PotentialCorrectionSupersedeScope;
   g_cfg.detection.continuation_planning_start_mode = ContinuationPlanningStartMode;
   if(!MohyIsPotentialCorrectionFibRangeValid(g_cfg.detection.potential_correction_min_fib_level,
                                              g_cfg.detection.potential_correction_max_fib_level))
     {
      out_error = "Invalid PotentialCorrection fib range: max fib must be strictly greater than min fib.";
      return false;
     }
   g_render_timeframe = ResolveRenderTimeframe((int)_Period,
                                               g_cfg.context_timeframe,
                                               g_cfg.execution_timeframe);
   if(g_render_timeframe <= 0 && RenderScope != MOHY_VIS_RENDER_PAIR_ONLY)
     {
      out_error = "Render timeframe resolution failed.";
      return false;
     }

   return true;
  }

void UpsertPeakValleyLabel(const string name,
                           const datetime t,
                           const double price,
                           const string text,
                           const color c,
                           const bool is_peak,
                           const string tooltip)
  {
   if(!PeakValleyShowLabels)
      return;
   if(t <= 0 || price <= 0.0 || text == "")
      return;

   if(ObjectFind(0, name) >= 0 && (ENUM_OBJECT)ObjectGetInteger(0, name, OBJPROP_TYPE) != OBJ_TEXT)
      ObjectDelete(0, name);

   if(ObjectFind(0, name) < 0)
     {
      if(!ObjectCreate(0, name, OBJ_TEXT, 0, t, price))
         return;
     }
   else
      ObjectMove(0, name, 0, t, price);

   SetObjectText(name, text, PeakValleyLabelFontSize, "Consolas", c);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, is_peak ? ANCHOR_LOWER : ANCHOR_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
   TouchRenderObject(name);
  }

void UpsertPeakValleyLegLine(const string name,
                             const MohySwingPoint &left,
                             const MohySwingPoint &right,
                             const int timeframe,
                             const bool provisional)
  {
   if(!PeakValleyShowLegLines)
      return;
   if(left.time <= 0 || right.time <= 0)
      return;
   if(left.price <= 0.0 || right.price <= 0.0)
      return;

   if(ObjectFind(0, name) >= 0 && (ENUM_OBJECT)ObjectGetInteger(0, name, OBJPROP_TYPE) != OBJ_TREND)
      ObjectDelete(0, name);

   if(ObjectFind(0, name) < 0)
     {
      if(!ObjectCreate(0, name,
                       OBJ_TREND,
                       0,
                       left.time,
                       left.price,
                       right.time,
                       right.price))
         return;
     }
   else
     {
      ObjectMove(0, name, 0, left.time, left.price);
      ObjectMove(0, name, 1, right.time, right.price);
     }

   const bool leg_up = (right.price > left.price);
   const color line_color = leg_up ? PeakValleyBullLegColor : PeakValleyBearLegColor;
   const string from_side = left.is_high ? "Peak" : "Valley";
   const string to_side = right.is_high ? "Peak" : "Valley";
   const string tooltip = StringFormat("%s %s -> %s | %s -> %s",
                                       MohyTimeframeToString(timeframe),
                                       from_side,
                                       to_side,
                                       TimeToString(left.time, TIME_DATE | TIME_MINUTES),
                                       TimeToString(right.time, TIME_DATE | TIME_MINUTES));

   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   const int line_style = provisional ? STYLE_DASH : MathMax(0, MathMin(4, PeakValleyLegLineStyle));
   ObjectSetInteger(0, name, OBJPROP_STYLE, line_style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, MathMax(1, PeakValleyLegLineWidth));
   ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
   TouchRenderObject(name);
  }

void UpsertPotentialImpulseLine(const string name,
                                const MohyPotentialImpulseFact &fact,
                                const int source_timeframe,
                                const int draw_timeframe,
                                const datetime draw_begin_time,
                                const datetime draw_end_time,
                                const double draw_begin_price,
                                const double draw_end_price)
  {
   if(!PotentialImpulseEnabled)
      return;
   if(draw_begin_time <= 0 || draw_end_time <= 0)
      return;
   if(draw_begin_price <= 0.0 || draw_end_price <= 0.0)
      return;

   if(ObjectFind(0, name) >= 0 && (ENUM_OBJECT)ObjectGetInteger(0, name, OBJPROP_TYPE) != OBJ_TREND)
      ObjectDelete(0, name);

   if(ObjectFind(0, name) < 0)
     {
      if(!ObjectCreate(0, name,
                       OBJ_TREND,
                       0,
                       draw_begin_time,
                       draw_begin_price,
                       draw_end_time,
                       draw_end_price))
         return;
     }
   else
     {
      ObjectMove(0, name, 0, draw_begin_time, draw_begin_price);
      ObjectMove(0, name, 1, draw_end_time, draw_end_price);
     }

   const color line_color = (fact.direction == MOHY_DIR_BULL)
                            ? PotentialImpulseBullColor
                            : PotentialImpulseBearColor;
   const string tooltip = StringFormat("PotentialImpulse %s | SourceTF=%s | DrawTF=%s | Dir=%s | State=%s | Break=%s | Certainty=%s | SwingCloses=%d | LegBreakCloses=%d | %s -> %s",
                                       Swing3PatternCode(fact.pattern_type),
                                       MohyTimeframeToString(source_timeframe),
                                       MohyTimeframeToString(draw_timeframe),
                                       (fact.direction == MOHY_DIR_BULL) ? "Bull" : "Bear",
                                       fact.confirmed ? "Confirmed" : "Live",
                                       MohyBreakStateToString(fact.break_state),
                                       MohyBreakoutCertaintyToString(fact.swing_breakout_certainty),
                                       fact.swing_breakout_close_count,
                                       fact.leg_breakout_close_count,
                                       TimeToString(draw_begin_time, TIME_DATE | TIME_MINUTES),
                                       TimeToString(draw_end_time, TIME_DATE | TIME_MINUTES));

   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_STYLE, MathMax(0, MathMin(4, PotentialImpulseLineStyle)));
   ObjectSetInteger(0, name, OBJPROP_WIDTH, MathMax(1, PotentialImpulseLineWidth));
   ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
   TouchRenderObject(name);
  }

void UpsertPotentialCorrectionLine(const string name,
                                   const MohyPotentialCorrectionFact &fact,
                                   const MohyPotentialCorrectionState draw_state,
                                   const bool is_active,
                                   const int source_timeframe,
                                   const int draw_timeframe,
                                   const datetime draw_begin_time,
                                   const datetime draw_end_time,
                                   const double draw_begin_price,
                                   const double draw_end_price)
  {
   if(!PotentialCorrectionEnabled || !PotentialCorrectionShowLines)
      return;
   if(draw_begin_time <= 0 || draw_end_time <= 0)
      return;
   if(draw_begin_price <= 0.0 || draw_end_price <= 0.0)
      return;

   if(ObjectFind(0, name) >= 0 && (ENUM_OBJECT)ObjectGetInteger(0, name, OBJPROP_TYPE) != OBJ_TREND)
      ObjectDelete(0, name);

   if(ObjectFind(0, name) < 0)
     {
      if(!ObjectCreate(0, name,
                       OBJ_TREND,
                       0,
                       draw_begin_time,
                       draw_begin_price,
                       draw_end_time,
                       draw_end_price))
         return;
     }
   else
     {
      ObjectMove(0, name, 0, draw_begin_time, draw_begin_price);
      ObjectMove(0, name, 1, draw_end_time, draw_end_price);
     }

   const color line_color = ResolvePotentialCorrectionLineColor(fact, draw_state);
   const int line_style = ResolvePotentialCorrectionLineStyle(draw_state, is_active);
    const string tooltip = StringFormat("PotentialCorrection | SourceTF=%s | DrawTF=%s | Dir=%s | StateSeg=%s | FactState=%s | Term=%s | HistMode=%s | StartMode=%s | RefStart=%d/%s/%.5f | VisStart=%d/%s/%.5f | OppICI=%d/%d | Depth=%.4f | Min/MaxFib=%.3f/%.3f | MinGate=%s | %s -> %s",
                                        MohyTimeframeToString(source_timeframe),
                                        MohyTimeframeToString(draw_timeframe),
                                        (fact.impulse_direction == MOHY_DIR_BULL) ? "BullImpulse" : "BearImpulse",
                                        MohyPotentialCorrectionStateToString(draw_state),
                                        MohyPotentialCorrectionStateToString(fact.state),
                                        MohyPotentialCorrectionTerminationReasonToString(fact.termination_reason),
                                       IsCurrentPotentialOnlyMode() ? "LifecycleFocus" : "LookbackHistory",
                                        "UnifiedImpulseEnd",
                                        fact.reference_begin_shift,
                                        TimeToString(fact.reference_begin_time, TIME_DATE | TIME_MINUTES),
                                       fact.reference_begin_price,
                                       fact.visual_begin_shift,
                                       TimeToString(fact.visual_begin_time, TIME_DATE | TIME_MINUTES),
                                       fact.visual_begin_price,
                                       fact.opposite_ici_count,
                                       fact.min_opposite_ici_count,
                                       fact.retrace_depth,
                                       fact.min_fib_level,
                                       fact.max_fib_level,
                                       fact.min_fib_gate_pass ? "Pass" : "Pending",
                                       TimeToString(draw_begin_time, TIME_DATE | TIME_MINUTES),
                                       TimeToString(draw_end_time, TIME_DATE | TIME_MINUTES));

   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_STYLE, line_style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, MathMax(1, PotentialCorrectionLineWidth));
   ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
   TouchRenderObject(name);
  }

void UpsertPotentialContinuationSignalMarker(const string name,
                                             const MohyPotentialContinuationSignalFact &fact,
                                             const int source_timeframe,
                                             const int draw_timeframe,
                                             const MohyLifecycleFocus &focus)
  {
   if(!ContinuationSignalEnabled)
      return;
   if(fact.broken_level_price <= 0.0)
      return;

   int breakout_shift = fact.signal_shift;
   if(breakout_shift < 0)
      breakout_shift = fact.broken_leg_end_shift;
   if(breakout_shift < 0)
      return;

   int start_shift = breakout_shift;
   datetime line_begin_time = fact.signal_time;
   if(ContinuationSignalStartMode == MOHY_CONT_SIG_START_BROKEN_STRUCTURE)
     {
      start_shift = fact.broken_leg_begin_shift;
      if(start_shift < 0)
         start_shift = fact.broken_level_shift;
      if(start_shift < 0)
         start_shift = breakout_shift;
      line_begin_time = fact.broken_leg_begin_time;
      if(line_begin_time <= 0)
         line_begin_time = fact.broken_level_time;
     }
   else
     {
      line_begin_time = fact.signal_time;
     }

   if(line_begin_time <= 0)
      line_begin_time = MohyITime(Symbol(), source_timeframe, start_shift);
   if(line_begin_time <= 0)
      return;

   const int end_offset_bars = MathMax(1, ContinuationSignalLineForwardBars);
   const int line_end_shift = breakout_shift - end_offset_bars;
   datetime line_end_time = 0;
   if(line_end_shift >= 0)
      line_end_time = MohyITime(Symbol(), source_timeframe, line_end_shift);
   if(line_end_time <= 0)
     {
      int tf_seconds = ResolveTimeframeSecondsSafe(source_timeframe);
      if(tf_seconds <= 0)
         tf_seconds = 60;
      datetime breakout_time = fact.signal_time;
      if(breakout_time <= 0)
         breakout_time = MohyITime(Symbol(), source_timeframe, breakout_shift);
      if(breakout_time <= 0)
         breakout_time = line_begin_time;
      line_end_time = breakout_time + (end_offset_bars * tf_seconds);
     }
   if(line_end_time <= line_begin_time)
     {
      int tf_seconds = ResolveTimeframeSecondsSafe(source_timeframe);
      if(tf_seconds <= 0)
         tf_seconds = 60;
      line_end_time = line_begin_time + (end_offset_bars * tf_seconds);
     }
   if(!ClipTimeRangeToLifecycleFocus(focus, line_begin_time, line_end_time))
      return;

   if(ObjectFind(0, name) >= 0 && (ENUM_OBJECT)ObjectGetInteger(0, name, OBJPROP_TYPE) != OBJ_TREND)
      ObjectDelete(0, name);

   if(ObjectFind(0, name) < 0)
     {
      if(!ObjectCreate(0, name,
                       OBJ_TREND,
                       0,
                       line_begin_time,
                       fact.broken_level_price,
                       line_end_time,
                       fact.broken_level_price))
         return;
     }
   else
     {
      ObjectMove(0, name, 0, line_begin_time, fact.broken_level_price);
      ObjectMove(0, name, 1, line_end_time, fact.broken_level_price);
     }

   const bool is_bull = (fact.direction == MOHY_DIR_BULL);
   const color mark_color = is_bull ? ContinuationSignalBullColor : ContinuationSignalBearColor;
   const string tooltip = StringFormat("PotentialContinuationSignal | SourceTF=%s | DrawTF=%s | Dir=%s | Corr=%d (%s, Active=%s, Rank=%d) | StartMode=%s | Confirm=%s | Swing3=%d | Break=%s/%d | BrokenLeg=%s -> %s | Signal=%s | BrokenLevel=%s/%.5f",
                                       MohyTimeframeToString(source_timeframe),
                                       MohyTimeframeToString(draw_timeframe),
                                       is_bull ? "Bull" : "Bear",
                                       fact.linked_potential_correction_index,
                                       MohyPotentialCorrectionStateToString(fact.linked_correction_state),
                                       fact.linked_correction_is_active ? "Yes" : "No",
                                       fact.linked_correction_recency_rank,
                                       (ContinuationSignalStartMode == MOHY_CONT_SIG_START_BROKEN_STRUCTURE) ? "BrokenStructure" : "Breakout",
                                       TimeToString(fact.correction_confirmed_time, TIME_DATE | TIME_MINUTES),
                                       fact.trigger_swing3_index,
                                       MohyBreakoutCertaintyToString(fact.trigger_breakout_certainty),
                                       fact.trigger_breakout_close_count,
                                       TimeToString(fact.broken_leg_begin_time, TIME_DATE | TIME_MINUTES),
                                       TimeToString(fact.broken_leg_end_time, TIME_DATE | TIME_MINUTES),
                                       TimeToString(fact.signal_time, TIME_DATE | TIME_MINUTES),
                                       TimeToString(fact.broken_level_time, TIME_DATE | TIME_MINUTES),
                                       fact.broken_level_price);

   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_STYLE, MathMax(0, MathMin(4, ContinuationSignalLineStyle)));
   ObjectSetInteger(0, name, OBJPROP_WIDTH, MathMax(1, ContinuationSignalLineWidth));
   ObjectSetInteger(0, name, OBJPROP_COLOR, mark_color);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
   TouchRenderObject(name);
  }

color ResolveTradeSetupPlanEntryColor(const MohyTradeSetupPlanFact &plan)
  {
   if(plan.plan_state == MOHY_TRADE_SETUP_PLAN_ELIGIBLE_NOW)
      return TradeSetupPlanEligibleColor;
   if(plan.plan_state == MOHY_TRADE_SETUP_PLAN_WAITING_FOR_PULLBACK)
      return TradeSetupPlanWaitingColor;
   return TradeSetupPlanInvalidColor;
  }

color ResolveHistoricalTradeSetupColor(const MohyHistoricalTradeSetupFact &fact)
  {
   switch(fact.outcome)
     {
      case MOHY_HIST_SETUP_OUTCOME_WAITING:
         return HistoricalTradeSetupWaitingColor;
      case MOHY_HIST_SETUP_OUTCOME_MISSED:
         return HistoricalTradeSetupMissedColor;
      case MOHY_HIST_SETUP_OUTCOME_ENTERED:
         return HistoricalTradeSetupEnteredColor;
      case MOHY_HIST_SETUP_OUTCOME_TARGET_HIT:
         return HistoricalTradeSetupTargetHitColor;
      case MOHY_HIST_SETUP_OUTCOME_STOP_HIT:
         return HistoricalTradeSetupStopHitColor;
      case MOHY_HIST_SETUP_OUTCOME_OPEN:
         return HistoricalTradeSetupOpenColor;
      default:
         return HistoricalTradeSetupMissedColor;
     }
  }

void UpsertHistoricalTradeSetupLabel(const string name,
                                     const datetime label_time,
                                     const double label_price,
                                     const string text,
                                     const color text_color,
                                     const string tooltip,
                                     const int label_anchor)
  {
   if(!HistoricalTradeSetupEnabled || !HistoricalTradeSetupShowLabels)
      return;
   if(label_time <= 0 || label_price <= 0.0 || text == "")
      return;

   if(ObjectFind(0, name) >= 0 && (ENUM_OBJECT)ObjectGetInteger(0, name, OBJPROP_TYPE) != OBJ_TEXT)
      ObjectDelete(0, name);

   if(ObjectFind(0, name) < 0)
     {
      if(!ObjectCreate(0, name, OBJ_TEXT, 0, label_time, label_price))
         return;
     }
   else
     {
      ObjectMove(0, name, 0, label_time, label_price);
     }

   SetObjectText(name,
                 text,
                 MathMax(6, HistoricalTradeSetupLabelFontSize),
                 "Consolas",
                 text_color);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, label_anchor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
   TouchRenderObject(name);
  }

void UpsertHistoricalTradeSetupLevel(const string name,
                                     const color line_color,
                                     const datetime begin_time,
                                     const datetime end_time,
                                     const double level_price,
                                     const string tooltip)
  {
   if(!HistoricalTradeSetupEnabled)
      return;
   if(begin_time <= 0 || end_time <= begin_time || level_price <= 0.0)
      return;

   if(ObjectFind(0, name) >= 0 && (ENUM_OBJECT)ObjectGetInteger(0, name, OBJPROP_TYPE) != OBJ_TREND)
      ObjectDelete(0, name);

   if(ObjectFind(0, name) < 0)
     {
      if(!ObjectCreate(0, name, OBJ_TREND, 0, begin_time, level_price, end_time, level_price))
         return;
     }
   else
     {
      ObjectMove(0, name, 0, begin_time, level_price);
      ObjectMove(0, name, 1, end_time, level_price);
     }

   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, MathMax(1, HistoricalTradeSetupLineWidth));
   ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
   TouchRenderObject(name);
  }

void UpsertTradeSetupPlanLevel(const string name,
                               const string level_label,
                               const color line_color,
                               const datetime begin_time,
                               const datetime end_time,
                               const double level_price,
                               const MohyTradeSetupPlanFact &plan,
                               const int source_timeframe,
                               const int draw_timeframe)
  {
   if(!TradeSetupPlanEnabled)
      return;
   if(begin_time <= 0 || end_time <= begin_time || level_price <= 0.0)
      return;

   if(ObjectFind(0, name) >= 0 && (ENUM_OBJECT)ObjectGetInteger(0, name, OBJPROP_TYPE) != OBJ_TREND)
      ObjectDelete(0, name);

   if(ObjectFind(0, name) < 0)
     {
      if(!ObjectCreate(0, name, OBJ_TREND, 0, begin_time, level_price, end_time, level_price))
         return;
     }
   else
     {
      ObjectMove(0, name, 0, begin_time, level_price);
      ObjectMove(0, name, 1, end_time, level_price);
     }

   const string tooltip = StringFormat("TradeSetupPlan %s | SourceTF=%s | DrawTF=%s | State=%s | ExecMode=%d | Stop=%s | Target=%s | RR=%.2f | Entry=%.5f | Stop=%.5f | Target=%.5f | Lots=%.2f | %s",
                                       level_label,
                                       MohyTimeframeToString(source_timeframe),
                                       MohyTimeframeToString(draw_timeframe),
                                       MohyTradeSetupPlanStateToString(plan.plan_state),
                                       (int)plan.execution_mode,
                                       MohyTradeSetupStopAnchorTypeToString(plan.stop_anchor_type),
                                       MohyTradeSetupTargetAnchorTypeToString(plan.target_anchor_type),
                                       plan.reward_to_risk,
                                       plan.proposed_entry_price,
                                       plan.stop_price,
                                       plan.target_price,
                                       plan.lots_normalized,
                                       plan.diagnostics);

   ObjectSetInteger(0, name, OBJPROP_STYLE, MathMax(0, MathMin(4, TradeSetupPlanLineStyle)));
   ObjectSetInteger(0, name, OBJPROP_WIDTH, MathMax(1, TradeSetupPlanLineWidth));
   ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
   TouchRenderObject(name);
  }

void UpsertTradeSetupPlanLevelLabel(const string name,
                                    const string level_label,
                                    const color text_color,
                                    const datetime label_time,
                                    const double label_price,
                                    const double display_price,
                                    const MohyTradeSetupPlanFact &plan,
                                    const int source_timeframe,
                                    const int draw_timeframe,
                                    const int label_anchor)
  {
   if(!TradeSetupPlanEnabled || !TradeSetupPlanShowLabels)
      return;
   if(label_time <= 0 || label_price <= 0.0)
      return;

   if(ObjectFind(0, name) >= 0 && (ENUM_OBJECT)ObjectGetInteger(0, name, OBJPROP_TYPE) != OBJ_TEXT)
      ObjectDelete(0, name);

   if(ObjectFind(0, name) < 0)
     {
      if(!ObjectCreate(0, name, OBJ_TEXT, 0, label_time, label_price))
         return;
     }
   else
     {
      ObjectMove(0, name, 0, label_time, label_price);
     }

   const string label_text = StringFormat("%s %.5f", level_label, display_price);
   const string tooltip = StringFormat("TradeSetupPlan %s Label | SourceTF=%s | DrawTF=%s | State=%s | RR=%.2f | Lots=%.2f",
                                       level_label,
                                       MohyTimeframeToString(source_timeframe),
                                       MohyTimeframeToString(draw_timeframe),
                                       MohyTradeSetupPlanStateToString(plan.plan_state),
                                       plan.reward_to_risk,
                                       plan.lots_normalized);
   SetObjectText(name,
                 label_text,
                 MathMax(6, TradeSetupPlanLabelFontSize),
                 "Consolas",
                 text_color);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, label_anchor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
   TouchRenderObject(name);
  }

void DrawTradeSetupPlans(const int source_timeframe,
                         const int draw_timeframe,
                         const MohyRenderWindow &window,
                         const MohyLifecycleFocus &focus,
                         const CMohyPriceActionSnapshot &snapshot)
  {
   if(!TradeSetupPlanEnabled)
      return;
   if(source_timeframe <= 0 || draw_timeframe <= 0)
      return;

   const int plan_count = ArraySize(snapshot.trade_setup_plans);
   if(plan_count <= 0)
      return;

   const bool current_only = IsCurrentPotentialOnlyMode();
   const bool focus_enabled = IsLifecycleFocusActive(focus);
   const bool resolved_runtime_focus = IsResolvedRuntimeFocusInCurrentOnly(focus);
   if(current_only && resolved_runtime_focus)
      return;
   int selected_correction_index = -1;
   if(current_only)
     {
      selected_correction_index = focus_enabled ? focus.correction_index : SelectPotentialCorrectionIndex(snapshot, true);
      if(selected_correction_index < 0 && !focus_enabled)
         selected_correction_index = SelectPotentialCorrectionIndex(snapshot, false);
      }
   const int selected_plan_index = current_only
                                   ? (focus.plan_index >= 0
                                      ? focus.plan_index
                                      : (focus.runtime_setup_key != ""
                                         ? FindTradeSetupPlanIndexBySetupKey(snapshot, focus.runtime_setup_key)
                                         : SelectTradeSetupPlanIndex(snapshot, selected_correction_index)))
                                   : -1;
   if(current_only && selected_plan_index < 0)
      return;
   const int label_plan_index = current_only
                                ? selected_plan_index
                                : SelectTradeSetupPlanIndex(snapshot, -1);
   const string tf_text = MohyTimeframeToString(source_timeframe);
   const int begin_plan = (current_only && selected_plan_index >= 0) ? selected_plan_index : 0;
   const int end_plan = (current_only && selected_plan_index >= 0) ? (selected_plan_index + 1) : plan_count;
   for(int i = begin_plan; i < end_plan; ++i)
     {
      const MohyTradeSetupPlanFact plan = snapshot.trade_setup_plans[i];
      if(!plan.valid)
         continue;
      if(focus_enabled)
        {
         if(selected_plan_index >= 0 && i != selected_plan_index)
            continue;
         if(focus.runtime_setup_key != "" && plan.runtime_setup_key != focus.runtime_setup_key)
            continue;
        }
      if(current_only &&
          selected_correction_index >= 0 &&
          plan.linked_potential_correction_index != selected_correction_index)
         continue;
      if(plan.proposed_entry_price <= 0.0 || plan.stop_price <= 0.0 || plan.target_price <= 0.0)
         continue;
      if(plan.linked_potential_continuation_signal_index < 0 ||
         plan.linked_potential_continuation_signal_index >= ArraySize(snapshot.potential_continuation_signals))
         continue;

      const MohyPotentialContinuationSignalFact signal =
         snapshot.potential_continuation_signals[plan.linked_potential_continuation_signal_index];
      datetime line_begin_time = signal.signal_time;
      if(line_begin_time <= 0)
         line_begin_time = signal.broken_level_time;
      if(line_begin_time <= 0)
         continue;

      int tf_seconds = ResolveTimeframeSecondsSafe(source_timeframe);
      if(tf_seconds <= 0)
         tf_seconds = 60;
      datetime line_end_time =
         line_begin_time + MathMax(1, TradeSetupPlanLineForwardBars) * tf_seconds;
      if(!ClipTimeRangeToLifecycleFocus(focus, line_begin_time, line_end_time))
         continue;
      if(window.start_time > 0 && line_end_time < window.start_time)
         continue;
      datetime label_time = line_end_time;
      if(label_time <= 0)
         label_time = line_begin_time;

      const color entry_color = ResolveTradeSetupPlanEntryColor(plan);
      const bool render_plan_labels = (TradeSetupPlanShowLabels && i == label_plan_index);
      UpsertTradeSetupPlanLevel(StringFormat("%sSETUP_PLAN_%s_%d_ENTRY",
                                             VisualizerPrefix(),
                                             tf_text,
                                             plan.index),
                                "Entry",
                                entry_color,
                                line_begin_time,
                                line_end_time,
                                plan.proposed_entry_price,
                                plan,
                                source_timeframe,
                                draw_timeframe);
      UpsertTradeSetupPlanLevel(StringFormat("%sSETUP_PLAN_%s_%d_STOP",
                                             VisualizerPrefix(),
                                             tf_text,
                                             plan.index),
                                "Stop",
                                TradeSetupPlanStopColor,
                                line_begin_time,
                                line_end_time,
                                plan.stop_price,
                                plan,
                                source_timeframe,
                                draw_timeframe);
      UpsertTradeSetupPlanLevel(StringFormat("%sSETUP_PLAN_%s_%d_TARGET",
                                             VisualizerPrefix(),
                                             tf_text,
                                             plan.index),
                                "Target",
                                TradeSetupPlanTargetColor,
                                line_begin_time,
                                line_end_time,
                                plan.target_price,
                                plan,
                                source_timeframe,
                                draw_timeframe);
      if(!render_plan_labels)
         continue;

      datetime entry_label_time = label_time;
      double entry_label_price = plan.proposed_entry_price;
      const bool entry_label_above = (plan.direction == MOHY_DIR_BEAR);
      ResolveSetupLabelPlacement(source_timeframe,
                                 label_time,
                                 plan.proposed_entry_price,
                                 TradeSetupPlanLabelFontSize,
                                 entry_label_above,
                                 entry_label_time,
                                 entry_label_price);
      UpsertTradeSetupPlanLevelLabel(StringFormat("%sSETUP_PLAN_%s_%d_ENTRY_LABEL",
                                                  VisualizerPrefix(),
                                                  tf_text,
                                                  plan.index),
                                     "ENTRY",
                                     entry_color,
                                     entry_label_time,
                                     entry_label_price,
                                     plan.proposed_entry_price,
                                     plan,
                                     source_timeframe,
                                     draw_timeframe,
                                     entry_label_above ? ANCHOR_LEFT_LOWER : ANCHOR_LEFT_UPPER);

      datetime stop_label_time = label_time;
      double stop_label_price = plan.stop_price;
      ResolveSetupLabelPlacement(source_timeframe,
                                 label_time,
                                 plan.stop_price,
                                 TradeSetupPlanLabelFontSize,
                                 false,
                                 stop_label_time,
                                 stop_label_price);
      UpsertTradeSetupPlanLevelLabel(StringFormat("%sSETUP_PLAN_%s_%d_STOP_LABEL",
                                                  VisualizerPrefix(),
                                                  tf_text,
                                                  plan.index),
                                     "STOP",
                                     TradeSetupPlanStopColor,
                                     stop_label_time,
                                     stop_label_price,
                                     plan.stop_price,
                                     plan,
                                     source_timeframe,
                                     draw_timeframe,
                                     ANCHOR_LEFT_UPPER);

      datetime target_label_time = label_time;
      double target_label_price = plan.target_price;
      ResolveSetupLabelPlacement(source_timeframe,
                                 label_time,
                                 plan.target_price,
                                 TradeSetupPlanLabelFontSize,
                                 true,
                                 target_label_time,
                                 target_label_price);
      UpsertTradeSetupPlanLevelLabel(StringFormat("%sSETUP_PLAN_%s_%d_TARGET_LABEL",
                                                  VisualizerPrefix(),
                                                  tf_text,
                                                  plan.index),
                                     "TARGET",
                                     TradeSetupPlanTargetColor,
                                     target_label_time,
                                     target_label_price,
                                     plan.target_price,
                                     plan,
                                     source_timeframe,
                                     draw_timeframe,
                                     ANCHOR_LEFT_LOWER);
     }
  }

void DrawHistoricalTradeSetups(const int source_timeframe,
                               const int draw_timeframe,
                               const MohyRenderWindow &window,
                               const MohyLifecycleFocus &focus,
                               const CMohyPriceActionSnapshot &snapshot)
  {
   if(!HistoricalTradeSetupEnabled)
      return;
   if(source_timeframe <= 0 || draw_timeframe <= 0)
      return;

   const int fact_count = ArraySize(snapshot.historical_trade_setups);
   if(fact_count <= 0)
      return;

   const bool current_only = IsCurrentPotentialOnlyMode();
   const bool focus_enabled = IsLifecycleFocusActive(focus);
   const int selected_history_index = current_only ? focus.historical_index : -1;
   if(current_only && selected_history_index < 0)
      return;

   const string tf_text = MohyTimeframeToString(source_timeframe);
   ulong labeled_outcome_mask = 0;
   for(int i = fact_count - 1; i >= 0; --i)
     {
      const MohyHistoricalTradeSetupFact fact = snapshot.historical_trade_setups[i];
      if(!fact.valid)
         continue;
      if(current_only && selected_history_index >= 0 && i != selected_history_index)
         continue;
      if(focus_enabled && focus.runtime_setup_key != "" && fact.runtime_setup_key != focus.runtime_setup_key)
         continue;
      if(fact.setup_time <= 0 || fact.planned_entry_price <= 0.0)
         continue;

      datetime setup_time = fact.setup_time;
      datetime end_time = fact.exit_time;
      int tf_seconds = ResolveTimeframeSecondsSafe(source_timeframe);
      if(tf_seconds <= 0)
         tf_seconds = 60;
      if(end_time <= 0)
         end_time = setup_time;
      if(end_time < setup_time)
         end_time = setup_time;
      if(end_time == setup_time)
         end_time = setup_time + tf_seconds;
      if(!ClipTimeRangeToLifecycleFocus(focus, setup_time, end_time))
         continue;
      if(window.start_time > 0 && end_time < window.start_time)
         continue;

      const color outcome_color = ResolveHistoricalTradeSetupColor(fact);
      const string tooltip = StringFormat("HistoricalTradeSetup | Outcome=%s | Dir=%s | Setup=%s | Entry=%.5f | Stop=%.5f | Target=%.5f | %s",
                                          MohyHistoricalTradeSetupOutcomeToString(fact.outcome),
                                          (fact.direction == MOHY_DIR_BULL ? "Bull" : (fact.direction == MOHY_DIR_BEAR ? "Bear" : "None")),
                                          TimeToString(setup_time, TIME_DATE | TIME_MINUTES),
                                          fact.planned_entry_price,
                                          fact.stop_price,
                                          fact.target_price,
                                          fact.diagnostics);

      UpsertHistoricalTradeSetupLevel(StringFormat("%sHIST_SETUP_%s_%d_ENTRY",
                                                   VisualizerPrefix(),
                                                   tf_text,
                                                   fact.index),
                                      outcome_color,
                                      setup_time,
                                      end_time,
                                      fact.entered && fact.entry_price > 0.0 ? fact.entry_price : fact.planned_entry_price,
                                      tooltip);

      if(fact.entered)
        {
         const datetime trade_begin_time = (fact.entry_time > 0) ? fact.entry_time : setup_time;
         datetime trade_end_time = end_time;
         if(trade_end_time <= trade_begin_time)
            trade_end_time = trade_begin_time + tf_seconds;
         UpsertHistoricalTradeSetupLevel(StringFormat("%sHIST_SETUP_%s_%d_STOP",
                                                      VisualizerPrefix(),
                                                      tf_text,
                                                      fact.index),
                                         TradeSetupPlanStopColor,
                                         trade_begin_time,
                                         trade_end_time,
                                         fact.stop_price,
                                         tooltip);
         UpsertHistoricalTradeSetupLevel(StringFormat("%sHIST_SETUP_%s_%d_TARGET",
                                                      VisualizerPrefix(),
                                                      tf_text,
                                                      fact.index),
                                         TradeSetupPlanTargetColor,
                                         trade_begin_time,
                                         trade_end_time,
                                         fact.target_price,
                                         tooltip);
        }

      if(HistoricalTradeSetupShowLabels)
        {
         const int outcome_value = (int)fact.outcome;
         const ulong outcome_bit = (outcome_value > 0 && outcome_value < 63)
                                   ? (((ulong)1) << outcome_value)
                                   : 0;
         if(outcome_bit == 0 || (labeled_outcome_mask & outcome_bit) != 0)
            continue;
         labeled_outcome_mask |= outcome_bit;

         const string label_text = StringFormat("%s %s",
                                                MohyHistoricalTradeSetupOutcomeToString(fact.outcome),
                                                fact.entered ? StringFormat("@ %.5f", fact.entry_price) : "");
         datetime label_time = end_time;
         double label_price = fact.entered && fact.exit_price > 0.0
                              ? fact.exit_price
                              : fact.planned_entry_price;
         const bool label_above = (fact.direction != MOHY_DIR_BEAR);
         ResolveSetupLabelPlacement(source_timeframe,
                                    label_time,
                                    label_price,
                                    HistoricalTradeSetupLabelFontSize,
                                    label_above,
                                    label_time,
                                    label_price);
         UpsertHistoricalTradeSetupLabel(StringFormat("%sHIST_SETUP_%s_%d_LABEL",
                                                      VisualizerPrefix(),
                                                      tf_text,
                                                      fact.index),
                                         label_time,
                                         label_price,
                                         TrimText(label_text),
                                         outcome_color,
                                         tooltip,
                                         label_above ? ANCHOR_LEFT_LOWER : ANCHOR_LEFT_UPPER);
        }

     }
  }

void DrawPotentialCorrectionSegment(const string name,
                                    const MohyPotentialCorrectionFact &fact,
                                    const MohyPotentialCorrectionState draw_state,
                                    const bool is_active,
                                    const int source_timeframe,
                                    const int draw_timeframe,
                                    const MohyLifecycleFocus &focus,
                                    const int begin_shift,
                                    const datetime begin_time,
                                    const double begin_price,
                                    const bool begin_is_high,
                                    const int end_shift,
                                    const datetime end_time,
                                    const double end_price,
                                    const bool end_is_high)
  {
   if(begin_shift < 0 || end_shift < 0)
      return;
   if(begin_shift < end_shift)
      return;
   if(begin_time <= 0 || end_time <= 0)
      return;
   if(begin_price <= 0.0 || end_price <= 0.0)
      return;

   datetime draw_begin_time = begin_time;
   datetime draw_end_time = end_time;
   double draw_begin_price = begin_price;
   double draw_end_price = end_price;
   ResolvePotentialImpulseEndpointTime(source_timeframe,
                                       draw_timeframe,
                                       begin_shift,
                                       begin_price,
                                       begin_is_high,
                                       begin_time,
                                       draw_begin_time);
   ResolvePotentialImpulseEndpointTime(source_timeframe,
                                       draw_timeframe,
                                       end_shift,
                                       end_price,
                                       end_is_high,
                                       end_time,
                                       draw_end_time);
   if(!ClipLineSegmentToLifecycleFocus(focus,
                                       draw_begin_time,
                                       draw_begin_price,
                                       draw_end_time,
                                       draw_end_price))
      return;

   UpsertPotentialCorrectionLine(name,
                                 fact,
                                 draw_state,
                                 is_active,
                                 source_timeframe,
                                 draw_timeframe,
                                 draw_begin_time,
                                 draw_end_time,
                                 draw_begin_price,
                                 draw_end_price);
  }

void DrawStatusBlock(const int chart_timeframe,
                     const int point_count,
                     const int confirmed_point_count,
                     const int provisional_point_count,
                     const string current_pattern,
                     const string current_break_state,
                     const string current_break_certainty,
                     const MohyLifecycleFocus &focus,
                     const CMohyPriceActionSnapshot &snapshot)
  {
   if(!ShowStatusBlock)
      return;

   const bool current_only = IsCurrentPotentialOnlyMode();
   const bool focus_enabled = IsLifecycleFocusActive(focus);
   const bool resolved_runtime_focus = IsResolvedRuntimeFocusInCurrentOnly(focus);

   int selected_impulse_index = current_only
                                ? (focus_enabled ? focus.impulse_index : -1)
                                : SelectPotentialImpulseIndex(snapshot);
   int selected_correction_index = current_only
                                   ? (focus_enabled ? focus.correction_index : -1)
                                   : SelectPotentialCorrectionIndex(snapshot, true);
   if(!current_only && selected_correction_index < 0)
      selected_correction_index = SelectPotentialCorrectionIndex(snapshot, false);

   int best_plan_index = current_only
                         ? (focus_enabled ? focus.plan_index : -1)
                         : SelectTradeSetupPlanIndex(snapshot, -1);
   if(current_only && resolved_runtime_focus)
      best_plan_index = -1;
   if(current_only && focus_enabled &&
      !resolved_runtime_focus &&
      best_plan_index < 0 &&
      focus.runtime_setup_key != "")
      best_plan_index = FindTradeSetupPlanIndexBySetupKey(snapshot, focus.runtime_setup_key);

   if(!current_only && best_plan_index >= 0)
     {
      const MohyTradeSetupPlanFact plan = snapshot.trade_setup_plans[best_plan_index];
      if(plan.linked_potential_impulse_index >= 0 &&
         plan.linked_potential_impulse_index < ArraySize(snapshot.potential_impulses))
         selected_impulse_index = plan.linked_potential_impulse_index;
      if(plan.linked_potential_correction_index >= 0 &&
         plan.linked_potential_correction_index < ArraySize(snapshot.potential_corrections))
         selected_correction_index = plan.linked_potential_correction_index;
     }

   string lines[];
   ArrayResize(lines, 20);
   lines[0] = "MOHY Visualizer";
   lines[1] = "Stage: Peak/Valley (Tick Snapshot)";
   lines[2] = StringFormat("ChartTF: %s", MohyTimeframeToString(chart_timeframe));
   lines[3] = StringFormat("Pair: %s/%s",
                           MohyTimeframeToString(g_cfg.context_timeframe),
                           MohyTimeframeToString(g_cfg.execution_timeframe));
   lines[4] = StringFormat("RenderTF: %s", MohyTimeframeToString(g_render_timeframe));
   lines[5] = StringFormat("SnapshotTF: %s | ExecFacts: %s",
                           MohyTimeframeToString(snapshot.timeframe),
                           snapshot.publishes_execution_stage_facts ? "Yes" : "No");
   lines[6] = StringFormat("Pivots: %d", point_count);
   lines[7] = StringFormat("Confirmed/Live: %d/%d", confirmed_point_count, provisional_point_count);
   lines[8] = StringFormat("Pivots L/R: %d/%d",
                           g_cfg.detection.swing_left_bars,
                           g_cfg.detection.swing_right_bars);
   lines[9] = StringFormat("Lookback: %d | Mode: %s",
                           MathMax(20, LookbackBars),
                           IsCurrentPotentialOnlyMode() ? "LifecycleFocus" : "History");
   lines[10] = "Cadence: Every Tick";
   lines[11] = StringFormat("Pattern: %s", current_pattern);
   lines[12] = StringFormat("Break/Certainty: %s / %s",
                            current_break_state,
                            current_break_certainty);
   lines[13] = "PotImpulse: n/a";
   lines[14] = "PotCorrection: n/a";
   if(selected_impulse_index >= 0 && selected_impulse_index < ArraySize(snapshot.potential_impulses))
     {
      const MohyPotentialImpulseFact fact = snapshot.potential_impulses[selected_impulse_index];
      if(fact.valid)
         lines[13] = StringFormat("PotImpulse: %s %s/%s",
                                  fact.confirmed ? "Confirmed" : "Live",
                                  MohyBreakStateToString(fact.break_state),
                                  MohyBreakoutCertaintyToString(fact.swing_breakout_certainty));
     }
   if(selected_correction_index >= 0 && selected_correction_index < ArraySize(snapshot.potential_corrections))
     {
      const MohyPotentialCorrectionFact fact = snapshot.potential_corrections[selected_correction_index];
      if(fact.valid)
        {
         if(fact.state == MOHY_POT_CORR_STATE_INVALIDATED)
            lines[14] = StringFormat("PotCorrection: %s %s",
                                     MohyPotentialCorrectionStateToString(fact.state),
                                     MohyPotentialCorrectionTerminationReasonToString(fact.termination_reason));
         else
            lines[14] = StringFormat("PotCorrection: %s Depth=%.3f OppICI=%d/%d",
                                     MohyPotentialCorrectionStateToString(fact.state),
                                     fact.retrace_depth,
                                     fact.opposite_ici_count,
                                     fact.min_opposite_ici_count);
        }
     }
   lines[15] = StringFormat("Focus: %s",
                            IsLifecycleFocusActive(focus)
                            ? StringFormat("%s%s",
                                           focus.runtime_joined
                                           ? MohyRuntimeLifecycleStateToString(focus.runtime_record.lifecycle_state)
                                           : "KernelFallback",
                                           focus.runtime_joined ? " (Runtime)" : "")
                            : "n/a");
   lines[16] = StringFormat("FocusKey: %s",
                            (focus.runtime_setup_key != "") ? focus.runtime_setup_key : "-");
   lines[17] = StringFormat("FocusWindow: %s -> %s",
                            (focus.render_start_time > 0)
                            ? TimeToString(focus.render_start_time, TIME_DATE | TIME_MINUTES)
                            : "-",
                            (focus.render_end_time > 0)
                            ? TimeToString(focus.render_end_time, TIME_DATE | TIME_MINUTES)
                            : "-");
   lines[18] = "SetupPlan: n/a";
   lines[19] = StringFormat("Setup/Hist Count: %d / %d",
                            ArraySize(snapshot.trade_setup_plans),
                            ArraySize(snapshot.historical_trade_setups));

   if(best_plan_index >= 0)
     {
      const MohyTradeSetupPlanFact plan = snapshot.trade_setup_plans[best_plan_index];
      lines[18] = StringFormat("SetupPlan: %s RR=%.2f Entry=%.5f",
                               MohyTradeSetupPlanStateToString(plan.plan_state),
                               plan.reward_to_risk,
                               plan.proposed_entry_price);
     }

   const int dock_corner = ResolveStatusBlockCorner(StatusBlockDock);
   const int dock_anchor = ResolveStatusBlockAnchor(dock_corner);
   const int x_offset = MathMax(0, StatusBlockOffsetX);
   const bool is_bottom_dock = (dock_corner == CORNER_LEFT_LOWER || dock_corner == CORNER_RIGHT_LOWER);
   const int line_count = ArraySize(lines);

   for(int i = 0; i < ArraySize(lines); ++i)
     {
      const string name = StringFormat("%sSTATUS_%d", VisualizerPrefix(), i);
      if(ObjectFind(0, name) < 0)
         if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
            continue;
      ObjectSetInteger(0, name, OBJPROP_CORNER, dock_corner);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, dock_anchor);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x_offset);
      const int y_distance = is_bottom_dock
                             ? (20 + (line_count - 1 - i) * 16)
                             : (20 + i * 16);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y_distance);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      SetObjectText(name,
                    lines[i],
                    StatusBlockTextFontSize,
                    "Consolas",
                    StatusBlockTextColor);
      TouchRenderObject(name);
     }
  }

bool BuildKernelSnapshot(const int timeframe,
                         const MohyRenderWindow &window,
                         CMohyPriceActionSnapshot &out_snapshot)
  {
   out_snapshot.Reset();
   if(timeframe <= 0)
      return false;

   const int bars = MohyIBars(Symbol(), timeframe);
   if(bars <= g_cfg.detection.swing_right_bars + 2)
      return false;

   const int from_shift = g_cfg.detection.swing_right_bars + 1;
   const int max_shift = ResolveSourceMaxShiftFromWindow(timeframe, window);
   if(max_shift < from_shift)
      return false;

   CMohyPriceActionKernel kernel;
   kernel.Configure(g_cfg,
                    timeframe,
                    g_cfg.context_timeframe,
                    g_cfg.execution_timeframe);

   if(!kernel.Build(Symbol(), from_shift, max_shift, out_snapshot, true))
      return false;

   return (ArraySize(out_snapshot.elements) > 0);
  }

int BuildAlternatingSwingStreamFromSnapshot(const CMohyPriceActionSnapshot &snapshot,
                                            MohySwingPoint &out_points[],
                                            const datetime min_time = 0,
                                            const datetime max_time = 0)
  {
   ArrayResize(out_points, 0);
   const int element_count = ArraySize(snapshot.elements);
   if(element_count <= 0)
      return 0;

   int point_count = 0;
   for(int i = 0; i < element_count; ++i)
     {
      if(min_time > 0 && snapshot.elements[i].time < min_time)
         continue;
      if(max_time > 0 && snapshot.elements[i].time > max_time)
         continue;

      ArrayResize(out_points, point_count + 1);
      out_points[point_count].is_high = (snapshot.elements[i].type == MOHY_ELEMENT_PEAK);
      out_points[point_count].confirmed = snapshot.elements[i].confirmed;
      out_points[point_count].shift = snapshot.elements[i].shift;
      out_points[point_count].time = snapshot.elements[i].time;
      out_points[point_count].price = snapshot.elements[i].pivot_price;
      point_count++;
     }
   return point_count;
  }

int BuildPatternRibbonPointsFromSnapshot(const CMohyPriceActionSnapshot &snapshot,
                                         MohyRibbonPoint &out_points[],
                                         const datetime min_time = 0,
                                         const datetime max_time = 0)
  {
   ArrayResize(out_points, 0);
   const int swing_count = ArraySize(snapshot.swings3);
   const int leg_count = ArraySize(snapshot.legs);
   if(swing_count <= 0 || leg_count <= 0)
      return 0;

   int point_count = 0;
   for(int i = 0; i < swing_count; ++i)
     {
      const MohySwing3Fact swing = snapshot.swings3[i];
      if(swing.leg3_index < 0 || swing.leg3_index >= leg_count)
         continue;

      const MohyLegFact leg3 = snapshot.legs[swing.leg3_index];
      if(leg3.end_time <= 0)
         continue;
      if(min_time > 0 && leg3.end_time < min_time)
         continue;
      if(max_time > 0 && leg3.end_time > max_time)
         continue;

      ArrayResize(out_points, point_count + 1);
      out_points[point_count].end_time = leg3.end_time;
      out_points[point_count].end_shift = leg3.end_shift;
      out_points[point_count].confirmed = swing.confirmed;
      out_points[point_count].pattern_type = swing.pattern_type;
      out_points[point_count].break_state = swing.break_state;
      out_points[point_count].breakout_certainty = swing.breakout_certainty;
      out_points[point_count].direction = swing.direction;
      point_count++;
     }

   return point_count;
  }

void ResolveCurrentPatternState(const CMohyPriceActionSnapshot &snapshot,
                                string &out_pattern,
                                string &out_break_state,
                                string &out_break_certainty)
  {
   out_pattern = "-";
   out_break_state = "-";
   out_break_certainty = "-";

   const int swing_count = ArraySize(snapshot.swings3);
   if(swing_count <= 0)
      return;

   const MohySwing3Fact current = snapshot.swings3[swing_count - 1];
   const string base_pattern = Swing3PatternLabel(current.pattern_type, current.direction);
   out_pattern = current.confirmed ? base_pattern : StringFormat("%s*", base_pattern);
   out_break_state = MohyBreakStateToString(current.break_state);
   out_break_certainty = MohyBreakoutCertaintyToString(current.breakout_certainty);
  }

bool ResolvePatternRibbonPriceBounds(double &out_bottom,
                                     double &out_top,
                                     double &out_label_price)
  {
   double price_min = MohyChartPriceMin(0, 0);
   double price_max = MohyChartPriceMax(0, 0);
   if(price_max <= price_min)
     {
      const int bars_probe = MathMin(MathMax(100, LookbackBars), MohyIBars(Symbol(), g_render_timeframe) - 1);
      if(bars_probe < 5)
         return false;

      const int highest_shift = MohyIHighest(Symbol(), g_render_timeframe, MODE_HIGH, bars_probe, 1);
      const int lowest_shift = MohyILowest(Symbol(), g_render_timeframe, MODE_LOW, bars_probe, 1);
      if(highest_shift < 0 || lowest_shift < 0)
         return false;
      price_max = MohyIHigh(Symbol(), g_render_timeframe, highest_shift);
      price_min = MohyILow(Symbol(), g_render_timeframe, lowest_shift);
      if(price_max <= price_min)
         return false;
     }

   const int height_pct = MathMax(3, MathMin(30, PatternRibbonHeightPercent));
   const double range = price_max - price_min;
   out_bottom = price_min;
   out_top = price_min + range * ((double)height_pct / 100.0);
   if(out_top <= out_bottom)
      return false;

   out_label_price = out_bottom + (out_top - out_bottom) * 0.25;
   return true;
  }

double ResolvePeakValleyLabelOffsetPrice(const int timeframe)
  {
   const double point = ResolveSymbolPoint(Symbol());
   const double configured_offset = MathMax(1, PeakValleyLabelOffsetPoints) * point;

   double price_min = MohyChartPriceMin(0, 0);
   double price_max = MohyChartPriceMax(0, 0);
   if(price_max <= price_min)
     {
      const int bars_total = MohyIBars(Symbol(), timeframe);
      const int bars_probe = MathMin(MathMax(100, LookbackBars), bars_total - 1);
      if(bars_probe > 0)
        {
         const int highest_shift = MohyIHighest(Symbol(), timeframe, MODE_HIGH, bars_probe, 1);
         const int lowest_shift = MohyILowest(Symbol(), timeframe, MODE_LOW, bars_probe, 1);
         if(highest_shift >= 0 && lowest_shift >= 0)
           {
            price_max = MohyIHigh(Symbol(), timeframe, highest_shift);
            price_min = MohyILow(Symbol(), timeframe, lowest_shift);
           }
        }
     }

   double offset = configured_offset;
   if(price_max > price_min)
     {
      // Keep labels near candles when the visible chart range is very compressed.
      const double visible_range = price_max - price_min;
      const double max_offset = visible_range * 0.015;
      if(max_offset > 0.0)
         offset = MathMin(offset, max_offset);
     }

   const double min_offset = point * 2.0;
   if(offset < min_offset)
      offset = min_offset;
   return offset;
  }

double ResolveSetupLabelOffsetPrice(const int timeframe,
                                    const int font_size)
  {
   const double point = ResolveSymbolPoint(Symbol());
   double offset = MathMax(4.0, (double)MathMax(6, font_size)) * point;

   double price_min = MohyChartPriceMin(0, 0);
   double price_max = MohyChartPriceMax(0, 0);
   if(price_max <= price_min)
     {
      const int bars_total = MohyIBars(Symbol(), timeframe);
      const int bars_probe = MathMin(MathMax(100, LookbackBars), bars_total - 1);
      if(bars_probe > 0)
        {
         const int highest_shift = MohyIHighest(Symbol(), timeframe, MODE_HIGH, bars_probe, 1);
         const int lowest_shift = MohyILowest(Symbol(), timeframe, MODE_LOW, bars_probe, 1);
         if(highest_shift >= 0 && lowest_shift >= 0)
           {
            price_max = MohyIHigh(Symbol(), timeframe, highest_shift);
            price_min = MohyILow(Symbol(), timeframe, lowest_shift);
           }
        }
     }

   if(price_max > price_min)
     {
      const double visible_range = price_max - price_min;
      const double max_offset = visible_range * 0.012;
      if(max_offset > 0.0)
         offset = MathMin(offset, max_offset);
     }

   const double min_offset = point * 3.0;
   if(offset < min_offset)
      offset = min_offset;
   return offset;
  }

bool IsSetupLabelPlacementAvailable(const datetime candidate_time,
                                    const double candidate_price,
                                    const int time_spacing_seconds,
                                    const double price_spacing)
  {
   for(int i = 0; i < g_setup_label_count; ++i)
     {
      if(MathAbs((double)(candidate_time - g_setup_label_times[i])) < (double)time_spacing_seconds &&
         MathAbs(candidate_price - g_setup_label_prices[i]) < price_spacing)
         return false;
     }
   return true;
  }

void ReserveSetupLabelPlacement(const datetime label_time,
                                const double label_price)
  {
   ArrayResize(g_setup_label_times, g_setup_label_count + 1);
   ArrayResize(g_setup_label_prices, g_setup_label_count + 1);
   g_setup_label_times[g_setup_label_count] = label_time;
   g_setup_label_prices[g_setup_label_count] = label_price;
   g_setup_label_count++;
  }

void ResolveSetupLabelPlacement(const int timeframe,
                                const datetime base_time,
                                const double base_price,
                                const int font_size,
                                const bool prefer_above,
                                datetime &out_time,
                                double &out_price)
  {
   out_time = base_time;
   out_price = base_price;
   if(base_time <= 0 || base_price <= 0.0)
      return;

   int tf_seconds = ResolveTimeframeSecondsSafe(timeframe);
   if(tf_seconds <= 0)
      tf_seconds = 60;

   const int time_spacing_seconds = MathMax(60, tf_seconds);
   const double price_spacing = ResolveSetupLabelOffsetPrice(timeframe, font_size);
   const int horizontal_slots = 4;

   for(int lane = 0; lane < 24; ++lane)
     {
      const int horizontal_lane = lane % horizontal_slots;
      const int vertical_tier = lane / horizontal_slots;
      const int signed_tier = vertical_tier + 1;
      const datetime candidate_time = base_time + (horizontal_lane * time_spacing_seconds);
      const double candidate_price = base_price + ((prefer_above ? 1.0 : -1.0) * signed_tier * price_spacing);
      if(!IsSetupLabelPlacementAvailable(candidate_time,
                                         candidate_price,
                                         MathMax(30, time_spacing_seconds / 2),
                                         price_spacing * 0.8))
         continue;

      out_time = candidate_time;
      out_price = candidate_price;
      ReserveSetupLabelPlacement(out_time, out_price);
      return;
     }

   ReserveSetupLabelPlacement(out_time, out_price);
  }

void UpsertPatternRibbonRect(const string name,
                             const datetime start_time,
                             const datetime end_time,
                             const double bottom_price,
                             const double top_price,
                             const color fill_color,
                             const string tooltip)
  {
   if(start_time <= 0 || end_time <= 0 || end_time <= start_time)
      return;
   if(top_price <= bottom_price)
      return;

   if(ObjectFind(0, name) >= 0 && (ENUM_OBJECT)ObjectGetInteger(0, name, OBJPROP_TYPE) != OBJ_RECTANGLE)
      ObjectDelete(0, name);

   if(ObjectFind(0, name) < 0)
     {
      if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, start_time, bottom_price, end_time, top_price))
         return;
     }
   else
     {
      ObjectMove(0, name, 0, start_time, bottom_price);
      ObjectMove(0, name, 1, end_time, top_price);
     }

   ObjectSetInteger(0, name, OBJPROP_COLOR, fill_color);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
   TouchRenderObject(name);
  }

void UpsertPatternRibbonText(const string name,
                             const datetime t,
                             const double price,
                             const string text,
                             const color c,
                             const string tooltip)
  {
   if(!PatternRibbonShowText)
      return;
   if(t <= 0 || price <= 0.0 || text == "")
      return;

   if(ObjectFind(0, name) >= 0 && (ENUM_OBJECT)ObjectGetInteger(0, name, OBJPROP_TYPE) != OBJ_TEXT)
      ObjectDelete(0, name);

   if(ObjectFind(0, name) < 0)
     {
      if(!ObjectCreate(0, name, OBJ_TEXT, 0, t, price))
         return;
     }
   else
      ObjectMove(0, name, 0, t, price);

   SetObjectText(name, text, PatternRibbonTextFontSize, "Consolas", c);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
   TouchRenderObject(name);
  }

void UpsertPatternRibbonConnector(const string name,
                                  const datetime t,
                                  const double bottom_price,
                                  const double top_price,
                                  const color c,
                                  const string tooltip)
  {
   if(!PatternRibbonConnectorsEnabled)
      return;
   if(t <= 0 || bottom_price <= 0.0 || top_price <= 0.0 || top_price <= bottom_price)
      return;

   if(ObjectFind(0, name) >= 0 && (ENUM_OBJECT)ObjectGetInteger(0, name, OBJPROP_TYPE) != OBJ_TREND)
      ObjectDelete(0, name);

   if(ObjectFind(0, name) < 0)
     {
      if(!ObjectCreate(0, name, OBJ_TREND, 0, t, bottom_price, t, top_price))
         return;
     }
   else
     {
      ObjectMove(0, name, 0, t, bottom_price);
      ObjectMove(0, name, 1, t, top_price);
     }

   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_STYLE, MathMax(0, MathMin(4, PatternRibbonConnectorStyle)));
   ObjectSetInteger(0, name, OBJPROP_WIDTH, MathMax(1, PatternRibbonConnectorWidth));
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
   TouchRenderObject(name);
  }

bool ResolvePatternRibbonConnectorTarget(const int timeframe,
                                         const MohyPatternRibbonSegment &segment,
                                         const double ribbon_top,
                                         const double chart_top_price,
                                         datetime &out_connector_time,
                                         double &out_connector_top_price)
  {
   out_connector_time = (segment.anchor_time > 0) ? segment.anchor_time : segment.end_time;
   if(out_connector_time <= 0)
      return false;

   int anchor_shift = MohyIBarShift(Symbol(), timeframe, out_connector_time, false);
   if(anchor_shift < 0)
     {
      out_connector_top_price = chart_top_price;
      return (out_connector_top_price > ribbon_top);
     }

   const double anchor_high = MohyIHigh(Symbol(), timeframe, anchor_shift);
   const double anchor_low = MohyILow(Symbol(), timeframe, anchor_shift);
   if(anchor_high > 0.0 && anchor_low > 0.0)
      out_connector_top_price = (anchor_high + anchor_low) * 0.5;
   else
      out_connector_top_price = MohyIClose(Symbol(), timeframe, anchor_shift);

   if(out_connector_top_price <= ribbon_top)
      out_connector_top_price = chart_top_price;

   return (out_connector_top_price > ribbon_top);
  }

datetime ResolveRibbonLabelMidTime(const datetime start_time,
                                   const datetime end_time,
                                   const double reference_price)
  {
   if(start_time <= 0 || end_time <= start_time)
      return start_time;

   int start_x = 0;
   int start_y = 0;
   int end_x = 0;
   int end_y = 0;
   if(ChartTimePriceToXY(0, 0, start_time, reference_price, start_x, start_y) &&
      ChartTimePriceToXY(0, 0, end_time, reference_price, end_x, end_y))
     {
      const int mid_x = (start_x + end_x) / 2;
      int sub_window = 0;
      datetime mid_time = 0;
      double mid_price = reference_price;
      if(ChartXYToTimePrice(0, mid_x, start_y, sub_window, mid_time, mid_price) && mid_time > 0)
         return mid_time;
     }

   return start_time + (end_time - start_time) / 2;
  }

void DrawPatternRibbon(const int timeframe,
                       const MohyRenderWindow &window,
                       const datetime min_time,
                       const MohyLifecycleFocus &focus,
                       const CMohyPriceActionSnapshot &snapshot)
  {
   if(!PatternRibbonEnabled)
      return;
  
   MohyRibbonPoint points[];
   const int point_count = BuildPatternRibbonPointsFromSnapshot(snapshot,
                                                                points,
                                                                min_time,
                                                                IsLifecycleFocusActive(focus) ? focus.render_end_time : 0);
   if(point_count <= 0)
      return;

   double ribbon_bottom = 0.0;
   double ribbon_top = 0.0;
   double ribbon_label_price = 0.0;
   if(!ResolvePatternRibbonPriceBounds(ribbon_bottom, ribbon_top, ribbon_label_price))
      return;

   double chart_top_price = MohyChartPriceMax(0, 0);
   if(chart_top_price <= ribbon_top)
     {
      const int bars_probe = MathMin(MathMax(100, LookbackBars), MohyIBars(Symbol(), timeframe) - 1);
      if(bars_probe > 0)
        {
         const int highest_shift = MohyIHighest(Symbol(), timeframe, MODE_HIGH, bars_probe, 1);
         if(highest_shift >= 0)
            chart_top_price = MohyIHigh(Symbol(), timeframe, highest_shift);
        }
     }
   if(chart_top_price <= ribbon_top)
      chart_top_price = ribbon_top + MathMax(ribbon_top - ribbon_bottom, ResolveSymbolPoint(Symbol()) * 10.0);

   const int start_index = 0;
   datetime window_start_time = window.start_time;
   if(window_start_time < min_time)
      window_start_time = min_time;
   if(window_start_time <= 0)
      window_start_time = points[start_index].end_time;
   datetime window_end_time = MohyITime(Symbol(), timeframe, 1);
   if(window_end_time <= 0)
      window_end_time = TimeCurrent();
   if(IsLifecycleFocusActive(focus) &&
      focus.render_end_time > 0 &&
      focus.render_end_time < window_end_time)
      window_end_time = focus.render_end_time;

   MohyPatternRibbonSegment segments[];
   int segment_count = 0;
   datetime segment_start = window_start_time;
   for(int i = start_index; i < point_count; ++i)
     {
      const datetime segment_end = points[i].end_time;
      if(segment_end <= segment_start)
         continue;

      MohyPatternRibbonSegment candidate;
      candidate.start_time = segment_start;
      candidate.end_time = segment_end;
      candidate.anchor_time = points[i].end_time;
      candidate.confirmed = points[i].confirmed;
      candidate.pattern_type = points[i].pattern_type;
      candidate.break_state = points[i].break_state;
      candidate.breakout_certainty = points[i].breakout_certainty;
      candidate.direction = points[i].direction;

      if(segment_count > 0 &&
         segments[segment_count - 1].confirmed == candidate.confirmed &&
         segments[segment_count - 1].pattern_type == candidate.pattern_type &&
         segments[segment_count - 1].direction == candidate.direction &&
         segments[segment_count - 1].break_state == candidate.break_state &&
         segments[segment_count - 1].breakout_certainty == candidate.breakout_certainty)
        {
         segments[segment_count - 1].end_time = candidate.end_time;
         segments[segment_count - 1].anchor_time = candidate.anchor_time;
        }
      else
        {
         ArrayResize(segments, segment_count + 1);
         segments[segment_count] = candidate;
         segment_count++;
        }

      segment_start = segment_end;
     }

   if(segment_count <= 0)
      return;

   if(window_end_time > segments[segment_count - 1].end_time)
      segments[segment_count - 1].end_time = window_end_time;

   const string tf_text = MohyTimeframeToString(timeframe);
   string previous_label = "";
   for(int i = 0; i < segment_count; ++i)
     {
      const MohyPatternRibbonSegment segment = segments[i];
      if(segment.end_time <= segment.start_time)
         continue;
      if(!IsPatternRibbonPatternVisible(segment.pattern_type))
         continue;

      const string base_label = Swing3PatternCode(segment.pattern_type);
      const string segment_label = segment.confirmed ? base_label : StringFormat("%s*", base_label);
      const string segment_tooltip = StringFormat("%s | Dir=%s | State=%s | Break=%s | Certainty=%s | %s -> %s",
                                                  segment_label,
                                                  (segment.direction == MOHY_DIR_BULL) ? "Bull" : ((segment.direction == MOHY_DIR_BEAR) ? "Bear" : "None"),
                                                  segment.confirmed ? "Confirmed" : "Live",
                                                  MohyBreakStateToString(segment.break_state),
                                                  MohyBreakoutCertaintyToString(segment.breakout_certainty),
                                                  TimeToString(segment.start_time, TIME_DATE | TIME_MINUTES),
                                                  TimeToString(segment.end_time, TIME_DATE | TIME_MINUTES));
      const color segment_color = ResolvePatternRibbonColor(segment.pattern_type);

      const string segment_name = StringFormat("%sRIB_SEG_%s_%d",
                                               VisualizerPrefix(),
                                               tf_text,
                                               i);
      UpsertPatternRibbonRect(segment_name,
                              segment.start_time,
                              segment.end_time,
                              ribbon_bottom,
                              ribbon_top,
                              segment_color,
                              segment_tooltip);

      if(PatternRibbonConnectorsEnabled)
        {
         datetime connector_time = 0;
         double connector_top_price = 0.0;
         if(ResolvePatternRibbonConnectorTarget(timeframe,
                                                segment,
                                                ribbon_top,
                                                chart_top_price,
                                                connector_time,
                                                connector_top_price))
           {
            const string connector_name = StringFormat("%sRIB_CON_%s_%d",
                                                       VisualizerPrefix(),
                                                       tf_text,
                                                       i);
            UpsertPatternRibbonConnector(connector_name,
                                         connector_time,
                                         ribbon_top,
                                         connector_top_price,
                                         segment_color,
                                         segment_tooltip);
           }
        }

      if(!PatternRibbonShowText)
         continue;
      if(PatternRibbonTextOnPatternChangeOnly && previous_label == segment_label)
         continue;

      const datetime mid_time = ResolveRibbonLabelMidTime(segment.start_time,
                                                          segment.end_time,
                                                          ribbon_label_price);
      const string label_name = StringFormat("%sRIB_TXT_%s_%d",
                                             VisualizerPrefix(),
                                             tf_text,
                                             i);
      UpsertPatternRibbonText(label_name,
                              mid_time,
                              ribbon_label_price,
                              segment_label,
                              PatternRibbonTextColor,
                              segment_tooltip);
      previous_label = segment_label;
     }
  }

void DrawPotentialImpulse(const int source_timeframe,
                          const int draw_timeframe,
                          const MohyRenderWindow &window,
                          const int selected_index,
                          const MohyLifecycleFocus &focus,
                          const CMohyPriceActionSnapshot &snapshot)
  {
   if(!PotentialImpulseEnabled)
      return;
   if(source_timeframe <= 0 || draw_timeframe <= 0)
      return;

   const int impulse_count = ArraySize(snapshot.potential_impulses);
   if(impulse_count <= 0)
      return;
   const bool focus_enabled = IsLifecycleFocusActive(focus);
   if(IsCurrentPotentialOnlyMode() &&
      selected_index < 0 &&
      (!focus_enabled || focus.runtime_impulse_id == ""))
      return;

   const string tf_text = MohyTimeframeToString(source_timeframe);
   for(int i = 0; i < impulse_count; ++i)
     {
      if(focus_enabled)
        {
         if(focus.runtime_impulse_id != "" &&
            snapshot.potential_impulses[i].runtime_impulse_id != focus.runtime_impulse_id)
            continue;
        }
      if(selected_index >= 0 && i != selected_index)
         continue;

      const MohyPotentialImpulseFact fact = snapshot.potential_impulses[i];
      if(!fact.valid)
         continue;

       if(fact.direction != MOHY_DIR_BULL && fact.direction != MOHY_DIR_BEAR)
          continue;
       if(window.start_time > 0 && fact.end_time < window.start_time)
          continue;

      datetime draw_begin_time = fact.begin_time;
      datetime draw_end_time = fact.end_time;
      double draw_begin_price = fact.begin_price;
      double draw_end_price = fact.end_price;
      const bool begin_is_high = (fact.direction == MOHY_DIR_BEAR);
      const bool end_is_high = !begin_is_high;
      ResolvePotentialImpulseEndpointTime(source_timeframe,
                                          draw_timeframe,
                                          fact.begin_shift,
                                          fact.begin_price,
                                          begin_is_high,
                                          fact.begin_time,
                                          draw_begin_time);
      ResolvePotentialImpulseEndpointTime(source_timeframe,
                                          draw_timeframe,
                                          fact.end_shift,
                                          fact.end_price,
                                          end_is_high,
                                          fact.end_time,
                                          draw_end_time);
      if(!ClipLineSegmentToLifecycleFocus(focus,
                                          draw_begin_time,
                                          draw_begin_price,
                                          draw_end_time,
                                          draw_end_price))
         continue;

      const string line_name = StringFormat("%sPOT_IMP_%s_%d",
                                            VisualizerPrefix(),
                                            tf_text,
                                            fact.index);
       UpsertPotentialImpulseLine(line_name,
                                  fact,
                                  source_timeframe,
                                  draw_timeframe,
                                  draw_begin_time,
                                  draw_end_time,
                                  draw_begin_price,
                                  draw_end_price);
     }
  }

void DrawPotentialCorrection(const int source_timeframe,
                             const int draw_timeframe,
                             const MohyRenderWindow &window,
                             const int selected_index,
                             const MohyLifecycleFocus &focus,
                             const CMohyPriceActionSnapshot &snapshot)
  {
   if(!PotentialCorrectionEnabled || !PotentialCorrectionShowLines)
      return;
   if(source_timeframe <= 0 || draw_timeframe <= 0)
      return;

   const int correction_count = ArraySize(snapshot.potential_corrections);
   if(correction_count <= 0)
      return;
   const bool focus_enabled = IsLifecycleFocusActive(focus);
   if(IsCurrentPotentialOnlyMode() &&
      selected_index < 0 &&
      (!focus_enabled || focus.runtime_impulse_id == ""))
      return;

   const bool state_segments_mode = (PotentialCorrectionRenderMode == MOHY_POT_CORR_RENDER_STATE_SEGMENTS);
   const string tf_text = MohyTimeframeToString(source_timeframe);
    for(int i = 0; i < correction_count; ++i)
      {
       if(focus_enabled)
         {
          if(focus.correction_index >= 0 && i != focus.correction_index)
             continue;
          if(focus.correction_index < 0 &&
             focus.runtime_impulse_id != "" &&
             snapshot.potential_corrections[i].runtime_impulse_id != focus.runtime_impulse_id)
             continue;
         }
       if(selected_index >= 0 && i != selected_index)
          continue;

      const MohyPotentialCorrectionFact fact = snapshot.potential_corrections[i];
      if(!fact.valid)
         continue;
      if(window.start_time > 0 && fact.end_time < window.start_time)
         continue;

      const bool is_active = fact.is_active;
      const MohyPotentialCorrectionTimelineFact timeline = fact.timeline_full;

      if(!state_segments_mode)
        {
         int display_begin_shift = fact.visual_begin_shift;
         datetime display_begin_time = fact.visual_begin_time;
         double display_begin_price = fact.visual_begin_price;
         if(display_begin_shift < 0 || display_begin_time <= 0 || display_begin_price <= 0.0)
           {
            display_begin_shift = fact.reference_begin_shift;
            display_begin_time = fact.reference_begin_time;
            display_begin_price = fact.reference_begin_price;
           }
         if(display_begin_shift < 0 || display_begin_time <= 0 || display_begin_price <= 0.0)
           {
            display_begin_shift = fact.begin_shift;
            display_begin_time = fact.begin_time;
            display_begin_price = fact.begin_price;
           }
         const bool display_begin_is_high = (fact.impulse_direction == MOHY_DIR_BULL);

         int display_end_shift = fact.end_shift;
         datetime display_end_time = fact.end_time;
         double display_end_price = fact.end_price;
         const bool display_end_is_high = (fact.impulse_direction == MOHY_DIR_BEAR);

         if(display_begin_shift < 0 || display_end_shift < 0)
            continue;
         if(display_begin_time <= 0 || display_end_time <= 0)
            continue;
         if(display_begin_price <= 0.0 || display_end_price <= 0.0)
            continue;

          datetime draw_begin_time = display_begin_time;
          datetime draw_end_time = display_end_time;
          double draw_begin_price = display_begin_price;
          double draw_end_price = display_end_price;
          ResolvePotentialImpulseEndpointTime(source_timeframe,
                                              draw_timeframe,
                                              display_begin_shift,
                                             display_begin_price,
                                             display_begin_is_high,
                                             display_begin_time,
                                             draw_begin_time);
         ResolvePotentialImpulseEndpointTime(source_timeframe,
                                             draw_timeframe,
                                             display_end_shift,
                                             display_end_price,
                                              display_end_is_high,
                                              display_end_time,
                                              draw_end_time);
          if(!ClipLineSegmentToLifecycleFocus(focus,
                                              draw_begin_time,
                                              draw_begin_price,
                                              draw_end_time,
                                              draw_end_price))
             continue;

          const string line_name = StringFormat("%sPOT_CORR_%s_%d",
                                                VisualizerPrefix(),
                                               tf_text,
                                               fact.index);
         UpsertPotentialCorrectionLine(line_name,
                                       fact,
                                       fact.state,
                                       is_active,
                                        source_timeframe,
                                        draw_timeframe,
                                        draw_begin_time,
                                        draw_end_time,
                                        draw_begin_price,
                                        draw_end_price);
           continue;
         }

      int forming_begin_shift = fact.visual_begin_shift;
      datetime forming_begin_time = fact.visual_begin_time;
      double forming_begin_price = fact.visual_begin_price;
      if(forming_begin_shift < 0 || forming_begin_time <= 0 || forming_begin_price <= 0.0)
        {
         forming_begin_shift = fact.reference_begin_shift;
         forming_begin_time = fact.reference_begin_time;
         forming_begin_price = fact.reference_begin_price;
        }
      if(forming_begin_shift < 0 || forming_begin_time <= 0 || forming_begin_price <= 0.0)
        {
         forming_begin_shift = fact.begin_shift;
         forming_begin_time = fact.begin_time;
         forming_begin_price = fact.begin_price;
        }

      if(forming_begin_shift < 0 || forming_begin_time <= 0 || forming_begin_price <= 0.0)
         continue;

      const bool forming_begin_is_high = (fact.impulse_direction == MOHY_DIR_BULL);
      const bool forming_end_is_high = !forming_begin_is_high;
      if(timeline.forming_end_shift >= 0 &&
         timeline.forming_end_time > 0 &&
         timeline.forming_end_price > 0.0)
        {
         DrawPotentialCorrectionSegment(StringFormat("%sPOT_CORR_%s_%d_SEG_FORM",
                                                     VisualizerPrefix(),
                                                     tf_text,
                                                     fact.index),
                                        fact,
                                         MOHY_POT_CORR_STATE_FORMING,
                                         is_active,
                                         source_timeframe,
                                         draw_timeframe,
                                         focus,
                                         forming_begin_shift,
                                         forming_begin_time,
                                         forming_begin_price,
                                        forming_begin_is_high,
                                        timeline.forming_end_shift,
                                        timeline.forming_end_time,
                                        timeline.forming_end_price,
                                        forming_end_is_high);
        }

      if(timeline.has_confirmed_segment &&
         timeline.confirmed_begin_shift >= 0 &&
         timeline.confirmed_end_shift >= 0 &&
         timeline.confirmed_begin_time > 0 &&
         timeline.confirmed_end_time > 0 &&
         timeline.confirmed_begin_price > 0.0 &&
         timeline.confirmed_end_price > 0.0)
        {
         const bool confirmed_begin_is_high = (fact.impulse_direction == MOHY_DIR_BULL);
         const bool confirmed_end_is_high = !confirmed_begin_is_high;
         DrawPotentialCorrectionSegment(StringFormat("%sPOT_CORR_%s_%d_SEG_CONF",
                                                     VisualizerPrefix(),
                                                     tf_text,
                                                     fact.index),
                                        fact,
                                         MOHY_POT_CORR_STATE_CONFIRMED,
                                         is_active,
                                         source_timeframe,
                                         draw_timeframe,
                                         focus,
                                         timeline.confirmed_begin_shift,
                                         timeline.confirmed_begin_time,
                                         timeline.confirmed_begin_price,
                                        confirmed_begin_is_high,
                                        timeline.confirmed_end_shift,
                                        timeline.confirmed_end_time,
                                        timeline.confirmed_end_price,
                                        confirmed_end_is_high);
        }

      if(timeline.has_invalidated_segment &&
         timeline.invalid_begin_shift >= 0 &&
         timeline.invalid_end_shift >= 0 &&
         timeline.invalid_begin_time > 0 &&
         timeline.invalid_end_time > 0 &&
         timeline.invalid_begin_price > 0.0 &&
         timeline.invalid_end_price > 0.0)
        {
         const bool invalid_begin_is_high = (fact.impulse_direction == MOHY_DIR_BULL);
         const bool invalid_end_is_high = !invalid_begin_is_high;
         DrawPotentialCorrectionSegment(StringFormat("%sPOT_CORR_%s_%d_SEG_INV",
                                                     VisualizerPrefix(),
                                                     tf_text,
                                                     fact.index),
                                        fact,
                                         MOHY_POT_CORR_STATE_INVALIDATED,
                                         is_active,
                                         source_timeframe,
                                         draw_timeframe,
                                         focus,
                                         timeline.invalid_begin_shift,
                                         timeline.invalid_begin_time,
                                         timeline.invalid_begin_price,
                                        invalid_begin_is_high,
                                        timeline.invalid_end_shift,
                                        timeline.invalid_end_time,
                                        timeline.invalid_end_price,
                                        invalid_end_is_high);
        }
     }
  }

void DrawPotentialContinuationSignals(const int source_timeframe,
                                      const int draw_timeframe,
                                      const MohyRenderWindow &window,
                                      const int selected_index,
                                      const MohyLifecycleFocus &focus,
                                      const CMohyPriceActionSnapshot &snapshot)
  {
   if(!ContinuationSignalEnabled)
      return;
   if(source_timeframe <= 0 || draw_timeframe <= 0)
      return;

   const int signal_count = ArraySize(snapshot.potential_continuation_signals);
   if(signal_count <= 0)
      return;
   const bool focus_enabled = IsLifecycleFocusActive(focus);
   if(IsCurrentPotentialOnlyMode() &&
      selected_index < 0 &&
      (!focus_enabled || focus.runtime_setup_key == ""))
      return;

   const string tf_text = MohyTimeframeToString(source_timeframe);
    for(int i = 0; i < signal_count; ++i)
      {
       if(focus_enabled)
         {
          if(focus.signal_index >= 0 && i != focus.signal_index)
             continue;
          if(focus.runtime_setup_key != "" &&
             snapshot.potential_continuation_signals[i].runtime_setup_key != focus.runtime_setup_key)
             continue;
         }
       if(selected_index >= 0 && i != selected_index)
          continue;

      const MohyPotentialContinuationSignalFact fact = snapshot.potential_continuation_signals[i];
      if(!fact.valid)
         continue;
       if(fact.direction != MOHY_DIR_BULL && fact.direction != MOHY_DIR_BEAR)
          continue;
       if(fact.signal_time <= 0 || fact.broken_level_price <= 0.0)
          continue;
       if(window.start_time > 0 && fact.signal_time < window.start_time)
          continue;
       if(!IsTimeWithinLifecycleFocus(focus, fact.signal_time))
          continue;

      const string marker_name = StringFormat("%sPOT_CONT_%s_%d",
                                              VisualizerPrefix(),
                                              tf_text,
                                              fact.index);
       UpsertPotentialContinuationSignalMarker(marker_name,
                                               fact,
                                               source_timeframe,
                                               draw_timeframe,
                                               focus);
      }
  }

void DrawPeakValley(const int timeframe,
                    const MohySwingPoint &points[],
                    const int count)
  {
   if(timeframe <= 0 || count <= 0)
      return;

   const string tf_text = MohyTimeframeToString(timeframe);
   const double offset = ResolvePeakValleyLabelOffsetPrice(timeframe);
   const string peak_text = (TrimText(PeakValleyPeakLabelText) == "") ? "P" : TrimText(PeakValleyPeakLabelText);
   const string valley_text = (TrimText(PeakValleyValleyLabelText) == "") ? "V" : TrimText(PeakValleyValleyLabelText);

   for(int i = 0; i < count; ++i)
     {
      const MohySwingPoint current = points[i];
      const bool is_peak = current.is_high;
      const string side = is_peak ? "Peak" : "Valley";
      const string label_name = StringFormat("%sPV_%s_%d_%d",
                                             VisualizerPrefix(),
                                             tf_text,
                                             current.shift,
                                             is_peak ? 1 : 0);
      const string base_text = is_peak ? peak_text : valley_text;
      const string label_text = current.confirmed ? base_text : StringFormat("%s*", base_text);
      const color label_color = is_peak ? PeakValleyPeakLabelColor : PeakValleyValleyLabelColor;
      const double label_price = is_peak ? (current.price + offset) : (current.price - offset);
      const string label_tip = StringFormat("%s | State=%s | %s | %s",
                                            side,
                                            current.confirmed ? "Confirmed" : "Live",
                                            TimeToString(current.time, TIME_DATE | TIME_MINUTES),
                                            DoubleToString(current.price, ResolveSymbolDigits(Symbol())));

      UpsertPeakValleyLabel(label_name,
                            current.time,
                            label_price,
                            label_text,
                            label_color,
                            is_peak,
                            label_tip);

      if(i <= 0)
         continue;

      const MohySwingPoint left = points[i - 1];
      const string leg_name = StringFormat("%sLEG_%s_%d",
                                           VisualizerPrefix(),
                                           tf_text,
                                           i);
      const bool provisional_leg = (!left.confirmed || !current.confirmed);
      UpsertPeakValleyLegLine(leg_name, left, current, timeframe, provisional_leg);
     }
  }

void RefreshVisualizer()
  {
   BeginRenderObjectTracking();
   if(g_render_timeframe <= 0)
     {
      DeleteUntouchedVisualizerObjects();
      return;
     }

   const int chart_timeframe = (int)_Period;
   MohyRenderWindow window;
   if(!ResolveRenderWindow((chart_timeframe > 0) ? chart_timeframe : g_render_timeframe, window))
     {
      DeleteUntouchedVisualizerObjects();
      return;
     }

   int count = 0;
   int confirmed_count = 0;
   int provisional_count = 0;
   string current_pattern = "-";
   string current_break_state = "-";
   string current_break_certainty = "-";
   bool has_render_data = false;
   MohyLifecycleFocus focus;
   ResetLifecycleFocus(focus);

   CMohyPriceActionSnapshot snapshot;
   bool has_render_snapshot = false;
   if(BuildKernelSnapshot(g_render_timeframe, window, snapshot))
     {
      has_render_snapshot = true;
      has_render_data = true;
     }

   const int correction_source_timeframe = g_cfg.execution_timeframe;
   const bool needs_correction_snapshot =
      (correction_source_timeframe > 0 &&
       (IsCurrentPotentialOnlyMode() ||
        (PotentialCorrectionEnabled && PotentialCorrectionShowLines) ||
        ContinuationSignalEnabled ||
        TradeSetupPlanEnabled ||
        HistoricalTradeSetupEnabled));
   CMohyPriceActionSnapshot correction_snapshot;
   bool has_correction_snapshot = false;
   if(needs_correction_snapshot)
     {
      if(has_render_snapshot && correction_source_timeframe == g_render_timeframe)
         has_correction_snapshot = true;
      else
         has_correction_snapshot = BuildKernelSnapshot(correction_source_timeframe,
                                                       window,
                                                       correction_snapshot);
     }

   if(IsCurrentPotentialOnlyMode())
     {
      if(has_correction_snapshot)
        {
         if(has_render_snapshot && correction_source_timeframe == g_render_timeframe)
            ResolveLifecycleFocus(snapshot, window, focus);
         else
            ResolveLifecycleFocus(correction_snapshot, window, focus);
        }
      else if(has_render_snapshot)
         ResolveLifecycleFocus(snapshot, window, focus);
     }

   const bool current_only_mode = IsCurrentPotentialOnlyMode();
   const bool lifecycle_focus_active = IsLifecycleFocusActive(focus);
   const bool render_lifecycle_overlays = (!current_only_mode || lifecycle_focus_active);

   if(has_render_snapshot)
     {
      MohySwingPoint points[];
      datetime render_min_time = window.start_time;
      datetime render_max_time = 0;
      if(lifecycle_focus_active)
        {
         if(focus.render_start_time > render_min_time)
            render_min_time = focus.render_start_time;
         render_max_time = focus.render_end_time;
        }
      count = BuildAlternatingSwingStreamFromSnapshot(snapshot,
                                                      points,
                                                      render_min_time,
                                                      render_max_time);
      if(count > 0)
        {
         for(int i = 0; i < count; ++i)
           {
            if(points[i].confirmed)
               confirmed_count++;
            else
               provisional_count++;
           }
         DrawPeakValley(g_render_timeframe, points, count);
        }

      ResolveCurrentPatternState(snapshot,
                                 current_pattern,
                                 current_break_state,
                                 current_break_certainty);
      DrawPatternRibbon(g_render_timeframe,
                        window,
                        render_min_time,
                        focus,
                        snapshot);
     }

   if(PotentialImpulseEnabled && render_lifecycle_overlays)
      {
       int potential_source_timeframe = 0;
       if(ResolvePotentialImpulseRenderPlan(chart_timeframe, potential_source_timeframe) &&
          potential_source_timeframe > 0)
         {
           if(has_render_snapshot && potential_source_timeframe == g_render_timeframe)
             {
               int selected_impulse_index = -1;
               if(IsCurrentPotentialOnlyMode())
                 {
                  selected_impulse_index = (focus.impulse_index >= 0)
                                           ? focus.impulse_index
                                           : ((focus.runtime_impulse_id != "")
                                              ? FindPotentialImpulseIndexByRuntimeImpulseId(snapshot,
                                                                                            focus.runtime_impulse_id)
                                              : -1);
                 }
                DrawPotentialImpulse(potential_source_timeframe,
                                     chart_timeframe,
                                     window,
                                     selected_impulse_index,
                                     focus,
                                     snapshot);
                has_render_data = true;
             }
           else
             {
                CMohyPriceActionSnapshot potential_snapshot;
                if(BuildKernelSnapshot(potential_source_timeframe, window, potential_snapshot))
                  {
                    int potential_selected_impulse_index = -1;
                    if(IsCurrentPotentialOnlyMode())
                      {
                       potential_selected_impulse_index = (focus.impulse_index >= 0)
                                                          ? focus.impulse_index
                                                          : ((focus.runtime_impulse_id != "")
                                                             ? FindPotentialImpulseIndexByRuntimeImpulseId(potential_snapshot,
                                                                                                           focus.runtime_impulse_id)
                                                             : -1);
                      }
                    DrawPotentialImpulse(potential_source_timeframe,
                                         chart_timeframe,
                                         window,
                                         potential_selected_impulse_index,
                                         focus,
                                         potential_snapshot);
                    has_render_data = true;
                  }
            }
         }
      }

   if(needs_correction_snapshot && correction_source_timeframe > 0 && render_lifecycle_overlays)
      {
        if(has_render_snapshot && correction_source_timeframe == g_render_timeframe)
          {
           int selected_correction_index = -1;
           if(IsCurrentPotentialOnlyMode())
             {
              selected_correction_index = (focus.correction_index >= 0)
                                          ? focus.correction_index
                                          : SelectPotentialCorrectionIndex(snapshot, true);
             }
           const int selected_signal_index =
              IsCurrentPotentialOnlyMode()
              ? ((focus.signal_index >= 0)
                 ? focus.signal_index
                 : (focus.runtime_setup_key != ""
                    ? FindPotentialContinuationSignalIndexBySetupKey(snapshot, focus.runtime_setup_key)
                    : ((selected_correction_index >= 0)
                       ? SelectPotentialContinuationSignalIndex(snapshot, selected_correction_index)
                       : -1)))
              : -1;
           if(PotentialCorrectionEnabled && PotentialCorrectionShowLines)
             {
               DrawPotentialCorrection(correction_source_timeframe,
                                       chart_timeframe,
                                       window,
                                       selected_correction_index,
                                       focus,
                                       snapshot);
               has_render_data = true;
             }
           if(ContinuationSignalEnabled && !TradeSetupPlanEnabled)
             {
               DrawPotentialContinuationSignals(correction_source_timeframe,
                                               chart_timeframe,
                                               window,
                                               selected_signal_index,
                                               focus,
                                               snapshot);
               has_render_data = true;
             }
           if(TradeSetupPlanEnabled)
             {
               DrawTradeSetupPlans(correction_source_timeframe,
                                   chart_timeframe,
                                   window,
                                   focus,
                                   snapshot);
               has_render_data = true;
             }
           if(HistoricalTradeSetupEnabled)
             {
               DrawHistoricalTradeSetups(correction_source_timeframe,
                                         chart_timeframe,
                                         window,
                                         focus,
                                         snapshot);
               has_render_data = true;
             }
          }
        else if(has_correction_snapshot)
          {
           int selected_correction_index = -1;
           if(IsCurrentPotentialOnlyMode())
             {
              selected_correction_index = (focus.correction_index >= 0)
                                          ? focus.correction_index
                                          : SelectPotentialCorrectionIndex(correction_snapshot, true);
             }
           const int selected_signal_index =
              IsCurrentPotentialOnlyMode()
              ? ((focus.signal_index >= 0)
                 ? focus.signal_index
                 : (focus.runtime_setup_key != ""
                    ? FindPotentialContinuationSignalIndexBySetupKey(correction_snapshot, focus.runtime_setup_key)
                    : ((selected_correction_index >= 0)
                       ? SelectPotentialContinuationSignalIndex(correction_snapshot, selected_correction_index)
                       : -1)))
              : -1;
           if(PotentialCorrectionEnabled && PotentialCorrectionShowLines)
             {
               DrawPotentialCorrection(correction_source_timeframe,
                                       chart_timeframe,
                                       window,
                                       selected_correction_index,
                                       focus,
                                       correction_snapshot);
               has_render_data = true;
             }
           if(ContinuationSignalEnabled && !TradeSetupPlanEnabled)
             {
               DrawPotentialContinuationSignals(correction_source_timeframe,
                                               chart_timeframe,
                                               window,
                                               selected_signal_index,
                                               focus,
                                               correction_snapshot);
               has_render_data = true;
             }
           if(TradeSetupPlanEnabled)
             {
               DrawTradeSetupPlans(correction_source_timeframe,
                                   chart_timeframe,
                                   window,
                                   focus,
                                   correction_snapshot);
               has_render_data = true;
             }
           if(HistoricalTradeSetupEnabled)
             {
               DrawHistoricalTradeSetups(correction_source_timeframe,
                                         chart_timeframe,
                                         window,
                                         focus,
                                         correction_snapshot);
               has_render_data = true;
             }
          }
      }

   DrawStatusBlock(chart_timeframe,
                   count,
                   confirmed_count,
                   provisional_count,
                   current_pattern,
                   current_break_state,
                   current_break_certainty,
                   focus,
                   snapshot);

   if(!has_render_data)
     {
      // No current payload should still clear stale setup/history drawings.
     }
   DeleteUntouchedVisualizerObjects();
  }

int OnInit()
  {
   string error = "";
   if(!ConfigureFromInputs(error))
     {
      Print("MOHY_Visualizer | ERROR | ", error);
      return(INIT_PARAMETERS_INCORRECT);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, "MOHY_Visualizer");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   DeleteVisualizerObjects();
  }

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   if(id != CHARTEVENT_CHART_CHANGE)
      return;
   const int resolved_render_timeframe = ResolveRenderTimeframe((int)_Period,
                                                                 g_cfg.context_timeframe,
                                                                 g_cfg.execution_timeframe);
   if(resolved_render_timeframe != g_render_timeframe)
      g_render_timeframe = resolved_render_timeframe;
   RefreshVisualizer();
  }

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
   const int resolved_render_timeframe = ResolveRenderTimeframe((int)_Period,
                                                                 g_cfg.context_timeframe,
                                                                 g_cfg.execution_timeframe);
   if(resolved_render_timeframe != g_render_timeframe)
     {
      g_render_timeframe = resolved_render_timeframe;
     }

   RefreshVisualizer();
   return(rates_total);
  }


