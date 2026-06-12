#property strict
#property script_show_inputs

#include <MOHY/Domain/Config.mqh>
#include <MOHY/Core/PriceActionKernel.mqh>

enum MohyPotentialImpulseMatrixProfile
  {
   MOHY_PI_MATRIX_PROFILE_LITE = 0,
   MOHY_PI_MATRIX_PROFILE_FULL = 1
  };

input string VerificationRunId = "";
input string VerificationSymbol = "";
input ENUM_TIMEFRAMES VerificationSourceTimeframe = PERIOD_H1;
input ENUM_TIMEFRAMES VerificationHTF = PERIOD_H1;
input ENUM_TIMEFRAMES VerificationLTF = PERIOD_M15;
input int VerificationLookbackBars = 1600;
input bool VerificationIncludeProvisionalLatest = true;
input MohyPotentialImpulseMatrixProfile VerificationMatrixProfile = MOHY_PI_MATRIX_PROFILE_FULL;
input int VerificationMaxCases = 0;
input string VerificationOutputDirectory = "MOHY\\verification\\potential_impulse";
input bool VerificationWriteDetailsCsv = true;
input bool VerificationWriteAssertionsCsv = true;

struct MohyPiMatrixCase
  {
   bool   enable;
   int    min_swing_breakout_closes;
   bool   require_leg_breakout;
   int    min_leg_breakout_closes;
   bool   require_directional_candles;
   bool   validate_endpoint_candles;
   int    allow_opposite_begin_candles;
   int    allow_opposite_end_candles;
   int    max_opposite_middle_candles;
   bool   allow_any_opposite_before_leg_breakout;
   double doji_epsilon_points;
  };

struct MohyPiMatrixResult
  {
   int    case_index;
   bool   enable;
   int    min_swing_breakout_closes;
   bool   require_leg_breakout;
   int    min_leg_breakout_closes;
   bool   require_directional_candles;
   bool   validate_endpoint_candles;
   int    allow_opposite_begin_candles;
   int    allow_opposite_end_candles;
   int    max_opposite_middle_candles;
   bool   allow_any_opposite_before_leg_breakout;
   double doji_epsilon_points;
   string config_hash;
   int    selection_count;
   int    confirmed_count;
   int    live_count;
   int    bull_count;
   int    bear_count;
   int    diagnostics_missing_count;
   string diagnostics_hash;
   string selection_hash;
   string full_hash;
  };

struct MohyPiAssertionRow
  {
   string rule_id;
   bool   pass;
   int    violation_count;
   string sample;
  };

int ToInt(const bool value)
  {
   return value ? 1 : 0;
  }

