# OP subagents

Small model-specific launchers for `op`. Set `OPENROUTER_API_KEY` first.

```bash
export OPENROUTER_API_KEY=...
~/code/dotfiles/subagents/op-deepseek.sh "Review this diff"
```

Each command forwards extra arguments, for example `--no-session` or
`--auto-approve`.

Commands:

- `op-deepseek.sh` — DeepSeek V4 Flash direct (`deepseek` provider, `DEEPSEEK_API_KEY`), not via OpenRouter
- `op-glm.sh` — GLM 5.3 through OpenRouter
- `op-gemini.sh` — Gemini 3.7 Flash through OpenRouter
- `op-opus.sh` — Claude Opus 5 through OpenRouter
- `op-gpt.sh` — GPT 6 Astra through OpenRouter
- `op-muse.sh` — Meta Muse Spark 1.3 through OpenPaths (`muse-spark-1.3`); cheap fixer: `op-muse.sh -p --auto-approve "fix failing test X"`
- `op-oxalpha.sh` — Ox Alpha through OpenRouter stealth routing
- `op-bunny.sh` — Space Bunny Alpha through OpenRouter stealth routing
- `op-mimo.sh` — Xiaomi MiMo-V2.6-Pro through OpenPaths (`xiaomi/mimo-v2.6-pro`), 1M context agentic model
- `op-runanywhere.sh` (`opany`) — GLM-5.3-Flash direct on RunAnywhere/Wally Cloud (`runanywhere` provider, `RUNANYWHERE_API_KEY`), not via OpenRouter; `OPANY_MODEL=qwen3.8-27b` swaps to the other model on the same key

# di subagents

Model-pinned launchers for `di` (the `lee101/di` fork of fx). `di-locate.sh`
finds the built binary at `<code>/di/zig-out/bin/di` under `$CODE_DIR`,
`~/code`, `/d/code`, `/vfast/data/code`, `/media/pcd/code` or
`/nvme0n1-disk/code`, first match wins; set `DI` to pin one. `di-bunny.sh` uses
`<code>/monitoring/run_agent.py` when present and the plain hard timeout
otherwise. `di-bunny-file.sh NAME PROMPT_FILE` keeps the full transcript in
`<code>/visualbench/gamefleet/runs` (or `~/.local/state/di-runs`) and prints
only the last 100 lines, so read the tail first and open the log only when needed. Set `OPENPATHS_API_KEY` first; `FX_MODEL` picks the
OpenPaths model and di selects the matching credential and route itself.

```bash
export OPENPATHS_API_KEY=...
dimuse "fix the /model picker so it lists every catalog"
dideep ask --yolo -- "review this diff"
```

Aliases (bashrc) and scripts:

- `dimuse` / `di-muse.sh` — Meta Muse Spark 1.3 (`muse-spark-1.3-contributor`), the default for di's self-improvement loop
- `digpt` / `di-gpt.sh` — GPT 5.6
- `diglm` / `di-glm.sh` — GLM 5.3
- `dideep` / `di-deep.sh` — DeepSeek V4 Flash (vision, experimental); also di's automatic fallback model
- `di`, `din`, `dini` — plain di, autonomous next steps, autonomous next steps + ideas
- `diself` — `scripts/self-improve.sh`: one autonomous di turn on di's own tree, gated by build + tests, then commit and push
- `diup` — `scripts/self-improve.sh --merge-upstream`: merge `vercel-labs/fx` main into di, let di resolve conflicts, gate, push

Every launcher forwards extra arguments, so `dimuse ask --json -- "..."` works.

# Unattended monitor fallback chain

Production monitors do not call a model CLI directly; they call the shim
`~/.local/monitor-bin/codex` (source: `bitbankgo/monitoring/codex-agent.sh`),
which tries, in order:

1. locally built codex (`~/code/codex`)
2. stock codex (`/usr/local/bin/codex`)
3. DeepSeek V4 Flash through `op` (needs `DEEPSEEK_API_KEY`)
4. Meta Muse Spark through `omp` (needs `META_API_KEY`)

Keys are read from `~/.secretbashrc` / project `.env`, never from unit files.
Only when every tier fails does the monitor fall through to emailing a human.
Force one tier for testing with `CODEX_SHIM_FORCE=deepseek|muse|local|stock`.

Both codex tiers run `gpt-6.1-sol` with reasoning effort `high` by default
(`MONITOR_MODEL` / `MONITOR_EFFORT` override it); a monitor that passes its own
`-m`/`--model` or `model_reasoning_effort` still wins. The op/omp fallback tiers
keep their own independent models.
