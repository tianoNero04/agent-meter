#!/bin/bash
# Native UI smoke test. Open the menu popover with all three providers enabled first.
# Requires Accessibility permission for the terminal running this script.
set -euo pipefail
for spec in '2 CODEX' '3 KIMI CODE' '4 ANTIGRAVITY'; do
  index="${spec%% *}"
  expected="${spec#* }"
  point=$(osascript - "$index" <<'APPLESCRIPT'
on run argv
  tell application "System Events" to tell process "AgentUsageDashboard"
    set targetButton to button (item 1 of argv as integer) of group 1 of window 1
    set {x, y} to position of targetButton
    set {w, h} to size of targetButton
    return ((x + w / 2) as integer as text) & "," & ((y + h / 2) as integer as text)
  end tell
end run
APPLESCRIPT
)
  swift -e "import CoreGraphics; let p = CGPoint(x: ${point%,*}, y: ${point#*,}); for kind: CGEventType in [.leftMouseDown, .leftMouseUp] { CGEvent(mouseEventSource: nil, mouseType: kind, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap) }"
  osascript - "$expected" <<'APPLESCRIPT'
on run argv
  tell application "System Events" to tell process "AgentUsageDashboard"
    repeat 20 times
      if (value of every static text of group 1 of window 1) contains (item 1 of argv) then return
      delay 0.1
    end repeat
    error "Provider did not switch to " & item 1 of argv
  end tell
end run
APPLESCRIPT
  echo "PASS: $expected"
done
