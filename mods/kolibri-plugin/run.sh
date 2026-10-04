#!/bin/bash
set -euo pipefail

# Install the Aleph Alpha Kolibri vLLM plugin without touching the image's
# vLLM, torch, or transformers builds.

PREFIX="[kolibri-plugin]"
PYTHON_BIN="${PYTHON_BIN:-python3}"
PLUGIN_DIST="aleph-alpha-inference"
PLUGIN_SPEC="aleph-alpha-inference>=1,<2"
MIN_TRANSFORMERS="5.5.3"

dist_version() {
  "$PYTHON_BIN" -c "import importlib.metadata as m, sys; print(m.version(sys.argv[1]))" "$1" 2>/dev/null || true
}

if [ -n "$(dist_version "$PLUGIN_DIST")" ]; then
  echo "$PREFIX $PLUGIN_DIST already installed; skipping install."
else
  # --no-deps: the plugin pins vllm<0.30, which would replace the image's vLLM build.
  echo "$PREFIX Installing $PLUGIN_SPEC (--no-deps)"
  if command -v uv >/dev/null 2>&1; then
    uv pip install --no-deps "$PLUGIN_SPEC"
  elif "$PYTHON_BIN" -m pip --version >/dev/null 2>&1; then
    "$PYTHON_BIN" -m pip install --no-deps "$PLUGIN_SPEC"
  else
    echo "$PREFIX Neither uv nor Python pip is available." >&2
    exit 1
  fi
fi

plugin_version="$(dist_version "$PLUGIN_DIST")"
if [ -z "$plugin_version" ]; then
  echo "$PREFIX $PLUGIN_DIST is not installed after the install step." >&2
  exit 1
fi

"$PYTHON_BIN" - "$PLUGIN_DIST" <<'PY'
import importlib.metadata as m
import sys

dist = sys.argv[1]
eps = [
    ep for ep in m.entry_points(group="vllm.general_plugins")
    if ep.dist is not None and ep.dist.name.lower().replace("_", "-") == dist
]
if not eps:
    sys.exit(f"[kolibri-plugin] {dist} registers no vllm.general_plugins entry point.")
print("[kolibri-plugin] vLLM plugin entry points: " + ", ".join(ep.name for ep in eps))
PY

vllm_version="$(dist_version vllm)"
torch_version="$(dist_version torch)"
transformers_version="$(dist_version transformers)"
echo "$PREFIX $PLUGIN_DIST=$plugin_version vllm=${vllm_version:-none} torch=${torch_version:-none} transformers=${transformers_version:-none}"

if ! "$PYTHON_BIN" - "$transformers_version" "$MIN_TRANSFORMERS" <<'PY'
import sys
from packaging.version import InvalidVersion, Version

try:
    ok = Version(sys.argv[1]) >= Version(sys.argv[2])
except InvalidVersion:
    ok = False
sys.exit(0 if ok else 1)
PY
then
  echo "$PREFIX transformers>=$MIN_TRANSFORMERS is required (found: ${transformers_version:-none})." >&2
  exit 1
fi

case "$vllm_version" in
  0.29.*) ;;
  *) echo "$PREFIX WARNING: $PLUGIN_DIST targets vLLM 0.29.x; this image has ${vllm_version:-none}." ;;
esac
