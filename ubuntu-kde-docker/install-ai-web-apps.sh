#!/usr/bin/env bash
# Install a curated "AI App drawer" for the marketing-agency desktop.
#
# Most AI/automation marketing tools ship only as SaaS web apps, so we register
# them as app-mode (PWA-style) desktop launchers: each opens in its own Chrome
# window with the site's real favicon, appearing/behaving like an installed app.
# Native AI apps that DO exist on Linux (Claude Desktop, the AI CLIs) are handled
# separately in the Dockerfile. Runs at build time (network available); a failed
# icon download falls back to a generic icon and never fails the build.
set -u

APPDIR=/usr/share/applications
ICONDIR=/opt/ai-icons
mkdir -p "$ICONDIR"

# Generic fallback icon (simple globe) so a launcher is never icon-less.
cat > "$ICONDIR/_fallback.svg" <<'SVG'
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" fill="#6c5ce7"/><path d="M2 12h20M12 2a15 15 0 010 20M12 2a15 15 0 000 20" stroke="#fff" stroke-width="1.2" fill="none"/></svg>
SVG

# id | Display Name | URL | menu category tail
# Categories: X-AI-Assistant, X-AI-Creative, X-AI-Automation (grouped in menu).
APPS=$(cat <<'LIST'
rabeeb|Rabeeb|https://rabeeb.com/|X-AI-Assistant
chatgpt|ChatGPT|https://chatgpt.com/|X-AI-Assistant
claude-web|Claude (Web)|https://claude.ai/|X-AI-Assistant
gemini|Gemini|https://gemini.google.com/|X-AI-Assistant
perplexity|Perplexity|https://www.perplexity.ai/|X-AI-Assistant
grok|Grok|https://grok.com/|X-AI-Assistant
canva|Canva|https://www.canva.com/|X-AI-Creative
midjourney|Midjourney|https://www.midjourney.com/|X-AI-Creative
ideogram|Ideogram|https://ideogram.ai/|X-AI-Creative
runway|Runway|https://runwayml.com/|X-AI-Creative
sora|Sora|https://sora.com/|X-AI-Creative
elevenlabs|ElevenLabs|https://elevenlabs.io/|X-AI-Creative
heygen|HeyGen|https://www.heygen.com/|X-AI-Creative
capcut|CapCut|https://www.capcut.com/|X-AI-Creative
descript|Descript|https://www.descript.com/|X-AI-Creative
gamma|Gamma|https://gamma.app/|X-AI-Creative
suno|Suno|https://suno.com/|X-AI-Creative
figma|Figma|https://www.figma.com/|X-AI-Creative
adobe-express|Adobe Express|https://express.adobe.com/|X-AI-Creative
notion|Notion|https://www.notion.so/|X-AI-Automation
n8n|n8n|https://n8n.io/|X-AI-Automation
zapier|Zapier|https://zapier.com/app/dashboard|X-AI-Automation
make|Make|https://www.make.com/|X-AI-Automation
LIST
)

# Prefer google-chrome-stable; fall back to brave/chromium if absent.
BROWSER=google-chrome-stable
command -v "$BROWSER" >/dev/null 2>&1 || BROWSER=brave-browser
command -v "$BROWSER" >/dev/null 2>&1 || BROWSER=chromium

echo "$APPS" | while IFS='|' read -r id name url cat; do
    [ -z "$id" ] && continue
    domain=$(printf '%s' "$url" | sed -E 's#https?://([^/]+)/?.*#\1#')
    icon="$ICONDIR/$id.png"
    # Real logo via Google's favicon service (128px); fall back to generic.
    if ! curl -fsSL --max-time 20 "https://www.google.com/s2/favicons?domain=${domain}&sz=128" -o "$icon" 2>/dev/null \
        || ! [ -s "$icon" ]; then
        cp "$ICONDIR/_fallback.svg" "$ICONDIR/$id.svg"
        icon="$ICONDIR/$id.svg"
    fi
    cat > "$APPDIR/aiapp-$id.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$name
GenericName=AI web app
Comment=$name — opened as an app window
Exec=$BROWSER --app=$url --class=aiapp-$id --name=aiapp-$id %U
Icon=$icon
Terminal=false
StartupNotify=true
StartupWMClass=aiapp-$id
Categories=Network;$cat;
EOF
    echo "  + $name ($domain)"
done

echo "AI App drawer installed ($(ls "$APPDIR"/aiapp-*.desktop 2>/dev/null | wc -l) launchers)."
exit 0
