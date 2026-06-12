#ifndef __MOHY_CORE_BUILDERS_POTENTIAL_CONTINUATION_BUILDER_MQH__
#define __MOHY_CORE_BUILDERS_POTENTIAL_CONTINUATION_BUILDER_MQH__

#include <MOHY/Domain/Config.mqh>
#include <MOHY/Core/Domain/PriceActionContracts.mqh>

class CMohyPotentialContinuationBuilder
  {
private:
   DetectionConfig m_cfg;
   int             m_timeframe;
   int             m_execution_timeframe;

   bool    IsSignalNewer(const MohyPotentialContinuationSignalFact &left,
                         const MohyPotentialContinuationSignalFact &right) const
     {
      return ((left.signal_shift < right.signal_shift) ||
              (left.signal_shift == right.signal_shift &&
               left.signal_time > right.signal_time));
     }

   bool    IsSignalPreferredForSelection(const MohyPotentialContinuationSignalFact &candidate,
                                         const MohyPotentialContinuationSignalFact &best) const
     {
      if(candidate.linked_correction_is_active != best.linked_correction_is_active)
         return candidate.linked_correction_is_active;

      if(candidate.linked_correction_recency_rank != best.linked_correction_recency_rank)
         return (candidate.linked_correction_recency_rank < best.linked_correction_recency_rank);

      return IsSignalNewer(candidate, best);
     }

   bool    IsContinuationIciPattern(const MohyDirection direction,
                                    const MohySwing3PatternType pattern_type) const
     {
      if(direction == MOHY_DIR_BULL)
         return (pattern_type == MOHY_SWING3_PATTERN_BULLISH_ICI);
      if(direction == MOHY_DIR_BEAR)
         return (pattern_type == MOHY_SWING3_PATTERN_BEARISH_ICI);
      return false;
     }

   bool    IsShiftInsideConfirmedWindow(const int shift,
                                        const int newest_shift,
                                        const int oldest_shift) const
     {
      if(shift < 0)
         return false;
      return (shift >= newest_shift && shift <= oldest_shift);
     }

   bool    IsPOrPStarStartMode() const
     {
      return (m_cfg.continuation_planning_start_mode == MOHY_CONT_PLAN_START_P_OR_P_STAR);
     }

   string  ContinuationPlanningStartModeToText() const
     {
      return IsPOrPStarStartMode() ? "POrPStar" : "ConfirmedPOnly";
     }

   bool    ResolveCorrectionSignalWindow(const MohyPotentialCorrectionFact &correction,
                                         int &out_newest_shift,
                                         int &out_oldest_shift) const
     {
      out_newest_shift = -1;
      out_oldest_shift = -1;

      if(!correction.valid)
         return false;
      if(correction.confirmed_shift < 0 || correction.confirmed_time <= 0)
         return false;
      if(correction.impulse_direction != MOHY_DIR_BULL &&
         correction.impulse_direction != MOHY_DIR_BEAR)
         return false;

      const int oldest_shift = correction.confirmed_shift - 1;
      if(oldest_shift < 0)
         return false;

      int newest_shift = 0;
      if(correction.invalidated_shift >= 0)
         newest_shift = correction.invalidated_shift + 1;

      newest_shift = MathMax(0, newest_shift);
      if(newest_shift > oldest_shift)
         return false;

      out_newest_shift = newest_shift;
      out_oldest_shift = oldest_shift;
      return true;
     }

   bool    IsSwingEligible(const MohySwing3Fact &swing) const
     {
      if(IsPOrPStarStartMode())
         return true;
      return swing.confirmed;
     }

   bool    AreTriggerLegsEligible(const MohyLegFact &leg2,
                                  const MohyLegFact &leg3) const
     {
      if(IsPOrPStarStartMode())
         return true;
      return (leg2.confirmed && leg3.confirmed);
     }

   void    AppendFact(const MohyPotentialContinuationSignalFact &fact,
                      MohyPotentialContinuationSignalFact &io_facts[],
                      int &io_count) const
     {
      ArrayResize(io_facts, io_count + 1);
      io_facts[io_count] = fact;
      io_facts[io_count].index = io_count;
      io_count++;
     }

   void    PopulateSelectionFacts(MohyPotentialContinuationSignalFact &io_facts[]) const
     {
      const int count = ArraySize(io_facts);
      int selected_index = -1;
      for(int i = 0; i < count; ++i)
        {
         io_facts[i].selection_rank = -1;
         io_facts[i].is_selected = false;
         if(!io_facts[i].valid)
            continue;
         if(selected_index < 0 || IsSignalPreferredForSelection(io_facts[i], io_facts[selected_index]))
            selected_index = i;
        }

      for(int i = 0; i < count; ++i)
        {
         if(!io_facts[i].valid)
            continue;

         int better_count = 0;
         for(int j = 0; j < count; ++j)
           {
            if(i == j || !io_facts[j].valid)
               continue;
            if(IsSignalPreferredForSelection(io_facts[j], io_facts[i]))
               better_count++;
           }
         io_facts[i].selection_rank = better_count;
        }

      if(selected_index >= 0 && selected_index < count)
         io_facts[selected_index].is_selected = true;
     }

public:
            CMohyPotentialContinuationBuilder()
              {
               MohySetDefaultDetectionConfig(m_cfg);
               m_timeframe = PERIOD_M15;
               m_execution_timeframe = PERIOD_M15;
              }

   void     Configure(const DetectionConfig &cfg,
                      const int timeframe,
                      const int execution_timeframe)
     {
      m_cfg = cfg;
      m_timeframe = timeframe;
      m_execution_timeframe = execution_timeframe;
     }

   int      Build(const MohyLegFact &execution_legs[],
                  const MohySwing3Fact &execution_swings3[],
                  const MohyPotentialCorrectionFact &potential_corrections[],
                  MohyPotentialContinuationSignalFact &out_facts[]) const
     {
      ArrayResize(out_facts, 0);

      if(!m_cfg.enable_potential_correction)
         return 0;
      if(m_timeframe != m_execution_timeframe)
         return 0;
      if(ArraySize(execution_legs) <= 0 || ArraySize(execution_swings3) <= 0)
         return 0;
      if(ArraySize(potential_corrections) <= 0)
         return 0;

      int fact_count = 0;
      const int correction_count = ArraySize(potential_corrections);
      for(int i = 0; i < correction_count; ++i)
        {
         const MohyPotentialCorrectionFact correction = potential_corrections[i];
         int window_newest_shift = -1;
         int window_oldest_shift = -1;
         if(!ResolveCorrectionSignalWindow(correction,
                                           window_newest_shift,
                                           window_oldest_shift))
            continue;

         const int swing_count = ArraySize(execution_swings3);
         for(int swing_i = 0; swing_i < swing_count; ++swing_i)
           {
            const MohySwing3Fact swing = execution_swings3[swing_i];
            if(!IsSwingEligible(swing))
               continue;
            if(swing.direction != correction.impulse_direction)
               continue;
            if(!IsContinuationIciPattern(correction.impulse_direction, swing.pattern_type))
               continue;
            if(swing.break_state != MOHY_BREAK_STATE_BREAKOUT)
               continue;
            if(swing.breakout_close_count < 1)
               continue;

            if(swing.leg2_index < 0 || swing.leg2_index >= ArraySize(execution_legs))
               continue;
            if(swing.leg3_index < 0 || swing.leg3_index >= ArraySize(execution_legs))
               continue;

            const MohyLegFact leg2 = execution_legs[swing.leg2_index];
            const MohyLegFact leg3 = execution_legs[swing.leg3_index];
            if(!AreTriggerLegsEligible(leg2, leg3))
               continue;
            if(leg2.end_shift <= leg3.end_shift)
               continue;
            if(leg2.begin_time <= 0 || leg3.end_time <= 0)
               continue;
            if(leg2.begin_price <= 0.0)
               continue;
            if(!IsShiftInsideConfirmedWindow(leg2.begin_shift,
                                             window_newest_shift,
                                             window_oldest_shift))
               continue;
            if(!IsShiftInsideConfirmedWindow(leg3.end_shift,
                                             window_newest_shift,
                                             window_oldest_shift))
               continue;

            MohyPotentialContinuationSignalFact fact;
            fact.index = -1;
            fact.valid = true;
            fact.linked_potential_correction_index = correction.index;
            fact.linked_potential_impulse_index = correction.linked_potential_impulse_index;
            fact.linked_potential_impulse_swing3_index = correction.linked_potential_impulse_swing3_index;
            fact.linked_correction_recency_rank = correction.recency_rank;
            fact.linked_correction_is_active = correction.is_active;
            fact.linked_correction_state = correction.state;
            fact.direction = correction.impulse_direction;
            fact.correction_confirmed_shift = correction.confirmed_shift;
            fact.correction_confirmed_time = correction.confirmed_time;
            fact.trigger_swing3_index = swing.index;
            fact.trigger_middle_leg_index = swing.leg2_index;
            fact.trigger_broken_leg_index = swing.leg2_index;
            fact.trigger_breakout_certainty = swing.breakout_certainty;
            fact.trigger_breakout_close_count = swing.breakout_close_count;
            fact.broken_leg_begin_shift = leg2.begin_shift;
            fact.broken_leg_begin_time = leg2.begin_time;
            fact.broken_leg_end_shift = leg3.end_shift;
             fact.broken_leg_end_time = leg3.end_time;
             fact.signal_shift = leg3.end_shift;
             fact.signal_time = leg3.end_time;
             fact.broken_level_shift = leg2.begin_shift;
             fact.broken_level_time = leg2.begin_time;
             fact.broken_level_price = leg2.begin_price;
             fact.selection_rank = -1;
             fact.is_selected = false;
             fact.diagnostics = StringFormat("Corr=%d|Impulse=%d|Dir=%s|Swing3=%d|StartMode=%s|CorrState=%s|SwingConfirmed=%s|Leg2Confirmed=%s|Leg3Confirmed=%s|BrokenLevelShift=%d|BrokenLeg=%d..%d|Window=%d..%d",
                                             fact.linked_potential_correction_index,
                                             fact.linked_potential_impulse_index,
                                            (fact.direction == MOHY_DIR_BULL) ? "Bull" : "Bear",
                                            fact.trigger_swing3_index,
                                            ContinuationPlanningStartModeToText(),
                                            MohyPotentialCorrectionStateToString(correction.state),
                                            swing.confirmed ? "Yes" : "No",
                                            leg2.confirmed ? "Yes" : "No",
                                            leg3.confirmed ? "Yes" : "No",
                                            fact.broken_level_shift,
                                            fact.broken_leg_begin_shift,
                                            fact.broken_leg_end_shift,
                                            window_oldest_shift,
                                            window_newest_shift);

            AppendFact(fact, out_facts, fact_count);
           }
        }

      PopulateSelectionFacts(out_facts);
      return fact_count;
     }
  };

#endif
