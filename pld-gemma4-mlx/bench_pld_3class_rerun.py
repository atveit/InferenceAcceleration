"""Re-bench PLD across 3 prompt classes — the script behind the blog post.

Same hardware/model as the post (Apple M3 Ultra, 96 GB; mlx-community/gemma-4-31b-it-4bit).
All three prompt classes are truncated/padded to exactly 800 tokens to give
a fair cross-class comparison and stay under Gemma 4's sliding_window=1024.

For each class, runs k=0 (no drafter, baseline) and PLD k=2 at n_min in {2, 3}.
Each (class, k, n_min) is measured 3 times after 1 warmup pass.

Greedy parity is checked as bit-exact string equality of the generated text
versus the k=0 baseline for the same prompt class. Note: this implementation
diffs run-0 only — see the blog post's "Caveats and honesty" section for why
that's a weak check.

Run:
    python bench_pld_3class_rerun.py
"""
from __future__ import annotations

import statistics
import time
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))

import mlx.core as mx  # noqa: F401  (imported for side-effects in mlx_lm)
from mlx_lm import load

from pld_spec_decode import run as pld_run
from prompts import PROMPTS

MODEL = "mlx-community/gemma-4-31b-it-4bit"
PROMPT_TOKENS = 800
MAX_TOKENS = 128
N_RUNS = 3
N_WARMUP = 1


def truncate_or_pad(tokenizer, raw: str, target: int) -> str:
    ids = tokenizer.encode(raw)
    if len(ids) >= target:
        return tokenizer.decode(ids[:target])
    pad = (
        "Additional historical context: the development of computer networks "
        "in the 1960s, the standardization of programming languages such as "
        "FORTRAN and COBOL, and the gradual miniaturization of components all "
        "contributed to the modern computing landscape. "
    )
    text = raw
    while len(tokenizer.encode(text)) < target:
        text = (
            text.replace("Question:", pad + "Question:", 1)
            if "Question:" in text
            else text + pad
        )
    return tokenizer.decode(tokenizer.encode(text)[:target])


def measure_one(model, tokenizer, prompt: str, k: int, n_min: int):
    prompt_ids = tokenizer.encode(prompt)
    n_prompt = len(prompt_ids)
    t_start = time.perf_counter()
    t_first = None
    n_gen = 0
    n_from_draft = 0
    tokens = []
    for tok, from_draft, t_now in pld_run(
        model, prompt_ids, max_tokens=MAX_TOKENS, k=k, n_max=4, n_min=n_min,
    ):
        if t_first is None:
            t_first = t_now
        tokens.append(int(tok))
        n_gen += 1
        if from_draft:
            n_from_draft += 1
    t_end = time.perf_counter()
    text = tokenizer.decode(tokens)
    ttfs = (t_first - t_start) if t_first else float("nan")
    wall = t_end - t_start
    decode_wall = (t_end - t_first) if t_first else float("nan")
    decode_tps = ((n_gen - 1) / decode_wall) if decode_wall and n_gen > 1 else float("nan")
    prefill_tps = (n_prompt / ttfs) if ttfs and ttfs > 0 else float("nan")
    total_tps = ((n_prompt + n_gen) / wall) if wall > 0 else float("nan")
    accept = (n_from_draft / max(1, n_gen)) if k > 0 else float("nan")
    return dict(
        n_prompt=n_prompt, n_gen=n_gen, ttfs=ttfs, wall=wall,
        prefill_tps=prefill_tps, decode_tps=decode_tps, total_tps=total_tps,
        accept=accept, text=text,
    )


