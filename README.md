# PrivateLink

Make every `http://` and `https://` link on your Mac open in a **private browser window**.

PrivateLink is a tiny background app with no Dock icon and no UI. You set it as the default browser. When you click a link, it passes the link to your browser in private mode and then quits.

## Setup

Requires macOS, Xcode command line tools, [`just`](https://github.com/casey/just) ≥ 1.27 and one of the supported browsers.

```sh
just all     # build, install to /Applications, set as default browser
just test    # open a test link and check that it worked
```

If macOS asks you to pick a default browser, choose **PrivateLink**.

## Supported browsers

PrivateLink uses the **first installed** browser from this list:

1. Brave
2. Google Chrome
3. Chromium
4. Microsoft Edge
5. Vivaldi
6. Firefox

To change the order or add a browser, edit the `browsers` list at the top of `Sources/main.swift` and run `just all`.

## Commands

| Command          | What it does                                      |
|------------------|---------------------------------------------------|
| `just all`       | Build, install and set as default                 |
| `just build`     | Build `PrivateLink.app`                           |
| `just install`   | Copy it to `/Applications`                        |
| `just setdefault`| Set it as the handler for http and https          |
| `just test`      | Open a test link, show the log, check it quit     |
| `just watch`     | Follow the log live (`/tmp/privatelink.log`)      |
| `just revert`    | Make Safari the default browser again             |
| `just uninstall` | Make Safari the default again and delete the app  |
| `just clean`     | Delete build output                               |

## How it works

If the browser isn't running, PrivateLink starts it in the background without opening a window (Chromium browsers only, using `--no-startup-window`). Firefox doesn't need this step. Then PrivateLink runs `open -n -g -a <browser> --args <private flags> <url>`, and the running browser opens the link in a private window. If that fails, the link opens in a normal window of the same browser. If no supported browser is installed, it opens in Safari. A link is never dropped.

## Limitations

- **The first link after the browser starts takes a little longer**, because PrivateLink waits for the browser to start.
- **The browser may restore your last session.** If it's set to reopen previous windows on startup, those normal windows reappear next to the private one.
- **There is no automatic check that the window is private.** No script can list a browser's private windows. Look at the window instead.

## Project layout

| File               | Purpose                                                                 |
|--------------------|-------------------------------------------------------------------------|
| `Sources/main.swift` | The app                                                               |
| `Package.swift`    | SwiftPM manifest                                                        |
| `make.sh`          | Puts the `.app` together (Info.plist, URL schemes) and signs it         |
| `setdefault.swift` | Sets the default http/https handler. Built with `-DSafari` for `revert` |
| `justfile`         | All commands and shared settings (bundle id `org.private.link`, log path) |

The earlier Brave-only version was tested on macOS 15.7 with Brave 148. Firefox has been checked: `--private-window` opens a private window whether or not Firefox is already running. The Chromium browsers have not been tested with the multi-browser version yet.
