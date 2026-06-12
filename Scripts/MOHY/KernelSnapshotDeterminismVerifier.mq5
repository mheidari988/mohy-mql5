#property strict
#property script_show_inputs

#include <MOHY/Domain/Config.mqh>
#include <MOHY/Core/PriceActionKernel.mqh>

input string VerificationRunId = "";
input string VerificationSymbol = "";
input ENUM_TIMEFRAMES VerificationSourceTimeframe = PERIOD_H1;
input ENUM_TIMEFRAMES VerificationHTF = PERIOD_H1;
input ENUM_TIMEFRAMES VerificationLTF = PERIOD_M15;
input int VerificationLookbackBars = 1600;
input int VerificationReplayPasses = 2;
input string VerificationOutputDirectory = "MOHY\\verification\\kernel_snapshot";
input bool VerificationWriteDetailsCsv = true;
input bool VerificationWriteAssertionsCsv = true;

struct MohyKsPassResult
  {
   int    pass_index;
   string config_hash;
   int    from_shift;
   int    max_shift;
   int    elements_count;
   string elements_hash;
   int    legs_count;
   string legs_hash;
   int    swings3_count;
   string swings3_hash;
   int    potential_impulses_count;
   string potential_impulses_hash;
   int    potential_corrections_count;
   string potential_corrections_hash;
   int    potential_continuation_signals_count;
   string potential_continuation_signals_hash;
   int    trade_setup_plans_count;
   string trade_setup_plans_hash;
   int    historical_trade_setups_count;
   string historical_trade_setups_hash;
   string combined_hash;
  };

struct MohyKsAssertionRow
  {
   string rule_id;
   bool   pass;
   int    violation_count;
   string sample;
  };

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
      acc = (acc == "") ? part : (acc + "\\" + part);
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
      const bool ok = ((ch >= '0' && ch <= '9') ||
                       (ch >= 'a' && ch <= 'z') ||
                       (ch >= 'A' && ch <= 'Z') ||
                       ch == '_' || ch == '-');
      out += ok ? StringSubstr(value, i, 1) : "_";
     }
   out = TrimText(out);
   return (out == "") ? "NA" : out;
  }

