# Product Madness

A Cooking Madness-style arcade game for 1-5 minute work tasks. Log a micro-task, lock your own time estimate, then race a countdown set by an AI par. Finish under par for stars, chain combos, level up the kitchen brigade, clear daily quests - and try to out-estimate the AI in the weekly showdown.

- **Play online:** https://ntangs.github.io/product-madness/
- Play locally: double-click `Product Madness.bat` (opens a chromeless game window), or open `Product Madness v1.html` in any browser. Online and local saves are separate; move progress with Settings > Export/Import.
- Data lives in this browser's localStorage. Back up via Settings > Export.
- Optional: give the AI rival a real brain - pick a provider in Settings and paste a key. **Gemini (Google) has a free tier** (key at aistudio.google.com/apikey; free-tier content may be used to improve Google's products) or **Claude (Anthropic)** pay-as-you-go (console.anthropic.com, pennies with a spend cap). Keep names and sensitive details out of task titles.
- Self-test: open the file with `?selftest` appended to the URL (82 assertions).
- Voice: tap the 🎤 next to the task box to speak a task (browser speech API, nothing external).
- Build it yourself: the full design spec and the step-by-step implementation plan (complete code per task) are in `docs/superpowers/` - an agent or a patient human can rebuild or extend the game from them.

## Make it yours

**First launch walks you through this** - a skippable 3-step in-game setup asks for your (optional) API key and work context. Everything personal lives in YOUR browser (localStorage) - never in this repo:

1. **Settings** (Progress tab, gear at the bottom): pick your AI provider (Gemini free tier or Claude) and paste your own key for AI pars and trash talk. Optional - the local estimator works fine without it.
2. **My work context**: write one paragraph about your typical micro-tasks in Settings. The AI uses it to estimate like it knows your job.
3. **Categories**: rename them, edit keywords (add your ticket prefix, e.g. "abc-"), adjust baseline times, add or archive - all in Settings.
4. **Play**: after a few finishes per category, pars come from your own history, not the defaults.

To extend the game itself: clone the repo, open the folder in Claude Code, and point it at the spec and plan in `docs/superpowers/` - they carry the full design context an agent needs.
- Spec: `docs/superpowers/specs/2026-07-16-product-madness-design.md` · Plan: `docs/superpowers/plans/2026-07-16-product-madness-v1.md`
