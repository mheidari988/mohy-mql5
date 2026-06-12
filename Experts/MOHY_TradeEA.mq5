#property strict

#include <MOHY/Domain/Config.mqh>
#include <MOHY/Core/PriceActionKernel.mqh>
#include <MOHY/Core/Domain/SnapshotSelectors.mqh>
#include <MOHY/Core/Compat/TerminalSeries.mqh>
#include <MOHY/Runtime/RuntimeInputMapper.mqh>
#include <MOHY/Runtime/RuntimeEngine.mqh>

enum MohyScanUniverseMode
  {
   MOHY_SCAN_UNIVERSE_MARKET_WATCH_ALL = 0,
   MOHY_SCAN_UNIVERSE_CHART_SYMBOL_ONLY = 1
  };

input ENUM_TIMEFRAMES HTF = (ENUM_TIMEFRAMES)16385;
input ENUM_TIMEFRAMES LTF = (ENUM_TIMEFRAMES)15;
input int      LookbackBars = 1600;
input MohyRuntimeRoleMode RuntimeRoleMode = MOHY_RUNTIME_ROLE_SHADOW_DEBUG;
input bool     EnableMarketWatchScanner = true;
input MohyScanUniverseMode ScanUniverseMode = MOHY_SCAN_UNIVERSE_MARKET_WATCH_ALL;
input int      ScannerIntervalSeconds = 2;
input bool     ScannerLogSummary = true;
input int      ScannerLogTopRanks = 3;
input bool     EnablePortfolioAllocator = true;
input int      PortfolioMaxActiveTrades = 2;
input bool     EnableLiveExecutionOwnership = false;
input bool     EnableArtifactBus = true;
input bool     EnableGlobalControlPanel = true;
input int      GlobalPanelTopRows = 5;

input bool     PotentialImpulseEnabled = true;
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

input double   MinRR = 2.0;
input double   RRTolerance = 0.02;
input bool     EnableSpreadFilter = true;
input double   MaxSpreadPoints = 40.0;
input int      SpreadEmaPeriod = 20;
input double   FixedSlippagePoints = 1.0;
input double   SlippageSpreadMultiplier = 0.25;
input double   FixedCommissionPoints = 0.0;
input double   MinTriggerMovePoints = 1.0;
input bool     EnableTriggerFreeze = true;
input double   FreezeSpreadMultiplier = 0.5;
input double   MinStopDistancePoints = 25.0;
input MohyEntryExecutionMode EntryExecutionMode = MOHY_ENTRY_VIRTUAL_TRIGGER;
input MohyRecheckMode RecheckMode = MOHY_RECHECK_ADJUST_ON_FAIL;
input MohyAdjustCadence AdjustCadence = MOHY_ADJUST_CADENCE_TICK_WITH_THROTTLE;
input int      AdjustMinSeconds = 1;
input bool     RecheckRRAtTrigger = true;
input MohyTouchSide SellTriggerTouchSide = MOHY_TOUCH_LOW_COST;
input MohyTouchSide BuyTriggerTouchSide = MOHY_TOUCH_LOW_COST;
input bool     EnablePendingAutoModify = true;
input MohyPreEntryInvalidationMode PreEntryInvalidationMode = MOHY_PRE_ENTRY_INVALIDATE_TOUCH;
input double   PreEntryInvalidationBufferPoints = 0.0;

input double   RiskPercent = 1.0;
input MohyRiskBase RiskBase = MOHY_RISK_BASE_CALCULATED_BALANCE;
input double   MaxConcurrentRiskPercent = 3.0;
input MohyExposureBase ExposureBase = MOHY_EXPOSURE_BASE_CALCULATED_BALANCE;
input int      MagicNumber = 26021601;
input int      BrokerSlippagePoints = 30;

input MohySLMode StopLossMode = MOHY_SL_OUTER_CORRECTION_EXTREME;
input double   OuterSLBufferPoints = 0.0;
input double   InnerSLBufferPoints = 0.0;
input int      InnerStopSwingIndex = 1;
input MohyTPMode TakeProfitMode = MOHY_TP_FIB_NEG_EXTENSION;
input double   FibTargetLevel = 0.272;
input double   TargetRR = 2.0;
input bool     EnableBreakEvenOnImpulseExtreme = true;
input int      BERetryTicks = 5;
input MohyPostBEProfile PostBEManagementProfile = MOHY_POST_BE_HYBRID;
input MohyPostBEStartMode PostBEStartMode = MOHY_POST_BE_START_AFTER_BE;
input double   PostBEStartR = 1.0;
input MohyTrailModel TrailModel = MOHY_TRAIL_STRUCTURE_BASED;
input MohyTrailUpdateCadence TrailUpdateCadence = MOHY_TRAIL_HYBRID_INTRABAR;
input bool     TrailOneWayRatchet = true;
input int      TrailStructureSwingIndex = 1;
input double   TrailFixedPoints = 150.0;
input int      TrailATRPeriod = 14;
input double   TrailATRMultiplier = 1.0;
input ENUM_MA_METHOD TrailMAMethod = MODE_EMA;
input int      TrailMAPeriod = 20;
input ENUM_APPLIED_PRICE TrailMAPrice = PRICE_CLOSE;
input double   TrailMABufferPoints = 0.0;
input MohyPartialModel PartialModel = MOHY_PARTIAL_R_MULTIPLE;
input int      PartialCount = 2;
input double   PartialPercent1 = 50.0;
input double   PartialPercent2 = 50.0;
input double   PartialPercent3 = 0.0;
input double   PartialRMultiple1 = 1.0;
input double   PartialRMultiple2 = 2.0;
input double   PartialRMultiple3 = 3.0;
input double   PartialFibLevel1 = 0.272;
input double   PartialFibLevel2 = 0.618;
input double   PartialFibLevel3 = 1.0;
input MohyPartialTargetMode PartialTargetMode1 = MOHY_PARTIAL_TARGET_R_MULTIPLE;
input MohyPartialTargetMode PartialTargetMode2 = MOHY_PARTIAL_TARGET_R_MULTIPLE;
input MohyPartialTargetMode PartialTargetMode3 = MOHY_PARTIAL_TARGET_R_MULTIPLE;
input MohyPostPartialStopAction PostPartialStopAction = MOHY_POST_PARTIAL_MOVE_TO_BE_OR_BE_PLUS;
input double   PostPartialBEPlusPoints = 0.0;
input MohyRunnerTargetMode RunnerTargetMode = MOHY_RUNNER_KEEP_EXISTING_TP;
input bool     ApplyExecFiltersToManagement = true;
input int      ManagementRetryCount = 3;
input bool     ManagementRetryThenMarketClose = true;

input bool     PanelEnabled = true;
input ENUM_BASE_CORNER PanelCorner = CORNER_RIGHT_UPPER;
input int      PanelOffsetX = 20;
input int      PanelOffsetY = 20;
input int      DangerousActionCooldownSeconds = 5;
input int      UiRedrawThrottleMs = 250;
input bool     EnableTerminalAlerts = true;
input bool     EnableFileAudit = true;

CMohyRuntimeEngine g_runtime;
StrategyConfig     g_cfg;
CMohyPriceActionKernel g_market_watch_kernel;

struct MohyMarketWatchScanState
  {
   string   symbol;
   datetime last_scan_time;
   bool     last_scan_ok;
   bool     publishes_execution_stage_facts;
   int      bars;
   int      impulse_count;
   int      correction_count;
   int      continuation_count;
   int      setup_plan_count;
   int      selected_plan_index;
   string   selected_plan_state;
   bool     selected_plan_valid;
   string   selected_plan_setup_key;
   string   selected_plan_impulse_id;
   string   selected_plan_direction;
   string   selected_plan_execution_mode;
   datetime selected_plan_setup_time;
   double   selected_plan_entry_price;
   double   selected_plan_expected_fill_price;
   double   selected_plan_required_entry_price;
   double   selected_plan_trigger_price;
   double   selected_plan_stop_price;
   double   selected_plan_target_price;
   double   selected_plan_risk_money;
   double   selected_plan_reward_to_risk;
   double   selected_plan_lots_normalized;
   bool     selected_plan_exposure_pass;
   MohyRejectReason selected_plan_reject_reason;
   bool     allocator_accepted;
   string   allocator_decision;
   double   allocator_candidate_risk_percent;
   int      primary_bucket_id;
   string   primary_bucket;
   string   bucket_reason;
   int      ranking_order;
   int      ranking_bucket_priority;
   double   ranking_score;
   int      ranking_plan_selection_rank;
   datetime ranking_plan_setup_time;
   string   ranking_diagnostics;
   string   last_error;
  };

enum MohyMarketOpportunityBucket
  {
   MOHY_BUCKET_CONFIRMED_POTENTIAL_IMPULSE = 0,
   MOHY_BUCKET_CONFIRMED_IMPULSE_AND_CONFIRMED_CORRECTION = 1,
   MOHY_BUCKET_CONFIRMED_SETUP_WAITING_ENTRY = 2,
   MOHY_BUCKET_ELIGIBLE_NOW = 3,
   MOHY_BUCKET_ENTERED_OPEN_RUNNING = 4,
   MOHY_BUCKET_BLOCKED_BY_RISK_OR_EXPOSURE = 5,
   MOHY_BUCKET_REJECTED_OR_INVALIDATED = 6
  };

MohyMarketWatchScanState g_market_watch_scan_states[];
ulong                    g_market_watch_scan_cycle = 0;
datetime                 g_market_watch_last_scan_time = 0;
MohyRuntimeRoleMode      g_panel_runtime_role = MOHY_RUNTIME_ROLE_SHADOW_DEBUG;
datetime                 g_artifact_started_at = 0;
string                   g_artifact_run_id = "";

struct MohyPortfolioCycleMetrics
  {
   int      processed_symbols;
   int      scanned_ok;
   int      scanned_failed;
   int      selected_setups;
   int      bucket_cpi;
   int      bucket_cic;
   int      bucket_waiting;
   int      bucket_eligible;
   int      bucket_open;
   int      bucket_blocked;
   int      bucket_rejected;
   int      allocator_accepted;
   int      allocator_blocked;
   double   allocator_exposure_base_value;
   double   allocator_open_risk_percent;
   double   allocator_allocated_risk_percent;
   int      execution_attempted;
   int      execution_success;
   int      execution_failed;
   string   first_error_symbol;
   string   first_error;
   string   execution_first_error_symbol;
   string   execution_first_error;
   datetime updated_at;
  };

struct MohyGlobalUiPendingAction
  {
   MohyUiActionId action_id;
   string         correlation_id;
   string         pre_state_hash;
   datetime       accepted_at;
  };

MohyPortfolioCycleMetrics g_portfolio_metrics;
CMohyRuntimeAudit         g_portfolio_audit;
string                    g_portfolio_scope_tag = "";
string                    g_global_panel_prefix = "";
MohyGlobalUiPendingAction g_global_pending_action;
MohyUiActionId            g_global_last_dangerous_action_id = MOHY_UI_ACTION_NONE;
datetime                  g_global_last_dangerous_action_time = 0;
string                    g_global_last_action_result = "Idle";
string                    g_global_last_panel_snapshot_hash = "";
uint                      g_global_last_panel_redraw_ms = 0;
bool                      g_global_pause_entries = false;

string MarketOpportunityBucketToString(const MohyMarketOpportunityBucket bucket)
  {
   if(bucket == MOHY_BUCKET_CONFIRMED_POTENTIAL_IMPULSE)
      return "ConfirmedPotentialImpulse";
   if(bucket == MOHY_BUCKET_CONFIRMED_IMPULSE_AND_CONFIRMED_CORRECTION)
      return "ConfirmedImpulseAndConfirmedCorrection";
   if(bucket == MOHY_BUCKET_CONFIRMED_SETUP_WAITING_ENTRY)
      return "ConfirmedSetupWaitingEntry";
   if(bucket == MOHY_BUCKET_ELIGIBLE_NOW)
      return "EligibleNow";
   if(bucket == MOHY_BUCKET_ENTERED_OPEN_RUNNING)
      return "EnteredOpenRunning";
   if(bucket == MOHY_BUCKET_BLOCKED_BY_RISK_OR_EXPOSURE)
      return "BlockedByRiskOrExposure";
   return "RejectedOrInvalidated";
  }

string ScanUniverseModeToString(const MohyScanUniverseMode mode)
  {
   if(mode == MOHY_SCAN_UNIVERSE_CHART_SYMBOL_ONLY)
      return "ChartSymbolOnly";
   return "MarketWatchAll";
  }

void ResolveScanUniverseSymbols(string &out_symbols[])
  {
   ArrayResize(out_symbols, 0);

   if(ScanUniverseMode == MOHY_SCAN_UNIVERSE_CHART_SYMBOL_ONLY)
     {
      const string chart_symbol = Symbol();
      if(chart_symbol != "")
        {
         ArrayResize(out_symbols, 1);
         out_symbols[0] = chart_symbol;
        }
      return;
     }

   const int symbol_total = SymbolsTotal(true);
   for(int i = 0; i < symbol_total; ++i)
     {
      const string symbol = SymbolName(i, true);
      if(symbol == "")
         continue;
      const int next = ArraySize(out_symbols);
      ArrayResize(out_symbols, next + 1);
      out_symbols[next] = symbol;
     }
  }

bool IsRiskOrExposureBlocked(const MohyTradeSetupPlanFact &plan)
  {
   if(!plan.exposure_pass)
      return true;
   return (plan.reject_reason == MOHY_REJECT_EXPOSURE_LIMIT_EXCEEDED);
  }

bool SnapshotHasConfirmedPotentialImpulse(const CMohyPriceActionSnapshot &snapshot)
  {
   return MohySnapshotHasConfirmedPotentialImpulse(snapshot);
  }

bool SnapshotHasConfirmedImpulseAndConfirmedCorrection(const CMohyPriceActionSnapshot &snapshot)
  {
   return MohySnapshotHasConfirmedImpulseAndConfirmedCorrection(snapshot);
  }

bool HasStrategyOpenTradeForSymbol(const string symbol)
  {
   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;

      const long position_magic = PositionGetInteger(POSITION_MAGIC);
      if(g_cfg.risk.magic_number > 0 && position_magic != (long)g_cfg.risk.magic_number)
         continue;

      return true;
     }

   return false;
  }

string BuildImpulseContextKey(const string impulse_id)
  {
   if(impulse_id == "")
      return "";

   string parts[];
   const int part_count = StringSplit(impulse_id, '|', parts);
   if(part_count < 6)
      return impulse_id;

   return StringFormat("%s|%s|%s|%s|%s|%s",
                       parts[0],
                       parts[1],
                       parts[2],
                       parts[3],
                       parts[4],
                       parts[5]);
  }

