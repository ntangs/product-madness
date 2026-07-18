# Product Madness v1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `Product Madness v1.html` - a standalone single-file HTML arcade game where the player races an AI par time on real micro-tasks, per the spec at `docs/superpowers/specs/2026-07-16-product-madness-design.md`.

**Architecture:** One HTML file containing ordered `<script>` module objects (Utils, Rules, Estimator, Quests, Store, ApiClient, Sfx, Fx, UI, SelfTest). All game logic is pure functions tested by a built-in `?selftest` page; UI is vanilla DOM. Persistence is one localStorage JSON doc. The only network call is the optional Anthropic API.

**Tech Stack:** Vanilla HTML/CSS/JS, WebAudio, canvas confetti, localStorage. No frameworks, no build step, no external assets. Tests run headlessly via Edge/Chrome `--dump-dom`.

## Global Constraints

- Repo root: `C:\Users\ntangs\Documents\Product-Madness\`. The game file is `Product Madness v1.html` at repo root (name has a space - always quote paths; in file URLs write it as `Product%20Madness%20v1.html`).
- Single standalone file: no CDN, no external fonts/images/scripts. Icons = emoji/inline SVG. Only network call: `https://api.anthropic.com/v1/messages`, and only when the user enables it.
- Colors: every color literal must be (or equal in value) a `:root` Strawberries & Cream token, `#fff`, `transparent`, or an alpha (rgba) variant of a token color. No blue, no purple, no green, no red hues outside the pink spectrum. CSS uses `var()` for token colors; JS-drawn graphics (confetti) may use token hex values as literals.
- UI copy uses plain hyphens. Never em-dashes or en-dashes anywhere, including code comments and commit messages.
- Vanilla JS only. No dependencies, no TypeScript, no modules/imports - plain `<script>` with `const` namespace objects.
- localStorage key: `product-madness.v1`. Schema per spec 5.3.
- All timing derives from timestamps (`Date.now()`), never from tick counting.
- Numbers are law: star thresholds, combo multipliers, XP formula, level curve, quest pool, estimator blend, clamps, and API contract are exactly as written in spec sections 3 and 4.
- The selftest verify command (referenced in steps as "run selftest"):
  ```bash
  EDGE="/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"; [ -f "$EDGE" ] || EDGE="/c/Program Files/Microsoft/Edge/Application/msedge.exe"; "$EDGE" --headless=new --disable-gpu --virtual-time-budget=2000 --dump-dom "file:///C:/Users/ntangs/Documents/Product-Madness/Product%20Madness%20v1.html?selftest" | grep -o "SELFTEST: [0-9]* passed, [0-9]* failed"
  ```
  Expected output format: `SELFTEST: N passed, 0 failed`. Any nonzero fail count = stop and fix before proceeding.
