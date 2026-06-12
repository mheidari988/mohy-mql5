#property strict
#property script_show_inputs

#include <MOHY/Domain/Config.mqh>
#include <MOHY/Core/PriceActionKernel.mqh>

enum MohyPotentialCorrectionMatrixProfile
  {
   MOHY_PC_MATRIX_PROFILE_LITE = 0,
   MOHY_PC_MATRIX_PROFILE_FULL = 1
  };

input string VerificationRunId = "";
input string VerificationSymbol = "";
input ENUM_TIMEFRAMES VerificationSourceTimeframe = PERIOD_M15;
input ENUM_TIMEFRAMES VerificationHTF = PERIOD_H1;
input ENUM_TIMEFRAMES VerificationLTF = PERIOD_M15;
input int VerificationLookbackBars = 2000;
input bool VerificationIncludeProvisionalLatest = true;
input MohyPotentialCorrectionMatrixProfile VerificationMatrixProfile = MOHY_PC_MATRIX_PROFILE_FULL;
input int VerificationMaxCases = 0;
input int VerificationCaseStartIndex = 0;
input int VerificationCaseCount = 0;
input string VerificationOutputDirectory = "MOHY\\verification\\potential_correction";
input bool VerificationWriteDetailsCsv = true;
input bool VerificationAppendDetailsCsv = false;
input bool VerificationWriteAssertionsCsv = true;
input bool VerificationSkipAssertions = false;
input bool VerificationComputeFullHash = true;

struct MohyPcMatrixCase
  {
   bool   enable;
   int    min_opposite_ici_count;
   int    min_fib_level;
   int    min_fib_trigger_mode;
   int    max_fib_level;
   int    max_fib_trigger_mode;
   double extreme_touch_epsilon_points;
   int    extreme_touch_min_count;
   int    supersede_direction_mode;
   int    supersede_scope;
  };

struct MohyPcMatrixResult
  {
   int    case_index;
   bool   enable;
   int    min_opposite_ici_count;
   int    min_fib_level;
   int    min_fib_trigger_mode;
   int    max_fib_level;
   int    max_fib_trigger_mode;
   double extreme_touch_epsilon_points;
   int    extreme_touch_min_count;
   int    supersede_direction_mode;
   int    supersede_scope;
   bool   fib_range_valid;
   string config_hash;
   int    selection_count;
   int    confirmed_count;
   int    forming_count;
   int    invalidated_count;
   int    invalidated_max_fib_count;
   int    invalidated_double_extreme_count;
   int    invalidated_supersede_count;
   int    active_count;
   int    invariant_violation_count;
   string invariant_sample;
   string selection_hash;
   string full_hash;
  };

struct MohyPcAssertionRow
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
      Print("MOHY | PC_MATRIX | VerificationIncludeProvisionalLatest=false requested; kernel publication lock forces provisional=true.");
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

string BuildCaseConfigSignature(const MohyPcMatrixCase &cfg)
  {
   return StringFormat("enable=%s|minOppIci=%d|minFibLevel=%d|minFibTrigger=%d|maxFibLevel=%d|maxFibTrigger=%d|extremeEps=%s|extremeMinTouches=%d|supDir=%d|supScope=%d",
                       BoolText(cfg.enable),
                       cfg.min_opposite_ici_count,
                       cfg.min_fib_level,
                       cfg.min_fib_trigger_mode,
                       cfg.max_fib_level,
                       cfg.max_fib_trigger_mode,
                       DoubleToString(cfg.extreme_touch_epsilon_points, 10),
                       cfg.extreme_touch_min_count,
                       cfg.supersede_direction_mode,
                       cfg.supersede_scope);
  }

void AppendCase(MohyPcMatrixCase &io_cases[],
                const MohyPcMatrixCase &value)
  {
   const int size = ArraySize(io_cases);
   ArrayResize(io_cases, size + 1);
   io_cases[size] = value;
  }

