#ifndef __MOHY_RUNTIME_COMMON_MQH__
#define __MOHY_RUNTIME_COMMON_MQH__

#include <MOHY/Domain/Config.mqh>
#include <MOHY/Domain/StateIds.mqh>

string MohyRuntimeTrim(const string value)
  {
   int start = 0;
   int end = StringLen(value) - 1;
   while(start <= end && StringGetCharacter(value, start) <= 32)
      start++;
   while(end >= start && StringGetCharacter(value, end) <= 32)
      end--;
   if(end < start)
      return "";
   return StringSubstr(value, start, end - start + 1);
  }

string MohyRuntimeNormalizeDirectoryPath(const string value)
  {
   string out = value;
   StringReplace(out, "/", "\\");
   while(StringFind(out, "\\\\") >= 0)
      StringReplace(out, "\\\\", "\\");
   return MohyRuntimeTrim(out);
  }

bool MohyRuntimeEnsureDirectory(const string relative_dir)
  {
   const string normalized = MohyRuntimeNormalizeDirectoryPath(relative_dir);
   if(normalized == "")
      return false;

   string parts[];
   const int count = StringSplit(normalized, '\\', parts);
   if(count <= 0)
      return false;

   string acc = "";
   for(int i = 0; i < count; ++i)
     {
      const string part = MohyRuntimeTrim(parts[i]);
      if(part == "")
         continue;
      acc = (acc == "") ? part : (acc + "\\" + part);
      FolderCreate(acc);
     }
   return true;
  }

string MohyRuntimeSanitizeToken(const string value)
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
   out = MohyRuntimeTrim(out);
   return (out == "") ? "NA" : out;
  }

string MohyRuntimeBoolToString(const bool value)
  {
   return value ? "true" : "false";
  }

uint MohyRuntimeHashBegin()
  {
   return 2166136261;
  }

uint MohyRuntimeHashUpdate(uint hash,
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

string MohyRuntimeHashHex(const uint hash)
  {
   return StringFormat("%08X", (int)hash);
  }

string MohyRuntimeBuildScopeTag(const string symbol,
                               const int context_timeframe,
                               const int execution_timeframe,
                               const int magic_number)
  {
   return StringFormat("%s_%s_%s_%d",
                       MohyRuntimeSanitizeToken(symbol),
                       MohyRuntimeSanitizeToken(MohyTimeframeToString(context_timeframe)),
                       MohyRuntimeSanitizeToken(MohyTimeframeToString(execution_timeframe)),
                       magic_number);
  }

string MohyRuntimeBuildRuntimeDirectory(const string scope_tag)
  {
   return StringFormat("MOHY\\runtime\\%s", scope_tag);
  }

string MohyRuntimeBuildRuntimePath(const string scope_tag,
                                  const string filename)
  {
   return StringFormat("%s\\%s",
                       MohyRuntimeBuildRuntimeDirectory(scope_tag),
                       filename);
  }

string MohyRuntimeBuildConfigHash(const StrategyConfig &cfg)
  {
   string signature = StringFormat("pair=%d|ctx=%d|exe=%d|entryMode=%d|pendingAuto=%d|minRR=%s|minStop=%s|spread=%s|risk=%s|maxRisk=%s|magic=%d|sl=%d|tp=%d|be=%d|beRetry=%d|pi=%d|pc=%d|contStart=%d|ui=%d",
                                   (int)cfg.timeframe_pair,
                                   cfg.context_timeframe,
                                   cfg.execution_timeframe,
                                   (int)cfg.entry.execution_mode,
                                   cfg.entry.enable_pending_auto_modify ? 1 : 0,
                                   DoubleToString(cfg.entry.min_rr, 8),
                                   DoubleToString(cfg.entry.min_stop_distance_points, 8),
                                   DoubleToString(cfg.entry.max_spread_points, 8),
                                   DoubleToString(cfg.risk.risk_percent, 8),
                                   DoubleToString(cfg.risk.max_concurrent_risk_percent, 8),
                                   cfg.risk.magic_number,
                                   (int)cfg.sl_mode,
                                   (int)cfg.tp_mode,
                                   cfg.management.enable_break_even_on_impulse_extreme ? 1 : 0,
                                   cfg.management.be_retry_ticks,
                                   cfg.detection.enable_potential_impulse ? 1 : 0,
                                   cfg.detection.enable_potential_correction ? 1 : 0,
                                   (int)cfg.detection.continuation_planning_start_mode,
                                   cfg.ui.enable_ui ? 1 : 0);
   return MohyRuntimeHashHex(MohyRuntimeHashUpdate(MohyRuntimeHashBegin(), signature));
  }

string MohyRuntimePriceToString(const double price,
                               const string symbol)
  {
   long digits = 10;
   if(symbol != "" && SymbolInfoInteger(symbol, SYMBOL_DIGITS, digits) && digits >= 0)
      return DoubleToString(price, (int)digits);
   return DoubleToString(price, 10);
  }

#endif