- End every commit message with: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`
- Never overwrite a shipped version. During this plan we are building v1, so edits to `Product Madness v1.html` are expected; after v1 is accepted, future work goes to `Product Madness v2.html`.

---

### Task 1: File skeleton, palette CSS, static shell, SelfTest harness

**Files:**
- Create: `Product Madness v1.html`

**Interfaces:**
- Produces: the full DOM shell (all element ids used by later tasks), CSS classes, `U` (Utils), `SelfTest` with `SelfTest.suite(fn)`, `SelfTest.render()`, `SelfTest.eq(name, got, want)`, `SelfTest.ok(name, cond)`, and the boot switch (`?selftest` renders tests; otherwise calls `UI.boot()` if defined).
- Consumes: nothing.

- [ ] **Step 1: Create the file with head, complete CSS, and body shell**

Create `Product Madness v1.html` with exactly this content:

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Product Madness</title>
<style>
  :root {
    --cream-page:#FBF3E7; --cream-surface:#FFFBF4; --pink-border:#F2C9D6;
    --blush-1:#FFDCE8; --blush-2:#FFC9DB; --hud-text:#8A4E68; --body-text:#7E5865;
    --rose-1:#F49FBC; --rose-2:#F2708F; --strawberry:#E9678C;
    --action-1:#F2708F; --action-2:#E85C82; --action-shadow:#C94E71;
    --tab-1:#F48FB1; --tab-2:#EC6F9C;
    --blush-minor:#F9DCE6; --cream-track:#F9E4D4; --cream-chip:#FFF4E4; --chip-border:#F4AFC8;
  }
  * { box-sizing:border-box; margin:0; padding:0; }
  html,body { height:100%; }
  body { background:var(--cream-page); color:var(--body-text);
         font-family:"Segoe UI",system-ui,sans-serif; font-size:14px; overflow:hidden; }
  #app { display:flex; flex-direction:column; height:100%; max-width:520px; margin:0 auto; padding:10px 10px 8px; }

  /* HUD */
  #hud { display:flex; align-items:center; justify-content:space-between; gap:8px;
         background:linear-gradient(180deg,var(--blush-1),var(--blush-2)); color:var(--hud-text);
         border-radius:14px; padding:8px 12px; font-weight:800; flex:0 0 auto; }
  #hud-clock { font-variant-numeric:tabular-nums; }
  #hud-level { display:flex; align-items:center; gap:6px; min-width:0; }
  #hud-title { font-size:11px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; max-width:90px; }
  #hud-xpbar { background:rgba(255,255,255,.85); border-radius:999px; height:8px; width:52px; overflow:hidden; }
  #hud-xpbar i { display:block; height:100%; width:0%; background:linear-gradient(90deg,var(--rose-1),var(--rose-2)); transition:width .3s; }
  #hud-quests { display:flex; gap:4px; }
  #hud-quests .pip { width:10px; height:10px; border-radius:50%; background:rgba(255,255,255,.85); display:inline-block; }
  #hud-quests .pip.done { background:var(--rose-2); }

  /* Scenes */
  main { flex:1 1 auto; min-height:0; display:flex; flex-direction:column; }
  .scene { display:none; flex:1; flex-direction:column; min-height:0; padding-top:10px; }
  .scene.on { display:flex; }

  /* Kitchen stage */
  #stage { flex:0 0 auto; background:var(--cream-surface); border:2px solid var(--pink-border);
           border-radius:18px; padding:16px 14px; min-height:280px; display:flex; align-items:stretch; }
  .stage-card { display:none; flex:1; flex-direction:column; align-items:center; justify-content:center; gap:10px; text-align:center; }
  .stage-card.on { display:flex; }
  .stage-emoji { font-size:44px; }
  .stage-card h2 { color:var(--hud-text); font-size:18px; font-weight:800; max-width:100%; overflow-wrap:anywhere; }
  .lbl { font-size:11px; font-weight:700; text-transform:uppercase; letter-spacing:.06em; opacity:.65; }
  #timer-display { font-size:56px; font-weight:900; color:var(--strawberry); font-variant-numeric:tabular-nums; line-height:1; }
  #timer-display.overtime { color:var(--action-shadow); animation:pulse 1s infinite; }
  #timer-display.paused { opacity:.45; }
  @keyframes pulse { 50% { opacity:.6; } }
  #par-bar { background:var(--cream-track); border-radius:999px; height:12px; width:85%; overflow:hidden; }
  #par-bar i { display:block; height:100%; width:0%; background:linear-gradient(90deg,var(--rose-1),var(--rose-2)); }
  #run-parline { display:flex; gap:14px; font-size:12px; font-weight:700; }
  .quip { font-size:12.5px; font-style:italic; background:var(--cream-chip); border:1.5px dashed var(--chip-border);
          border-radius:10px; padding:6px 10px; max-width:95%; color:#A2547A; }
  .quip:empty { display:none; }
  .par-reveal { display:flex; align-items:baseline; gap:8px; font-weight:900; font-size:26px; color:var(--strawberry); }
  .par-reveal .lbl { font-size:11px; }
  .badge { font-size:9px; font-weight:800; text-transform:uppercase; letter-spacing:.05em;
           background:var(--blush-minor); color:var(--hud-text); border-radius:999px; padding:2px 8px; align-self:center; }
  .mycall { background:var(--cream-chip); border:1.5px dashed var(--chip-border); border-radius:10px;
            padding:4px 12px; font-weight:800; color:#A2547A; }

  /* Buttons */
  button { font-family:inherit; border:none; cursor:pointer; font-weight:800; color:var(--hud-text); }
  .btn-primary { background:linear-gradient(180deg,var(--action-1),var(--action-2)); color:#fff;
                 border-radius:14px; padding:10px 26px; font-size:16px; box-shadow:0 3px 0 var(--action-shadow); }
  .btn-primary:active { transform:translateY(2px); box-shadow:0 1px 0 var(--action-shadow); }
  .btn-primary.big { font-size:20px; padding:12px 42px; }
  .btn-minor { background:var(--blush-minor); border-radius:10px; padding:7px 16px; font-size:12px; }
  .btn-ghost { background:transparent; font-size:12px; opacity:.7; text-decoration:underline; }
  .row2 { display:flex; gap:8px; }

  /* Call picker */
  #call-chips { display:flex; gap:6px; flex-wrap:wrap; justify-content:center; }
  #call-chips button { background:var(--blush-minor); border-radius:999px; padding:8px 14px; font-size:14px; }
  #call-chips button.on { background:linear-gradient(180deg,var(--tab-1),var(--tab-2)); color:#fff; }
  #call-slider { width:85%; accent-color:var(--rose-2); }
  #call-value { font-size:22px; font-weight:900; color:var(--strawberry); font-variant-numeric:tabular-nums; }

  /* Quick log + rail */
  #quicklog-wrap { display:flex; align-items:center; gap:8px; margin-top:10px; flex:0 0 auto; }
  #quick-log { flex:1; background:#fff; border:2px solid var(--pink-border); border-radius:12px;
               padding:9px 12px; font-family:inherit; font-size:14px; color:var(--body-text); outline:none; }
  #quick-log:focus { border-color:var(--rose-1); }
  .chip { background:var(--blush-minor); color:var(--hud-text); border-radius:999px; padding:4px 10px;
          font-size:11px; font-weight:800; white-space:nowrap; cursor:pointer; }
  #order-rail { display:flex; gap:8px; overflow-x:auto; padding:10px 2px 4px; min-height:64px; flex:0 0 auto; }
  .ticket { background:var(--cream-surface); border:2px solid var(--pink-border); border-radius:12px;
            padding:6px 10px; min-width:130px; max-width:170px; flex:0 0 auto; font-size:12px; }
  .ticket .t-title { font-weight:800; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
  .ticket .t-row { display:flex; justify-content:space-between; align-items:center; margin-top:5px; gap:6px; }
  .ticket .t-start { background:linear-gradient(180deg,var(--action-1),var(--action-2)); color:#fff;
                     border-radius:8px; padding:3px 10px; font-size:11px; }
  .ticket .t-del { opacity:.5; font-size:11px; background:none; }

  /* Progress scene */
  #scene-progress { overflow-y:auto; gap:8px; }
  #scene-progress h3 { font-size:11px; font-weight:800; text-transform:uppercase; letter-spacing:.08em;
                       opacity:.6; margin:10px 2px 4px; }
  .prow { display:flex; justify-content:space-between; align-items:center; background:var(--cream-surface);
          border:1.5px solid var(--pink-border); border-radius:10px; padding:7px 10px; font-size:13px; margin-bottom:5px; }
  .qbar { background:var(--cream-track); border-radius:999px; height:6px; margin:-1px 2px 7px; overflow:hidden; }
  .qbar i { display:block; height:100%; background:var(--rose-2); }
  #scoreboard { text-align:center; background:linear-gradient(180deg,var(--blush-1),var(--blush-2));
                color:var(--hud-text); border-radius:12px; padding:10px; font-weight:900; font-size:18px; }
  .hday { font-size:11px; font-weight:800; opacity:.55; margin:8px 2px 3px; }

  /* Tabs */
  #tabs { display:flex; background:#F9E9DC; border-radius:14px; overflow:hidden; margin-top:10px; flex:0 0 auto; }
  #tabs button { flex:1; padding:11px 0; font-size:14px; background:transparent; }
  #tabs button.on { background:linear-gradient(180deg,var(--tab-1),var(--tab-2)); color:#fff; }

  /* Toasts, banner, level-up, drawer */
  #toasts { position:fixed; bottom:74px; left:50%; transform:translateX(-50%); display:flex;
            flex-direction:column; gap:6px; align-items:center; z-index:40; pointer-events:none; }
  .toast { background:var(--cream-surface); border:2px solid var(--pink-border); color:var(--body-text);
           border-radius:999px; padding:7px 16px; font-weight:800; font-size:13px;
           box-shadow:0 4px 12px rgba(200,130,150,.25); animation:toastin .2s; }
  @keyframes toastin { from { transform:translateY(8px); opacity:0; } }
  #levelup { position:fixed; inset:0; background:rgba(126,88,101,.45); display:flex;
             align-items:center; justify-content:center; z-index:50; }
  #levelup .card { background:var(--cream-surface); border:3px solid var(--pink-border); border-radius:20px;
                   padding:26px 30px; text-align:center; display:flex; flex-direction:column; gap:10px; align-items:center; }
  #levelup h2 { color:var(--strawberry); font-size:24px; }
  #banner { position:fixed; top:0; left:0; right:0; background:linear-gradient(180deg,var(--blush-1),var(--blush-2));
            color:var(--hud-text); padding:10px 14px; z-index:45; display:flex; gap:10px; align-items:center;
            justify-content:center; flex-wrap:wrap; font-weight:700; font-size:13px; }
  #settings-drawer { position:fixed; top:0; right:0; bottom:0; width:320px; max-width:92vw;
                     background:var(--cream-surface); border-left:3px solid var(--pink-border); z-index:60;
                     padding:18px; overflow-y:auto; display:flex; flex-direction:column; gap:12px; }
  #settings-drawer label { font-size:12px; font-weight:800; display:flex; flex-direction:column; gap:4px; }
  #settings-drawer input[type=text], #settings-drawer input[type=password], #settings-drawer select {
    background:#fff; border:2px solid var(--pink-border); border-radius:8px; padding:7px 9px;
    font-family:inherit; color:var(--body-text); }
  .drawer-note { font-size:11px; background:var(--cream-chip); border:1.5px dashed var(--chip-border);
                 border-radius:8px; padding:7px 9px; color:#A2547A; }
  .switchrow { display:flex; align-items:center; justify-content:space-between; font-size:13px; font-weight:800; }
  #fx { position:fixed; inset:0; pointer-events:none; z-index:70; }
  [hidden] { display:none !important; }

  /* Selftest page */
  #selftest { padding:20px; font-family:Consolas,monospace; background:#fff; color:#333;
              position:fixed; inset:0; overflow:auto; z-index:100; }
  #selftest h1 { font-size:16px; margin-bottom:10px; }
  #selftest li.pass { color:#7E5865; }
  #selftest li.fail { color:#C94E71; font-weight:bold; }
</style>
</head>
<body>
<div id="app">
  <header id="hud">
    <div id="hud-clock">--:--</div>
    <div id="hud-level"><span id="hud-title">Dishwasher</span><span id="hud-lv">Lv 1</span>
      <span id="hud-xpbar"><i id="hud-xpfill"></i></span></div>
    <div id="hud-stars">★ 0</div>
    <div id="hud-quests"><i class="pip"></i><i class="pip"></i><i class="pip"></i></div>
  </header>
  <main>
    <section id="scene-kitchen" class="scene on">
      <div id="stage">
        <div id="stage-idle" class="stage-card on">
          <div class="stage-emoji">🍓</div>
          <h2>Order up?</h2>
          <p class="lbl">log a task below to start the rush</p>
        </div>
        <div id="stage-call" class="stage-card">
          <h2 id="call-title"></h2>
          <p class="lbl">lock your call - how long will this take you?</p>
          <div id="call-chips"></div>
          <input id="call-slider" type="range" min="30" max="600" step="15" value="180">
          <div id="call-value">3:00</div>
          <button id="btn-lock" class="btn-primary">Lock my call</button>
          <button id="btn-cancel-call" class="btn-ghost">send to rail instead</button>
        </div>
        <div id="stage-ready" class="stage-card">
          <h2 id="ready-title"></h2>
          <div id="ready-quip" class="quip"></div>
          <div class="par-reveal"><span class="lbl">AI par</span><span id="ready-par">-:--</span><span id="ready-par-src" class="badge">local</span></div>
          <div class="mycall">🥊 my call: <span id="ready-call">-:--</span></div>
          <button id="btn-start" class="btn-primary big">▶ Start</button>
        </div>
        <div id="stage-run" class="stage-card">
          <h2 id="run-title"></h2>
          <div id="timer-display">0:00</div>
          <div id="par-bar"><i id="par-fill"></i></div>
          <div id="run-parline"><span id="run-par"></span><span id="run-call"></span></div>
          <button id="btn-done" class="btn-primary big">✔ DONE</button>
          <div class="row2">
            <button id="btn-pause" class="btn-minor">⏸ pause</button>
            <button id="btn-drop" class="btn-minor">✕ drop</button>
          </div>
        </div>
      </div>
      <div id="quicklog-wrap">
        <input id="quick-log" placeholder="+ log a task and press Enter" maxlength="80">
        <span id="quick-cat" class="chip" hidden></span>
      </div>
      <div id="order-rail"></div>
    </section>
    <section id="scene-progress" class="scene">
      <h3>Daily quests</h3><div id="quest-list"></div>
      <h3>You vs AI - this week</h3><div id="scoreboard"></div>
      <h3>Your records</h3><div id="records"></div>
      <h3>History</h3><div id="history"></div>
      <button id="settings-open" class="btn-ghost">⚙ settings</button>
    </section>
  </main>
  <nav id="tabs">
    <button id="tab-kitchen" class="on">🍳 Kitchen</button>
    <button id="tab-progress">📈 Progress</button>
  </nav>
  <div id="toasts"></div>
  <div id="levelup" hidden><div class="card"><div class="stage-emoji">🎉</div><h2 id="levelup-title"></h2><p id="levelup-sub"></p><button id="levelup-ok" class="btn-primary">Back to the pass</button></div></div>
  <div id="banner" hidden><p id="banner-msg"></p><span id="banner-actions"></span></div>
  <aside id="settings-drawer" hidden>
    <h3 style="color:var(--hud-text)">Settings</h3>
    <div class="switchrow"><span>Sound</span><input id="set-sound" type="checkbox" checked></div>
    <div class="switchrow"><span>Claude API estimates</span><input id="set-api-enabled" type="checkbox"></div>
    <label>Anthropic API key<input id="set-api-key" type="password" placeholder="sk-ant-..."></label>
    <label>Model<select id="set-model">
      <option value="claude-haiku-4-5">claude-haiku-4-5 (fast, cheap)</option>
      <option value="claude-sonnet-5">claude-sonnet-5 (sharper)</option>
    </select></label>
    <p class="drawer-note">Privacy: when the API is on, task titles are sent to Anthropic to estimate par. Keep member names and PHI out of task titles. The key stays in this browser only and is never included in exports.</p>
    <button id="btn-export" class="btn-minor">⬇ Export data (JSON)</button>
    <label class="btn-minor" style="text-align:center">⬆ Import data<input id="file-import" type="file" accept=".json" hidden></label>
    <button id="btn-reset" class="btn-minor">Reset everything</button>
    <h3 style="color:var(--hud-text)">Categories</h3>
    <div id="cat-editor"></div>
    <button id="settings-close" class="btn-ghost">close</button>
  </aside>
  <canvas id="fx"></canvas>
</div>
<script>
// ===== Utils =====
const U = {
  pad2: n => String(n).padStart(2, '0'),
  mmss(sec) { sec = Math.max(0, Math.round(sec)); return `${Math.floor(sec / 60)}:${U.pad2(sec % 60)}`; },
  round5: s => Math.round(s / 5) * 5,
  clamp: (v, lo, hi) => Math.min(hi, Math.max(lo, v)),
  median(a) { const s = [...a].sort((x, y) => x - y); const m = s.length >> 1; return s.length ? (s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2) : 0; },
  uid: () => 't_' + Date.now().toString(36) + Math.random().toString(36).slice(2, 7),
  esc(s) { return String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])); },
};

// ===== Rules =====

// ===== Estimator =====

// ===== Quests =====

// ===== Store =====

// ===== ApiClient =====

// ===== Sfx =====

// ===== Fx =====

// ===== UI =====

// ===== SelfTest =====
const SelfTest = {
  results: [], suites: [],
  suite(fn) { SelfTest.suites.push(fn); },
  eq(name, got, want) { const pass = JSON.stringify(got) === JSON.stringify(want); SelfTest.results.push({ name, pass, got, want }); },
  ok(name, cond) { SelfTest.results.push({ name, pass: !!cond, got: cond, want: true }); },
  async render() {
    SelfTest.results = [];
    for (const fn of SelfTest.suites) {
      try { await fn(); }
      catch (e) { SelfTest.results.push({ name: 'suite threw: ' + e.message, pass: false, got: String(e), want: 'no throw' }); }
    }
    const fails = SelfTest.results.filter(r => !r.pass);
    document.body.innerHTML = `<div id="selftest"><h1>SELFTEST: ${SelfTest.results.length - fails.length} passed, ${fails.length} failed</h1><ol>` +
      SelfTest.results.map(r => `<li class="${r.pass ? 'pass' : 'fail'}">${U.esc(r.name)}${r.pass ? '' : ` - got ${U.esc(JSON.stringify(r.got))}, want ${U.esc(JSON.stringify(r.want))}`}</li>`).join('') + '</ol></div>';
  },
};

SelfTest.suite(() => {
  SelfTest.eq('utils: mmss formats 150s', U.mmss(150), '2:30');
  SelfTest.eq('utils: median even count', U.median([10, 20, 30, 40]), 25);
  SelfTest.eq('utils: round5', U.round5(133), 135);
  SelfTest.eq('utils: clamp', U.clamp(9999, 30, 1200), 1200);
});

// ===== Boot =====
(async () => {
  if (location.search.includes('selftest')) { await SelfTest.render(); }
  else if (typeof UI !== 'undefined') { UI.boot(); }
})();
</script>
</body>
</html>
```

- [ ] **Step 2: Run selftest to verify the harness works**

Run the selftest command from Global Constraints.
Expected: `SELFTEST: 4 passed, 0 failed`

- [ ] **Step 3: Smoke-check the shell renders**

```bash
EDGE="/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"; [ -f "$EDGE" ] || EDGE="/c/Program Files/Microsoft/Edge/Application/msedge.exe"; "$EDGE" --headless=new --disable-gpu --virtual-time-budget=2000 --dump-dom "file:///C:/Users/ntangs/Documents/Product-Madness/Product%20Madness%20v1.html" | grep -o 'id="timer-display"\|id="quick-log"\|id="order-rail"\|id="settings-drawer"' | wc -l
```
Expected: `4`

- [ ] **Step 4: Commit**

```bash
cd "C:/Users/ntangs/Documents/Product-Madness" && git add "Product Madness v1.html" && git commit -m "feat: skeleton, palette, shell, selftest harness

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Rules engine (stars, combo, XP, levels, showdown, time helpers)

**Files:**
- Modify: `Product Madness v1.html` - fill the `// ===== Rules =====` section; add a `SelfTest.suite` block just above the `// ===== Boot =====` marker.

