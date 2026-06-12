#ifndef __MOHY_CORE_DOMAIN_SNAPSHOT_SELECTORS_MQH__
#define __MOHY_CORE_DOMAIN_SNAPSHOT_SELECTORS_MQH__

#include <MOHY/Core/Domain/PriceActionContracts.mqh>

bool MohyIsImpulseMoreRecent(const MohyPotentialImpulseFact &candidate,
                             const MohyPotentialImpulseFact &best)
  {
   if(candidate.end_shift != best.end_shift)
      return (candidate.end_shift < best.end_shift);
   if(candidate.end_time != best.end_time)
      return (candidate.end_time > best.end_time);
   return (candidate.index > best.index);
  }

bool MohyIsCorrectionPreferred(const MohyPotentialCorrectionFact &candidate,
                               const MohyPotentialCorrectionFact &best)
  {
   if(candidate.recency_rank >= 0 && best.recency_rank >= 0 &&
      candidate.recency_rank != best.recency_rank)
      return (candidate.recency_rank < best.recency_rank);
   if(candidate.end_time != best.end_time)
      return (candidate.end_time > best.end_time);
   return (candidate.index > best.index);
  }

bool MohyIsContinuationSignalPreferred(const MohyPotentialContinuationSignalFact &candidate,
                                       const MohyPotentialContinuationSignalFact &best)
  {
   if(candidate.selection_rank >= 0 && best.selection_rank >= 0 &&
      candidate.selection_rank != best.selection_rank)
      return (candidate.selection_rank < best.selection_rank);
   if(candidate.signal_time != best.signal_time)
      return (candidate.signal_time > best.signal_time);
   return (candidate.index > best.index);
  }

bool MohyIsTradeSetupPlanPreferred(const MohyTradeSetupPlanFact &candidate,
                                   const MohyTradeSetupPlanFact &best)
  {
   if(candidate.selection_rank >= 0 && best.selection_rank >= 0 &&
      candidate.selection_rank != best.selection_rank)
      return (candidate.selection_rank < best.selection_rank);
   if(candidate.setup_time != best.setup_time)
      return (candidate.setup_time > best.setup_time);
   return (candidate.index > best.index);
  }

bool MohySnapshotHasConfirmedPotentialImpulse(const CMohyPriceActionSnapshot &snapshot)
  {
   for(int i = 0; i < ArraySize(snapshot.potential_impulses); ++i)
      {
       const MohyPotentialImpulseFact fact = snapshot.potential_impulses[i];
       if(fact.valid && fact.confirmed)
         {
          int selected_correction_index = -1;
          for(int j = 0; j < ArraySize(snapshot.potential_corrections); ++j)
            {
             const MohyPotentialCorrectionFact correction = snapshot.potential_corrections[j];
             if(!correction.valid ||
                correction.linked_potential_impulse_index != fact.index)
                continue;

             if(selected_correction_index < 0 ||
                MohyIsCorrectionPreferred(correction,
                                          snapshot.potential_corrections[selected_correction_index]))
                selected_correction_index = j;
            }

          // A confirmed impulse remains "potential" only while its linked correction
          // context is still actionable (forming/confirmed) or not yet published.
          if(selected_correction_index < 0)
             return true;

          const MohyPotentialCorrectionFact selected_correction =
             snapshot.potential_corrections[selected_correction_index];
          if(selected_correction.state != MOHY_POT_CORR_STATE_INVALIDATED)
             return true;
         }
      }
   return false;
  }

bool MohySnapshotHasConfirmedImpulseAndConfirmedCorrection(const CMohyPriceActionSnapshot &snapshot)
  {
   for(int i = 0; i < ArraySize(snapshot.potential_corrections); ++i)
     {
      const MohyPotentialCorrectionFact correction = snapshot.potential_corrections[i];
      if(!correction.valid ||
         !correction.confirmed ||
         correction.state != MOHY_POT_CORR_STATE_CONFIRMED)
         continue;

      const int impulse_index = correction.linked_potential_impulse_index;
      if(impulse_index < 0 || impulse_index >= ArraySize(snapshot.potential_impulses))
         continue;

      const MohyPotentialImpulseFact impulse = snapshot.potential_impulses[impulse_index];
      if(impulse.valid && impulse.confirmed)
         return true;
     }

   return false;
  }

int MohyFindPotentialImpulseIndexByRuntimeImpulseId(const CMohyPriceActionSnapshot &snapshot,
                                                    const string impulse_id)
  {
   if(impulse_id == "")
      return -1;

   int selected_index = -1;
   for(int i = 0; i < ArraySize(snapshot.potential_impulses); ++i)
     {
      const MohyPotentialImpulseFact fact = snapshot.potential_impulses[i];
      if(!fact.valid || fact.runtime_impulse_id != impulse_id)
         continue;

      if(selected_index < 0 ||
         MohyIsImpulseMoreRecent(fact, snapshot.potential_impulses[selected_index]))
         selected_index = i;
     }

   return selected_index;
  }

int MohySelectPotentialImpulseIndex(const CMohyPriceActionSnapshot &snapshot)
  {
   int selected_index = -1;
   for(int i = 0; i < ArraySize(snapshot.potential_impulses); ++i)
     {
      const MohyPotentialImpulseFact fact = snapshot.potential_impulses[i];
      if(!fact.valid)
         continue;

      if(selected_index < 0 ||
         MohyIsImpulseMoreRecent(fact, snapshot.potential_impulses[selected_index]))
         selected_index = i;
     }

   return selected_index;
  }

