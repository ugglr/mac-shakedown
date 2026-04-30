#!/bin/bash
# display-test.sh — open a fullscreen color cycle in Safari for visual inspection.
# Press F to fullscreen, Space to start cycling, ← / → to navigate, Esc / Cmd-Q to exit.

set -euo pipefail

SECONDS_PER_COLOR=${SECONDS_PER_COLOR:-15}

HTML=$(mktemp -t shakedown-display).html

# Heredoc with no expansion, then sed in the duration
cat > "$HTML" <<'HTML'
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Shakedown Display Test</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
html,body{height:100%;overflow:hidden;cursor:none;
  font:14px ui-monospace,Menlo,monospace;-webkit-user-select:none}
body{display:flex;flex-direction:column;align-items:center;justify-content:center;
  transition:background .12s linear;background:#888}
.label{padding:10px 14px;border-radius:6px;background:rgba(127,127,127,.35);
  color:#fff;font-weight:600;letter-spacing:.08em;text-shadow:0 1px 0 rgba(0,0,0,.4)}
.help{margin-top:14px;color:rgba(255,255,255,.55);font-size:11px;letter-spacing:.04em}
.controls-hint{position:fixed;bottom:24px;font-size:10px;color:rgba(255,255,255,.4);letter-spacing:.06em}
</style>
</head>
<body>
<div class="label" id="label">PRESS F FOR FULLSCREEN, SPACE TO START</div>
<div class="help" id="help">color cycle for dead pixels, backlight bleed, uniformity</div>
<div class="controls-hint">F fullscreen · Space play/pause · ← → navigate · Esc exit</div>
<script>
const colors = [
  {bg:"#ffffff", name:"WHITE — look for dead/dim pixels and tint patches"},
  {bg:"#ff0000", name:"RED — look for stuck pixels (black or wrong color)"},
  {bg:"#00ff00", name:"GREEN — look for stuck pixels"},
  {bg:"#0000ff", name:"BLUE — look for stuck pixels"},
  {bg:"#808080", name:"50% GRAY — look for backlight uniformity / patches"},
  {bg:"#000000", name:"BLACK — dim ambient light, look for backlight bleed at edges"},
];
const duration = SECS_PLACEHOLDER * 1000;
let idx = -1, paused = true, timer = null;

function show(i) {
  idx = (i + colors.length) % colors.length;
  const c = colors[idx];
  document.body.style.background = c.bg;
  const isLight = ["#ffffff","#808080"].includes(c.bg);
  document.getElementById("label").textContent = c.name;
  document.getElementById("label").style.color = isLight ? "#000" : "#fff";
  if (timer) { clearTimeout(timer); timer = null; }
  if (!paused) timer = setTimeout(() => show(idx + 1), duration);
}

document.addEventListener("keydown", e => {
  if (e.key === "Escape") window.close();
  else if (e.key === "f" || e.key === "F") {
    if (!document.fullscreenElement) document.documentElement.requestFullscreen();
    else document.exitFullscreen();
  } else if (e.key === " ") {
    e.preventDefault();
    if (idx < 0) { paused = false; show(0); }
    else { paused = !paused; show(idx); }
  } else if (e.key === "ArrowRight") { paused = true; show(idx + 1); }
  else if (e.key === "ArrowLeft") { paused = true; show(idx - 1); }
});
</script>
</body>
</html>
HTML

# Substitute the duration
sed -i.bak "s/SECS_PLACEHOLDER/${SECONDS_PER_COLOR}/" "$HTML"
rm -f "${HTML}.bak"

cat <<INFO >&2
Display test page written to: $HTML
Opening in default browser. Then:
  F        fullscreen
  Space    play/pause cycling
  ← / →    previous/next manually
  Esc      exit

Each color shows for ${SECONDS_PER_COLOR}s when cycling.
INFO

open "$HTML"