**Interfaces:**
- Consumes: `U` from Task 1.
- Produces (all pure; later tasks call these exact names):
  - `Rules.stars(actualSec, parSec) -> 0|1|2|3`
  - `Rules.comboMultiplier(count) -> 1|1.1|1.25|1.5|2`
  - `Rules.taskXp(stars, showdownWin, comboCount) -> integer`
  - `Rules.xpForLevel(n) -> cumulative XP integer`, `Rules.levelForXp(xp) -> level integer`
  - `Rules.titleForLevel(n) -> string`
  - `Rules.showdownWinner(myCallSec, parSec, actualSec) -> 'you'|'ai'`
  - `Rules.dayKey(dateObj) -> 'YYYY-MM-DD'` (local), `Rules.weekOf(dateObj) -> Monday 'YYYY-MM-DD'`
  - `Rules.elapsedActiveMs(task, nowMs) -> ms` (task uses `startedAt`, `pausedMs`, `pausedAt`, `state`)
  - `Rules.currentComboBase(tasks, dayKey) -> integer` (consecutive starred finishes today, excluding running tasks)

- [ ] **Step 1: Write the failing tests**

Insert immediately before the `// ===== Boot =====` marker:

```js
SelfTest.suite(() => {
  SelfTest.eq('stars: 75% of par is 3', Rules.stars(75, 100), 3);
  SelfTest.eq('stars: 76% is 2', Rules.stars(76, 100), 2);
  SelfTest.eq('stars: 95% is 2', Rules.stars(95, 100), 2);
  SelfTest.eq('stars: 96% is 1', Rules.stars(96, 100), 1);
  SelfTest.eq('stars: exactly par is 1', Rules.stars(100, 100), 1);
  SelfTest.eq('stars: overtime is 0', Rules.stars(101, 100), 0);
  SelfTest.eq('combo: multipliers', [0,1,2,3,4,5,9].map(Rules.comboMultiplier), [1,1,1.1,1.25,1.5,2,2]);
  SelfTest.eq('xp: 3 stars + win at combo 4', Rules.taskXp(3, true, 4), Math.floor(33 * 1.5));
  SelfTest.eq('xp: 0 stars no win combo 0', Rules.taskXp(0, false, 0), 10);
  SelfTest.eq('levels: thresholds', [2,3,4,5,6,7,8,9,10].map(Rules.xpForLevel), [100,280,520,800,1120,1470,1850,2260,2700]);
  SelfTest.eq('levels: levelForXp boundaries', [0,99,100,279,280,2700].map(Rules.levelForXp), [1,1,2,2,3,10]);
  SelfTest.eq('titles: 1 and 10', [Rules.titleForLevel(1), Rules.titleForLevel(10)], ['Dishwasher','Michelin Three-Star']);
  SelfTest.eq('titles: 11 and 12', [Rules.titleForLevel(11), Rules.titleForLevel(12)], ['Legend of the Pass','Legend of the Pass II']);
  SelfTest.eq('showdown: closer call wins', Rules.showdownWinner(150, 210, 160), 'you');
  SelfTest.eq('showdown: tie goes to you', Rules.showdownWinner(150, 210, 180), 'you');
  SelfTest.eq('showdown: ai closer', Rules.showdownWinner(60, 170, 180), 'ai');
  SelfTest.eq('weekOf: Thu 2026-07-16 is week of Mon 13th', Rules.weekOf(new Date(2026, 6, 16)), '2026-07-13');
  SelfTest.eq('weekOf: Sun maps back to Monday', Rules.weekOf(new Date(2026, 6, 19)), '2026-07-13');
  SelfTest.eq('weekOf: Monday maps to itself', Rules.weekOf(new Date(2026, 6, 13)), '2026-07-13');
  SelfTest.eq('elapsed: running excludes pausedMs', Rules.elapsedActiveMs({ startedAt: 1000, pausedMs: 500, pausedAt: null, state: 'running' }, 3000), 1500);
  SelfTest.eq('elapsed: paused freezes clock', Rules.elapsedActiveMs({ startedAt: 1000, pausedMs: 0, pausedAt: 2000, state: 'paused' }, 5000), 1000);
  const mk = (state, stars, finishedAt) => ({ state, stars, finishedAt });
  const D = new Date(2026, 6, 16, 10).getTime();
  SelfTest.eq('combo base: two starred', Rules.currentComboBase([mk('done',2,D), mk('done',1,D+1)], '2026-07-16'), 2);
  SelfTest.eq('combo base: drop breaks', Rules.currentComboBase([mk('done',2,D), mk('dropped',0,D+1)], '2026-07-16'), 0);
  SelfTest.eq('combo base: zero-star breaks then rebuilds', Rules.currentComboBase([mk('done',0,D), mk('done',2,D+1)], '2026-07-16'), 1);
  SelfTest.eq('combo base: other days excluded', Rules.currentComboBase([mk('done',3,D - 86400000)], '2026-07-16'), 0);
});
```

- [ ] **Step 2: Run selftest to verify it fails**

Run the selftest command. Expected: output contains `failed` with a nonzero count (the suite throws `Rules is not defined`, reported as a fail).

- [ ] **Step 3: Implement Rules**

Fill the `// ===== Rules =====` section:

```js
const Rules = {
  stars(actualSec, parSec) {
    const t = actualSec / parSec;
    if (t <= 0.75) return 3;
    if (t <= 0.95) return 2;
    if (t <= 1.0) return 1;
    return 0;
  },
  comboMultiplier(count) { return count >= 5 ? 2 : ([1, 1, 1.1, 1.25, 1.5][count] || 1); },
  taskXp(stars, showdownWin, comboCount) {
    return Math.floor((10 + 5 * stars + (showdownWin ? 8 : 0)) * Rules.comboMultiplier(comboCount));
  },
  xpForLevel(n) { return n <= 1 ? 0 : Math.round(100 * Math.pow(n - 1, 1.5) / 10) * 10; },
  levelForXp(xp) { let n = 1; while (Rules.xpForLevel(n + 1) <= xp) n++; return n; },
  titleForLevel(n) {
    const t = ['Dishwasher', 'Prep Cook', 'Line Cook', 'Station Chef', 'Sous Chef',
               'Head Chef', 'Executive Chef', 'Michelin One-Star', 'Michelin Two-Star', 'Michelin Three-Star'];
    if (n <= 10) return t[n - 1];
    if (n === 11) return 'Legend of the Pass';
    const R = [['X', 10], ['IX', 9], ['V', 5], ['IV', 4], ['I', 1]];
    let k = n - 10, s = '';
    for (const [sym, v] of R) while (k >= v) { s += sym; k -= v; }
    return 'Legend of the Pass ' + s;
  },
  showdownWinner(myCallSec, parSec, actualSec) {
    return Math.abs(myCallSec - actualSec) <= Math.abs(parSec - actualSec) ? 'you' : 'ai';
  },
  dayKey(d) { return `${d.getFullYear()}-${U.pad2(d.getMonth() + 1)}-${U.pad2(d.getDate())}`; },
  weekOf(d) { const x = new Date(d); x.setDate(x.getDate() - ((x.getDay() + 6) % 7)); return Rules.dayKey(x); },
  elapsedActiveMs(task, nowMs) {
    const pausing = task.state === 'paused' && task.pausedAt ? (nowMs - task.pausedAt) : 0;
    return nowMs - task.startedAt - (task.pausedMs || 0) - pausing;
  },
  currentComboBase(tasks, dayKey) {
    const seq = tasks
      .filter(t => (t.state === 'done' || t.state === 'dropped') && t.finishedAt && Rules.dayKey(new Date(t.finishedAt)) === dayKey)
      .sort((a, b) => a.finishedAt - b.finishedAt);
    let c = 0;
    for (let i = seq.length - 1; i >= 0; i--) {
      if (seq[i].state === 'done' && seq[i].stars > 0) c++; else break;
    }
    return c;
  },
};
```

- [ ] **Step 4: Run selftest to verify it passes**

Run the selftest command. Expected: `SELFTEST: 29 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/ntangs/Documents/Product-Madness" && git add "Product Madness v1.html" && git commit -m "feat: rules engine - stars, combo, xp, levels, showdown, time helpers

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Estimator and seed category library

**Files:**
- Modify: `Product Madness v1.html` - fill `// ===== Estimator =====`; add a `SelfTest.suite` block above `// ===== Boot =====`.

**Interfaces:**
- Consumes: `U`.
- Produces:
  - `SEED_CATEGORIES` - object keyed by category id, values `{ label, emoji, keywords: string[], baselineSec, samples: number[], archived: false }`. Ids: `email-reply, chat-reply, jira-comment, jira-draft, grooming, wireframe, doc-review, notes, agenda, status, calendar, files, data-check, nudge, other`.
  - `Estimator.detectCategory(title, categories) -> categoryId` (lowercase substring match, first match in insertion order, fallback `'other'`)
  - `Estimator.localPar(categoryObj) -> seconds` (median of last 5 when 3+ samples; blend `(sum + baseline * (3 - count)) / 3` for 1-2; baseline for 0; round to 5s; clamp 30..1200)

- [ ] **Step 1: Write the failing tests**

```js
SelfTest.suite(() => {
  SelfTest.eq('detect: email keyword', Estimator.detectCategory('Reply to Alex email', SEED_CATEGORIES), 'email-reply');
  SelfTest.eq('detect: multi-word phrase', Estimator.detectCategory('follow up with Sam', SEED_CATEGORIES), 'nudge');
  SelfTest.eq('detect: no match falls to other', Estimator.detectCategory('water the plants', SEED_CATEGORIES), 'other');
  SelfTest.eq('detect: case-insensitive', Estimator.detectCategory('GROOM the backlog', SEED_CATEGORIES), 'grooming');
  const cat = (baselineSec, samples) => ({ baselineSec, samples, archived: false });
  SelfTest.eq('par: 0 samples uses baseline', Estimator.localPar(cat(180, [])), 180);
  SelfTest.eq('par: 1 sample blends', Estimator.localPar(cat(180, [60])), 140);
  SelfTest.eq('par: 2 samples blend', Estimator.localPar(cat(180, [60, 90])), 110);
  SelfTest.eq('par: 3 samples use median', Estimator.localPar(cat(180, [100, 200, 300])), 200);
  SelfTest.eq('par: 6+ samples use last five', Estimator.localPar(cat(180, [600, 100, 100, 100, 100, 100])), 100);
  SelfTest.eq('par: rounds to 5s', Estimator.localPar(cat(133, [])), 135);
  SelfTest.eq('par: clamps low', Estimator.localPar(cat(180, [5, 5, 5])), 30);
  SelfTest.eq('par: clamps high', Estimator.localPar(cat(180, [4000, 4000, 4000])), 1200);
  SelfTest.ok('seed: 15 categories', Object.keys(SEED_CATEGORIES).length === 15);
  SelfTest.ok('seed: other has no keywords', SEED_CATEGORIES.other.keywords.length === 0);
});
```

- [ ] **Step 2: Run selftest to verify it fails**

Run the selftest command. Expected: nonzero failed count (`Estimator is not defined`).

- [ ] **Step 3: Implement Estimator and seeds**

