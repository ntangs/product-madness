# Product Madness

A Cooking Madness-style arcade game for 1-5 minute work tasks. Log a micro-task, lock your own time estimate, then race a countdown set by an AI par. Finish under par for stars, chain combos, level up the kitchen brigade, clear daily quests - and try to out-estimate the AI in the weekly showdown.

- **Play online:** https://ntangs.github.io/product-madness/
- Play locally: double-click `Product Madness.bat` (opens a chromeless game window), or open `Product Madness v1.html` in any browser. Online and local saves are separate; move progress with Settings > Export/Import.
- Data lives in this browser's localStorage. Back up via Settings > Export.
- Optional: paste an Anthropic API key in Settings for Claude-powered pars and trash talk. Keep member names and PHI out of task titles.
- Self-test: open the file with `?selftest` appended to the URL (82 assertions).
- Voice: tap the 🎤 next to the task box to speak a task (browser speech API, nothing external).
- Build it yourself: the full design spec and the step-by-step implementation plan (complete code per task) are in `docs/superpowers/` - an agent or a patient human can rebuild or extend the game from them.
- Spec: `docs/superpowers/specs/2026-07-16-product-madness-design.md` · Plan: `docs/superpowers/plans/2026-07-16-product-madness-v1.md`