void BuildProfileDomain(const MohyPotentialCorrectionMatrixProfile profile,
                        int &out_enable_flags[],
                        int &out_min_opposite_ici_counts[],
                        int &out_min_fib_levels[],
                        int &out_min_fib_trigger_modes[],
                        int &out_max_fib_levels[],
                        int &out_max_fib_trigger_modes[],
                        double &out_extreme_eps_points[],
                        int &out_extreme_touch_min_counts[],
                        int &out_supersede_direction_modes[],
                        int &out_supersede_scopes[])
  {
   ArrayResize(out_enable_flags, 2);
   out_enable_flags[0] = 1;
   out_enable_flags[1] = 0;

   if(profile == MOHY_PC_MATRIX_PROFILE_FULL)
     {
      ArrayResize(out_min_opposite_ici_counts, 4);
      out_min_opposite_ici_counts[0] = 0;
      out_min_opposite_ici_counts[1] = 1;
      out_min_opposite_ici_counts[2] = 2;
      out_min_opposite_ici_counts[3] = 3;
     }
   else
     {
      ArrayResize(out_min_opposite_ici_counts, 3);
      out_min_opposite_ici_counts[0] = 0;
      out_min_opposite_ici_counts[1] = 1;
      out_min_opposite_ici_counts[2] = 2;
     }

   ArrayResize(out_min_fib_levels, (profile == MOHY_PC_MATRIX_PROFILE_FULL) ? 3 : 2);
   out_min_fib_levels[0] = (int)MOHY_POT_CORR_MIN_FIB_0382;
   if(ArraySize(out_min_fib_levels) > 1)
      out_min_fib_levels[1] = (int)MOHY_POT_CORR_MIN_FIB_0618;
   if(ArraySize(out_min_fib_levels) > 2)
      out_min_fib_levels[2] = (int)MOHY_POT_CORR_MIN_FIB_0500;

   ArrayResize(out_min_fib_trigger_modes, 2);
   out_min_fib_trigger_modes[0] = (int)MOHY_LEVEL_TRIGGER_TOUCH;
   out_min_fib_trigger_modes[1] = (int)MOHY_LEVEL_TRIGGER_CLOSE_BEYOND;

   ArrayResize(out_max_fib_levels, (profile == MOHY_PC_MATRIX_PROFILE_FULL) ? 4 : 2);
   out_max_fib_levels[0] = (int)MOHY_POT_CORR_MAX_FIB_0618;
   if(ArraySize(out_max_fib_levels) > 1)
      out_max_fib_levels[1] = (int)MOHY_POT_CORR_MAX_FIB_0786;
   if(ArraySize(out_max_fib_levels) > 2)
      out_max_fib_levels[2] = (int)MOHY_POT_CORR_MAX_FIB_0886;
   if(ArraySize(out_max_fib_levels) > 3)
      out_max_fib_levels[3] = (int)MOHY_POT_CORR_MAX_FIB_1000;

   ArrayResize(out_max_fib_trigger_modes, (profile == MOHY_PC_MATRIX_PROFILE_FULL) ? 2 : 1);
   out_max_fib_trigger_modes[0] = (int)MOHY_LEVEL_TRIGGER_TOUCH;
   if(ArraySize(out_max_fib_trigger_modes) > 1)
      out_max_fib_trigger_modes[1] = (int)MOHY_LEVEL_TRIGGER_CLOSE_BEYOND;

   if(profile == MOHY_PC_MATRIX_PROFILE_FULL)
     {
      ArrayResize(out_extreme_eps_points, 3);
      out_extreme_eps_points[0] = 0.0;
      out_extreme_eps_points[1] = 0.1;
      out_extreme_eps_points[2] = 1.0;
     }
   else
     {
      ArrayResize(out_extreme_eps_points, 2);
      out_extreme_eps_points[0] = 0.0;
      out_extreme_eps_points[1] = 1.0;
     }

   ArrayResize(out_extreme_touch_min_counts, 2);
   out_extreme_touch_min_counts[0] = 1;
   out_extreme_touch_min_counts[1] = 2;

   ArrayResize(out_supersede_direction_modes, 2);
   out_supersede_direction_modes[0] = (int)MOHY_POT_CORR_SUPERSEDE_DIR_ANY;
   out_supersede_direction_modes[1] = (int)MOHY_POT_CORR_SUPERSEDE_DIR_OPPOSITE_ONLY;

   ArrayResize(out_supersede_scopes, (profile == MOHY_PC_MATRIX_PROFILE_FULL) ? 2 : 1);
   out_supersede_scopes[0] = (int)MOHY_POT_CORR_SUPERSEDE_SCOPE_FORMING_ONLY;
   if(ArraySize(out_supersede_scopes) > 1)
      out_supersede_scopes[1] = (int)MOHY_POT_CORR_SUPERSEDE_SCOPE_FORMING_AND_CONFIRMED;
  }