```js
const SEED_CATEGORIES = {
  'email-reply': { label: 'Email reply', emoji: '✉️', keywords: ['email', 'reply', 'respond', 'inbox'], baselineSec: 180, samples: [], archived: false },
  'chat-reply':  { label: 'Teams/chat reply', emoji: '💬', keywords: ['teams', 'chat', 'slack', 'message', 'ping'], baselineSec: 90, samples: [], archived: false },
  'jira-comment':{ label: 'Jira comment', emoji: '🎫', keywords: ['jira comment', 'comment', 'acm-'], baselineSec: 150, samples: [], archived: false },
  'jira-draft':  { label: 'Jira ticket draft', emoji: '📝', keywords: ['ticket', 'story', 'jira', 'draft'], baselineSec: 300, samples: [], archived: false },
  'grooming':    { label: 'Backlog grooming', emoji: '🧹', keywords: ['groom', 'backlog', 'triage'], baselineSec: 300, samples: [], archived: false },
  'wireframe':   { label: 'Wireframe edit', emoji: '🎨', keywords: ['wireframe', 'mockup', 'html'], baselineSec: 240, samples: [], archived: false },
  'doc-review':  { label: 'Doc review skim', emoji: '📄', keywords: ['review', 'skim', 'read'], baselineSec: 240, samples: [], archived: false },
  'notes':       { label: 'Meeting notes', emoji: '🗒️', keywords: ['notes', 'recap', 'minutes'], baselineSec: 240, samples: [], archived: false },
  'agenda':      { label: 'Agenda prep', emoji: '📋', keywords: ['agenda', 'prep', '1:1'], baselineSec: 300, samples: [], archived: false },
  'status':      { label: 'Status update', emoji: '📣', keywords: ['status', 'update', 'standup'], baselineSec: 180, samples: [], archived: false },
  'calendar':    { label: 'Calendar wrangling', emoji: '📆', keywords: ['calendar', 'schedule', 'invite'], baselineSec: 120, samples: [], archived: false },
  'files':       { label: 'File cleanup', emoji: '🗂️', keywords: ['file', 'rename', 'organize', 'folder'], baselineSec: 120, samples: [], archived: false },
  'data-check':  { label: 'Quick data check', emoji: '🔎', keywords: ['check', 'verify', 'lookup'], baselineSec: 180, samples: [], archived: false },
  'nudge':       { label: 'Follow-up nudge', emoji: '👋', keywords: ['follow up', 'nudge', 'remind'], baselineSec: 90, samples: [], archived: false },
  'other':       { label: 'Other', emoji: '⭐', keywords: [], baselineSec: 180, samples: [], archived: false },
};

const Estimator = {
  detectCategory(title, categories) {
    const t = title.toLowerCase();
    for (const [id, c] of Object.entries(categories)) {
      if (c.archived || !c.keywords.length) continue;
      if (c.keywords.some(k => t.includes(k))) return id;
    }
    return 'other';
  },
  localPar(cat) {
    const s = cat.samples;
    let sec;
    if (s.length >= 3) sec = U.median(s.slice(-5));
    else if (s.length > 0) sec = (s.reduce((a, b) => a + b, 0) + cat.baselineSec * (3 - s.length)) / 3;
    else sec = cat.baselineSec;
    return U.clamp(U.round5(sec), 30, 1200);
  },
};
```

- [ ] **Step 4: Run selftest to verify it passes**

Run the selftest command. Expected: `SELFTEST: 43 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/ntangs/Documents/Product-Madness" && git add "Product Madness v1.html" && git commit -m "feat: local estimator with seeded category library

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: Quests engine

**Files:**
- Modify: `Product Madness v1.html` - fill `// ===== Quests =====`; add a `SelfTest.suite` block above `// ===== Boot =====`.

**Interfaces:**
- Consumes: nothing new.
- Produces:
  - `mulberry32(seed) -> () => float`
  - `QUEST_TEMPLATES` - array of `{ id, label, target, rewardXp }` (8 templates, ids 1..8, per spec 3.6)
  - `Quests.forDate(dayKey) -> [{ templateId, label, target, rewardXp, progress: 0, done: false }]` (3 items, deterministic per dayKey)
  - `Quests.applyFinish(items, ctx) -> newlyDone[]` where `ctx = { stars, showdownWin, combo, hour, categoriesToday, fromRail }` (mutates items)
  - `Quests.applyDrop(items)` (resets templates 7 and 8 progress)

- [ ] **Step 1: Write the failing tests**

```js
SelfTest.suite(() => {
  const a = Quests.forDate('2026-07-16'), b = Quests.forDate('2026-07-16');
  SelfTest.eq('quests: deterministic per date', a, b);
  SelfTest.ok('quests: three distinct templates', new Set(a.map(q => q.templateId)).size === 3);
  SelfTest.ok('quests: different date differs', JSON.stringify(Quests.forDate('2026-07-17')) !== JSON.stringify(a));
  const items = [
    { templateId: 1, label: 'Clear 5 tasks', target: 5, rewardXp: 40, progress: 4, done: false },
    { templateId: 3, label: 'Beat the AI in 2 showdowns', target: 2, rewardXp: 45, progress: 1, done: false },
    { templateId: 5, label: 'Score a 3-star finish before noon', target: 1, rewardXp: 50, progress: 0, done: false },
    { templateId: 8, label: '5 starred finishes in a row', target: 5, rewardXp: 60, progress: 3, done: false },
  ];
  const newlyDone = Quests.applyFinish(items, { stars: 3, showdownWin: true, combo: 2, hour: 10, categoriesToday: 2, fromRail: false });
  SelfTest.eq('quests: task count completes', items[0].done, true);
  SelfTest.eq('quests: showdown completes', items[1].done, true);
  SelfTest.eq('quests: 3-star before noon completes', items[2].done, true);
  SelfTest.eq('quests: streak advances', items[3].progress, 4);
  SelfTest.eq('quests: newlyDone lists three', newlyDone.length, 3);
  Quests.applyFinish(items, { stars: 0, showdownWin: false, combo: 0, hour: 14, categoriesToday: 2, fromRail: false });
  SelfTest.eq('quests: unstarred finish resets streak', items[3].progress, 0);
  const railItems = [{ templateId: 7, label: 'Clear 3 rail tickets, no drops', target: 3, rewardXp: 45, progress: 2, done: false }];
  Quests.applyDrop(railItems);
  SelfTest.eq('quests: drop resets rail quest', railItems[0].progress, 0);
});
```

- [ ] **Step 2: Run selftest to verify it fails**

Run the selftest command. Expected: nonzero failed count (`Quests is not defined`).

- [ ] **Step 3: Implement Quests**

```js
function mulberry32(seed) {
  let a = seed >>> 0;
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const QUEST_TEMPLATES = [
  { id: 1, label: 'Clear 5 tasks', target: 5, rewardXp: 40 },
  { id: 2, label: 'Earn 6 stars', target: 6, rewardXp: 40 },
  { id: 3, label: 'Beat the AI in 2 showdowns', target: 2, rewardXp: 45 },
  { id: 4, label: 'Reach a 3-combo', target: 3, rewardXp: 45 },
  { id: 5, label: 'Score a 3-star finish before noon', target: 1, rewardXp: 50 },
  { id: 6, label: 'Finish tasks in 3 categories', target: 3, rewardXp: 40 },
  { id: 7, label: 'Clear 3 rail tickets, no drops', target: 3, rewardXp: 45 },
  { id: 8, label: '5 starred finishes in a row', target: 5, rewardXp: 60 },
];

const Quests = {
  forDate(dayKey) {
    const rnd = mulberry32(Number(dayKey.replaceAll('-', '')));
    const pool = [...QUEST_TEMPLATES];
    const picked = [];
    while (picked.length < 3) picked.push(pool.splice(Math.floor(rnd() * pool.length), 1)[0]);
    return picked.map(t => ({ templateId: t.id, label: t.label, target: t.target, rewardXp: t.rewardXp, progress: 0, done: false }));
  },
  applyFinish(items, ctx) {
    const newlyDone = [];
    for (const q of items) {
      if (q.done) continue;
      switch (q.templateId) {
        case 1: q.progress++; break;
        case 2: q.progress = Math.min(q.target, q.progress + ctx.stars); break;
        case 3: if (ctx.showdownWin) q.progress++; break;
        case 4: q.progress = Math.max(q.progress, ctx.combo); break;
        case 5: if (ctx.stars === 3 && ctx.hour < 12) q.progress = 1; break;
        case 6: q.progress = Math.min(q.target, ctx.categoriesToday); break;
        case 7: if (ctx.fromRail) q.progress++; break;
        case 8: q.progress = ctx.stars > 0 ? q.progress + 1 : 0; break;
      }
      if (q.progress >= q.target) { q.done = true; newlyDone.push(q); }
    }
    return newlyDone;
  },
  applyDrop(items) {
    for (const q of items) if (!q.done && (q.templateId === 7 || q.templateId === 8)) q.progress = 0;
  },
};
```

- [ ] **Step 4: Run selftest to verify it passes**

Run the selftest command. Expected: `SELFTEST: 53 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/ntangs/Documents/Product-Madness" && git add "Product Madness v1.html" && git commit -m "feat: deterministic daily quests engine

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: Store (state, persistence, rollover, export/import)

**Files:**
- Modify: `Product Madness v1.html` - fill `// ===== Store =====`; add a `SelfTest.suite` block above `// ===== Boot =====`.

**Interfaces:**
- Consumes: `Rules.dayKey`, `Rules.weekOf`, `Quests.forDate`, `SEED_CATEGORIES`.
- Produces:
  - `Store.KEY = 'product-madness.v1'`, `Store.state`, `Store.storage`
  - `Store.defaults(nowDate) -> state doc` (schema per spec 5.3; task objects also carry `pausedAt: null` and `fromRail: false`)
  - `Store.load(storage, nowDate) -> { corrupt: boolean, raw: string|null }` (on corrupt/foreign version: state = defaults IN MEMORY ONLY, no save; raw = original string)
  - `Store.save() -> boolean` (false on quota error)
  - `Store.ensureDay(nowDate) -> boolean changed`, `Store.ensureWeek(nowDate) -> boolean changed`
  - `Store.recordSample(catId, sec)` (appends, keeps last 20)
  - `Store.exportJson() -> string` (pretty JSON, apiKey stripped)
  - `Store.importJson(text) -> boolean` (validates version 1 + shape; preserves the local apiKey; saves on success)

- [ ] **Step 1: Write the failing tests**

```js
SelfTest.suite(() => {
  const fake = () => ({ data: {}, getItem(k) { return k in this.data ? this.data[k] : null; }, setItem(k, v) { this.data[k] = v; }, removeItem(k) { delete this.data[k]; } });
  const D = new Date(2026, 6, 16, 9);
  let f = fake();
  let r = Store.load(f, D);
  SelfTest.eq('store: fresh load not corrupt', r.corrupt, false);
  SelfTest.eq('store: defaults level 1', Store.state.player.level, 1);
  SelfTest.eq('store: quests dated today', Store.state.quests.date, '2026-07-16');
  SelfTest.eq('store: showdown week Monday', Store.state.player.showdown.weekOf, '2026-07-13');
  Store.state.player.xp = 123; Store.save();
  Store.load(f, D);
  SelfTest.eq('store: save/load roundtrip', Store.state.player.xp, 123);
  SelfTest.eq('store: day rollover regenerates quests', Store.ensureDay(new Date(2026, 6, 17, 9)), true);
  SelfTest.eq('store: quests now dated 17th', Store.state.quests.date, '2026-07-17');
  SelfTest.eq('store: week rollover resets tally', (Store.state.player.showdown.you = 5, Store.ensureWeek(new Date(2026, 6, 20, 9)), Store.state.player.showdown.you), 0);
  for (let i = 0; i < 25; i++) Store.recordSample('email-reply', 100 + i);
  SelfTest.eq('store: samples capped at 20', Store.state.categories['email-reply'].samples.length, 20);
  SelfTest.eq('store: samples keep newest', Store.state.categories['email-reply'].samples[19], 124);
  Store.state.settings.apiKey = 'sk-ant-secret';
  SelfTest.ok('store: export strips key', !Store.exportJson().includes('sk-ant-secret'));
  SelfTest.eq('store: import garbage rejected', Store.importJson('{nope'), false);
  SelfTest.eq('store: import wrong version rejected', Store.importJson('{"version":2}'), false);
  const exported = Store.exportJson();
  Store.state.player.xp = 999;
  SelfTest.eq('store: import restores', (Store.importJson(exported), Store.state.player.xp), 123);
  SelfTest.eq('store: import preserves local key', Store.state.settings.apiKey, 'sk-ant-secret');
  const f2 = fake(); f2.data[Store.KEY] = '{broken json';
  const r2 = Store.load(f2, D);
  SelfTest.eq('store: corrupt flagged', r2.corrupt, true);
  SelfTest.eq('store: corrupt raw preserved', r2.raw, '{broken json');
  SelfTest.ok('store: corrupt not auto-saved over', f2.data[Store.KEY] === '{broken json');
});
```