bool FindConsumedImpulseForSymbol(const string symbol,
                                  const string impulse_id,
                                  MohyRuntimeConsumedImpulse &out_consumed)
  {
   out_consumed.impulse_id = "";
   out_consumed.reason = MOHY_IMPULSE_CONSUMED_NONE;
   out_consumed.updated_at = 0;
   out_consumed.setup_key = "";

   if(symbol == "" || impulse_id == "")
      return false;

   CMohyRuntimeStore store;
   store.Configure(MohyRuntimeBuildScopeTag(symbol,
                                            g_cfg.context_timeframe,
                                            g_cfg.execution_timeframe,
                                            g_cfg.risk.magic_number));
   MohyRuntimeConsumedImpulse rows[];
   ArrayResize(rows, 0);
   if(!store.LoadConsumedImpulses(rows))
      return false;

   const int consumed_index = store.FindConsumedImpulse(rows, impulse_id);
   if(consumed_index >= 0 && consumed_index < ArraySize(rows))
     {
      out_consumed = rows[consumed_index];
      return true;
     }

   const string context_key = BuildImpulseContextKey(impulse_id);
   if(context_key == "")
      return false;

   for(int i = 0; i < ArraySize(rows); ++i)
     {
      if(rows[i].impulse_id == "")
         continue;
      if(BuildImpulseContextKey(rows[i].impulse_id) != context_key)
         continue;
      out_consumed = rows[i];
      return true;
     }

   return false;
  }

MohyMarketOpportunityBucket ClassifySnapshotBucket(const string symbol,
                                                   const CMohyPriceActionSnapshot &snapshot,
                                                   MohyMarketWatchScanState &io_state)
  {
   if(HasStrategyOpenTradeForSymbol(symbol))
     {
      io_state.bucket_reason = "OpenStrategyPosition";
      return MOHY_BUCKET_ENTERED_OPEN_RUNNING;
     }

   int selected_plan_index = MohyFindSelectedTradeSetupPlanIndex(snapshot, false);
   if(selected_plan_index < 0)
      selected_plan_index = MohySelectTradeSetupPlanIndex(snapshot, -1);
   io_state.selected_plan_index = selected_plan_index;

   if(selected_plan_index >= 0 &&
      selected_plan_index < ArraySize(snapshot.trade_setup_plans))
    {
      const MohyTradeSetupPlanFact plan = snapshot.trade_setup_plans[selected_plan_index];
      io_state.selected_plan_state = MohyTradeSetupPlanStateToString(plan.plan_state);
      io_state.selected_plan_valid = plan.valid;
      io_state.selected_plan_direction = MohyDirectionToString(plan.direction);
      io_state.selected_plan_execution_mode = (plan.execution_mode == MOHY_ENTRY_REAL_PENDING_ORDER)
                                              ? "RealPendingOrder"
                                              : "VirtualTrigger";
      io_state.selected_plan_setup_time = plan.setup_time;
      io_state.selected_plan_entry_price = plan.proposed_entry_price;
      io_state.selected_plan_expected_fill_price = plan.expected_fill_price;
      io_state.selected_plan_required_entry_price = plan.required_entry_price;
      io_state.selected_plan_trigger_price = plan.trigger_price;
      io_state.selected_plan_stop_price = plan.stop_price;
      io_state.selected_plan_target_price = plan.target_price;
      io_state.selected_plan_risk_money = plan.risk_money;
      io_state.selected_plan_reward_to_risk = plan.reward_to_risk;
      io_state.selected_plan_lots_normalized = plan.lots_normalized;
      io_state.selected_plan_exposure_pass = plan.exposure_pass;
      io_state.selected_plan_reject_reason = plan.reject_reason;
      io_state.selected_plan_impulse_id = plan.runtime_impulse_id;
      io_state.selected_plan_setup_key = plan.runtime_setup_key;

      string selected_impulse_id = "";
      string selected_setup_key = "";
      if(plan.valid &&
         MohyRuntimeResolveIdentity(symbol,
                                   snapshot,
                                   plan,
                                    selected_impulse_id,
                                    selected_setup_key))
        {
         io_state.selected_plan_impulse_id = selected_impulse_id;
         io_state.selected_plan_setup_key = selected_setup_key;
         MohyRuntimeConsumedImpulse consumed;
         if(FindConsumedImpulseForSymbol(symbol, selected_impulse_id, consumed))
           {
            const string consumed_reason = MohyImpulseConsumptionReasonToString(consumed.reason);
            io_state.selected_plan_state = StringFormat("Consumed(%s)", consumed_reason);
            io_state.bucket_reason = StringFormat("ImpulseConsumed:%s", consumed_reason);
            return MOHY_BUCKET_REJECTED_OR_INVALIDATED;
           }
        }

      if(plan.plan_state == MOHY_TRADE_SETUP_PLAN_ELIGIBLE_NOW)
        {
         if(IsRiskOrExposureBlocked(plan))
           {
            io_state.bucket_reason = StringFormat("EligibleButBlocked:%s",
                                                  MohyRejectReasonToString(plan.reject_reason));
            return MOHY_BUCKET_BLOCKED_BY_RISK_OR_EXPOSURE;
           }
         io_state.bucket_reason = "PlanEligibleNow";
         return MOHY_BUCKET_ELIGIBLE_NOW;
        }

      if(plan.plan_state == MOHY_TRADE_SETUP_PLAN_WAITING_FOR_PULLBACK)
        {
         io_state.bucket_reason = "PlanWaitingForPullback";
         return MOHY_BUCKET_CONFIRMED_SETUP_WAITING_ENTRY;
        }

      if(plan.plan_state == MOHY_TRADE_SETUP_PLAN_INELIGIBLE)
        {
         if(IsRiskOrExposureBlocked(plan))
           {
            io_state.bucket_reason = StringFormat("IneligibleBlocked:%s",
                                                  MohyRejectReasonToString(plan.reject_reason));
            return MOHY_BUCKET_BLOCKED_BY_RISK_OR_EXPOSURE;
           }

         if(plan.reject_reason == MOHY_REJECT_CONTINUATION_NOT_CONFIRMED)
           {
            if(SnapshotHasConfirmedImpulseAndConfirmedCorrection(snapshot))
              {
               io_state.bucket_reason = "ContinuationNotConfirmed";
               return MOHY_BUCKET_CONFIRMED_IMPULSE_AND_CONFIRMED_CORRECTION;
              }

            if(SnapshotHasConfirmedPotentialImpulse(snapshot))
              {
               io_state.bucket_reason = "ContinuationNotConfirmed";
               return MOHY_BUCKET_CONFIRMED_POTENTIAL_IMPULSE;
              }
           }

         io_state.bucket_reason = StringFormat("Ineligible:%s",
                                               MohyRejectReasonToString(plan.reject_reason));
         return MOHY_BUCKET_REJECTED_OR_INVALIDATED;
        }

      io_state.bucket_reason = "PlanInvalidated";
      return MOHY_BUCKET_REJECTED_OR_INVALIDATED;
     }

   if(SnapshotHasConfirmedImpulseAndConfirmedCorrection(snapshot))
     {
      io_state.bucket_reason = "ConfirmedImpulseAndCorrectionNoPlan";
      return MOHY_BUCKET_CONFIRMED_IMPULSE_AND_CONFIRMED_CORRECTION;
     }

   if(SnapshotHasConfirmedPotentialImpulse(snapshot))
     {
      io_state.bucket_reason = "ConfirmedImpulseNoConfirmedCorrection";
      return MOHY_BUCKET_CONFIRMED_POTENTIAL_IMPULSE;
     }

   io_state.bucket_reason = "NoEligibleKernelContext";
   return MOHY_BUCKET_REJECTED_OR_INVALIDATED;
  }

int FindMarketWatchScanStateIndex(const string symbol)
  {
   for(int i = 0; i < ArraySize(g_market_watch_scan_states); ++i)
      if(g_market_watch_scan_states[i].symbol == symbol)
         return i;
   return -1;
  }

int UpsertMarketWatchScanState(const MohyMarketWatchScanState &state)
  {
   const int existing_index = FindMarketWatchScanStateIndex(state.symbol);
   if(existing_index >= 0)
     {
      g_market_watch_scan_states[existing_index] = state;
      return existing_index;
     }

   const int next_index = ArraySize(g_market_watch_scan_states);
   ArrayResize(g_market_watch_scan_states, next_index + 1);
   g_market_watch_scan_states[next_index] = state;
   return next_index;
  }

bool IsRankedOpportunityBucket(const MohyMarketOpportunityBucket bucket)
  {
   return (bucket == MOHY_BUCKET_ELIGIBLE_NOW ||
           bucket == MOHY_BUCKET_CONFIRMED_SETUP_WAITING_ENTRY ||
           bucket == MOHY_BUCKET_CONFIRMED_IMPULSE_AND_CONFIRMED_CORRECTION ||
           bucket == MOHY_BUCKET_CONFIRMED_POTENTIAL_IMPULSE);
  }

int ResolveBucketPriority(const MohyMarketOpportunityBucket bucket)
  {
   if(bucket == MOHY_BUCKET_ELIGIBLE_NOW)
      return 700;
   if(bucket == MOHY_BUCKET_CONFIRMED_SETUP_WAITING_ENTRY)
      return 600;
   if(bucket == MOHY_BUCKET_CONFIRMED_IMPULSE_AND_CONFIRMED_CORRECTION)
      return 500;
   if(bucket == MOHY_BUCKET_CONFIRMED_POTENTIAL_IMPULSE)
      return 400;
   if(bucket == MOHY_BUCKET_ENTERED_OPEN_RUNNING)
      return 200;
   if(bucket == MOHY_BUCKET_BLOCKED_BY_RISK_OR_EXPOSURE)
      return 100;
   return 0;
  }

double ComputePlanQualityScore(const MohyTradeSetupPlanFact &plan)
  {
   const double rr_component = MathMin(MathMax(plan.reward_to_risk, 0.0), 10.0) * 100.0;
   const double selection_component =
      (plan.selection_rank >= 0)
      ? MathMax(0.0, 100.0 - MathMin((double)plan.selection_rank, 100.0))
      : 0.0;
   const double spread_component =
      (plan.spread_est_points > 0.0)
      ? MathMax(0.0, 50.0 - MathMin(plan.spread_est_points, 50.0))
      : 25.0;
   const double cost_component =
      (plan.total_entry_cost_points > 0.0)
      ? MathMax(0.0, 25.0 - MathMin(plan.total_entry_cost_points, 25.0))
      : 12.5;

   return rr_component + selection_component + spread_component + cost_component;
  }

void ApplyRankingMetrics(MohyMarketWatchScanState &io_state,
                         const MohyMarketOpportunityBucket bucket,
                         const bool has_selected_plan,
                         const MohyTradeSetupPlanFact &selected_plan)
  {
   io_state.ranking_order = 0;
   io_state.ranking_bucket_priority = ResolveBucketPriority(bucket);
   io_state.ranking_score = 0.0;
   io_state.ranking_plan_selection_rank = 999999;
   io_state.ranking_plan_setup_time = 0;
   io_state.ranking_diagnostics = "n/a";

   if(!IsRankedOpportunityBucket(bucket))
     {
      io_state.ranking_diagnostics = "NotRankedBucket";
      return;
     }

   io_state.ranking_score = (double)(io_state.ranking_bucket_priority * 1000);
   if(has_selected_plan && selected_plan.valid)
     {
      const double quality_score = ComputePlanQualityScore(selected_plan);
      io_state.ranking_score += quality_score;
      io_state.ranking_plan_selection_rank =
         (selected_plan.selection_rank >= 0) ? selected_plan.selection_rank : 999999;
      io_state.ranking_plan_setup_time = selected_plan.setup_time;
      io_state.ranking_diagnostics =
         StringFormat("bucket=%s|quality=%.2f|rr=%.2f|sel=%d|spread=%.2f|cost=%.2f",
                      io_state.primary_bucket,
                      quality_score,
                      selected_plan.reward_to_risk,
                      selected_plan.selection_rank,
                      selected_plan.spread_est_points,
                      selected_plan.total_entry_cost_points);
      return;
     }

   io_state.ranking_diagnostics =
      StringFormat("bucket=%s|quality=0.00|noSelectedPlan", io_state.primary_bucket);
  }

bool IsStateRankedHigher(const MohyMarketWatchScanState &lhs,
                         const MohyMarketWatchScanState &rhs)
  {
   if(lhs.ranking_bucket_priority != rhs.ranking_bucket_priority)
      return (lhs.ranking_bucket_priority > rhs.ranking_bucket_priority);
   if(MathAbs(lhs.ranking_score - rhs.ranking_score) > 1e-8)
      return (lhs.ranking_score > rhs.ranking_score);
   if(lhs.ranking_plan_selection_rank != rhs.ranking_plan_selection_rank)
      return (lhs.ranking_plan_selection_rank < rhs.ranking_plan_selection_rank);
   if(lhs.ranking_plan_setup_time != rhs.ranking_plan_setup_time)
      return (lhs.ranking_plan_setup_time > rhs.ranking_plan_setup_time);
   return (StringCompare(lhs.symbol, rhs.symbol, false) < 0);
  }

void ApplyDeterministicRanking(const int &scan_state_indexes[])
  {
   int ranked_indexes[];
   ArrayResize(ranked_indexes, 0);

   for(int i = 0; i < ArraySize(scan_state_indexes); ++i)
     {
      const int state_index = scan_state_indexes[i];
      if(state_index < 0 || state_index >= ArraySize(g_market_watch_scan_states))
         continue;

      g_market_watch_scan_states[state_index].ranking_order = 0;
      if(!g_market_watch_scan_states[state_index].last_scan_ok)
         continue;
      if(g_market_watch_scan_states[state_index].ranking_bucket_priority <= 0)
         continue;
      const MohyMarketOpportunityBucket bucket =
         (MohyMarketOpportunityBucket)g_market_watch_scan_states[state_index].primary_bucket_id;
      if(!IsRankedOpportunityBucket(bucket))
         continue;

      const int next_ranked_index = ArraySize(ranked_indexes);
      ArrayResize(ranked_indexes, next_ranked_index + 1);
      ranked_indexes[next_ranked_index] = state_index;
     }

   for(int i = 0; i < ArraySize(ranked_indexes) - 1; ++i)
     {
      int best_index = i;
      for(int j = i + 1; j < ArraySize(ranked_indexes); ++j)
        {
         const MohyMarketWatchScanState candidate = g_market_watch_scan_states[ranked_indexes[j]];
         const MohyMarketWatchScanState best = g_market_watch_scan_states[ranked_indexes[best_index]];
         if(IsStateRankedHigher(candidate, best))
            best_index = j;
        }
      if(best_index != i)
        {
         const int temp = ranked_indexes[i];
         ranked_indexes[i] = ranked_indexes[best_index];
         ranked_indexes[best_index] = temp;
        }
     }

   for(int i = 0; i < ArraySize(ranked_indexes); ++i)
     {
      const int state_index = ranked_indexes[i];
      if(state_index < 0 || state_index >= ArraySize(g_market_watch_scan_states))
         continue;
      g_market_watch_scan_states[state_index].ranking_order = i + 1;
     }
  }

double ResolveSymbolPoint(const string symbol)
  {
   double point = 0.0;
   if(!SymbolInfoDouble(symbol, SYMBOL_POINT, point) || point <= 0.0)
      point = _Point;
   return MathMax(1e-10, point);
  }

double ResolveMoneyPerLot(const string symbol,
                          const double entry_price,
                          const double stop_price)
  {
   const double distance = MathAbs(entry_price - stop_price);
   if(distance <= 1e-10)
      return 0.0;

   double tick_size = 0.0;
   double tick_value = 0.0;
   if(!SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE, tick_size) || tick_size <= 0.0)
      tick_size = ResolveSymbolPoint(symbol);
   if(!SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE, tick_value) || tick_value <= 0.0)
      return 0.0;
   if(tick_size <= 1e-10)
      return 0.0;

   return (distance / tick_size) * tick_value;
  }

