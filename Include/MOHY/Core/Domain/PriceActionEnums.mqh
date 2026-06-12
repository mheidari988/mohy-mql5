#ifndef __MOHY_CORE_DOMAIN_PRICE_ACTION_ENUMS_MQH__
#define __MOHY_CORE_DOMAIN_PRICE_ACTION_ENUMS_MQH__

enum MohyElementType
  {
   MOHY_ELEMENT_NONE = 0,
   MOHY_ELEMENT_PEAK = 1,
   MOHY_ELEMENT_VALLEY = -1
  };

enum MohyLegType
  {
   MOHY_LEG_NONE = 0,
   MOHY_LEG_BULL = 1,
   MOHY_LEG_BEAR = -1
  };

enum MohySwing3PatternType
  {
   MOHY_SWING3_PATTERN_UNKNOWN = 0,
   MOHY_SWING3_PATTERN_BULLISH_ICI = 1,
   MOHY_SWING3_PATTERN_BULLISH_CIC = 2,
   MOHY_SWING3_PATTERN_BULLISH_ICC = 3,
   MOHY_SWING3_PATTERN_BULLISH_CII = 4,
   MOHY_SWING3_PATTERN_BEARISH_ICI = 5,
   MOHY_SWING3_PATTERN_BEARISH_CIC = 6,
   MOHY_SWING3_PATTERN_BEARISH_ICC = 7,
   MOHY_SWING3_PATTERN_BEARISH_CII = 8
  };

enum MohyBreakState
  {
   MOHY_BREAK_STATE_UNKNOWN = 0,
   MOHY_BREAK_STATE_BREAKOUT = 1,
   MOHY_BREAK_STATE_NO_CLOSE_BREAK = -1
  };

enum MohyBreakoutCertainty
  {
   MOHY_BREAKOUT_CERTAINTY_UNKNOWN = 0,
   MOHY_BREAKOUT_CERTAINTY_UNCERTAIN = 1,
   MOHY_BREAKOUT_CERTAINTY_CERTAIN = 2
  };

enum MohyCorrectionState
  {
   MOHY_CORRECTION_STATE_UNKNOWN = 0,
   MOHY_CORRECTION_STATE_NOT_RETESTED = 1,
   MOHY_CORRECTION_STATE_RETESTED = 2,
   MOHY_CORRECTION_STATE_BROKEBACK = 3
  };

enum MohyPotentialCorrectionState
  {
   MOHY_POT_CORR_STATE_FORMING = 0,
   MOHY_POT_CORR_STATE_CONFIRMED = 1,
   MOHY_POT_CORR_STATE_INVALIDATED = 2
  };

enum MohyPotentialCorrectionTerminationReason
  {
   MOHY_POT_CORR_TERM_NONE = 0,
   MOHY_POT_CORR_TERM_CONFIRMED = 1,
   MOHY_POT_CORR_TERM_MAX_FIB_INVALIDATED = 2,
   MOHY_POT_CORR_TERM_DOUBLE_EXTREME_INVALIDATED = 3,
   MOHY_POT_CORR_TERM_SUPERSEDED_BY_NEW_HTF_SWING = 4
  };

enum MohyTradeSetupPlanState
  {
   MOHY_TRADE_SETUP_PLAN_INELIGIBLE = 0,
   MOHY_TRADE_SETUP_PLAN_ELIGIBLE_NOW = 1,
   MOHY_TRADE_SETUP_PLAN_WAITING_FOR_PULLBACK = 2,
   MOHY_TRADE_SETUP_PLAN_INVALIDATED = 3
  };

enum MohyTradeSetupStopAnchorType
  {
   MOHY_TRADE_SETUP_STOP_UNKNOWN = 0,
   MOHY_TRADE_SETUP_STOP_OUTER_CORRECTION_EXTREME = 1,
   MOHY_TRADE_SETUP_STOP_INNER_STRUCTURE = 2
  };

enum MohyTradeSetupTargetAnchorType
  {
   MOHY_TRADE_SETUP_TARGET_UNKNOWN = 0,
   MOHY_TRADE_SETUP_TARGET_FIB_NEG_EXTENSION = 1,
   MOHY_TRADE_SETUP_TARGET_RISK_REWARD = 2
  };

enum MohyHistoricalTradeSetupOutcome
  {
   MOHY_HIST_SETUP_OUTCOME_UNKNOWN = 0,
   MOHY_HIST_SETUP_OUTCOME_WAITING = 1,
   MOHY_HIST_SETUP_OUTCOME_MISSED = 2,
   MOHY_HIST_SETUP_OUTCOME_ENTERED = 3,
   MOHY_HIST_SETUP_OUTCOME_TARGET_HIT = 4,
   MOHY_HIST_SETUP_OUTCOME_STOP_HIT = 5,
   MOHY_HIST_SETUP_OUTCOME_OPEN = 6
  };

string MohyElementTypeToString(const MohyElementType value)
  {
   if(value == MOHY_ELEMENT_PEAK)
      return "Peak";
   if(value == MOHY_ELEMENT_VALLEY)
      return "Valley";
   return "None";
  }

string MohyLegTypeToString(const MohyLegType value)
  {
   if(value == MOHY_LEG_BULL)
      return "Bull";
   if(value == MOHY_LEG_BEAR)
      return "Bear";
   return "None";
  }

