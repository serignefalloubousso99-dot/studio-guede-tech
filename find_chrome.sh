# Sourced by the other scripts to set $CHROME to a working Chrome/Chromium
# binary, checking common install locations across Windows, macOS and
# Linux. Override by exporting CHROME yourself before running a script,
# e.g.: CHROME="/path/to/chrome" ./make_reel.sh ...

if [ -n "$CHROME" ] && [ -x "$CHROME" ]; then
  : # already set and valid, keep it
else
  CHROME=""
  for candidate in \
    "/c/Program Files/Google/Chrome/Application/chrome.exe" \
    "/c/Program Files (x86)/Google/Chrome/Application/chrome.exe" \
    "/c/Program Files/Microsoft/Edge/Application/msedge.exe" \
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
    "/Applications/Chromium.app/Contents/MacOS/Chromium" \
    "$(command -v google-chrome 2>/dev/null)" \
    "$(command -v google-chrome-stable 2>/dev/null)" \
    "$(command -v chromium 2>/dev/null)" \
    "$(command -v chromium-browser 2>/dev/null)"
  do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
      CHROME="$candidate"
      break
    fi
  done

  if [ -z "$CHROME" ]; then
    echo "Could not find Chrome/Chromium/Edge automatically." >&2
    echo "Install Google Chrome, or set CHROME=/path/to/chrome before running this script." >&2
    exit 1
  fi
fi