- [ ] **Step 2: Run selftest to verify it fails**

Run the selftest command. Expected: nonzero failed count (`Store is not defined`).

- [ ] **Step 3: Implement Store**

```js
const Store = {
  KEY: 'product-madness.v1',
  state: null,
  storage: null,
  defaults(nowDate) {
    return {
      version: 1,
      player: { xp: 0, level: 1, starsTotal: 0, bestCombo: 0,
                showdown: { weekOf: Rules.weekOf(nowDate), you: 0, ai: 0 } },
      tasks: [],
      categories: JSON.parse(JSON.stringify(SEED_CATEGORIES)),
      quests: { date: Rules.dayKey(nowDate), items: Quests.forDate(Rules.dayKey(nowDate)) },
      settings: { apiKey: '', apiEnabled: false, model: 'claude-haiku-4-5', sound: true, lastExportAt: null },
    };
  },
  load(storage, nowDate) {
    Store.storage = storage;
    let raw = null, s = null, corrupt = false;
    try { raw = storage.getItem(Store.KEY); if (raw) s = JSON.parse(raw); }
    catch (e) { corrupt = true; }
    if (s && s.version !== 1) { corrupt = true; s = null; }
    if (!s) {
      Store.state = Store.defaults(nowDate);
      if (!corrupt && raw === null) Store.save();
      return { corrupt, raw };
    }
    Store.state = s;
    if (Store.ensureDay(nowDate) | Store.ensureWeek(nowDate)) Store.save();
    return { corrupt: false, raw };
  },
  save() { try { Store.storage.setItem(Store.KEY, JSON.stringify(Store.state)); return true; } catch (e) { return false; } },
  ensureDay(nowDate) {
    const dk = Rules.dayKey(nowDate);
    if (Store.state.quests.date === dk) return false;
    Store.state.quests = { date: dk, items: Quests.forDate(dk) };
    return true;
  },
  ensureWeek(nowDate) {
    const wk = Rules.weekOf(nowDate), sd = Store.state.player.showdown;
    if (sd.weekOf === wk) return false;
    sd.weekOf = wk; sd.you = 0; sd.ai = 0;
    return true;
  },
  recordSample(catId, sec) {
    const c = Store.state.categories[catId];
    if (!c) return;
    c.samples.push(sec);
    if (c.samples.length > 20) c.samples = c.samples.slice(-20);
  },
  exportJson() {
    const copy = JSON.parse(JSON.stringify(Store.state));
    copy.settings.apiKey = '';
    return JSON.stringify(copy, null, 2);
  },
  importJson(text) {
    let s;
    try { s = JSON.parse(text); } catch (e) { return false; }
    if (!s || s.version !== 1 || !s.player || !Array.isArray(s.tasks) || !s.categories || !s.quests || !s.settings) return false;
    s.settings.apiKey = (Store.state && Store.state.settings.apiKey) || '';
    Store.state = s;
    Store.save();
    return true;
  },
};
```

- [ ] **Step 4: Run selftest to verify it passes**

Run the selftest command. Expected: `SELFTEST: 71 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/ntangs/Documents/Product-Madness" && git add "Product Madness v1.html" && git commit -m "feat: store - persistence, rollover, export/import, corruption safety

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: Kitchen scene - core loop, timer, order rail

**Files:**
- Modify: `Product Madness v1.html` - fill `// ===== UI =====` (partially; Progress rendering lands in Task 7 by extending `UI`); no new selftest suites (pure logic already covered; this task is DOM wiring).

**Interfaces:**
- Consumes: everything produced so far.
- Produces (Task 7/8/9/10 call these exact names):
  - `UI.boot()`, `UI.renderAll()`, `UI.toast(msg)`, `UI.el(id) -> element`
  - `UI.flow = { stage: 'idle'|'call'|'ready'|'run', taskId: string|null }`
  - `UI.addTask(title) -> task`, `UI.enterCall(task)`, `UI.lockCall()`, `UI.startTask(task, fromRail)`, `UI.finishTask(task)`, `UI.dropTask(task)`, `UI.togglePause(task)`
  - `UI.renderRail()`, `UI.renderStage()`, `UI.renderHud()` (stub ok until Task 7), `UI.renderProgress()` (stub until Task 7)
  - `UI.revealPar(task) -> Promise` (local par now; Task 9 patches in the API path)
  - `UI.onLevelUp(newLevel)` (stub: toast; Task 8 replaces with card + confetti)
  - `UI.finishFlavor(task) -> string` (stub returning ''; Task 8 fills)

- [ ] **Step 1: Implement the UI module (core loop)**

Fill `// ===== UI =====`:

```js
const UI = {
  flow: { stage: 'idle', taskId: null },
  el: id => document.getElementById(id),
  now: () => Date.now(),
  _raf: null,

  boot() {
    const res = Store.load(window.localStorage, new Date());
    UI.bind();
    UI.renderAll();
    UI.tickLoop();
    if (res.corrupt) UI.showCorrupt(res.raw);
    UI.maybeRestore();
    setInterval(UI.rollover, 30000);
  },

  bind() {
    UI.el('quick-log').addEventListener('keydown', e => {
      if (e.key !== 'Enter') return;
      const title = e.target.value.trim();
      if (!title) return;
      e.target.value = '';
      const task = UI.addTask(title);
      const busy = UI.flow.stage !== 'idle';
      if (busy) { UI.toast('🎟 ticket on the rail'); UI.renderRail(); }
      else UI.enterCall(task);
    });
    UI.el('quick-log').addEventListener('input', e => {
      const t = e.target.value.trim();
      const chip = UI.el('quick-cat');
      if (!t) { chip.hidden = true; return; }
      const cat = Store.state.categories[Estimator.detectCategory(t, Store.state.categories)];
      chip.textContent = cat.emoji + ' ' + cat.label;
      chip.hidden = false;
    });
    UI.el('btn-lock').addEventListener('click', UI.lockCall);
    UI.el('btn-cancel-call').addEventListener('click', () => {
      UI.flow = { stage: 'idle', taskId: null };
      UI.renderStage(); UI.renderRail();
    });
    UI.el('btn-start').addEventListener('click', () => {
      const t = UI.task(); if (t) UI.beginRun(t);
    });
    UI.el('btn-done').addEventListener('click', () => { const t = UI.task(); if (t) UI.finishTask(t); });
    UI.el('btn-pause').addEventListener('click', () => { const t = UI.task(); if (t) UI.togglePause(t); });
    UI.el('btn-drop').addEventListener('click', () => { const t = UI.task(); if (t) UI.dropTask(t); });
    UI.el('call-slider').addEventListener('input', e => UI.setCall(Number(e.target.value)));
    UI.el('tab-kitchen').addEventListener('click', () => UI.switchTab('kitchen'));
    UI.el('tab-progress').addEventListener('click', () => UI.switchTab('progress'));
  },

  task() { return Store.state.tasks.find(t => t.id === UI.flow.taskId) || null; },

  addTask(title) {
    const category = Estimator.detectCategory(title, Store.state.categories);
    const task = { id: U.uid(), title, category, state: 'queued',
      createdAt: UI.now(), startedAt: 0, pausedMs: 0, pausedAt: null, finishedAt: 0,
      parSec: 0, parSource: 'local', myCallSec: 0, actualSec: 0,
      stars: 0, showdownWin: false, xp: 0, comboAt: 1, quip: '', fromRail: false };
    Store.state.tasks.push(task);
    Store.save();
    return task;
  },

  // --- call picker ---
  _callSec: 180,
  enterCall(task) {
    UI.flow = { stage: 'call', taskId: task.id };
    UI.el('call-title').textContent = task.title;
    const chips = UI.el('call-chips');
    chips.innerHTML = '';
    [60, 120, 180, 240, 300].forEach(sec => {
      const b = document.createElement('button');
      b.textContent = (sec / 60) + ' min';
      b.dataset.sec = sec;
      b.addEventListener('click', () => UI.setCall(sec));
      chips.appendChild(b);
    });
    UI.setCall(180);
    UI.renderStage(); UI.renderRail();
  },
  setCall(sec) {
    UI._callSec = sec;
    UI.el('call-slider').value = sec;
    UI.el('call-value').textContent = U.mmss(sec);
    document.querySelectorAll('#call-chips button').forEach(b =>
      b.classList.toggle('on', Number(b.dataset.sec) === sec));
  },
  async lockCall() {
    const task = UI.task(); if (!task) return;
    task.myCallSec = UI._callSec;
    UI.flow.stage = 'ready';
    UI.renderStage();
    await UI.revealPar(task);
    Store.save();
  },
  async revealPar(task) {
    const cat = Store.state.categories[task.category];
    task.parSec = Estimator.localPar(cat);
    task.parSource = 'local';
    task.quip = '';
    UI.el('ready-title').textContent = task.title;
    UI.el('ready-par').textContent = U.mmss(task.parSec);
    UI.el('ready-par-src').textContent = task.parSource;
    UI.el('ready-call').textContent = U.mmss(task.myCallSec);
    UI.el('ready-quip').textContent = task.quip;
  },

  // --- running ---
  beginRun(task, fromRail = false) {
    task.state = 'running';
    task.startedAt = UI.now();
    task.fromRail = task.fromRail || fromRail;
    UI.flow = { stage: 'run', taskId: task.id };
    UI.el('run-title').textContent = task.title;
    UI.el('run-par').textContent = 'par ' + U.mmss(task.parSec);
    UI.el('run-call').textContent = '🥊 ' + U.mmss(task.myCallSec);
    Store.save();
    UI.renderStage(); UI.renderRail();
  },
  async startTask(task, fromRail) {
    UI.flow = { stage: 'call', taskId: task.id };
    UI.enterCall(task);
    task.fromRail = fromRail;
  },
  togglePause(task) {
    if (task.state === 'running') { task.state = 'paused'; task.pausedAt = UI.now(); }
    else if (task.state === 'paused') { task.pausedMs += UI.now() - task.pausedAt; task.pausedAt = null; task.state = 'running'; }
    UI.el('btn-pause').textContent = task.state === 'paused' ? '▶ resume' : '⏸ pause';
    UI.el('timer-display').classList.toggle('paused', task.state === 'paused');
    Store.save();
  },

  finishTask(task) {
    const nowD = new Date();
    Store.ensureDay(nowD); Store.ensureWeek(nowD);
    const dk = Rules.dayKey(nowD);
    const base = Rules.currentComboBase(Store.state.tasks, dk);
    const actualSec = Math.max(1, Math.round(Rules.elapsedActiveMs(task, UI.now()) / 1000));
    if (task.state === 'paused') { task.pausedMs += UI.now() - task.pausedAt; task.pausedAt = null; }
    task.state = 'done'; task.finishedAt = UI.now(); task.actualSec = actualSec;
    task.stars = Rules.stars(actualSec, task.parSec);
    const win = Rules.showdownWinner(task.myCallSec, task.parSec, actualSec) === 'you';
    task.showdownWin = win;
    const combo = task.stars > 0 ? base + 1 : 0;
    task.comboAt = Math.max(1, combo);
    task.xp = Rules.taskXp(task.stars, win, combo);
    const p = Store.state.player;
    const beforeLevel = Rules.levelForXp(p.xp);
    p.xp += task.xp;
    p.starsTotal += task.stars;
    p.bestCombo = Math.max(p.bestCombo, combo);
    p.showdown[win ? 'you' : 'ai']++;
    Store.recordSample(task.category, actualSec);
    const todayCats = new Set(Store.state.tasks
      .filter(t => t.state === 'done' && t.finishedAt && Rules.dayKey(new Date(t.finishedAt)) === dk)
      .map(t => t.category));
    const newlyDone = Quests.applyFinish(Store.state.quests.items,
      { stars: task.stars, showdownWin: win, combo, hour: nowD.getHours(), categoriesToday: todayCats.size, fromRail: task.fromRail });
    for (const q of newlyDone) { p.xp += q.rewardXp; UI.toast('🏆 quest: ' + q.label + ' +' + q.rewardXp + ' XP'); }
    p.level = Rules.levelForXp(p.xp);
    Store.save();
    const starTxt = task.stars > 0 ? '★'.repeat(task.stars) : 'overtime';
    UI.toast(`${starTxt} +${task.xp} XP` + (combo >= 2 ? ` (x${Rules.comboMultiplier(combo)} combo)` : ''));
    UI.toast(win ? '🥊 you beat the AI!' : '🤖 the AI takes this one');
    const flavor = UI.finishFlavor(task);
    if (flavor) UI.toast(flavor);
    if (p.level > beforeLevel) UI.onLevelUp(p.level);
    UI.flow = { stage: 'idle', taskId: null };
    UI.renderAll();
  },

  dropTask(task) {
    if (task.state === 'paused' && task.pausedAt) { task.pausedMs += UI.now() - task.pausedAt; task.pausedAt = null; }
    task.state = 'dropped'; task.finishedAt = UI.now();
    Quests.applyDrop(Store.state.quests.items);
    Store.save();
    UI.toast('✕ dropped - no harm done');
    UI.flow = { stage: 'idle', taskId: null };
    UI.renderAll();
  },

  // --- timer loop ---
  tickLoop() {
    const step = () => {
      const t = UI.task();
      if (UI.flow.stage === 'run' && t && (t.state === 'running' || t.state === 'paused')) {
        const el = Math.round(Rules.elapsedActiveMs(t, UI.now()) / 1000);
        const remain = t.parSec - el;
        const disp = UI.el('timer-display');
        if (remain >= 0) {
          disp.textContent = U.mmss(remain);
          disp.classList.remove('overtime');
          if (remain <= 5 && remain > 0 && t.state === 'running' && UI._lastTick !== remain) { UI._lastTick = remain; Sfx.tick(); }
        } else {
          disp.textContent = '+' + U.mmss(-remain);
          disp.classList.add('overtime');
        }
        UI.el('par-fill').style.width = Math.min(100, (el / t.parSec) * 100) + '%';
      }
      const d = new Date();
      UI.el('hud-clock').textContent = `${d.getHours() % 12 || 12}:${U.pad2(d.getMinutes())}${d.getHours() < 12 ? 'a' : 'p'}`;
      UI._raf = requestAnimationFrame(step);
    };
    UI._raf = requestAnimationFrame(step);
    document.addEventListener('visibilitychange', () => { if (!document.hidden) UI.renderAll(); });
  },
  _lastTick: null,

  // --- rail + stage + scenes ---
  renderRail() {
    const rail = UI.el('order-rail');
    const queued = Store.state.tasks.filter(t => t.state === 'queued' && t.id !== UI.flow.taskId);
    rail.innerHTML = '';
    for (const t of queued) {
      const cat = Store.state.categories[t.category];
      const tk = document.createElement('div');
      tk.className = 'ticket';
      tk.innerHTML = `<div class="t-title">${U.esc(t.title)}</div>
        <div class="t-row"><span class="chip">${cat.emoji} ${U.esc(cat.label)}</span>
        <button class="t-start">▶</button><button class="t-del">✕</button></div>`;
      tk.querySelector('.t-start').addEventListener('click', () => {
        if (UI.flow.stage !== 'idle') { UI.toast('finish the current task first'); return; }
        UI.startTask(t, true);
      });
      tk.querySelector('.t-del').addEventListener('click', () => {
        t.state = 'dropped'; t.finishedAt = UI.now(); Store.save(); UI.renderRail();
      });
      rail.appendChild(tk);
    }
  },
  renderStage() {
    const map = { idle: 'stage-idle', call: 'stage-call', ready: 'stage-ready', run: 'stage-run' };
    for (const [stage, id] of Object.entries(map)) UI.el(id).classList.toggle('on', UI.flow.stage === stage);
    const t = UI.task();
    if (UI.flow.stage === 'run' && t) {
      UI.el('btn-pause').textContent = t.state === 'paused' ? '▶ resume' : '⏸ pause';
      UI.el('timer-display').classList.toggle('paused', t.state === 'paused');
    }
  },
  switchTab(name) {
    UI.el('scene-kitchen').classList.toggle('on', name === 'kitchen');
    UI.el('scene-progress').classList.toggle('on', name === 'progress');
    UI.el('tab-kitchen').classList.toggle('on', name === 'kitchen');
    UI.el('tab-progress').classList.toggle('on', name === 'progress');
    if (name === 'progress') UI.renderProgress();
  },
  renderAll() { UI.renderStage(); UI.renderRail(); UI.renderHud(); UI.renderProgress(); },
  renderHud() {},        // Task 7
  renderProgress() {},   // Task 7
  finishFlavor(task) { return ''; },  // Task 8
  onLevelUp(newLevel) { UI.toast('🎉 Level ' + newLevel + ' - ' + Rules.titleForLevel(newLevel)); }, // Task 8 upgrades

  // --- restore + banners + toasts ---
  maybeRestore() {
    const t = Store.state.tasks.find(t => t.state === 'running' || t.state === 'paused');
    if (!t) return;
    UI.banner(`"${t.title}" was still on the clock - keep racing?`, [
      ['Keep racing', () => { UI.flow = { stage: 'run', taskId: t.id }; UI.el('run-title').textContent = t.title; UI.el('run-par').textContent = 'par ' + U.mmss(t.parSec); UI.el('run-call').textContent = '🥊 ' + U.mmss(t.myCallSec); UI.renderStage(); }],
      ['Drop it', () => UI.dropTask(t)],
    ]);
  },
  showCorrupt(raw) {
    UI.banner('Saved data could not be read. Export what is recoverable, then reset.', [
      ['Download raw', () => { const a = document.createElement('a'); a.href = URL.createObjectURL(new Blob([raw || ''], { type: 'application/json' })); a.download = 'product-madness-recovered.json'; a.click(); }],
      ['Reset', () => { Store.save(); UI.banner(null); UI.renderAll(); }],
    ]);
  },
  banner(msg, actions = []) {
    const b = UI.el('banner');
    if (!msg) { b.hidden = true; return; }
    UI.el('banner-msg').textContent = msg;
    const act = UI.el('banner-actions');
    act.innerHTML = '';
    for (const [label, fn] of actions) {
      const btn = document.createElement('button');
      btn.className = 'btn-minor'; btn.textContent = label;
      btn.addEventListener('click', () => { b.hidden = true; fn(); });
      act.appendChild(btn);
    }
    b.hidden = false;
  },
  toast(msg) {
    const t = document.createElement('div');
    t.className = 'toast'; t.textContent = msg;
    UI.el('toasts').appendChild(t);
    setTimeout(() => t.remove(), 2600);
  },
  rollover() {
    const nowD = new Date();
    const changed = Store.ensureDay(nowD) | Store.ensureWeek(nowD);
    if (changed) { Store.save(); UI.renderAll(); }
  },
};
```

Also fill `// ===== Sfx =====` with a silent stub so `Sfx.tick()` does not throw before Task 8:

```js
const Sfx = { tick() {}, ding() {}, star() {}, womp() {}, levelUp() {} };
```

- [ ] **Step 2: Run selftest to confirm nothing regressed**

Run the selftest command. Expected: `SELFTEST: 71 passed, 0 failed`

- [ ] **Step 3: Smoke-check boot**

```bash
EDGE="/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"; [ -f "$EDGE" ] || EDGE="/c/Program Files/Microsoft/Edge/Application/msedge.exe"; "$EDGE" --headless=new --disable-gpu --virtual-time-budget=2000 --dump-dom "file:///C:/Users/ntangs/Documents/Product-Madness/Product%20Madness%20v1.html" | grep -c 'stage-idle" class="stage-card on"'
```
Expected: `1` (boot ran, idle stage active, no thrown error blanking the page)

- [ ] **Step 4: Manual check (open the file in a browser)**

Verify: type "reply to Alex email" + Enter shows the call picker with the email chip suggested; lock call shows par reveal (badge "local"); Start runs the countdown; DONE fires star + XP toasts; a second task typed mid-run lands on the rail and can be started after; pause freezes the timer; drop clears without toasts of XP.

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/ntangs/Documents/Product-Madness" && git add "Product Madness v1.html" && git commit -m "feat: kitchen scene - core loop, timer, order rail, restore banner

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: HUD and Progress scene

**Files:**
- Modify: `Product Madness v1.html` - replace the `UI.renderHud` and `UI.renderProgress` stubs (keep the exact names); add one `SelfTest.suite` block above `// ===== Boot =====`.

**Interfaces:**
- Consumes: `UI`, `Store`, `Rules`, `U`.
- Produces: `UI.categoryRecords() -> [{ id, label, emoji, median, best, count }]` (pure over `Store.state`; sorted by count desc, only categories with at least 1 sample).

- [ ] **Step 1: Write the failing test**

```js
SelfTest.suite(() => {
  const fake = { data: {}, getItem(k) { return k in this.data ? this.data[k] : null; }, setItem(k, v) { this.data[k] = v; }, removeItem(k) { delete this.data[k]; } };
  Store.load(fake, new Date(2026, 6, 16, 9));
  Store.state.categories['email-reply'].samples = [100, 200, 300];
  Store.state.categories['notes'].samples = [240];
  const rec = UI.categoryRecords();
  SelfTest.eq('records: only sampled categories', rec.length, 2);
  SelfTest.eq('records: sorted by count desc', rec[0].id, 'email-reply');
  SelfTest.eq('records: median/best/count', [rec[0].median, rec[0].best, rec[0].count], [200, 100, 3]);
});
```

- [ ] **Step 2: Run selftest to verify it fails**

Run the selftest command. Expected: nonzero failed count (`UI.categoryRecords is not a function`).

- [ ] **Step 3: Implement renderHud, renderProgress, categoryRecords**

Replace the two stub lines inside `UI` (`renderHud() {},` and `renderProgress() {},`) with:

```js
  renderHud() {
    const p = Store.state.player;
    UI.el('hud-title').textContent = Rules.titleForLevel(p.level);
    UI.el('hud-lv').textContent = 'Lv ' + p.level;
    const lo = Rules.xpForLevel(p.level), hi = Rules.xpForLevel(p.level + 1);
    UI.el('hud-xpfill').style.width = Math.min(100, ((p.xp - lo) / (hi - lo)) * 100) + '%';
    UI.el('hud-stars').textContent = '★ ' + p.starsTotal;
    const pips = document.querySelectorAll('#hud-quests .pip');
    Store.state.quests.items.forEach((q, i) => { if (pips[i]) pips[i].classList.toggle('done', q.done); });
  },

  categoryRecords() {
    return Object.entries(Store.state.categories)
      .filter(([, c]) => c.samples.length > 0)
      .map(([id, c]) => ({ id, label: c.label, emoji: c.emoji,
        median: U.median(c.samples), best: Math.min(...c.samples), count: c.samples.length }))
      .sort((a, b) => b.count - a.count);
  },

  renderProgress() {
    const ql = UI.el('quest-list');
    ql.innerHTML = '';
    for (const q of Store.state.quests.items) {
      const row = document.createElement('div');
      row.className = 'prow';
      row.innerHTML = `<span>${q.done ? '✅' : '▢'} ${U.esc(q.label)}</span><b>${Math.min(q.progress, q.target)}/${q.target} · +${q.rewardXp}</b>`;
      ql.appendChild(row);
      const bar = document.createElement('div');
      bar.className = 'qbar';
      bar.innerHTML = `<i style="width:${Math.min(100, (q.progress / q.target) * 100)}%"></i>`;
      ql.appendChild(bar);
    }
    const sd = Store.state.player.showdown;
    UI.el('scoreboard').textContent = `YOU ${sd.you} - ${sd.ai} AI 🥊`;
    const rc = UI.el('records');
    rc.innerHTML = '';
    for (const r of UI.categoryRecords()) {
      const row = document.createElement('div');
      row.className = 'prow';
      row.innerHTML = `<span>${r.emoji} ${U.esc(r.label)}</span><b>~${U.mmss(r.median)} · best ${U.mmss(r.best)} · x${r.count}</b>`;
      rc.appendChild(row);
    }
    const hist = UI.el('history');
    hist.innerHTML = '';
    const finished = Store.state.tasks
      .filter(t => (t.state === 'done' || t.state === 'dropped') && t.finishedAt)
      .sort((a, b) => b.finishedAt - a.finishedAt)
      .slice(0, 60);
    let lastDay = '';
    for (const t of finished) {
      const day = Rules.dayKey(new Date(t.finishedAt));
      if (day !== lastDay) {
        lastDay = day;
        const h = document.createElement('div');
        h.className = 'hday'; h.textContent = day;
        hist.appendChild(h);
      }
      const row = document.createElement('div');
      row.className = 'prow';
      row.innerHTML = t.state === 'dropped'
        ? `<span>✕ ${U.esc(t.title)}</span><b>dropped</b>`
        : `<span>${t.stars > 0 ? '★'.repeat(t.stars) : '⏱'} ${U.esc(t.title)}</span><b>${U.mmss(t.actualSec)} / par ${U.mmss(t.parSec)} ${t.showdownWin ? '🥊' : ''}</b>`;
      hist.appendChild(row);
    }
  },
```