string MohySwing3PatternTypeToString(const MohySwing3PatternType value)
  {
   switch(value)
     {
      case MOHY_SWING3_PATTERN_BULLISH_ICI: return "BullishICI";
      case MOHY_SWING3_PATTERN_BULLISH_CIC: return "BullishCIC";
      case MOHY_SWING3_PATTERN_BULLISH_ICC: return "BullishICC";
      case MOHY_SWING3_PATTERN_BULLISH_CII: return "BullishCII";
      case MOHY_SWING3_PATTERN_BEARISH_ICI: return "BearishICI";
      case MOHY_SWING3_PATTERN_BEARISH_CIC: return "BearishCIC";
      case MOHY_SWING3_PATTERN_BEARISH_ICC: return "BearishICC";
      case MOHY_SWING3_PATTERN_BEARISH_CII: return "BearishCII";
      default: break;
     }
   return "Unknown";
  }

string MohyBreakStateToString(const MohyBreakState value)
  {
   if(value == MOHY_BREAK_STATE_BREAKOUT)
      return "Breakout";
   if(value == MOHY_BREAK_STATE_NO_CLOSE_BREAK)
      return "NoCloseBreak";
   return "Unknown";
  }

string MohyBreakoutCertaintyToString(const MohyBreakoutCertainty value)
  {
   if(value == MOHY_BREAKOUT_CERTAINTY_UNCERTAIN)
      return "Uncertain";
   if(value == MOHY_BREAKOUT_CERTAINTY_CERTAIN)
      return "Certain";
   return "Unknown";
  }

string MohyCorrectionStateToString(const MohyCorrectionState value)
  {
   if(value == MOHY_CORRECTION_STATE_NOT_RETESTED)
      return "NotRetested";
   if(value == MOHY_CORRECTION_STATE_RETESTED)
      return "Retested";
   if(value == MOHY_CORRECTION_STATE_BROKEBACK)
      return "Brokeback";
   return "Unknown";
  }

string MohyPotentialCorrectionStateToString(const MohyPotentialCorrectionState value)
  {
   if(value == MOHY_POT_CORR_STATE_FORMING)
      return "Forming";
   if(value == MOHY_POT_CORR_STATE_CONFIRMED)
      return "Confirmed";
   if(value == MOHY_POT_CORR_STATE_INVALIDATED)
      return "Invalidated";
   return "Unknown";
  }

string MohyPotentialCorrectionTerminationReasonToString(const MohyPotentialCorrectionTerminationReason value)
  {
   if(value == MOHY_POT_CORR_TERM_NONE)
      return "None";
   if(value == MOHY_POT_CORR_TERM_CONFIRMED)
      return "Confirmed";
   if(value == MOHY_POT_CORR_TERM_MAX_FIB_INVALIDATED)
      return "MaxFibInvalidated";
   if(value == MOHY_POT_CORR_TERM_DOUBLE_EXTREME_INVALIDATED)
      return "DoubleExtremeInvalidated";
   if(value == MOHY_POT_CORR_TERM_SUPERSEDED_BY_NEW_HTF_SWING)
      return "SupersededByNewHTFSwing";
   return "Unknown";
  }

string MohyTradeSetupPlanStateToString(const MohyTradeSetupPlanState value)
  {
   if(value == MOHY_TRADE_SETUP_PLAN_INELIGIBLE)
      return "Ineligible";
   if(value == MOHY_TRADE_SETUP_PLAN_ELIGIBLE_NOW)
      return "EligibleNow";
   if(value == MOHY_TRADE_SETUP_PLAN_WAITING_FOR_PULLBACK)
      return "WaitingForPullback";
   if(value == MOHY_TRADE_SETUP_PLAN_INVALIDATED)
      return "Invalidated";
   return "Unknown";
  }

string MohyTradeSetupStopAnchorTypeToString(const MohyTradeSetupStopAnchorType value)
  {
   if(value == MOHY_TRADE_SETUP_STOP_OUTER_CORRECTION_EXTREME)
      return "OuterCorrectionExtreme";
   if(value == MOHY_TRADE_SETUP_STOP_INNER_STRUCTURE)
      return "InnerStructure";
   return "Unknown";
  }

string MohyTradeSetupTargetAnchorTypeToString(const MohyTradeSetupTargetAnchorType value)
  {
   if(value == MOHY_TRADE_SETUP_TARGET_FIB_NEG_EXTENSION)
      return "FibNegExtension";
   if(value == MOHY_TRADE_SETUP_TARGET_RISK_REWARD)
      return "RiskReward";
   return "Unknown";
  }

string MohyHistoricalTradeSetupOutcomeToString(const MohyHistoricalTradeSetupOutcome value)
  {
   if(value == MOHY_HIST_SETUP_OUTCOME_WAITING)
      return "Waiting";
   if(value == MOHY_HIST_SETUP_OUTCOME_MISSED)
      return "Missed";
   if(value == MOHY_HIST_SETUP_OUTCOME_ENTERED)
      return "Entered";
   if(value == MOHY_HIST_SETUP_OUTCOME_TARGET_HIT)
      return "TargetHit";
   if(value == MOHY_HIST_SETUP_OUTCOME_STOP_HIT)
      return "StopHit";
   if(value == MOHY_HIST_SETUP_OUTCOME_OPEN)
      return "Open";
   return "Unknown";
  }

#endif
