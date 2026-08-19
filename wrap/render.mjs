#!/usr/bin/env node
/**
 * Claude-HUD-shaped snapshot for Grok.
 *
 * Claude side (this machine) is combined-hud: claude-hud identity + OMC full
 * (git / ctx bar / rate limits / last tool / agents / todos). Grok has no
 * statusLine API and no OMC transcript, so we rebuild the same *rows* from
 * grok-hud JSON + signals.json + summary.json + git + config.toml.
 *
 * Things Claude has that Grok simply does not (not rendered):
 * ralph, autopilot, PRD story, mission board, OMC agent tree, todos,
 * prompt-cache hit%, Claude auth/cost USD, skills-in-turn.
 */
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { hostname, homedir } from "node:os";
import { basename, join } from "node:path";

const HOME = homedir();
const CFG_PATH = join(HOME, ".grok/plugins/grok-hud/config.json");
const RESET = "\x1b[0m";
const DIM = "\x1b[2m";
const SEP = `${DIM} │ ${RESET}`;
/** Fallbacks only — live colors always come from config.json hex. */
const FALLBACK = {
  context: "#4ade80",
  warning: "#facc15",
  critical: "#f87171",
  model: "#22d3ee",
  project: "#facc15",
  git: "#c084fc",
  gitBranch: "#67e8f9",
  tools: "#60a5fa",
};

function loadCfg() {
  try {
    return JSON.parse(readFileSync(CFG_PATH, "utf8"));
  } catch {
    return {};
  }
}

function hexAnsi(hex, fallback) {
  if (typeof hex !== "string" || !hex.startsWith("#") || hex.length !== 7) return fallback;
  const r = parseInt(hex.slice(1, 3), 16);
  const g = parseInt(hex.slice(3, 5), 16);
  const b = parseInt(hex.slice(5, 7), 16);
  return `\x1b[38;2;${r};${g};${b}m`;
}

function paint(text, ansi) {
  return `${ansi}${text}${RESET}`;
}

function shortTok(n) {
  const x = Number(n) || 0;
  if (x >= 1_000_000) return (x / 1_000_000).toFixed(1).replace(/\.0$/, "") + "M";
  if (x >= 1_000) return Math.round(x / 1000) + "k";
  return String(Math.round(x));
}

