#!/bin/bash
set -euo pipefail

# KDE Plasma Desktop Optimization Script
echo "🖥️  Optimizing KDE Plasma for remote desktop performance..."

# Environment variables with defaults
DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_HOME="/home/${DEV_USERNAME}"

# Ensure user exists
if ! id "$DEV_USERNAME" >/dev/null 2>&1; then
    echo "⚠️  User $DEV_USERNAME not found, skipping KDE optimization"
    exit 0
fi

# Create KDE configuration directories
sudo -u "$DEV_USERNAME" mkdir -p "${DEV_HOME}/.config"
sudo -u "$DEV_USERNAME" mkdir -p "${DEV_HOME}/.kde/share/config"
sudo -u "$DEV_USERNAME" mkdir -p "${DEV_HOME}/.local/share/kservices5"

echo "🎨 Configuring KDE for optimal remote desktop performance..."

# Create optimized KDE configuration for remote desktop
cat > "${DEV_HOME}/.config/kwinrc" << 'EOF'
[Compositing]
Enabled=true
Backend=OpenGL
GLCore=false
HiddenPreviews=5
OpenGLIsUnsafe=false
WindowsBlockCompositing=true
AnimationSpeed=0

[Effect-Blur]
BlurStrength=1
NoiseStrength=0

[Effect-PresentWindows]
BorderActivate=9
BorderActivateAll=9
BorderActivateClass=9

[Effect-DesktopGrid]
BorderActivate=9
BorderActivateAll=9

[Plugins]
blurEnabled=false
contrastEnabled=false
dimscreenEnabled=false
highlightwindowEnabled=false
kwin4_effect_fadeEnabled=false
kwin4_effect_translucencyEnabled=false
minimizeanimationEnabled=false
slideEnabled=false
zoomEnabled=false
presentwindowsEnabled=false
desktopgridEnabled=false
boxswitchEnabled=false
coverswithEnabled=false
flipswithEnabled=false
glideEnabled=false
magiclampEnabled=false
scalingEnabled=false
sheetEnabled=false
slidebackEnabled=false
thumbnailasideEnabled=false
windowgeometryEnabled=false

[Windows]
AutoRaise=false
AutoRaiseInterval=750
BorderSnapZone=10
CenterSnapZone=0
DelayFocusInterval=300
SeparateScreenFocus=false
ActiveMouseScreen=true
FocusPolicy=ClickToFocus
FocusStealingPreventionLevel=1
GeometryTip=false
HideUtilityWindowsForInactive=true
InactiveTabsSkipTaskbar=false
MaximizeButtonLeftClickCommand=Maximize
MaximizeButtonMiddleClickCommand=Maximize (vertical only)
MaximizeButtonRightClickCommand=Maximize (horizontal only)
NextFocusPrefersMouse=false
Placement=Smart
SnapOnlyWhenOverlapping=false
TitlebarDoubleClickCommand=Maximize
WindowSnapZone=10
EOF

# Optimize Plasma desktop configuration
cat > "${DEV_HOME}/.config/plasmarc" << 'EOF'
[Theme]
name=breeze-dark

[Wallpapers]
usersWallpapers=

[PlasmaViews][Panel 1]
alignment=132
floating=0
panelOpacity=2

[PlasmaViews][Panel 1][Defaults]
thickness=36

[PlasmaViews][Panel 1][Horizontal1920]
thickness=36
EOF

# Configure lightweight panel and desktop effects
cat > "${DEV_HOME}/.config/plasma-org.kde.plasma.desktop-appletsrc" << 'EOF'
[ActionPlugins][0]
RightButton;NoModifier=org.kde.contextmenu

[ActionPlugins][1]
MidButton;NoModifier=org.kde.paste

[Containments][1]
activityId=
formfactor=0
immutability=1
lastScreen=0
location=0
plugin=org.kde.plasma.folder
wallpaperplugin=org.kde.color

[Containments][1][ConfigDialog]
DialogHeight=540
DialogWidth=720