double ResolveOpenStrategyWorstCaseRiskMoney()
  {
   double open_risk_money = 0.0;
   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(g_cfg.risk.magic_number > 0 &&
         PositionGetInteger(POSITION_MAGIC) != (long)g_cfg.risk.magic_number)
         continue;

      const string symbol = PositionGetString(POSITION_SYMBOL);
      const long type = PositionGetInteger(POSITION_TYPE);
      const double volume = PositionGetDouble(POSITION_VOLUME);
      const double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double stop_price = PositionGetDouble(POSITION_SL);
      if(symbol == "" || volume <= 1e-10 || entry_price <= 0.0 || stop_price <= 0.0)
         continue;

      double effective_stop = 0.0;
      if(type == POSITION_TYPE_BUY)
        {
         if(stop_price >= entry_price - 1e-10)
            continue;
         effective_stop = stop_price;
        }
      else if(type == POSITION_TYPE_SELL)
        {
         if(stop_price <= entry_price + 1e-10)
            continue;
         effective_stop = stop_price;
        }
      else
         continue;

      const double money_per_lot = ResolveMoneyPerLot(symbol, entry_price, effective_stop);
      if(money_per_lot <= 1e-10)
         continue;

      open_risk_money += money_per_lot * volume;
     }

   return open_risk_money;
  }

double ResolveExposureBaseValue(const double open_risk_money)
  {
   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   const double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   if(g_cfg.risk.exposure_base == MOHY_EXPOSURE_BASE_EQUITY)
      return MathMax(0.0, equity);
   if(g_cfg.risk.exposure_base == MOHY_EXPOSURE_BASE_BALANCE)
      return MathMax(0.0, balance);
   return MathMax(0.0, balance - open_risk_money);
  }

int CountOpenStrategyPositions()
  {
   int open_count = 0;
   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(g_cfg.risk.magic_number > 0 &&
         PositionGetInteger(POSITION_MAGIC) != (long)g_cfg.risk.magic_number)
         continue;
      open_count++;
     }
   return open_count;
  }

double EstimateOpenStrategyRiskPercent(const double exposure_base_value,
                                       const double open_risk_money)
  {
   if(exposure_base_value <= 1e-10 || open_risk_money <= 1e-10)
      return 0.0;
   return (open_risk_money / exposure_base_value) * 100.0;
  }

bool IsAllocatorActionableBucket(const int bucket_id)
  {
   return (bucket_id == (int)MOHY_BUCKET_ELIGIBLE_NOW ||
           bucket_id == (int)MOHY_BUCKET_CONFIRMED_SETUP_WAITING_ENTRY);
  }

void ApplyPortfolioAllocator(const int &scan_state_indexes[],
                             int &out_accepted,
                             int &out_blocked,
                             double &out_exposure_base_value,
                             double &out_open_risk_percent,
                             double &out_allocated_risk_percent)
  {
   out_accepted = 0;
   out_blocked = 0;
   const double open_risk_money = ResolveOpenStrategyWorstCaseRiskMoney();
   out_exposure_base_value = ResolveExposureBaseValue(open_risk_money);
   out_open_risk_percent = EstimateOpenStrategyRiskPercent(out_exposure_base_value,
                                                           open_risk_money);
   out_allocated_risk_percent = 0.0;

   if(!EnablePortfolioAllocator)
      return;

   const int max_active_trades = MathMax(1, PortfolioMaxActiveTrades);
   int active_trade_count = CountOpenStrategyPositions();
   double allocated_risk_percent = out_open_risk_percent;

   for(int rank = 1; rank <= ArraySize(scan_state_indexes); ++rank)
     {
      int state_index = -1;
      for(int i = 0; i < ArraySize(scan_state_indexes); ++i)
        {
         const int candidate_index = scan_state_indexes[i];
         if(candidate_index < 0 || candidate_index >= ArraySize(g_market_watch_scan_states))
            continue;
         if(g_market_watch_scan_states[candidate_index].ranking_order == rank)
           {
            state_index = candidate_index;
            break;
           }
        }

      if(state_index < 0)
         continue;

      MohyMarketWatchScanState state = g_market_watch_scan_states[state_index];
      if(!state.last_scan_ok || !IsAllocatorActionableBucket(state.primary_bucket_id))
         continue;

      string block_reason = "";
      double candidate_risk_percent = g_cfg.risk.risk_percent;
      if(out_exposure_base_value > 1e-10 && state.selected_plan_risk_money > 0.0)
         candidate_risk_percent =
            (state.selected_plan_risk_money / out_exposure_base_value) * 100.0;
      candidate_risk_percent = MathMax(0.0, candidate_risk_percent);
      state.allocator_candidate_risk_percent = candidate_risk_percent;
      state.allocator_accepted = false;
      state.allocator_decision = "None";

      if(!state.selected_plan_valid)
         block_reason = "NoSelectedPlan";
      else if(active_trade_count >= max_active_trades)
         block_reason = "MaxActiveTradesCap";
      else if((allocated_risk_percent + candidate_risk_percent) >
              (g_cfg.risk.max_concurrent_risk_percent + 1e-10))
         block_reason = "ConcurrentRiskCap";

      if(block_reason != "")
        {
         state.primary_bucket_id = (int)MOHY_BUCKET_BLOCKED_BY_RISK_OR_EXPOSURE;
         state.primary_bucket = MarketOpportunityBucketToString(MOHY_BUCKET_BLOCKED_BY_RISK_OR_EXPOSURE);
         state.bucket_reason = StringFormat("AllocatorBlocked:%s", block_reason);
         state.allocator_decision = StringFormat("Blocked:%s", block_reason);
         state.ranking_diagnostics = StringFormat("%s|allocator=blocked:%s|riskPct=%.3f|allocatedPct=%.3f|maxPct=%.3f|maxTrades=%d",
                                                  state.ranking_diagnostics,
                                                  block_reason,
                                                  candidate_risk_percent,
                                                  allocated_risk_percent,
                                                  g_cfg.risk.max_concurrent_risk_percent,
                                                  max_active_trades);
         g_market_watch_scan_states[state_index] = state;
         out_blocked++;
         continue;
        }

      active_trade_count++;
      allocated_risk_percent += candidate_risk_percent;
      state.allocator_accepted = true;
      state.allocator_decision = "Accepted";
      state.bucket_reason = StringFormat("%s|AllocatorAccepted", state.bucket_reason);
      state.ranking_diagnostics = StringFormat("%s|allocator=accepted|riskPct=%.3f|allocatedPct=%.3f|maxPct=%.3f|maxTrades=%d",
                                               state.ranking_diagnostics,
                                               candidate_risk_percent,
                                               allocated_risk_percent,
                                               g_cfg.risk.max_concurrent_risk_percent,
                                               max_active_trades);
      g_market_watch_scan_states[state_index] = state;
      out_accepted++;
     }

   out_allocated_risk_percent = allocated_risk_percent;
  }

bool ShouldRunLivePortfolioExecution()
  {
   return (EnableLiveExecutionOwnership &&
           RuntimeRoleMode == MOHY_RUNTIME_ROLE_GLOBAL_LIVE &&
           EnableMarketWatchScanner);
  }

bool ExecuteRuntimeForSymbol(const string symbol,
                             string &out_error)
  {
   out_error = "";
   if(symbol == "")
     {
      out_error = "EmptySymbol";
      return false;
     }

   if(!SymbolSelect(symbol, true))
     {
      out_error = "SymbolSelectFailed";
      return false;
     }

   StrategyConfig symbol_cfg = g_cfg;
   symbol_cfg.symbol = symbol;
   // Global panel actions use centralized audit rows in portfolio scope;
   // suppress per-symbol alert/audit fan-out during dispatch.
   symbol_cfg.ui.enable_terminal_alerts = false;
   symbol_cfg.ui.enable_file_audit = false;

   CMohyRuntimeEngine symbol_runtime;
   symbol_runtime.Configure(symbol_cfg,
                            symbol,
                            LookbackBars,
                            false,
                            (int)PanelCorner,
                            PanelOffsetX,
                            PanelOffsetY,
                            MOHY_RUNTIME_ROLE_GLOBAL_LIVE);
   if(!symbol_runtime.Initialize())
     {
      out_error = "RuntimeInitFailed";
      return false;
     }

   symbol_runtime.OnTick();
   symbol_runtime.Shutdown();
   return true;
  }

void RunLiveExecutionOwnershipCycle(const int &scan_state_indexes[],
                                    int &out_attempted,
                                    int &out_success,
                                    int &out_failed,
                                    string &out_first_error_symbol,
                                    string &out_first_error)
  {
   out_attempted = 0;
   out_success = 0;
   out_failed = 0;
   out_first_error_symbol = "";
   out_first_error = "";

   if(!ShouldRunLivePortfolioExecution())
      return;
   if(g_global_pause_entries)
      return;

   const int max_symbols_per_cycle = MathMax(1, PortfolioMaxActiveTrades);
   for(int rank = 1; rank <= ArraySize(scan_state_indexes); ++rank)
     {
      if(out_attempted >= max_symbols_per_cycle)
         break;

      int state_index = -1;
      for(int i = 0; i < ArraySize(scan_state_indexes); ++i)
        {
         const int candidate_index = scan_state_indexes[i];
         if(candidate_index < 0 || candidate_index >= ArraySize(g_market_watch_scan_states))
            continue;
         if(g_market_watch_scan_states[candidate_index].ranking_order == rank)
           {
            state_index = candidate_index;
            break;
           }
        }
      if(state_index < 0)
         continue;

      MohyMarketWatchScanState state = g_market_watch_scan_states[state_index];
      if(!state.last_scan_ok)
         continue;
      if(!state.allocator_accepted)
         continue;
      if(!IsAllocatorActionableBucket(state.primary_bucket_id))
         continue;

      out_attempted++;
      string execution_error = "";
      if(ExecuteRuntimeForSymbol(state.symbol, execution_error))
        {
         state.ranking_diagnostics = StringFormat("%s|exec=ok", state.ranking_diagnostics);
         out_success++;
        }
      else
        {
         state.primary_bucket_id = (int)MOHY_BUCKET_BLOCKED_BY_RISK_OR_EXPOSURE;
         state.primary_bucket = MarketOpportunityBucketToString(MOHY_BUCKET_BLOCKED_BY_RISK_OR_EXPOSURE);
         state.bucket_reason = StringFormat("ExecutionFailed:%s", execution_error);
         state.ranking_diagnostics = StringFormat("%s|exec=failed:%s", state.ranking_diagnostics, execution_error);
         state.last_error = execution_error;
         out_failed++;
         if(out_first_error_symbol == "")
           {
            out_first_error_symbol = state.symbol;
            out_first_error = execution_error;
           }
        }

      g_market_watch_scan_states[state_index] = state;
     }
  }

void RecountCurrentBuckets(const int &scan_state_indexes[],
                           int &out_cpi,
                           int &out_cic,
                           int &out_waiting,
                           int &out_eligible,
                           int &out_open,
                           int &out_blocked,
                           int &out_rejected)
  {
   out_cpi = 0;
   out_cic = 0;
   out_waiting = 0;
   out_eligible = 0;
   out_open = 0;
   out_blocked = 0;
   out_rejected = 0;

   for(int i = 0; i < ArraySize(scan_state_indexes); ++i)
     {
      const int state_index = scan_state_indexes[i];
      if(state_index < 0 || state_index >= ArraySize(g_market_watch_scan_states))
         continue;
      if(!g_market_watch_scan_states[state_index].last_scan_ok)
         continue;

      switch((MohyMarketOpportunityBucket)g_market_watch_scan_states[state_index].primary_bucket_id)
        {
         case MOHY_BUCKET_CONFIRMED_POTENTIAL_IMPULSE:
            out_cpi++;
            break;
         case MOHY_BUCKET_CONFIRMED_IMPULSE_AND_CONFIRMED_CORRECTION:
            out_cic++;
            break;
         case MOHY_BUCKET_CONFIRMED_SETUP_WAITING_ENTRY:
            out_waiting++;
            break;
         case MOHY_BUCKET_ELIGIBLE_NOW:
            out_eligible++;
            break;
         case MOHY_BUCKET_ENTERED_OPEN_RUNNING:
            out_open++;
            break;
         case MOHY_BUCKET_BLOCKED_BY_RISK_OR_EXPOSURE:
            out_blocked++;
            break;
         default:
            out_rejected++;
            break;
        }
     }
  }

string JsonEscape(const string value)
  {
   string out = "";
   const int len = StringLen(value);
   for(int i = 0; i < len; ++i)
     {
      const int ch = StringGetCharacter(value, i);
      if(ch == '\\')
         out += "\\\\";
      else if(ch == '\"')
         out += "\\\"";
      else if(ch == '\n')
         out += "\\n";
      else if(ch == '\r')
         out += "\\r";
      else if(ch == '\t')
         out += "\\t";
      else if(ch < 32)
         out += " ";
      else
         out += StringSubstr(value, i, 1);
     }
   return out;
  }

string JsonDouble(const double value,
                  const int digits)
  {
   if(!MathIsValidNumber(value))
      return "0";
   string text = DoubleToString(value, digits);
   StringReplace(text, ",", ".");
   return text;
  }

