# Product Madness - Design Spec

Date: 2026-07-16
Status: Approved design, pending user review of this document
Owner: ntangs (single player, personal tool)

## 1. What this is

Product Madness is a personal arcade game, inspired by Cooking Madness, that makes small work tasks (roughly 1 to 5 minutes each) fun to finish. You log a micro-task, lock in your own time estimate, then race a countdown set by an AI estimate of the same task. Finishing under the AI's par earns stars, combos, XP, and levels. Your estimate competes against the AI's in a running "showdown" rivalry. Daily quests give each workday a shape.

It is a single standalone HTML file that runs in a chromeless browser app window beside your real work. No install, no server, no accounts. All data stays in the browser's localStorage.

Not goals: this is not a time tracker for reporting, not a Jira integration, not multi-user, and it never nags. If a mechanic ever pressures you to rush real work quality, the mechanic is wrong, not you.

## 2. Decision ledger (from brainstorm, 2026-07-16)

| Decision | Choice |
|---|---|
| AI estimator | Hybrid: local estimator always on, Claude API optional refinement |
| Scoring philosophy | Beat the clock (arcade), racing the AI's par - not your own estimate |
| Your estimate | Side-bet "showdown": locked in before the AI par is revealed; closer-to-actual wins the round |
| App shape | Two scenes (Kitchen = play, Progress = stats) + persistent HUD |
| Form factor | Single-file HTML in an Edge app-mode window, localStorage persistence |
| Aesthetic | "Strawberries & Cream" pastel: pink spectrum + cream only. No blue, no purple, no mint, no other hues. ARC design-token rule explicitly waived for this personal app (user decision 2026-07-16) |
| Name | Product Madness |
| Task entry | Manual only, quick-log box; tasks can queue on an "order rail" while one is running |

Design mockups from the brainstorm live in `design-mockups/` (app-shape comparison, palette iterations; `visual-style-v3.html` is the locked look).

## 3. Game rules

### 3.1 Core loop

1. Log a task: one text box, Enter. A category chip is auto-suggested from keywords; tap to change it. If a task is already running, the new task becomes a ticket on the order rail.
2. Lock your call: pick your estimate from quick chips (1 / 2 / 3 / 4 / 5 min) or a fine slider (0:30 to 10:00, 15 s steps). Your call is locked BEFORE the AI par is revealed, so it cannot anchor on the AI's number.
3. Par reveal: the AI's estimate appears (with a quip when the API layer is on) and becomes the par time.
4. Start: countdown runs from par. Center of the Kitchen scene: task title, big timer, par progress bar, your-call chip.
5. Finish with DONE, or Pause (freely), or Drop.

### 3.2 Stars

Let `t = actualSec / parSec` (actual excludes paused time):

| Result | Stars |
|---|---|
| t <= 0.75 | 3 stars |
| 0.75 < t <= 0.95 | 2 stars |
| 0.95 < t <= 1.00 | 1 star |
| t > 1.00 (overtime) | 0 stars |

Overtime behavior: at 0:00 the timer flips to counting up in overtime styling. The task can still be finished; it earns base XP, records history (this data improves future pars), but 0 stars and the combo breaks.

### 3.3 Showdown (you vs the AI)

On every finished task: if `abs(myCallSec - actualSec) <= abs(parSec - actualSec)` the round is yours (ties go to you), otherwise the AI takes it. Wins tally on a weekly scoreboard (weeks start Monday) shown in the Progress scene: "YOU 12 - 8 AI". The scoreboard covers the current week only and resets on the first open of a new week; prior weeks are not retained. A showdown win adds bonus XP.

### 3.4 Combo

Consecutive finishes at 1 star or better, same local day, build a combo. XP multiplier by combo count: 1 task x1.0, 2 x1.1, 3 x1.25, 4 x1.5, 5+ x2.0 (cap). A 0-star finish or a Drop breaks the combo. Pause does not. Combo resets at midnight.

### 3.5 XP and levels

`xp = floor((10 + 5 * stars + 8 * showdownWin) * comboMultiplier)` per finished task, plus quest rewards.

