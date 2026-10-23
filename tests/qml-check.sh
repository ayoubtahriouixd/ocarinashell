#!/usr/bin/env bash
# Compile every QML file of the shell (or the ones given, relative to shell/) in a throwaway qs instance:
# Qt.createComponent() only parses and type-checks, nothing is instantiated, no window is shown and the
# running shell is untouched. Exit 1 if any file fails. Usage: tests/qml-check.sh [modules/x/Y.qml …]
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
work="$(mktemp -d "${TMPDIR:-/tmp}/ocarina-qmlcheck.XXXXXX")"
trap 'rm -rf "$work"' EXIT
cp -rL "$repo/shell/." "$work/"          # -L: components/OcarinaLogo.qml is a link into assets/

if (($#)); then
    files=("$@")
else
    mapfile -t files < <(cd "$work" && find . -name '*.qml' ! -name shell.qml ! -path './safe/*' -printf '%P\n' | sort)
fi

# the imports make qs generate the qs.* modules; the list goes through the environment
cat > "$work/shell.qml" <<'EOF'
import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

ShellRoot {
    Component.onCompleted: {
        let bad = 0;
        for (const f of Quickshell.env("QML_CHECK").split(" ")) {
            const c = Qt.createComponent(f, Component.PreferSynchronous);
            if (c.status !== Component.Ready) {
                bad++;
                console.info("QMLCHECK FAIL " + c.errorString().trim());
            }
        }
        console.info("QMLCHECK DONE " + bad);
        Qt.quit();
    }
}
EOF
# every module directory must be imported somewhere for qs to register it
for d in "$work"/modules/*/; do
    m="$(basename "$d")"
    sed -i "s|^import qs.services$|import qs.services\nimport qs.modules.$m|" "$work/shell.qml"
done

# Qt.quit() does not end a qs instance: wait for the summary line, then stop it
log="$work/.log"
(cd "$work" && QML_CHECK="${files[*]}" exec qs -p "$work" >"$log" 2>&1) &
qs_pid=$!
for _ in $(seq 600); do
    grep -q 'QMLCHECK DONE' "$log" 2>/dev/null && break
    kill -0 "$qs_pid" 2>/dev/null || break
    sleep 0.1
done
kill "$qs_pid" 2>/dev/null || true
wait "$qs_pid" 2>/dev/null || true
out="$(sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -E 'QMLCHECK' || true)"
grep 'QMLCHECK FAIL' <<<"$out" | sed 's/^.*QMLCHECK FAIL /✗ /' || true
bad="$(sed -n 's/^.*QMLCHECK DONE //p' <<<"$out")"
if [[ -z "$bad" ]]; then
    echo "qml-check: qs no terminó" >&2
    exit 1
fi
echo "qml-check: ${#files[@]} ficheros, $bad con errores"
[[ "$bad" == 0 ]]
