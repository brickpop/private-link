// Set a browser bundle as the system default handler for http and https.
// Default target: PrivateBeacon. Compile with -DSafari to target Safari instead.
// LSSetDefaultHandlerForURLScheme is deprecated but remains the only C API;
// it writes the per-user LaunchServices database, so no sudo is required.
import Foundation
import CoreServices

#if Safari
let bid = "com.apple.Safari" as CFString
#else
let bid = "dev.brickpop.privatebeacon" as CFString
#endif

var failed = false
for scheme in ["http", "https"] {
    let status = LSSetDefaultHandlerForURLScheme(scheme as CFString, bid)
    let h = LSCopyDefaultHandlerForURLScheme(scheme as CFString)
    let now: String = h != nil ? (h!.takeRetainedValue() as String) : "?"
    print("\(scheme): set=\(status == 0 ? "ok" : "err \(status)"), default=\(now)")
    if now != (bid as String) { failed = true }
}
exit(failed ? 1 : 0)