- [ ] **Step 4: Run selftest to verify it passes**

Run the selftest command. Expected: `SELFTEST: 74 passed, 0 failed`

- [ ] **Step 5: Manual check**

Open the file: finish two tasks, flip to Progress - quests show progress bars, scoreboard reflects showdown results, records show the category with median/best/count, history groups under today's date, HUD level bar and star count move.

- [ ] **Step 6: Commit**

```bash
cd "C:/Users/ntangs/Documents/Product-Madness" && git add "Product Madness v1.html" && git commit -m "feat: HUD and progress scene - quests, scoreboard, records, history

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: Sound, confetti, level-up ceremony, finish flavor

**Files:**
- Modify: `Product Madness v1.html` - replace the `Sfx` stub, fill `// ===== Fx =====`, replace `UI.onLevelUp` and `UI.finishFlavor` stubs, wire the level-up dialog button.

**Interfaces:**
- Consumes: `Store.state.settings.sound`, `UI.el`, `Rules.titleForLevel`.
- Produces: `Sfx.tick/ding/star(n)/womp/levelUp`, `Fx.burst(n)`, working `UI.onLevelUp(newLevel)`, `UI.finishFlavor(task) -> string`.

- [ ] **Step 1: Implement Sfx (replace the stub)**

```js
const Sfx = {
  ctx: null,
  on: () => Store.state && Store.state.settings.sound,
  beep(freq, dur = 0.1, type = 'triangle', gain = 0.04, when = 0) {
    if (!Sfx.on()) return;
    try {
      const c = Sfx.ctx || (Sfx.ctx = new (window.AudioContext || window.webkitAudioContext)());
      const o = c.createOscillator(), g = c.createGain();
      o.type = type; o.frequency.value = freq;
      o.connect(g); g.connect(c.destination);
      const t = c.currentTime + when;
      g.gain.setValueAtTime(gain, t);
      g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
      o.start(t); o.stop(t + dur + 0.02);
    } catch (e) { /* audio unavailable - stay silent */ }
  },
  tick() { Sfx.beep(880, 0.05, 'square', 0.02); },
  ding() { Sfx.beep(1046, 0.15); Sfx.beep(1318, 0.15, 'triangle', 0.04, 0.12); },
  star(n) { for (let i = 0; i < Math.max(1, n); i++) Sfx.beep(1046 + i * 262, 0.12, 'triangle', 0.05, i * 0.12); },
  womp() { Sfx.beep(196, 0.3, 'sawtooth', 0.03); Sfx.beep(147, 0.35, 'sawtooth', 0.03, 0.18); },
  levelUp() { [523, 659, 784, 1046, 1318].forEach((f, i) => Sfx.beep(f, 0.15, 'triangle', 0.05, i * 0.09)); },
};
```

- [ ] **Step 2: Implement Fx confetti**

Fill `// ===== Fx =====`:

```js
const Fx = {
  parts: [], running: false,
  burst(n = 90) {
    const cv = document.getElementById('fx');
    cv.width = innerWidth; cv.height = innerHeight;
    const colors = ['#F2708F', '#F49FBC', '#FFC9DB', '#FFF4E4', '#E9678C', '#FFDCE8'];
    for (let i = 0; i < n; i++) {
      Fx.parts.push({ x: cv.width / 2, y: cv.height / 2.4,
        vx: (Math.random() - 0.5) * 14, vy: -Math.random() * 13 - 3,
        s: 5 + Math.random() * 6, r: Math.random() * Math.PI,
        c: colors[i % colors.length], life: 90 + Math.random() * 40 });
    }
    if (!Fx.running) { Fx.running = true; Fx.loop(); }
  },
  loop() {
    const cv = document.getElementById('fx'), ctx = cv.getContext('2d');
    ctx.clearRect(0, 0, cv.width, cv.height);
    Fx.parts = Fx.parts.filter(p => p.life > 0);
    for (const p of Fx.parts) {
      p.x += p.vx; p.y += p.vy; p.vy += 0.35; p.r += 0.1; p.life--;
      ctx.save(); ctx.translate(p.x, p.y); ctx.rotate(p.r);
      ctx.fillStyle = p.c; ctx.fillRect(-p.s / 2, -p.s / 2, p.s, p.s * 0.6);
      ctx.restore();
    }
    if (Fx.parts.length) requestAnimationFrame(Fx.loop);
    else { Fx.running = false; ctx.clearRect(0, 0, cv.width, cv.height); }
  },
};
```

- [ ] **Step 3: Replace UI.onLevelUp and UI.finishFlavor; wire dialog and finish sounds**

Replace the `UI.onLevelUp` stub with:

```js
  onLevelUp(newLevel) {
    UI.el('levelup-title').textContent = 'Level ' + newLevel + '!';
    UI.el('levelup-sub').textContent = 'You are now: ' + Rules.titleForLevel(newLevel);
    UI.el('levelup').hidden = false;
    Fx.burst();
    Sfx.levelUp();
  },
```

Replace the `UI.finishFlavor` stub with:

```js
  finishFlavor(task) {
    if (task.quip && task.parSource === 'api') return '';
    const win = ['Called it. The kitchen fears you.', 'Chef things. Keep moving.', 'That ticket never stood a chance.'];
    const lose = ['The AI smirks quietly.', 'Par stands. Next order.', 'Recalibrating your legend...'];
    const pool = task.showdownWin ? win : lose;
    return pool[task.finishedAt % pool.length];
  },
```

In `UI.bind()`, add:

```js
    UI.el('levelup-ok').addEventListener('click', () => { UI.el('levelup').hidden = true; });
```

In `UI.finishTask`, directly after the line `const starTxt = ...`, add:

```js
    if (task.stars > 0) Sfx.star(task.stars); else Sfx.womp();
    if (task.stars === 3) Fx.burst(50);
```

- [ ] **Step 4: Run selftest to confirm nothing regressed**

Run the selftest command. Expected: `SELFTEST: 74 passed, 0 failed`

- [ ] **Step 5: Manual check**

Finish a task fast (short par via a category you have seeded low, or a quick real task): star chime plays, 3-star finish bursts confetti; force enough XP for a level-up (finish several tasks): level card shows with title and confetti; sound toggle in the drawer is respected once Task 9 wires it.

- [ ] **Step 6: Commit**

```bash
cd "C:/Users/ntangs/Documents/Product-Madness" && git add "Product Madness v1.html" && git commit -m "feat: sound synth, confetti, level-up ceremony, finish flavor

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: Claude API layer and Settings drawer

**Files:**
- Modify: `Product Madness v1.html` - fill `// ===== ApiClient =====`, extend `UI.revealPar` to try the API, wire the settings drawer; add a `SelfTest.suite` block above `// ===== Boot =====`.

**Interfaces:**
- Consumes: `Store.state.settings`, `U.median`, `UI.revealPar`.
- Produces:
  - `PM_PROFILE` string, `SYSTEM_PROMPT(cat) -> string`, `USER_PROMPT(title, historyLines) -> string`
  - `ApiClient.par(title, cat, historyLines, settings, dayKey, fetchFn = fetch) -> Promise<{seconds, quip} | null>`
  - `ApiClient.failStreak` counter, `ApiClient.cache`

- [ ] **Step 1: Write the failing tests**

```js
SelfTest.suite(async () => {
  const settings = { apiKey: 'k', apiEnabled: true, model: 'claude-haiku-4-5' };
  const cat = { label: 'Email reply', baselineSec: 180, samples: [120, 150] };
  const okFetch = async () => ({ ok: true, json: async () => ({ content: [{ type: 'text', text: 'Here: {"seconds":240,"quip":"Easy money."}' }] }) });
  ApiClient.cache = {}; ApiClient.failStreak = 0;
  const good = await ApiClient.par('reply to Bob', cat, [], settings, '2026-07-16', okFetch);
  SelfTest.eq('api: parses seconds and quip', [good.seconds, good.quip], [240, 'Easy money.']);
  const badRange = async () => ({ ok: true, json: async () => ({ content: [{ type: 'text', text: '{"seconds":99999,"quip":"x"}' }] }) });
  SelfTest.eq('api: out-of-range seconds rejected', await ApiClient.par('t2', cat, [], settings, '2026-07-16', badRange), null);
  const garbage = async () => ({ ok: true, json: async () => ({ content: [{ type: 'text', text: 'no json here' }] }) });
  SelfTest.eq('api: garbage rejected', await ApiClient.par('t3', cat, [], settings, '2026-07-16', garbage), null);
  const httpErr = async () => ({ ok: false, status: 401, json: async () => ({}) });
  SelfTest.eq('api: http error rejected', await ApiClient.par('t4', cat, [], settings, '2026-07-16', httpErr), null);
  SelfTest.eq('api: failStreak counted', ApiClient.failStreak, 3);
  const throwFetch = async () => { throw new Error('offline'); };
  const cached = await ApiClient.par('reply to Bob', cat, [], settings, '2026-07-16', throwFetch);
  SelfTest.eq('api: same-day cache hit skips fetch', cached.seconds, 240);
  SelfTest.ok('api: quip capped at 90 chars', (await (async () => { const long = async () => ({ ok: true, json: async () => ({ content: [{ type: 'text', text: `{"seconds":120,"quip":"${'x'.repeat(200)}"}` }] }) }); return ApiClient.par('t5', cat, [], settings, '2026-07-16', long); })()).quip.length === 90);
});
```

- [ ] **Step 2: Run selftest to verify it fails**

Run the selftest command. Expected: nonzero failed count (`ApiClient is not defined`).

- [ ] **Step 3: Implement ApiClient and prompts**

Fill `// ===== ApiClient =====`:

```js
const PM_PROFILE = 'The player is a senior product manager and business analyst at a healthcare technology company. Typical micro-tasks: replying to stakeholder emails and Teams messages, writing and grooming Jira tickets, editing HTML wireframes and mockups, cleaning up meeting notes, prepping agendas, and quick data checks in reports. They work fast and take pride in accurate estimates.';

function SYSTEM_PROMPT(cat) {
  const med = cat.samples.length ? U.median(cat.samples.slice(-5)) + 's' : 'n/a';
  return `You estimate how long the player's next micro-task will take, in seconds. You are their playful arcade rival: confident, teasing, never mean. ${PM_PROFILE}\nCategory "${cat.label}": baseline ${cat.baselineSec}s, ${cat.samples.length} recorded samples, recent median ${med}.\nRespond with ONLY a JSON object, no other text: {"seconds": <integer between 30 and 1200>, "quip": "<max 90 characters of playful trash talk about this estimate>"}`;
}

