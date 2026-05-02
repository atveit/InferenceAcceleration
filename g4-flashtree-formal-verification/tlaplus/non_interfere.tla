----------------------- MODULE non_interfere -----------------------
EXTENDS Integers, Sequences

CONSTANT Tokens,              \* The set of all possible tokens
         MaxTraceLen,         \* Maximum length of the target trace for model checking
         MaxDraftLen          \* Maximum length of a single draft block

VARIABLES accepted_output,     \* The sequence of tokens accepted so far
          drafter_proposal,    \* The current draft proposal
          target_model_trace   \* The ground truth sequence from the target model

Vars == <<accepted_output, drafter_proposal, target_model_trace>>

\* Bounded helper: all sequences over S of length 0..N. Replaces TLC's
\* unbounded Seq(S) so the model-checker has an enumerable domain. This
\* is a *modeling* bound (we only check up to MaxTraceLen / MaxDraftLen
\* tokens) — it is not a proof for unbounded N.
BoundedSeq(S, N) == UNION { [1..n -> S] : n \in 0..N }

TypeOK ==
    /\ accepted_output \in BoundedSeq(Tokens, MaxTraceLen)
    /\ drafter_proposal \in BoundedSeq(Tokens, MaxDraftLen)
    /\ target_model_trace \in BoundedSeq(Tokens, MaxTraceLen)

Init ==
    /\ accepted_output = << >>
    /\ drafter_proposal = << >>
    /\ \E s \in BoundedSeq(Tokens, MaxTraceLen) :
        /\ Len(s) \in 1..MaxTraceLen
        /\ target_model_trace = s

\* The Drafter proposes a non-empty block of tokens. Modelled as fully
\* non-deterministic / adversarial: any sequence of length 1..MaxDraftLen
\* over Tokens may be proposed. The point of the spec is that
\* non-interference holds *despite* this adversary.
DrafterPropose ==
    /\ drafter_proposal = << >>
    /\ Len(accepted_output) < Len(target_model_trace)
    /\ \E s \in BoundedSeq(Tokens, MaxDraftLen) :
        /\ Len(s) \in 1..MaxDraftLen
        /\ drafter_proposal' = s
    /\ UNCHANGED <<accepted_output, target_model_trace>>

\* The Verifier checks the drafter_proposal against the target_model_trace,
\* applying the speculative-decoding accept rule:
\*   1. Accept the longest matching prefix.
\*   2. If there is a remaining target token, append it as the
\*      "correction token" so progress is guaranteed.
Verify ==
    /\ drafter_proposal /= << >>
    /\ LET
           \* Length of matching prefix between proposal and the
           \* remaining target trace.
           match_indices == {i \in 0..Len(drafter_proposal) :
               \A j \in 1..i :
                   /\ Len(accepted_output) + j <= Len(target_model_trace)
                   /\ drafter_proposal[j] = target_model_trace[Len(accepted_output) + j]}

           max_match == CHOOSE i \in match_indices : \A j \in match_indices : i >= j

           matched_seq == SubSeq(drafter_proposal, 1, max_match)
           next_idx == Len(accepted_output) + max_match + 1
       IN
           /\ IF next_idx <= Len(target_model_trace)
              THEN accepted_output' = accepted_output \o matched_seq \o << target_model_trace[next_idx] >>
              ELSE accepted_output' = accepted_output \o matched_seq
           /\ drafter_proposal' = << >>
           /\ UNCHANGED target_model_trace

Next == DrafterPropose \/ Verify

\* Fairness on both actions. WF_Vars(Verify) alone wasn't enough — in
\* the initial state Verify is disabled (drafter_proposal = << >>) and
\* DrafterPropose was unfair, allowing infinite stuttering at Init.
\* Adding WF on DrafterPropose forces the system to make progress
\* whenever accepted_output is still strictly shorter than the target.
Spec == Init /\ [][Next]_Vars /\ WF_Vars(Verify) /\ WF_Vars(DrafterPropose)

\* Safety: accepted_output is always a prefix of target_model_trace,
\* regardless of what the drafter proposed. This is the actual
\* "non-interference" claim: an adversarial drafter cannot push tokens
\* into the output that don't agree with the target trace.
\*
\* Important caveat: target_model_trace is a *fixed* sequence in this
\* model, not a probability distribution. So this proves a deterministic
\* prefix property, not "the drafter cannot bias the target
\* distribution." The OVERVIEW phrasing is stronger than what the spec
\* actually shows.
NonInterference ==
    /\ Len(accepted_output) <= Len(target_model_trace)
    /\ accepted_output = SubSeq(target_model_trace, 1, Len(accepted_output))

=============================================================================
\* Notes:
\*
\* The original spec used `Seq(Tokens)` (the infinite set of all finite
\* sequences) inside Init/DrafterPropose. TLC cannot enumerate Seq(S)
\* and errored immediately on the shipped artefact. We replace Seq with
\* the bounded helper BoundedSeq(S, N).
\*
\* The original spec also defined Termination == <>(accepted_output =
\* target_model_trace). With WF on Verify alone, Termination is
\* violated: in Init, Verify is disabled, so the system can stutter at
\* Init forever. With WF on both Verify and DrafterPropose, progress is
\* forced — but Termination still hits a TLC fairness-modelling subtlety
\* (DrafterPropose has an existential over BoundedSeq, and TLC's WF
\* fairness on an action with an existential body is not strong enough
\* to guarantee any *particular* drafter behaviour). Rather than encode
\* a heavier scheduler, we drop the liveness claim from the shipped
\* spec; the property of interest in the paper is safety
\* (non-interference), not liveness. The audit's recommendation
\* (remediation plan T3) is followed: ship safety-only.
