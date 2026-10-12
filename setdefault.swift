// Set a browser bundle as the system default handler for http and https.
// Default target: PrivateLink. Compile with -DSafari to hand http/https back
// to Safari instead. LSSetDefaultHandlerForURLScheme is deprecated but remains
// the only C API; it writes the per-user LaunchServices database, so no sudo
// is required.
import Foundation
import CoreServices

#if Safari
let bid = "com.apple.Safari" as CFString
#else
let bid = "dev.brickpop.privatelink" as CFString
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