bool NearlyEqual(const double a,
                 const double b)
  {
   return (MathAbs(a - b) <= 1e-12);
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

string BoolText(const bool value)
  {
   return value ? "1" : "0";
  }

bool ResolveIncludeProvisionalLatest()
  {
   if(!VerificationIncludeProvisionalLatest)
      Print("MOHY | PI_MATRIX | VerificationIncludeProvisionalLatest=false requested; kernel publication lock forces provisional=true.");
   return true;
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

string BuildCaseConfigSignature(const MohyPiMatrixCase &cfg)
  {
   return StringFormat("enable=%s|minSwing=%d|reqLeg=%s|minLeg=%d|reqDir=%s|validateEndpoints=%s|allowBegin=%d|allowEnd=%d|maxMiddle=%d|allowAnyBeforeLegBreak=%s|doji=%s",
                       BoolText(cfg.enable),
                       cfg.min_swing_breakout_closes,
                       BoolText(cfg.require_leg_breakout),
                       cfg.min_leg_breakout_closes,
                       BoolText(cfg.require_directional_candles),
                       BoolText(cfg.validate_endpoint_candles),
                       cfg.allow_opposite_begin_candles,
                       cfg.allow_opposite_end_candles,
                       cfg.max_opposite_middle_candles,
                       BoolText(cfg.allow_any_opposite_before_leg_breakout),
                       DoubleToString(cfg.doji_epsilon_points, 10));
  }

void AppendCase(MohyPiMatrixCase &io_cases[],
                const MohyPiMatrixCase &value)
  {
   const int size = ArraySize(io_cases);
   ArrayResize(io_cases, size + 1);
   io_cases[size] = value;
  }
void BuildProfileDomain(const MohyPotentialImpulseMatrixProfile profile,
                        int &out_enable_flags[],
                        int &out_min_swing_values[],
                        int &out_require_leg_flags[],
                        int &out_min_leg_values[],
                        int &out_require_directional_flags[],
                        int &out_validate_endpoint_flags[],
                        int &out_allow_begin_values[],
                        int &out_allow_end_values[],
                        int &out_max_middle_values[],
                        int &out_allow_any_flags[],
                        double &out_doji_values[])
  {
   ArrayResize(out_enable_flags, 2);
   out_enable_flags[0] = 1;
   out_enable_flags[1] = 0;

   ArrayResize(out_min_swing_values, 3);
   out_min_swing_values[0] = 0;
   out_min_swing_values[1] = 1;
   out_min_swing_values[2] = 2;

   ArrayResize(out_require_leg_flags, 2);
   out_require_leg_flags[0] = 1;
   out_require_leg_flags[1] = 0;

   ArrayResize(out_min_leg_values, 2);
   out_min_leg_values[0] = 1;
   out_min_leg_values[1] = 2;

   ArrayResize(out_require_directional_flags, 2);
   out_require_directional_flags[0] = 1;
   out_require_directional_flags[1] = 0;

   ArrayResize(out_validate_endpoint_flags, (profile == MOHY_PI_MATRIX_PROFILE_FULL) ? 2 : 1);
   out_validate_endpoint_flags[0] = 0;
   if(ArraySize(out_validate_endpoint_flags) > 1)
      out_validate_endpoint_flags[1] = 1;

   ArrayResize(out_allow_begin_values, 2);
   out_allow_begin_values[0] = 0;
   out_allow_begin_values[1] = 1;

   ArrayResize(out_allow_end_values, (profile == MOHY_PI_MATRIX_PROFILE_FULL) ? 2 : 1);
   out_allow_end_values[0] = 0;
   if(ArraySize(out_allow_end_values) > 1)
      out_allow_end_values[1] = 1;

   ArrayResize(out_max_middle_values, 2);
   out_max_middle_values[0] = 0;
   out_max_middle_values[1] = 1;

   ArrayResize(out_allow_any_flags, 2);
   out_allow_any_flags[0] = 0;
   out_allow_any_flags[1] = 1;

   if(profile == MOHY_PI_MATRIX_PROFILE_FULL)
     {
      ArrayResize(out_doji_values, 3);
      out_doji_values[0] = 1e-10;
      out_doji_values[1] = 0.1;
      out_doji_values[2] = 1.0;
     }
   else
     {
      ArrayResize(out_doji_values, 1);
      out_doji_values[0] = 0.1;
     }
  }

void BuildMatrixCases(const MohyPotentialImpulseMatrixProfile profile,
                      const int max_cases,
                      MohyPiMatrixCase &out_cases[])
  {
   ArrayResize(out_cases, 0);

   int enable_flags[];
   int min_swing_values[];
   int require_leg_flags[];
   int min_leg_values[];
   int require_directional_flags[];
   int validate_endpoint_flags[];
   int allow_begin_values[];
   int allow_end_values[];
   int max_middle_values[];
   int allow_any_flags[];
   double doji_values[];

   BuildProfileDomain(profile,
                      enable_flags,
                      min_swing_values,
                      require_leg_flags,
                      min_leg_values,
                      require_directional_flags,
                      validate_endpoint_flags,
                      allow_begin_values,
                      allow_end_values,
                      max_middle_values,
                      allow_any_flags,
                      doji_values);

   bool stop = false;
   for(int ie = 0; ie < ArraySize(enable_flags) && !stop; ++ie)
     {
      for(int ims = 0; ims < ArraySize(min_swing_values) && !stop; ++ims)
        {
         for(int irl = 0; irl < ArraySize(require_leg_flags) && !stop; ++irl)
           {
            for(int iml = 0; iml < ArraySize(min_leg_values) && !stop; ++iml)
              {
               for(int ird = 0; ird < ArraySize(require_directional_flags) && !stop; ++ird)
                 {
                  for(int ive = 0; ive < ArraySize(validate_endpoint_flags) && !stop; ++ive)
                    {
                     for(int iab = 0; iab < ArraySize(allow_begin_values) && !stop; ++iab)
                       {
                        for(int iae = 0; iae < ArraySize(allow_end_values) && !stop; ++iae)
                          {
                           for(int imm = 0; imm < ArraySize(max_middle_values) && !stop; ++imm)
                             {
                              for(int iaa = 0; iaa < ArraySize(allow_any_flags) && !stop; ++iaa)
                                {
                                 for(int ide = 0; ide < ArraySize(doji_values) && !stop; ++ide)
                                   {
                                    MohyPiMatrixCase c;
                                    c.enable = (enable_flags[ie] != 0);
                                    c.min_swing_breakout_closes = min_swing_values[ims];
                                    c.require_leg_breakout = (require_leg_flags[irl] != 0);
                                    c.min_leg_breakout_closes = min_leg_values[iml];
                                    c.require_directional_candles = (require_directional_flags[ird] != 0);
                                    c.validate_endpoint_candles = (validate_endpoint_flags[ive] != 0);
                                    c.allow_opposite_begin_candles = allow_begin_values[iab];
                                    c.allow_opposite_end_candles = allow_end_values[iae];
                                    c.max_opposite_middle_candles = max_middle_values[imm];
                                    c.allow_any_opposite_before_leg_breakout = (allow_any_flags[iaa] != 0);
                                    c.doji_epsilon_points = doji_values[ide];
                                    AppendCase(out_cases, c);

                                    if(max_cases > 0 && ArraySize(out_cases) >= max_cases)
                                       stop = true;
                                   }
                                }
                             }
                          }
                       }
                    }
                 }
              }
           }
        }
     }
  }
bool EvaluateSingleCase(const string symbol,
                        const int source_timeframe,
                        const int context_timeframe,
                        const int execution_timeframe,
                        const int lookback_bars,
                        const bool include_provisional_latest,
                        const int case_index,
                        const MohyPiMatrixCase &c,
                        MohyPiMatrixResult &out_result,
                        string &out_error)
  {
   out_error = "";

   DetectionConfig cfg;
   MohySetDefaultDetectionConfig(cfg);
   cfg.enable_potential_impulse = c.enable;
   cfg.potential_impulse_min_swing_breakout_closes = MathMax(0, c.min_swing_breakout_closes);
   cfg.potential_impulse_require_leg_breakout = c.require_leg_breakout;
   cfg.potential_impulse_min_leg_breakout_closes = MathMax(1, c.min_leg_breakout_closes);
   cfg.potential_impulse_require_directional_candles = c.require_directional_candles;
   cfg.potential_impulse_validate_endpoint_candles = c.validate_endpoint_candles;
   cfg.potential_impulse_allow_opposite_begin_candles = MathMax(0, c.allow_opposite_begin_candles);
   cfg.potential_impulse_allow_opposite_end_candles = MathMax(0, c.allow_opposite_end_candles);
   cfg.potential_impulse_max_opposite_middle_candles = MathMax(0, c.max_opposite_middle_candles);
   cfg.potential_impulse_allow_any_opposite_before_leg_breakout = c.allow_any_opposite_before_leg_breakout;
   cfg.potential_impulse_doji_epsilon_points = MathMax(1e-10, c.doji_epsilon_points);
   cfg.enable_potential_correction = false;

   CMohyPriceActionKernel kernel;
   kernel.Configure(cfg,
                    source_timeframe,
                    context_timeframe,
                    execution_timeframe);

   CMohyPriceActionSnapshot snapshot;
   if(!kernel.BuildRecent(symbol,
                          lookback_bars,
                          snapshot,
                          include_provisional_latest))
     {
      out_error = StringFormat("BuildRecent failed for symbol=%s tf=%s bars=%d",
                               symbol,
                               MohyTimeframeToString(source_timeframe),
                               MohyIBars(symbol, source_timeframe));
      return false;
     }

   out_result.case_index = case_index;
   out_result.enable = c.enable;
   out_result.min_swing_breakout_closes = c.min_swing_breakout_closes;
   out_result.require_leg_breakout = c.require_leg_breakout;
   out_result.min_leg_breakout_closes = c.min_leg_breakout_closes;
   out_result.require_directional_candles = c.require_directional_candles;
   out_result.validate_endpoint_candles = c.validate_endpoint_candles;
   out_result.allow_opposite_begin_candles = c.allow_opposite_begin_candles;
   out_result.allow_opposite_end_candles = c.allow_opposite_end_candles;
   out_result.max_opposite_middle_candles = c.max_opposite_middle_candles;
   out_result.allow_any_opposite_before_leg_breakout = c.allow_any_opposite_before_leg_breakout;
   out_result.doji_epsilon_points = c.doji_epsilon_points;
   out_result.config_hash = HashHex(BuildCaseConfigSignature(c));
   out_result.selection_count = 0;
   out_result.confirmed_count = 0;
   out_result.live_count = 0;
   out_result.bull_count = 0;
   out_result.bear_count = 0;
   out_result.diagnostics_missing_count = 0;
   out_result.diagnostics_hash = "";

   string selection_signature = "";
   string diagnostics_signature = "";
   string full_signature = "";
   const int impulse_count = ArraySize(snapshot.potential_impulses);
   for(int i = 0; i < impulse_count; ++i)
     {
      const MohyPotentialImpulseFact fact = snapshot.potential_impulses[i];
      if(!fact.valid)
         continue;

      out_result.selection_count++;
      if(fact.confirmed)
         out_result.confirmed_count++;
      else
         out_result.live_count++;

      if(fact.direction == MOHY_DIR_BULL)
         out_result.bull_count++;
      if(fact.direction == MOHY_DIR_BEAR)
         out_result.bear_count++;

      const string diagnostics = TrimText(fact.diagnostics);
      if(diagnostics == "")
         out_result.diagnostics_missing_count++;

      selection_signature += StringFormat("%d|%d|%d|%d|%d|%d;",
                                          fact.swing3_index,
                                          fact.leg_index,
                                          (int)fact.direction,
                                          fact.begin_shift,
                                          fact.end_shift,
                                          ToInt(fact.confirmed));

      diagnostics_signature += StringFormat("%d|%d|%s;",
                                            fact.swing3_index,
                                            fact.leg_index,
                                            diagnostics);

      full_signature += StringFormat("%d|%d|%d|%d|%d|%d|%d|%d|%s|%d|%I64d|%d|%I64d|%s|%d|%I64d|%s|%s;",
                                     fact.swing3_index,
                                     fact.leg_index,
                                     (int)fact.direction,
                                     ToInt(fact.confirmed),
                                     (int)fact.pattern_type,
                                     (int)fact.break_state,
                                     (int)fact.swing_breakout_certainty,
                                     fact.swing_breakout_close_count,
                                     DoubleToString(fact.leg_break_reference_price, 8),
                                     fact.leg_breakout_close_count,
                                     fact.first_leg_breakout_time,
                                     fact.begin_shift,
                                     fact.begin_time,
                                     DoubleToString(fact.begin_price, 8),
                                     fact.end_shift,
                                     fact.end_time,
                                     DoubleToString(fact.end_price, 8),
                                     diagnostics);
     }

   if(selection_signature == "")
      selection_signature = "EMPTY";
   if(diagnostics_signature == "")
      diagnostics_signature = "EMPTY";
   if(full_signature == "")
      full_signature = "EMPTY";

   out_result.diagnostics_hash = HashHex(diagnostics_signature);
   out_result.selection_hash = HashHex(selection_signature);
   out_result.full_hash = HashHex(full_signature);
   return true;
  }

void AppendAssertion(MohyPiAssertionRow &io_rows[],
                     const string rule_id,
                     const bool pass,
                     const int violation_count,
                     const string sample)
  {
   const int size = ArraySize(io_rows);
   ArrayResize(io_rows, size + 1);
   io_rows[size].rule_id = rule_id;
   io_rows[size].pass = pass;
   io_rows[size].violation_count = violation_count;
   io_rows[size].sample = sample;
  }

int FindKeyIndex(const string &keys[],
                 const string key)
  {
   const int size = ArraySize(keys);
   for(int i = 0; i < size; ++i)
     {
      if(keys[i] == key)
         return i;
     }
   return -1;
  }
void EvaluateAssertions(const MohyPiMatrixResult &results[],
                        MohyPiAssertionRow &out_assertions[])
  {
   ArrayResize(out_assertions, 0);
   const int n = ArraySize(results);

   int v_enable_off = 0;
   string s_enable_off = "";
   for(int i = 0; i < n; ++i)
     {
      if(results[i].enable)
         continue;
      if(results[i].selection_count != 0)
        {
         v_enable_off++;
         if(s_enable_off == "")
            s_enable_off = StringFormat("case=%d count=%d",
                                        results[i].case_index,
                                        results[i].selection_count);
        }
     }
   AppendAssertion(out_assertions,
                   "ENABLE_OFF_EMPTY",
                   (v_enable_off == 0),
                   v_enable_off,
                   s_enable_off);

   int v_swing_monotonic = 0;
   string s_swing_monotonic = "";
   for(int i = 0; i < n; ++i)
     {
      for(int j = 0; j < n; ++j)
        {
         if(results[i].enable != results[j].enable)
            continue;
         if(results[i].require_leg_breakout != results[j].require_leg_breakout)
            continue;
         if(results[i].min_leg_breakout_closes != results[j].min_leg_breakout_closes)
            continue;
         if(results[i].require_directional_candles != results[j].require_directional_candles)
            continue;
         if(results[i].validate_endpoint_candles != results[j].validate_endpoint_candles)
            continue;
         if(results[i].allow_opposite_begin_candles != results[j].allow_opposite_begin_candles)
            continue;
         if(results[i].allow_opposite_end_candles != results[j].allow_opposite_end_candles)
            continue;
         if(results[i].max_opposite_middle_candles != results[j].max_opposite_middle_candles)
            continue;
         if(results[i].allow_any_opposite_before_leg_breakout != results[j].allow_any_opposite_before_leg_breakout)
            continue;
         if(!NearlyEqual(results[i].doji_epsilon_points, results[j].doji_epsilon_points))
            continue;
         if(results[i].min_swing_breakout_closes >= results[j].min_swing_breakout_closes)
            continue;
         if(results[j].selection_count > results[i].selection_count)
           {
            v_swing_monotonic++;
            if(s_swing_monotonic == "")
               s_swing_monotonic = StringFormat("case%d[minSwing=%d,count=%d] -> case%d[minSwing=%d,count=%d]",
                                                results[i].case_index,
                                                results[i].min_swing_breakout_closes,
                                                results[i].selection_count,
                                                results[j].case_index,
                                                results[j].min_swing_breakout_closes,
                                                results[j].selection_count);
           }
        }
     }
   AppendAssertion(out_assertions,
                   "SWING_GATE_MONOTONIC",
                   (v_swing_monotonic == 0),
                   v_swing_monotonic,
                   s_swing_monotonic);

   int v_leg_monotonic = 0;
   string s_leg_monotonic = "";
   for(int i = 0; i < n; ++i)
     {
      if(!results[i].require_leg_breakout)
         continue;
      for(int j = 0; j < n; ++j)
        {
         if(!results[j].require_leg_breakout)
            continue;
         if(results[i].enable != results[j].enable)
            continue;
         if(results[i].min_swing_breakout_closes != results[j].min_swing_breakout_closes)
            continue;
         if(results[i].require_directional_candles != results[j].require_directional_candles)
            continue;
         if(results[i].validate_endpoint_candles != results[j].validate_endpoint_candles)
            continue;
         if(results[i].allow_opposite_begin_candles != results[j].allow_opposite_begin_candles)
            continue;
         if(results[i].allow_opposite_end_candles != results[j].allow_opposite_end_candles)
            continue;
         if(results[i].max_opposite_middle_candles != results[j].max_opposite_middle_candles)
            continue;
         if(results[i].allow_any_opposite_before_leg_breakout != results[j].allow_any_opposite_before_leg_breakout)
            continue;
         if(!NearlyEqual(results[i].doji_epsilon_points, results[j].doji_epsilon_points))
            continue;
         if(results[i].min_leg_breakout_closes >= results[j].min_leg_breakout_closes)
            continue;
         if(results[j].selection_count > results[i].selection_count)
           {
            v_leg_monotonic++;
            if(s_leg_monotonic == "")
               s_leg_monotonic = StringFormat("case%d[minLeg=%d,count=%d] -> case%d[minLeg=%d,count=%d]",
                                              results[i].case_index,
                                              results[i].min_leg_breakout_closes,
                                              results[i].selection_count,
                                              results[j].case_index,
                                              results[j].min_leg_breakout_closes,
                                              results[j].selection_count);
           }
        }
     }
   AppendAssertion(out_assertions,
                   "LEG_GATE_MONOTONIC_WHEN_REQUIRED",
                   (v_leg_monotonic == 0),
                   v_leg_monotonic,
                   s_leg_monotonic);
   int v_directional_ignored = 0;
   string s_directional_ignored = "";
   string dir_keys[];
   string dir_hashes[];
   int dir_counts[];
   int dir_case_indexes[];
   for(int i = 0; i < n; ++i)
     {
      if(results[i].require_directional_candles)
         continue;

      const string key = StringFormat("en=%d|minSwing=%d|reqLeg=%d|minLeg=%d",
                                      ToInt(results[i].enable),
                                      results[i].min_swing_breakout_closes,
                                      ToInt(results[i].require_leg_breakout),
                                      results[i].min_leg_breakout_closes);
      const int ix = FindKeyIndex(dir_keys, key);
      if(ix < 0)
        {
         const int size = ArraySize(dir_keys);
         ArrayResize(dir_keys, size + 1);
         ArrayResize(dir_hashes, size + 1);
         ArrayResize(dir_counts, size + 1);
         ArrayResize(dir_case_indexes, size + 1);
         dir_keys[size] = key;
         dir_hashes[size] = results[i].selection_hash;
         dir_counts[size] = results[i].selection_count;
         dir_case_indexes[size] = results[i].case_index;
        }
      else
        {
         if(results[i].selection_hash != dir_hashes[ix] ||
            results[i].selection_count != dir_counts[ix])
           {
            v_directional_ignored++;
            if(s_directional_ignored == "")
               s_directional_ignored = StringFormat("baseCase=%d compareCase=%d key=%s baseHash=%s compareHash=%s",
                                                    dir_case_indexes[ix],
                                                    results[i].case_index,
                                                    key,
                                                    dir_hashes[ix],
                                                    results[i].selection_hash);
           }
        }
     }
   AppendAssertion(out_assertions,
                   "DIRECTIONAL_PARAMS_IGNORED_WHEN_DIRECTIONAL_DISABLED",
                   (v_directional_ignored == 0),
                   v_directional_ignored,
                   s_directional_ignored);

   int v_min_leg_ignored = 0;
   string s_min_leg_ignored = "";
   string leg_keys[];
   string leg_hashes[];
   int leg_counts[];
   int leg_case_indexes[];
   for(int i = 0; i < n; ++i)
     {
      if(results[i].require_leg_breakout)
         continue;

      const string key = StringFormat("en=%d|minSwing=%d|reqDir=%d|validate=%d|allowBegin=%d|allowEnd=%d|maxMiddle=%d|allowAny=%d|doji=%s",
                                      ToInt(results[i].enable),
                                      results[i].min_swing_breakout_closes,
                                      ToInt(results[i].require_directional_candles),
                                      ToInt(results[i].validate_endpoint_candles),
                                      results[i].allow_opposite_begin_candles,
                                      results[i].allow_opposite_end_candles,
                                      results[i].max_opposite_middle_candles,
                                      ToInt(results[i].allow_any_opposite_before_leg_breakout),
                                      DoubleToString(results[i].doji_epsilon_points, 10));
      const int ix = FindKeyIndex(leg_keys, key);
      if(ix < 0)
        {
         const int size = ArraySize(leg_keys);
         ArrayResize(leg_keys, size + 1);
         ArrayResize(leg_hashes, size + 1);
         ArrayResize(leg_counts, size + 1);
         ArrayResize(leg_case_indexes, size + 1);
         leg_keys[size] = key;
         leg_hashes[size] = results[i].selection_hash;
         leg_counts[size] = results[i].selection_count;
         leg_case_indexes[size] = results[i].case_index;
        }
      else
        {
         if(results[i].selection_hash != leg_hashes[ix] ||
            results[i].selection_count != leg_counts[ix])
           {
            v_min_leg_ignored++;
            if(s_min_leg_ignored == "")
               s_min_leg_ignored = StringFormat("baseCase=%d compareCase=%d key=%s baseHash=%s compareHash=%s",
                                                leg_case_indexes[ix],
                                                results[i].case_index,
                                                key,
                                                leg_hashes[ix],
                                                results[i].selection_hash);
           }
        }
     }
   AppendAssertion(out_assertions,
                   "MIN_LEG_IGNORED_WHEN_LEG_BREAKOUT_DISABLED",
                   (v_min_leg_ignored == 0),
                   v_min_leg_ignored,
                   s_min_leg_ignored);

   int v_diagnostics_present = 0;
   string s_diagnostics_present = "";
   for(int i = 0; i < n; ++i)
     {
      if(!results[i].enable)
         continue;
      if(results[i].selection_count <= 0)
         continue;
      if(results[i].diagnostics_missing_count == 0)
         continue;

      v_diagnostics_present++;
      if(s_diagnostics_present == "")
         s_diagnostics_present = StringFormat("case=%d selection=%d missing=%d",
                                              results[i].case_index,
                                              results[i].selection_count,
                                              results[i].diagnostics_missing_count);
     }
   AppendAssertion(out_assertions,
                   "DIAGNOSTICS_PRESENT_FOR_SELECTIONS",
                   (v_diagnostics_present == 0),
                   v_diagnostics_present,
                   s_diagnostics_present);
  }

bool WriteMatrixCsv(const string path,
                    const string run_id,
                    const string symbol,
                    const int source_timeframe,
                    const int context_timeframe,
                    const int execution_timeframe,
                    const bool include_provisional_latest,
                    const MohyPiMatrixResult &results[])
  {
   const int handle = FileOpen(path, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("MOHY | PI_MATRIX | Failed to open matrix CSV: %s (err=%d)", path, GetLastError());
      return false;
     }

   FileWrite(handle,
             "run_id",
             "symbol",
             "source_timeframe",
             "context_timeframe",
             "execution_timeframe",
             "include_provisional_latest",
             "case_index",
             "enable",
             "min_swing_breakout_closes",
             "require_leg_breakout",
             "min_leg_breakout_closes",
             "require_directional_candles",
             "validate_endpoint_candles",
             "allow_opposite_begin_candles",
             "allow_opposite_end_candles",
             "max_opposite_middle_candles",
             "allow_any_opposite_before_leg_breakout",
             "doji_epsilon_points",
             "config_hash",
             "selection_count",
             "confirmed_count",
             "live_count",
             "bull_count",
             "bear_count",
             "diagnostics_missing_count",
             "diagnostics_hash",
             "selection_hash",
             "full_hash");

   const int size = ArraySize(results);
   for(int i = 0; i < size; ++i)
     {
      FileWrite(handle,
                run_id,
                symbol,
                MohyTimeframeToString(source_timeframe),
                MohyTimeframeToString(context_timeframe),
                MohyTimeframeToString(execution_timeframe),
                ToInt(include_provisional_latest),
                results[i].case_index,
                ToInt(results[i].enable),
                results[i].min_swing_breakout_closes,
                ToInt(results[i].require_leg_breakout),
                results[i].min_leg_breakout_closes,
                ToInt(results[i].require_directional_candles),
                ToInt(results[i].validate_endpoint_candles),
                results[i].allow_opposite_begin_candles,
                results[i].allow_opposite_end_candles,
                results[i].max_opposite_middle_candles,
                ToInt(results[i].allow_any_opposite_before_leg_breakout),
                DoubleToString(results[i].doji_epsilon_points, 10),
                results[i].config_hash,
                results[i].selection_count,
                results[i].confirmed_count,
                results[i].live_count,
                results[i].bull_count,
                results[i].bear_count,
                results[i].diagnostics_missing_count,
                results[i].diagnostics_hash,
                results[i].selection_hash,
                results[i].full_hash);
     }

   FileClose(handle);
   return true;
  }
bool WriteAssertionsCsv(const string path,
                        const string run_id,
                        const MohyPiAssertionRow &assertions[])
  {
   const int handle = FileOpen(path, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("MOHY | PI_MATRIX | Failed to open assertions CSV: %s (err=%d)", path, GetLastError());
      return false;
     }

   FileWrite(handle,
             "run_id",
             "rule_id",
             "pass",
             "violation_count",
             "sample");

   const int size = ArraySize(assertions);
   for(int i = 0; i < size; ++i)
     {
      FileWrite(handle,
                run_id,
                assertions[i].rule_id,
                ToInt(assertions[i].pass),
                assertions[i].violation_count,
                assertions[i].sample);
     }

   FileClose(handle);
   return true;
  }

void OnStart()
  {
   const string symbol = (TrimText(VerificationSymbol) == "") ? _Symbol : TrimText(VerificationSymbol);
   const int source_timeframe = (int)VerificationSourceTimeframe;
   const int context_timeframe = (int)VerificationHTF;
   const int execution_timeframe = (int)VerificationLTF;
   const bool effective_include_provisional_latest = ResolveIncludeProvisionalLatest();

   if(!SymbolSelect(symbol, true))
     {
      PrintFormat("MOHY | PI_MATRIX | SymbolSelect failed for '%s'", symbol);
      return;
     }

   if(!MohyValidateTimeframePair(context_timeframe, execution_timeframe))
     {
      PrintFormat("MOHY | PI_MATRIX | Invalid timeframe pair HTF=%s LTF=%s",
                  MohyTimeframeToString(context_timeframe),
                  MohyTimeframeToString(execution_timeframe));
      return;
     }

   if(source_timeframe <= 0)
     {
      Print("MOHY | PI_MATRIX | Invalid source timeframe.");
      return;
     }

   MohyPiMatrixCase cases[];
   BuildMatrixCases(VerificationMatrixProfile,
                    MathMax(0, VerificationMaxCases),
                    cases);
   const int case_count = ArraySize(cases);
   if(case_count <= 0)
     {
      Print("MOHY | PI_MATRIX | No matrix cases generated.");
      return;
     }

   string run_id = TrimText(VerificationRunId);
   if(run_id == "")
     {
      run_id = StringFormat("PI_MATRIX_%s_%s_%s",
                            symbol,
                            MohyTimeframeToString(source_timeframe),
                            BuildTimestampToken(TimeCurrent()));
     }
   run_id = SanitizeToken(run_id);

   PrintFormat("MOHY | PI_MATRIX | Starting run_id=%s symbol=%s source_tf=%s HTF/LTF=%s/%s cases=%d profile=%d",
               run_id,
               symbol,
               MohyTimeframeToString(source_timeframe),
               MohyTimeframeToString(context_timeframe),
               MohyTimeframeToString(execution_timeframe),
               case_count,
               (int)VerificationMatrixProfile);

   MohyPiMatrixResult results[];
   ArrayResize(results, case_count);
   bool failed = false;
   string failed_message = "";
   for(int i = 0; i < case_count; ++i)
     {
      string eval_error = "";
      if(!EvaluateSingleCase(symbol,
                             source_timeframe,
                             context_timeframe,
                             execution_timeframe,
                             MathMax(100, VerificationLookbackBars),
                             effective_include_provisional_latest,
                             i,
                             cases[i],
                             results[i],
                             eval_error))
        {
         failed = true;
         failed_message = StringFormat("Case %d failed: %s", i, eval_error);
         break;
        }
     }

   if(failed)
     {
      PrintFormat("MOHY | PI_MATRIX | %s", failed_message);
      return;
     }

   MohyPiAssertionRow assertions[];
   EvaluateAssertions(results, assertions);

   int assertion_fail_count = 0;
   for(int i = 0; i < ArraySize(assertions); ++i)
     {
      if(!assertions[i].pass)
         assertion_fail_count++;
     }

   string matrix_path = "";
   string assertions_path = "";
   if(VerificationWriteDetailsCsv || VerificationWriteAssertionsCsv)
     {
      const string out_dir = NormalizeDirectoryPath(VerificationOutputDirectory);
      if(!EnsureOutputDirectory(out_dir))
        {
         PrintFormat("MOHY | PI_MATRIX | Failed to ensure output directory: %s", out_dir);
         return;
        }

      matrix_path = StringFormat("%s\\%s__matrix.csv", out_dir, run_id);
      assertions_path = StringFormat("%s\\%s__assertions.csv", out_dir, run_id);
     }

   if(VerificationWriteDetailsCsv)
     {
      if(!WriteMatrixCsv(matrix_path,
                         run_id,
                         symbol,
                         source_timeframe,
                         context_timeframe,
                         execution_timeframe,
                         effective_include_provisional_latest,
                         results))
         return;
     }

   if(VerificationWriteAssertionsCsv)
     {
      if(!WriteAssertionsCsv(assertions_path,
                             run_id,
                             assertions))
         return;
     }

   for(int i = 0; i < ArraySize(assertions); ++i)
     {
      PrintFormat("MOHY | PI_MATRIX | Assertion %s pass=%s violations=%d sample=%s",
                  assertions[i].rule_id,
                  assertions[i].pass ? "true" : "false",
                  assertions[i].violation_count,
                  assertions[i].sample);
     }

   PrintFormat("MOHY | PI_MATRIX | Completed run_id=%s cases=%d assertion_failures=%d matrix_csv=%s assertions_csv=%s",
               run_id,
               case_count,
               assertion_fail_count,
               matrix_path,
               assertions_path);
  }
