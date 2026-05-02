---------------- MODULE rollback ----------------
EXTENDS Integers, FiniteSets

CONSTANTS MaxLen

VARIABLES len, pending_reads

vars == <<len, pending_reads>>

Init ==
    /\ len = 0
    /\ pending_reads = {}

Extend ==
    /\ len < MaxLen
    /\ len' = len + 1
    /\ UNCHANGED pending_reads

StartRead ==
    \E i \in 1..len :
        /\ pending_reads' = pending_reads \cup {i}
        /\ UNCHANGED len

FinishRead ==
    \E i \in pending_reads :
        /\ pending_reads' = pending_reads \ {i}
        /\ UNCHANGED len

\* Unsafe Rollback: directly truncates len regardless of active reads.
\* Kept here so the *unsafe* spec (UnsafeNext below) can be model-checked
\* separately and produce a real counter-example to NoGhostReads. The
\* shipped Spec uses Next (safe only) and is expected to hold.
UnsafeRollback ==
    \E k \in 0..(len - 1) :
        /\ len' = k
        /\ UNCHANGED pending_reads

\* Safe Rollback: synchronizes by waiting for active reads beyond the new
\* length to finish. Encodes the runtime's "drain in-flight readers
\* before truncating the cache pointer" rule.
SafeRollback ==
    \E k \in 0..(len - 1) :
        /\ \A i \in pending_reads : i <= k
        /\ len' = k
        /\ UNCHANGED pending_reads

\* Safe next-state relation (used by Spec).
Next ==
    \/ Extend
    \/ StartRead
    \/ FinishRead
    \/ SafeRollback

\* Unsafe next-state relation (used by UnsafeSpec for counter-example).
UnsafeNext ==
    \/ Extend
    \/ StartRead
    \/ FinishRead
    \/ UnsafeRollback

Spec       == Init /\ [][Next]_vars
UnsafeSpec == Init /\ [][UnsafeNext]_vars

\* Safety invariant: every pending read index points within the current
\* live range. A "ghost read" is a pending_read i with i > len, i.e. a
\* reader still trying to read a position the cache has already
\* truncated past.
NoGhostReads == \A i \in pending_reads : i <= len

==================================================
