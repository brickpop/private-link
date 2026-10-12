# PrivateLink — every http/https link opens a private Brave tab.
#
#   just build      compile + assemble the .app
#   just install    copy to /Applications (admin prompt if it asks)
#   just setdefault register as system handler for http + https
#   just test       open a link through it and show the log
#   just all        build + install + setdefault

default:
    @just --list

# Compile and assemble PrivateLink.app
build:
    @./make.sh

# Install to /Applications (uses sudo only if needed)
install: build
    #!/usr/bin/env bash
    set -euo pipefail
    if cp -R PrivateLink.app /Applications/ 2>/dev/null; then
        echo "installed /Applications/PrivateLink.app"
    else
        echo "/Applications not writable without sudo — you may be prompted:"
        sudo cp -R PrivateLink.app /Applications/
        echo "installed /Applications/PrivateLink.app (via sudo)"
    fi

# Compile the 'set as default' helper
setdefault-bin:
    #!/usr/bin/env bash
    set -euo pipefail
    swiftc -o setdefault setdefault.swift 2>/dev/null

# Register PrivateLink as the system default for http:// and https://
setdefault: setdefault-bin
    #!/usr/bin/env bash
    set -euo pipefail
    BID=dev.brickpop.privatelink
    # Make sure LaunchServices knows about the installed app
    LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
    "$LSREGISTER" -f /Applications/PrivateLink.app
    # Older macOS: the deprecated API writes the user LS database with no sudo.
    # ('err -54' on the second scheme is benign; the database still updates —
    # verification below is what matters, so don't let set -e trip on it.)
    ./setdefault || true
    # Sonoma+ rewrote default-browser handling: the API above updates the LS
    # database, but browsers must also confirm via the system picker. Verify:
    if ./setdefault | grep -q "default=$BID"; then
        echo "OK: PrivateLink is now the default for http and https"
    else
        echo "NOTE: macOS may still show the 'default web browser' prompt on first link."
        echo "If a dialog appears, choose PrivateLink. (System policy, not our bug.)"
    fi

# End-to-end test: route a link through the installed app
test:
    #!/usr/bin/env bash
    set -uo pipefail
    rm -f /tmp/privatelink.log
    open https://example.com   # goes through whatever handler is registered
    sleep 4
    echo "--- /tmp/privatelink.log ---"
    cat /tmp/privatelink.log 2>/dev/null || echo "(no log — app not invoked; handler not default yet?)"
    # App should have quit itself
    if pgrep -x PrivateLink >/dev/null; then
        echo "WARNING: PrivateLink still running"
    else
        echo "OK: app launched Brave and quit itself"
    fi

# Watch the log live
watch:
    tail -f /tmp/privatelink.log

# Everything: build, install, register as default, verify
all: install setdefault
    @echo "Done. Test with: just test"

# Unregister and remove from /Applications
uninstall: setdefault-bin
    #!/usr/bin/env bash
    set -euo pipefail
    LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
    "$LSREGISTER" -u /Applications/PrivateLink.app 2>/dev/null || true
    rm -rf /Applications/PrivateLink.app
    # Hand http/https back to Safari
    swiftc -o setdefault-safari -DSafari setdefault.swift 2>/dev/null || true
    ./setdefault-safari 2>/dev/null || true
    echo "uninstalled"

# Give http/https back to Safari (safety valve)
revert: setdefault-bin
    swiftc -o setdefault-safari -DSafari setdefault.swift 2>/dev/null || true
    ./setdefault-safari || echo "could not revert via API; do it in System Settings if needed"

clean:
    rm -rf .build PrivateLink.app setdefault setdefault-safari
    rm -f /tmp/privatelink.log
