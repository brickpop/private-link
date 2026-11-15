// PrivateLink — default http/https handler that forwards each link to a
// browser's private window, then quits.

import Cocoa

struct Browser {
    let bundleId: String
    let privateArgs: [String] // put in front of the URL
    // How to start the browser without opening a window, so a private window
    // can be handed to it. nil: the browser honours privateArgs on a cold
    // start, so there is no need to start it first.
    let startArgs: [String]?
}

// Chromium browsers ignore --incognito on a cold start (they only read it when
// a second instance forwards it), so they are started window-less first.
let chromiumStart = ["--no-startup-window"]

// Order of preference: the first installed browser wins.
let browsers = [
    Browser(bundleId: "com.brave.Browser",     privateArgs: ["--new-window", "--incognito"], startArgs: chromiumStart),
    Browser(bundleId: "com.google.Chrome",     privateArgs: ["--new-window", "--incognito"], startArgs: chromiumStart),
    Browser(bundleId: "org.chromium.Chromium", privateArgs: ["--new-window", "--incognito"], startArgs: chromiumStart),
    Browser(bundleId: "com.microsoft.edgemac", privateArgs: ["--new-window", "--inprivate"], startArgs: chromiumStart),
    Browser(bundleId: "com.vivaldi.Vivaldi",   privateArgs: ["--new-window", "--incognito"], startArgs: chromiumStart),
    Browser(bundleId: "org.mozilla.firefox",   privateArgs: ["--private-window"],            startArgs: nil),
]

// Last resort when no listed browser is installed. Must be an explicit app:
// a plain NSWorkspace.open(url) would route the link back to PrivateLink.
let fallbackBundleId = "com.apple.Safari"

let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
// Never in the Dock, no menu bar, not activatable — the app is a phantom.
app.setActivationPolicy(.prohibited)
app.run()

final class Delegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // Link batches waiting for their browser to start. Quit only when none
    // are left: another batch can arrive while one is waiting.
    private var pending = 0

    // LaunchServices delivers each clicked link here.
    func application(_ application: NSApplication, open urls: [URL]) {
        let links = urls.filter { ["http", "https"].contains($0.scheme?.lowercased() ?? "") }
        let installed = browsers.lazy.compactMap { b in
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: b.bundleId).map { (b, $0) }
        }.first
        guard case let (browser, appURL)? = installed else {
            for url in links {
                log("WARN: no supported browser installed; normal window in \(fallbackBundleId): \(url)")
                plainOpen(url, bundleId: fallbackBundleId)
            }
            return quitIfIdle()
        }
        let handOff = { for url in links { self.forward(url, browser: browser, appURL: appURL) } }
        let running = !NSRunningApplication.runningApplications(withBundleIdentifier: browser.bundleId).isEmpty
        guard !running, let startArgs = browser.startArgs else {
            handOff()
            return quitIfIdle()
        }
        pending += 1
        start(browser, appURL: appURL, args: startArgs) {
            handOff()
            self.pending -= 1
            self.quitIfIdle()
        }
    }

    private func quitIfIdle() {
        if pending == 0 { NSApp.terminate(nil) } // handoff done
    }

    // Starts the browser in the background without a window, then calls done
    // on the main thread. On failure it still calls done: the handoff will
    // then cold-start the browser, at worst in a normal window.
    private func start(_ browser: Browser, appURL: URL, args: [String], done: @escaping () -> Void) {
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.activates = false
        cfg.arguments = args
        log("starting \(browser.bundleId)")
        NSWorkspace.shared.openApplication(at: appURL, configuration: cfg) { _, error in
            if let error { self.log("WARN: could not start \(browser.bundleId): \(error)") }
            DispatchQueue.main.async(execute: done)
        }
    }

    private func forward(_ url: URL, browser: Browser, appURL: URL) {
        if !openPrivate(url, browser: browser, appURL: appURL) {
            log("WARN: normal window in \(browser.bundleId): \(url)")
            plainOpen(url, bundleId: browser.bundleId)
        }
    }

    // `open -n` starts a second browser instance with the private flags; a
    // running browser takes the link over in a private window. -g keeps focus
    // on the app whose link we handled. We do not wait for `open`: forward-and-go.
    private func openPrivate(_ url: URL, browser: Browser, appURL: URL) -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        proc.arguments = ["-n", "-g", "-a", appURL.path, "--args"] + browser.privateArgs + [url.absoluteString]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            log("private window in \(browser.bundleId): \(url)")
            return true
        } catch {
            log("launch failed for \(browser.bundleId): \(error)")
            return false
        }
    }

    // Never drop the link.
    private func plainOpen(_ url: URL, bundleId: String) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            log("ERROR: \(bundleId) not found; link dropped: \(url)")
            return
        }
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.activates = true
        NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: cfg, completionHandler: nil)
    }

    private func log(_ msg: String) {
        let line = "[\(Date())] \(msg)\n"
        FileHandle.standardError.write(Data(line.utf8))
        let p = "/tmp/privatelink.log"
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
