---------------- MODULE dispatch ----------------
EXTENDS Integers

VARIABLES amx_status, ane_status, buffer_state

vars == <<amx_status, ane_status, buffer_state>>

Init ==
    /\ amx_status = "Idle"
    /\ ane_status = "Idle"
    /\ buffer_state = "Empty"

\* ANE starts dequantizing a tile. Buffer transitions Empty -> Writing.
StartANE ==
    /\ ane_status = "Idle"
    /\ buffer_state = "Empty"
    /\ ane_status' = "Writing"
    /\ buffer_state' = "Writing"
    /\ UNCHANGED amx_status

\* ANE finishes dequantizing and marks buffer as Ready for AMX consumer.
FinishANE ==
    /\ ane_status = "Writing"
    /\ ane_status' = "Idle"
    /\ buffer_state' = "Ready"
    /\ UNCHANGED amx_status

\* AMX starts reading the Ready buffer for attention calculations.
StartAMX ==
    /\ amx_status = "Idle"
    /\ buffer_state = "Ready"
    /\ amx_status' = "Reading"
    /\ buffer_state' = "Reading"
    /\ UNCHANGED ane_status

\* AMX finishes and empties the buffer; cycle returns to Init.
FinishAMX ==
    /\ amx_status = "Reading"
    /\ amx_status' = "Idle"
    /\ buffer_state' = "Empty"
    /\ UNCHANGED ane_status

Next ==
    \/ StartANE
    \/ FinishANE
    \/ StartAMX
    \/ FinishAMX

\* Spec adds weak fairness on Next so liveness can be checked. Without
\* fairness, stuttering at Init forever is a legal behaviour and any
\* eventual property would be vacuously falsifiable.
Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

\* Safety: AMX is only in the Reading state when the buffer is in the
\* Reading state too — i.e. AMX never reads from a buffer that isn't
\* currently bound to a read transaction.
DataIntegrity == (amx_status = "Reading" => buffer_state = "Reading")

\* Safety: ANE never writes while AMX is reading. Captures the basic
\* exclusion property of the producer/consumer ring.
NoCollision == ~(ane_status = "Writing" /\ amx_status = "Reading")

\* Liveness (deadlock freedom, salvaged form). The original
\* DeadlockFree == ~(amx_status = "Idle" /\ ane_status = "Idle"
\*                   /\ buffer_state = "Empty")
\* is *false in Init* (everything starts Idle/Empty) and would be
\* falsified before any action fires. The honest reformulation: from
\* the all-Idle state, the system can always make progress — i.e. the
\* buffer eventually becomes non-Empty.
\*
\* Under WF_vars(Next), StartANE is enabled in Init (Idle/Idle/Empty)
\* and must therefore eventually fire. So <>(buffer_state /= "Empty")
\* should hold from Init.
Liveness == <>(buffer_state /= "Empty")

==================================================