[Containments][1][General]
ToolBoxButtonState=topcenter
ToolBoxButtonX=537

[Containments][1][Wallpaper][org.kde.color][General]
Color=30,30,30
EOF

# Optimize font rendering for screen sharing
sudo -u "$DEV_USERNAME" mkdir -p "${DEV_HOME}/.config/fontconfig"
cat > "${DEV_HOME}/.config/fontconfig/fonts.conf" << 'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "fonts.dtd">
<fontconfig>
  <match target="font">
    <edit name="antialias" mode="assign">
      <bool>true</bool>
    </edit>
    <edit name="hinting" mode="assign">
      <bool>true</bool>
    </edit>
    <edit name="hintstyle" mode="assign">
      <const>hintslight</const>
    </edit>
    <edit name="rgba" mode="assign">
      <const>rgb</const>
    </edit>
    <edit name="lcdfilter" mode="assign">
      <const>lcddefault</const>
    </edit>
  </match>
  <!-- Optimize for screen sharing -->
  <match target="font">
    <edit name="embeddedbitmap" mode="assign">
      <bool>false</bool>
    </edit>
  </match>
</fontconfig>
EOF

# Create performance-optimized Plasma theme configuration
cat > "${DEV_HOME}/.config/kdeglobals" << 'EOF'
[ColorEffects:Disabled]
Color=56,56,56
ColorAmount=0
ColorEffect=0
ContrastAmount=0.65
ContrastEffect=1
IntensityAmount=0.1
IntensityEffect=2

[ColorEffects:Inactive]
ChangeSelectionColor=true
Color=112,111,110
ColorAmount=0.025
ColorEffect=2
ContrastAmount=0.1
ContrastEffect=2
Enable=false
IntensityAmount=0
IntensityEffect=0

[Colors:Button]
BackgroundAlternate=64,69,82
BackgroundNormal=49,54,59
DecorationFocus=61,174,233
DecorationHover=61,174,233
ForegroundActive=61,174,233
ForegroundInactive=161,169,177
ForegroundLink=29,153,243
ForegroundNegative=218,68,83
ForegroundNeutral=246,116,0
ForegroundNormal=252,252,252
ForegroundPositive=39,174,96
ForegroundVisited=155,89,182

[Colors:Complementary]
BackgroundAlternate=30,87,116
BackgroundNormal=42,46,50
DecorationFocus=61,174,233
DecorationHover=61,174,233
ForegroundActive=61,174,233
ForegroundInactive=161,169,177
ForegroundLink=29,153,243
ForegroundNegative=218,68,83
ForegroundNeutral=246,116,0
ForegroundNormal=252,252,252
ForegroundPositive=39,174,96
ForegroundVisited=155,89,182

[Colors:Selection]
BackgroundAlternate=30,146,255
BackgroundNormal=61,174,233
DecorationFocus=61,174,233
DecorationHover=61,174,233
ForegroundActive=252,252,252
ForegroundInactive=161,169,177
ForegroundLink=253,188,75
ForegroundNegative=218,68,83
ForegroundNeutral=246,116,0
ForegroundNormal=252,252,252
ForegroundPositive=39,174,96
ForegroundVisited=155,89,182

[Colors:Tooltip]
BackgroundAlternate=77,77,77
BackgroundNormal=35,38,41
DecorationFocus=61,174,233
DecorationHover=61,174,233
ForegroundActive=61,174,233
ForegroundInactive=161,169,177
ForegroundLink=29,153,243
ForegroundNegative=218,68,83
ForegroundNeutral=246,116,0
ForegroundNormal=252,252,252
ForegroundPositive=39,174,96
ForegroundVisited=155,89,182

[Colors:View]
BackgroundAlternate=49,54,59
BackgroundNormal=35,38,41
DecorationFocus=61,174,233
DecorationHover=61,174,233
ForegroundActive=61,174,233
ForegroundInactive=161,169,177
ForegroundLink=29,153,243
ForegroundNegative=218,68,83
ForegroundNeutral=246,116,0
ForegroundNormal=252,252,252
ForegroundPositive=39,174,96
ForegroundVisited=155,89,182

