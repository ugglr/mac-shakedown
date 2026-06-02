#!/bin/bash
# llama-bench.sh: OPT-IN combined CPU + GPU + memory load via llama.cpp.
#
# This is the only phase that reaches the network and runs third-party code. It
# is off unless you pass `./run --llama`, and it degrades to a "skipped" verdict
# (never failing the run) at every step. It exists because the M5 Max defect was
# reported on AI workloads, and an LLM inference benchmark is the one test that
# stresses the CPU, the GPU (Metal), and the memory subsystem together under
# sustained load, which none of the built-in phases do.
#
# What it does, opt-in only:
#   1. git clone llama.cpp (ggml-org) at a pinned ref into a cache dir
#   2. build llama-bench with cmake (Metal + Accelerate, both ship with macOS)
#   3. obtain a small GGUF model (LLAMA_MODEL path, or download LLAMA_MODEL_URL)
#   4. run `llama-bench` and record prompt/generation tokens-per-second + spread
# Each step skips cleanly if its tool / network / model is unavailable. The clone
# and build are cached so reruns are fast. See SECURITY.md for the disclosure.
#
# Output: JSON to stdout. Progress to stderr.
#
# Env knobs:
#   LLAMA_REPO        default https://github.com/ggml-org/llama.cpp
#   LLAMA_REF         default a pinned tag (override to bump); falls back to the
#                     default branch with a recorded note if the tag is missing
#   LLAMA_REPS        default 5   (llama-bench repetitions, for run-to-run spread)
#   LLAMA_MODEL       path to a local .gguf (preferred; skips the download)
#   LLAMA_MODEL_URL   default small GGUF to download if LLAMA_MODEL is unset
#   LLAMA_MODEL_SHA256  optional. If set, the downloaded model is verified against
#                     this sha256 before it is cached; a mismatch skips the phase.
#                     Unset means the download is NOT integrity-checked (see
#                     SECURITY.md); provide a local LLAMA_MODEL for guaranteed
#                     consistency.
#   SHAKEDOWN_LLAMA_DIR  cache dir (default ~/.cache/shakedown/llama)

set -euo pipefail

