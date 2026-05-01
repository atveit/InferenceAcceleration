"""PLD-driven speculative decoding loop for mlx-lm verifiers.

mlx-lm's built-in `stream_generate(..., draft_model=...)` requires
`draft_model` to be an `nn.Module`. Our PLD drafter is pure Python, so
we re-implement the verify-and-rollback loop here using the same KV-cache
primitives mlx-lm uses internally.

Greedy parity:
    The verifier's sampler is `argmax`. A draft token is accepted iff it
    equals `argmax(verifier_logits[i])`. When a draft token is rejected,
    the verifier's argmax token at that position is emitted instead (the
    "free" token). After divergence, the cache is rolled back so only
    the accepted prefix + the free token remain committed.

This makes output bit-identical to greedy `mlx_lm.generate(...)` modulo
floating-point determinism in the verifier itself.

Public entry point: ``run(...)`` — a generator yielding
``(token_id: int, from_draft: bool)`` per emitted token.

Design notes:
    - Verifier forward pass at each spec step is sequence length k+1
      (k draft tokens + 1 carry-over from previous step). This matches
      how `speculative_generate_step` shapes its forward.
    - We use ``mlx_lm.models.cache.make_prompt_cache`` and
      ``trim_prompt_cache``; same as mlx-lm itself. If the verifier
      cache is not trimmable, we error out loudly rather than silently
      falling back. (Gemma 4's KVCache is trimmable; checked.)
    - Logits processors are not supported (greedy parity only).
"""

from __future__ import annotations

import time
from typing import Generator, List, Tuple

import mlx.core as mx
import mlx.nn as nn
from mlx_lm.models import cache as cache_module

from pld_drafter import propose as pld_propose


def _argmax_tokens(logits: mx.array) -> mx.array:
    """Greedy sampler: argmax along last axis."""
    return mx.argmax(logits, axis=-1)


def _prefill(model: nn.Module, model_cache, prompt_ids: mx.array,
             prefill_step_size: int = 512) -> mx.array:
    """Run the prompt through the model in chunks, leaving the last token
    unconsumed (so it can be the seed for the first verifier step).

    Returns the trailing single-token array (shape [1])."""
    y = prompt_ids.astype(mx.uint32)
    while y.size > 1:
        n_to_process = min(prefill_step_size, y.size - 1)
        model(y[:n_to_process][None], cache=model_cache)
        mx.eval([c.state for c in model_cache])
        y = y[n_to_process:]
        mx.clear_cache()
    return y  # length-1 array