[Colors:Window]
BackgroundAlternate=77,77,77
BackgroundNormal=49,54,59
DecorationFocus=61,174,233
DecorationHover=61,174,233
ForegroundActive=61,174,233
ForegroundInactive=161,169,177
ForegroundLink=29,153,243
ForegroundNegative=218,68,83
ForegroundNeutral=246,116,0
ForegroundNormal=252,252,252
ForegroundPositive=39,174,96
ForegroundVisited=155,89,182

[General]
ColorScheme=BreezeDark
Name=Breeze Dark
shadeSortColumn=true

[Icons]
Theme=breeze-dark

[KDE]
LookAndFeelPackage=org.kde.breezedark.desktop
ShowDeleteCommand=false
contrast=4

[KFileDialog Settings]
Allow Expansion=false
Automatically select filename extension=true
Breadcrumb Navigation=true
Decoration position=2
LocationCombo Completionmode=5
PathCombo Completionmode=5
Show Bookmarks=false
Show Full Path=false
Show Inline Previews=true
Show Preview=false
Show Speedbar=true
Show hidden files=false
Sort by=Name
Sort directories first=true
Sort reversed=false
Speedbar Width=138
View Style=Simple

[WM]
activeBackground=49,54,59
activeBlend=252,252,252
activeForeground=252,252,252
inactiveBackground=42,46,50
inactiveBlend=161,169,177
inactiveForeground=161,169,177
EOF

# Create lightweight window decoration configuration
cat > "${DEV_HOME}/.config/kwinrulesrc" << 'EOF'
[1]
Description=Optimize all windows for remote desktop
clientmachine=localhost
clientmachinematch=1
types=1
wmclass=.*
wmclasscomplete=false
wmclassmatch=3
noborder=true
noborderrule=2
skiptaskbar=false
skiptaskbarrule=2
skippager=false
skippagerrule=2
skipswitcher=false
skipswitcherrule=2
above=false
aboverule=2
below=false
belowrule=2
fullscreen=false
fullscreenrule=2
maximize=false
maximizerule=2
minimizehoriz=false
minimizehorizrule=2
minimizevert=false
minimizevertrule=2
shade=false
shaderule=2
closeable=true
closeablerule=2
autogroup=false
autogrouprule=2
autogroupfg=true
autogroupfgrule=2
autogroupid=
autogroupidrule=2
strictgeometry=false
strictgeometryrule=2
shortcut=
shortcutrule=2
disableglobalshortcuts=false
disableglobalshortcutsrule=2
EOF

# Set proper ownership of all configuration files
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DEV_HOME}/.config"
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DEV_HOME}/.kde" 2>/dev/null || true
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DEV_HOME}/.local" 2>/dev/null || true

# Create KDE startup optimization script
cat > /usr/local/bin/kde-startup-optimizer << 'EOF'
#!/bin/bash
set -euo pipefail

echo "⚡ Optimizing KDE startup for remote desktop..."

# Set environment variables for optimal KDE performance
export KWIN_COMPOSE=O2
export KWIN_TRIPLE_BUFFER=1
export __GL_YIELD="USLEEP"
export __GL_THREADED_OPTIMIZATIONS=1

# Disable splash screen for faster startup
export KDE_SPLASH=false

# Optimize Qt graphics system
export QT_GRAPHICSSYSTEM=native
export QT_XCB_GL_INTEGRATION=xcb_egl

echo "✅ KDE startup optimization environment configured"
EOF

chmod +x /usr/local/bin/kde-startup-optimizer

echo "🔧 KDE Plasma desktop optimization setup complete"
echo "🎨 Visual effects and animations disabled for better performance"
echo "🖼️  Lightweight theme and window decorations configured"
echo "⚡ Font rendering optimized for screen sharing"
echo "✅ KDE Plasma optimization completed"
