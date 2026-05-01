# InferenceAcceleration

AI inference acceleration techniques, tools, and experiments — companion code
for blog posts and write-ups at [amund.blog](https://amund.blog).

## Projects

| directory | TL;DR | blog post |
|---|---|---|
| [`pld-gemma4-mlx/`](./pld-gemma4-mlx/) | Prompt Lookup Decoding (PLD) on Gemma 4 31B 4-bit on Apple M3 Ultra under `mlx-lm 0.31.3`. **+54 % decode** with greedy parity holding on the structured / JSON RAG class; classic-doc-RAG parity is fragile (one config out of two); code-RAG parity fails everywhere. Includes the n-gram drafter, the verify-and-rollback spec-decode loop, the three prompt classes, and the exact bench script behind the post. | [Can Prompt Lookup Decoding Speed Up Gemma 4 31B 4-bit on Apple Silicon for RAG-style Workloads?](https://amund.blog/accelerating-gemma4-31b-pld-mlx-lm/) |

## License

Apache-2.0 — see [`LICENSE`](./LICENSE).
