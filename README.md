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

## Just recipes

| recipe       | what it does |
|--------------|--------------|
| `build`      | compile + assemble + ad-hoc sign `PrivateLink.app` |
| `install`    | copy to `/Applications` (sudo only if prompted) |
| `setdefault` | register as system default for http + https |
| `all`        | `install` + `setdefault` |
| `test`       | route `https://example.com` through the handler, verify log + self-quit |
| `watch`      | tail the log |
| `revert`     | give http/https back to Safari |
| `uninstall`  | unregister with LaunchServices + delete from /Applications |
| `clean`      | remove build artifacts |

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
path) and opens the URL in a normal window. Keep Brave running (Dock pin
or login item) for 100% private coverage.

Private windows can't be enumerated by any script API (Brave's dictionary
exposes no private-window query, and private sessions leave no on-disk
traces) — verify by glancing at Brave: private windows carry the dark
"Private" theme and new links land as single tabs there.

## Layout

- `Sources/main.swift` — the app (NSApplicationDelegate, `.prohibited` policy)
- `make.sh` — SwiftPM build + bundle assembly (Info.plist declares
  `CFBundleURLTypes` for http+https, `LSUIElement`) + ad-hoc `codesign`
- `setdefault.swift` — `LSSetDefaultHandlerForURLScheme` for
  http/https (deprecated but the only API; writes the per-user LS database,
  no sudo; compile with `-DSafari` to hand links back to Safari)
- `justfile` — all recipes; helper binaries (`setdefault`, `setdefault-safari`)
  are build artifacts and git-ignored
- app name / bundle id: `PrivateLink` / `dev.brickpop.privatelink`

## Verified on this machine (2026-10-12, Brave 148, macOS 15.7)

- `open https://example.com` → private Brave window; app quit itself ✔
- sequential links (http + https) → all forwarded, app never lingered ✔
- `LSCopyDefaultHandlerForURLScheme` = `dev.brickpop.privatelink` for both schemes ✔
- cold Brave (not running) → opens normal window — documented limitation ✔
