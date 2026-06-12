#property strict

#include <MOHY/Domain/Config.mqh>
#include <MOHY/Runtime/RuntimeInputMapper.mqh>
#include <MOHY/Runtime/RuntimeEngine.mqh>

input ENUM_TIMEFRAMES HTF = (ENUM_TIMEFRAMES)16385;
input ENUM_TIMEFRAMES LTF = (ENUM_TIMEFRAMES)15;
input int      LookbackBars = 1600;
input MohyRuntimeRoleMode RuntimeRoleMode = MOHY_RUNTIME_ROLE_SHADOW_DEBUG;

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

   return MohyBuildStrategyConfigFromRuntimeInputs(inputs, g_cfg, out_error);
  }

int OnInit()
  {
   string error = "";
   if(!ConfigureFromInputs(error))
     {
      PrintFormat("MOHY_DebugEA init failed: %s", error);
      return INIT_FAILED;
     }

   g_runtime.Configure(g_cfg,
                       Symbol(),
                       LookbackBars,
                       PanelEnabled,
                       (int)PanelCorner,
                       PanelOffsetX,
                       PanelOffsetY,
                       RuntimeRoleMode);
   if(!g_runtime.Initialize())
      return INIT_FAILED;
   PrintFormat("MOHY_DebugEA initialized. RuntimeRole=%s", MohyRuntimeRoleModeToString(RuntimeRoleMode));
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
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
   g_runtime.OnChartEvent(id, lparam, dparam, sparam);
  }

