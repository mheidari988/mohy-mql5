#property strict
#property script_show_inputs

#include <MOHY/Domain/Config.mqh>
#include <MOHY/Core/Compat/TerminalSeries.mqh>
#include <MOHY/Core/PriceActionKernel.mqh>

enum MohyKernelDebugScope
  {
   MOHY_KERNEL_DEBUG_SCOPE_LTF_ONLY = 0,
   MOHY_KERNEL_DEBUG_SCOPE_HTF_ONLY = 1,
   MOHY_KERNEL_DEBUG_SCOPE_HTF_AND_LTF = 2
  };

input string DebugRunId = "";
input ENUM_TIMEFRAMES HTF = PERIOD_H1;
input ENUM_TIMEFRAMES LTF = PERIOD_M15;
input MohyKernelDebugScope KernelDebugScope = MOHY_KERNEL_DEBUG_SCOPE_HTF_AND_LTF;
input bool IncludeProvisionalLatest = true;
input int LookbackBars = 1600;
input int WindowOlderContextBars = 200;
input int BarContextBeforeWindow = 50;
input int BarContextAfterWindow = 20;
input bool ExportFactsOutsideWindow = true;

input string StartLineName = "";
input string EndLineName = "";
input bool PreferSelectedVerticalLines = true;
input bool AllowAnyLinesFallback = true;
input datetime ManualWindowStart = 0;
input datetime ManualWindowEnd = 0;

input int SwingLeftBars = 1;
input int SwingRightBars = 1;
input MohyEqualSwingClassificationMode EqualSwingClassificationMode = MOHY_EQUAL_SWING_CLASSIFY_WEAKER;
input int ContinuationSwingRefIndex = 1;
input double BreakBufferPoints = 0.0;

input bool PotentialImpulseEnabled = true;
input int PotentialImpulseMinSwingBreakoutCloses = 1;
input bool PotentialImpulseRequireLegBreakout = true;
input int PotentialImpulseMinLegBreakoutCloses = 1;
input bool PotentialImpulseRequireDirectionalCandles = true;
input bool PotentialImpulseValidateEndpointCandles = false;
input int PotentialImpulseAllowOppositeBeginCandles = 0;
input int PotentialImpulseAllowOppositeEndCandles = 0;
input int PotentialImpulseMaxOppositeMiddleCandles = 0;
input bool PotentialImpulseAllowAnyOppositeBeforeLegBreakout = true;
input double PotentialImpulseDojiEpsilonPoints = 0.1;

input bool PotentialCorrectionEnabled = true;
input int PotentialCorrectionMinOppositeICICount = 1;
input MohyPotentialCorrectionMinFibLevel PotentialCorrectionMinFibLevel = MOHY_POT_CORR_MIN_FIB_0382;
input MohyLevelTriggerMode PotentialCorrectionMinFibTriggerMode = MOHY_LEVEL_TRIGGER_TOUCH;
input MohyPotentialCorrectionMaxFibLevel PotentialCorrectionMaxFibLevel = MOHY_POT_CORR_MAX_FIB_0786;
input MohyLevelTriggerMode PotentialCorrectionMaxFibTriggerMode = MOHY_LEVEL_TRIGGER_TOUCH;
input double PotentialCorrectionExtremeTouchEpsilonPoints = 0.0;
input int PotentialCorrectionExtremeTouchMinCount = 1;
input MohyPotentialCorrectionSupersedeDirectionMode PotentialCorrectionSupersedeDirectionMode = MOHY_POT_CORR_SUPERSEDE_DIR_ANY;
input MohyPotentialCorrectionSupersedeScope PotentialCorrectionSupersedeScope = MOHY_POT_CORR_SUPERSEDE_SCOPE_FORMING_ONLY;
input MohyContinuationPlanningStartMode ContinuationPlanningStartMode = MOHY_CONT_PLAN_START_P_OR_P_STAR;

input string OutputDirectory = "MOHY\\debug_window";

struct MohyDebugVLine
  {
   string   name;
   datetime time;
   bool     selected;
   long     line_color;
   int      style;
   int      width;
  };

int ToInt(const bool value)
  {
   return value ? 1 : 0;
  }

string BoolText(const bool value)
  {
   return value ? "1" : "0";
  }

bool ResolveIncludeProvisionalLatest()
  {
   static bool notice_logged = false;
   if(!IncludeProvisionalLatest && !notice_logged)
     {
      Print("[WindowDebugExporter] IncludeProvisionalLatest=false requested; kernel publication lock forces provisional=true.");
      notice_logged = true;
     }
   return true;
  }

