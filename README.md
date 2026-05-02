# InferenceAcceleration

AI inference acceleration techniques, tools, and experiments — companion code
for blog posts and write-ups at [amund.blog](https://amund.blog).

## Projects

| directory | TL;DR | blog post |
|---|---|---|
| [`pld-gemma4-mlx/`](./pld-gemma4-mlx/) | Prompt Lookup Decoding (PLD) on Gemma 4 31B 4-bit on Apple M3 Ultra under `mlx-lm 0.31.3`. **+54 % decode** with greedy parity holding on the structured / JSON RAG class; classic-doc-RAG parity is fragile (one config out of two); code-RAG parity fails everywhere. Includes the n-gram drafter, the verify-and-rollback spec-decode loop, the three prompt classes, and the exact bench script behind the post. | [Can Prompt Lookup Decoding Speed Up Gemma 4 31B 4-bit on Apple Silicon for RAG-style Workloads?](https://amund.blog/accelerating-gemma4-31b-pld-mlx-lm/) |
| [`g4-flashtree-formal-verification/`](./g4-flashtree-formal-verification/) | Formal-methods proof code for a hypothetical *G4-FlashTree* speculative-decoding stack (Gemma 4 31B + DFlash drafter + DDTree verifier). **Audit-first**: 12 originally-claimed artifacts were audited; what survived is partitioned into a four-tier evidence pyramid — 4 Lean theorems (`lake build` green, zero `sorry`), 4 TLA⁺ properties under bounded TLC including a load-bearing safe-vs-unsafe counter-example pair, 3 ABS behavioral models (no `absc` run captured), and engineering claims explicitly excluded from the formal bundle. The "(and can't)" half is the most interesting half. | [What formal methods can (and can't) prove about a Gemma 4 + DFlash + DDTree blueprint](https://amund.blog/g4-flashtree-formal-verification/) |

## License

Apache-2.0 — see [`LICENSE`](./LICENSE).
