# OP subagents

Small model-specific launchers for `op`. Set `OPENROUTER_API_KEY` first.

```bash
export OPENROUTER_API_KEY=...
~/code/dotfiles/subagents/op-deepseek.sh "Review this diff"
```

Each command forwards extra arguments, for example `--no-session` or
`--auto-approve`.

Commands:

- `op-deepseek.sh` — DeepSeek V4 Flash through OpenRouter
- `op-glm.sh` — GLM 5.3 through OpenRouter
- `op-gemini.sh` — Gemini 3.7 Flash through OpenRouter
- `op-opus.sh` — Claude Opus 5 through OpenRouter
- `op-gpt.sh` — GPT 6 Astra through OpenRouter
- `op-oxalpha.sh` — Ox Alpha through OpenRouter stealth routing

# di subagents

Model-pinned launchers for `di` (`/vfast/data/code/fx/zig-out/bin/di`, the
`lee101/di` fork of fx). Set `OPENPATHS_API_KEY` first; `FX_MODEL` picks the
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
