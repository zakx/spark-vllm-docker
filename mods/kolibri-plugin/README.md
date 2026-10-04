# kolibri-plugin

Installs the `aleph-alpha-inference` package, which provides the vLLM plugin
for `Aleph-Alpha/Kolibri-1` (model architecture, `kolibri1` reasoning parser,
and `kolibri1` tool-call parser). vLLM finds the plugin through its
`vllm.general_plugins` entry point.

The package declares `vllm>=0.29,<0.30`. The mod installs it with `--no-deps`
so that the image's vLLM, torch, and transformers builds stay unchanged. The
mod stops if `transformers<5.5.3` and prints a warning if vLLM is not 0.29.x.

Used by `recipes/kolibri-1.yaml`.
