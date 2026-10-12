# PrivateLink

Every `http://` / `https://` link on this Mac opens in a **private Brave window** (a single tab).

PrivateLink is a phantom app (no Dock icon, no UI, quits itself after each
handoff) registered as the system default handler for http/https. When any
app asks the system to open a web link, LaunchServices launches PrivateLink
with the URL; it tells Brave to open the link privately and terminates.

## Quick start

```sh
just all        # build + install to /Applications + set as system default
just test       # open https://example.com through it, check log, confirm self-quit
just watch      # tail the log live (/tmp/privatelink.log)
```

## Justfile

Everything is driven from the justfile — there is no separate build script to
remember. `make.sh` is an implementation detail called by `just build`;
helper binaries (`setdefault`, `setdefault-safari`) are compiled on demand by
the recipes that need them and are git-ignored.

Recipes are grouped (needs `just >= 1.27`; enabled via the shebang):

| group        | recipes | what they do |
|--------------|---------|--------------|
| `[build]`    | `build` | compile (SwiftPM) + assemble + ad-hoc sign `PrivateLink.app` |
| `[install]`  | `install` | copy to `/Applications` (sudo only if prompted) |
| `[default]`  | `setdefault`, `all` | register as system default for http + https; `all` = install + setdefault |
| `[verify]`   | `test`, `watch` | route a link through the handler and verify log + self-quit; tail log |
| `[undo]`     | `revert`, `uninstall`, `clean` | hand links back to Safari; unregister + delete; remove artifacts |

`just --list --group undo` filters a single group.

## How it works (per link)

1. **Path B (bonus)** — Brave's AppleScript dictionary:
   `make new window with properties {mode:"incognito", URL:…}`.
   Needs a one-time **Automation (TCC) prompt** — click **Allow**.
   Note: ad-hoc code signing = a new code identity per rebuild, so the
   prompt reappears after each `just all`. Denial is harmless (falls back).
2. **Path A (workhorse)** — `open -n -g -a Brave --args --new-window --incognito <url>`.
   Chromium's second-instance mechanism forwards the link to the running
   Brave as a Private window with one tab. Needs **no permissions**.
3. **Path C** — plain `NSWorkspace` open (normal tab) so a link is never lost.

## Known limitation

If **Brave is not running at all**, a cold Brave ignores forwarded
`--incognito` flags (Chromium parses them only via the second-instance
path) and opens a normal window. Keep Brave running (Dock pin or login item)
for 100% private coverage.

Private windows can't be enumerated by any script API (Brave's dictionary
exposes no private-window query, and private sessions leave no on-disk
traces) — verify by glancing at Brave: private windows carry the dark
"Private" theme and new links land as single tabs there.

## Layout

- `Sources/main.swift` — the app (NSApplicationDelegate, `.prohibited` policy)
- `Package.swift` — SwiftPM manifest (`swift build -c release`)
- `make.sh` — bundle assembly called by `just build` (Info.plist declares
  `CFBundleURLTypes` for http+https, `LSUIElement`) + ad-hoc `codesign`
- `setdefault.swift` — `LSSetDefaultHandlerForURLScheme` for
  http/https (deprecated but the only API; writes the per-user LS database,
  no sudo; compiled with `-DSafari` by `just revert` to hand links back)
- `justfile` — the entrypoint; all recipes and shared config (bundle id,
  log path, LaunchServices tool) live there
- app name / bundle id: `PrivateLink` / `org.private.link`

## Verified on this machine (2026-10-12, Brave 148, macOS 15.7)

- `open https://example.com` → private Brave window; app quit itself ✔
- sequential links (http + https) → all forwarded, app never lingered ✔
- `LSCopyDefaultHandlerForURLScheme` = `org.private.link` for both schemes ✔
- cold Brave (not running) → opens normal window — documented limitation ✔
