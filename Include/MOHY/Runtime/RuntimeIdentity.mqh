#ifndef __MOHY_RUNTIME_IDENTITY_MQH__
#define __MOHY_RUNTIME_IDENTITY_MQH__

#include <MOHY/Runtime/RuntimeCommon.mqh>
#include <MOHY/Core/Domain/PriceActionContracts.mqh>

bool MohyRuntimeResolveIdentity(const string symbol,
                               const CMohyPriceActionSnapshot &snapshot,
                               const MohyTradeSetupPlanFact &plan,
                               string &out_impulse_id,
                               string &out_setup_key)
  {
   out_impulse_id = "";
   out_setup_key = "";
   if(symbol == "" || !plan.valid)
      return false;
   if(plan.linked_potential_impulse_index < 0 ||
      plan.linked_potential_impulse_index >= ArraySize(snapshot.potential_impulses))
      return false;
   if(plan.linked_potential_correction_index < 0 ||
      plan.linked_potential_correction_index >= ArraySize(snapshot.potential_corrections))
      return false;
   if(plan.linked_potential_continuation_signal_index < 0 ||
      plan.linked_potential_continuation_signal_index >= ArraySize(snapshot.potential_continuation_signals))
      return false;

   const MohyPotentialImpulseFact impulse =
      snapshot.potential_impulses[plan.linked_potential_impulse_index];
   const MohyPotentialCorrectionFact correction =
      snapshot.potential_corrections[plan.linked_potential_correction_index];
   const MohyPotentialContinuationSignalFact signal =
      snapshot.potential_continuation_signals[plan.linked_potential_continuation_signal_index];

   if(!impulse.valid || !correction.valid || !signal.valid)
      return false;

   if(!MohyBuildRuntimeImpulseId(symbol,
                                 snapshot.context_timeframe,
                                 snapshot.execution_timeframe,
                                 plan.direction,
                                 impulse.begin_time,
                                 impulse.end_time,
                                 impulse.begin_price,
                                 impulse.end_price,
                                 out_impulse_id))
      return false;
   datetime correction_anchor_time = correction.confirmed_time;
   if(correction_anchor_time <= 0)
      correction_anchor_time = correction.reference_begin_time;
   if(correction_anchor_time <= 0)
      correction_anchor_time = correction.begin_time;
   return MohyBuildRuntimeSetupKey(out_impulse_id,
                                   correction_anchor_time,
                                   signal.signal_time,
                                   out_setup_key);
  }

#endif

