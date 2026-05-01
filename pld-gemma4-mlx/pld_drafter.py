"""Prompt Lookup Decoding (PLD) drafter.

Pure-Python n-gram suffix-match drafter. Zero DRAM bandwidth: just scans
the existing token history (prompt + tokens generated so far) for the
most recent occurrence of the current suffix and emits the next k tokens
that followed that occurrence.

Reference: Saxena (2023), "Prompt Lookup Decoding".
https://github.com/apoorvumang/prompt-lookup-decoding

This module has no dependency on MLX or any tokenizer. It operates on
plain Python ints (token ids).
"""

from __future__ import annotations

from typing import List, Sequence


def propose(
    history: Sequence[int],
    k: int,
    n_max: int = 4,
    n_min: int = 2,
) -> List[int]:
    """Return up to ``k`` proposed token ids by suffix-matching ``history``.

    Algorithm:
      For n in n_max, n_max-1, ..., n_min:
        suffix = history[-n:]
        scan history[:-n] right-to-left for the most recent occurrence of
        ``suffix``; if found at position p (so history[p:p+n] == suffix),
        emit history[p+n : p+n+k] (clipped to whatever is available).
        If that yields >=1 token, return it.
      Otherwise return [].

    Notes:
      - We scan right-to-left to bias toward the most recent context.
      - We do NOT pad with shorter draft if the match runs off the end of
        history; we just return the shorter list. The verifier still gets
        a free token at the divergence point in the spec-decode loop.
      - n_min=2 keeps the false-positive rate manageable; single-token
        matches in language model outputs are too noisy to be useful.

    Args:
        history: full token id stream (prompt + generated so far). At
            least 1 token long.
        k: target number of draft tokens to propose.
        n_max: maximum n-gram length to try first.
        n_min: minimum n-gram length to fall back to.

    Returns:
        list of token ids, length in [0, k].
    """
    if k <= 0 or len(history) < n_min + 1:
        return []

    H = len(history)
    n_max_eff = min(n_max, H - 1)
    if n_max_eff < n_min:
        return []

    # Treat history as a list once for cheap slicing.
    h = list(history) if not isinstance(history, list) else history

    for n in range(n_max_eff, n_min - 1, -1):
        suffix = h[H - n : H]
        # Search for `suffix` in h[: H - n], right-to-left.
        # Using a simple right-to-left scan; the inputs are short enough
        # (<= a few thousand tokens) that this is well under a millisecond.
        end_search = H - n  # exclusive upper bound
        # Iterate candidate start positions from the right.
        first = suffix[0]
        for p in range(end_search - 1, -1, -1):
            if h[p] != first:
                continue
            # Compare full suffix.
            if h[p : p + n] == suffix:
                start = p + n
                end = min(start + k, H - n)  # don't include suffix itself
                # Actually, the continuation comes from positions
                # immediately after this past occurrence of the suffix.
                # The continuation can run all the way to H (the end of
                # current history), but we clip to k tokens.
                end = min(start + k, H)
                draft = h[start:end]
                if draft:
                    return list(draft)
                # else: matched but no continuation tokens (suffix at the
                # very end of an earlier identical span). Try shorter n.
                break
    return []


# --- light self-test (no inference, no model) -------------------------------
def _selftest() -> None:
    # exact repeat
    h = [1, 2, 3, 4, 5, 1, 2, 3]
    assert propose(h, k=2, n_max=4, n_min=2) == [4, 5], propose(h, k=2)

    # fall-back to shorter n-gram
    h = [9, 1, 2, 7, 8, 1, 2]
    # suffix [1,2] -> earlier occurrence at index 1, continuation [7,8]
    assert propose(h, k=2, n_max=4, n_min=2) == [7, 8], propose(h, k=2)

    # no match -> []
    h = [10, 20, 30, 40]
    assert propose(h, k=3, n_max=4, n_min=2) == []

    # overlap allowed: continuation can run through current suffix region
    h = [1, 2, 3, 1, 2]
    # suffix [1,2] matches at index 0; continuation h[2:5] == [3,1,2]
    assert propose(h, k=4, n_max=4, n_min=2) == [3, 1, 2], propose(h, k=4)

    # tiny history
    assert propose([5], k=2) == []
    assert propose([], k=2) == []

    print("[pld_drafter] selftest ok")


if __name__ == "__main__":
    _selftest()
