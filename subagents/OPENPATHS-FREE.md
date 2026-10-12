# Free OpenPaths Companions

`op-openpathsfree.sh --print --no-tools --no-session "prompt"`

Requires an exported `OPENPATHS_API_KEY`. Default model is
`nous/poolside/laguna-s-2.1:free`. `OP_FREE_MODEL` may select another `:free`
model; non-free selectors and CLI routing overrides are rejected.

The OP wrapper uses supported `models.yml` custom-provider configuration in a
private per-run temporary agent directory. It pins all model roles to the
selected free model, disables discovered extensions, and clears fallback
chains. It does not edit global OP settings, store API keys, or fall back to
OpenRouter. Temporary OP sessions/caches are removed when the process exits.
The wrapper's free policy covers model routing, not arbitrary shell commands
an approved tool might execute. Use `--no-tools` for story-only requests.

Tests: `python subagents/test_op_openpathsfree.py -v` and
`bash -n subagents/op-openpathsfree.sh`.

On 2026-10-12, a bounded live no-tools OP request returned `FREE_ROUTE_OK`.
The existing DI companion also completed a real file-read tool roundtrip;
the generated two-game story passed schema/word-count validation. These are
smoke tests, not a claim of global DI/OP parity or comprehensive tool coverage.
Existing DI wrappers remain unchanged. Direct DI `FX_PROVIDER=deepseek`
configuration is unsupported; do not describe its OpenRouter wrapper as a
direct DeepSeek provider.