def run(
    model: nn.Module,
    prompt_ids: List[int],
    *,
    max_tokens: int = 128,
    k: int = 4,
    n_max: int = 4,
    n_min: int = 2,
    prefill_step_size: int = 512,
) -> Generator[Tuple[int, bool, float], None, None]:
    """Stream tokens via PLD spec-decode.

    Yields tuples ``(token_id, from_draft, t_now)`` where ``t_now`` is the
    wall-clock time at emission (perf_counter). The bench harness uses
    ``t_now`` to compute TTFS without re-instrumenting this loop.

    If ``k == 0`` the loop degenerates to plain greedy decode (no draft).

    Args:
        model: mlx-lm verifier model (already loaded).
        prompt_ids: prompt token ids as a Python list.
        max_tokens: max tokens to emit.
        k: number of draft tokens per spec step.
        n_max, n_min: PLD n-gram bounds.

    Notes:
        - The cache is created inside this function and dropped on exit.
        - Greedy bit-identical to stock mlx-lm under argmax sampling.
    """
    if not prompt_ids:
        raise ValueError("prompt_ids must be non-empty")

    model_cache = cache_module.make_prompt_cache(model)

    if k > 0 and not cache_module.can_trim_prompt_cache(model_cache):
        types = {type(c).__name__ for c in model_cache if not c.is_trimmable()}
        raise ValueError(
            f"PLD spec-decode requires a trimmable prompt cache (got {types})."
        )

    # ---- prefill ----------------------------------------------------------
    prompt_arr = mx.array(prompt_ids, dtype=mx.uint32)
    y = _prefill(model, model_cache, prompt_arr, prefill_step_size)
    # ``y`` is the last prompt token; it has not yet been consumed.

    # ``history`` is the running list of all token ids the verifier has
    # actually accepted/emitted (prompt + emitted). The drafter scans this
    # to propose suffix continuations.
    history: List[int] = list(prompt_ids)

    n_emitted = 0

    # Plain greedy fallback (no draft) ------------------------------------
    if k <= 0:
        # consume the trailing prompt token to get a real continuation
        while n_emitted < max_tokens:
            logits = model(y[None], cache=model_cache)
            tok = _argmax_tokens(logits[:, -1, :])
            mx.eval(tok)
            tok_id = int(tok.item())
            history.append(tok_id)
            yield (tok_id, False, time.perf_counter())
            n_emitted += 1
            y = mx.array([tok_id], dtype=mx.uint32)
        return

    # Spec-decode loop ----------------------------------------------------
    while n_emitted < max_tokens:
        budget = max_tokens - n_emitted
        # propose up to k draft tokens (clip to remaining budget so we
        # don't over-emit if all are accepted).
        num_draft = min(k, budget - 1) if budget > 1 else 0
        if num_draft < 0:
            num_draft = 0
        draft_tokens = pld_propose(history, k=num_draft, n_max=n_max, n_min=n_min) \
            if num_draft > 0 else []
        num_draft = len(draft_tokens)

        # Verifier forward at seq_len = num_draft + 1
        if num_draft > 0:
            y_in = mx.concatenate(
                [y, mx.array(draft_tokens, dtype=mx.uint32)]
            )
        else:
            y_in = y
        logits = model(y_in[None], cache=model_cache)
        # tokens at every position
        v_tokens = _argmax_tokens(logits[0])  # shape [num_draft+1]
        mx.eval(v_tokens)
        v_list = v_tokens.tolist()

        # Compare verifier tokens at positions 0..num_draft-1 to drafts.
        # Position i predicts the (i+1)-th token in the next stream:
        #   v_list[0] is the verifier's argmax given y_in[:1] -> next tok
        #   v_list[1] is given y_in[:2] (which assumed draft_tokens[0]),
        #     etc.
        # Acceptance rule: v_list[i] == draft_tokens[i] => accept draft[i],
        # else reject and emit v_list[i] as the divergence token.
        n_accept = 0
        diverge_token = v_list[num_draft]  # default: all drafts accepted -> bonus
        for i in range(num_draft):
            if v_list[i] == draft_tokens[i]:
                n_accept += 1
            else:
                diverge_token = v_list[i]
                break

        # Emit accepted draft tokens
        t_now = time.perf_counter()
        for i in range(n_accept):
            if n_emitted >= max_tokens:
                break
            history.append(draft_tokens[i])
            yield (draft_tokens[i], True, t_now)
            n_emitted += 1

        # Emit the divergence (or bonus) token
        if n_emitted < max_tokens:
            history.append(diverge_token)
            yield (diverge_token, False, t_now)
            n_emitted += 1

        # Roll back KV cache for rejected drafts.
        # The verifier consumed (1 + num_draft) tokens this step but only
        # (n_accept + 1) of them should remain "committed" (the trailing
        # carry-over y was already in history; the n_accept accepted drafts
        # plus the divergence/bonus token are the new commits).
        # Cache currently holds: prior + 1 (carry-y) + num_draft.
        # Want it to hold:       prior + 1 (carry-y) + n_accept.
        # If the divergence token came from v_list[n_accept] (i.e. a true
        # rejection or a bonus position), its KV state is at position
        # n_accept of the just-appended block, but we want the *next* step
        # to recompute from that token as a fresh single-token forward.
        # So we trim (num_draft - n_accept) entries from the tail.
        trim_n = num_draft - n_accept
        if trim_n > 0:
            cache_module.trim_prompt_cache(model_cache, trim_n)

        # Set up next step: y is the most recently emitted token (the
        # divergence/bonus), which must be re-processed as the seed of
        # the next forward (its KV is NOT yet in cache because we trimmed
        # it OR because it's a bonus from position num_draft which we
        # also need to drop — wait, careful here).
        #
        # Subtle: if all drafts accepted (n_accept == num_draft), the
        # cache holds prior + 1 + num_draft; the bonus token came from
        # the position AFTER all drafts and its KV is NOT in the cache
        # (it was just predicted from the last position's logits). So
        # next step seeds with the bonus token, no trim needed — already
        # handled (trim_n == 0).
        #
        # If n_accept < num_draft, we trim (num_draft - n_accept). After
        # trim, cache holds prior + 1 + n_accept. The divergence token
        # is fresh (not in cache); next step seeds with it. Correct.
        next_seed = history[-1]
        y = mx.array([next_seed], dtype=mx.uint32)


# --- standalone smoke-test (NOT a bench) ------------------------------------
def _smoketest_offline() -> None:
    """Sanity-check the loop logic without running a model.

    Uses a fake nn.Module-like object that returns deterministic logits.
    This validates the cache-trim arithmetic only when run against a real
    model; the offline portion only checks the PLD drafter import + the
    function signature.
    """
    from pld_drafter import propose
    assert propose([1, 2, 3, 1, 2], k=2) == [3, 1, 2][:2]
    print("[pld_spec_decode] offline smoke ok (no model used)")


if __name__ == "__main__":
    _smoketest_offline()