LLAMA_REPO=${LLAMA_REPO:-https://github.com/ggml-org/llama.cpp}
LLAMA_REF=${LLAMA_REF:-b4585}
LLAMA_REPS=${LLAMA_REPS:-5}
LLAMA_DIR=${SHAKEDOWN_LLAMA_DIR:-$HOME/.cache/shakedown/llama}
LLAMA_MODEL=${LLAMA_MODEL:-}
LLAMA_MODEL_URL=${LLAMA_MODEL_URL:-https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf}
LLAMA_MODEL_SHA256=${LLAMA_MODEL_SHA256:-}

if ! [[ "$LLAMA_REPS" =~ ^[0-9]+$ ]] || (( LLAMA_REPS < 1 )); then
  echo "llama-bench.sh: LLAMA_REPS must be a positive integer (got '$LLAMA_REPS')" >&2
  exit 2
fi

emit_skipped() {
  # $1: human-readable reason. Routed through python3 so the JSON is well-formed.
  python3 - "$1" <<'PYEOF'
import json
import sys
reason = sys.argv[1]
print(json.dumps({
    "workload": "llama.cpp llama-bench (combined CPU + GPU + memory, AI inference)",
    "verdict": "skipped",
    "data_quality": "skipped",
    "data_quality_notes": [reason],
    "verdict_reasons": [reason + "; phase skipped"],
}, indent=2))
PYEOF
}

if ! command -v git >/dev/null 2>&1; then
  emit_skipped "git not found (the --llama phase needs git to clone llama.cpp)"
  exit 0
fi
if ! command -v cmake >/dev/null 2>&1; then
  emit_skipped "cmake not found (the --llama phase builds llama.cpp with cmake; install it, e.g. brew install cmake, to enable this opt-in phase)"
  exit 0
fi

mkdir -p "$LLAMA_DIR"
SRC="$LLAMA_DIR/llama.cpp"
BIN="$SRC/build/bin/llama-bench"
ref_note=""

# 1) Clone (cached). Prefer the pinned ref; fall back to the default branch.
if [[ ! -d "$SRC/.git" ]]; then
  echo "llama-bench: cloning $LLAMA_REPO @ $LLAMA_REF (one-time, cached in $LLAMA_DIR)" >&2
  if ! git clone --depth 1 --branch "$LLAMA_REF" "$LLAMA_REPO" "$SRC" 2>/dev/null; then
    if ! git clone --depth 1 "$LLAMA_REPO" "$SRC" 2>/dev/null; then
      emit_skipped "git clone failed (offline, or $LLAMA_REPO unreachable); set LLAMA_MODEL and retry on a network"
      exit 0
    fi
    ref_note="pinned ref $LLAMA_REF not found; built from the default branch instead"
  fi
fi

# 2) Build llama-bench (cached). Metal + Accelerate are used automatically on macOS.
if [[ ! -x "$BIN" ]]; then
  echo "llama-bench: building llama-bench with cmake (one-time, ~3-5 min)" >&2
  if ! cmake -S "$SRC" -B "$SRC/build" -DCMAKE_BUILD_TYPE=Release >/dev/null 2>&1; then
    emit_skipped "cmake configure failed"
    exit 0
  fi
  if ! cmake --build "$SRC/build" --target llama-bench -j >/dev/null 2>&1; then
    emit_skipped "llama.cpp build failed"
    exit 0
  fi
fi
if [[ ! -x "$BIN" ]]; then
  emit_skipped "build produced no llama-bench binary at $BIN"
  exit 0
fi

# 3) Model: prefer a user-provided path, else download the pinned small GGUF.
MODEL="$LLAMA_MODEL"
if [[ -z "$MODEL" ]]; then
  MODEL="$LLAMA_DIR/model.gguf"
  if [[ ! -f "$MODEL" ]]; then
    echo "llama-bench: downloading model (one-time, cached): $LLAMA_MODEL_URL" >&2
    if ! curl -fL --retry 2 -o "$MODEL.partial" "$LLAMA_MODEL_URL" 2>/dev/null; then
      rm -f "$MODEL.partial"
      emit_skipped "model download failed; set LLAMA_MODEL=/path/to/model.gguf (any small GGUF) and rerun"
      exit 0
    fi
    # Optional integrity check. A complete but corrupted or tampered download
    # would otherwise be cached and run, so verify when a hash is provided.
    if [[ -n "$LLAMA_MODEL_SHA256" ]]; then
      got=$(shasum -a 256 "$MODEL.partial" 2>/dev/null | awk '{print $1}')
      if [[ "$got" != "$LLAMA_MODEL_SHA256" ]]; then
        rm -f "$MODEL.partial"
        emit_skipped "model checksum mismatch (got ${got:-none}, expected $LLAMA_MODEL_SHA256); refusing to cache"
        exit 0
      fi
    fi
    mv "$MODEL.partial" "$MODEL"
  fi
fi
if [[ ! -f "$MODEL" ]]; then
  emit_skipped "no model file available; set LLAMA_MODEL=/path/to/model.gguf"
  exit 0
fi

# 4) Run the benchmark. -o json gives a stable, parseable result.
echo "llama-bench: running ($LLAMA_REPS reps, model $(basename "$MODEL"))" >&2
T0=$(date +%s)
if ! RAW=$("$BIN" -m "$MODEL" -p 512 -n 128 -r "$LLAMA_REPS" -o json 2>/dev/null); then
  emit_skipped "llama-bench run failed (model incompatible or out of memory?)"
  exit 0
fi
T1=$(date +%s)

python3 - "$RAW" "$((T1 - T0))" "$MODEL" "$LLAMA_REF" "$ref_note" <<'PYEOF'
import json
import sys

try:
    rows = json.loads(sys.argv[1])
except json.JSONDecodeError:
    print(json.dumps({
        "workload": "llama.cpp llama-bench (combined CPU + GPU + memory, AI inference)",
        "verdict": "skipped",
        "data_quality": "skipped",
        "data_quality_notes": ["llama-bench produced unparseable output"],
        "verdict_reasons": ["llama-bench output not JSON; phase skipped"],
    }, indent=2))
    sys.exit(0)

wall = int(sys.argv[2])
model = sys.argv[3].rsplit("/", 1)[-1]
ref = sys.argv[4]
ref_note = sys.argv[5]

backend = None
prompt = None  # (avg_ts, stddev_ts)
gen = None
for e in rows if isinstance(rows, list) else []:
    backend = e.get("backend_name") or e.get("backend") or backend
    n_gen = e.get("n_gen", 0) or 0
    n_prompt = e.get("n_prompt", 0) or 0
    avg = e.get("avg_ts")
    std = e.get("stddev_ts", 0) or 0
    if avg is None:
        continue
    if n_prompt and not n_gen:
        prompt = (avg, std)
    elif n_gen and not n_prompt:
        gen = (avg, std)

if prompt is None and gen is None:
    print(json.dumps({
        "workload": "llama.cpp llama-bench (combined CPU + GPU + memory, AI inference)",
        "verdict": "skipped",
        "data_quality": "skipped",
        "data_quality_notes": ["llama-bench returned no prompt/generation rows"],
        "verdict_reasons": ["no usable llama-bench result; phase skipped"],
    }, indent=2))
    sys.exit(0)


def spread(t):
    return round(t[1] / t[0] * 100, 2) if t and t[0] else None


notes = []
if ref_note:
    notes.append(ref_note)

summary = []
if prompt:
    summary.append(f"prompt {prompt[0]:,.1f} tok/s")
if gen:
    summary.append(f"gen {gen[0]:,.1f} tok/s")

result = {
    "workload": "llama.cpp llama-bench (combined CPU + GPU + memory, AI inference)",
    "model": model,
    "llama_ref": ref,
    "backend": backend,
    "prompt_tok_per_s": round(prompt[0], 2) if prompt else None,
    "prompt_tok_per_s_stddev": round(prompt[1], 2) if prompt else None,
    "prompt_spread_pct": spread(prompt),
    "gen_tok_per_s": round(gen[0], 2) if gen else None,
    "gen_tok_per_s_stddev": round(gen[1], 2) if gen else None,
    "gen_spread_pct": spread(gen),
    "wall_seconds": wall,
    "data_quality": "ok",
    "data_quality_notes": notes,
    "verdict": "info",
    "verdict_reasons": [
        f"{backend or 'llama.cpp'}: " + ", ".join(summary)
        + (f" (gen spread {spread(gen):.1f}%)" if gen and spread(gen) is not None else ""),
        "informational in v0.2; GPU/AI thresholds land once the corpus has baselines"
    ],
}
print(json.dumps(result, indent=2))
PYEOF