function dur(sec) {
  const s = Math.max(0, Math.round(Number(sec) || 0));
  if (s < 60) return `${s}s`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m`;
  const h = Math.floor(m / 60);
  const rem = m % 60;
  return rem ? `${h}h ${rem}m` : `${h}h`;
}

function bar(pct, width, color) {
  const p = Math.max(0, Math.min(100, Number(pct) || 0));
  const filled = Math.round((p / 100) * width);
  return paint("█".repeat(filled) + "░".repeat(width - filled), color);
}

function pctColor(pct, cOk, cWarn, cErr, warn, crit) {
  if (pct >= crit) return cErr;
  if (pct >= warn) return cWarn;
  return cOk;
}

function grokHudJson(cwd) {
  const r = spawnSync("grok-hud", ["--json", "--all", "--cwd", cwd], {
    encoding: "utf8",
    timeout: 8000,
    env: process.env,
  });
  try {
    return JSON.parse(r.stdout || "{}");
  } catch {
    return {};
  }
}

function readJson(p) {
  try {
    return JSON.parse(readFileSync(p, "utf8"));
  } catch {
    return null;
  }
}

function sessionFiles(cwd, sessionId) {
  const enc = encodeURIComponent(cwd);
  const dir = join(HOME, ".grok/sessions", enc, sessionId);
  return {
    dir,
    signals: readJson(join(dir, "signals.json")) || {},
    summary: readJson(join(dir, "summary.json")) || {},
  };
}

/**
 * Grok's meter reads params._meta.totalTokens on every stream/tool tick.
 * signals.json only flushes at turn end (and lags auto-compact too).
 *
 * Regex on a byte tail, not JSON.parse-per-line: tool_call_update lines are
 * often hundreds of KB, so a 512KB tail is one truncated JSON object and
 * parse() returns nothing — HUD then falls back to the stale signals number.
 * `_meta.totalTokens` sits at the END of the line, so the tail still has it.
 * LAST sane value, not MAX — MAX once picked a 5M junk field.
 *
 * 🔴 Match `_meta.totalTokens` only. A bare `"totalTokens":N` also appears in
 * nested API `usage` blobs inside tool output (measured: 1,224,478 input+output
 * vs real _meta 247k) — that is what painted 245% (1.2M/500k).
 */
function lastTotalTokens(updatesPath) {
  try {
    if (!existsSync(updatesPath)) return 0;
    const st = spawnSync("tail", ["-c", "524288", updatesPath], { encoding: "utf8", timeout: 1000 });
    const text = st.stdout || "";
    let last = 0;
    for (const m of text.matchAll(/"_meta"\s*:\s*\{\s*"totalTokens"\s*:\s*(\d+)/g)) {
      const n = Number(m[1]);
      if (n > 0 && n <= 2_000_000) last = n;
    }
    return last;
  } catch {
    return 0;
  }
}

function permissionMode() {
  try {
    const t = readFileSync(join(HOME, ".grok/config.toml"), "utf8");
    const m = t.match(/permission_mode\s*=\s*"([^"]+)"/);
    return m ? m[1] : "";
  } catch {
    return "";
  }
}

function grokVersion() {
  try {
    const v = JSON.parse(readFileSync(join(HOME, ".grok/version.json"), "utf8"));
    return v.version || "";
  } catch {
    return "";
  }
}

function dirtyCount(cwd) {
  const r = spawnSync("git", ["--no-optional-locks", "status", "--porcelain"], {
    cwd,
    encoding: "utf8",
    timeout: 1000,
  });
  if (r.status !== 0) return 0;
  return (r.stdout || "").split("\n").filter((l) => l.trim()).length;
}

function toolGlyph(status, cOk, cWarn, cErr) {
  if (status === "error") return paint("✗", cErr);
  if (status === "running" || status === "pending") return paint("◐", cWarn);
  return paint("✓", cOk);
}

function shortModel(id) {
  if (!id) return "Grok";
  return String(id).replace(/^grok-/, "Grok ");
}

function modeLabel(agent) {
  if (!agent) return "";
  const a = String(agent).toLowerCase();
  if (a.includes("plan")) return "plan";
  if (a.includes("ask")) return "ask";
  return "";
}

function resetsIn(iso, now) {
  if (!iso) return "";
  const t = Date.parse(iso);
  if (!Number.isFinite(t)) return "";
  const sec = Math.max(0, Math.round((t - now) / 1000));
  if (sec < 3600) return `${Math.round(sec / 60)}m`;
  if (sec < 86400) return `${Math.round(sec / 3600)}h`;
  return `${Math.round(sec / 86400)}d`;
}

function main() {
  const cwd = process.argv[2] || process.cwd();
  const wantPid = Number(process.argv[3] || 0);
  const cfg = loadCfg();
  const colors = cfg.colors || {};
  const warn = Number(cfg.display?.warningThreshold ?? 80);
  const crit = Number(cfg.display?.criticalThreshold ?? 90);
  const now = Date.now();

  const cOk = hexAnsi(colors.context, hexAnsi(FALLBACK.context, DIM));
  const cWarn = hexAnsi(colors.warning, hexAnsi(FALLBACK.warning, DIM));
  const cErr = hexAnsi(colors.critical, hexAnsi(FALLBACK.critical, DIM));
  const cModel = hexAnsi(colors.model, hexAnsi(FALLBACK.model, DIM));
  const cProj = hexAnsi(colors.project, hexAnsi(FALLBACK.project, DIM));
  const cGit = hexAnsi(colors.git, hexAnsi(FALLBACK.git, DIM));
  const cBr = hexAnsi(colors.gitBranch, hexAnsi(FALLBACK.gitBranch, DIM));
  const cTools = hexAnsi(colors.tools, hexAnsi(FALLBACK.tools, DIM));
  const cLabel = DIM;

  const blob = grokHudJson(cwd);
  const sessions = Array.isArray(blob.sessions) ? blob.sessions : [];
  // When tmux gives us a pane pid, NEVER fall back to another live Grok
  // (herdr splash used to steal this conversation's 300k context bar).
  let s = wantPid
    ? sessions.find((x) => Number(x.pid) === wantPid)
    : sessions.find((x) => x.live) || sessions[0];
  if (!s && wantPid) {
    s = { cwd, sessionId: "", live: true, pid: wantPid, git: {}, context: {} };
  }
  if (!s) {
    console.log(`${DIM}grok-hud: no session${RESET}`);
    return;
  }

  const { dir: sessDir, signals, summary } = sessionFiles(s.cwd || cwd, s.sessionId);
  const git = s.git || {};
  const ctx = s.context || {};
  let total = Number(ctx.total ?? signals.contextWindowTokens ?? 500000) || 500000;
  const liveUsed = lastTotalTokens(join(sessDir, "updates.jsonl"));
  const used = liveUsed || Number(ctx.used ?? signals.contextTokensUsed ?? 0);
  // Bar width is 0–100; never paint 245%. If used still exceeds the window
  // after the _meta filter, grow the denominator instead of overflowing %.
  if (used > total && total > 0) total = used;
  const pct = total > 0 ? Math.min(100, Math.round((used / total) * 100)) : 0;
  const usage = blob.creditUsage || {};
  const usagePct = Math.round(Number(usage.percent) || 0);
  const dirty = dirtyCount(s.cwd || cwd);
  const effort = summary.reasoning_effort || "";
  const mode = modeLabel(summary.agent_name || s.agent);
  const title = (s.title || summary.generated_title || "").slice(0, 24);
  const host = hostname().replace(/\.local$/, "");
  const repo = basename((s.cwd || cwd).replace(/\/$/, ""));
  const perm = permissionMode();
  const sandbox = summary.sandbox_profile && summary.sandbox_profile !== "off" ? summary.sandbox_profile : "";
  const ver = grokVersion();
  const compact = Number(signals.compactionCount || 0);
  const errs = Number(signals.errorCount || 0) + Number(signals.toolFailureCount || 0);
  const files = Number(signals.agentFilesTouched || signals.totalFilesTouched || 0);
  const add = Number(signals.agentLinesAdded || 0);
  const del = Number(signals.agentLinesRemoved || 0);
  const turns = s.turns ?? signals.turnCount ?? "";
  const toolsN = s.toolCallCount ?? signals.toolCallCount ?? "";
  const ctxCol = pctColor(pct, cOk, cWarn, cErr, warn, crit);
  const useCol = pctColor(usagePct, cOk, cWarn, cErr, warn, crit);

  // Line 1 — OMC line1: host · repo · branch · dirty
  const gitBits = [];
  gitBits.push(paint(repo, cProj));
  if (git.branch) {
    const star = git.isDirty || dirty ? "*" : "";
    gitBits.push(paint(`${git.branch}${star}`, cBr));
  }
  if (git.ahead > 0) gitBits.push(paint(`↑${git.ahead}`, cGit));
  if (git.behind > 0) gitBits.push(paint(`↓${git.behind}`, cGit));
  if (dirty > 0) gitBits.push(paint(`${dirty}Δ`, cWarn));
  const line1 = [paint(host, cLabel), gitBits.join(" ")].filter(Boolean).join(SEP);

  // Line 2 — claude-hud identity: [model ◑ effort] · mode · title · live · ver
  const modelId = shortModel(s.model || signals.primaryModelId || "grok");
  const effortBit = effort ? ` ◑ ${effort}` : "";
  const live = s.live ? paint("● live", cOk) : paint("○ stale", DIM);
  const line2 = [
    paint(`[${modelId}${effortBit}]`, cModel),
    mode ? paint(mode, cGit) : "",
    title ? paint(title, cLabel) : "",
    live,
    ver ? paint(`v${ver}`, cLabel) : "",
    perm ? paint(perm, cLabel) : "",
  ]
    .filter(Boolean)
    .join(SEP);

  // Line 3 — OMC contextBar + session
  const ctxWarn =
    pct >= crit ? paint(" ⚠ context critical", cErr) : pct >= warn ? paint(" ⚠ context high", cWarn) : "";
  const line3 = [
    `${paint("Context", cLabel)} ${bar(pct, 10, ctxCol)} ${paint(`${pct}% (${shortTok(used)}/${shortTok(total)})`, ctxCol)}${ctxWarn}`,
    `${paint("Time", cLabel)} ${paint(dur(s.durationSeconds ?? signals.sessionDurationSeconds), cLabel)}`,
    turns !== "" ? `${paint("Turns", cLabel)} ${paint(String(turns), cLabel)}` : "",
    toolsN !== "" ? `${paint("Tools", cLabel)} ${paint(String(toolsN), cLabel)}` : "",
    files ? `${paint("Files", cLabel)} ${paint(String(files), cLabel)}` : "",
    add || del ? `${paint("Lines", cLabel)} ${paint(`+${add}`, cOk)} ${paint(`-${del}`, cErr)}` : "",
  ]
    .filter(Boolean)
    .join(SEP);

  // Line 4 — OMC rateLimits + health
  const reset = resetsIn(usage.periodEnd, now);
  const line4 = [
    `${paint("Usage", cLabel)} ${bar(usagePct, 10, useCol)} ${paint(`${usagePct}%`, useCol)} ${paint(`(${usage.periodType || "weekly"})`, cLabel)}${reset ? paint(` · resets ${reset}`, cLabel) : ""}`,
    sandbox ? paint(`sandbox ${sandbox}`, cWarn) : "",
    compact > 0 ? paint(`compact ${compact}`, cLabel) : "",
    errs > 0 ? paint(`err ${errs}`, cErr) : "",
  ]
    .filter(Boolean)
    .join(SEP);

  // Line 5 — last tools (OMC lastTool / callCounts)
  const recent = Array.isArray(s.recentTools) ? s.recentTools.slice(0, cfg.display?.maxTools || 4) : [];
  const counts = new Map();
  const chunks = [];
  for (const t of recent) {
    if (t.status === "running" || t.status === "pending") {
      chunks.push(`${toolGlyph(t.status, cOk, cWarn, cErr)} ${paint(t.name, cTools)}${t.target ? paint(` ${String(t.target).slice(0, 18)}`, cLabel) : ""}`);
    } else {
      counts.set(t.name, (counts.get(t.name) || 0) + 1);
    }
  }
  for (const [name, n] of counts) {
    chunks.push(`${toolGlyph("completed", cOk, cWarn, cErr)} ${paint(name, cTools)}${n > 1 ? paint(` ×${n}`, cLabel) : ""}`);
  }
  let line5 = chunks.length ? chunks.join(" | ") : paint("(no recent tools)", cLabel);

  // Line 6 — extra sessions (Claude shows one session; we flag siblings)
  if (sessions.length > 1) {
    line5 = `${line5}${SEP}${paint(`(+${sessions.length - 1} more)`, cLabel)}`;
  }

  let out = [line1, line2, line3, line4, line5].join("\n") + "\n";
  if (process.env.GROK_HUD_TMUX === "1") out = ansiToTmux(out);
  process.stdout.write(out);
}

const FG = {
  30: "black",
  31: "red",
  32: "green",
  33: "yellow",
  34: "blue",
  35: "magenta",
  36: "cyan",
  37: "white",
  90: "brightblack",
  91: "brightred",
  92: "brightgreen",
  93: "brightyellow",
  94: "brightblue",
  95: "brightmagenta",
  96: "brightcyan",
  97: "brightwhite",
};

function ansiToTmux(text) {
  return text.replace(/\x1b\[([0-9;]*)m/g, (_, inner) => {
    if (!inner || inner === "0") return "#[default]";
    const parts = inner.split(";");
    const out = [];
    for (let i = 0; i < parts.length; i++) {
      const p = parts[i];
      if (p === "" || p === "0") out.push("default");
      else if (p === "1") out.push("bold");
      else if (p === "2") out.push("dim");
      else if (p === "22") {
        out.push("nobold");
        out.push("nodim");
      } else if (p === "39") out.push("fg=default");
      else if (FG[p]) out.push(`fg=${FG[p]}`);
      else if (p === "38" && parts[i + 1] === "2" && parts[i + 4] != null) {
        const r = Number(parts[i + 2]);
        const g = Number(parts[i + 3]);
        const b = Number(parts[i + 4]);
        out.push(`fg=#${r.toString(16).padStart(2, "0")}${g.toString(16).padStart(2, "0")}${b.toString(16).padStart(2, "0")}`);
        i += 4;
      } else if (p === "38" && parts[i + 1] === "5" && parts[i + 2] != null) {
        out.push(`fg=colour${parts[i + 2]}`);
        i += 2;
      }
    }
    return "#[" + (out.join(",") || "default") + "]";
  });
}

main();
