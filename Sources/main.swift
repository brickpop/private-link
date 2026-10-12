// PrivateBeacon — a tiny browser shim for macOS.
//
// Registered as the system default handler for http/https. When any app
// asks the system to open a web link, LaunchServices launches *this* app
// with the URL. We forward the URL to Brave as a private (incognito) tab
// and quit immediately — the app exists only for that handoff.
//
// Verified paths (empirical, this machine, 2026-10-12):
//   A. `open -n -g -a Brave --args --new-window --incognito <url>`
//      -> Chromium's second-instance mechanism forwards the URL to the
//         running Brave as a PRIVATE window with one tab. No permissions
//         needed. This is the workhorse.
//   B. AppleScript: `make new window with properties {mode:"incognito", URL:…}`
//      -> same result, but requires a one-time Automation (TCC) grant for
//         *our* identity. Ad-hoc code signing gives a new identity per
//         rebuild, so the prompt reappears after `just all`; treat as bonus.
//   C. plain NSWorkspace open — normal tab; only so a link is never lost.
//
// Order per link: B (silent success if already granted), else A, else C.
//
// Known limitation: if Brave is NOT running at all, a cold Brave ignores
// forwarded --incognito flags (Chromium parses them only on the
// second-instance path) and opens a normal window. Keep Brave running
// (Dock pin / login item) for 100% private coverage.

import Cocoa

let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
// Never in the Dock, no menu bar, not activatable — the app is a phantom.
app.setActivationPolicy(.prohibited)
app.run()

final class Delegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // LaunchServices delivers each clicked link here.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { forward(url) }
        NSApp.terminate(nil) // handoff done; Brave owns the windows now
    }

    private let braveBid = "com.brave.Browser"
    // Sticky within one launch: once TCC denies path B, skip it for the rest
    // of this run so we don't deny-loop the prompt on every link.
    private var automationDenied = false

    private func forward(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return }
        if !automationDenied, privateTabViaAppleScript(url) { return }
        if privateTabViaOpenFlags(url) { return }
        plainOpen(url)
    }

    // Path B (bonus): Brave's own scripting command — one private window,
    // one tab. Requires the one-time Automation consent prompt (Allow).
    private func privateTabViaAppleScript(_ url: URL) -> Bool {
        let esc = url.absoluteString
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let src = """
        tell application id "\(braveBid)"
            make new window with properties {mode:"incognito", URL:"\(esc)"}
        end tell
        """
        var error: NSDictionary?
        NSAppleScript(source: src)?.executeAndReturnError(&error)
        if let error {
            let num = error[NSAppleScript.errorNumber] as? Int ?? 0
            if num == -1743 {
                automationDenied = true
                log("B: no automation grant; falling back for \(url)")
            } else {
                log("B error (\(num)): \(url)")
            }
            return false
        }
        log("B: private tab via AppleScript: \(url)")
        return true
    }

    // Path A (workhorse): `open -n -g -a Brave --args --new-window --incognito <url>`.
    // Verified: with Brave running this opens the link in a Private window
    // with a single tab. -g keeps focus on the app whose link we handled.
    // We do not wait for `open`: the transient flagged Brave instance may
    // raise its own Automation prompt; staying alive would make us quit
    // before the user can answer it. Forward-and-go.
    private func privateTabViaOpenFlags(_ url: URL) -> Bool {
        guard let brave = NSWorkspace.shared.urlForApplication(withBundleIdentifier: braveBid) else {
            log("A: Brave not found")
            return false
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = ["-n", "-g", "-a", brave.path, "--args",
                          "--new-window", "--incognito", url.absoluteString]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            log("A: forwarded via Brave flags: \(url)")
            return true
        } catch {
            log("A: flags launch failed: \(error)")
            return false
        }
    }

    // Path C: never drop the link.
    private func plainOpen(_ url: URL) {
        if let brave = NSWorkspace.shared.urlForApplication(withBundleIdentifier: braveBid) {
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.activates = true
            NSWorkspace.shared.open([url], withApplicationAt: brave, configuration: cfg, completionHandler: nil)
        } else {
            NSWorkspace.shared.open(url)
        }
        log("C: WARN plain open (normal tab): \(url)")
    }

    private func log(_ msg: String) {
        let line = "[\(Date())] \(msg)\n"
        FileHandle.standardError.write(Data(line.utf8))
        let p = "/tmp/privatebeacon.log"
        if !FileManager.default.fileExists(atPath: p) {
            FileManager.default.createFile(atPath: p, contents: nil)
        }
        if let h = FileHandle(forWritingAtPath: p) {
            h.seekToEndOfFile()
            h.write(Data(line.utf8))
            h.closeFile()
        }
    }
}
