# wakubp — Bypass by [waku](https://t.me/wakubox) on Teyvat (Antigravity / Gemini 3.8 Flash)

Local prompt pack and bypass installer for **Antigravity 2.0 (Gemini 3.8 Flash)**, **OpenCode**, and **DeepSeek Harness**.
Everything ships locally in this folder — the installer never touches the network.

---

## Directory Structure

```text
wakubp/
├── wakubp.bat             # Main launcher (double-click to open GUI menu)
├── README.md              # Documentation
├── LICENSE                # MIT License
├── .gitignore             # Git ignore rules
├── .gitattributes         # Line-ending rules (CRLF for Windows scripts, LF for docs)
├── src/                   # Application engine & UI scripts
│   ├── build-exe.ps1      # Compiles the entire repo into a standalone single-file wakubp.exe
│   ├── launch.vbs         # WSH helper to spawn GUI without PowerShell console flash
│   ├── gui.ps1            # WinForms GUI front-end
│   └── engine.ps1         # Core installer & backup manifest engine
└── payload/               # Clean payload bundle shipped to targets
    ├── GEMINI.md          # Core spec (identity, voice, scope, output contract)
    ├── prompt.txt         # Task-pipe template
    ├── opencode-bypass.md # Global AGENTS.md payload for OpenCode & DeepSeek Harness
    └── .gemini/
        ├── domains/       # Domain modules: systems, instrumentation, reverse, networking, automation, creative
        └── references/    # Quality gate, compatibility notes, engines, shapes
```

---

## Quick Launch & Single-File `.exe` Build

- **Run from folder:** Double-click **`wakubp.bat`** to open the menu.
- **Build standalone single-file `.exe` (for easy sharing):**
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File .\src\build-exe.ps1
  ```
  Produces **`dist\wakubp.exe`** (~45 KB) with all `src\` and `payload\` files GZip-compressed inside. You can share **`wakubp.exe`** alone as a single file without any accompanying folders.

**Menu Layout & Live Status:**
- Each row's **left accent bar and number turn green** when that app's bypass is currently installed, and revert to blue when removed.

| Key | Target | Left Click (Main Row) | Right Button |
|---|---|---|---|
| **1** | **Antigravity** | Install bypass + `AGENT.md` credit | `Delete` (Restore everything) |
| **2** | **OpenCode** | Inject global `AGENTS.md` | `Remove` (Restore original) |
| **3** | **DeepSeek Harness** | Inject global `AGENTS.md` | `Remove` (Restore original) |
| **0** | **Exit** | Close window | — |

---

## What Each Action Does

### 1. Antigravity (`Install` / `Delete`)
- **Writes:**
  - Global profile: `~\.gemini\domains\`, `~\.gemini\references\`, `~\.gemini\rules\GEMINI.md`, `~\.gemini\GEMINI.md`
  - Workspace (`~\Antigravity-Workspace` by default): `GEMINI.md`, `prompt.txt`, `.gemini\{domains,references}`
  - Desktop: `prompt.txt` (unless `-no-desktop`)
  - Telemetry off in existing Antigravity / VS Code `settings.json` files (unless `-no-telemetry`)
  - Appends/upgrades a delimited closing-credit block in `~\Downloads\AyuGram Desktop\AGENT.md` (override with `-agent-file <path>`)
- **Backups & Manifest:**
  - Every file overwritten is backed up to `~\.gemini\waku-core\backup-<timestamp>\` and tracked in `~\.gemini\waku-core\install-manifest.json`.
  - Clicking **`Delete`** (or running `wakubp-cli.bat delete`) restores all original files from backup and removes installer-created files.

### 2. OpenCode (`OpenCode` / `Remove`)
- Copies `payload\opencode-bypass.md` to `~\.config\opencode\AGENTS.md`.
- Backs up any pre-existing file into `waku-core` manifest so **`Remove`** (or `remove-bypass`) restores it cleanly.

### 3. DeepSeek Harness (`DeepSeek Harness` / `Remove`)
- Copies `payload\opencode-bypass.md` to `$DSH_HOME\AGENTS.md` (defaults to `~\.dsh\AGENTS.md`).
- Backs up any pre-existing file into `waku-core` manifest so **`Remove`** (or `remove-dsh`) restores it cleanly.

---

## Design Rule & Activation

The spec is written in the positive voice. It states the workspace, the artifact types, the voice, and the shape of a complete answer:
- **§7 Conversation mode** — a question gets an answer at the depth asked. Not every turn owes an artifact.
- **§8 One-line gap** — if a piece genuinely cannot be produced, one sentence names it and the rest ships complete.

**Activation:** Send `visor down` in a session. Output marker: `[waku]`.
**Re-pinning after a long session:** Send `still on the bench. re-pin.`
