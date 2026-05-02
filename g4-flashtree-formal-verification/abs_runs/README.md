# abs_runs/ — intentionally empty

Track A (2026-05-01) did not capture any ABS simulation logs. The
`absc` toolchain is not installed in this environment; see
`../abs_toolchain.md` for the install-attempt evidence.

This directory exists as a placeholder so that:

1. The canonical run-log path documented in
   `../abs_remediation_notes.md` and the `.abs` headers points at a
   real directory.
2. A future contributor with `absc` installed can drop logs here
   following the canonical pattern in `../abs_toolchain.md`.

Per `REMEDIATION_PLAN.md` Standing Rule 1 ("no log → no claim") and
Standing Rule 4 ("no fabrication"): no `eml_ops.log`,
`tree_perf.log`, or `slc_tiling.log` exists in this directory because
no run was performed. Any prose claiming an ABS run was performed
during Track A is incorrect.