Cumulative XP to reach level n (level 1 starts at 0): `100 * (n - 1) ^ 1.5`, rounded to the nearest 10. So L2 = 100, L3 = 280, L4 = 520, L5 = 800, L6 = 1120, L7 = 1470, L8 = 1850, L9 = 2260, L10 = 2700, and onward by the same formula.

Titles (kitchen brigade homage): 1 Dishwasher, 2 Prep Cook, 3 Line Cook, 4 Station Chef, 5 Sous Chef, 6 Head Chef, 7 Executive Chef, 8 Michelin One-Star, 9 Michelin Two-Star, 10 Michelin Three-Star, 11+ Legend of the Pass (with roman numerals: Legend of the Pass II, III, ...).

Level-up moment: confetti burst + jingle + title card.

### 3.6 Daily quests

3 quests per day, drawn deterministically from the template pool using a PRNG seeded by the date (same date always yields the same 3, so reloads cannot reroll). Reset at local midnight; regenerated on first open of a new day. Progress shows in the Progress scene; compact pips in the HUD. Rewards are claimed automatically on completion (toast + XP).

Template pool (v1):

| # | Quest | Target | Reward XP |
|---|---|---|---|
| 1 | Clear N tasks | 5 | 40 |
| 2 | Earn N stars | 6 | 40 |
| 3 | Beat the AI in N showdowns | 2 | 45 |
| 4 | Reach a N-combo | 3 | 45 |
| 5 | Score a 3-star finish before noon | 1 | 50 |
| 6 | Finish tasks in N different categories | 3 | 40 |
| 7 | Clear 3 order-rail tickets without a drop | 3 | 45 |
| 8 | 5 starred finishes in a row | 5 | 60 |

### 3.7 Pause, drop, and edge cases

- Pause: unlimited and guilt-free (real work has interruptions). Paused time is excluded from `actualSec`. Visual paused state on the timer.
- Drop: discards the running task. No XP, no history sample, combo breaks. Queued tickets can be deleted from the rail without penalty.
- Midnight rollover while a task runs: the task counts toward the day it was FINISHED (quests and combo evaluate at finish time).
- A task left running or paused when the window closes is restored on next open (timestamps make elapsed time truthful); if it was running while closed, that wall-clock time counts as elapsed. The restore banner offers "keep racing" or "drop it".

### 3.8 Order rail

Tickets (queued tasks) render as small cards under the quick-log, max 6 visible, scroll beyond. Each shows title + category chip + a tap-to-start button; any ticket can start next (player picks order). Rail persists across sessions.

## 4. Estimator

### 4.1 Local layer (always on)

- Category detection: lowercase the title; a category matches if any of its keywords (which may be multi-word phrases) appears as a substring of the title; first matching category in library order wins; no match lands in "Other". The suggested chip is always shown and correctable before Start.
- Par calculation for the detected category:
  - 5+ samples: median of the last 5 `actualSec`
  - 3 or 4 samples: median of what exists
  - 1 or 2 samples: `(mean(samples) * count + baselineSec * (3 - count)) / 3`
  - 0 samples: `baselineSec`
- Rounded to the nearest 5 s and clamped to [30 s, 1200 s].
- Samples are appended on every finished task (including overtime finishes; not drops). Categories keep the last 20 samples.

### 4.2 Seed category library

Baked into the file, all editable in-app (rename, re-keyword, adjust baseline, add, archive):

| Category | Keywords (v1) | Baseline |
|---|---|---|
| Email reply | email, reply, respond, inbox | 3:00 |
| Teams/chat reply | teams, chat, slack, message, ping | 1:30 |
| Jira comment | jira comment, comment | 2:30 |
| Jira ticket draft | ticket, story, jira, draft ticket | 5:00 |
| Backlog grooming pass | groom, backlog, triage | 5:00 |
| Wireframe micro-edit | wireframe, mockup, html edit | 4:00 |
| Doc review skim | review, skim, read, doc | 4:00 |
| Meeting notes cleanup | notes, recap, minutes | 4:00 |
| Agenda prep | agenda, prep, 1:1 | 5:00 |
| Status update draft | status, update, standup | 3:00 |
| Calendar wrangling | calendar, schedule, invite, meeting time | 2:00 |
| File cleanup | file, rename, organize, folder | 2:00 |
| Quick data check | check, verify, lookup, data | 3:00 |
| Follow-up nudge | follow up, nudge, remind | 1:30 |
| Other | (fallback) | 3:00 |