int MohyFindPotentialCorrectionIndexByRuntimeImpulseId(const CMohyPriceActionSnapshot &snapshot,
                                                       const string impulse_id,
                                                       const bool active_only)
  {
   if(impulse_id == "")
      return -1;

   int selected_index = -1;
   for(int i = 0; i < ArraySize(snapshot.potential_corrections); ++i)
     {
      const MohyPotentialCorrectionFact fact = snapshot.potential_corrections[i];
      if(!fact.valid)
         continue;
      if(active_only && !fact.is_active)
         continue;
      if(fact.runtime_impulse_id != impulse_id)
         continue;

      if(fact.is_selected)
         return i;

      if(selected_index < 0 ||
         MohyIsCorrectionPreferred(fact, snapshot.potential_corrections[selected_index]))
         selected_index = i;
     }

   return selected_index;
  }

int MohySelectPotentialCorrectionIndex(const CMohyPriceActionSnapshot &snapshot,
                                       const bool active_only)
  {
   int selected_index = -1;
   for(int i = 0; i < ArraySize(snapshot.potential_corrections); ++i)
     {
      const MohyPotentialCorrectionFact fact = snapshot.potential_corrections[i];
      if(!fact.valid)
         continue;
      if(active_only && !fact.is_active)
         continue;

      if(fact.is_selected)
         return i;

      if(selected_index < 0 ||
         MohyIsCorrectionPreferred(fact, snapshot.potential_corrections[selected_index]))
         selected_index = i;
     }

   return selected_index;
  }

int MohyFindPotentialContinuationSignalIndexBySetupKey(const CMohyPriceActionSnapshot &snapshot,
                                                       const string setup_key)
  {
   if(setup_key == "")
      return -1;

   int selected_index = -1;
   for(int i = 0; i < ArraySize(snapshot.potential_continuation_signals); ++i)
     {
      const MohyPotentialContinuationSignalFact fact = snapshot.potential_continuation_signals[i];
      if(!fact.valid || fact.runtime_setup_key != setup_key)
         continue;

      if(fact.is_selected)
         return i;

      if(selected_index < 0 ||
         MohyIsContinuationSignalPreferred(fact, snapshot.potential_continuation_signals[selected_index]))
         selected_index = i;
     }

   return selected_index;
  }

int MohySelectPotentialContinuationSignalIndex(const CMohyPriceActionSnapshot &snapshot,
                                               const int preferred_correction_index)
  {
   int selected_index = -1;
   for(int i = 0; i < ArraySize(snapshot.potential_continuation_signals); ++i)
     {
      const MohyPotentialContinuationSignalFact fact = snapshot.potential_continuation_signals[i];
      if(!fact.valid)
         continue;
      if(preferred_correction_index >= 0 &&
         fact.linked_potential_correction_index != preferred_correction_index)
         continue;

      if(fact.is_selected)
         return i;

      if(selected_index < 0 ||
         MohyIsContinuationSignalPreferred(fact, snapshot.potential_continuation_signals[selected_index]))
         selected_index = i;
     }

   return selected_index;
  }

int MohyFindTradeSetupPlanIndexBySetupKey(const CMohyPriceActionSnapshot &snapshot,
                                          const string setup_key)
  {
   if(setup_key == "")
      return -1;

   int selected_index = -1;
   for(int i = 0; i < ArraySize(snapshot.trade_setup_plans); ++i)
     {
      const MohyTradeSetupPlanFact plan = snapshot.trade_setup_plans[i];
      if(!plan.valid || plan.runtime_setup_key != setup_key)
         continue;

      if(plan.is_selected)
         return i;

      if(selected_index < 0 ||
         MohyIsTradeSetupPlanPreferred(plan, snapshot.trade_setup_plans[selected_index]))
         selected_index = i;
     }

   return selected_index;
  }

int MohySelectTradeSetupPlanIndex(const CMohyPriceActionSnapshot &snapshot,
                                  const int preferred_correction_index)
  {
   int selected_index = -1;
   for(int i = 0; i < ArraySize(snapshot.trade_setup_plans); ++i)
     {
      const MohyTradeSetupPlanFact plan = snapshot.trade_setup_plans[i];
      if(!plan.valid)
         continue;
      if(preferred_correction_index >= 0 &&
         plan.linked_potential_correction_index != preferred_correction_index)
         continue;

      if(plan.is_selected)
         return i;

      if(selected_index < 0 ||
         MohyIsTradeSetupPlanPreferred(plan, snapshot.trade_setup_plans[selected_index]))
         selected_index = i;
     }

   return selected_index;
  }

int MohyFindSelectedTradeSetupPlanIndex(const CMohyPriceActionSnapshot &snapshot,
                                        const bool allow_rank_fallback = false)
  {
   for(int i = 0; i < ArraySize(snapshot.trade_setup_plans); ++i)
     {
      const MohyTradeSetupPlanFact plan = snapshot.trade_setup_plans[i];
      if(plan.valid && plan.is_selected)
         return i;
     }

   if(!allow_rank_fallback)
      return -1;

   return MohySelectTradeSetupPlanIndex(snapshot, -1);
  }

#endif
