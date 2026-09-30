import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

void main() => runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const DiceScreen(),
    ));

class DiceScreen extends StatelessWidget {
  const DiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14501A),
      body: SafeArea(
        bottom: false, // app bar sits right under the status bar
        child: ModelViewer(
          id: 'dice',
          src: 'assets/dice.glb',
          // transparent = no dark square around the dice
          backgroundColor: Colors.transparent,
          ar: false,
          autoRotate: false,
          cameraControls: false,
          disableZoom: true,
          disablePan: true,
          disableTap: true,
          interactionPrompt: InteractionPrompt.none,
          // fixed aerial (top-down) camera
          cameraOrbit: '0deg 6deg auto',
          minCameraOrbit: 'auto 0deg auto',
          maxCameraOrbit: 'auto 180deg auto',
          debugLogging: false,
          relatedCss: _css,
          relatedJs: _js,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// UI + physics + animation run INSIDE the web view (Flutter stays idle = no lag).
// ---------------------------------------------------------------------------

const String _css = r'''
html, body {
  height: 100%; margin: 0; overflow: hidden; touch-action: none;
  -webkit-tap-highlight-color: transparent; user-select: none;
  background: radial-gradient(circle at 50% 50%, #2e7d32 0%, #1b5e20 55%, #0a2e10 100%) !important;
  font-family: sans-serif;
}
.die {
  position: fixed !important; top: 50%;
  z-index: 2; pointer-events: none;
  background: transparent !important; background-color: transparent !important;
  --poster-color: transparent;
  will-change: transform; transform-origin: 50% 50%;
}
.shadow {
  position: fixed; left: 50%; top: 50%; z-index: 1; border-radius: 50%; pointer-events: none;
  background: radial-gradient(circle at center, rgba(0,0,0,.8) 0%, rgba(0,0,0,0) 70%);
}
#label {
  position: fixed; left: 0; right: 0; top: 66px; z-index: 3; text-align: center;
  color: #fff; font-size: 20px; pointer-events: none;
}
/* ---- app bar ---- */
#bar {
  position: fixed; top: 0; left: 0; right: 0; height: 56px; z-index: 10;
  display: flex; align-items: center; padding: 0 6px 0 18px; box-sizing: border-box;
  background: #14501a; color: #fff; box-shadow: 0 2px 8px rgba(0,0,0,.4);
}
#bar .title { font-size: 21px; font-weight: 600; flex: 1; }
#bar button {
  width: 44px; height: 44px; border: 0; border-radius: 22px; background: transparent;
  display: flex; align-items: center; justify-content: center; cursor: pointer;
}
#bar button:active { background: rgba(255,255,255,.18); }
/* ---- history panel ---- */
#panel {
  position: fixed; top: 60px; right: 8px; width: min(88vw, 330px); max-height: 60vh; z-index: 11;
  display: none; flex-direction: column; overflow: hidden;
  background: rgba(8,38,13,.97); color: #fff; border-radius: 16px;
  box-shadow: 0 8px 28px rgba(0,0,0,.55);
}
#panel .ph {
  display: flex; align-items: center; justify-content: space-between;
  padding: 12px 16px; font-size: 17px; font-weight: 600; border-bottom: 1px solid rgba(255,255,255,.15);
}
#panel .ph button, .btn {
  border: 0; border-radius: 16px; padding: 7px 16px; font-size: 14px; cursor: pointer;
  background: rgba(255,255,255,.16); color: #fff;
}
#plist { overflow-y: auto; padding: 4px 0; touch-action: pan-y; }
#plist .row {
  display: flex; justify-content: space-between; padding: 11px 16px; font-size: 17px;
  border-bottom: 1px solid rgba(255,255,255,.08);
}
#plist .row .n { opacity: .6; }
#plist .empty { padding: 22px 16px; opacity: .7; text-align: center; font-size: 15px; }
/* ---- calibration wizard ---- */
#wiz {
  position: fixed; left: 10px; right: 10px; bottom: 14px; z-index: 12; display: none;
  background: rgba(8,38,13,.97); color: #fff; border-radius: 18px; padding: 16px;
  text-align: center; font-size: 17px; box-shadow: 0 8px 28px rgba(0,0,0,.55);
}
#wbtns { display: grid; grid-template-columns: repeat(6, 1fr); gap: 8px; margin-top: 12px; }
#wbtns button {
  height: 48px; border: 0; border-radius: 12px; font-size: 20px; font-weight: 700;
  background: #2e7d32; color: #fff; cursor: pointer;
}
#wbtns button:active { background: #43a047; }
#wta {
  display: none; width: 100%; box-sizing: border-box; margin-top: 10px; height: 70px;
  font-size: 13px; background: #041a08; color: #b9f6ca; border: 0; border-radius: 10px;
  padding: 8px; user-select: text; -webkit-user-select: text;
}
#wact { display: none; margin-top: 10px; gap: 10px; justify-content: center; }
''';

const String _js = r'''
(function () {
  // ================== TWEAK THESE ==================
  var DICE = 2;          // number of dice (2 recommended)
  var ELEM = 1.0;        // size of each 3D canvas vs screen width
  var NEAR = 0.84;       // dice size when high up, close to the camera
  var GROUND = 0.21;     // dice size on the ground (smaller = farther away)
  var DICE_HALF = 0.22;  // half width of dice vs screen width at scale 1 (fixes contact size)
  var BAR = 56;          // app bar height (px)
  var WALL = 6;          // invisible wall margin (px)
  var START_Z = 0.8;     // height the dice are thrown from (1 = closest to camera)
  var G = 7;             // gravity (lower = floatier, longer fall)
  var EZ = 0.5;          // ground bounce (0..1)
  var EW = 0.6;          // wall bounce (0..1)
  var EC = 0.75;         // dice-vs-dice bounce (0..1)
  var FRICTION = 1500;   // ground friction (px/s^2)
  var DRAG = 0.55;       // air drag
  var SPIN = 0.8;        // tumble per pixel travelled
  var TIMESCALE = 1;     // 0.5 = slow motion
  var MAX_HISTORY = 50;  // how many past rolls to keep

  // [roll, pitch] in degrees that puts each number on TOP.
  // Run the calibration wizard (sliders icon in the app bar) and paste its result here.
  var FACES = { 1:[0,0], 2:[0,90], 3:[90,0], 4:[-90,0], 5:[0,-90], 6:[0,180] };
  // =================================================

  var BASE = [[0,0],[0,90],[90,0],[-90,0],[0,-90],[0,180]]; // six orientations used by the wizard
  var ICON_HIST = '<svg viewBox="0 0 24 24" width="26" height="26" fill="#fff"><path d="M13 3a9 9 0 0 0-9 9H1l3.89 3.89.07.14L9 12H6c0-3.87 3.13-7 7-7s7 3.13 7 7-3.13 7-7 7c-1.93 0-3.68-.79-4.94-2.06l-1.42 1.42A8.954 8.954 0 0 0 13 21a9 9 0 0 0 0-18zm-1 5v5l4.28 2.54.72-1.21-3.5-2.08V8H12z"/></svg>';
  var ICON_TUNE = '<svg viewBox="0 0 24 24" width="24" height="24" fill="#fff"><path d="M3 17v2h6v-2H3zM3 5v2h10V5H3zm10 16v-2h8v-2h-8v-2h-2v6h2zM7 9v2H3v2h4v2h2V9H7zm14 4v-2H11v2h10zm-6-4h2V7h4V5h-4V3h-2v6z"/></svg>';

  var DT = 1 / 240, NMAX = 240 * 9;
  var dice = [], act = [], history = [], rollNo = 0;
  var first, label, bar, panel, wizEl, rolling = false, panelOpen = false, wiz = null, wd = null, W, H;

  function $(id) { return document.getElementById(id); }
  function mk(tag, id, html) {
    var e = document.createElement(tag); if (id) e.id = id; if (html !== undefined) e.innerHTML = html; return e;
  }
  function rad(z) { return W * DICE_HALF * ELEM * (GROUND + z * (NEAR - GROUND)); }
  function bounds() {
    return { L: WALL - W / 2, R: W - WALL - W / 2, T: BAR + WALL - H / 2, B: H - WALL - H / 2 };
  }
  function rnd(n) { return 1 + Math.floor(Math.random() * n); }
  function corr(v) { return v - Math.round(v / 360) * 360; }
  function say(t) { if (label) label.textContent = t; }

  // ---------------------------------------------------------------- physics
  function simulate(bs) {
    var bd = bounds(), L = bd.L, R = bd.R, T = bd.T, B = bd.B;
    var m = bs.length, o = [], k, i, p, q;
    for (k = 0; k < m; k++)
      o.push({ X: [], Y: [], Z: [], AR: [], AP: [], AY: [], PL: [], ar: 0, ap: 0, ay: 0, path: 0 });

    for (i = 0; i < NMAX; i++) {
      for (k = 0; k < m; k++) {
        var c = bs[k], a = o[k];
        c.vz -= G * DT; c.z += c.vz * DT;
        if (c.z <= 0) {
          c.z = 0;
          if (Math.abs(c.vz) > 0.35) {
            c.vz = Math.abs(c.vz) * EZ; c.vx *= 0.8; c.vy *= 0.8;
            a.ay += (Math.random() - 0.5) * 160; a.ap += (Math.random() - 0.5) * 60;
          } else { c.vz = 0; }
        }
        var s0 = Math.sqrt(c.vx * c.vx + c.vy * c.vy);
        if (c.z > 0) { var d = Math.pow(DRAG, DT); c.vx *= d; c.vy *= d; }
        else if (s0 > 0) { var f = Math.max(0, s0 - FRICTION * DT) / s0; c.vx *= f; c.vy *= f; }

        c.x += c.vx * DT; c.y += c.vy * DT;

        var r = rad(c.z);
        if (c.x < L + r) { c.x = L + r; if (c.vx < 0) { c.vx = -c.vx * EW; a.ay += c.vy * 0.05; } }
        if (c.x > R - r) { c.x = R - r; if (c.vx > 0) { c.vx = -c.vx * EW; a.ay -= c.vy * 0.05; } }
        if (c.y < T + r) { c.y = T + r; if (c.vy < 0) { c.vy = -c.vy * EW; a.ay += c.vx * 0.05; } }
        if (c.y > B - r) { c.y = B - r; if (c.vy > 0) { c.vy = -c.vy * EW; a.ay -= c.vx * 0.05; } }

        a.ar += c.vx * DT * SPIN; a.ap += c.vy * DT * SPIN;
      }

      for (p = 0; p < m; p++) for (q = p + 1; q < m; q++) {
        var A = bs[p], Bd = bs[q];
        if (Math.abs(A.z - Bd.z) > 0.3) continue;
        var dx = Bd.x - A.x, dy = Bd.y - A.y, dist = Math.sqrt(dx * dx + dy * dy);
        var minD = rad(A.z) + rad(Bd.z);
        if (dist < minD && dist > 0.001) {
          var nx = dx / dist, ny = dy / dist, ov = minD - dist;
          A.x -= nx * ov / 2; A.y -= ny * ov / 2; Bd.x += nx * ov / 2; Bd.y += ny * ov / 2;
          var rvn = (Bd.vx - A.vx) * nx + (Bd.vy - A.vy) * ny;
          if (rvn < 0) {
            var j = -(1 + EC) * rvn / 2;
            A.vx -= j * nx; A.vy -= j * ny; Bd.vx += j * nx; Bd.vy += j * ny;
            o[p].ay += (Math.random() - 0.5) * 140; o[q].ay += (Math.random() - 0.5) * 140;
          }
        }
      }

      var allRest = true;
      for (k = 0; k < m; k++) {
        var cc = bs[k], oo = o[k], sp2 = Math.sqrt(cc.vx * cc.vx + cc.vy * cc.vy);
        oo.path += sp2 * DT + Math.abs(cc.vz) * DT * 300;
        oo.X.push(cc.x); oo.Y.push(cc.y); oo.Z.push(cc.z);
        oo.AR.push(oo.ar); oo.AP.push(oo.ap); oo.AY.push(oo.ay); oo.PL.push(oo.path);
        if (!(cc.z === 0 && sp2 < 8)) allRest = false;
      }
      if (allRest && i > 30) break;
    }

    for (k = 0; k < m; k++) {
      var zz = o[k], total = zz.PL[zz.PL.length - 1] || 1;
      for (i = 0; i < zz.PL.length; i++) zz.PL[i] /= total;
      zz.cr = corr(zz.ar); zz.cp = corr(zz.ap); zz.cy = corr(zz.ay);
    }
    return o;
  }

  // -------------------------------------------------------------- rendering
  function place(d, x, y, z) {
    d.x = x; d.y = y;
    var s = GROUND + z * (NEAR - GROUND);
    d.el.style.transform = 'translate3d(' + x + 'px,' + y + 'px,0) scale(' + s + ')';
    d.sh.style.transform = 'translate(' + (x + z * 35) + 'px,' + (y + z * 50 + 3) +
      'px) translate(-50%,-50%) scale(' + (s / GROUND) + ')';
    d.sh.style.opacity = (0.1 + 0.5 * (1 - Math.min(z, 1))).toFixed(3);
  }

  function setOri(d, r, p, y) {
    try {
      d.el.orientation = r.toFixed(1) + 'deg ' + p.toFixed(1) + 'deg ' + y.toFixed(1) + 'deg';
    } catch (e) { /* a dice that is not ready must never stop the animation */ }
  }

  // ---------------------------------------------------------------- history
  function renderHistory() {
    var list = $('plist');
    if (!history.length) {
      list.innerHTML = '<div class="empty">No rolls yet - tap the table to throw the dice!</div>';
      return;
    }
    list.innerHTML = history.map(function (h) {
      var txt = h.vals.length > 1 ? h.vals.join(' + ') + ' = <b>' + h.sum + '</b>' : '<b>' + h.sum + '</b>';
      return '<div class="row"><span class="n">#' + h.no + '</span><span>' + txt + '</span></div>';
    }).join('');
  }
  function openPanel() { renderHistory(); panel.style.display = 'flex'; panelOpen = true; }
  function closePanel() { panel.style.display = 'none'; panelOpen = false; }

  // ------------------------------------------------------------------ throw
  function throwDice(bs) {
    rolling = true;
    say('Rolling...');
    var k, vals = [], yaws = [];
    for (k = 0; k < act.length; k++) { vals.push(rnd(6)); yaws.push(Math.random() * 360); }
    var sims = simulate(bs), n = sims[0].X.length, t0 = null;

    function frame(now) {
      if (t0 === null) t0 = now;
      var simT = (now - t0) / 1000 * TIMESCALE;
      var i = Math.min(Math.floor(simT / DT), n - 1);
      for (var k = 0; k < act.length; k++) {
        var s = sims[k], p = s.PL[i], f = FACES[vals[k]];
        place(act[k], s.X[i], s.Y[i], s.Z[i]);
        setOri(act[k], f[0] + s.AR[i] - s.cr * p, f[1] + s.AP[i] - s.cp * p, yaws[k] + s.AY[i] - s.cy * p);
      }
      if (i < n - 1) {
        requestAnimationFrame(frame);
      } else {
        var sum = 0;
        for (var j = 0; j < act.length; j++) {
          var ff = FACES[vals[j]];
          setOri(act[j], ff[0], ff[1], yaws[j]);
          sum += vals[j];
        }
        rolling = false;
        rollNo++;
        history.unshift({ no: rollNo, vals: vals.slice(), sum: sum });
        if (history.length > MAX_HISTORY) history.pop();
        if (panelOpen) renderHistory();
        say(act.length > 1
          ? 'You rolled ' + vals.join(' + ') + ' = ' + sum + '  |  tap to throw again'
          : 'You rolled a ' + sum + '  |  tap to throw again');
      }
    }
    requestAnimationFrame(frame);
  }

  function autoThrow() {
    var b = bounds(), r0 = rad(START_Z), span = b.R - b.L - 2 * r0, base = Math.random() * span, bs = [];
    for (var k = 0; k < act.length; k++) {
      var a = (Math.random() * 100 - 50) * Math.PI / 180, sp = 1300 + Math.random() * 1700;
      bs.push({
        x: b.L + r0 + ((base + k * span / act.length) % span),
        y: b.B - r0 - 20, z: START_Z,
        vx: sp * Math.sin(a), vy: -sp * Math.cos(a), vz: 0.9 + Math.random() * 1.3
      });
    }
    throwDice(bs);
  }

  function onDown(e) {
    var t = e.target;
    if (t && t.closest && t.closest('#bar, #panel, #wiz')) return; // taps on the UI
    if (panelOpen) { closePanel(); return; }
    if (wiz || rolling) return;
    W = window.innerWidth; H = window.innerHeight;
    act = dice.filter(function (d) { return d.ok && d.ready; });
    if (!act.length) { say('Loading dice...'); return; }
    try { autoThrow(); }
    catch (err) { rolling = false; say('ERROR: ' + err.message); }
  }

  // ------------------------------------------------------ calibration wizard
  function wizShow(msg) {
    var b = BASE[wiz.i], bd = bounds();
    setOri(wd, b[0], b[1], 0);
    place(wd, 0, (bd.T + bd.B) / 2 - 60, 0.55);
    $('wtxt').innerHTML = (msg || '') + '<b>Step ' + (wiz.i + 1) + ' of 6</b><br>' +
      'Which number is on the <b>TOP</b> of the dice (the face pointing at you)?';
  }

  function restoreDice() {
    dice.forEach(function (d) {
      d.el.style.visibility = 'visible'; d.sh.style.visibility = 'visible';
      var s = restSpot(d); place(d, s.x, s.y, 0);
      if (d.ready) { var f = FACES[rnd(6)]; setOri(d, f[0], f[1], Math.random() * 360); }
    });
  }

  function startWizard() {
    if (rolling || wiz) return;
    W = window.innerWidth; H = window.innerHeight;
    var ready = dice.filter(function (d) { return d.ok && d.ready; });
    if (!ready.length) { say('Loading dice...'); return; }
    closePanel();
    wd = ready[0];
    dice.forEach(function (d) { d.el.style.visibility = 'hidden'; d.sh.style.visibility = 'hidden'; });
    wd.el.style.visibility = 'visible'; wd.sh.style.visibility = 'visible';
    wiz = { i: 0, ans: [] };
    $('wbtns').style.display = 'grid';
    $('wta').style.display = 'none'; $('wact').style.display = 'none';
    wizEl.style.display = 'block';
    say('');
    wizShow('');
  }

  function wizAnswer(n) {
    if (!wiz || wiz.done) return;
    wiz.ans.push(n); wiz.i++;
    if (wiz.i < 6) { wizShow(''); return; }

    var seen = {}, ok = true;
    wiz.ans.forEach(function (a) { if (seen[a]) ok = false; seen[a] = 1; });
    if (!ok) {
      wiz.i = 0; wiz.ans = [];
      wizShow('<span style="color:#ffab91">Two answers were the same - let\'s try again.</span><br>');
      return;
    }
    var nf = {};
    for (var j = 0; j < 6; j++) nf[wiz.ans[j]] = BASE[j];
    FACES = nf;
    var line = 'var FACES = { ' + [1, 2, 3, 4, 5, 6].map(function (n) {
      return n + ':[' + FACES[n][0] + ',' + FACES[n][1] + ']';
    }).join(', ') + ' };';

    wiz.done = true;
    $('wbtns').style.display = 'none';
    $('wtxt').innerHTML = '<b>Done!</b> The numbers now match the top face.<br>' +
      '<span style="font-size:14px;opacity:.85">To keep this after restarting the app, replace the FACES line in the code with:</span>';
    var ta = $('wta'); ta.value = line; ta.style.display = 'block';
    $('wact').style.display = 'flex';
  }

  function wizClose() {
    wizEl.style.display = 'none';
    wiz = null; wd = null;
    restoreDice();
    statusText();
  }

  function copyLine() {
    var ta = $('wta');
    ta.select();
    try {
      if (navigator.clipboard) navigator.clipboard.writeText(ta.value);
      else document.execCommand('copy');
    } catch (e) { try { document.execCommand('copy'); } catch (e2) { /* select-only fallback */ } }
    $('copyBtn').textContent = 'Copied!';
  }

  // ---------------------------------------------------------------- set up
  function whenLoaded(e, cb) {
    if (e.loaded) cb(); else e.addEventListener('load', cb, { once: true });
  }

  function restSpot(self) {
    var b = bounds(), r = rad(0), x, y, t = 0;
    do {
      x = b.L + r + Math.random() * (b.R - b.L - 2 * r);
      y = b.T + r + Math.random() * (b.B - b.T - 2 * r);
      t++;
    } while (t < 30 && dice.some(function (q) {
      return q !== self && q.x !== undefined && Math.hypot(q.x - x, q.y - y) < r * 2.4;
    }));
    return { x: x, y: y };
  }

  function statusText() {
    if (wiz) return;
    var loadedCount = dice.filter(function (d) { return d.ready; }).length;
    var alive = dice.filter(function (d) { return d.ok; }).length;
    say(loadedCount < alive ? 'Loading dice ' + loadedCount + '/' + alive + '...' : 'Tap to throw the dice');
  }

  function addDie(e) {
    e.classList.add('die');
    e.setAttribute('loading', 'eager');
    e.style.setProperty('width', (ELEM * 100) + 'vw', 'important');
    e.style.setProperty('height', (ELEM * 100) + 'vw', 'important');
    e.style.setProperty('left', (-(ELEM - 1) * 50) + 'vw', 'important');
    e.style.setProperty('margin-top', (-ELEM * 50) + 'vw', 'important');

    var sh = mk('div'); sh.className = 'shadow';
    var sw = W * DICE_HALF * ELEM * 2 * GROUND * 1.15;
    sh.style.width = sw + 'px'; sh.style.height = sw + 'px';
    document.body.appendChild(sh);

    var d = { el: e, sh: sh, ok: true, ready: false };
    dice.push(d);
    var spot = restSpot(d);
    place(d, spot.x, spot.y, 0);

    whenLoaded(e, function () {
      var f = FACES[rnd(6)];
      d.ready = true;
      setOri(d, f[0], f[1], Math.random() * 360);
      statusText();
    });
    return d;
  }

  function fail(d) {
    if (!d.ok || d.ready) return;
    d.ok = false;
    d.el.style.display = 'none';
    d.sh.style.display = 'none';
    say('One dice could not load - continuing with the others');
  }

  function buildUI() {
    label = mk('div', 'label', 'Loading dice...');
    document.body.appendChild(label);

    bar = mk('div', 'bar',
      '<div class="title">Dice Roll</div>' +
      '<button id="calBtn" title="Calibrate faces">' + ICON_TUNE + '</button>' +
      '<button id="histBtn" title="Roll history">' + ICON_HIST + '</button>');
    document.body.appendChild(bar);

    panel = mk('div', 'panel',
      '<div class="ph"><span>Roll history</span><button id="clrBtn">Clear</button></div><div id="plist"></div>');
    document.body.appendChild(panel);

    wizEl = mk('div', 'wiz',
      '<div id="wtxt"></div><div id="wbtns"></div><textarea id="wta" readonly></textarea>' +
      '<div id="wact"><button class="btn" id="copyBtn">Copy</button>' +
      '<button class="btn" id="doneBtn" style="background:#2e7d32">Done</button></div>');
    document.body.appendChild(wizEl);

    var wb = $('wbtns');
    for (var n = 1; n <= 6; n++) {
      var b = mk('button', null, String(n));
      b.setAttribute('data-n', n);
      b.addEventListener('click', function () { wizAnswer(parseInt(this.getAttribute('data-n'), 10)); });
      wb.appendChild(b);
    }

    $('histBtn').addEventListener('click', function () { panelOpen ? closePanel() : openPanel(); });
    $('clrBtn').addEventListener('click', function () { history = []; rollNo = 0; renderHistory(); });
    $('calBtn').addEventListener('click', startWizard);
    $('copyBtn').addEventListener('click', copyLine);
    $('doneBtn').addEventListener('click', wizClose);
  }

  function start() {
    first = document.getElementById('dice');
    if (!first) { setTimeout(start, 50); return; }
    W = window.innerWidth; H = window.innerHeight;

    buildUI();
    window.onerror = function (m, u, l) { say('JS ERROR: ' + m + ' (line ' + l + ')'); };

    addDie(first);

    // create the extra dice only AFTER the first one has fully loaded
    whenLoaded(first, function () {
      for (var k = 1; k < DICE; k++) {
        var c = first.cloneNode(true);
        c.id = 'dice' + (k + 1);
        first.parentNode.appendChild(c);
        var d = addDie(c);
        (function (dd) {
          dd.el.addEventListener('error', function () { fail(dd); });
          setTimeout(function () { fail(dd); }, 8000);
        })(d);
      }
      statusText();
    });

    window.addEventListener('pointerdown', onDown);
  }
  start();
})();
''';