### 4.3 Claude API layer (optional)

- Settings drawer: paste Anthropic API key (stored only in localStorage), enable toggle, model picker (default `claude-haiku-4-5`; alternate `claude-sonnet-5`).
- Request: `POST https://api.anthropic.com/v1/messages` with headers `x-api-key`, `anthropic-version: 2023-06-01`, `content-type: application/json`, `anthropic-dangerous-direct-browser-access: true`. `max_tokens: 150`.
- System prompt contains: a one-paragraph profile of the player's role and typical work (user-editable in Settings as "My work context"; ships with a generic knowledge-work default), the detected category's stats (baseline, sample count, median), the last 10 finished tasks in that category as `title - actual m:ss` lines, and strict output instructions.
- Expected response: a single JSON object `{"seconds": <int>, "quip": "<string, max 90 chars>"}`. Parse the first JSON object found; validate seconds as an integer in [30, 1200]; on any parse or validation failure, fall back to local silently.
- Timeout 3.5 s, no retry (the game must feel instant); on timeout or error, local par is used.
- The par chip always shows its source badge: a small "local" or "Claude" tag. Quips display at par reveal and on finish (win or lose flavor).
- Identical-title requests within the same day reuse the cached API answer instead of re-calling.

### 4.4 Privacy

Task titles and the work-context paragraph leave the machine only when the API toggle is on, and only to Anthropic's API. Standing rule: keep names and sensitive details out of both. Settings shows this reminder next to the toggle. The API key never appears in exports (export strips `settings.apiKey`).

## 5. Architecture

### 5.1 Form

