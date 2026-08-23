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
- `op-gpt.sh` — GPT 5.6 Sol through OpenRouter
- `op-oxalpha.sh` — Ox Alpha through OpenRouter stealth routing