void BuildMatrixCases(const MohyPotentialCorrectionMatrixProfile profile,
                      const int max_cases,
                      MohyPcMatrixCase &out_cases[])
  {
   ArrayResize(out_cases, 0);

   int enable_flags[];
   int min_opposite_ici_counts[];
   int min_fib_levels[];
   int min_fib_trigger_modes[];
   int max_fib_levels[];
   int max_fib_trigger_modes[];
   double extreme_eps_points[];
   int extreme_touch_min_counts[];
   int supersede_direction_modes[];
   int supersede_scopes[];

   BuildProfileDomain(profile,
                      enable_flags,
                      min_opposite_ici_counts,
                      min_fib_levels,
                      min_fib_trigger_modes,
                      max_fib_levels,
                      max_fib_trigger_modes,
                      extreme_eps_points,
                      extreme_touch_min_counts,
                      supersede_direction_modes,
                      supersede_scopes);

   bool stop = false;
   for(int ie = 0; ie < ArraySize(enable_flags) && !stop; ++ie)
     {
      for(int ioci = 0; ioci < ArraySize(min_opposite_ici_counts) && !stop; ++ioci)
        {
         for(int imf = 0; imf < ArraySize(min_fib_levels) && !stop; ++imf)
           {
            for(int imft = 0; imft < ArraySize(min_fib_trigger_modes) && !stop; ++imft)
              {
               for(int ixf = 0; ixf < ArraySize(max_fib_levels) && !stop; ++ixf)
                 {
                  for(int ixft = 0; ixft < ArraySize(max_fib_trigger_modes) && !stop; ++ixft)
                    {
                     for(int ieps = 0; ieps < ArraySize(extreme_eps_points) && !stop; ++ieps)
                       {
                        for(int ietc = 0; ietc < ArraySize(extreme_touch_min_counts) && !stop; ++ietc)
                          {
                           for(int isd = 0; isd < ArraySize(supersede_direction_modes) && !stop; ++isd)
                             {
                              for(int iss = 0; iss < ArraySize(supersede_scopes) && !stop; ++iss)
                                {
                                 MohyPcMatrixCase c;
                                 c.enable = (enable_flags[ie] != 0);
                                 c.min_opposite_ici_count = min_opposite_ici_counts[ioci];
                                 c.min_fib_level = min_fib_levels[imf];
                                 c.min_fib_trigger_mode = min_fib_trigger_modes[imft];
                                 c.max_fib_level = max_fib_levels[ixf];
                                 c.max_fib_trigger_mode = max_fib_trigger_modes[ixft];
                                 c.extreme_touch_epsilon_points = extreme_eps_points[ieps];
                                 c.extreme_touch_min_count = extreme_touch_min_counts[ietc];
                                 c.supersede_direction_mode = supersede_direction_modes[isd];
                                 c.supersede_scope = supersede_scopes[iss];
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
void NoteInvariantViolation(int &io_count,
                            string &io_sample,
                            const string sample)
  {
   io_count++;
   if(io_sample == "")
      io_sample = sample;
  }

bool EvaluateSingleCase(const string symbol,
                        const int source_timeframe,
                        const int context_timeframe,
                        const int execution_timeframe,
                        const int lookback_bars,
                        const bool include_provisional_latest,
                        const bool compute_full_hash,
                        const int case_index,
                        const MohyPcMatrixCase &c,
                        MohyPcMatrixResult &out_result,
                        string &out_error)
  {
   out_error = "";

   DetectionConfig cfg;
   MohySetDefaultDetectionConfig(cfg);
   cfg.enable_potential_correction = c.enable;
   cfg.potential_correction_min_opposite_ici_count = MathMax(0, c.min_opposite_ici_count);
   cfg.potential_correction_min_fib_level = (MohyPotentialCorrectionMinFibLevel)c.min_fib_level;
   cfg.potential_correction_min_fib_trigger_mode = (MohyLevelTriggerMode)c.min_fib_trigger_mode;
   cfg.potential_correction_max_fib_level = (MohyPotentialCorrectionMaxFibLevel)c.max_fib_level;
   cfg.potential_correction_max_fib_trigger_mode = (MohyLevelTriggerMode)c.max_fib_trigger_mode;
   cfg.potential_correction_extreme_touch_epsilon_points = MathMax(0.0, c.extreme_touch_epsilon_points);
   cfg.potential_correction_extreme_touch_min_count = MathMax(1, c.extreme_touch_min_count);
   cfg.potential_correction_supersede_direction_mode = (MohyPotentialCorrectionSupersedeDirectionMode)c.supersede_direction_mode;
   cfg.potential_correction_supersede_scope = (MohyPotentialCorrectionSupersedeScope)c.supersede_scope;

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
   out_result.min_opposite_ici_count = c.min_opposite_ici_count;
   out_result.min_fib_level = c.min_fib_level;
   out_result.min_fib_trigger_mode = c.min_fib_trigger_mode;
   out_result.max_fib_level = c.max_fib_level;
   out_result.max_fib_trigger_mode = c.max_fib_trigger_mode;
   out_result.extreme_touch_epsilon_points = c.extreme_touch_epsilon_points;
   out_result.extreme_touch_min_count = c.extreme_touch_min_count;
   out_result.supersede_direction_mode = c.supersede_direction_mode;
   out_result.supersede_scope = c.supersede_scope;
   out_result.fib_range_valid = MohyIsPotentialCorrectionFibRangeValid((MohyPotentialCorrectionMinFibLevel)c.min_fib_level,
                                                                        (MohyPotentialCorrectionMaxFibLevel)c.max_fib_level);
   out_result.config_hash = HashHex(BuildCaseConfigSignature(c));
   out_result.selection_count = 0;
   out_result.confirmed_count = 0;
   out_result.forming_count = 0;
   out_result.invalidated_count = 0;
   out_result.invalidated_max_fib_count = 0;
   out_result.invalidated_double_extreme_count = 0;
   out_result.invalidated_supersede_count = 0;
   out_result.active_count = 0;
   out_result.invariant_violation_count = 0;
   out_result.invariant_sample = "";

   string selection_signature = "";
   string full_signature = "";
   int recency_ranks[];

   const int correction_count = ArraySize(snapshot.potential_corrections);
   for(int i = 0; i < correction_count; ++i)
     {
      const MohyPotentialCorrectionFact fact = snapshot.potential_corrections[i];
      if(!fact.valid)
         continue;

      const int rank_size = ArraySize(recency_ranks);
      ArrayResize(recency_ranks, rank_size + 1);
      recency_ranks[rank_size] = fact.recency_rank;

      out_result.selection_count++;
      if(fact.is_active)
         out_result.active_count++;

      if(fact.state == MOHY_POT_CORR_STATE_FORMING)
         out_result.forming_count++;
      else if(fact.state == MOHY_POT_CORR_STATE_CONFIRMED)
         out_result.confirmed_count++;
      else if(fact.state == MOHY_POT_CORR_STATE_INVALIDATED)
         out_result.invalidated_count++;

      if(fact.termination_reason == MOHY_POT_CORR_TERM_MAX_FIB_INVALIDATED)
         out_result.invalidated_max_fib_count++;
      if(fact.termination_reason == MOHY_POT_CORR_TERM_DOUBLE_EXTREME_INVALIDATED)
         out_result.invalidated_double_extreme_count++;
      if(fact.termination_reason == MOHY_POT_CORR_TERM_SUPERSEDED_BY_NEW_HTF_SWING)
         out_result.invalidated_supersede_count++;

      if(fact.state == MOHY_POT_CORR_STATE_CONFIRMED &&
         (!fact.min_fib_gate_pass || !fact.opposite_ici_gate_pass))
         NoteInvariantViolation(out_result.invariant_violation_count,
                                out_result.invariant_sample,
                                StringFormat("case=%d confirmed-gates=min:%d opp:%d",
                                             case_index,
                                             ToInt(fact.min_fib_gate_pass),
                                             ToInt(fact.opposite_ici_gate_pass)));

      if(fact.state == MOHY_POT_CORR_STATE_FORMING && fact.termination_reason != MOHY_POT_CORR_TERM_NONE)
         NoteInvariantViolation(out_result.invariant_violation_count,
                                out_result.invariant_sample,
                                StringFormat("case=%d forming-term=%d", case_index, (int)fact.termination_reason));

      if(fact.min_fib_level + 1e-10 >= fact.max_fib_level)
         NoteInvariantViolation(out_result.invariant_violation_count,
                                out_result.invariant_sample,
                                StringFormat("case=%d fib-range min=%.6f max=%.6f",
                                             case_index,
                                             fact.min_fib_level,
                                             fact.max_fib_level));

      if(fact.reference_begin_shift != fact.begin_shift ||
         fact.reference_begin_time != fact.begin_time ||
         !NearlyEqual(fact.reference_begin_price, fact.begin_price))
         NoteInvariantViolation(out_result.invariant_violation_count,
                                out_result.invariant_sample,
                                StringFormat("case=%d ref-begin-mismatch begin=%d/%I64d/%.8f ref=%d/%I64d/%.8f",
                                             case_index,
                                             fact.begin_shift,
                                             fact.begin_time,
                                             fact.begin_price,
                                             fact.reference_begin_shift,
                                             fact.reference_begin_time,
                                             fact.reference_begin_price));

      if(fact.visual_begin_shift < 0 ||
         fact.visual_begin_time <= 0 ||
         fact.visual_begin_price <= 0.0 ||
         !NearlyEqual(fact.visual_begin_price, fact.impulse_extreme_price))
         NoteInvariantViolation(out_result.invariant_violation_count,
                                out_result.invariant_sample,
                                StringFormat("case=%d visual-begin-invalid vis=%d/%I64d/%.8f impulseExtreme=%.8f",
                                             case_index,
                                             fact.visual_begin_shift,
                                             fact.visual_begin_time,
                                             fact.visual_begin_price,
                                             fact.impulse_extreme_price));

      if(fact.visual_begin_shift != fact.reference_begin_shift ||
         fact.visual_begin_time != fact.reference_begin_time ||
         !NearlyEqual(fact.visual_begin_price, fact.reference_begin_price))
         NoteInvariantViolation(out_result.invariant_violation_count,
                                out_result.invariant_sample,
                                StringFormat("case=%d visual-ref-begin-mismatch vis=%d/%I64d/%.8f ref=%d/%I64d/%.8f",
                                             case_index,
                                             fact.visual_begin_shift,
                                             fact.visual_begin_time,
                                             fact.visual_begin_price,
                                             fact.reference_begin_shift,
                                             fact.reference_begin_time,
                                             fact.reference_begin_price));

      selection_signature += StringFormat("%d|%d|%d|%d|%d|%d|%d|%d;",
                                          fact.linked_potential_impulse_index,
                                          (int)fact.impulse_direction,
                                          (int)fact.state,
                                          (int)fact.termination_reason,
                                          fact.begin_shift,
                                          fact.end_shift,
                                          fact.recency_rank,
                                          ToInt(fact.is_active));

      if(compute_full_hash)
         full_signature += StringFormat("%d|%d|%d|%d|%d|%d|%d|%I64d|%d|%I64d|%s|%s|%d|%I64d|%d|%I64d|%d|%d|%d|%d|%d|%d|%I64d|%s|%d|%I64d|%s;",
                                        fact.linked_potential_impulse_index,
                                        fact.linked_potential_impulse_swing3_index,
                                        (int)fact.impulse_direction,
                                        (int)fact.state,
                                        (int)fact.termination_reason,
                                        ToInt(fact.confirmed),
                                        fact.begin_shift,
                                        fact.begin_time,
                                        fact.end_shift,
                                        fact.end_time,
                                        DoubleToString(fact.retrace_depth, 8),
                                        DoubleToString(fact.impulse_extreme_price, 8),
                                        fact.confirmed_shift,
                                        fact.confirmed_time,
                                        fact.invalidated_shift,
                                        fact.invalidated_time,
                                        fact.opposite_ici_count,
                                        fact.min_opposite_ici_count,
                                        fact.recency_rank,
                                        fact.timeline_full.extreme_shift,
                                        fact.timeline_trimmed.extreme_shift,
                                        fact.reference_begin_shift,
                                        fact.reference_begin_time,
                                        DoubleToString(fact.reference_begin_price, 8),
                                        fact.visual_begin_shift,
                                        fact.visual_begin_time,
                                        DoubleToString(fact.visual_begin_price, 8));
     }

   if(out_result.selection_count > 0 && out_result.active_count != 1)
      NoteInvariantViolation(out_result.invariant_violation_count,
                             out_result.invariant_sample,
                             StringFormat("case=%d active-count=%d", case_index, out_result.active_count));

   if(out_result.selection_count !=
      out_result.confirmed_count + out_result.forming_count + out_result.invalidated_count)
      NoteInvariantViolation(out_result.invariant_violation_count,
                             out_result.invariant_sample,
                             StringFormat("case=%d state-count-mismatch=%d/%d/%d/%d",
                                          case_index,
                                          out_result.selection_count,
                                          out_result.confirmed_count,
                                          out_result.forming_count,
                                          out_result.invalidated_count));

   if(selection_signature == "")
      selection_signature = "EMPTY";
   if(!compute_full_hash)
      full_signature = "FULL_HASH_DISABLED";
   else if(full_signature == "")
      full_signature = "EMPTY";

   out_result.selection_hash = HashHex(selection_signature);
   out_result.full_hash = HashHex(full_signature);
   return true;
  }

void AppendAssertion(MohyPcAssertionRow &io_rows[],
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

void EvaluateAssertions(const MohyPcMatrixResult &results[],
                        MohyPcAssertionRow &out_assertions[])
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

   int v_invalid_fib = 0;
   string s_invalid_fib = "";
   for(int i = 0; i < n; ++i)
     {
      if(results[i].fib_range_valid)
         continue;
      if(results[i].selection_count != 0)
        {
         v_invalid_fib++;
         if(s_invalid_fib == "")
            s_invalid_fib = StringFormat("case=%d count=%d minFib=%d maxFib=%d",
                                         results[i].case_index,
                                         results[i].selection_count,
                                         results[i].min_fib_level,
                                         results[i].max_fib_level);
        }
     }
   AppendAssertion(out_assertions,
                   "INVALID_FIB_RANGE_EMPTY",
                   (v_invalid_fib == 0),
                   v_invalid_fib,
                   s_invalid_fib);

   int v_selection_stable = 0;
   string s_selection_stable = "";
   int baseline_count = -1;
   int baseline_case = -1;
   for(int i = 0; i < n; ++i)
     {
      if(!results[i].enable || !results[i].fib_range_valid)
         continue;

      if(baseline_count < 0)
        {
         baseline_count = results[i].selection_count;
         baseline_case = results[i].case_index;
         continue;
        }

      if(results[i].selection_count != baseline_count)
        {
         v_selection_stable++;
         if(s_selection_stable == "")
            s_selection_stable = StringFormat("baseCase=%d baseCount=%d compareCase=%d compareCount=%d",
                                              baseline_case,
                                              baseline_count,
                                              results[i].case_index,
                                              results[i].selection_count);
        }
     }
   AppendAssertion(out_assertions,
                   "SELECTION_COUNT_STABLE_WHEN_ENABLED_VALID_FIB",
                   (v_selection_stable == 0),
                   v_selection_stable,
                   s_selection_stable);

   int v_invariants = 0;
   string s_invariants = "";
   for(int i = 0; i < n; ++i)
     {
      if(results[i].invariant_violation_count <= 0)
         continue;
      v_invariants += results[i].invariant_violation_count;
      if(s_invariants == "")
         s_invariants = StringFormat("case=%d violations=%d sample=%s",
                                     results[i].case_index,
                                     results[i].invariant_violation_count,
                                     results[i].invariant_sample);
     }
   AppendAssertion(out_assertions,
                   "FACT_INVARIANTS",
                   (v_invariants == 0),
                   v_invariants,
                   s_invariants);

   int v_min_opp = 0;
   string s_min_opp = "";
   int v_min_fib_trigger = 0;
   string s_min_fib_trigger = "";
   int v_max_fib_trigger = 0;
   string s_max_fib_trigger = "";
   int v_sup_dir = 0;
   string s_sup_dir = "";
   int v_sup_scope = 0;
   string s_sup_scope = "";

   for(int i = 0; i < n; ++i)
     {
      if(!results[i].enable || !results[i].fib_range_valid)
         continue;
      for(int j = i + 1; j < n; ++j)
        {
         if(!results[j].enable || !results[j].fib_range_valid)
            continue;

         const bool same_except_min_opp =
            (results[i].min_fib_level == results[j].min_fib_level &&
             results[i].min_fib_trigger_mode == results[j].min_fib_trigger_mode &&
             results[i].max_fib_level == results[j].max_fib_level &&
             results[i].max_fib_trigger_mode == results[j].max_fib_trigger_mode &&
             NearlyEqual(results[i].extreme_touch_epsilon_points, results[j].extreme_touch_epsilon_points) &&
             results[i].extreme_touch_min_count == results[j].extreme_touch_min_count &&
             results[i].supersede_direction_mode == results[j].supersede_direction_mode &&
             results[i].supersede_scope == results[j].supersede_scope);
         if(same_except_min_opp)
           {
            if(results[i].min_opposite_ici_count < results[j].min_opposite_ici_count &&
               results[j].confirmed_count > results[i].confirmed_count)
              {
               v_min_opp++;
               if(s_min_opp == "")
                  s_min_opp = StringFormat("case%d[minOpp=%d,confirmed=%d] -> case%d[minOpp=%d,confirmed=%d]",
                                           results[i].case_index,
                                           results[i].min_opposite_ici_count,
                                           results[i].confirmed_count,
                                           results[j].case_index,
                                           results[j].min_opposite_ici_count,
                                           results[j].confirmed_count);
              }
            if(results[j].min_opposite_ici_count < results[i].min_opposite_ici_count &&
               results[i].confirmed_count > results[j].confirmed_count)
              {
               v_min_opp++;
               if(s_min_opp == "")
                  s_min_opp = StringFormat("case%d[minOpp=%d,confirmed=%d] -> case%d[minOpp=%d,confirmed=%d]",
                                           results[j].case_index,
                                           results[j].min_opposite_ici_count,
                                           results[j].confirmed_count,
                                           results[i].case_index,
                                           results[i].min_opposite_ici_count,
                                           results[i].confirmed_count);
              }
           }

         const bool same_except_min_trigger =
            (results[i].min_opposite_ici_count == results[j].min_opposite_ici_count &&
             results[i].min_fib_level == results[j].min_fib_level &&
             results[i].max_fib_level == results[j].max_fib_level &&
             results[i].max_fib_trigger_mode == results[j].max_fib_trigger_mode &&
             NearlyEqual(results[i].extreme_touch_epsilon_points, results[j].extreme_touch_epsilon_points) &&
             results[i].extreme_touch_min_count == results[j].extreme_touch_min_count &&
             results[i].supersede_direction_mode == results[j].supersede_direction_mode &&
             results[i].supersede_scope == results[j].supersede_scope);
         if(same_except_min_trigger)
           {
            const bool i_touch = (results[i].min_fib_trigger_mode == (int)MOHY_LEVEL_TRIGGER_TOUCH);
            const bool j_touch = (results[j].min_fib_trigger_mode == (int)MOHY_LEVEL_TRIGGER_TOUCH);
            if(i_touch != j_touch)
              {
               const int touch_confirmed = i_touch ? results[i].confirmed_count : results[j].confirmed_count;
               const int close_confirmed = i_touch ? results[j].confirmed_count : results[i].confirmed_count;
               if(close_confirmed > touch_confirmed)
                 {
                  v_min_fib_trigger++;
                  if(s_min_fib_trigger == "")
                     s_min_fib_trigger = StringFormat("touchCase=%d closeCase=%d touchConfirmed=%d closeConfirmed=%d",
                                                      i_touch ? results[i].case_index : results[j].case_index,
                                                      i_touch ? results[j].case_index : results[i].case_index,
                                                      touch_confirmed,
                                                      close_confirmed);
                 }
              }
           }

         const bool same_except_max_trigger =
            (results[i].min_opposite_ici_count == results[j].min_opposite_ici_count &&
             results[i].min_fib_level == results[j].min_fib_level &&
             results[i].min_fib_trigger_mode == results[j].min_fib_trigger_mode &&
             results[i].max_fib_level == results[j].max_fib_level &&
             NearlyEqual(results[i].extreme_touch_epsilon_points, results[j].extreme_touch_epsilon_points) &&
             results[i].extreme_touch_min_count == results[j].extreme_touch_min_count &&
             results[i].supersede_direction_mode == results[j].supersede_direction_mode &&
             results[i].supersede_scope == results[j].supersede_scope);
         if(same_except_max_trigger)
           {
            const bool i_touch = (results[i].max_fib_trigger_mode == (int)MOHY_LEVEL_TRIGGER_TOUCH);
            const bool j_touch = (results[j].max_fib_trigger_mode == (int)MOHY_LEVEL_TRIGGER_TOUCH);
            if(i_touch != j_touch)
              {
               const int touch_invalidated = i_touch ? results[i].invalidated_max_fib_count : results[j].invalidated_max_fib_count;
               const int close_invalidated = i_touch ? results[j].invalidated_max_fib_count : results[i].invalidated_max_fib_count;
               if(close_invalidated > touch_invalidated)
                 {
                  v_max_fib_trigger++;
                  if(s_max_fib_trigger == "")
                     s_max_fib_trigger = StringFormat("touchCase=%d closeCase=%d touchMaxInv=%d closeMaxInv=%d",
                                                      i_touch ? results[i].case_index : results[j].case_index,
                                                      i_touch ? results[j].case_index : results[i].case_index,
                                                      touch_invalidated,
                                                      close_invalidated);
                 }
              }
           }

         const bool same_except_sup_dir =
            (results[i].min_opposite_ici_count == results[j].min_opposite_ici_count &&
             results[i].min_fib_level == results[j].min_fib_level &&
             results[i].min_fib_trigger_mode == results[j].min_fib_trigger_mode &&
             results[i].max_fib_level == results[j].max_fib_level &&
             results[i].max_fib_trigger_mode == results[j].max_fib_trigger_mode &&
             NearlyEqual(results[i].extreme_touch_epsilon_points, results[j].extreme_touch_epsilon_points) &&
             results[i].extreme_touch_min_count == results[j].extreme_touch_min_count &&
             results[i].supersede_scope == results[j].supersede_scope);
         if(same_except_sup_dir)
           {
            const bool i_any = (results[i].supersede_direction_mode == (int)MOHY_POT_CORR_SUPERSEDE_DIR_ANY);
            const bool j_any = (results[j].supersede_direction_mode == (int)MOHY_POT_CORR_SUPERSEDE_DIR_ANY);
            if(i_any != j_any)
              {
               const int any_sup = i_any ? results[i].invalidated_supersede_count : results[j].invalidated_supersede_count;
               const int opp_sup = i_any ? results[j].invalidated_supersede_count : results[i].invalidated_supersede_count;
               if(any_sup < opp_sup)
                 {
                  v_sup_dir++;
                  if(s_sup_dir == "")
                     s_sup_dir = StringFormat("anyCase=%d oppCase=%d anySup=%d oppSup=%d",
                                              i_any ? results[i].case_index : results[j].case_index,
                                              i_any ? results[j].case_index : results[i].case_index,
                                              any_sup,
                                              opp_sup);
                 }
              }
           }

         const bool same_except_sup_scope =
            (results[i].min_opposite_ici_count == results[j].min_opposite_ici_count &&
             results[i].min_fib_level == results[j].min_fib_level &&
             results[i].min_fib_trigger_mode == results[j].min_fib_trigger_mode &&
             results[i].max_fib_level == results[j].max_fib_level &&
             results[i].max_fib_trigger_mode == results[j].max_fib_trigger_mode &&
             NearlyEqual(results[i].extreme_touch_epsilon_points, results[j].extreme_touch_epsilon_points) &&
             results[i].extreme_touch_min_count == results[j].extreme_touch_min_count &&
             results[i].supersede_direction_mode == results[j].supersede_direction_mode);
         if(same_except_sup_scope)
           {
            const bool i_forming_only = (results[i].supersede_scope == (int)MOHY_POT_CORR_SUPERSEDE_SCOPE_FORMING_ONLY);
            const bool j_forming_only = (results[j].supersede_scope == (int)MOHY_POT_CORR_SUPERSEDE_SCOPE_FORMING_ONLY);
            if(i_forming_only != j_forming_only)
              {
               const int forming_only_sup = i_forming_only ? results[i].invalidated_supersede_count : results[j].invalidated_supersede_count;
               const int forming_and_sup = i_forming_only ? results[j].invalidated_supersede_count : results[i].invalidated_supersede_count;
               if(forming_and_sup < forming_only_sup)
                 {
                  v_sup_scope++;
                  if(s_sup_scope == "")
                     s_sup_scope = StringFormat("formingOnlyCase=%d formingAndCase=%d formingOnlySup=%d formingAndSup=%d",
                                                i_forming_only ? results[i].case_index : results[j].case_index,
                                                i_forming_only ? results[j].case_index : results[i].case_index,
                                                forming_only_sup,
                                                forming_and_sup);
                 }
              }
           }
        }
     }

   AppendAssertion(out_assertions,
                   "MIN_OPPOSITE_ICI_MONOTONIC_CONFIRMED",
                   (v_min_opp == 0),
                   v_min_opp,
                   s_min_opp);
   AppendAssertion(out_assertions,
                   "MIN_FIB_CLOSE_STRICTER_THAN_TOUCH",
                   (v_min_fib_trigger == 0),
                   v_min_fib_trigger,
                   s_min_fib_trigger);
   AppendAssertion(out_assertions,
                   "MAX_FIB_CLOSE_LOOSER_THAN_TOUCH",
                   (v_max_fib_trigger == 0),
                   v_max_fib_trigger,
                   s_max_fib_trigger);
   AppendAssertion(out_assertions,
                   "SUPERSEDE_DIRECTION_ANY_SUPERSET",
                   (v_sup_dir == 0),
                   v_sup_dir,
                   s_sup_dir);
   AppendAssertion(out_assertions,
                   "SUPERSEDE_SCOPE_FORMING_AND_CONFIRMED_SUPERSET",
                   (v_sup_scope == 0),
                   v_sup_scope,
                   s_sup_scope);
  }

bool WriteMatrixCsv(const string path,
                    const string run_id,
                    const string symbol,
                    const int source_timeframe,
                    const int context_timeframe,
                    const int execution_timeframe,
                    const bool include_provisional_latest,
                    const bool append_existing,
                    const MohyPcMatrixResult &results[])
  {
   bool write_header = true;
   int flags = FILE_CSV | FILE_ANSI;
   if(append_existing && FileIsExist(path))
     {
      flags |= FILE_READ | FILE_WRITE;
      write_header = false;
     }
   else
      flags |= FILE_WRITE;

   const int handle = FileOpen(path, flags, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("MOHY | PC_MATRIX | Failed to open matrix CSV: %s (err=%d)", path, GetLastError());
      return false;
     }

   if(!write_header)
      FileSeek(handle, 0, SEEK_END);
   else
      FileWrite(handle,
                "run_id",
                "symbol",
                "source_timeframe",
                "context_timeframe",
                "execution_timeframe",
                "include_provisional_latest",
                "case_index",
                "enable",
                "min_opposite_ici_count",
                "min_fib_level",
                "min_fib_trigger_mode",
                "max_fib_level",
                "max_fib_trigger_mode",
                "extreme_touch_epsilon_points",
                "extreme_touch_min_count",
                "supersede_direction_mode",
                "supersede_scope",
                "fib_range_valid",
                "config_hash",
                "selection_count",
                "confirmed_count",
                "forming_count",
                "invalidated_count",
                "invalidated_max_fib_count",
                "invalidated_double_extreme_count",
                "invalidated_supersede_count",
                "active_count",
                "invariant_violation_count",
                "invariant_sample",
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
                results[i].min_opposite_ici_count,
                results[i].min_fib_level,
                results[i].min_fib_trigger_mode,
                results[i].max_fib_level,
                results[i].max_fib_trigger_mode,
                DoubleToString(results[i].extreme_touch_epsilon_points, 10),
                results[i].extreme_touch_min_count,
                results[i].supersede_direction_mode,
                results[i].supersede_scope,
                ToInt(results[i].fib_range_valid),
                results[i].config_hash,
                results[i].selection_count,
                results[i].confirmed_count,
                results[i].forming_count,
                results[i].invalidated_count,
                results[i].invalidated_max_fib_count,
                results[i].invalidated_double_extreme_count,
                results[i].invalidated_supersede_count,
                results[i].active_count,
                results[i].invariant_violation_count,
                results[i].invariant_sample,
                results[i].selection_hash,
                results[i].full_hash);
     }

   FileClose(handle);
   return true;
  }
bool WriteAssertionsCsv(const string path,
                        const string run_id,
                        const MohyPcAssertionRow &assertions[])
  {
   const int handle = FileOpen(path, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("MOHY | PC_MATRIX | Failed to open assertions CSV: %s (err=%d)", path, GetLastError());
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
      PrintFormat("MOHY | PC_MATRIX | SymbolSelect failed for '%s'", symbol);
      return;
     }

   if(!MohyValidateTimeframePair(context_timeframe, execution_timeframe))
     {
      PrintFormat("MOHY | PC_MATRIX | Invalid timeframe pair HTF=%s LTF=%s",
                  MohyTimeframeToString(context_timeframe),
                  MohyTimeframeToString(execution_timeframe));
      return;
     }

   if(source_timeframe <= 0)
     {
      Print("MOHY | PC_MATRIX | Invalid source timeframe.");
      return;
     }

   if(source_timeframe != execution_timeframe)
     {
      PrintFormat("MOHY | PC_MATRIX | Source timeframe must equal LTF for correction build. source=%s LTF=%s",
                  MohyTimeframeToString(source_timeframe),
                  MohyTimeframeToString(execution_timeframe));
      return;
     }

   MohyPcMatrixCase cases[];
   BuildMatrixCases(VerificationMatrixProfile,
                    MathMax(0, VerificationMaxCases),
                    cases);
   const int total_case_count = ArraySize(cases);
   if(total_case_count <= 0)
     {
      Print("MOHY | PC_MATRIX | No matrix cases generated.");
      return;
     }

   const int start_index = MathMax(0, VerificationCaseStartIndex);
   if(start_index >= total_case_count)
     {
      PrintFormat("MOHY | PC_MATRIX | VerificationCaseStartIndex out of range: %d (total=%d)",
                  start_index,
                  total_case_count);
      return;
     }

   int selected_case_count = total_case_count - start_index;
   if(VerificationCaseCount > 0)
      selected_case_count = MathMin(selected_case_count, VerificationCaseCount);
   if(selected_case_count <= 0)
     {
      Print("MOHY | PC_MATRIX | Selected case range is empty.");
      return;
     }
   const int end_index = start_index + selected_case_count - 1;
   const bool full_range = (start_index == 0 && selected_case_count == total_case_count);

   string run_id = TrimText(VerificationRunId);
   if(run_id == "")
     {
      run_id = StringFormat("PC_MATRIX_%s_%s_%s",
                            symbol,
                            MohyTimeframeToString(source_timeframe),
                            BuildTimestampToken(TimeCurrent()));
      }
   run_id = SanitizeToken(run_id);

   PrintFormat("MOHY | PC_MATRIX | Starting run_id=%s symbol=%s source_tf=%s HTF/LTF=%s/%s profile=%d range=%d..%d selected=%d/%d append=%s fullHash=%s",
               run_id,
               symbol,
               MohyTimeframeToString(source_timeframe),
               MohyTimeframeToString(context_timeframe),
               MohyTimeframeToString(execution_timeframe),
               (int)VerificationMatrixProfile,
               start_index,
               end_index,
               selected_case_count,
               total_case_count,
               VerificationAppendDetailsCsv ? "true" : "false",
               VerificationComputeFullHash ? "true" : "false");

   MohyPcMatrixResult results[];
   ArrayResize(results, selected_case_count);
   bool failed = false;
   string failed_message = "";
   for(int i = 0; i < selected_case_count; ++i)
     {
      const int case_index = start_index + i;
      string eval_error = "";
      if(!EvaluateSingleCase(symbol,
                             source_timeframe,
                             context_timeframe,
                             execution_timeframe,
                             MathMax(100, VerificationLookbackBars),
                             effective_include_provisional_latest,
                             VerificationComputeFullHash,
                             case_index,
                             cases[case_index],
                             results[i],
                             eval_error))
        {
         failed = true;
         failed_message = StringFormat("Case %d failed: %s", case_index, eval_error);
         break;
        }

      if(((i + 1) % 250) == 0 || (i + 1) == selected_case_count)
         PrintFormat("MOHY | PC_MATRIX | Progress %d/%d (absoluteCase=%d)",
                     i + 1,
                     selected_case_count,
                     case_index);
     }

   if(failed)
     {
      PrintFormat("MOHY | PC_MATRIX | %s", failed_message);
      return;
     }

   MohyPcAssertionRow assertions[];
   const bool should_write_assertions = (VerificationWriteAssertionsCsv &&
                                         !VerificationSkipAssertions &&
                                         full_range &&
                                         !VerificationAppendDetailsCsv);
   if(VerificationWriteAssertionsCsv && !should_write_assertions)
      Print("MOHY | PC_MATRIX | Assertions output skipped. Requires full non-appended range with VerificationSkipAssertions=false.");

   if(should_write_assertions)
      EvaluateAssertions(results, assertions);
   else
      ArrayResize(assertions, 0);

   int assertion_fail_count = 0;
   for(int i = 0; i < ArraySize(assertions); ++i)
     {
      if(!assertions[i].pass)
         assertion_fail_count++;
     }

   string matrix_path = "";
   string assertions_path = "";
   if(VerificationWriteDetailsCsv || should_write_assertions)
     {
      const string out_dir = NormalizeDirectoryPath(VerificationOutputDirectory);
      if(!EnsureOutputDirectory(out_dir))
        {
         PrintFormat("MOHY | PC_MATRIX | Failed to ensure output directory: %s", out_dir);
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
                         VerificationAppendDetailsCsv,
                         results))
         return;
     }

   if(should_write_assertions)
     {
      if(!WriteAssertionsCsv(assertions_path,
                             run_id,
                             assertions))
         return;
     }

   for(int i = 0; i < ArraySize(assertions); ++i)
     {
      PrintFormat("MOHY | PC_MATRIX | Assertion %s pass=%s violations=%d sample=%s",
                  assertions[i].rule_id,
                  assertions[i].pass ? "true" : "false",
                  assertions[i].violation_count,
                  assertions[i].sample);
     }

   PrintFormat("MOHY | PC_MATRIX | Completed run_id=%s cases=%d assertion_failures=%d matrix_csv=%s assertions_csv=%s",
               run_id,
               selected_case_count,
               assertion_fail_count,
               matrix_path,
               assertions_path);
  }
