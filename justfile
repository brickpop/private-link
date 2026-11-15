#!/usr/bin/env just --justfile

# PrivateLink — every http/https link on this Mac opens in a private browser window.
#
# Groups:
#   just build       compile + assemble the .app
#   just install     copy to /Applications (admin prompt if it asks)
#   just setdefault  register as system handler for http + https
#   just all         build + install + setdefault
#   just test        open a link through it, check log, confirm self-quit
#   just watch       tail the log live
#   just revert      give http/https back to Safari
#   just uninstall   unregister + delete the app
#   just clean       remove build artifacts

# ---- configuration -------------------------------------------------------

APP         := "PrivateLink"
BUNDLE_ID   := "org.private.link"
APP_DIR     := APP + ".app"
INSTALL_DIR := "/Applications/" + APP + ".app"
LOG         := "/tmp/privatelink.log"
LSREGISTER  := "/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"

default:
    @just --list

# ---- build ---------------------------------------------------------------

# Compile with SwiftPM and assemble + ad-hoc sign {{APP}}.app
[group('build')]
build:
    @./make.sh

# ---- install -------------------------------------------------------------

# Install to /Applications (sudo only if a plain copy isn't possible)
[group('install')]
install: build
    #!/usr/bin/env bash
    set -euo pipefail
    if cp -R {{APP_DIR}} /Applications/ 2>/dev/null; then
        echo "installed {{INSTALL_DIR}}"
    else
        echo "/Applications not writable without sudo — you may be prompted:"
        sudo cp -R {{APP_DIR}} /Applications/
        echo "installed {{INSTALL_DIR}} (via sudo)"
    fi

# ---- become the system default for http/https ----------------------------

# Compile the 'set as default' helper (also used by revert/uninstall)
[group('default')]
setdefault-bin:
    #!/usr/bin/env bash
    set -euo pipefail
    swiftc -o setdefault setdefault.swift 2>/dev/null

# Register {{APP}} as the system default handler for http:// and https://
[group('default')]
setdefault: setdefault-bin
    #!/usr/bin/env bash
    set -euo pipefail
    # Make sure LaunchServices knows about the installed app
    {{LSREGISTER}} -f {{INSTALL_DIR}}
    # LSSetDefaultHandlerForURLScheme writes the per-user LS database, no sudo.
    # ('err -54' on the second scheme is benign; the database still updates —
    # verification below is what matters, so don't let set -e trip on it.)
    ./setdefault || true
    # macOS also guards the 'default browser' setting with a system prompt. Verify:
    if ./setdefault | grep -q "default={{BUNDLE_ID}}"; then
        echo "OK: {{APP}} is now the default for http and https"
    else
        echo "NOTE: macOS may still show the 'default web browser' prompt on first link."
        echo "If a dialog appears, choose {{APP}}. (System policy, not our bug.)"
    fi

# Everything: build, install, register as default
[group('default')]
all: install setdefault
    @echo "Done. Test with: just test"

# ---- verify --------------------------------------------------------------

# End-to-end test: route a link through the installed app, check log + self-quit
[group('verify')]
test:
    #!/usr/bin/env bash
    set -uo pipefail
    rm -f {{LOG}}
    open https://example.com   # goes through whatever handler is registered
    sleep 4
    echo "--- {{LOG}} ---"
    cat {{LOG}} 2>/dev/null || echo "(no log — app not invoked; handler not default yet?)"
    if pgrep -x {{APP}} >/dev/null; then
        echo "WARNING: {{APP}} still running (should self-quit after handoff)"
    else
        echo "OK: app handed the link off and quit itself"
    fi

# Watch the log live
[group('verify')]
watch:
    tail -f {{LOG}}

# ---- undo ----------------------------------------------------------------

# Give http/https back to Safari (safety valve)
[group('undo')]
revert: setdefault-bin
    #!/usr/bin/env bash
    set -euo pipefail
    swiftc -o setdefault-safari -DSafari setdefault.swift 2>/dev/null || true
    ./setdefault-safari || echo "could not revert via API; do it in System Settings if needed"

# Unregister and remove from /Applications, handing links back to Safari
[group('undo')]
uninstall: setdefault-bin
    #!/usr/bin/env bash
    set -euo pipefail
    {{LSREGISTER}} -u {{INSTALL_DIR}} 2>/dev/null || true
    rm -rf {{INSTALL_DIR}}
    swiftc -o setdefault-safari -DSafari setdefault.swift 2>/dev/null || true
    ./setdefault-safari 2>/dev/null || true
    echo "uninstalled"

# Remove build artifacts (app bundle, helper binaries, log)
[group('undo')]
clean:
    rm -rf .build {{APP_DIR}} setdefault setdefault-safari
    rm -f {{LOG}}