def measure_grid(model, tokenizer, prompt, k, n_min):
    """1 warmup + N_RUNS measured. Returns dict of mean fields + per-run lists."""
    for _ in range(N_WARMUP):
        measure_one(model, tokenizer, prompt, k, n_min)
    runs = [measure_one(model, tokenizer, prompt, k, n_min) for _ in range(N_RUNS)]

    def col(name):
        vs = [r[name] for r in runs]
        if isinstance(vs[0], float):
            clean = [v for v in vs if v == v]  # filter NaN
            if not clean:
                return float("nan"), 0.0, vs
            mu = statistics.mean(clean)
            sd = statistics.stdev(clean) if len(clean) > 1 else 0.0
            return mu, sd, vs
        return vs[0], 0.0, vs

    pf, pf_sd, _ = col("prefill_tps")
    dc, dc_sd, _ = col("decode_tps")
    tt, tt_sd, _ = col("total_tps")
    tf, tf_sd, _ = col("ttfs")
    ac, ac_sd, _ = col("accept")
    return dict(
        prefill_mean=pf, prefill_sd=pf_sd,
        decode_mean=dc, decode_sd=dc_sd,
        total_mean=tt, total_sd=tt_sd,
        ttfs_mean=tf, ttfs_sd=tf_sd,
        accept_mean=ac, accept_sd=ac_sd,
        runs=runs,
    )


def main():
    print(f"[load] {MODEL}", flush=True)
    t0 = time.perf_counter()
    model, tokenizer = load(MODEL)
    print(f"[load] done in {time.perf_counter() - t0:.1f}s\n", flush=True)

    classes = ("passage", "code", "json_rag")
    grid = [(0, 2)] + [(2, n) for n in (2, 3)]  # (k, n_min); n_min unused for k=0

    results = {}

    for cls in classes:
        raw = PROMPTS[cls]
        prompt = truncate_or_pad(tokenizer, raw, PROMPT_TOKENS)
        n_actual = len(tokenizer.encode(prompt))
        print(f"=== prompt_class={cls}  prompt_tokens={n_actual}  max_tokens={MAX_TOKENS} ===",
              flush=True)
        results[cls] = {"prompt_tokens": n_actual}

        for k, n_min in grid:
            label = f"k={k}" if k == 0 else f"k={k} n_min={n_min}"
            print(f"  [{label}] running …", flush=True)
            r = measure_grid(model, tokenizer, prompt, k, n_min)
            results[cls][(k, n_min)] = r
            print(f"    decode={r['decode_mean']:6.2f} ± {r['decode_sd']:.2f}  "
                  f"prefill={r['prefill_mean']:7.2f}  total={r['total_mean']:6.2f}  "
                  f"TTFS={r['ttfs_mean']*1000:5.0f}ms  "
                  f"accept={r['accept_mean']:.3f}", flush=True)

        baseline_text = results[cls][(0, 2)]["runs"][0]["text"]
        results[cls]["baseline_text"] = baseline_text
        for k, n_min in grid:
            if k == 0:
                continue
            sample = results[cls][(k, n_min)]["runs"][0]["text"]
            parity = (sample == baseline_text)
            print(f"  [k={k} n_min={n_min}] greedy parity vs k=0: "
                  f"{'PASS' if parity else 'FAIL'}", flush=True)
        print()

    print("\n" + "=" * 80)
    print("SUMMARY  (mean of 3 runs after 1 warmup)")
    print("=" * 80)
    print(f"{'class':<10} {'k':>2} {'n_min':>5} {'prefill':>9} {'decode':>9} "
          f"{'total':>8} {'TTFS_ms':>9} {'accept':>8} {'parity':>7}")
    print("-" * 80)
    for cls in classes:
        baseline_text = results[cls]["baseline_text"]
        for k, n_min in grid:
            r = results[cls][(k, n_min)]
            sample = r["runs"][0]["text"]
            parity = "—" if k == 0 else ("PASS" if sample == baseline_text else "FAIL")
            print(f"{cls:<10} {k:>2} {n_min if k > 0 else '—':>5} "
                  f"{r['prefill_mean']:>9.2f} {r['decode_mean']:>9.2f} "
                  f"{r['total_mean']:>8.2f} {r['ttfs_mean']*1000:>9.0f} "
                  f"{r['accept_mean']:>7.3f}  {parity:>7}")


if __name__ == "__main__":
    main()