function USER_PROMPT(title, historyLines) {
  return `Task: "${title}"\nRecent similar tasks (actual times):\n${historyLines.length ? historyLines.join('\n') : '(none yet)'}`;
}

const ApiClient = {
  cache: {},
  failStreak: 0,
  async par(title, cat, historyLines, settings, dayKey, fetchFn = fetch) {
    const ck = dayKey + '|' + title.toLowerCase();
    if (ApiClient.cache[ck]) return ApiClient.cache[ck];
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 3500);
    try {
      const res = await fetchFn('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        signal: ctrl.signal,
        headers: {
          'x-api-key': settings.apiKey,
          'anthropic-version': '2023-06-01',
          'content-type': 'application/json',
          'anthropic-dangerous-direct-browser-access': 'true',
        },
        body: JSON.stringify({
          model: settings.model, max_tokens: 150,
          system: SYSTEM_PROMPT(cat),
          messages: [{ role: 'user', content: USER_PROMPT(title, historyLines) }],
        }),
      });
      if (!res.ok) throw new Error('http ' + res.status);
      const data = await res.json();
      const text = (data.content || []).map(b => b.text || '').join('');
      const m = text.match(/\{[\s\S]*\}/);
      if (!m) throw new Error('no json');
      const obj = JSON.parse(m[0]);
      const seconds = Math.round(obj.seconds);
      if (!Number.isFinite(seconds) || seconds < 30 || seconds > 1200) throw new Error('bad seconds');
      const out = { seconds, quip: String(obj.quip || '').slice(0, 90) };
      ApiClient.failStreak = 0;
      ApiClient.cache[ck] = out;
      return out;
    } catch (e) {
      ApiClient.failStreak++;
      return null;
    } finally {
      clearTimeout(timer);
    }
  },
};
```

- [ ] **Step 4: Wire the API into par reveal and build the Settings drawer**

Replace `UI.revealPar` with:

```js
  async revealPar(task) {
    const cat = Store.state.categories[task.category];
    task.parSec = Estimator.localPar(cat);
    task.parSource = 'local';
    task.quip = '';
    const s = Store.state.settings;
    if (s.apiEnabled && s.apiKey) {
      UI.el('ready-par').textContent = '…';
      const historyLines = Store.state.tasks
        .filter(t => t.state === 'done' && t.category === task.category)
        .slice(-10)
        .map(t => `${t.title} - ${U.mmss(t.actualSec)}`);
      const api = await ApiClient.par(task.title, cat, historyLines, s, Rules.dayKey(new Date()));
      if (api && task.state === 'queued') { task.parSec = api.seconds; task.parSource = 'api'; task.quip = api.quip; }
      else if (!api && ApiClient.failStreak >= 3) UI.toast('Claude is napping - local pars for now');
    }
    UI.el('ready-title').textContent = task.title;
    UI.el('ready-par').textContent = U.mmss(task.parSec);
    UI.el('ready-par-src').textContent = task.parSource === 'api' ? 'Claude' : 'local';
    UI.el('ready-call').textContent = U.mmss(task.myCallSec);
    UI.el('ready-quip').textContent = task.quip;
  },
```

Add to `UI.bind()`:

```js
    UI.el('settings-open').addEventListener('click', () => {
      const s = Store.state.settings;
      UI.el('set-sound').checked = s.sound;
      UI.el('set-api-enabled').checked = s.apiEnabled;
      UI.el('set-api-key').value = s.apiKey;
      UI.el('set-model').value = s.model;
      UI.el('settings-drawer').hidden = false;
    });
    UI.el('settings-close').addEventListener('click', () => { UI.el('settings-drawer').hidden = true; });
    UI.el('set-sound').addEventListener('change', e => { Store.state.settings.sound = e.target.checked; Store.save(); });
    UI.el('set-api-enabled').addEventListener('change', e => { Store.state.settings.apiEnabled = e.target.checked; Store.save(); });
    UI.el('set-api-key').addEventListener('change', e => { Store.state.settings.apiKey = e.target.value.trim(); Store.save(); });
    UI.el('set-model').addEventListener('change', e => { Store.state.settings.model = e.target.value; Store.save(); });
    UI.el('btn-export').addEventListener('click', () => {
      const a = document.createElement('a');
      a.href = URL.createObjectURL(new Blob([Store.exportJson()], { type: 'application/json' }));
      const d = new Date();
      a.download = `product-madness-export-${d.getFullYear()}${U.pad2(d.getMonth() + 1)}${U.pad2(d.getDate())}.json`;
      a.click();
      Store.state.settings.lastExportAt = UI.now(); Store.save();
      UI.toast('⬇ exported');
    });
    UI.el('file-import').addEventListener('change', async e => {
      const file = e.target.files[0];
      if (!file) return;
      const ok = Store.importJson(await file.text());
      UI.toast(ok ? '⬆ imported' : 'import failed - file rejected');
      if (ok) { UI.el('settings-drawer').hidden = true; UI.renderAll(); }
      e.target.value = '';
    });
    UI.el('btn-reset').addEventListener('click', () => {
      if (!confirm('Reset ALL Product Madness data?')) return;
      if (!confirm('Really? Levels, history, records - everything?')) return;
      Store.state = Store.defaults(new Date());
      Store.save();
      UI.el('settings-drawer').hidden = true;
      UI.flow = { stage: 'idle', taskId: null };
      UI.renderAll();
      UI.toast('fresh kitchen');
    });
```

- [ ] **Step 5: Category editor in the drawer (spec 4.2 - categories editable in-app)**

In the settings-open handler added in Step 4, after `UI.el('settings-drawer').hidden = false;`, add `UI.renderCatEditor();`. Then add this method to `UI`:

```js
  renderCatEditor() {
    const box = UI.el('cat-editor');
    box.innerHTML = '';
    for (const [id, c] of Object.entries(Store.state.categories)) {
      const row = document.createElement('div');
      row.className = 'prow';
      row.style.flexWrap = 'wrap';
      row.innerHTML = `<b>${c.emoji}</b>
        <input data-f="label" value="${U.esc(c.label)}" style="width:34%">
        <input data-f="baselineSec" type="number" min="30" max="1200" value="${c.baselineSec}" style="width:18%" title="baseline seconds">
        <input data-f="keywords" value="${U.esc(c.keywords.join(', '))}" style="width:100%;margin-top:4px" placeholder="keywords, comma separated">
        <label style="display:flex;flex-direction:row;gap:4px;font-size:11px;align-items:center">archived <input data-f="archived" type="checkbox" ${c.archived ? 'checked' : ''}></label>`;
      row.querySelectorAll('input').forEach(inp => inp.addEventListener('change', () => {
        const f = inp.dataset.f;
        if (f === 'label') c.label = inp.value.trim() || c.label;
        if (f === 'baselineSec') c.baselineSec = U.clamp(Number(inp.value) || c.baselineSec, 30, 1200);
        if (f === 'keywords') c.keywords = inp.value.split(',').map(s => s.trim().toLowerCase()).filter(Boolean);
        if (f === 'archived') c.archived = inp.checked;
        Store.save();
      }));
      box.appendChild(row);
    }
    const add = document.createElement('button');
    add.className = 'btn-minor';
    add.textContent = '+ add category';
    add.addEventListener('click', () => {
      const label = prompt('Category name?');
      if (!label) return;
      const id = label.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '') || 'cat-' + Date.now();
      if (Store.state.categories[id]) { UI.toast('that category exists'); return; }
      Store.state.categories[id] = { label, emoji: '🍓', keywords: [], baselineSec: 180, samples: [], archived: false };
      Store.save();
      UI.renderCatEditor();
    });
    box.appendChild(add);
  },
```

Note: archiving a category only removes it from keyword detection (`Estimator.detectCategory` skips archived); the `other` fallback keeps working because the fallback return does not check archived.

- [ ] **Step 6: Run selftest to verify it passes**

Run the selftest command. Expected: `SELFTEST: 81 passed, 0 failed`

- [ ] **Step 7: Manual check**

Open Settings from Progress: toggle sound off (no more blips), paste a real API key and enable - next par reveal shows "…" then a Claude badge and a quip; wrong key falls back to local silently and after 3 tries shows the napping toast; export downloads JSON without the key; import restores; reset requires two confirms. In the category editor: rename a category, change a baseline, add a keyword, add a new category, archive one - each survives a reload.

- [ ] **Step 8: Commit**

```bash
cd "C:/Users/ntangs/Documents/Product-Madness" && git add "Product Madness v1.html" && git commit -m "feat: Claude API estimator layer and settings drawer

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 10: Resilience - quota toast, restore polish, rollover live-check

**Files:**
- Modify: `Product Madness v1.html` - small edits inside `UI` and `Store` call sites.

**Interfaces:**
- Consumes: `Store.save()` boolean, `UI.banner`, `UI.toast`.
- Produces: no new APIs; behavior hardening only.

- [ ] **Step 1: Surface save failures**

In `UI.finishTask`, change the line `Store.save();` (the one after `p.level = Rules.levelForXp(p.xp);`) to:

```js
    if (!Store.save()) UI.toast('⚠ storage full - export your data from settings');
```

- [ ] **Step 2: Guard the timer against a finished flow**

At the top of `UI.finishTask`, add a re-entry guard as the first line:

```js
    if (task.state !== 'running' && task.state !== 'paused') return;
```

- [ ] **Step 3: Run selftest to confirm nothing regressed**

Run the selftest command. Expected: `SELFTEST: 81 passed, 0 failed`

- [ ] **Step 4: Manual check**

Start a task, close the window, reopen: restore banner appears; "Keep racing" resumes with elapsed time counted truthfully; "Drop it" discards. Double-click DONE rapidly: XP is granted once.

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/ntangs/Documents/Product-Madness" && git add "Product Madness v1.html" && git commit -m "fix: save-failure toast, double-finish guard

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 11: Launcher, acceptance checklist, ship

**Files:**
- Create: `Product Madness.bat`
- Create: `README.md`

- [ ] **Step 1: Create the launcher**

`Product Madness.bat`:

```bat
@echo off
set EDGE="C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
if not exist %EDGE% set EDGE="C:\Program Files\Microsoft\Edge\Application\msedge.exe"
start "" %EDGE% --app="file:///C:/Users/ntangs/Documents/Product-Madness/Product%20Madness%20v1.html" --window-size=430,720
```

- [ ] **Step 2: Create README.md**

```markdown
# Product Madness

A personal arcade game for micro-tasks. Log a task, lock your call, race the AI's par.

- Play: double-click `Product Madness.bat` (opens a chromeless game window), or open `Product Madness v1.html` in any browser.
- Data lives in this browser's localStorage. Back up via Settings > Export.
- Optional: paste an Anthropic API key in Settings for Claude-powered pars and trash talk. Keep member names and PHI out of task titles.
- Self-test: open the file with `?selftest` appended to the URL.
- Spec: `docs/superpowers/specs/2026-07-16-product-madness-design.md`
```

- [ ] **Step 3: Run the full acceptance checklist (spec 5.7)**

Work through all 14 items in spec section 5.7 manually, in the app window launched from the .bat. Fix anything that fails before proceeding (each fix follows the usual cycle: adjust, re-run selftest, re-check).

- [ ] **Step 4: Final selftest**

Run the selftest command. Expected: `SELFTEST: 81 passed, 0 failed`

- [ ] **Step 5: Commit**

```bash
cd "C:/Users/ntangs/Documents/Product-Madness" && git add "Product Madness.bat" README.md && git commit -m "feat: launcher and readme - v1 ships

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```
