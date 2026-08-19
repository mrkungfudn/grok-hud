import * as fs from 'node:fs';
import * as path from 'node:path';
import type {
  ActiveSession,
  SessionSignals,
  SessionSnapshot,
  SessionSummary,
  ToolEntry,
} from './types.js';
import { getGitStatus } from './git.js';
import { parseRecentTools } from './activity.js';

/**
 * Live context fill from the tail of updates.jsonl (`params._meta.totalTokens`).
 * Grok's meter uses this during a turn. signals.json only flushes at turn end
 * (and can stay stale across auto-compact). Regex on a byte tail, not
 * JSON.parse-per-line: a single tool_call_update is often larger than the
 * tail window, parse() then returns nothing, and HUD falls back to the stale
 * signals number. `_meta` sits at the END of the line so the tail still has
 * it. LAST sane value (≤ 2M), not MAX — MAX once picked a 5M junk field.
 *
 * 🔴 Match `_meta.totalTokens` only. Bare `"totalTokens":N` also lives in
 * nested API `usage` inside tool output (1.2M input+output vs real _meta
 * ~250k) — that painted 245% (1.2M/500k) on the HUD.
 */
function lastTotalTokensFromUpdates(updatesPath: string): number {
  if (!fs.existsSync(updatesPath)) return 0;
  try {
    const stat = fs.statSync(updatesPath);
    const fd = fs.openSync(updatesPath, 'r');
    try {
      const maxBytes = Math.min(stat.size, 512 * 1024);
      const start = Math.max(0, stat.size - maxBytes);
      const buf = Buffer.alloc(maxBytes);
      const read = fs.readSync(fd, buf, 0, maxBytes, start);
      const content = buf.subarray(0, read).toString('utf8');
      let last = 0;
      for (const m of content.matchAll(/"_meta"\s*:\s*\{\s*"totalTokens"\s*:\s*(\d+)/g)) {
        const n = Number(m[1]);
        if (n > 0 && n <= 2_000_000) last = n;
      }
      return last;
    } finally {
      fs.closeSync(fd);
    }
  } catch {
    return 0;
  }
}

function readJsonFile<T>(filePath: string): T | null {
  try {
    if (!fs.existsSync(filePath)) return null;
    return JSON.parse(fs.readFileSync(filePath, 'utf8')) as T;
  } catch {
    return null;
  }
}

function encodeCwdSegment(cwd: string): string {
  // Grok stores cwd as path segments joined by %2F (URL-encoded /)
  return cwd
    .split(path.sep)
    .filter((p, i) => !(i === 0 && p === ''))
    .map((seg) => encodeURIComponent(seg))
    .join('%2F')
    .replace(/^/, cwd.startsWith('/') ? '%2F' : '');
}

export function sessionDirFor(grokHome: string, cwd: string, sessionId: string): string {
  return path.join(grokHome, 'sessions', encodeCwdSegment(cwd), sessionId);
}

/** Find session directory by walking sessions tree (fallback). */
export function findSessionDir(grokHome: string, sessionId: string): string | null {
  const root = path.join(grokHome, 'sessions');
  if (!fs.existsSync(root)) return null;

  try {
    for (const cwdEnc of fs.readdirSync(root)) {
      if (cwdEnc.startsWith('.') || cwdEnc === 'session_search.sqlite') continue;
      const candidate = path.join(root, cwdEnc, sessionId);
      if (fs.existsSync(path.join(candidate, 'summary.json')) || fs.existsSync(candidate)) {
        if (fs.statSync(candidate).isDirectory()) {
          return candidate;
        }
      }
    }
  } catch {
    // ignore
  }
  return null;
}

function isPidAlive(pid?: number): boolean {
  if (!pid || pid <= 0) return false;
  try {
    process.kill(pid, 0);
    return true;
  } catch {
    return false;
  }
}

export function loadActiveSessions(grokHome: string): ActiveSession[] {
  const file = path.join(grokHome, 'active_sessions.json');
  const data = readJsonFile<ActiveSession[]>(file);
  if (!Array.isArray(data)) return [];
  return data.filter((s) => s && typeof s.session_id === 'string');
}

/** List recent sessions from disk, newest first. */
export function listRecentSessions(grokHome: string, limit = 20): Array<{ sessionId: string; dir: string; mtime: number }> {
  const root = path.join(grokHome, 'sessions');
  const out: Array<{ sessionId: string; dir: string; mtime: number }> = [];
  if (!fs.existsSync(root)) return out;

  try {
    for (const cwdEnc of fs.readdirSync(root)) {
      if (cwdEnc.startsWith('.') || !cwdEnc.includes('%')) continue;
      const cwdDir = path.join(root, cwdEnc);
      let st: fs.Stats;
      try {
        st = fs.statSync(cwdDir);
      } catch {
        continue;
      }
      if (!st.isDirectory()) continue;

      for (const sessionId of fs.readdirSync(cwdDir)) {
        const dir = path.join(cwdDir, sessionId);
        try {
          const s = fs.statSync(dir);
          if (!s.isDirectory()) continue;
          if (!fs.existsSync(path.join(dir, 'summary.json')) && !fs.existsSync(path.join(dir, 'signals.json'))) {
            continue;
          }
          out.push({ sessionId, dir, mtime: s.mtimeMs });
        } catch {
          // skip
        }
      }
    }
  } catch {
    // ignore
  }

  out.sort((a, b) => b.mtime - a.mtime);
  return out.slice(0, limit);
}

export async function loadSessionSnapshot(options: {
  grokHome: string;
  sessionId: string;
  cwd?: string;
  pid?: number;
  openedAt?: string;
  enableGit: boolean;
  maxTools: number;
}): Promise<SessionSnapshot | null> {
  const { grokHome, sessionId, enableGit, maxTools } = options;
  let dir: string | null = null;
  if (options.cwd) {
    dir = sessionDirFor(grokHome, options.cwd, sessionId);
    if (!fs.existsSync(dir)) dir = null;
  }
  if (!dir) {
    dir = findSessionDir(grokHome, sessionId);
  }
  if (!dir) return null;

  const summary = readJsonFile<SessionSummary>(path.join(dir, 'summary.json'));
  let signals = readJsonFile<SessionSignals>(path.join(dir, 'signals.json'));
  const cwd = options.cwd || summary?.info?.cwd || summary?.git_root_dir || '';
  const tools: ToolEntry[] = parseRecentTools(path.join(dir, 'updates.jsonl'), maxTools * 3).slice(0, maxTools);

  // Prefer live totalTokens (written every tool/stream tick) over signals.json
  // which only updates when a turn ends — that's why the HUD lagged Grok's meter.
  let windowTokens = signals?.contextWindowTokens ?? 500_000;
  const liveTokens = lastTotalTokensFromUpdates(path.join(dir, 'updates.jsonl'));
  if (liveTokens > 0) {
    if (liveTokens > windowTokens) windowTokens = liveTokens;
    signals = {
      ...(signals ?? {}),
      contextTokensUsed: liveTokens,
      contextWindowTokens: windowTokens,
      contextWindowUsage: Math.min(100, Math.round((liveTokens / windowTokens) * 100)),
      primaryModelId: signals?.primaryModelId ?? summary?.current_model_id,
    };
  }

  const gitStatus = enableGit && cwd ? await getGitStatus(cwd) : null;

  return {
    sessionId,
    cwd,
    dir,
    pid: options.pid,
    openedAt: options.openedAt,
    live: isPidAlive(options.pid),
    summary,
    signals,
    tools,
    gitStatus,
  };
}

export async function collectSnapshots(options: {
  grokHome: string;
  cwdFilter?: string;
  sessionId?: string;
  enableGit: boolean;
  maxTools: number;
  includeInactive?: boolean;
}): Promise<SessionSnapshot[]> {
  const { grokHome, enableGit, maxTools } = options;
  const active = loadActiveSessions(grokHome);
  const snapshots: SessionSnapshot[] = [];
  const seen = new Set<string>();

  const candidates: ActiveSession[] = [];

  if (options.sessionId) {
    const match = active.find((a) => a.session_id === options.sessionId);
    candidates.push(
      match ?? {
        session_id: options.sessionId,
        cwd: options.cwdFilter,
      },
    );
  } else if (options.cwdFilter) {
    const norm = path.resolve(options.cwdFilter);
    const filtered = active.filter((a) => a.cwd && path.resolve(a.cwd) === norm);
    if (filtered.length > 0) {
      candidates.push(...filtered);
    } else if (options.includeInactive !== false) {
      // fall back to most recent session under this cwd encoding
      const encoded = encodeCwdSegment(norm);
      const dir = path.join(grokHome, 'sessions', encoded);
      if (fs.existsSync(dir)) {
        const sessions = fs
          .readdirSync(dir)
          .map((id) => {
            const p = path.join(dir, id);
            try {
              return { id, mtime: fs.statSync(p).mtimeMs };
            } catch {
              return null;
            }
          })
          .filter((x): x is { id: string; mtime: number } => !!x)
          .sort((a, b) => b.mtime - a.mtime);
        if (sessions[0]) {
          candidates.push({ session_id: sessions[0].id, cwd: norm });
        }
      }
    }
  } else {
    candidates.push(...active);
    if (candidates.length === 0 && options.includeInactive !== false) {
      for (const recent of listRecentSessions(grokHome, 3)) {
        candidates.push({ session_id: recent.sessionId });
      }
    }
  }

  for (const c of candidates) {
    if (seen.has(c.session_id)) continue;
    seen.add(c.session_id);
    const snap = await loadSessionSnapshot({
      grokHome,
      sessionId: c.session_id,
      cwd: c.cwd,
      pid: c.pid,
      openedAt: c.opened_at,
      enableGit,
      maxTools,
    });
    if (snap) snapshots.push(snap);
  }

  // Prefer live sessions, then most recently updated
  snapshots.sort((a, b) => {
    if (a.live !== b.live) return a.live ? -1 : 1;
    const at = Date.parse(a.summary?.last_active_at || a.summary?.updated_at || a.openedAt || '0');
    const bt = Date.parse(b.summary?.last_active_at || b.summary?.updated_at || b.openedAt || '0');
    return bt - at;
  });

  return snapshots;
}