string BuildTimestampToken(const datetime t)
  {
   string out = TimeToString(t, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
   StringReplace(out, ".", "");
   StringReplace(out, ":", "");
   StringReplace(out, " ", "_");
   return out;
  }

uint HashBegin()
  {
   return 2166136261;
  }

uint HashUpdate(uint hash,
                const string text)
  {
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

string HashHex(const uint hash)
  {
   return StringFormat("%08X", (int)hash);
  }

string BuildConfigSignature(const StrategyConfig &cfg,
                            const int source_timeframe,
                            const int context_timeframe,
                            const int execution_timeframe,
                            const int lookback_bars)
  {
   return StringFormat("source=%d|ctx=%d|exe=%d|look=%d|left=%d|right=%d|pi=%d|pc=%d|sl=%d|tp=%d|minRR=%s|targetRR=%s|exec=%d|recheck=%d",
                       source_timeframe,
                       context_timeframe,
                       execution_timeframe,
                       lookback_bars,
                       cfg.detection.swing_left_bars,
                       cfg.detection.swing_right_bars,
                       cfg.detection.enable_potential_impulse ? 1 : 0,
                       cfg.detection.enable_potential_correction ? 1 : 0,
                       (int)cfg.sl_mode,
                       (int)cfg.tp_mode,
                       DoubleToString(cfg.entry.min_rr, 10),
                       DoubleToString(cfg.target_rr, 10),
                       (int)cfg.entry.execution_mode,
                       (int)cfg.entry.recheck_mode);
  }

string FingerprintElements(const MohyElementFact &facts[])
  {
   uint hash = HashBegin();
   for(int i = 0; i < ArraySize(facts); ++i)
      hash = HashUpdate(hash,
                        StringFormat("%d|%d|%I64d|%d|%d|%s|%d|%d;",
                                     facts[i].index,
                                     facts[i].shift,
                                     facts[i].time,
                                     (int)facts[i].type,
                                     facts[i].confirmed ? 1 : 0,
                                     DoubleToString(facts[i].pivot_price, 10),
                                     facts[i].dual_pivot ? 1 : 0,
                                     facts[i].dual_order));
   return HashHex(hash);
  }

string FingerprintLegs(const MohyLegFact &facts[])
  {
   uint hash = HashBegin();
   for(int i = 0; i < ArraySize(facts); ++i)
      hash = HashUpdate(hash,
                        StringFormat("%d|%d|%d|%d|%d|%d|%d|%s;",
                                     facts[i].index,
                                     facts[i].begin_element_index,
                                     facts[i].end_element_index,
                                     (int)facts[i].type,
                                     (int)facts[i].direction,
                                     facts[i].begin_shift,
                                     facts[i].end_shift,
                                     DoubleToString(facts[i].end_price, 10)));
   return HashHex(hash);
  }

string FingerprintSwings3(const MohySwing3Fact &facts[])
  {
   uint hash = HashBegin();
   for(int i = 0; i < ArraySize(facts); ++i)
      hash = HashUpdate(hash,
                        StringFormat("%d|%d|%d|%d|%d|%d|%d|%d|%d;",
                                     facts[i].index,
                                     facts[i].leg1_index,
                                     facts[i].leg2_index,
                                     facts[i].leg3_index,
                                     (int)facts[i].direction,
                                     facts[i].confirmed ? 1 : 0,
                                     (int)facts[i].pattern_type,
                                     (int)facts[i].break_state,
                                     facts[i].breakout_close_count));
   return HashHex(hash);
  }

string FingerprintPotentialImpulses(const MohyPotentialImpulseFact &facts[])
  {
   uint hash = HashBegin();
   for(int i = 0; i < ArraySize(facts); ++i)
      hash = HashUpdate(hash,
                        StringFormat("%d|%d|%d|%d|%d|%d|%s|%s;",
                                     facts[i].index,
                                     facts[i].valid ? 1 : 0,
                                     facts[i].swing3_index,
                                     facts[i].leg_index,
                                     (int)facts[i].direction,
                                     (int)facts[i].break_state,
                                     DoubleToString(facts[i].begin_price, 10),
                                     DoubleToString(facts[i].end_price, 10)));
   return HashHex(hash);
  }

string FingerprintPotentialCorrections(const MohyPotentialCorrectionFact &facts[])
  {
   uint hash = HashBegin();
   for(int i = 0; i < ArraySize(facts); ++i)
      hash = HashUpdate(hash,
                        StringFormat("%d|%d|%d|%d|%d|%d|%d|%s|%s|%d|%d|%d;",
                                     facts[i].index,
                                     facts[i].valid ? 1 : 0,
                                     facts[i].linked_potential_impulse_index,
                                     facts[i].linked_potential_impulse_swing3_index,
                                     (int)facts[i].impulse_direction,
                                     (int)facts[i].state,
                                     facts[i].confirmed_shift,
                                     DoubleToString(facts[i].begin_price, 10),
                                     DoubleToString(facts[i].end_price, 10),
                                     facts[i].recency_rank,
                                     facts[i].is_active ? 1 : 0,
                                     facts[i].is_selected ? 1 : 0));
   return HashHex(hash);
  }

string FingerprintPotentialContinuationSignals(const MohyPotentialContinuationSignalFact &facts[])
  {
   uint hash = HashBegin();
   for(int i = 0; i < ArraySize(facts); ++i)
      hash = HashUpdate(hash,
                        StringFormat("%d|%d|%d|%d|%d|%d|%d|%s|%d|%d;",
                                     facts[i].index,
                                     facts[i].valid ? 1 : 0,
                                     facts[i].linked_potential_correction_index,
                                     facts[i].linked_potential_impulse_index,
                                     (int)facts[i].direction,
                                     facts[i].signal_shift,
                                     facts[i].broken_level_shift,
                                     DoubleToString(facts[i].broken_level_price, 10),
                                     facts[i].selection_rank,
                                     facts[i].is_selected ? 1 : 0));
   return HashHex(hash);
  }

string FingerprintTradeSetupPlans(const MohyTradeSetupPlanFact &facts[])
  {
   uint hash = HashBegin();
   for(int i = 0; i < ArraySize(facts); ++i)
      hash = HashUpdate(hash,
                        StringFormat("%d|%d|%d|%d|%d|%d|%d|%d|%d|%I64d|%d|%d|%d|%d|%d|%d|%d|%d|%s|%s|%s|%s|%s|%s|%s|%s|%s|%d|%d|%d|%s|%s|%s|%s|%d|%d;",
                                     facts[i].index,
                                     facts[i].valid ? 1 : 0,
                                     facts[i].linked_potential_continuation_signal_index,
                                     facts[i].linked_potential_correction_index,
                                     facts[i].linked_potential_impulse_index,
                                     facts[i].linked_potential_impulse_swing3_index,
                                     facts[i].linked_correction_recency_rank,
                                     facts[i].linked_correction_is_active ? 1 : 0,
                                     (int)facts[i].direction,
                                     (int)facts[i].plan_state,
                                     (int)facts[i].reject_reason,
                                     (int)facts[i].execution_mode,
                                     facts[i].setup_shift,
                                     (long)facts[i].setup_time,
                                     (int)facts[i].post_be_profile,
                                     (int)facts[i].trigger_touch_side,
                                     (int)facts[i].recheck_mode,
                                     (int)facts[i].adjust_cadence,
                                     facts[i].adjust_min_seconds,
                                     facts[i].recheck_rr_at_trigger ? 1 : 0,
                                     facts[i].trigger_freeze_enabled ? 1 : 0,
                                     facts[i].pending_auto_modify_enabled ? 1 : 0,
                                     DoubleToString(facts[i].current_executable_price, 10),
                                     DoubleToString(facts[i].proposed_entry_price, 10),
                                     DoubleToString(facts[i].expected_fill_price, 10),
                                     DoubleToString(facts[i].required_entry_price, 10),
                                     DoubleToString(facts[i].trigger_price, 10),
                                     DoubleToString(facts[i].stop_price, 10),
                                     DoubleToString(facts[i].target_price, 10),
                                     DoubleToString(facts[i].reward_to_risk, 10),
                                     DoubleToString(facts[i].spread_est_points, 10),
                                     DoubleToString(facts[i].slippage_est_points, 10),
                                     DoubleToString(facts[i].commission_est_points, 10),
                                     DoubleToString(facts[i].total_entry_cost_points, 10),
                                     DoubleToString(facts[i].min_trigger_move_points, 10),
                                     DoubleToString(facts[i].trigger_freeze_points, 10),
                                     DoubleToString(facts[i].risk_distance_points, 10),
                                     facts[i].selection_rank,
                                     facts[i].is_selected ? 1 : 0));
   return HashHex(hash);
  }

string FingerprintHistoricalTradeSetups(const MohyHistoricalTradeSetupFact &facts[])
  {
   uint hash = HashBegin();
   for(int i = 0; i < ArraySize(facts); ++i)
      hash = HashUpdate(hash,
                        StringFormat("%d|%d|%d|%d|%d|%d|%d|%d|%I64d|%d|%I64d|%s|%s|%s|%s|%s|%s;",
                                     facts[i].index,
                                     facts[i].valid ? 1 : 0,
                                     facts[i].linked_trade_setup_plan_index,
                                     facts[i].linked_potential_continuation_signal_index,
                                     facts[i].linked_potential_correction_index,
                                     facts[i].linked_potential_impulse_index,
                                     (int)facts[i].initial_plan_state,
                                     (int)facts[i].outcome,
                                     facts[i].setup_shift,
                                     (long)facts[i].setup_time,
                                     facts[i].entry_shift,
                                     (long)facts[i].entry_time,
                                     DoubleToString(facts[i].planned_entry_price, 10),
                                     DoubleToString(facts[i].stop_price, 10),
                                     DoubleToString(facts[i].target_price, 10),
                                     DoubleToString(facts[i].entry_price, 10),
                                     DoubleToString(facts[i].exit_price, 10),
                                     facts[i].entered ? "1" : "0"));
   return HashHex(hash);
  }

bool EvaluateSinglePass(const string symbol,
                        const int source_timeframe,
                        const int context_timeframe,
                        const int execution_timeframe,
                        const int lookback_bars,
                        const int pass_index,
                        MohyKsPassResult &out_result,
                        string &out_error)
  {
   out_error = "";
   StrategyConfig cfg;
   MohySetDefaultStrategyConfig(cfg);

   CMohyPriceActionKernel kernel;
   kernel.Configure(cfg, source_timeframe, context_timeframe, execution_timeframe);

   CMohyPriceActionSnapshot snapshot;
   if(!kernel.BuildRecent(symbol, lookback_bars, snapshot, true))
     {
      out_error = StringFormat("BuildRecent failed symbol=%s tf=%s", symbol, MohyTimeframeToString(source_timeframe));
      return false;
     }

   out_result.pass_index = pass_index;
   out_result.config_hash = HashHex(HashUpdate(HashBegin(),
                                               BuildConfigSignature(cfg,
                                                                    source_timeframe,
                                                                    context_timeframe,
                                                                    execution_timeframe,
                                                                    lookback_bars)));
   out_result.from_shift = snapshot.from_shift;
   out_result.max_shift = snapshot.max_shift;
   out_result.elements_count = ArraySize(snapshot.elements);
   out_result.elements_hash = FingerprintElements(snapshot.elements);
   out_result.legs_count = ArraySize(snapshot.legs);
   out_result.legs_hash = FingerprintLegs(snapshot.legs);
   out_result.swings3_count = ArraySize(snapshot.swings3);
   out_result.swings3_hash = FingerprintSwings3(snapshot.swings3);
   out_result.potential_impulses_count = ArraySize(snapshot.potential_impulses);
   out_result.potential_impulses_hash = FingerprintPotentialImpulses(snapshot.potential_impulses);
   out_result.potential_corrections_count = ArraySize(snapshot.potential_corrections);
   out_result.potential_corrections_hash = FingerprintPotentialCorrections(snapshot.potential_corrections);
   out_result.potential_continuation_signals_count = ArraySize(snapshot.potential_continuation_signals);
   out_result.potential_continuation_signals_hash = FingerprintPotentialContinuationSignals(snapshot.potential_continuation_signals);
   out_result.trade_setup_plans_count = ArraySize(snapshot.trade_setup_plans);
   out_result.trade_setup_plans_hash = FingerprintTradeSetupPlans(snapshot.trade_setup_plans);
   out_result.historical_trade_setups_count = ArraySize(snapshot.historical_trade_setups);
   out_result.historical_trade_setups_hash = FingerprintHistoricalTradeSetups(snapshot.historical_trade_setups);
   out_result.combined_hash = HashHex(HashUpdate(HashBegin(),
                                                 StringFormat("%s|%d|%d|%d|%d|%d|%d|%d|%s|%s|%s|%s|%s|%s|%s|%s|%s",
                                                              out_result.config_hash,
                                                              out_result.from_shift,
                                                              out_result.max_shift,
                                                              snapshot.timeframe,
                                                              snapshot.context_timeframe,
                                                              snapshot.execution_timeframe,
                                                              snapshot.source_is_context_timeframe ? 1 : 0,
                                                              snapshot.source_is_execution_timeframe ? 1 : 0,
                                                              snapshot.publishes_execution_stage_facts ? 1 : 0,
                                                              out_result.elements_hash,
                                                              out_result.legs_hash,
                                                              out_result.swings3_hash,
                                                              out_result.potential_impulses_hash,
                                                              out_result.potential_corrections_hash,
                                                              out_result.potential_continuation_signals_hash,
                                                              out_result.trade_setup_plans_hash,
                                                              out_result.historical_trade_setups_hash)));
   return true;
  }

void AppendAssertion(MohyKsAssertionRow &io_rows[],
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

void EvaluateAssertions(const MohyKsPassResult &results[],
                        MohyKsAssertionRow &out_assertions[])
  {
   ArrayResize(out_assertions, 0);
   const int n = ArraySize(results);
   if(n <= 1)
     {
      AppendAssertion(out_assertions, "SNAPSHOT_RANGE_STABLE", true, 0, "single-pass");
      AppendAssertion(out_assertions, "ELEMENT_HASH_STABLE", true, 0, "single-pass");
      AppendAssertion(out_assertions, "LEG_HASH_STABLE", true, 0, "single-pass");
      AppendAssertion(out_assertions, "SWING3_HASH_STABLE", true, 0, "single-pass");
      AppendAssertion(out_assertions, "POTENTIAL_IMPULSE_HASH_STABLE", true, 0, "single-pass");
      AppendAssertion(out_assertions, "POTENTIAL_CORRECTION_HASH_STABLE", true, 0, "single-pass");
      AppendAssertion(out_assertions, "CONTINUATION_HASH_STABLE", true, 0, "single-pass");
      AppendAssertion(out_assertions, "TRADE_SETUP_PLAN_HASH_STABLE", true, 0, "single-pass");
      AppendAssertion(out_assertions, "HISTORICAL_SETUP_HASH_STABLE", true, 0, "single-pass");
      AppendAssertion(out_assertions, "COMBINED_HASH_STABLE", true, 0, "single-pass");
      return;
     }

   const MohyKsPassResult base = results[0];
   int v_range = 0; string s_range = "";
   int v_elements = 0; string s_elements = "";
   int v_legs = 0; string s_legs = "";
   int v_swings3 = 0; string s_swings3 = "";
   int v_impulses = 0; string s_impulses = "";
   int v_corrections = 0; string s_corrections = "";
   int v_continuations = 0; string s_continuations = "";
   int v_plans = 0; string s_plans = "";
   int v_history = 0; string s_history = "";
   int v_combined = 0; string s_combined = "";

   for(int i = 1; i < n; ++i)
     {
      if(results[i].from_shift != base.from_shift || results[i].max_shift != base.max_shift)
        {
         v_range++;
         if(s_range == "")
            s_range = StringFormat("pass0=%d..%d pass%d=%d..%d",
                                   base.from_shift,
                                   base.max_shift,
                                   results[i].pass_index,
                                   results[i].from_shift,
                                   results[i].max_shift);
        }
      if(results[i].elements_hash != base.elements_hash)
        {
         v_elements++;
         if(s_elements == "")
            s_elements = StringFormat("pass0=%s pass%d=%s", base.elements_hash, results[i].pass_index, results[i].elements_hash);
        }
      if(results[i].legs_hash != base.legs_hash)
        {
         v_legs++;
         if(s_legs == "")
            s_legs = StringFormat("pass0=%s pass%d=%s", base.legs_hash, results[i].pass_index, results[i].legs_hash);
        }
      if(results[i].swings3_hash != base.swings3_hash)
        {
         v_swings3++;
         if(s_swings3 == "")
            s_swings3 = StringFormat("pass0=%s pass%d=%s", base.swings3_hash, results[i].pass_index, results[i].swings3_hash);
        }
      if(results[i].potential_impulses_hash != base.potential_impulses_hash)
        {
         v_impulses++;
         if(s_impulses == "")
            s_impulses = StringFormat("pass0=%s pass%d=%s", base.potential_impulses_hash, results[i].pass_index, results[i].potential_impulses_hash);
        }
      if(results[i].potential_corrections_hash != base.potential_corrections_hash)
        {
         v_corrections++;
         if(s_corrections == "")
            s_corrections = StringFormat("pass0=%s pass%d=%s", base.potential_corrections_hash, results[i].pass_index, results[i].potential_corrections_hash);
        }
      if(results[i].potential_continuation_signals_hash != base.potential_continuation_signals_hash)
        {
         v_continuations++;
         if(s_continuations == "")
            s_continuations = StringFormat("pass0=%s pass%d=%s", base.potential_continuation_signals_hash, results[i].pass_index, results[i].potential_continuation_signals_hash);
        }
      if(results[i].trade_setup_plans_hash != base.trade_setup_plans_hash)
        {
         v_plans++;
         if(s_plans == "")
            s_plans = StringFormat("pass0=%s pass%d=%s", base.trade_setup_plans_hash, results[i].pass_index, results[i].trade_setup_plans_hash);
        }
      if(results[i].historical_trade_setups_hash != base.historical_trade_setups_hash)
        {
         v_history++;
         if(s_history == "")
            s_history = StringFormat("pass0=%s pass%d=%s", base.historical_trade_setups_hash, results[i].pass_index, results[i].historical_trade_setups_hash);
        }
      if(results[i].combined_hash != base.combined_hash)
        {
         v_combined++;
         if(s_combined == "")
            s_combined = StringFormat("pass0=%s pass%d=%s", base.combined_hash, results[i].pass_index, results[i].combined_hash);
        }
     }

   AppendAssertion(out_assertions, "SNAPSHOT_RANGE_STABLE", (v_range == 0), v_range, s_range);
   AppendAssertion(out_assertions, "ELEMENT_HASH_STABLE", (v_elements == 0), v_elements, s_elements);
   AppendAssertion(out_assertions, "LEG_HASH_STABLE", (v_legs == 0), v_legs, s_legs);
   AppendAssertion(out_assertions, "SWING3_HASH_STABLE", (v_swings3 == 0), v_swings3, s_swings3);
   AppendAssertion(out_assertions, "POTENTIAL_IMPULSE_HASH_STABLE", (v_impulses == 0), v_impulses, s_impulses);
   AppendAssertion(out_assertions, "POTENTIAL_CORRECTION_HASH_STABLE", (v_corrections == 0), v_corrections, s_corrections);
   AppendAssertion(out_assertions, "CONTINUATION_HASH_STABLE", (v_continuations == 0), v_continuations, s_continuations);
   AppendAssertion(out_assertions, "TRADE_SETUP_PLAN_HASH_STABLE", (v_plans == 0), v_plans, s_plans);
   AppendAssertion(out_assertions, "HISTORICAL_SETUP_HASH_STABLE", (v_history == 0), v_history, s_history);
   AppendAssertion(out_assertions, "COMBINED_HASH_STABLE", (v_combined == 0), v_combined, s_combined);
  }

bool WriteMatrixCsv(const string path,
                    const string run_id,
                    const string symbol,
                    const int source_timeframe,
                    const int context_timeframe,
                    const int execution_timeframe,
                    const int lookback_bars,
                    const MohyKsPassResult &results[])
  {
   const int handle = FileOpen(path, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("MOHY | KS_DET | Failed to open matrix CSV: %s (err=%d)", path, GetLastError());
      return false;
     }

   FileWrite(handle,
             "run_id",
             "symbol",
             "source_timeframe",
             "context_timeframe",
             "execution_timeframe",
             "include_provisional_latest",
             "lookback_bars",
             "pass_index",
             "config_hash",
             "from_shift",
             "max_shift",
             "elements_count",
             "elements_hash",
             "legs_count",
             "legs_hash",
             "swings3_count",
             "swings3_hash",
             "potential_impulses_count",
             "potential_impulses_hash",
             "potential_corrections_count",
             "potential_corrections_hash",
             "potential_continuation_signals_count",
             "potential_continuation_signals_hash",
             "trade_setup_plans_count",
             "trade_setup_plans_hash",
             "historical_trade_setups_count",
             "historical_trade_setups_hash",
             "combined_hash");

   for(int i = 0; i < ArraySize(results); ++i)
      FileWrite(handle,
                run_id,
                symbol,
                MohyTimeframeToString(source_timeframe),
                MohyTimeframeToString(context_timeframe),
                MohyTimeframeToString(execution_timeframe),
                1,
                lookback_bars,
                results[i].pass_index,
                results[i].config_hash,
                results[i].from_shift,
                results[i].max_shift,
                results[i].elements_count,
                results[i].elements_hash,
                results[i].legs_count,
                results[i].legs_hash,
                results[i].swings3_count,
                results[i].swings3_hash,
                results[i].potential_impulses_count,
                results[i].potential_impulses_hash,
                results[i].potential_corrections_count,
                results[i].potential_corrections_hash,
                results[i].potential_continuation_signals_count,
                results[i].potential_continuation_signals_hash,
                results[i].trade_setup_plans_count,
                results[i].trade_setup_plans_hash,
                results[i].historical_trade_setups_count,
                results[i].historical_trade_setups_hash,
                results[i].combined_hash);

   FileClose(handle);
   return true;
  }

bool WriteAssertionsCsv(const string path,
                        const string run_id,
                        const MohyKsAssertionRow &assertions[])
  {
   const int handle = FileOpen(path, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(handle == INVALID_HANDLE)
     {
      PrintFormat("MOHY | KS_DET | Failed to open assertions CSV: %s (err=%d)", path, GetLastError());
      return false;
     }

   FileWrite(handle, "run_id", "rule_id", "pass", "violation_count", "sample");
   for(int i = 0; i < ArraySize(assertions); ++i)
      FileWrite(handle,
                run_id,
                assertions[i].rule_id,
                assertions[i].pass ? 1 : 0,
                assertions[i].violation_count,
                assertions[i].sample);

   FileClose(handle);
   return true;
  }

void OnStart()
  {
   const string symbol = (TrimText(VerificationSymbol) == "") ? _Symbol : TrimText(VerificationSymbol);
   const int source_timeframe = (int)VerificationSourceTimeframe;
   const int context_timeframe = (int)VerificationHTF;
   const int execution_timeframe = (int)VerificationLTF;
   const int lookback_bars = MathMax(100, VerificationLookbackBars);
   const int replay_passes = MathMax(1, VerificationReplayPasses);

   if(!SymbolSelect(symbol, true))
     {
      PrintFormat("MOHY | KS_DET | SymbolSelect failed for '%s'", symbol);
      return;
     }

   if(!MohyValidateTimeframePair(context_timeframe, execution_timeframe))
     {
      PrintFormat("MOHY | KS_DET | Invalid timeframe pair HTF=%s LTF=%s",
                  MohyTimeframeToString(context_timeframe),
                  MohyTimeframeToString(execution_timeframe));
      return;
     }

   string run_id = TrimText(VerificationRunId);
   if(run_id == "")
      run_id = StringFormat("KS_DET_%s_%s_%s",
                            symbol,
                            MohyTimeframeToString(source_timeframe),
                            BuildTimestampToken(TimeCurrent()));
   run_id = SanitizeToken(run_id);

   MohyKsPassResult results[];
   ArrayResize(results, replay_passes);
   for(int i = 0; i < replay_passes; ++i)
     {
      string eval_error = "";
      if(!EvaluateSinglePass(symbol,
                             source_timeframe,
                             context_timeframe,
                             execution_timeframe,
                             lookback_bars,
                             i,
                             results[i],
                             eval_error))
        {
         PrintFormat("MOHY | KS_DET | Pass %d failed: %s", i, eval_error);
         return;
        }
     }

   MohyKsAssertionRow assertions[];
   EvaluateAssertions(results, assertions);

   string matrix_path = "";
   string assertions_path = "";
   if(VerificationWriteDetailsCsv || VerificationWriteAssertionsCsv)
     {
      const string out_dir = NormalizeDirectoryPath(VerificationOutputDirectory);
      if(!EnsureOutputDirectory(out_dir))
        {
         PrintFormat("MOHY | KS_DET | Failed to ensure output directory: %s", out_dir);
         return;
        }
      matrix_path = StringFormat("%s\\%s__matrix.csv", out_dir, run_id);
      assertions_path = StringFormat("%s\\%s__assertions.csv", out_dir, run_id);
     }

   if(VerificationWriteDetailsCsv &&
      !WriteMatrixCsv(matrix_path,
                      run_id,
                      symbol,
                      source_timeframe,
                      context_timeframe,
                      execution_timeframe,
                      lookback_bars,
                      results))
      return;

   if(VerificationWriteAssertionsCsv &&
      !WriteAssertionsCsv(assertions_path, run_id, assertions))
      return;

   for(int i = 0; i < ArraySize(assertions); ++i)
      PrintFormat("MOHY | KS_DET | Assertion %s pass=%s violations=%d sample=%s",
                  assertions[i].rule_id,
                  assertions[i].pass ? "true" : "false",
                  assertions[i].violation_count,
                  assertions[i].sample);

   PrintFormat("MOHY | KS_DET | Completed run_id=%s passes=%d matrix_csv=%s assertions_csv=%s",
               run_id,
               replay_passes,
               matrix_path,
               assertions_path);
  }