string TimeText(const datetime value)
  {
   if(value <= 0)
      return "";
   return TimeToString(value, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
  }

string TrimText(const string value)
  {
   int start = 0;
   int end = StringLen(value) - 1;
   while(start <= end && StringGetCharacter(value, start) <= 32) start++;
   while(end >= start && StringGetCharacter(value, end) <= 32) end--;
   if(end < start)
      return "";
   return StringSubstr(value, start, end - start + 1);
  }

string NormalizeDirectoryPath(const string value)
  {
   string out = value;
   StringReplace(out, "/", "\\");
   while(StringFind(out, "\\\\") >= 0)
      StringReplace(out, "\\\\", "\\");
   return TrimText(out);
  }

bool EnsureOutputDirectory(const string relative_dir)
  {
   const string normalized = NormalizeDirectoryPath(relative_dir);
   if(normalized == "")
      return false;

   string parts[];
   const int count = StringSplit(normalized, '\\', parts);
   if(count <= 0)
      return false;

   string acc = "";
   for(int i = 0; i < count; ++i)
     {
      const string part = TrimText(parts[i]);
      if(part == "")
         continue;

      if(acc == "")
         acc = part;
      else
         acc = acc + "\\" + part;

      ResetLastError();
      FolderCreate(acc);
     }

   return true;
  }

string SanitizeToken(const string value)
  {
   string out = "";
   const int len = StringLen(value);
   for(int i = 0; i < len; ++i)
     {
      const int ch = StringGetCharacter(value, i);
      const bool ok_digit = (ch >= '0' && ch <= '9');
      const bool ok_lower = (ch >= 'a' && ch <= 'z');
      const bool ok_upper = (ch >= 'A' && ch <= 'Z');
      const bool ok_extra = (ch == '_' || ch == '-');
      if(ok_digit || ok_lower || ok_upper || ok_extra)
         out += StringSubstr(value, i, 1);
      else
         out += "_";
     }
   out = TrimText(out);
   if(out == "")
      out = "NA";
   return out;
  }

string BuildTimestampToken(const datetime t)
  {
   string out = TimeToString(t, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
   StringReplace(out, ".", "");
   StringReplace(out, ":", "");
   StringReplace(out, " ", "_");
   return out;
  }

uint Fnv1a32(const string text)
  {
   uint hash = 2166136261;
   const int len = StringLen(text);
   for(int i = 0; i < len; ++i)
     {
      const uint ch = (uint)StringGetCharacter(text, i);
      hash ^= (ch & 0xFF);
      hash *= 16777619;
      hash ^= ((ch >> 8) & 0xFF);
      hash *= 16777619;
     }
   return hash;
  }

string HashHex(const string text)
  {
   return StringFormat("%08X", (int)Fnv1a32(text));
  }

string EscapePayloadValue(const string value)
  {
   string out = value;
   StringReplace(out, "\\", "\\\\");
   StringReplace(out, ";", "\\;");
   StringReplace(out, "=", "\\=");
   StringReplace(out, "\r", " ");
   StringReplace(out, "\n", " ");
   return out;
  }

void PayloadAdd(string &io_payload,
                const string key,
                const string value)
  {
   if(key == "")
      return;
   if(io_payload != "")
      io_payload += ";";
   io_payload += key + "=" + EscapePayloadValue(value);
  }

void PayloadAddInt(string &io_payload,
                   const string key,
                   const int value)
  {
   PayloadAdd(io_payload, key, IntegerToString(value));
  }

void PayloadAddLong(string &io_payload,
                    const string key,
                    const long value)
  {
   PayloadAdd(io_payload, key, IntegerToString((int)value));
  }

void PayloadAddDouble(string &io_payload,
                      const string key,
                      const double value,
                      const int digits = 10)
  {
   PayloadAdd(io_payload, key, DoubleToString(value, digits));
  }

void PayloadAddBool(string &io_payload,
                    const string key,
                    const bool value)
  {
   PayloadAdd(io_payload, key, BoolText(value));
  }

void PayloadAddTime(string &io_payload,
                    const string key,
                    const datetime value)
  {
   PayloadAdd(io_payload, key, TimeText(value));
  }

bool IsTimeInWindow(const datetime t,
                    const datetime window_start,
                    const datetime window_end)
  {
   if(t <= 0 || window_start <= 0 || window_end <= 0)
      return false;
   return (t >= window_start && t <= window_end);
  }

bool IntersectsWindow(const datetime a,
                      const datetime b,
                      const datetime window_start,
                      const datetime window_end)
  {
   if(window_start <= 0 || window_end <= 0)
      return false;

   datetime left = a;
   datetime right = b;
   if(left <= 0 && right > 0)
      left = right;
   if(right <= 0 && left > 0)
      right = left;
   if(left <= 0 || right <= 0)
      return false;
   if(left > right)
     {
      const datetime temp = left;
      left = right;
      right = temp;
     }

   return !(right < window_start || left > window_end);
  }

bool ShouldWriteFact(const bool in_window)
  {
   return (ExportFactsOutsideWindow || in_window);
  }

string DirectionToText(const MohyDirection direction)
  {
   if(direction == MOHY_DIR_BULL)
      return "Bull";
   if(direction == MOHY_DIR_BEAR)
      return "Bear";
   return "None";
  }

string EntryExecutionModeToText(const MohyEntryExecutionMode mode)
  {
   if(mode == MOHY_ENTRY_REAL_PENDING_ORDER)
      return "RealPendingOrder";
   return "VirtualTrigger";
  }

string PostBEProfileToText(const MohyPostBEProfile profile)
  {
   if(profile == MOHY_POST_BE_TRAIL_ONLY)
      return "TrailOnly";
   if(profile == MOHY_POST_BE_PARTIAL_ONLY)
      return "PartialOnly";
   if(profile == MOHY_POST_BE_HYBRID)
      return "Hybrid";
   return "Off";
  }

string RejectReasonToText(const MohyRejectReason reason)
  {
   switch(reason)
     {
      case MOHY_REJECT_NONE: return "None";
      case MOHY_REJECT_NO_VALID_IMPULSE_CONTEXT: return "NoValidImpulseContext";
      case MOHY_REJECT_RETRACEMENT_INVALID: return "RetracementInvalid";
      case MOHY_REJECT_CONTINUATION_NOT_CONFIRMED: return "ContinuationNotConfirmed";
      case MOHY_REJECT_PRE_ENTRY_INVALIDATED: return "PreEntryInvalidated";
      case MOHY_REJECT_SPREAD_FILTER_FAILED: return "SpreadFilterFailed";
      case MOHY_REJECT_MIN_RR_NOT_SATISFIED: return "MinRRNotSatisfied";
      case MOHY_REJECT_STOP_DISTANCE_INVALID: return "StopDistanceInvalid";
      case MOHY_REJECT_LOT_NORMALIZATION_FAILED: return "LotNormalizationFailed";
      case MOHY_REJECT_EXPOSURE_LIMIT_EXCEEDED: return "ExposureLimitExceeded";
      case MOHY_REJECT_PENDING_PLACEMENT_REJECTED: return "PendingPlacementRejected";
      case MOHY_REJECT_EXECUTION_FAILED: return "ExecutionFailed";
      case MOHY_REJECT_BROKER_CONSTRAINT: return "BrokerConstraint";
      case MOHY_REJECT_INVALID_PLAN: return "InvalidPlan";
      default: break;
     }
   return "Unknown";
  }

string SLModeToText(const MohySLMode mode)
  {
   if(mode == MOHY_SL_INNER_STRUCTURE)
      return "InnerStructure";
   if(mode == MOHY_SL_AUTO)
      return "Auto";
   return "OuterCorrectionExtreme";
  }

string TPModeToText(const MohyTPMode mode)
  {
   if(mode == MOHY_TP_RISK_REWARD)
      return "RiskReward";
   return "FibNegExtension";
  }

bool ResolveTimeframePair(const int htf,
                          const int ltf,
                          MohyTimeframePair &out_pair)
  {
   if(htf == PERIOD_H1 && ltf == PERIOD_M15)
     {
      out_pair = MOHY_TF_PAIR_H1_M15;
      return true;
     }
   if(htf == PERIOD_H2 && ltf == PERIOD_M30)
     {
      out_pair = MOHY_TF_PAIR_H2_M30;
      return true;
     }
   if(htf == PERIOD_H4 && ltf == PERIOD_H1)
     {
      out_pair = MOHY_TF_PAIR_H4_H1;
      return true;
     }
   if(htf == PERIOD_D1 && ltf == PERIOD_H4)
     {
      out_pair = MOHY_TF_PAIR_D1_H4;
      return true;
     }
   return false;
  }

void SortVLinesByTime(MohyDebugVLine &io_lines[])
  {
   const int count = ArraySize(io_lines);
   for(int i = 0; i < count - 1; ++i)
     {
      int best = i;
      for(int j = i + 1; j < count; ++j)
        {
         if(io_lines[j].time < io_lines[best].time)
            best = j;
        }
      if(best == i)
         continue;
      const MohyDebugVLine temp = io_lines[i];
      io_lines[i] = io_lines[best];
      io_lines[best] = temp;
     }
  }

int CollectVerticalLines(MohyDebugVLine &out_lines[])
  {
   ArrayResize(out_lines, 0);
   const int total = ObjectsTotal(0, -1, -1);
   for(int i = 0; i < total; ++i)
     {
      const string name = ObjectName(0, i, -1, -1);
      if(name == "")
         continue;
      if((ENUM_OBJECT)ObjectGetInteger(0, name, OBJPROP_TYPE) != OBJ_VLINE)
         continue;

      MohyDebugVLine line;
      line.name = name;
      line.time = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
      line.selected = (ObjectGetInteger(0, name, OBJPROP_SELECTED) != 0);
      line.line_color = ObjectGetInteger(0, name, OBJPROP_COLOR);
      line.style = (int)ObjectGetInteger(0, name, OBJPROP_STYLE);
      line.width = (int)ObjectGetInteger(0, name, OBJPROP_WIDTH);

      const int size = ArraySize(out_lines);
      ArrayResize(out_lines, size + 1);
      out_lines[size] = line;
     }

   SortVLinesByTime(out_lines);
   return ArraySize(out_lines);
  }

int FindVLineIndexByName(const MohyDebugVLine &lines[],
                         const string name)
  {
   const string target = TrimText(name);
   if(target == "")
      return -1;

   const int count = ArraySize(lines);
   for(int i = 0; i < count; ++i)
     {
      if(lines[i].name == target)
         return i;
     }
   return -1;
  }

void NormalizeWindow(datetime &io_start,
                     datetime &io_end,
                     string &io_start_name,
                     string &io_end_name)
  {
   if(io_start <= io_end)
      return;
   const datetime tmp_time = io_start;
   io_start = io_end;
   io_end = tmp_time;
   const string tmp_name = io_start_name;
   io_start_name = io_end_name;
   io_end_name = tmp_name;
  }

bool ResolveWindow(const MohyDebugVLine &lines[],
                   datetime &out_start,
                   datetime &out_end,
                   string &out_start_name,
                   string &out_end_name,
                   string &out_source,
                   string &out_error)
  {
   out_start = 0;
   out_end = 0;
   out_start_name = "";
   out_end_name = "";
   out_source = "";
   out_error = "";

   const int line_count = ArraySize(lines);

   const string start_name = TrimText(StartLineName);
   const string end_name = TrimText(EndLineName);
   if(start_name != "" && end_name != "")
     {
      const int i_start = FindVLineIndexByName(lines, start_name);
      const int i_end = FindVLineIndexByName(lines, end_name);
      if(i_start >= 0 && i_end >= 0)
        {
         out_start = lines[i_start].time;
         out_end = lines[i_end].time;
         out_start_name = lines[i_start].name;
         out_end_name = lines[i_end].name;
         out_source = "LineNames";
         NormalizeWindow(out_start, out_end, out_start_name, out_end_name);
         return true;
        }
     }

   if(PreferSelectedVerticalLines && line_count >= 2)
     {
      bool has_selected = false;
      datetime selected_min_time = 0;
      datetime selected_max_time = 0;
      string selected_min_name = "";
      string selected_max_name = "";
      for(int i = 0; i < line_count; ++i)
        {
         if(!lines[i].selected)
            continue;
         if(!has_selected || lines[i].time < selected_min_time)
           {
            selected_min_time = lines[i].time;
            selected_min_name = lines[i].name;
           }
         if(!has_selected || lines[i].time > selected_max_time)
           {
            selected_max_time = lines[i].time;
            selected_max_name = lines[i].name;
           }
         has_selected = true;
        }

      if(has_selected && selected_min_time > 0 && selected_max_time > 0 && selected_min_time != selected_max_time)
        {
         out_start = selected_min_time;
         out_end = selected_max_time;
         out_start_name = selected_min_name;
         out_end_name = selected_max_name;
         out_source = "SelectedVerticalLines";
         NormalizeWindow(out_start, out_end, out_start_name, out_end_name);
         return true;
        }
     }

   if(line_count == 2)
     {
      out_start = lines[0].time;
      out_end = lines[1].time;
      out_start_name = lines[0].name;
      out_end_name = lines[1].name;
      out_source = "ExactlyTwoVerticalLines";
      NormalizeWindow(out_start, out_end, out_start_name, out_end_name);
      return true;
     }

   if(ManualWindowStart > 0 && ManualWindowEnd > 0 && ManualWindowStart != ManualWindowEnd)
     {
      out_start = ManualWindowStart;
      out_end = ManualWindowEnd;
      out_start_name = "ManualWindowStart";
      out_end_name = "ManualWindowEnd";
      out_source = "ManualTimes";
      NormalizeWindow(out_start, out_end, out_start_name, out_end_name);
      return true;
     }

   if(AllowAnyLinesFallback && line_count >= 2)
     {
      out_start = lines[0].time;
      out_end = lines[line_count - 1].time;
      out_start_name = lines[0].name;
      out_end_name = lines[line_count - 1].name;
      out_source = "AllVerticalLinesMinMax";
      NormalizeWindow(out_start, out_end, out_start_name, out_end_name);
      return true;
     }

   out_error = "Window resolution failed. Provide two selected vertical lines, explicit line names, or manual times.";
   return false;
  }

bool ConfigureFromInputs(StrategyConfig &out_cfg,
                         string &out_error)
  {
   out_error = "";
   MohySetDefaultStrategyConfig(out_cfg);
   out_cfg.symbol = Symbol();

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
      out_error = StringFormat("Unsupported timeframe pair HTF=%s LTF=%s.",
                               MohyTimeframeToString(htf),
                               MohyTimeframeToString(ltf));
      return false;
     }

   out_cfg.timeframe_pair = pair;
   out_cfg.context_timeframe = htf;
   out_cfg.execution_timeframe = ltf;

   out_cfg.detection.equal_swing_classification_mode = EqualSwingClassificationMode;
   out_cfg.detection.swing_left_bars = MathMax(1, SwingLeftBars);
   out_cfg.detection.swing_right_bars = MathMax(1, SwingRightBars);
   out_cfg.detection.continuation_swing_ref_index = MathMax(1, ContinuationSwingRefIndex);
   out_cfg.detection.break_buffer_points = MathMax(0.0, BreakBufferPoints);

   out_cfg.detection.enable_potential_impulse = PotentialImpulseEnabled;
   out_cfg.detection.potential_impulse_min_swing_breakout_closes = MathMax(0, PotentialImpulseMinSwingBreakoutCloses);
   out_cfg.detection.potential_impulse_require_leg_breakout = PotentialImpulseRequireLegBreakout;
   out_cfg.detection.potential_impulse_min_leg_breakout_closes = MathMax(1, PotentialImpulseMinLegBreakoutCloses);
   out_cfg.detection.potential_impulse_require_directional_candles = PotentialImpulseRequireDirectionalCandles;
   out_cfg.detection.potential_impulse_validate_endpoint_candles = PotentialImpulseValidateEndpointCandles;
   out_cfg.detection.potential_impulse_allow_opposite_begin_candles = MathMax(0, PotentialImpulseAllowOppositeBeginCandles);
   out_cfg.detection.potential_impulse_allow_opposite_end_candles = MathMax(0, PotentialImpulseAllowOppositeEndCandles);
   out_cfg.detection.potential_impulse_max_opposite_middle_candles = MathMax(0, PotentialImpulseMaxOppositeMiddleCandles);
   out_cfg.detection.potential_impulse_allow_any_opposite_before_leg_breakout = PotentialImpulseAllowAnyOppositeBeforeLegBreakout;
   out_cfg.detection.potential_impulse_doji_epsilon_points = MathMax(1e-10, PotentialImpulseDojiEpsilonPoints);

   out_cfg.detection.enable_potential_correction = PotentialCorrectionEnabled;
   out_cfg.detection.potential_correction_min_opposite_ici_count = MathMax(0, PotentialCorrectionMinOppositeICICount);
   out_cfg.detection.potential_correction_min_fib_level = PotentialCorrectionMinFibLevel;
   out_cfg.detection.potential_correction_min_fib_trigger_mode = PotentialCorrectionMinFibTriggerMode;
   out_cfg.detection.potential_correction_max_fib_level = PotentialCorrectionMaxFibLevel;
   out_cfg.detection.potential_correction_max_fib_trigger_mode = PotentialCorrectionMaxFibTriggerMode;
   out_cfg.detection.potential_correction_extreme_touch_epsilon_points = MathMax(0.0, PotentialCorrectionExtremeTouchEpsilonPoints);
   out_cfg.detection.potential_correction_extreme_touch_min_count = MathMax(1, PotentialCorrectionExtremeTouchMinCount);
   out_cfg.detection.potential_correction_supersede_direction_mode = PotentialCorrectionSupersedeDirectionMode;
   out_cfg.detection.potential_correction_supersede_scope = PotentialCorrectionSupersedeScope;
   out_cfg.detection.continuation_planning_start_mode = ContinuationPlanningStartMode;

   if(!MohyIsPotentialCorrectionFibRangeValid(out_cfg.detection.potential_correction_min_fib_level,
                                              out_cfg.detection.potential_correction_max_fib_level))
     {
      out_error = "Invalid PotentialCorrection fib range: max fib must be strictly greater than min fib.";
      return false;
     }

   return true;
  }

string BuildStrategyConfigSignature(const StrategyConfig &cfg)
  {
   return StringFormat("pair=%d|ctx=%d|exe=%d|equal=%d|left=%d|right=%d|contRef=%d|contStart=%d|breakBuf=%s|piEnable=%s|piMinSwing=%d|piReqLeg=%s|piMinLeg=%d|piReqDir=%s|piValEndpoints=%s|piAllowBegin=%d|piAllowEnd=%d|piMaxMiddle=%d|piAllowAnyBeforeLegBreak=%s|piDoji=%s|pcEnable=%s|pcMinIci=%d|pcMinFib=%d|pcMinFibTrig=%d|pcMaxFib=%d|pcMaxFibTrig=%d|pcExtremeEps=%s|pcExtremeMin=%d|pcSupDir=%d|pcSupScope=%d|entryMinRR=%s|entryRRTol=%s|entrySpreadFilter=%s|entryMaxSpread=%s|entryExecMode=%d|riskPct=%s|riskBase=%d|maxConcurrentRiskPct=%s|exposureBase=%d|postBE=%d|slMode=%d|outerSLBuf=%s|innerSLBuf=%s|innerStopIdx=%d|tpMode=%d|fibTarget=%s|targetRR=%s",
                         cfg.timeframe_pair,
                         cfg.context_timeframe,
                         cfg.execution_timeframe,
                       cfg.detection.equal_swing_classification_mode,
                       cfg.detection.swing_left_bars,
                       cfg.detection.swing_right_bars,
                       cfg.detection.continuation_swing_ref_index,
                       cfg.detection.continuation_planning_start_mode,
                       DoubleToString(cfg.detection.break_buffer_points, 10),
                       BoolText(cfg.detection.enable_potential_impulse),
                       cfg.detection.potential_impulse_min_swing_breakout_closes,
                       BoolText(cfg.detection.potential_impulse_require_leg_breakout),
                       cfg.detection.potential_impulse_min_leg_breakout_closes,
                       BoolText(cfg.detection.potential_impulse_require_directional_candles),
                       BoolText(cfg.detection.potential_impulse_validate_endpoint_candles),
                       cfg.detection.potential_impulse_allow_opposite_begin_candles,
                       cfg.detection.potential_impulse_allow_opposite_end_candles,
                       cfg.detection.potential_impulse_max_opposite_middle_candles,
                       BoolText(cfg.detection.potential_impulse_allow_any_opposite_before_leg_breakout),
                       DoubleToString(cfg.detection.potential_impulse_doji_epsilon_points, 10),
                       BoolText(cfg.detection.enable_potential_correction),
                       cfg.detection.potential_correction_min_opposite_ici_count,
                       cfg.detection.potential_correction_min_fib_level,
                       cfg.detection.potential_correction_min_fib_trigger_mode,
                       cfg.detection.potential_correction_max_fib_level,
                         cfg.detection.potential_correction_max_fib_trigger_mode,
                         DoubleToString(cfg.detection.potential_correction_extreme_touch_epsilon_points, 10),
                         cfg.detection.potential_correction_extreme_touch_min_count,
                         cfg.detection.potential_correction_supersede_direction_mode,
                         cfg.detection.potential_correction_supersede_scope,
                         DoubleToString(cfg.entry.min_rr, 10),
                         DoubleToString(cfg.entry.rr_tolerance, 10),
                         BoolText(cfg.entry.enable_spread_filter),
                         DoubleToString(cfg.entry.max_spread_points, 10),
                         cfg.entry.execution_mode,
                         DoubleToString(cfg.risk.risk_percent, 10),
                         cfg.risk.risk_base,
                         DoubleToString(cfg.risk.max_concurrent_risk_percent, 10),
                         cfg.risk.exposure_base,
                         cfg.management.post_be_profile,
                         cfg.sl_mode,
                         DoubleToString(cfg.outer_sl_buffer_points, 10),
                         DoubleToString(cfg.inner_sl_buffer_points, 10),
                         cfg.inner_stop_swing_index,
                         cfg.tp_mode,
                         DoubleToString(cfg.fib_target_level, 10),
                         DoubleToString(cfg.target_rr, 10));
  }

void WriteCsvHeader(const int handle)
  {
   FileWrite(handle,
             "run_id",
             "generated_at",
             "row_type",
             "scope",
             "entity_id",
             "in_window",
             "time_from",
             "time_to",
             "payload");
  }

void WriteCsvRow(const int handle,
                 const string run_id,
                 const string generated_at,
                 const string row_type,
                 const string scope,
                 const string entity_id,
                 const bool in_window,
                 const datetime time_from,
                 const datetime time_to,
                 const string payload)
  {
   FileWrite(handle,
             run_id,
             generated_at,
             row_type,
             scope,
             entity_id,
             BoolText(in_window),
             TimeText(time_from),
             TimeText(time_to),
             payload);
  }

void WriteErrorRow(const int handle,
                   const string run_id,
                   const string generated_at,
                   const string scope,
                   const string code,
                   const string message)
  {
   string payload = "";
   PayloadAdd(payload, "code", code);
   PayloadAdd(payload, "message", message);
   WriteCsvRow(handle,
               run_id,
               generated_at,
               "error",
               scope,
               code,
               false,
               0,
               0,
               payload);
  }

bool ResolveSnapshotShiftRange(const string symbol,
                               const int timeframe,
                               const int swing_right_bars,
                               const datetime window_start,
                               const datetime window_end,
                               int &out_from_shift,
                               int &out_max_shift,
                               int &out_window_start_shift,
                               int &out_window_end_shift,
                               string &out_error)
  {
   out_error = "";
   out_from_shift = -1;
   out_max_shift = -1;
   out_window_start_shift = -1;
   out_window_end_shift = -1;

   const int bars = MohyIBars(symbol, timeframe);
   if(bars <= swing_right_bars + 2)
     {
      out_error = StringFormat("Not enough bars: bars=%d, swingRight=%d", bars, swing_right_bars);
      return false;
     }

   out_window_start_shift = MohyIBarShift(symbol, timeframe, window_start, false);
   out_window_end_shift = MohyIBarShift(symbol, timeframe, window_end, false);
   const int older_window_shift = MathMax(out_window_start_shift, out_window_end_shift);
   const int min_required_oldest = MathMax(MathMax(20, LookbackBars),
                                           older_window_shift + MathMax(0, WindowOlderContextBars));

   out_from_shift = swing_right_bars + 1;
   out_max_shift = MathMin(bars - swing_right_bars - 2,
                           min_required_oldest);
   if(out_max_shift < out_from_shift)
     {
      out_error = StringFormat("Invalid shift range from=%d max=%d bars=%d", out_from_shift, out_max_shift, bars);
      return false;
     }

   return true;
  }

void ExportBars(const int handle,
                const string run_id,
                const string generated_at,
                const string scope,
                const string symbol,
                const int timeframe,
                const int from_shift,
                const int max_shift,
                const int window_start_shift,
                const int window_end_shift,
                const datetime window_start,
                const datetime window_end)
  {
   int older_shift = MathMax(window_start_shift, window_end_shift);
   int newer_shift = MathMin(window_start_shift, window_end_shift);
   if(older_shift < 0 || newer_shift < 0)
     {
      older_shift = max_shift;
      newer_shift = from_shift;
     }

   const int bar_max = MathMin(max_shift, older_shift + MathMax(0, BarContextBeforeWindow));
   const int bar_min = MathMax(from_shift, MathMax(0, newer_shift - MathMax(0, BarContextAfterWindow)));
   if(bar_max < bar_min)
      return;

   const int tf_seconds = MathMax(1, MohyPeriodSeconds(timeframe));
   for(int shift = bar_max; shift >= bar_min; --shift)
     {
      const datetime bar_time = MohyITime(symbol, timeframe, shift);
      if(bar_time <= 0)
         continue;
      const datetime bar_end = bar_time + tf_seconds - 1;
      const bool in_window = IntersectsWindow(bar_time, bar_end, window_start, window_end);
      if(!ShouldWriteFact(in_window))
         continue;

      string payload = "";
      PayloadAddInt(payload, "shift", shift);
      PayloadAddTime(payload, "time", bar_time);
      PayloadAddDouble(payload, "open", MohyIOpen(symbol, timeframe, shift), _Digits);
      PayloadAddDouble(payload, "high", MohyIHigh(symbol, timeframe, shift), _Digits);
      PayloadAddDouble(payload, "low", MohyILow(symbol, timeframe, shift), _Digits);
      PayloadAddDouble(payload, "close", MohyIClose(symbol, timeframe, shift), _Digits);
      PayloadAddLong(payload, "tick_volume", iVolume(symbol, (ENUM_TIMEFRAMES)timeframe, shift));
      PayloadAddLong(payload, "real_volume", iRealVolume(symbol, (ENUM_TIMEFRAMES)timeframe, shift));
      PayloadAddInt(payload, "spread", iSpread(symbol, (ENUM_TIMEFRAMES)timeframe, shift));
      WriteCsvRow(handle,
                  run_id,
                  generated_at,
                  "bar",
                  scope,
                  StringFormat("BAR_%d", shift),
                  in_window,
                  bar_time,
                  bar_end,
                  payload);
     }
  }

void ExportKernelSnapshot(const int handle,
                          const string run_id,
                          const string generated_at,
                          const string symbol,
                          const StrategyConfig &cfg,
                          const int timeframe,
                          const datetime window_start,
                          const datetime window_end)
  {
   const string scope = StringFormat("Kernel/%s", MohyTimeframeToString(timeframe));
   int from_shift = -1;
   int max_shift = -1;
   int window_start_shift = -1;
   int window_end_shift = -1;
   string range_error = "";
   if(!ResolveSnapshotShiftRange(symbol,
                                 timeframe,
                                 cfg.detection.swing_right_bars,
                                 window_start,
                                 window_end,
                                 from_shift,
                                 max_shift,
                                 window_start_shift,
                                 window_end_shift,
                                 range_error))
     {
      WriteErrorRow(handle, run_id, generated_at, scope, "RANGE", range_error);
      return;
     }

   CMohyPriceActionKernel kernel;
   kernel.Configure(cfg,
                    timeframe,
                    cfg.context_timeframe,
                    cfg.execution_timeframe);

   CMohyPriceActionSnapshot snapshot;
   if(!kernel.Build(symbol,
                    from_shift,
                    max_shift,
                    snapshot,
                    ResolveIncludeProvisionalLatest()))
     {
      WriteErrorRow(handle,
                    run_id,
                    generated_at,
                    scope,
                    "BUILD",
                    StringFormat("kernel.Build failed from=%d max=%d", from_shift, max_shift));
      return;
     }

   string summary = "";
   PayloadAddInt(summary, "from_shift", from_shift);
   PayloadAddInt(summary, "max_shift", max_shift);
   PayloadAddInt(summary, "window_start_shift", window_start_shift);
   PayloadAddInt(summary, "window_end_shift", window_end_shift);
   PayloadAdd(summary, "snapshot_timeframe", MohyTimeframeToString(snapshot.timeframe));
   PayloadAdd(summary, "context_timeframe", MohyTimeframeToString(snapshot.context_timeframe));
   PayloadAdd(summary, "execution_timeframe", MohyTimeframeToString(snapshot.execution_timeframe));
   PayloadAddBool(summary, "source_is_context_timeframe", snapshot.source_is_context_timeframe);
   PayloadAddBool(summary, "source_is_execution_timeframe", snapshot.source_is_execution_timeframe);
   PayloadAddBool(summary, "publishes_execution_stage_facts", snapshot.publishes_execution_stage_facts);
   PayloadAddInt(summary, "elements", ArraySize(snapshot.elements));
   PayloadAddInt(summary, "legs", ArraySize(snapshot.legs));
   PayloadAddInt(summary, "swings3", ArraySize(snapshot.swings3));
   PayloadAddInt(summary, "potential_impulses", ArraySize(snapshot.potential_impulses));
   PayloadAddInt(summary, "potential_corrections", ArraySize(snapshot.potential_corrections));
   PayloadAddInt(summary, "potential_continuation_signals", ArraySize(snapshot.potential_continuation_signals));
   PayloadAddInt(summary, "trade_setup_plans", ArraySize(snapshot.trade_setup_plans));
   PayloadAddInt(summary, "historical_trade_setups", ArraySize(snapshot.historical_trade_setups));
   WriteCsvRow(handle,
               run_id,
               generated_at,
               "snapshot_summary",
               scope,
               "summary",
               true,
               window_start,
               window_end,
               summary);

   ExportBars(handle,
              run_id,
              generated_at,
              scope,
              symbol,
              timeframe,
              from_shift,
              max_shift,
              window_start_shift,
              window_end_shift,
              window_start,
              window_end);

   const int element_count = ArraySize(snapshot.elements);
   for(int i = 0; i < element_count; ++i)
     {
      const MohyElementFact fact = snapshot.elements[i];
      const bool in_window = IsTimeInWindow(fact.time, window_start, window_end);
      if(!ShouldWriteFact(in_window))
         continue;

      string payload = "";
      PayloadAddInt(payload, "index", fact.index);
      PayloadAddInt(payload, "shift", fact.shift);
      PayloadAddTime(payload, "time", fact.time);
      PayloadAdd(payload, "type", MohyElementTypeToString(fact.type));
      PayloadAddBool(payload, "confirmed", fact.confirmed);
      PayloadAdd(payload, "candle_momentum", DirectionToText(fact.candle_momentum));
      PayloadAddDouble(payload, "open", fact.open_price, _Digits);
      PayloadAddDouble(payload, "high", fact.high_price, _Digits);
      PayloadAddDouble(payload, "low", fact.low_price, _Digits);
      PayloadAddDouble(payload, "close", fact.close_price, _Digits);
      PayloadAddDouble(payload, "pivot", fact.pivot_price, _Digits);
      PayloadAddBool(payload, "dual_pivot", fact.dual_pivot);
      PayloadAddInt(payload, "dual_order", fact.dual_order);
      WriteCsvRow(handle,
                  run_id,
                  generated_at,
                  "element",
                  scope,
                  StringFormat("E_%d", fact.index),
                  in_window,
                  fact.time,
                  fact.time,
                  payload);
     }

   const int leg_count = ArraySize(snapshot.legs);
   for(int i = 0; i < leg_count; ++i)
     {
      const MohyLegFact fact = snapshot.legs[i];
      const bool in_window = IntersectsWindow(fact.begin_time, fact.end_time, window_start, window_end);
      if(!ShouldWriteFact(in_window))
         continue;

      string payload = "";
      PayloadAddInt(payload, "index", fact.index);
      PayloadAddInt(payload, "begin_element_index", fact.begin_element_index);
      PayloadAddInt(payload, "end_element_index", fact.end_element_index);
      PayloadAdd(payload, "type", MohyLegTypeToString(fact.type));
      PayloadAdd(payload, "direction", DirectionToText(fact.direction));
      PayloadAddBool(payload, "confirmed", fact.confirmed);
      PayloadAddInt(payload, "begin_shift", fact.begin_shift);
      PayloadAddTime(payload, "begin_time", fact.begin_time);
      PayloadAddDouble(payload, "begin_price", fact.begin_price, _Digits);
      PayloadAddInt(payload, "end_shift", fact.end_shift);
      PayloadAddTime(payload, "end_time", fact.end_time);
      PayloadAddDouble(payload, "end_price", fact.end_price, _Digits);
      PayloadAddInt(payload, "candle_count", fact.candle_count);
      WriteCsvRow(handle,
                  run_id,
                  generated_at,
                  "leg",
                  scope,
                  StringFormat("L_%d", fact.index),
                  in_window,
                  fact.begin_time,
                  fact.end_time,
                  payload);
     }

   const int swing_count = ArraySize(snapshot.swings3);
   for(int i = 0; i < swing_count; ++i)
     {
      const MohySwing3Fact fact = snapshot.swings3[i];
      datetime swing_begin_time = 0;
      datetime swing_end_time = 0;
      if(fact.leg1_index >= 0 && fact.leg1_index < leg_count)
         swing_begin_time = snapshot.legs[fact.leg1_index].begin_time;
      if(fact.leg3_index >= 0 && fact.leg3_index < leg_count)
         swing_end_time = snapshot.legs[fact.leg3_index].end_time;

      const bool in_window = IntersectsWindow(swing_begin_time, swing_end_time, window_start, window_end);
      if(!ShouldWriteFact(in_window))
         continue;

      string payload = "";
      PayloadAddInt(payload, "index", fact.index);
      PayloadAddInt(payload, "leg1_index", fact.leg1_index);
      PayloadAddInt(payload, "leg2_index", fact.leg2_index);
      PayloadAddInt(payload, "leg3_index", fact.leg3_index);
      PayloadAdd(payload, "direction", DirectionToText(fact.direction));
      PayloadAddBool(payload, "confirmed", fact.confirmed);
      PayloadAdd(payload, "pattern_type", MohySwing3PatternTypeToString(fact.pattern_type));
      PayloadAdd(payload, "break_state", MohyBreakStateToString(fact.break_state));
      PayloadAdd(payload, "breakout_certainty", MohyBreakoutCertaintyToString(fact.breakout_certainty));
      PayloadAdd(payload, "correction_state", MohyCorrectionStateToString(fact.correction_state));
      PayloadAddInt(payload, "breakout_close_count", fact.breakout_close_count);
      PayloadAddInt(payload, "lower_low_element_index", fact.lower_low_element_index);
      PayloadAddInt(payload, "higher_low_element_index", fact.higher_low_element_index);
      PayloadAddInt(payload, "lower_high_element_index", fact.lower_high_element_index);
      PayloadAddInt(payload, "higher_high_element_index", fact.higher_high_element_index);
      WriteCsvRow(handle,
                  run_id,
                  generated_at,
                  "swing3",
                  scope,
                  StringFormat("S3_%d", fact.index),
                  in_window,
                  swing_begin_time,
                  swing_end_time,
                  payload);
     }

    const int impulse_count = ArraySize(snapshot.potential_impulses);
   for(int i = 0; i < impulse_count; ++i)
     {
      const MohyPotentialImpulseFact fact = snapshot.potential_impulses[i];
      const bool in_window = IntersectsWindow(fact.begin_time, fact.end_time, window_start, window_end);
      if(!ShouldWriteFact(in_window))
         continue;

      string payload = "";
      PayloadAddInt(payload, "index", fact.index);
      PayloadAddBool(payload, "valid", fact.valid);
      PayloadAddInt(payload, "swing3_index", fact.swing3_index);
      PayloadAddInt(payload, "leg_index", fact.leg_index);
      PayloadAdd(payload, "direction", DirectionToText(fact.direction));
      PayloadAddBool(payload, "confirmed", fact.confirmed);
      PayloadAdd(payload, "pattern_type", MohySwing3PatternTypeToString(fact.pattern_type));
      PayloadAdd(payload, "break_state", MohyBreakStateToString(fact.break_state));
      PayloadAdd(payload, "swing_breakout_certainty", MohyBreakoutCertaintyToString(fact.swing_breakout_certainty));
      PayloadAddInt(payload, "swing_breakout_close_count", fact.swing_breakout_close_count);
      PayloadAddDouble(payload, "leg_break_reference_price", fact.leg_break_reference_price, _Digits);
      PayloadAddInt(payload, "leg_breakout_close_count", fact.leg_breakout_close_count);
      PayloadAddInt(payload, "first_leg_breakout_shift", fact.first_leg_breakout_shift);
      PayloadAddTime(payload, "first_leg_breakout_time", fact.first_leg_breakout_time);
      PayloadAddInt(payload, "begin_shift", fact.begin_shift);
      PayloadAddTime(payload, "begin_time", fact.begin_time);
      PayloadAddDouble(payload, "begin_price", fact.begin_price, _Digits);
      PayloadAddInt(payload, "end_shift", fact.end_shift);
      PayloadAddTime(payload, "end_time", fact.end_time);
      PayloadAddDouble(payload, "end_price", fact.end_price, _Digits);
      PayloadAdd(payload, "diagnostics", fact.diagnostics);
      WriteCsvRow(handle,
                  run_id,
                  generated_at,
                  "potential_impulse",
                  scope,
                  StringFormat("PI_%d", fact.index),
                  in_window,
                  fact.begin_time,
                  fact.end_time,
                  payload);
     }

   const int correction_count = ArraySize(snapshot.potential_corrections);
   for(int i = 0; i < correction_count; ++i)
     {
      const MohyPotentialCorrectionFact fact = snapshot.potential_corrections[i];
      const datetime corr_end_time = (fact.timeline_full.timeline_end_time > 0)
                                     ? fact.timeline_full.timeline_end_time
                                     : fact.end_time;
      const bool in_window = IntersectsWindow(fact.begin_time, corr_end_time, window_start, window_end) ||
                             IsTimeInWindow(fact.confirmed_time, window_start, window_end) ||
                             IsTimeInWindow(fact.invalidated_time, window_start, window_end);
      if(!ShouldWriteFact(in_window))
         continue;

      string payload = "";
      PayloadAddInt(payload, "index", fact.index);
      PayloadAddBool(payload, "valid", fact.valid);
      PayloadAddInt(payload, "linked_potential_impulse_index", fact.linked_potential_impulse_index);
      PayloadAddInt(payload, "linked_potential_impulse_swing3_index", fact.linked_potential_impulse_swing3_index);
      PayloadAdd(payload, "impulse_direction", DirectionToText(fact.impulse_direction));
      PayloadAddBool(payload, "confirmed", fact.confirmed);
      PayloadAdd(payload, "state", MohyPotentialCorrectionStateToString(fact.state));
      PayloadAdd(payload, "termination_reason", MohyPotentialCorrectionTerminationReasonToString(fact.termination_reason));
      PayloadAddInt(payload, "begin_shift", fact.begin_shift);
      PayloadAddTime(payload, "begin_time", fact.begin_time);
      PayloadAddDouble(payload, "begin_price", fact.begin_price, _Digits);
      PayloadAddInt(payload, "reference_begin_shift", fact.reference_begin_shift);
      PayloadAddTime(payload, "reference_begin_time", fact.reference_begin_time);
      PayloadAddDouble(payload, "reference_begin_price", fact.reference_begin_price, _Digits);
      PayloadAddInt(payload, "visual_begin_shift", fact.visual_begin_shift);
      PayloadAddTime(payload, "visual_begin_time", fact.visual_begin_time);
      PayloadAddDouble(payload, "visual_begin_price", fact.visual_begin_price, _Digits);
      PayloadAddInt(payload, "end_shift", fact.end_shift);
      PayloadAddTime(payload, "end_time", fact.end_time);
      PayloadAddDouble(payload, "end_price", fact.end_price, _Digits);
      PayloadAddDouble(payload, "impulse_origin_price", fact.impulse_origin_price, _Digits);
      PayloadAddDouble(payload, "impulse_extreme_price", fact.impulse_extreme_price, _Digits);
      PayloadAddDouble(payload, "retrace_depth", fact.retrace_depth, 10);
      PayloadAddDouble(payload, "min_fib_level", fact.min_fib_level, 6);
      PayloadAddDouble(payload, "max_fib_level", fact.max_fib_level, 6);
      PayloadAddInt(payload, "min_fib_trigger_mode", fact.min_fib_trigger_mode);
      PayloadAddInt(payload, "max_fib_trigger_mode", fact.max_fib_trigger_mode);
      PayloadAddInt(payload, "opposite_ici_count", fact.opposite_ici_count);
      PayloadAddInt(payload, "min_opposite_ici_count", fact.min_opposite_ici_count);
      PayloadAddBool(payload, "min_fib_gate_pass", fact.min_fib_gate_pass);
      PayloadAddBool(payload, "opposite_ici_gate_pass", fact.opposite_ici_gate_pass);
      PayloadAddInt(payload, "confirmed_shift", fact.confirmed_shift);
      PayloadAddTime(payload, "confirmed_time", fact.confirmed_time);
      PayloadAddInt(payload, "invalidated_shift", fact.invalidated_shift);
      PayloadAddTime(payload, "invalidated_time", fact.invalidated_time);
      PayloadAddInt(payload, "recency_rank", fact.recency_rank);
      PayloadAddBool(payload, "is_active", fact.is_active);
      PayloadAddBool(payload, "is_selected", fact.is_selected);
      PayloadAdd(payload, "diagnostics", fact.diagnostics);
      WriteCsvRow(handle,
                  run_id,
                  generated_at,
                  "potential_correction",
                  scope,
                  StringFormat("PC_%d", fact.index),
                  in_window,
                  fact.begin_time,
                  corr_end_time,
                  payload);

      string timeline_full_payload = "";
      PayloadAddInt(timeline_full_payload, "index", fact.index);
      PayloadAddInt(timeline_full_payload, "timeline_end_shift", fact.timeline_full.timeline_end_shift);
      PayloadAddTime(timeline_full_payload, "timeline_end_time", fact.timeline_full.timeline_end_time);
      PayloadAddInt(timeline_full_payload, "extreme_shift", fact.timeline_full.extreme_shift);
      PayloadAddTime(timeline_full_payload, "extreme_time", fact.timeline_full.extreme_time);
      PayloadAddDouble(timeline_full_payload, "extreme_price", fact.timeline_full.extreme_price, _Digits);
      PayloadAddInt(timeline_full_payload, "forming_end_shift", fact.timeline_full.forming_end_shift);
      PayloadAddTime(timeline_full_payload, "forming_end_time", fact.timeline_full.forming_end_time);
      PayloadAddDouble(timeline_full_payload, "forming_end_price", fact.timeline_full.forming_end_price, _Digits);
      PayloadAddBool(timeline_full_payload, "has_confirmed_segment", fact.timeline_full.has_confirmed_segment);
      PayloadAddInt(timeline_full_payload, "confirmed_begin_shift", fact.timeline_full.confirmed_begin_shift);
      PayloadAddTime(timeline_full_payload, "confirmed_begin_time", fact.timeline_full.confirmed_begin_time);
      PayloadAddDouble(timeline_full_payload, "confirmed_begin_price", fact.timeline_full.confirmed_begin_price, _Digits);
      PayloadAddInt(timeline_full_payload, "confirmed_end_shift", fact.timeline_full.confirmed_end_shift);
      PayloadAddTime(timeline_full_payload, "confirmed_end_time", fact.timeline_full.confirmed_end_time);
      PayloadAddDouble(timeline_full_payload, "confirmed_end_price", fact.timeline_full.confirmed_end_price, _Digits);
      PayloadAddBool(timeline_full_payload, "has_invalidated_segment", fact.timeline_full.has_invalidated_segment);
      PayloadAddInt(timeline_full_payload, "invalid_begin_shift", fact.timeline_full.invalid_begin_shift);
      PayloadAddTime(timeline_full_payload, "invalid_begin_time", fact.timeline_full.invalid_begin_time);
      PayloadAddDouble(timeline_full_payload, "invalid_begin_price", fact.timeline_full.invalid_begin_price, _Digits);
      PayloadAddInt(timeline_full_payload, "invalid_end_shift", fact.timeline_full.invalid_end_shift);
      PayloadAddTime(timeline_full_payload, "invalid_end_time", fact.timeline_full.invalid_end_time);
      PayloadAddDouble(timeline_full_payload, "invalid_end_price", fact.timeline_full.invalid_end_price, _Digits);
      WriteCsvRow(handle,
                  run_id,
                  generated_at,
                  "potential_correction_timeline_full",
                  scope,
                  StringFormat("PC_%d_FULL", fact.index),
                  in_window,
                  fact.begin_time,
                  corr_end_time,
                  timeline_full_payload);

      string timeline_trimmed_payload = "";
      PayloadAddInt(timeline_trimmed_payload, "index", fact.index);
      PayloadAddInt(timeline_trimmed_payload, "timeline_end_shift", fact.timeline_trimmed.timeline_end_shift);
      PayloadAddTime(timeline_trimmed_payload, "timeline_end_time", fact.timeline_trimmed.timeline_end_time);
      PayloadAddInt(timeline_trimmed_payload, "extreme_shift", fact.timeline_trimmed.extreme_shift);
      PayloadAddTime(timeline_trimmed_payload, "extreme_time", fact.timeline_trimmed.extreme_time);
      PayloadAddDouble(timeline_trimmed_payload, "extreme_price", fact.timeline_trimmed.extreme_price, _Digits);
      PayloadAddInt(timeline_trimmed_payload, "forming_end_shift", fact.timeline_trimmed.forming_end_shift);
      PayloadAddTime(timeline_trimmed_payload, "forming_end_time", fact.timeline_trimmed.forming_end_time);
      PayloadAddDouble(timeline_trimmed_payload, "forming_end_price", fact.timeline_trimmed.forming_end_price, _Digits);
      PayloadAddBool(timeline_trimmed_payload, "has_confirmed_segment", fact.timeline_trimmed.has_confirmed_segment);
      PayloadAddInt(timeline_trimmed_payload, "confirmed_begin_shift", fact.timeline_trimmed.confirmed_begin_shift);
      PayloadAddTime(timeline_trimmed_payload, "confirmed_begin_time", fact.timeline_trimmed.confirmed_begin_time);
      PayloadAddDouble(timeline_trimmed_payload, "confirmed_begin_price", fact.timeline_trimmed.confirmed_begin_price, _Digits);
      PayloadAddInt(timeline_trimmed_payload, "confirmed_end_shift", fact.timeline_trimmed.confirmed_end_shift);
      PayloadAddTime(timeline_trimmed_payload, "confirmed_end_time", fact.timeline_trimmed.confirmed_end_time);
      PayloadAddDouble(timeline_trimmed_payload, "confirmed_end_price", fact.timeline_trimmed.confirmed_end_price, _Digits);
      PayloadAddBool(timeline_trimmed_payload, "has_invalidated_segment", fact.timeline_trimmed.has_invalidated_segment);
      PayloadAddInt(timeline_trimmed_payload, "invalid_begin_shift", fact.timeline_trimmed.invalid_begin_shift);
      PayloadAddTime(timeline_trimmed_payload, "invalid_begin_time", fact.timeline_trimmed.invalid_begin_time);
      PayloadAddDouble(timeline_trimmed_payload, "invalid_begin_price", fact.timeline_trimmed.invalid_begin_price, _Digits);
      PayloadAddInt(timeline_trimmed_payload, "invalid_end_shift", fact.timeline_trimmed.invalid_end_shift);
      PayloadAddTime(timeline_trimmed_payload, "invalid_end_time", fact.timeline_trimmed.invalid_end_time);
      PayloadAddDouble(timeline_trimmed_payload, "invalid_end_price", fact.timeline_trimmed.invalid_end_price, _Digits);
      WriteCsvRow(handle,
                  run_id,
                  generated_at,
                  "potential_correction_timeline_trimmed",
                  scope,
                  StringFormat("PC_%d_TRIMMED", fact.index),
                  in_window,
                  fact.begin_time,
                  corr_end_time,
                  timeline_trimmed_payload);
     }

   const int continuation_count = ArraySize(snapshot.potential_continuation_signals);
   for(int i = 0; i < continuation_count; ++i)
     {
      const MohyPotentialContinuationSignalFact fact = snapshot.potential_continuation_signals[i];
      const datetime time_from = (fact.broken_level_time > 0) ? fact.broken_level_time : fact.signal_time;
      const datetime time_to = (fact.signal_time > 0) ? fact.signal_time : time_from;
      const bool in_window = IntersectsWindow(time_from, time_to, window_start, window_end);
      if(!ShouldWriteFact(in_window))
         continue;

      string payload = "";
      PayloadAddInt(payload, "index", fact.index);
      PayloadAddBool(payload, "valid", fact.valid);
      PayloadAddInt(payload, "linked_potential_correction_index", fact.linked_potential_correction_index);
      PayloadAddInt(payload, "linked_potential_impulse_index", fact.linked_potential_impulse_index);
      PayloadAddInt(payload, "linked_potential_impulse_swing3_index", fact.linked_potential_impulse_swing3_index);
      PayloadAddInt(payload, "linked_correction_recency_rank", fact.linked_correction_recency_rank);
      PayloadAddBool(payload, "linked_correction_is_active", fact.linked_correction_is_active);
      PayloadAdd(payload, "linked_correction_state", MohyPotentialCorrectionStateToString(fact.linked_correction_state));
      PayloadAdd(payload, "direction", DirectionToText(fact.direction));
      PayloadAddInt(payload, "correction_confirmed_shift", fact.correction_confirmed_shift);
      PayloadAddTime(payload, "correction_confirmed_time", fact.correction_confirmed_time);
      PayloadAddInt(payload, "trigger_swing3_index", fact.trigger_swing3_index);
      PayloadAddInt(payload, "trigger_middle_leg_index", fact.trigger_middle_leg_index);
      PayloadAddInt(payload, "trigger_broken_leg_index", fact.trigger_broken_leg_index);
      PayloadAdd(payload, "trigger_breakout_certainty", MohyBreakoutCertaintyToString(fact.trigger_breakout_certainty));
      PayloadAddInt(payload, "trigger_breakout_close_count", fact.trigger_breakout_close_count);
      PayloadAddInt(payload, "broken_leg_begin_shift", fact.broken_leg_begin_shift);
      PayloadAddTime(payload, "broken_leg_begin_time", fact.broken_leg_begin_time);
      PayloadAddInt(payload, "broken_leg_end_shift", fact.broken_leg_end_shift);
      PayloadAddTime(payload, "broken_leg_end_time", fact.broken_leg_end_time);
      PayloadAddInt(payload, "signal_shift", fact.signal_shift);
      PayloadAddTime(payload, "signal_time", fact.signal_time);
      PayloadAddInt(payload, "broken_level_shift", fact.broken_level_shift);
      PayloadAddTime(payload, "broken_level_time", fact.broken_level_time);
      PayloadAddDouble(payload, "broken_level_price", fact.broken_level_price, _Digits);
      PayloadAddInt(payload, "selection_rank", fact.selection_rank);
      PayloadAddBool(payload, "is_selected", fact.is_selected);
      PayloadAdd(payload, "diagnostics", fact.diagnostics);
      WriteCsvRow(handle,
                  run_id,
                  generated_at,
                  "potential_continuation_signal",
                  scope,
                  StringFormat("PCS_%d", fact.index),
                  in_window,
                  time_from,
                  time_to,
                  payload);
     }

   const int plan_count = ArraySize(snapshot.trade_setup_plans);
   for(int i = 0; i < plan_count; ++i)
     {
      const MohyTradeSetupPlanFact fact = snapshot.trade_setup_plans[i];
      datetime linked_time_from = 0;
      datetime linked_time_to = 0;

      for(int j = 0; j < continuation_count; ++j)
        {
         const MohyPotentialContinuationSignalFact signal = snapshot.potential_continuation_signals[j];
         if(signal.index != fact.linked_potential_continuation_signal_index)
            continue;
         linked_time_from = (signal.broken_level_time > 0) ? signal.broken_level_time : signal.signal_time;
         linked_time_to = (signal.signal_time > 0) ? signal.signal_time : linked_time_from;
         break;
        }

      const bool in_window = IntersectsWindow(linked_time_from, linked_time_to, window_start, window_end);
      if(!ShouldWriteFact(in_window))
         continue;

      string payload = "";
      PayloadAddInt(payload, "index", fact.index);
      PayloadAddBool(payload, "valid", fact.valid);
      PayloadAddInt(payload, "linked_potential_continuation_signal_index", fact.linked_potential_continuation_signal_index);
      PayloadAddInt(payload, "linked_potential_correction_index", fact.linked_potential_correction_index);
      PayloadAddInt(payload, "linked_potential_impulse_index", fact.linked_potential_impulse_index);
      PayloadAddInt(payload, "linked_potential_impulse_swing3_index", fact.linked_potential_impulse_swing3_index);
      PayloadAddInt(payload, "linked_correction_recency_rank", fact.linked_correction_recency_rank);
      PayloadAddBool(payload, "linked_correction_is_active", fact.linked_correction_is_active);
      PayloadAdd(payload, "direction", DirectionToText(fact.direction));
      PayloadAdd(payload, "plan_state", MohyTradeSetupPlanStateToString(fact.plan_state));
      PayloadAdd(payload, "reject_reason", RejectReasonToText(fact.reject_reason));
      PayloadAdd(payload, "execution_mode", EntryExecutionModeToText(fact.execution_mode));
      PayloadAddInt(payload, "setup_shift", fact.setup_shift);
      PayloadAddTime(payload, "setup_time", fact.setup_time);
      PayloadAdd(payload, "post_be_profile", PostBEProfileToText(fact.post_be_profile));
      PayloadAddDouble(payload, "current_executable_price", fact.current_executable_price, _Digits);
      PayloadAddDouble(payload, "proposed_entry_price", fact.proposed_entry_price, _Digits);
      PayloadAddDouble(payload, "expected_fill_price", fact.expected_fill_price, _Digits);
      PayloadAddDouble(payload, "required_entry_price", fact.required_entry_price, _Digits);
      PayloadAddDouble(payload, "trigger_price", fact.trigger_price, _Digits);
      PayloadAddDouble(payload, "stop_price", fact.stop_price, _Digits);
      PayloadAddDouble(payload, "target_price", fact.target_price, _Digits);
      PayloadAddDouble(payload, "reward_to_risk", fact.reward_to_risk, 10);
      PayloadAddDouble(payload, "min_rr", fact.min_rr, 10);
      PayloadAddDouble(payload, "rr_tolerance", fact.rr_tolerance, 10);
      PayloadAdd(payload, "trigger_touch_side", MohyTouchSideToString(fact.trigger_touch_side));
      PayloadAdd(payload, "recheck_mode", MohyRecheckModeToString(fact.recheck_mode));
      PayloadAdd(payload, "adjust_cadence", MohyAdjustCadenceToString(fact.adjust_cadence));
      PayloadAddInt(payload, "adjust_min_seconds", fact.adjust_min_seconds);
      PayloadAddBool(payload, "recheck_rr_at_trigger", fact.recheck_rr_at_trigger);
      PayloadAddDouble(payload, "spread_est_points", fact.spread_est_points, 10);
      PayloadAddDouble(payload, "slippage_est_points", fact.slippage_est_points, 10);
      PayloadAddDouble(payload, "commission_est_points", fact.commission_est_points, 10);
      PayloadAddDouble(payload, "total_entry_cost_points", fact.total_entry_cost_points, 10);
      PayloadAddDouble(payload, "min_trigger_move_points", fact.min_trigger_move_points, 10);
      PayloadAddBool(payload, "trigger_freeze_enabled", fact.trigger_freeze_enabled);
      PayloadAddDouble(payload, "trigger_freeze_points", fact.trigger_freeze_points, 10);
      PayloadAddBool(payload, "pending_auto_modify_enabled", fact.pending_auto_modify_enabled);
      PayloadAddDouble(payload, "risk_distance_points", fact.risk_distance_points, 10);
      PayloadAddDouble(payload, "risk_money", fact.risk_money, 10);
      PayloadAddDouble(payload, "lots_raw", fact.lots_raw, 10);
      PayloadAddDouble(payload, "lots_normalized", fact.lots_normalized, 10);
      PayloadAddDouble(payload, "spread_points", fact.spread_points, 10);
      PayloadAddBool(payload, "spread_pass", fact.spread_pass);
      PayloadAddBool(payload, "exposure_pass", fact.exposure_pass);
      PayloadAdd(payload, "stop_anchor_type", MohyTradeSetupStopAnchorTypeToString(fact.stop_anchor_type));
      PayloadAdd(payload, "target_anchor_type", MohyTradeSetupTargetAnchorTypeToString(fact.target_anchor_type));
      PayloadAddInt(payload, "stop_anchor_shift", fact.stop_anchor_shift);
      PayloadAddInt(payload, "target_anchor_shift", fact.target_anchor_shift);
      PayloadAddInt(payload, "selection_rank", fact.selection_rank);
      PayloadAddBool(payload, "is_selected", fact.is_selected);
      PayloadAddTime(payload, "linked_time_from", linked_time_from);
      PayloadAddTime(payload, "linked_time_to", linked_time_to);
      PayloadAdd(payload, "diagnostics", fact.diagnostics);
      WriteCsvRow(handle,
                  run_id,
                  generated_at,
                  "trade_setup_plan",
                  scope,
                  StringFormat("TSP_%d", fact.index),
                  in_window,
                  linked_time_from,
                  linked_time_to,
                  payload);
     }
  }

void ExportChartBars(const int handle,
                     const string run_id,
                     const string generated_at,
                     const string symbol,
                     const datetime window_start,
                     const datetime window_end)
  {
   const int chart_tf = (int)_Period;
   const int bars = MohyIBars(symbol, chart_tf);
   if(bars <= 5)
      return;

   int window_start_shift = MohyIBarShift(symbol, chart_tf, window_start, false);
   int window_end_shift = MohyIBarShift(symbol, chart_tf, window_end, false);
   int older_shift = MathMax(window_start_shift, window_end_shift);
   if(older_shift < 0)
      older_shift = MathMin(bars - 2, MathMax(100, LookbackBars));

   const int from_shift = 1;
   const int max_shift = MathMin(bars - 2,
                                 MathMax(MathMax(20, LookbackBars),
                                         older_shift + MathMax(0, BarContextBeforeWindow)));

   const string scope = StringFormat("Chart/%s", MohyTimeframeToString(chart_tf));
   ExportBars(handle,
              run_id,
              generated_at,
              scope,
              symbol,
              chart_tf,
              from_shift,
              max_shift,
              window_start_shift,
              window_end_shift,
              window_start,
              window_end);
  }

bool WriteLastRunPointer(const string output_dir,
                         const datetime generated_at_time,
                         const string run_id,
                         const string csv_relative_path,
                         const string symbol,
                         const int chart_timeframe,
                         const int htf,
                         const int ltf,
                         const datetime window_start,
                         const datetime window_end,
                         const string window_source,
                         const string window_start_name,
                         const string window_end_name)
  {
   const string pointer_path = output_dir + "\\last_run_pointer.csv";
   const int handle = FileOpen(pointer_path, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("[WindowDebugExporter] Failed to write last run pointer: %s (error=%d)",
                  pointer_path,
                  GetLastError());
      return false;
     }

   FileWrite(handle,
             "generated_at",
             "run_id",
             "csv_relative_path",
             "symbol",
             "chart_timeframe",
             "htf",
             "ltf",
             "window_start",
             "window_end",
             "window_source",
             "window_start_line",
             "window_end_line");

   FileWrite(handle,
             TimeText(generated_at_time),
             run_id,
             csv_relative_path,
             symbol,
             MohyTimeframeToString(chart_timeframe),
             MohyTimeframeToString(htf),
             MohyTimeframeToString(ltf),
             TimeText(window_start),
             TimeText(window_end),
             window_source,
             window_start_name,
             window_end_name);
   FileClose(handle);
   return true;
  }

void OnStart()
  {
   const string symbol = Symbol();
   const datetime now = TimeCurrent();
   const string generated_at = TimeText(now);
   string run_id = TrimText(DebugRunId);
   if(run_id == "")
      run_id = StringFormat("RUN_%s", BuildTimestampToken(now));
   const string run_id_token = SanitizeToken(run_id);

   StrategyConfig cfg;
   string cfg_error = "";
   if(!ConfigureFromInputs(cfg, cfg_error))
     {
      PrintFormat("[WindowDebugExporter] Configuration error: %s", cfg_error);
      return;
     }

   MohyDebugVLine lines[];
   const int line_count = CollectVerticalLines(lines);
   datetime window_start = 0;
   datetime window_end = 0;
   string window_start_name = "";
   string window_end_name = "";
   string window_source = "";
   string window_error = "";
   if(!ResolveWindow(lines,
                     window_start,
                     window_end,
                     window_start_name,
                     window_end_name,
                     window_source,
                     window_error))
     {
      PrintFormat("[WindowDebugExporter] %s", window_error);
      PrintFormat("[WindowDebugExporter] Found vertical lines: %d", line_count);
      for(int i = 0; i < line_count; ++i)
        {
         PrintFormat("[WindowDebugExporter]   name=%s time=%s selected=%d",
                     lines[i].name,
                     TimeText(lines[i].time),
                     ToInt(lines[i].selected));
        }
      return;
     }

   const string normalized_dir = NormalizeDirectoryPath(OutputDirectory);
   if(!EnsureOutputDirectory(normalized_dir))
     {
      PrintFormat("[WindowDebugExporter] Failed to create output directory: %s", normalized_dir);
      return;
     }

   const string filename = StringFormat("window_debug_%s_%s_%s_%s_%s.csv",
                                        SanitizeToken(symbol),
                                        MohyTimeframeToString((int)_Period),
                                        BuildTimestampToken(window_start),
                                        BuildTimestampToken(window_end),
                                        run_id_token);
   const string relative_path = normalized_dir + "\\" + filename;

   const int handle = FileOpen(relative_path, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("[WindowDebugExporter] Failed to open output file: %s (error=%d)",
                  relative_path,
                  GetLastError());
      return;
     }

   WriteCsvHeader(handle);

   string meta = "";
   PayloadAdd(meta, "symbol", symbol);
   PayloadAdd(meta, "chart_timeframe", MohyTimeframeToString((int)_Period));
   PayloadAdd(meta, "htf", MohyTimeframeToString(cfg.context_timeframe));
   PayloadAdd(meta, "ltf", MohyTimeframeToString(cfg.execution_timeframe));
   PayloadAdd(meta, "window_start", TimeText(window_start));
   PayloadAdd(meta, "window_end", TimeText(window_end));
   PayloadAdd(meta, "window_start_line", window_start_name);
   PayloadAdd(meta, "window_end_line", window_end_name);
   PayloadAdd(meta, "window_source", window_source);
   PayloadAddBool(meta, "include_provisional_latest", ResolveIncludeProvisionalLatest());
   PayloadAddInt(meta, "lookback_bars", MathMax(20, LookbackBars));
   PayloadAddInt(meta, "window_older_context_bars", MathMax(0, WindowOlderContextBars));
   PayloadAddInt(meta, "bar_context_before", MathMax(0, BarContextBeforeWindow));
   PayloadAddInt(meta, "bar_context_after", MathMax(0, BarContextAfterWindow));
   PayloadAddBool(meta, "export_facts_outside_window", ExportFactsOutsideWindow);
   PayloadAddLong(meta, "chart_id", ChartID());
   PayloadAddInt(meta, "terminal_build", (int)TerminalInfoInteger(TERMINAL_BUILD));
   PayloadAddInt(meta, "line_count", line_count);
   WriteCsvRow(handle,
               run_id,
               generated_at,
               "metadata",
               "global",
               "meta",
               true,
               window_start,
               window_end,
               meta);

   const string cfg_sig = BuildStrategyConfigSignature(cfg);
   string cfg_payload = "";
   PayloadAdd(cfg_payload, "config_hash", HashHex(cfg_sig));
   PayloadAdd(cfg_payload, "config_type", "strategy");
   PayloadAdd(cfg_payload, "sl_mode", SLModeToText(cfg.sl_mode));
   PayloadAdd(cfg_payload, "tp_mode", TPModeToText(cfg.tp_mode));
   PayloadAdd(cfg_payload, "config_signature", cfg_sig);
   WriteCsvRow(handle,
               run_id,
               generated_at,
               "config",
               "global",
               "strategy",
               true,
               window_start,
               window_end,
               cfg_payload);

   for(int i = 0; i < line_count; ++i)
     {
      string line_payload = "";
      PayloadAdd(line_payload, "name", lines[i].name);
      PayloadAddTime(line_payload, "time", lines[i].time);
      PayloadAddBool(line_payload, "selected", lines[i].selected);
      PayloadAddLong(line_payload, "color", lines[i].line_color);
      PayloadAddInt(line_payload, "style", lines[i].style);
      PayloadAddInt(line_payload, "width", lines[i].width);
      WriteCsvRow(handle,
                  run_id,
                  generated_at,
                  "vline",
                  "chart",
                  StringFormat("VLINE_%d", i),
                  IsTimeInWindow(lines[i].time, window_start, window_end),
                  lines[i].time,
                  lines[i].time,
                  line_payload);
     }

   ExportChartBars(handle,
                   run_id,
                   generated_at,
                   symbol,
                   window_start,
                   window_end);

   if(KernelDebugScope == MOHY_KERNEL_DEBUG_SCOPE_LTF_ONLY ||
      KernelDebugScope == MOHY_KERNEL_DEBUG_SCOPE_HTF_AND_LTF)
     {
      ExportKernelSnapshot(handle,
                           run_id,
                           generated_at,
                           symbol,
                           cfg,
                           cfg.execution_timeframe,
                           window_start,
                           window_end);
     }

   if(KernelDebugScope == MOHY_KERNEL_DEBUG_SCOPE_HTF_ONLY ||
      KernelDebugScope == MOHY_KERNEL_DEBUG_SCOPE_HTF_AND_LTF)
     {
      ExportKernelSnapshot(handle,
                           run_id,
                           generated_at,
                           symbol,
                           cfg,
                           cfg.context_timeframe,
                           window_start,
                           window_end);
     }

   FileClose(handle);
   const bool pointer_written = WriteLastRunPointer(normalized_dir,
                                                    now,
                                                    run_id,
                                                    relative_path,
                                                    symbol,
                                                    (int)_Period,
                                                    cfg.context_timeframe,
                                                    cfg.execution_timeframe,
                                                    window_start,
                                                    window_end,
                                                    window_source,
                                                    window_start_name,
                                                    window_end_name);
   PrintFormat("[WindowDebugExporter] CSV exported: %s", relative_path);
   if(pointer_written)
      PrintFormat("[WindowDebugExporter] Last run pointer updated: %s\\last_run_pointer.csv", normalized_dir);
   PrintFormat("[WindowDebugExporter] Window: %s -> %s (%s)",
               TimeText(window_start),
               TimeText(window_end),
               window_source);
  }