bool WriteTextArtifact(const string path,
                       const string payload)
  {
   const int handle = FileOpen(path, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
      return false;

   FileWriteString(handle, payload);
   FileClose(handle);
   return true;
  }

string BuildPortfolioArtifactScopeTag()
  {
   string scope_symbol = "PORTFOLIO";
   if(ScanUniverseMode == MOHY_SCAN_UNIVERSE_CHART_SYMBOL_ONLY)
      scope_symbol = StringFormat("PORTFOLIO_%s", Symbol());

   return MohyRuntimeBuildScopeTag(scope_symbol,
                                   g_cfg.context_timeframe,
                                   g_cfg.execution_timeframe,
                                   g_cfg.risk.magic_number);
  }

string BuildPortfolioArtifactDirectory()
  {
   return StringFormat("MOHY\\runtime\\portfolio\\%s", BuildPortfolioArtifactScopeTag());
  }

void ResetPortfolioCycleMetrics()
  {
   g_portfolio_metrics.processed_symbols = 0;
   g_portfolio_metrics.scanned_ok = 0;
   g_portfolio_metrics.scanned_failed = 0;
   g_portfolio_metrics.selected_setups = 0;
   g_portfolio_metrics.bucket_cpi = 0;
   g_portfolio_metrics.bucket_cic = 0;
   g_portfolio_metrics.bucket_waiting = 0;
   g_portfolio_metrics.bucket_eligible = 0;
   g_portfolio_metrics.bucket_open = 0;
   g_portfolio_metrics.bucket_blocked = 0;
   g_portfolio_metrics.bucket_rejected = 0;
   g_portfolio_metrics.allocator_accepted = 0;
   g_portfolio_metrics.allocator_blocked = 0;
   g_portfolio_metrics.allocator_exposure_base_value = 0.0;
   g_portfolio_metrics.allocator_open_risk_percent = 0.0;
   g_portfolio_metrics.allocator_allocated_risk_percent = 0.0;
   g_portfolio_metrics.execution_attempted = 0;
   g_portfolio_metrics.execution_success = 0;
   g_portfolio_metrics.execution_failed = 0;
   g_portfolio_metrics.first_error_symbol = "";
   g_portfolio_metrics.first_error = "";
   g_portfolio_metrics.execution_first_error_symbol = "";
   g_portfolio_metrics.execution_first_error = "";
   g_portfolio_metrics.updated_at = 0;
  }

string GlobalPanelName(const string suffix)
  {
   return StringFormat("%s%s", g_global_panel_prefix, suffix);
  }

string CompactPanelText(const string value,
                        const int max_len)
  {
   if(max_len <= 3 || StringLen(value) <= max_len)
      return value;
   return StringFormat("%s...%s",
                       StringSubstr(value, 0, max_len - 3),
                       "");
  }

bool IsGlobalPanelRightCorner()
  {
   return (PanelCorner == CORNER_RIGHT_UPPER || PanelCorner == CORNER_RIGHT_LOWER);
  }

bool IsGlobalPanelLowerCorner()
  {
   return (PanelCorner == CORNER_LEFT_LOWER || PanelCorner == CORNER_RIGHT_LOWER);
  }

void ResolveGlobalPanelOrigin(const int panel_width,
                              const int panel_height,
                              int &out_x,
                              int &out_y)
  {
   out_x = PanelOffsetX;
   out_y = PanelOffsetY;

   long chart_width = 0;
   long chart_height = 0;
   if(!ChartGetInteger(ChartID(), CHART_WIDTH_IN_PIXELS, 0, chart_width) ||
      !ChartGetInteger(ChartID(), CHART_HEIGHT_IN_PIXELS, 0, chart_height))
      return;

   if(IsGlobalPanelRightCorner())
      out_x = MathMax(0, (int)chart_width - PanelOffsetX - panel_width);
   if(IsGlobalPanelLowerCorner())
      out_y = MathMax(0, (int)chart_height - PanelOffsetY - panel_height);
  }

void GlobalPanelUpsertRect(const string name,
                           const color fill_color,
                           const color border_color,
                           const int x,
                           const int y,
                           const int width,
                           const int height)
  {
   if(ObjectFind(ChartID(), name) < 0)
      ObjectCreate(ChartID(), name, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(ChartID(), name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(ChartID(), name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(ChartID(), name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(ChartID(), name, OBJPROP_XSIZE, width);
   ObjectSetInteger(ChartID(), name, OBJPROP_YSIZE, height);
   ObjectSetInteger(ChartID(), name, OBJPROP_BGCOLOR, fill_color);
   ObjectSetInteger(ChartID(), name, OBJPROP_COLOR, border_color);
   ObjectSetInteger(ChartID(), name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(ChartID(), name, OBJPROP_BACK, false);
   ObjectSetInteger(ChartID(), name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(ChartID(), name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(ChartID(), name, OBJPROP_SELECTED, false);
   ObjectSetInteger(ChartID(), name, OBJPROP_ZORDER, 0);
  }

void GlobalPanelUpsertLabel(const string name,
                            const string text,
                            const int x,
                            const int y,
                            const color text_color,
                            const int font_size,
                            const bool bold = false)
  {
   if(ObjectFind(ChartID(), name) < 0)
      ObjectCreate(ChartID(), name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(ChartID(), name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(ChartID(), name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(ChartID(), name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(ChartID(), name, OBJPROP_COLOR, text_color);
   ObjectSetInteger(ChartID(), name, OBJPROP_FONTSIZE, font_size);
   ObjectSetString(ChartID(), name, OBJPROP_FONT, bold ? "Consolas Bold" : "Consolas");
   ObjectSetString(ChartID(), name, OBJPROP_TEXT, text);
   ObjectSetInteger(ChartID(), name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(ChartID(), name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(ChartID(), name, OBJPROP_SELECTED, false);
   ObjectSetInteger(ChartID(), name, OBJPROP_ZORDER, 1);
  }

void GlobalPanelUpsertButton(const string name,
                             const string text,
                             const int x,
                             const int y,
                             const int width,
                             const int height,
                             const color bg_color,
                             const color text_color)
  {
   if(ObjectFind(ChartID(), name) < 0)
      ObjectCreate(ChartID(), name, OBJ_BUTTON, 0, 0, 0);

   ObjectSetInteger(ChartID(), name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(ChartID(), name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(ChartID(), name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(ChartID(), name, OBJPROP_XSIZE, width);
   ObjectSetInteger(ChartID(), name, OBJPROP_YSIZE, height);
   ObjectSetInteger(ChartID(), name, OBJPROP_BGCOLOR, bg_color);
   ObjectSetInteger(ChartID(), name, OBJPROP_COLOR, text_color);
   ObjectSetInteger(ChartID(), name, OBJPROP_FONTSIZE, 9);
   ObjectSetString(ChartID(), name, OBJPROP_FONT, "Consolas");
   ObjectSetString(ChartID(), name, OBJPROP_TEXT, text);
   ObjectSetInteger(ChartID(), name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(ChartID(), name, OBJPROP_ZORDER, 2);
  }

void ClearGlobalControlPanel()
  {
   if(g_global_panel_prefix == "")
      return;
   ObjectsDeleteAll(ChartID(), g_global_panel_prefix);
   ChartRedraw(ChartID());
  }

void ClearLegacyRuntimePanel()
  {
   const string legacy_prefix = StringFormat("MOHY_EA_%I64d_", ChartID());
   ObjectsDeleteAll(ChartID(), legacy_prefix);
  }

bool IsDangerousGlobalAction(const MohyUiActionId action_id)
  {
   return (action_id == MOHY_UI_ACTION_CANCEL_WAITING_ENTRIES ||
           action_id == MOHY_UI_ACTION_CLOSE_STRATEGY_TRADES ||
           action_id == MOHY_UI_ACTION_EMERGENCY_FLATTEN);
  }

int GlobalUiActionWindowSeconds()
  {
   return MathMax(1, DangerousActionCooldownSeconds);
  }

void ResetGlobalPendingAction()
  {
   g_global_pending_action.action_id = MOHY_UI_ACTION_NONE;
   g_global_pending_action.correlation_id = "";
   g_global_pending_action.pre_state_hash = "";
   g_global_pending_action.accepted_at = 0;
  }

bool GlobalPendingActionActive()
  {
   return (g_global_pending_action.action_id != MOHY_UI_ACTION_NONE);
  }

int GlobalPendingActionRemainingSeconds()
  {
   if(!GlobalPendingActionActive() || g_global_pending_action.accepted_at <= 0)
      return 0;

   const int elapsed = (int)(TimeCurrent() - g_global_pending_action.accepted_at);
   return MathMax(0, GlobalUiActionWindowSeconds() - elapsed);
  }

int GlobalDangerousCooldownRemainingSeconds()
  {
   if(g_global_last_dangerous_action_id == MOHY_UI_ACTION_NONE ||
      g_global_last_dangerous_action_time <= 0)
      return 0;

   const int elapsed = (int)(TimeCurrent() - g_global_last_dangerous_action_time);
   return MathMax(0, GlobalUiActionWindowSeconds() - elapsed);
  }

MohyUiAlertEventType GlobalSeverityFromResult(const MohyUiResultCode code)
  {
   if(code == MOHY_UI_RESULT_SUCCESS)
      return MOHY_UI_ALERT_INFO;
   if(code == MOHY_UI_RESULT_COOLDOWN_ACTIVE || code == MOHY_UI_RESULT_BLOCKED_BY_GUARD)
      return MOHY_UI_ALERT_WARNING;
   return MOHY_UI_ALERT_CRITICAL;
  }

string BuildGlobalUiStateHash()
  {
   uint hash = MohyRuntimeHashBegin();
   hash = MohyRuntimeHashUpdate(hash, IntegerToString((int)g_market_watch_scan_cycle));
   hash = MohyRuntimeHashUpdate(hash, IntegerToString(g_portfolio_metrics.bucket_cpi));
   hash = MohyRuntimeHashUpdate(hash, IntegerToString(g_portfolio_metrics.bucket_cic));
   hash = MohyRuntimeHashUpdate(hash, IntegerToString(g_portfolio_metrics.bucket_waiting));
   hash = MohyRuntimeHashUpdate(hash, IntegerToString(g_portfolio_metrics.bucket_eligible));
   hash = MohyRuntimeHashUpdate(hash, IntegerToString(g_portfolio_metrics.bucket_open));
   hash = MohyRuntimeHashUpdate(hash, IntegerToString(g_portfolio_metrics.bucket_blocked));
   hash = MohyRuntimeHashUpdate(hash, IntegerToString(g_portfolio_metrics.bucket_rejected));
   hash = MohyRuntimeHashUpdate(hash, MohyRuntimeBoolToString(g_global_pause_entries));
   hash = MohyRuntimeHashUpdate(hash, g_global_last_action_result);
   hash = MohyRuntimeHashUpdate(hash, MohyUiActionIdToString(g_global_pending_action.action_id));
   return MohyRuntimeHashHex(hash);
  }

string BuildGlobalCorrelationId(const MohyUiActionId action_id,
                                const string pre_state_hash)
  {
   uint hash = MohyRuntimeHashBegin();
   hash = MohyRuntimeHashUpdate(hash, MohyUiActionIdToString(action_id));
   hash = MohyRuntimeHashUpdate(hash, IntegerToString((int)TimeCurrent()));
   hash = MohyRuntimeHashUpdate(hash, pre_state_hash);
   return StringFormat("GLOBAL_%s_%d_%s",
                       MohyUiActionIdToString(action_id),
                       (int)TimeCurrent(),
                       MohyRuntimeHashHex(hash));
  }

void RecordGlobalUiAudit(const string stage,
                         const MohyUiActionId action_id,
                         const string correlation_id,
                         const string pre_state_hash,
                         const string post_state_hash,
                         const MohyUiResultCode result_code,
                         const MohyUiAlertEventType severity,
                         const int broker_error,
                         const string message)
  {
   g_portfolio_audit.LogUiAction(g_cfg,
                                 Symbol(),
                                 stage,
                                 action_id,
                                 correlation_id,
                                 pre_state_hash,
                                 post_state_hash,
                                 result_code,
                                 severity,
                                 broker_error,
                                 message,
                                 "TradeEA_GlobalPanel");
  }

void ExpireGlobalPendingActionIfNeeded()
  {
   if(!GlobalPendingActionActive() || GlobalPendingActionRemainingSeconds() > 0)
      return;

   const string post_hash = BuildGlobalUiStateHash();
   RecordGlobalUiAudit("Expired",
                       g_global_pending_action.action_id,
                       g_global_pending_action.correlation_id,
                       g_global_pending_action.pre_state_hash,
                       post_hash,
                       MOHY_UI_RESULT_CONFIRMATION_EXPIRED,
                       GlobalSeverityFromResult(MOHY_UI_RESULT_CONFIRMATION_EXPIRED),
                       0,
                       "ConfirmationExpired");
   g_global_last_action_result = StringFormat("%sExpired",
                                              MohyUiActionIdToString(g_global_pending_action.action_id));
   ResetGlobalPendingAction();
  }

string ResolveGlobalConfirmationState()
  {
   if(GlobalPendingActionActive())
      return StringFormat("Confirm %s (%ds)",
                          MohyUiActionIdToString(g_global_pending_action.action_id),
                          GlobalPendingActionRemainingSeconds());

   const int cooldown = GlobalDangerousCooldownRemainingSeconds();
   if(cooldown > 0 && g_global_last_dangerous_action_id != MOHY_UI_ACTION_NONE)
      return StringFormat("Cooldown %s (%ds)",
                          MohyUiActionIdToString(g_global_last_dangerous_action_id),
                          cooldown);

   return "Ready";
  }

string ResolveActionObjectSuffix(const MohyUiActionId action_id)
  {
   if(action_id == MOHY_UI_ACTION_PAUSE_ENTRIES)
      return "BTN_PAUSE";
   if(action_id == MOHY_UI_ACTION_RESUME_ENTRIES)
      return "BTN_RESUME";
   if(action_id == MOHY_UI_ACTION_CANCEL_WAITING_ENTRIES)
      return "BTN_CANCEL_WAITING";
   if(action_id == MOHY_UI_ACTION_CLOSE_STRATEGY_TRADES)
      return "BTN_CLOSE_TRADES";
   if(action_id == MOHY_UI_ACTION_EMERGENCY_FLATTEN)
      return "BTN_FLATTEN";
   return "";
  }

bool TriggerSymbolRuntimeUiAction(const string symbol,
                                  const MohyUiActionId action_id,
                                  string &out_error)
  {
   out_error = "";
   if(symbol == "")
     {
      out_error = "EmptySymbol";
      return false;
     }

   const string suffix = ResolveActionObjectSuffix(action_id);
   if(suffix == "")
     {
      out_error = "UnsupportedAction";
      return false;
     }

   if(!SymbolSelect(symbol, true))
     {
      out_error = "SymbolSelectFailed";
      return false;
     }

   StrategyConfig symbol_cfg = g_cfg;
   symbol_cfg.symbol = symbol;

   CMohyRuntimeEngine symbol_runtime;
   symbol_runtime.Configure(symbol_cfg,
                            symbol,
                            LookbackBars,
                            false,
                            (int)PanelCorner,
                            PanelOffsetX,
                            PanelOffsetY,
                            MOHY_RUNTIME_ROLE_GLOBAL_LIVE);
   if(!symbol_runtime.Initialize())
     {
      out_error = "RuntimeInitFailed";
      return false;
     }

   const string object_name = StringFormat("MOHY_EA_%I64d_%s", ChartID(), suffix);
   const long click_lparam = 0;
   const double click_dparam = 0.0;
   symbol_runtime.OnChartEvent(CHARTEVENT_OBJECT_CLICK, click_lparam, click_dparam, object_name);
   if(IsDangerousGlobalAction(action_id))
      symbol_runtime.OnChartEvent(CHARTEVENT_OBJECT_CLICK, click_lparam, click_dparam, object_name);
   symbol_runtime.Shutdown();
   return true;
  }

void CollectScannedSymbols(string &out_symbols[])
  {
   ArrayResize(out_symbols, 0);
   for(int i = 0; i < ArraySize(g_market_watch_scan_states); ++i)
     {
      const MohyMarketWatchScanState state = g_market_watch_scan_states[i];
      if(state.symbol == "")
         continue;
      if(!state.last_scan_ok)
         continue;

      const int next = ArraySize(out_symbols);
      ArrayResize(out_symbols, next + 1);
      out_symbols[next] = state.symbol;
     }

   if(ArraySize(out_symbols) == 0)
     {
      ArrayResize(out_symbols, 1);
      out_symbols[0] = Symbol();
     }
  }

void ExecuteGlobalUiAction(const MohyUiActionId action_id,
                           MohyUiResultCode &out_result_code,
                           string &out_message)
  {
   out_result_code = MOHY_UI_RESULT_FAILED;
   out_message = "ActionFailed";

   if(RuntimeRoleMode != MOHY_RUNTIME_ROLE_GLOBAL_LIVE)
     {
      out_result_code = MOHY_UI_RESULT_DENIED_BY_AUTHORITY;
      out_message = "GlobalPanelRequiresGlobalLive";
      return;
     }

   if(action_id == MOHY_UI_ACTION_PAUSE_ENTRIES ||
      action_id == MOHY_UI_ACTION_RESUME_ENTRIES)
     {
      g_global_pause_entries = (action_id == MOHY_UI_ACTION_PAUSE_ENTRIES);
      out_result_code = MOHY_UI_RESULT_SUCCESS;
      out_message = (action_id == MOHY_UI_ACTION_PAUSE_ENTRIES)
                    ? "EntriesPaused"
                    : "EntriesResumed";
      return;
     }

   string symbols[];
   CollectScannedSymbols(symbols);
   int dispatched_ok = 0;
   int dispatched_failed = 0;
   string first_error = "";

   for(int i = 0; i < ArraySize(symbols); ++i)
     {
      string dispatch_error = "";
      if(TriggerSymbolRuntimeUiAction(symbols[i], action_id, dispatch_error))
         dispatched_ok++;
      else
        {
         dispatched_failed++;
         if(first_error == "")
            first_error = StringFormat("%s:%s", symbols[i], dispatch_error);
        }
     }

   if(action_id == MOHY_UI_ACTION_EMERGENCY_FLATTEN)
      g_global_pause_entries = true;

   if(dispatched_failed == 0)
      out_result_code = MOHY_UI_RESULT_SUCCESS;
   else
      out_result_code = MOHY_UI_RESULT_FAILED;

   out_message = StringFormat("Dispatch %s ok=%d failed=%d%s",
                              MohyUiActionIdToString(action_id),
                              dispatched_ok,
                              dispatched_failed,
                              (first_error == "" ? "" : StringFormat(" first=%s", first_error)));
  }

void HandleGlobalUiAction(const MohyUiActionId action_id)
  {
   ExpireGlobalPendingActionIfNeeded();

   const string pre_hash = BuildGlobalUiStateHash();
   const string action_name = MohyUiActionIdToString(action_id);

   if(IsDangerousGlobalAction(action_id))
     {
      const int cooldown = GlobalDangerousCooldownRemainingSeconds();
      if(cooldown > 0)
        {
         const string message = StringFormat("CooldownActive %ds", cooldown);
         RecordGlobalUiAudit("Outcome",
                             action_id,
                             "",
                             pre_hash,
                             BuildGlobalUiStateHash(),
                             MOHY_UI_RESULT_COOLDOWN_ACTIVE,
                             GlobalSeverityFromResult(MOHY_UI_RESULT_COOLDOWN_ACTIVE),
                             0,
                             message);
         g_global_last_action_result = StringFormat("%s %s", action_name, message);
         return;
        }

      if(!GlobalPendingActionActive() || g_global_pending_action.action_id != action_id)
        {
         g_global_pending_action.action_id = action_id;
         g_global_pending_action.accepted_at = TimeCurrent();
         g_global_pending_action.pre_state_hash = pre_hash;
         g_global_pending_action.correlation_id = BuildGlobalCorrelationId(action_id, pre_hash);
         RecordGlobalUiAudit("Intent",
                             action_id,
                             g_global_pending_action.correlation_id,
                             pre_hash,
                             pre_hash,
                             MOHY_UI_RESULT_SUCCESS,
                             GlobalSeverityFromResult(MOHY_UI_RESULT_SUCCESS),
                             0,
                             "DangerousActionIntentStaged");
         g_global_last_action_result = StringFormat("Confirm %s (%ds)",
                                                    action_name,
                                                    GlobalPendingActionRemainingSeconds());
         return;
        }

      if(GlobalPendingActionRemainingSeconds() <= 0)
        {
         const string message = "ConfirmationExpired";
         RecordGlobalUiAudit("Expired",
                             action_id,
                             g_global_pending_action.correlation_id,
                             g_global_pending_action.pre_state_hash,
                             BuildGlobalUiStateHash(),
                             MOHY_UI_RESULT_CONFIRMATION_EXPIRED,
                             GlobalSeverityFromResult(MOHY_UI_RESULT_CONFIRMATION_EXPIRED),
                             0,
                             message);
         g_global_last_action_result = StringFormat("%s %s", action_name, message);
         ResetGlobalPendingAction();
         return;
        }
     }

   const string correlation_id = IsDangerousGlobalAction(action_id)
                                 ? g_global_pending_action.correlation_id
                                 : BuildGlobalCorrelationId(action_id, pre_hash);
   RecordGlobalUiAudit("Confirmed",
                       action_id,
                       correlation_id,
                       pre_hash,
                       pre_hash,
                       MOHY_UI_RESULT_SUCCESS,
                       GlobalSeverityFromResult(MOHY_UI_RESULT_SUCCESS),
                       0,
                       "ActionConfirmed");

   MohyUiResultCode result_code = MOHY_UI_RESULT_FAILED;
   string message = "";
   ExecuteGlobalUiAction(action_id, result_code, message);

   const MohyUiAlertEventType severity = GlobalSeverityFromResult(result_code);
   const string post_hash = BuildGlobalUiStateHash();
   RecordGlobalUiAudit("Outcome",
                       action_id,
                       correlation_id,
                       pre_hash,
                       post_hash,
                       result_code,
                       severity,
                       0,
                       message);

   if(IsDangerousGlobalAction(action_id) &&
      result_code == MOHY_UI_RESULT_SUCCESS)
     {
      g_global_last_dangerous_action_id = action_id;
      g_global_last_dangerous_action_time = TimeCurrent();
     }

   g_global_last_action_result = StringFormat("%s %s", action_name, message);
   ResetGlobalPendingAction();
  }

bool HandleGlobalPanelChartEvent(const int id,
                                 const string sparam,
                                 MohyUiActionId &out_action)
  {
   out_action = MOHY_UI_ACTION_NONE;
   if(id != CHARTEVENT_OBJECT_CLICK)
      return false;

   if(sparam == GlobalPanelName("BTN_PAUSE"))
     {
      out_action = MOHY_UI_ACTION_PAUSE_ENTRIES;
      return true;
     }
   if(sparam == GlobalPanelName("BTN_RESUME"))
     {
      out_action = MOHY_UI_ACTION_RESUME_ENTRIES;
      return true;
     }
   if(sparam == GlobalPanelName("BTN_CANCEL_WAITING"))
     {
      out_action = MOHY_UI_ACTION_CANCEL_WAITING_ENTRIES;
      return true;
     }
   if(sparam == GlobalPanelName("BTN_CLOSE_TRADES"))
     {
      out_action = MOHY_UI_ACTION_CLOSE_STRATEGY_TRADES;
      return true;
     }
   if(sparam == GlobalPanelName("BTN_FLATTEN"))
     {
      out_action = MOHY_UI_ACTION_EMERGENCY_FLATTEN;
      return true;
     }
   return false;
  }

void RenderGlobalControlPanel()
  {
   if(!EnableGlobalControlPanel)
     {
      ClearGlobalControlPanel();
      return;
     }

   const int top_rows = MathMax(1, MathMin(8, GlobalPanelTopRows));
   const int panel_width = 520;
   const int panel_height = 320 + (top_rows * 18);
   int panel_x = PanelOffsetX;
   int panel_y = PanelOffsetY;
   ResolveGlobalPanelOrigin(panel_width, panel_height, panel_x, panel_y);

   string panel_hash = "";
   panel_hash += IntegerToString((int)g_market_watch_scan_cycle);
   panel_hash += "|" + IntegerToString(g_portfolio_metrics.bucket_cpi);
   panel_hash += "|" + IntegerToString(g_portfolio_metrics.bucket_cic);
   panel_hash += "|" + IntegerToString(g_portfolio_metrics.bucket_waiting);
   panel_hash += "|" + IntegerToString(g_portfolio_metrics.bucket_eligible);
   panel_hash += "|" + IntegerToString(g_portfolio_metrics.bucket_open);
   panel_hash += "|" + IntegerToString(g_portfolio_metrics.bucket_blocked);
   panel_hash += "|" + IntegerToString(g_portfolio_metrics.bucket_rejected);
   panel_hash += "|" + ScanUniverseModeToString(ScanUniverseMode);
   panel_hash += "|" + g_global_last_action_result;
   panel_hash += "|" + ResolveGlobalConfirmationState();
   panel_hash += "|" + MohyRuntimeBoolToString(g_global_pause_entries);

   const uint now_ms = GetTickCount();
   const int throttle_ms = MathMax(0, UiRedrawThrottleMs);
   const bool should_render = (panel_hash != g_global_last_panel_snapshot_hash ||
                               throttle_ms <= 0 ||
                               (now_ms - g_global_last_panel_redraw_ms) >= (uint)throttle_ms);
   if(!should_render)
      return;

   g_global_last_panel_snapshot_hash = panel_hash;
   g_global_last_panel_redraw_ms = now_ms;

   const color fill_color = C'245,247,250';
   const color border_color = C'80,95,110';
   GlobalPanelUpsertRect(GlobalPanelName("PANEL_BG"),
                         fill_color,
                         border_color,
                         panel_x,
                         panel_y,
                         panel_width,
                         panel_height);
   GlobalPanelUpsertLabel(GlobalPanelName("TITLE"),
                          "MOHY TradeEA Global Panel",
                          panel_x + 12,
                          panel_y + 8,
                          clrBlack,
                          11,
                          true);

   GlobalPanelUpsertLabel(GlobalPanelName("LINE1"),
                          StringFormat("Role: %s | LiveOwnership: %s | Scope: %s | Entries: %s",
                                       MohyRuntimeRoleModeToString(RuntimeRoleMode),
                                       ShouldRunLivePortfolioExecution() ? "On" : "Off",
                                       ScanUniverseModeToString(ScanUniverseMode),
                                       g_global_pause_entries ? "Paused" : "Active"),
                          panel_x + 12,
                          panel_y + 30,
                          clrBlack,
                          9);
   GlobalPanelUpsertLabel(GlobalPanelName("LINE2"),
                          StringFormat("Cycle: %I64u | Symbols: %d ok=%d fail=%d selected=%d",
                                       g_market_watch_scan_cycle,
                                       g_portfolio_metrics.processed_symbols,
                                       g_portfolio_metrics.scanned_ok,
                                       g_portfolio_metrics.scanned_failed,
                                       g_portfolio_metrics.selected_setups),
                          panel_x + 12,
                          panel_y + 48,
                          clrBlack,
                          9);
   GlobalPanelUpsertLabel(GlobalPanelName("LINE3"),
                          StringFormat("Buckets: CPI=%d CIC=%d W=%d E=%d O=%d B=%d R=%d",
                                       g_portfolio_metrics.bucket_cpi,
                                       g_portfolio_metrics.bucket_cic,
                                       g_portfolio_metrics.bucket_waiting,
                                       g_portfolio_metrics.bucket_eligible,
                                       g_portfolio_metrics.bucket_open,
                                       g_portfolio_metrics.bucket_blocked,
                                       g_portfolio_metrics.bucket_rejected),
                          panel_x + 12,
                          panel_y + 66,
                          clrBlack,
                          9);
   GlobalPanelUpsertLabel(GlobalPanelName("LINE4"),
                          StringFormat("Alloc: A=%d Blk=%d OpenRisk=%.3f%% TotalRisk=%.3f%% Max=%.3f%%",
                                       g_portfolio_metrics.allocator_accepted,
                                       g_portfolio_metrics.allocator_blocked,
                                       g_portfolio_metrics.allocator_open_risk_percent,
                                       g_portfolio_metrics.allocator_allocated_risk_percent,
                                       g_cfg.risk.max_concurrent_risk_percent),
                          panel_x + 12,
                          panel_y + 84,
                          clrBlack,
                          9);
   GlobalPanelUpsertLabel(GlobalPanelName("LINE5"),
                          StringFormat("Exec: Att=%d Ok=%d Fail=%d",
                                       g_portfolio_metrics.execution_attempted,
                                       g_portfolio_metrics.execution_success,
                                       g_portfolio_metrics.execution_failed),
                          panel_x + 12,
                          panel_y + 102,
                          clrBlack,
                          9);
   GlobalPanelUpsertLabel(GlobalPanelName("LINE6"),
                          StringFormat("Confirm: %s",
                                       CompactPanelText(ResolveGlobalConfirmationState(), 52)),
                          panel_x + 12,
                          panel_y + 120,
                          clrBlack,
                          8);
   GlobalPanelUpsertLabel(GlobalPanelName("LINE7"),
                          StringFormat("Last: %s",
                                       CompactPanelText(g_global_last_action_result, 56)),
                          panel_x + 12,
                          panel_y + 138,
                          clrBlack,
                          8);

   const int row_start_y = panel_y + 160;
   for(int row = 0; row < top_rows; ++row)
     {
      string row_text = "-";
      const int rank = row + 1;
      for(int i = 0; i < ArraySize(g_market_watch_scan_states); ++i)
        {
         const MohyMarketWatchScanState state = g_market_watch_scan_states[i];
         if(!state.last_scan_ok)
            continue;
         if(state.ranking_order != rank)
            continue;
         row_text = StringFormat("%d) %s | %s | score=%.1f | alloc=%s",
                                 rank,
                                 state.symbol,
                                 state.primary_bucket,
                                 state.ranking_score,
                                 state.allocator_accepted ? "A" : "NA");
         break;
        }

      GlobalPanelUpsertLabel(GlobalPanelName(StringFormat("ROW%d", rank)),
                             CompactPanelText(row_text, 78),
                             panel_x + 12,
                             row_start_y + (row * 18),
                             clrBlack,
                             8);
     }

   const int button_y = row_start_y + (top_rows * 18) + 8;
   GlobalPanelUpsertButton(GlobalPanelName("BTN_PAUSE"),
                           "Pause",
                           panel_x + 12,
                           button_y,
                           90,
                           24,
                           C'210,90,90',
                           clrWhite);
   GlobalPanelUpsertButton(GlobalPanelName("BTN_RESUME"),
                           "Resume",
                           panel_x + 112,
                           button_y,
                           90,
                           24,
                           C'76,175,80',
                           clrWhite);
   GlobalPanelUpsertButton(GlobalPanelName("BTN_CANCEL_WAITING"),
                           "Cancel Waiting",
                           panel_x + 212,
                           button_y,
                           130,
                           24,
                           C'244,180,0',
                           clrBlack);
   GlobalPanelUpsertButton(GlobalPanelName("BTN_CLOSE_TRADES"),
                           "Close Trades",
                           panel_x + 352,
                           button_y,
                           150,
                           24,
                           C'255,138,101',
                           clrBlack);
   GlobalPanelUpsertButton(GlobalPanelName("BTN_FLATTEN"),
                           "Emergency Flat",
                           panel_x + 12,
                           button_y + 28,
                           190,
                           24,
                           C'183,28,28',
                           clrWhite);
  }

void PublishArtifactBus(const int &scan_state_indexes[],
                        const int processed_symbols,
                        const int scanned_ok,
                        const int scanned_failed,
                        const int symbols_with_selected_setup,
                        const int bucket_confirmed_potential_impulse,
                        const int bucket_confirmed_impulse_and_confirmed_correction,
                        const int bucket_confirmed_setup_waiting_entry,
                        const int bucket_eligible_now,
                        const int bucket_entered_open_running,
                        const int bucket_blocked_by_risk_or_exposure,
                        const int bucket_rejected_or_invalidated,
                        const int allocator_accepted,
                        const int allocator_blocked,
                        const double allocator_exposure_base_value,
                        const double allocator_open_risk_percent,
                        const double allocator_allocated_risk_percent,
                        const int execution_attempted,
                        const int execution_success,
                        const int execution_failed,
                        const string first_error_symbol,
                        const string first_error,
                        const string execution_first_error_symbol,
                        const string execution_first_error)
  {
   if(!EnableArtifactBus)
      return;

   const string artifact_dir = BuildPortfolioArtifactDirectory();
   if(!MohyRuntimeEnsureDirectory(artifact_dir))
      return;

   const datetime now = TimeCurrent();
   const string scope_tag = BuildPortfolioArtifactScopeTag();
   const string config_hash = MohyRuntimeBuildConfigHash(g_cfg);
   const string runtime_role = MohyRuntimeRoleModeToString(RuntimeRoleMode);
   const string panel_role = MohyRuntimeRoleModeToString(g_panel_runtime_role);
   const string context_tf = MohyTimeframeToString(g_cfg.context_timeframe);
   const string execution_tf = MohyTimeframeToString(g_cfg.execution_timeframe);

   string symbols_json = "";
   bool first_symbol = true;
   for(int i = 0; i < ArraySize(scan_state_indexes); ++i)
     {
      const int state_index = scan_state_indexes[i];
      if(state_index < 0 || state_index >= ArraySize(g_market_watch_scan_states))
         continue;

      const MohyMarketWatchScanState state = g_market_watch_scan_states[state_index];
      if(state.symbol == "")
         continue;

      string symbol_json = "{";
      symbol_json += "\"schema_version\":\"tradeea_live_snapshot_v1\",";
      symbol_json += "\"artifact_type\":\"live_snapshot\",";
      symbol_json += "\"run_id\":\"" + JsonEscape(g_artifact_run_id) + "\",";
      symbol_json += "\"written_at\":" + IntegerToString((int)now) + ",";
      symbol_json += "\"scanner_cycle\":" + IntegerToString((int)g_market_watch_scan_cycle) + ",";
      symbol_json += "\"scope_tag\":\"" + JsonEscape(scope_tag) + "\",";
      symbol_json += "\"scan_universe_mode\":\"" + JsonEscape(ScanUniverseModeToString(ScanUniverseMode)) + "\",";
      symbol_json += "\"config_hash\":\"" + JsonEscape(config_hash) + "\",";
      symbol_json += "\"runtime_role\":\"" + JsonEscape(runtime_role) + "\",";
      symbol_json += "\"panel_role\":\"" + JsonEscape(panel_role) + "\",";
      symbol_json += "\"live_ownership_enabled\":" + MohyRuntimeBoolToString(ShouldRunLivePortfolioExecution()) + ",";
      symbol_json += "\"symbol\":\"" + JsonEscape(state.symbol) + "\",";
      symbol_json += "\"context_timeframe\":\"" + JsonEscape(context_tf) + "\",";
      symbol_json += "\"execution_timeframe\":\"" + JsonEscape(execution_tf) + "\",";
      symbol_json += "\"last_scan_time\":" + IntegerToString((int)state.last_scan_time) + ",";
      symbol_json += "\"last_scan_ok\":" + MohyRuntimeBoolToString(state.last_scan_ok) + ",";
      symbol_json += "\"publishes_execution_stage_facts\":" + MohyRuntimeBoolToString(state.publishes_execution_stage_facts) + ",";
      symbol_json += "\"primary_bucket\":\"" + JsonEscape(state.primary_bucket) + "\",";
      symbol_json += "\"bucket_reason\":\"" + JsonEscape(state.bucket_reason) + "\",";
      symbol_json += "\"counts\":{";
      symbol_json += "\"bars\":" + IntegerToString(state.bars) + ",";
      symbol_json += "\"impulses\":" + IntegerToString(state.impulse_count) + ",";
      symbol_json += "\"corrections\":" + IntegerToString(state.correction_count) + ",";
      symbol_json += "\"continuations\":" + IntegerToString(state.continuation_count) + ",";
      symbol_json += "\"setup_plans\":" + IntegerToString(state.setup_plan_count);
      symbol_json += "},";
      symbol_json += "\"selected_plan\":{";
      symbol_json += "\"index\":" + IntegerToString(state.selected_plan_index) + ",";
      symbol_json += "\"state\":\"" + JsonEscape(state.selected_plan_state) + "\",";
      symbol_json += "\"valid\":" + MohyRuntimeBoolToString(state.selected_plan_valid) + ",";
      symbol_json += "\"setup_key\":\"" + JsonEscape(state.selected_plan_setup_key) + "\",";
      symbol_json += "\"impulse_id\":\"" + JsonEscape(state.selected_plan_impulse_id) + "\",";
      symbol_json += "\"direction\":\"" + JsonEscape(state.selected_plan_direction) + "\",";
      symbol_json += "\"execution_mode\":\"" + JsonEscape(state.selected_plan_execution_mode) + "\",";
      symbol_json += "\"setup_time\":" + IntegerToString((int)state.selected_plan_setup_time) + ",";
      symbol_json += "\"entry_price\":" + JsonDouble(state.selected_plan_entry_price, 8) + ",";
      symbol_json += "\"expected_fill_price\":" + JsonDouble(state.selected_plan_expected_fill_price, 8) + ",";
      symbol_json += "\"required_entry_price\":" + JsonDouble(state.selected_plan_required_entry_price, 8) + ",";
      symbol_json += "\"trigger_price\":" + JsonDouble(state.selected_plan_trigger_price, 8) + ",";
      symbol_json += "\"stop_price\":" + JsonDouble(state.selected_plan_stop_price, 8) + ",";
      symbol_json += "\"target_price\":" + JsonDouble(state.selected_plan_target_price, 8) + ",";
      symbol_json += "\"risk_money\":" + JsonDouble(state.selected_plan_risk_money, 8) + ",";
      symbol_json += "\"reward_to_risk\":" + JsonDouble(state.selected_plan_reward_to_risk, 8) + ",";
      symbol_json += "\"lots_normalized\":" + JsonDouble(state.selected_plan_lots_normalized, 8) + ",";
      symbol_json += "\"exposure_pass\":" + MohyRuntimeBoolToString(state.selected_plan_exposure_pass) + ",";
      symbol_json += "\"reject_reason\":\"" + JsonEscape(MohyRejectReasonToString(state.selected_plan_reject_reason)) + "\"";
      symbol_json += "},";
      symbol_json += "\"ranking\":{";
      symbol_json += "\"order\":" + IntegerToString(state.ranking_order) + ",";
      symbol_json += "\"bucket_priority\":" + IntegerToString(state.ranking_bucket_priority) + ",";
      symbol_json += "\"score\":" + JsonDouble(state.ranking_score, 6) + ",";
      symbol_json += "\"selection_rank\":" + IntegerToString(state.ranking_plan_selection_rank) + ",";
      symbol_json += "\"plan_setup_time\":" + IntegerToString((int)state.ranking_plan_setup_time);
      symbol_json += "},";
      symbol_json += "\"allocator\":{";
      symbol_json += "\"accepted\":" + MohyRuntimeBoolToString(state.allocator_accepted) + ",";
      symbol_json += "\"decision\":\"" + JsonEscape(state.allocator_decision) + "\",";
      symbol_json += "\"candidate_risk_percent\":" + JsonDouble(state.allocator_candidate_risk_percent, 6);
      symbol_json += "},";
      symbol_json += "\"diagnostics\":\"" + JsonEscape(state.ranking_diagnostics) + "\",";
      symbol_json += "\"last_error\":\"" + JsonEscape(state.last_error) + "\"";
      symbol_json += "}";

      const string snapshot_path = StringFormat("%s\\live_snapshot_%s.json",
                                                artifact_dir,
                                                MohyRuntimeSanitizeToken(state.symbol));
      WriteTextArtifact(snapshot_path, symbol_json);

      if(!first_symbol)
         symbols_json += ",";
      first_symbol = false;

      symbols_json += "{";
      symbols_json += "\"symbol\":\"" + JsonEscape(state.symbol) + "\",";
      symbols_json += "\"bucket\":\"" + JsonEscape(state.primary_bucket) + "\",";
      symbols_json += "\"bucket_reason\":\"" + JsonEscape(state.bucket_reason) + "\",";
      symbols_json += "\"ranking_order\":" + IntegerToString(state.ranking_order) + ",";
      symbols_json += "\"ranking_score\":" + JsonDouble(state.ranking_score, 6) + ",";
      symbols_json += "\"selected_plan_state\":\"" + JsonEscape(state.selected_plan_state) + "\",";
      symbols_json += "\"selected_setup_key\":\"" + JsonEscape(state.selected_plan_setup_key) + "\",";
      symbols_json += "\"selected_impulse_id\":\"" + JsonEscape(state.selected_plan_impulse_id) + "\",";
      symbols_json += "\"selected_entry_price\":" + JsonDouble(state.selected_plan_entry_price, 8) + ",";
      symbols_json += "\"selected_stop_price\":" + JsonDouble(state.selected_plan_stop_price, 8) + ",";
      symbols_json += "\"selected_target_price\":" + JsonDouble(state.selected_plan_target_price, 8) + ",";
      symbols_json += "\"allocator_accepted\":" + MohyRuntimeBoolToString(state.allocator_accepted) + ",";
      symbols_json += "\"allocator_decision\":\"" + JsonEscape(state.allocator_decision) + "\",";
      symbols_json += "\"last_scan_ok\":" + MohyRuntimeBoolToString(state.last_scan_ok);
      symbols_json += "}";
     }

   string top_ranked_json = "";
   bool first_top = true;
   const int top_n = MathMax(0, ScannerLogTopRanks);
   for(int rank = 1; rank <= top_n; ++rank)
     {
      int rank_state_index = -1;
      for(int i = 0; i < ArraySize(scan_state_indexes); ++i)
        {
         const int state_index = scan_state_indexes[i];
         if(state_index < 0 || state_index >= ArraySize(g_market_watch_scan_states))
            continue;
         if(g_market_watch_scan_states[state_index].ranking_order == rank)
           {
            rank_state_index = state_index;
            break;
           }
        }
      if(rank_state_index < 0)
         break;

      const MohyMarketWatchScanState ranked_state = g_market_watch_scan_states[rank_state_index];
      if(!first_top)
         top_ranked_json += ",";
      first_top = false;
      top_ranked_json += "{";
      top_ranked_json += "\"rank\":" + IntegerToString(rank) + ",";
      top_ranked_json += "\"symbol\":\"" + JsonEscape(ranked_state.symbol) + "\",";
      top_ranked_json += "\"bucket\":\"" + JsonEscape(ranked_state.primary_bucket) + "\",";
      top_ranked_json += "\"score\":" + JsonDouble(ranked_state.ranking_score, 6) + ",";
      top_ranked_json += "\"setup_key\":\"" + JsonEscape(ranked_state.selected_plan_setup_key) + "\"";
      top_ranked_json += "}";
     }

   string portfolio_json = "{";
   portfolio_json += "\"schema_version\":\"tradeea_portfolio_state_v1\",";
   portfolio_json += "\"artifact_type\":\"portfolio_state\",";
   portfolio_json += "\"run_id\":\"" + JsonEscape(g_artifact_run_id) + "\",";
   portfolio_json += "\"written_at\":" + IntegerToString((int)now) + ",";
   portfolio_json += "\"scanner_cycle\":" + IntegerToString((int)g_market_watch_scan_cycle) + ",";
   portfolio_json += "\"scope_tag\":\"" + JsonEscape(scope_tag) + "\",";
   portfolio_json += "\"scan_universe_mode\":\"" + JsonEscape(ScanUniverseModeToString(ScanUniverseMode)) + "\",";
   portfolio_json += "\"config_hash\":\"" + JsonEscape(config_hash) + "\",";
   portfolio_json += "\"symbol_anchor\":\"" + JsonEscape(Symbol()) + "\",";
   portfolio_json += "\"context_timeframe\":\"" + JsonEscape(context_tf) + "\",";
   portfolio_json += "\"execution_timeframe\":\"" + JsonEscape(execution_tf) + "\",";
   portfolio_json += "\"runtime_role\":\"" + JsonEscape(runtime_role) + "\",";
   portfolio_json += "\"panel_role\":\"" + JsonEscape(panel_role) + "\",";
   portfolio_json += "\"live_ownership_enabled\":" + MohyRuntimeBoolToString(ShouldRunLivePortfolioExecution()) + ",";
   portfolio_json += "\"summary\":{";
   portfolio_json += "\"symbols_total\":" + IntegerToString(processed_symbols) + ",";
   portfolio_json += "\"scanned_ok\":" + IntegerToString(scanned_ok) + ",";
   portfolio_json += "\"scanned_failed\":" + IntegerToString(scanned_failed) + ",";
   portfolio_json += "\"selected_setups\":" + IntegerToString(symbols_with_selected_setup);
   portfolio_json += "},";
   portfolio_json += "\"buckets\":{";
   portfolio_json += "\"confirmed_potential_impulse\":" + IntegerToString(bucket_confirmed_potential_impulse) + ",";
   portfolio_json += "\"confirmed_impulse_and_confirmed_correction\":" + IntegerToString(bucket_confirmed_impulse_and_confirmed_correction) + ",";
   portfolio_json += "\"confirmed_setup_waiting_entry\":" + IntegerToString(bucket_confirmed_setup_waiting_entry) + ",";
   portfolio_json += "\"eligible_now\":" + IntegerToString(bucket_eligible_now) + ",";
   portfolio_json += "\"entered_open_running\":" + IntegerToString(bucket_entered_open_running) + ",";
   portfolio_json += "\"blocked_by_risk_or_exposure\":" + IntegerToString(bucket_blocked_by_risk_or_exposure) + ",";
   portfolio_json += "\"rejected_or_invalidated\":" + IntegerToString(bucket_rejected_or_invalidated);
   portfolio_json += "},";
   portfolio_json += "\"allocator\":{";
   portfolio_json += "\"accepted\":" + IntegerToString(allocator_accepted) + ",";
   portfolio_json += "\"blocked\":" + IntegerToString(allocator_blocked) + ",";
   portfolio_json += "\"open_risk_percent\":" + JsonDouble(allocator_open_risk_percent, 6) + ",";
   portfolio_json += "\"total_risk_percent\":" + JsonDouble(allocator_allocated_risk_percent, 6) + ",";
   portfolio_json += "\"max_risk_percent\":" + JsonDouble(g_cfg.risk.max_concurrent_risk_percent, 6) + ",";
   portfolio_json += "\"exposure_base_value\":" + JsonDouble(allocator_exposure_base_value, 6);
   portfolio_json += "},";
   portfolio_json += "\"execution\":{";
   portfolio_json += "\"attempted\":" + IntegerToString(execution_attempted) + ",";
   portfolio_json += "\"success\":" + IntegerToString(execution_success) + ",";
   portfolio_json += "\"failed\":" + IntegerToString(execution_failed) + ",";
   portfolio_json += "\"first_error_symbol\":\"" + JsonEscape(execution_first_error_symbol) + "\",";
   portfolio_json += "\"first_error\":\"" + JsonEscape(execution_first_error) + "\"";
   portfolio_json += "},";
   portfolio_json += "\"scanner_first_error\":{";
   portfolio_json += "\"symbol\":\"" + JsonEscape(first_error_symbol) + "\",";
   portfolio_json += "\"error\":\"" + JsonEscape(first_error) + "\"";
   portfolio_json += "},";
   portfolio_json += "\"top_ranked\":[" + top_ranked_json + "],";
   portfolio_json += "\"symbols\":[" + symbols_json + "]";
   portfolio_json += "}";

   WriteTextArtifact(StringFormat("%s\\portfolio_state.json", artifact_dir), portfolio_json);
  }

bool BuildMarketWatchSnapshot(const string symbol,
                              CMohyPriceActionSnapshot &out_snapshot,
                              string &out_error)
  {
   out_error = "";
   out_snapshot.Reset();

   if(symbol == "")
     {
      out_error = "EmptySymbol";
      return false;
     }

   if(!SymbolSelect(symbol, true))
     {
      out_error = "SymbolSelectFailed";
      return false;
     }

   const int minimum_bars = MathMax(100, g_cfg.detection.swing_right_bars + 3);
   const int bars = MohyIBars(symbol, g_cfg.execution_timeframe);
   if(bars < minimum_bars)
     {
      out_error = StringFormat("InsufficientBars %d<%d", bars, minimum_bars);
      return false;
     }

   if(!g_market_watch_kernel.BuildRecent(symbol, LookbackBars, out_snapshot, true))
     {
      out_error = "SnapshotBuildFailed";
      return false;
     }
   if(!out_snapshot.publishes_execution_stage_facts)
     {
      out_error = "ExecutionFactsUnavailable";
      return false;
     }

   return true;
  }

void RunMarketWatchScanCycle()
  {
   if(!EnableMarketWatchScanner)
      return;

   string scan_symbols[];
   ResolveScanUniverseSymbols(scan_symbols);
   const int symbol_total = ArraySize(scan_symbols);
   g_market_watch_last_scan_time = TimeCurrent();
   g_market_watch_scan_cycle++;

   int processed_symbols = 0;
   int scanned_ok = 0;
   int scanned_failed = 0;
   int symbols_with_selected_setup = 0;
   int bucket_confirmed_potential_impulse = 0;
   int bucket_confirmed_impulse_and_confirmed_correction = 0;
   int bucket_confirmed_setup_waiting_entry = 0;
   int bucket_eligible_now = 0;
   int bucket_entered_open_running = 0;
   int bucket_blocked_by_risk_or_exposure = 0;
   int bucket_rejected_or_invalidated = 0;
   int allocator_accepted = 0;
   int allocator_blocked = 0;
   double allocator_exposure_base_value = 0.0;
   double allocator_open_risk_percent = 0.0;
   double allocator_allocated_risk_percent = 0.0;
   int execution_attempted = 0;
   int execution_success = 0;
   int execution_failed = 0;
   string execution_first_error_symbol = "";
   string execution_first_error = "";
   int scan_state_indexes[];
   ArrayResize(scan_state_indexes, 0);
   string first_error_symbol = "";
   string first_error = "";

   for(int i = 0; i < symbol_total; ++i)
     {
      const string symbol = scan_symbols[i];
      if(symbol == "")
         continue;
      processed_symbols++;

      MohyMarketWatchScanState state;
      state.symbol = symbol;
      state.last_scan_time = g_market_watch_last_scan_time;
      state.last_scan_ok = false;
      state.publishes_execution_stage_facts = false;
      state.bars = MohyIBars(symbol, g_cfg.execution_timeframe);
      state.impulse_count = 0;
      state.correction_count = 0;
      state.continuation_count = 0;
      state.setup_plan_count = 0;
      state.selected_plan_index = -1;
      state.selected_plan_state = "n/a";
      state.selected_plan_valid = false;
      state.selected_plan_setup_key = "";
      state.selected_plan_impulse_id = "";
      state.selected_plan_direction = "";
      state.selected_plan_execution_mode = "";
      state.selected_plan_setup_time = 0;
      state.selected_plan_entry_price = 0.0;
      state.selected_plan_expected_fill_price = 0.0;
      state.selected_plan_required_entry_price = 0.0;
      state.selected_plan_trigger_price = 0.0;
      state.selected_plan_stop_price = 0.0;
      state.selected_plan_target_price = 0.0;
      state.selected_plan_risk_money = 0.0;
      state.selected_plan_reward_to_risk = 0.0;
      state.selected_plan_lots_normalized = 0.0;
      state.selected_plan_exposure_pass = false;
      state.selected_plan_reject_reason = MOHY_REJECT_INVALID_PLAN;
      state.allocator_accepted = false;
      state.allocator_decision = "None";
      state.allocator_candidate_risk_percent = 0.0;
      state.primary_bucket_id = (int)MOHY_BUCKET_REJECTED_OR_INVALIDATED;
      state.primary_bucket = MarketOpportunityBucketToString(MOHY_BUCKET_REJECTED_OR_INVALIDATED);
      state.bucket_reason = "n/a";
      state.ranking_order = 0;
      state.ranking_bucket_priority = 0;
      state.ranking_score = 0.0;
      state.ranking_plan_selection_rank = 999999;
      state.ranking_plan_setup_time = 0;
      state.ranking_diagnostics = "n/a";
      state.last_error = "";

      CMohyPriceActionSnapshot snapshot;
      string build_error = "";
      if(BuildMarketWatchSnapshot(symbol, snapshot, build_error))
        {
         state.last_scan_ok = true;
         state.publishes_execution_stage_facts = snapshot.publishes_execution_stage_facts;
         state.impulse_count = ArraySize(snapshot.potential_impulses);
         state.correction_count = ArraySize(snapshot.potential_corrections);
         state.continuation_count = ArraySize(snapshot.potential_continuation_signals);
         state.setup_plan_count = ArraySize(snapshot.trade_setup_plans);
         const MohyMarketOpportunityBucket bucket = ClassifySnapshotBucket(symbol, snapshot, state);
         state.primary_bucket_id = (int)bucket;
         state.primary_bucket = MarketOpportunityBucketToString(bucket);
         const bool has_selected_plan = (state.selected_plan_index >= 0 &&
                                         state.selected_plan_index < ArraySize(snapshot.trade_setup_plans));
         MohyTradeSetupPlanFact selected_plan_for_ranking;
         selected_plan_for_ranking.valid = false;
         if(has_selected_plan)
           {
            selected_plan_for_ranking = snapshot.trade_setup_plans[state.selected_plan_index];
            state.selected_plan_valid = selected_plan_for_ranking.valid;
            state.selected_plan_risk_money = selected_plan_for_ranking.risk_money;
            state.selected_plan_reward_to_risk = selected_plan_for_ranking.reward_to_risk;
            state.selected_plan_exposure_pass = selected_plan_for_ranking.exposure_pass;
            state.selected_plan_reject_reason = selected_plan_for_ranking.reject_reason;
           }
         ApplyRankingMetrics(state, bucket, has_selected_plan, selected_plan_for_ranking);
         if(state.selected_plan_index >= 0)
            symbols_with_selected_setup++;

         switch(bucket)
           {
            case MOHY_BUCKET_CONFIRMED_POTENTIAL_IMPULSE:
               bucket_confirmed_potential_impulse++;
               break;
            case MOHY_BUCKET_CONFIRMED_IMPULSE_AND_CONFIRMED_CORRECTION:
               bucket_confirmed_impulse_and_confirmed_correction++;
               break;
            case MOHY_BUCKET_CONFIRMED_SETUP_WAITING_ENTRY:
               bucket_confirmed_setup_waiting_entry++;
               break;
            case MOHY_BUCKET_ELIGIBLE_NOW:
               bucket_eligible_now++;
               break;
            case MOHY_BUCKET_ENTERED_OPEN_RUNNING:
               bucket_entered_open_running++;
               break;
            case MOHY_BUCKET_BLOCKED_BY_RISK_OR_EXPOSURE:
               bucket_blocked_by_risk_or_exposure++;
               break;
            default:
               bucket_rejected_or_invalidated++;
               break;
           }

         scanned_ok++;
        }
      else
        {
         state.primary_bucket = MarketOpportunityBucketToString(MOHY_BUCKET_REJECTED_OR_INVALIDATED);
         state.primary_bucket_id = (int)MOHY_BUCKET_REJECTED_OR_INVALIDATED;
         state.bucket_reason = build_error;
         state.ranking_diagnostics = StringFormat("BuildError:%s", build_error);
         state.last_error = build_error;
         scanned_failed++;
         bucket_rejected_or_invalidated++;
         if(first_error_symbol == "")
           {
            first_error_symbol = symbol;
            first_error = build_error;
           }
        }

      const int state_index = UpsertMarketWatchScanState(state);
      if(state_index >= 0)
        {
         const int next_scan_index = ArraySize(scan_state_indexes);
         ArrayResize(scan_state_indexes, next_scan_index + 1);
         scan_state_indexes[next_scan_index] = state_index;
        }
     }

   ApplyDeterministicRanking(scan_state_indexes);
   ApplyPortfolioAllocator(scan_state_indexes,
                           allocator_accepted,
                           allocator_blocked,
                           allocator_exposure_base_value,
                           allocator_open_risk_percent,
                           allocator_allocated_risk_percent);
   RunLiveExecutionOwnershipCycle(scan_state_indexes,
                                  execution_attempted,
                                  execution_success,
                                  execution_failed,
                                  execution_first_error_symbol,
                                  execution_first_error);
   RecountCurrentBuckets(scan_state_indexes,
                         bucket_confirmed_potential_impulse,
                         bucket_confirmed_impulse_and_confirmed_correction,
                         bucket_confirmed_setup_waiting_entry,
                         bucket_eligible_now,
                         bucket_entered_open_running,
                         bucket_blocked_by_risk_or_exposure,
                         bucket_rejected_or_invalidated);

   PublishArtifactBus(scan_state_indexes,
                      processed_symbols,
                      scanned_ok,
                      scanned_failed,
                      symbols_with_selected_setup,
                      bucket_confirmed_potential_impulse,
                      bucket_confirmed_impulse_and_confirmed_correction,
                      bucket_confirmed_setup_waiting_entry,
                      bucket_eligible_now,
                      bucket_entered_open_running,
                      bucket_blocked_by_risk_or_exposure,
                      bucket_rejected_or_invalidated,
                      allocator_accepted,
                      allocator_blocked,
                      allocator_exposure_base_value,
                      allocator_open_risk_percent,
                      allocator_allocated_risk_percent,
                      execution_attempted,
                      execution_success,
                      execution_failed,
                      first_error_symbol,
                      first_error,
                      execution_first_error_symbol,
                      execution_first_error);

   g_portfolio_metrics.processed_symbols = processed_symbols;
   g_portfolio_metrics.scanned_ok = scanned_ok;
   g_portfolio_metrics.scanned_failed = scanned_failed;
   g_portfolio_metrics.selected_setups = symbols_with_selected_setup;
   g_portfolio_metrics.bucket_cpi = bucket_confirmed_potential_impulse;
   g_portfolio_metrics.bucket_cic = bucket_confirmed_impulse_and_confirmed_correction;
   g_portfolio_metrics.bucket_waiting = bucket_confirmed_setup_waiting_entry;
   g_portfolio_metrics.bucket_eligible = bucket_eligible_now;
   g_portfolio_metrics.bucket_open = bucket_entered_open_running;
   g_portfolio_metrics.bucket_blocked = bucket_blocked_by_risk_or_exposure;
   g_portfolio_metrics.bucket_rejected = bucket_rejected_or_invalidated;
   g_portfolio_metrics.allocator_accepted = allocator_accepted;
   g_portfolio_metrics.allocator_blocked = allocator_blocked;
   g_portfolio_metrics.allocator_exposure_base_value = allocator_exposure_base_value;
   g_portfolio_metrics.allocator_open_risk_percent = allocator_open_risk_percent;
   g_portfolio_metrics.allocator_allocated_risk_percent = allocator_allocated_risk_percent;
   g_portfolio_metrics.execution_attempted = execution_attempted;
   g_portfolio_metrics.execution_success = execution_success;
   g_portfolio_metrics.execution_failed = execution_failed;
   g_portfolio_metrics.first_error_symbol = first_error_symbol;
   g_portfolio_metrics.first_error = first_error;
   g_portfolio_metrics.execution_first_error_symbol = execution_first_error_symbol;
   g_portfolio_metrics.execution_first_error = execution_first_error;
   g_portfolio_metrics.updated_at = TimeCurrent();

   RenderGlobalControlPanel();

   if(!ScannerLogSummary)
      return;

   string top_rank_summary = "none";
   const int top_n = MathMax(0, ScannerLogTopRanks);
   if(top_n > 0)
     {
      top_rank_summary = "";
      int emitted = 0;
      for(int rank = 1; rank <= top_n; ++rank)
        {
         int rank_state_index = -1;
         for(int i = 0; i < ArraySize(scan_state_indexes); ++i)
           {
            const int state_index = scan_state_indexes[i];
            if(state_index < 0 || state_index >= ArraySize(g_market_watch_scan_states))
               continue;
            if(g_market_watch_scan_states[state_index].ranking_order == rank)
              {
               rank_state_index = state_index;
               break;
              }
           }
         if(rank_state_index < 0)
            break;

         const MohyMarketWatchScanState ranked_state = g_market_watch_scan_states[rank_state_index];
         if(emitted > 0)
            top_rank_summary += ",";
         top_rank_summary += StringFormat("%d:%s(%s,%.1f)",
                                          rank,
                                          ranked_state.symbol,
                                          ranked_state.primary_bucket,
                                          ranked_state.ranking_score);
         emitted++;
        }
      if(top_rank_summary == "")
         top_rank_summary = "none";
     }

   if(first_error_symbol != "")
      PrintFormat("MOHY_TradeEA scanner cycle=%I64u scope=%s symbols=%d ok=%d failed=%d selected=%d buckets=[CPI:%d CIC:%d W:%d E:%d O:%d B:%d R:%d] alloc=[A:%d Blk:%d OpenRisk:%.3f%% TotalRisk:%.3f%% Max:%.3f%% Base:%.2f] exec=[Att:%d Ok:%d Fail:%d Mode:%s] top=[%s] firstError=%s:%s",
                  g_market_watch_scan_cycle,
                  ScanUniverseModeToString(ScanUniverseMode),
                  processed_symbols,
                  scanned_ok,
                  scanned_failed,
                  symbols_with_selected_setup,
                  bucket_confirmed_potential_impulse,
                  bucket_confirmed_impulse_and_confirmed_correction,
                  bucket_confirmed_setup_waiting_entry,
                  bucket_eligible_now,
                  bucket_entered_open_running,
                  bucket_blocked_by_risk_or_exposure,
                  bucket_rejected_or_invalidated,
                  allocator_accepted,
                  allocator_blocked,
                  allocator_open_risk_percent,
                  allocator_allocated_risk_percent,
                  g_cfg.risk.max_concurrent_risk_percent,
                  allocator_exposure_base_value,
                  execution_attempted,
                  execution_success,
                  execution_failed,
                  ShouldRunLivePortfolioExecution() ? "GlobalLive" : "Shadow",
                  top_rank_summary,
                  first_error_symbol,
                  first_error);
   else
      PrintFormat("MOHY_TradeEA scanner cycle=%I64u scope=%s symbols=%d ok=%d failed=%d selected=%d buckets=[CPI:%d CIC:%d W:%d E:%d O:%d B:%d R:%d] alloc=[A:%d Blk:%d OpenRisk:%.3f%% TotalRisk:%.3f%% Max:%.3f%% Base:%.2f] exec=[Att:%d Ok:%d Fail:%d Mode:%s] top=[%s]",
                  g_market_watch_scan_cycle,
                  ScanUniverseModeToString(ScanUniverseMode),
                  processed_symbols,
                  scanned_ok,
                  scanned_failed,
                  symbols_with_selected_setup,
                  bucket_confirmed_potential_impulse,
                  bucket_confirmed_impulse_and_confirmed_correction,
                  bucket_confirmed_setup_waiting_entry,
                  bucket_eligible_now,
                  bucket_entered_open_running,
                  bucket_blocked_by_risk_or_exposure,
                  bucket_rejected_or_invalidated,
                  allocator_accepted,
                  allocator_blocked,
                  allocator_open_risk_percent,
                  allocator_allocated_risk_percent,
                  g_cfg.risk.max_concurrent_risk_percent,
                  allocator_exposure_base_value,
                  execution_attempted,
                  execution_success,
                  execution_failed,
                  ShouldRunLivePortfolioExecution() ? "GlobalLive" : "Shadow",
                  top_rank_summary);

   if(execution_first_error_symbol != "")
      PrintFormat("MOHY_TradeEA execution cycle=%I64u firstError=%s:%s",
                  g_market_watch_scan_cycle,
                  execution_first_error_symbol,
                  execution_first_error);
  }

bool ConfigureFromInputs(string &out_error)
  {
   MohyRuntimeInputConfig inputs;
   inputs.symbol = Symbol();
   inputs.context_timeframe = (int)HTF;
   inputs.execution_timeframe = (int)LTF;

   inputs.potential_impulse_enabled = PotentialImpulseEnabled;
   inputs.potential_impulse_min_swing_breakout_closes = PotentialImpulseMinSwingBreakoutCloses;
   inputs.potential_impulse_require_leg_breakout = PotentialImpulseRequireLegBreakout;
   inputs.potential_impulse_min_leg_breakout_closes = PotentialImpulseMinLegBreakoutCloses;
   inputs.potential_impulse_require_directional_candles = PotentialImpulseRequireDirectionalCandles;
   inputs.potential_impulse_validate_endpoint_candles = PotentialImpulseValidateEndpointCandles;
   inputs.potential_impulse_allow_opposite_begin_candles = PotentialImpulseAllowOppositeBeginCandles;
   inputs.potential_impulse_allow_opposite_end_candles = PotentialImpulseAllowOppositeEndCandles;
   inputs.potential_impulse_max_opposite_middle_candles = PotentialImpulseMaxOppositeMiddleCandles;
   inputs.potential_impulse_allow_any_opposite_before_leg_breakout = PotentialImpulseAllowAnyOppositeBeforeLegBreakout;
   inputs.potential_impulse_doji_epsilon_points = PotentialImpulseDojiEpsilonPoints;

   inputs.potential_correction_enabled = PotentialCorrectionEnabled;
   inputs.potential_correction_min_opposite_ici_count = PotentialCorrectionMinOppositeICICount;
   inputs.potential_correction_min_fib_level = PotentialCorrectionMinFibLevel;
   inputs.potential_correction_min_fib_trigger_mode = PotentialCorrectionMinFibTriggerMode;
   inputs.potential_correction_max_fib_level = PotentialCorrectionMaxFibLevel;
   inputs.potential_correction_max_fib_trigger_mode = PotentialCorrectionMaxFibTriggerMode;
   inputs.potential_correction_extreme_touch_epsilon_points = PotentialCorrectionExtremeTouchEpsilonPoints;
   inputs.potential_correction_extreme_touch_min_count = PotentialCorrectionExtremeTouchMinCount;
   inputs.potential_correction_supersede_direction_mode = PotentialCorrectionSupersedeDirectionMode;
   inputs.potential_correction_supersede_scope = PotentialCorrectionSupersedeScope;
   inputs.continuation_planning_start_mode = ContinuationPlanningStartMode;

   inputs.entry_execution_mode = EntryExecutionMode;
   inputs.min_rr = MinRR;
   inputs.rr_tolerance = RRTolerance;
   inputs.enable_spread_filter = EnableSpreadFilter;
   inputs.max_spread_points = MaxSpreadPoints;
   inputs.recheck_mode = RecheckMode;
   inputs.adjust_cadence = AdjustCadence;
   inputs.adjust_min_seconds = AdjustMinSeconds;
   inputs.recheck_rr_at_trigger = RecheckRRAtTrigger;
   inputs.sell_trigger_touch_side = SellTriggerTouchSide;
   inputs.buy_trigger_touch_side = BuyTriggerTouchSide;
   inputs.spread_ema_period = SpreadEmaPeriod;
   inputs.fixed_slippage_points = FixedSlippagePoints;
   inputs.slippage_spread_multiplier = SlippageSpreadMultiplier;
   inputs.fixed_commission_points = FixedCommissionPoints;
   inputs.min_trigger_move_points = MinTriggerMovePoints;
   inputs.enable_trigger_freeze = EnableTriggerFreeze;
   inputs.freeze_spread_multiplier = FreezeSpreadMultiplier;
   inputs.min_stop_distance_points = MinStopDistancePoints;
   inputs.pre_entry_invalidation_mode = PreEntryInvalidationMode;
   inputs.pre_entry_invalidation_buffer_points = PreEntryInvalidationBufferPoints;
   inputs.enable_pending_auto_modify = EnablePendingAutoModify;

   inputs.risk_percent = RiskPercent;
   inputs.risk_base = RiskBase;
   inputs.max_concurrent_risk_percent = MaxConcurrentRiskPercent;
   inputs.exposure_base = ExposureBase;
   inputs.magic_number = MagicNumber;
   inputs.broker_slippage_points = BrokerSlippagePoints;
   inputs.apply_exec_filters_to_management = ApplyExecFiltersToManagement;

   inputs.stop_loss_mode = StopLossMode;
   inputs.outer_sl_buffer_points = OuterSLBufferPoints;
   inputs.inner_sl_buffer_points = InnerSLBufferPoints;
   inputs.inner_stop_swing_index = InnerStopSwingIndex;
   inputs.take_profit_mode = TakeProfitMode;
   inputs.fib_target_level = FibTargetLevel;
   inputs.target_rr = TargetRR;

   inputs.post_be_management_profile = PostBEManagementProfile;
   inputs.post_be_start_mode = PostBEStartMode;
   inputs.post_be_start_r = PostBEStartR;
   inputs.enable_break_even_on_impulse_extreme = EnableBreakEvenOnImpulseExtreme;
   inputs.be_retry_ticks = BERetryTicks;
   inputs.trail_model = TrailModel;
   inputs.trail_update_cadence = TrailUpdateCadence;
   inputs.trail_one_way_ratchet = TrailOneWayRatchet;
   inputs.trail_structure_swing_index = TrailStructureSwingIndex;
   inputs.trail_fixed_points = TrailFixedPoints;
   inputs.trail_atr_period = TrailATRPeriod;
   inputs.trail_atr_multiplier = TrailATRMultiplier;
   inputs.trail_ma_method = (int)TrailMAMethod;
   inputs.trail_ma_period = TrailMAPeriod;
   inputs.trail_ma_price = (int)TrailMAPrice;
   inputs.trail_ma_buffer_points = TrailMABufferPoints;
   inputs.partial_model = PartialModel;
   inputs.partial_count = PartialCount;
   inputs.partial_percent_1 = PartialPercent1;
   inputs.partial_percent_2 = PartialPercent2;
   inputs.partial_percent_3 = PartialPercent3;
   inputs.partial_r_multiple_1 = PartialRMultiple1;
   inputs.partial_r_multiple_2 = PartialRMultiple2;
   inputs.partial_r_multiple_3 = PartialRMultiple3;
   inputs.partial_fib_level_1 = PartialFibLevel1;
   inputs.partial_fib_level_2 = PartialFibLevel2;
   inputs.partial_fib_level_3 = PartialFibLevel3;
   inputs.partial_target_mode_1 = PartialTargetMode1;
   inputs.partial_target_mode_2 = PartialTargetMode2;
   inputs.partial_target_mode_3 = PartialTargetMode3;
   inputs.post_partial_stop_action = PostPartialStopAction;
   inputs.post_partial_be_plus_points = PostPartialBEPlusPoints;
   inputs.runner_target_mode = RunnerTargetMode;
   inputs.management_retry_count = ManagementRetryCount;
   inputs.management_retry_then_market_close = ManagementRetryThenMarketClose;

   inputs.panel_enabled = PanelEnabled;
   inputs.dangerous_action_cooldown_seconds = DangerousActionCooldownSeconds;
   inputs.ui_redraw_throttle_ms = UiRedrawThrottleMs;
   inputs.enable_terminal_alerts = EnableTerminalAlerts;
   inputs.enable_file_audit = EnableFileAudit;

   if(!MohyBuildStrategyConfigFromRuntimeInputs(inputs, g_cfg, out_error))
      return false;

   if(EnableMarketWatchScanner && ScannerIntervalSeconds < 1)
     {
      out_error = "ScannerIntervalSeconds must be >= 1 when scanner is enabled.";
      return false;
     }
   if(EnableMarketWatchScanner &&
      ScanUniverseMode == MOHY_SCAN_UNIVERSE_CHART_SYMBOL_ONLY &&
      Symbol() == "")
     {
      out_error = "ScanUniverseMode=ChartSymbolOnly requires a valid chart symbol.";
      return false;
     }

   if(RuntimeRoleMode == MOHY_RUNTIME_ROLE_GLOBAL_LIVE && !EnableLiveExecutionOwnership)
     {
      out_error = "RuntimeRoleMode=GlobalLive requires EnableLiveExecutionOwnership=true.";
      return false;
     }
   if(EnableLiveExecutionOwnership && RuntimeRoleMode != MOHY_RUNTIME_ROLE_GLOBAL_LIVE)
     {
      out_error = "EnableLiveExecutionOwnership=true requires RuntimeRoleMode=GlobalLive.";
      return false;
     }
   if(EnableLiveExecutionOwnership && !EnableMarketWatchScanner)
     {
      out_error = "EnableLiveExecutionOwnership=true requires EnableMarketWatchScanner=true.";
      return false;
     }
   if(EnableLiveExecutionOwnership && !EnablePortfolioAllocator)
     {
      out_error = "EnableLiveExecutionOwnership=true requires EnablePortfolioAllocator=true.";
      return false;
     }

   if(EnablePortfolioAllocator && PortfolioMaxActiveTrades < 1)
     {
      out_error = "PortfolioMaxActiveTrades must be >= 1 when allocator is enabled.";
      return false;
     }

   return true;
  }

int OnInit()
  {
   string error = "";
   if(!ConfigureFromInputs(error))
     {
      PrintFormat("MOHY_TradeEA init failed: %s", error);
      return INIT_FAILED;
     }

   g_artifact_started_at = TimeCurrent();
   g_artifact_run_id = StringFormat("tradeea_%d_%s_%s_%d",
                                    (int)g_artifact_started_at,
                                    MohyRuntimeSanitizeToken(Symbol()),
                                    MohyRuntimeSanitizeToken(MohyTimeframeToString(g_cfg.execution_timeframe)),
                                    g_cfg.risk.magic_number);
   g_portfolio_scope_tag = BuildPortfolioArtifactScopeTag();
   g_global_panel_prefix = StringFormat("MOHY_TRADEEA_%I64d_", ChartID());
   g_global_last_action_result = "Idle";
   g_global_last_panel_snapshot_hash = "";
   g_global_last_panel_redraw_ms = 0;
   g_global_pause_entries = false;
   g_global_last_dangerous_action_id = MOHY_UI_ACTION_NONE;
   g_global_last_dangerous_action_time = 0;
   ResetGlobalPendingAction();
   ResetPortfolioCycleMetrics();
   g_portfolio_audit.Configure(g_portfolio_scope_tag,
                               ChartID(),
                               EnableFileAudit,
                               EnableTerminalAlerts);

   g_panel_runtime_role = RuntimeRoleMode;
   if(ShouldRunLivePortfolioExecution())
      g_panel_runtime_role = MOHY_RUNTIME_ROLE_READ_ONLY;
   const bool runtime_panel_enabled = (PanelEnabled && !EnableGlobalControlPanel);

   if(EnableGlobalControlPanel)
      ClearLegacyRuntimePanel();

   g_runtime.Configure(g_cfg,
                       Symbol(),
                       LookbackBars,
                       runtime_panel_enabled,
                       (int)PanelCorner,
                       PanelOffsetX,
                       PanelOffsetY,
                       g_panel_runtime_role);
   if(!g_runtime.Initialize())
      return INIT_FAILED;
   if(EnableMarketWatchScanner)
     {
      string init_scan_symbols[];
      ResolveScanUniverseSymbols(init_scan_symbols);
      g_market_watch_kernel.Configure(g_cfg,
                                      g_cfg.execution_timeframe,
                                      g_cfg.context_timeframe,
                                      g_cfg.execution_timeframe);
      if(!EventSetTimer(MathMax(1, ScannerIntervalSeconds)))
        {
         Print("MOHY_TradeEA init failed: unable to start market watch scanner timer.");
         g_runtime.Shutdown();
         return INIT_FAILED;
        }
      RunMarketWatchScanCycle();
      PrintFormat("MOHY_TradeEA scanner enabled. interval=%ds, scope=%s, symbols=%d",
                  MathMax(1, ScannerIntervalSeconds),
                  ScanUniverseModeToString(ScanUniverseMode),
                  ArraySize(init_scan_symbols));
     }
   PrintFormat("MOHY_TradeEA initialized. RuntimeRole=%s PanelRole=%s LiveOwnership=%s ScanScope=%s GlobalPanel=%s RuntimePanel=%s",
               MohyRuntimeRoleModeToString(RuntimeRoleMode),
               MohyRuntimeRoleModeToString(g_panel_runtime_role),
               ShouldRunLivePortfolioExecution() ? "On" : "Off",
               ScanUniverseModeToString(ScanUniverseMode),
               EnableGlobalControlPanel ? "On" : "Off",
               runtime_panel_enabled ? "On" : "Off");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(EnableMarketWatchScanner)
      EventKillTimer();
   ClearGlobalControlPanel();
   g_runtime.Shutdown();
  }

void OnTick()
  {
   g_runtime.OnTick();
  }

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
   ExpireGlobalPendingActionIfNeeded();
   MohyUiActionId action_id = MOHY_UI_ACTION_NONE;
   if(HandleGlobalPanelChartEvent(id, sparam, action_id))
     {
      HandleGlobalUiAction(action_id);
      RenderGlobalControlPanel();
      return;
     }

   g_runtime.OnChartEvent(id, lparam, dparam, sparam);
  }

void OnTimer()
  {
   ExpireGlobalPendingActionIfNeeded();
   RunMarketWatchScanCycle();
  }