- One standalone file: `Product Madness v1.html` at `C:\Users\ntangs\Documents\Product-Madness\`. No CDN, no external assets, no network calls except the optional Anthropic API. Icons are inline SVG and emoji. Sounds are WebAudio-synthesized (tick on final 5 s, finish ding, star chimes, level-up jingle, soft womp on overtime), mutable in Settings.
- Future changes ship as new versioned files (`Product Madness v2.html`); never overwrite a working version.
- Launcher: `Product Madness.bat` in the same folder runs Edge app mode, e.g. `start msedge --app="file:///C:/Users/ntangs/Documents/Product-Madness/Product%20Madness%20v1.html" --window-size=430,720`. Pin the resulting window to the taskbar. Plain browser open works too.

### 5.2 Code layout (inside the single file)

Vanilla JS, no framework. Ordered sections, each a small module object: `Store` (state + persistence + export/import), `Rules` (stars, combo, XP, levels - pure functions), `Estimator` (category match + local par - pure functions), `ApiClient` (Claude call + cache + fallback), `Quests` (seeded generation + progress - pure generation), `UI` (HUD, Kitchen scene, Progress scene, Settings drawer, order rail), `Audio` (synth), `Fx` (confetti canvas), `SelfTest`.

### 5.3 Data model (localStorage key `product-madness.v1`, single JSON doc)

```json
{
  "version": 1,
  "player": { "xp": 0, "level": 1, "starsTotal": 0, "bestCombo": 0,
              "showdown": { "weekOf": "2026-07-13", "you": 0, "ai": 0 } },
  "tasks": [ { "id": "t_...", "title": "", "category": "email-reply",
               "state": "queued | running | paused | done | dropped",
               "createdAt": 0, "startedAt": 0, "pausedMs": 0, "finishedAt": 0,
               "parSec": 0, "parSource": "local | api",
               "myCallSec": 0, "actualSec": 0,
               "stars": 0, "showdownWin": false, "xp": 0, "comboAt": 1, "quip": "" } ],
  "categories": { "email-reply": { "label": "Email reply", "emoji": "✉",
                  "keywords": ["email", "reply"], "baselineSec": 180,
                  "samples": [/* last 20 actualSec */], "archived": false } },
  "quests": { "date": "2026-07-16",
              "items": [ { "templateId": 1, "label": "", "target": 5,
                           "progress": 0, "done": false, "rewardXp": 40 } ] },
  "settings": { "apiKey": "", "apiEnabled": false, "model": "claude-haiku-4-5",
                "sound": true, "lastExportAt": null }
}
```

Write-through: every state change persists immediately. History view derives from `tasks` (grouped by day); category records (median, best, count) derive from `samples` and `tasks`.

### 5.4 Timekeeping

All timing derives from timestamps (`startedAt`, `pausedMs`, now), never from interval tick counting, so browser throttling of a backgrounded window cannot drift the clock. `requestAnimationFrame` drives the visible countdown; `visibilitychange` forces recompute on return. HUD shows real time-of-day.

### 5.5 Error handling

- API failure or malformed response: silent fallback to local par, source badge says "local"; no error modal ever blocks play. A subtle toast appears only if the toggle is on and 3 consecutive calls have failed ("Claude is napping - local pars for now").
- localStorage quota exceeded or corrupt JSON on load: non-blocking banner offering Export (of whatever is recoverable) and Reset. Never silently wipe.
- Import validates `version` and shape before replacing state; a bad file changes nothing.

### 5.6 Visual system

Strawberries & Cream palette (locked in `design-mockups/visual-style-v3.html`):

| Token | Value | Use |
|---|---|---|
| cream page | #FBF3E7 | window background |
| cream surface | #FFFBF4 | cards, phone body |
| pink border | #F2C9D6 | card and input borders |
| blush HUD | #FFDCE8 to #FFC9DB | HUD, scoreboard chip |
| HUD text | #8A4E68 | text on blush |
| body text | #7E5865 | primary text |
| rose fill | #F49FBC to #F2708F | level bar, par bar, quest bars |
| strawberry | #E9678C | countdown timer |
| deep rose action | #F2708F to #E85C82, shadow #C94E71 | DONE button, active tab (#F48FB1 to #EC6F9C) |
| blush minor | #F9DCE6 | pause/drop buttons |
| cream track | #F9E4D4 | bar tracks |
| cream chip | #FFF4E4, dashed #F4AFC8 | your-call chip |
| mauve text | #A2547A | quip, your-call chip, drawer note text |
| tabs track | #F9E9DC | tab bar background |

Type: "Segoe UI", system-ui stack; heavy weights (800/900) for game chrome; big rounded radii (10 to 20 px); chunky soft shadows. Overtime state uses the deepest rose, not a new hue. No colors outside the pink spectrum + cream.

### 5.7 Testing

- Built-in self-test: opening the file with `?selftest` runs assertions over the pure logic - star thresholds at boundaries (0.75, 0.95, 1.0), combo sequences and breaks, XP formula, level thresholds, estimator blending at 0/1/2/3/5+ samples, clamping, quest determinism per date, showdown tie-to-player - and renders an in-page pass/fail list.
- Manual acceptance checklist (run before calling v1 done):
  1. Log, call, par reveal, start, DONE full loop
  2. Star boundaries behave per 3.2 (test with short pars)
  3. Overtime finish: 0 stars, history recorded, combo broken
  4. Pause excludes time; accurate after minimizing the window 2+ min
  5. Drop discards with no history sample
  6. Order rail: queue 3 while one runs, start them in any order
  7. Showdown tally updates, tie goes to player, weekly reset Monday
  8. Level-up fires confetti + new title at exact threshold
  9. Quests progress, auto-claim, same 3 reappear on reload, new 3 next day
  10. API on: Claude par + quip + badge; API key wrong: silent local fallback
  11. Export then Reset then Import restores everything (and export contains no API key)
  12. `?selftest` fully green
  13. .bat opens the app window at game proportions
  14. Close mid-task, reopen: restore banner, elapsed time truthful

## 6. Out of scope for v1 (parking lot)

End-of-day "shift complete" ceremony and week map (option C from brainstorm), coins/shop/upgrade meta, day-streak mechanics, notifications or reminders, Jira/calendar import, multi-device sync, theming beyond Strawberries & Cream, pause limits or anti-cheat (single player, honor system).

## 7. Build order (input to the implementation plan)

1. Skeleton + palette + HUD + Kitchen scene static
2. Rules engine + Store (pure functions first, self-test alongside)
3. Core loop playable with local estimator
4. Order rail + Progress scene (quests, scoreboard, records, history)
5. Quests engine + level-ups + audio + confetti
6. API layer + Settings drawer + export/import
7. Launcher .bat + acceptance checklist pass
