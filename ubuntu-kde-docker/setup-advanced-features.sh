#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_HOME="/home/${DEV_USERNAME}"

# Logging function
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ADVANCED-FEATURES] $*"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ADVANCED-FEATURES ERROR] $*" >&2
}

log_info "Setting up advanced remote desktop features..."

# Create feature directories
mkdir -p \
    "/opt/advanced-features" \
    "/opt/advanced-features/clipboard" \
    "/opt/advanced-features/file-transfer" \
    "/opt/advanced-features/multimonitor" \
    "/opt/advanced-features/recording" \
    "/opt/advanced-features/mobile"

# Enhanced Clipboard Synchronization with File Support
cat > "/opt/advanced-features/clipboard/enhanced-clipboard.py" << 'EOF'
#!/usr/bin/env python3
import os
import time
import json
import base64
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
import socketserver
import subprocess
import tempfile

class ClipboardHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/clipboard':
            try:
                # Get clipboard content
                result = subprocess.run(['xclip', '-selection', 'clipboard', '-o'], 
                                      capture_output=True, text=True)
                content = result.stdout
                
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                
                response = {'type': 'text', 'content': content}
                self.wfile.write(json.dumps(response).encode())
            except Exception as e:
                self.send_error(500, f"Clipboard error: {str(e)}")
    
    def do_POST(self):
        if self.path == '/clipboard':
            try:
                content_length = int(self.headers['Content-Length'])
                post_data = self.rfile.read(content_length)
                data = json.loads(post_data.decode())
                
                if data['type'] == 'text':
                    # Set clipboard text
                    proc = subprocess.Popen(['xclip', '-selection', 'clipboard'], 
                                          stdin=subprocess.PIPE)
                    proc.communicate(data['content'].encode())
                elif data['type'] == 'file':
                    # Handle file clipboard
                    file_data = base64.b64decode(data['content'])
                    temp_file = tempfile.NamedTemporaryFile(delete=False, 
                                                          suffix=data.get('extension', ''))
                    temp_file.write(file_data)
                    temp_file.close()
                    
                    # Set file path to clipboard
                    proc = subprocess.Popen(['xclip', '-selection', 'clipboard'], 
                                          stdin=subprocess.PIPE)
                    proc.communicate(temp_file.name.encode())
                
                self.send_response(200)
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(b'{"status": "success"}')
                
            except Exception as e:
                self.send_error(500, f"Clipboard set error: {str(e)}")

if __name__ == '__main__':
    PORT = 8082
    with socketserver.TCPServer(("", PORT), ClipboardHandler) as httpd:
        print(f"Enhanced clipboard server running on port {PORT}")
        httpd.serve_forever()
EOF

# File Transfer System with Drag & Drop
cat > "/opt/advanced-features/file-transfer/file-transfer-server.py" << 'EOF'
#!/usr/bin/env python3
import os
import json
import base64
from http.server import HTTPServer, BaseHTTPRequestHandler
import socketserver
import tempfile
import shutil

class FileTransferHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/upload':
            try:
                content_length = int(self.headers['Content-Length'])
                post_data = self.rfile.read(content_length)
                data = json.loads(post_data.decode())
                
                # Create upload directory
                upload_dir = "/home/devuser/Desktop/Uploads"
                os.makedirs(upload_dir, exist_ok=True)
                
                # Save uploaded file
                file_data = base64.b64decode(data['content'])
                file_path = os.path.join(upload_dir, data['filename'])
                
                with open(file_path, 'wb') as f:
                    f.write(file_data)
                
                # Set proper permissions
                shutil.chown(file_path, user='devuser', group='devuser')
                
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                
                response = {'status': 'success', 'path': file_path}
                self.wfile.write(json.dumps(response).encode())
                
            except Exception as e:
                self.send_error(500, f"Upload error: {str(e)}")
    
    def do_GET(self):
        if self.path.startswith('/download/'):
            try:
                file_path = self.path.replace('/download/', '/home/devuser/Desktop/')
                
                if os.path.exists(file_path) and os.path.isfile(file_path):
                    with open(file_path, 'rb') as f:
                        file_data = f.read()
                    
                    encoded_data = base64.b64encode(file_data).decode()
                    
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.end_headers()
                    
                    response = {
                        'status': 'success',
                        'filename': os.path.basename(file_path),
                        'content': encoded_data
                    }
                    self.wfile.write(json.dumps(response).encode())
                else:
                    self.send_error(404, "File not found")
                    
            except Exception as e:
                self.send_error(500, f"Download error: {str(e)}")

if __name__ == '__main__':
    PORT = 8083
    with socketserver.TCPServer(("", PORT), FileTransferHandler) as httpd:
        print(f"File transfer server running on port {PORT}")
        httpd.serve_forever()
EOF

# Multi-Monitor Virtual Display Manager
cat > "/opt/advanced-features/multimonitor/monitor-manager.sh" << 'EOF'
#!/bin/bash

# Multi-monitor configuration for virtual displays
setup_virtual_monitors() {
    log_info "Setting up virtual multi-monitor configuration..."
    
    # Create additional virtual screens
    export DISPLAY=:0
    
    # Primary monitor (existing)
    xrandr --addmode VNC-0 1920x1080
    
    # Add secondary virtual monitor
    xrandr --newmode "1920x1080_60.00_secondary" 173.00 1920 2048 2248 2576 1080 1083 1088 1120 -hsync +vsync
    xrandr --addmode VNC-1 "1920x1080_60.00_secondary" 2>/dev/null || true
    
    # Configure dual monitor layout
    xrandr --output VNC-0 --mode 1920x1080 --pos 0x0 --primary
    xrandr --output VNC-1 --mode "1920x1080_60.00_secondary" --pos 1920x0 2>/dev/null || true
    
    log_info "Virtual multi-monitor setup complete"
}

# Dynamic monitor switching
switch_monitor_layout() {
    local layout="$1"
    export DISPLAY=:0
    
    case "$layout" in
        "single")
            xrandr --output VNC-0 --mode 1920x1080 --pos 0x0 --primary
            xrandr --output VNC-1 --off 2>/dev/null || true
            ;;
        "dual-horizontal")
            xrandr --output VNC-0 --mode 1920x1080 --pos 0x0 --primary
            xrandr --output VNC-1 --mode "1920x1080_60.00_secondary" --pos 1920x0 2>/dev/null || true
            ;;
        "dual-vertical")
            xrandr --output VNC-0 --mode 1920x1080 --pos 0x0 --primary
            xrandr --output VNC-1 --mode "1920x1080_60.00_secondary" --pos 0x1080 2>/dev/null || true
            ;;
    esac
}

# HTTP API for monitor control
cat > "/opt/advanced-features/multimonitor/monitor-api.py" << 'PYEOF'
#!/usr/bin/env python3
import subprocess
import json
from http.server import HTTPServer, BaseHTTPRequestHandler
import socketserver

class MonitorHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/monitor/layout':
            try:
                content_length = int(self.headers['Content-Length'])
                post_data = self.rfile.read(content_length)
                data = json.loads(post_data.decode())
                
                layout = data.get('layout', 'single')
                
                # Call monitor switch script
                subprocess.run(['/opt/advanced-features/multimonitor/monitor-manager.sh', 
                              'switch_monitor_layout', layout], check=True)
                
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                
                response = {'status': 'success', 'layout': layout}
                self.wfile.write(json.dumps(response).encode())
                
            except Exception as e:
                self.send_error(500, f"Monitor layout error: {str(e)}")

if __name__ == '__main__':
    PORT = 8084
    with socketserver.TCPServer(("", PORT), MonitorHandler) as httpd:
        print(f"Monitor API server running on port {PORT}")
        httpd.serve_forever()
PYEOF

# Make scripts executable

if [ -f /opt/advanced-features/multimonitor/monitor-manager.sh ]; then
    chmod +x /opt/advanced-features/multimonitor/monitor-manager.sh
fi

# Setup virtual monitors
setup_virtual_monitors
EOF

# Session Recording and Playback System
cat > "/opt/advanced-features/recording/session-recorder.sh" << 'EOF'
#!/bin/bash

RECORD_DIR="/home/devuser/Desktop/Recordings"
mkdir -p "$RECORD_DIR"

# Start session recording
start_recording() {
    local session_name="${1:-session_$(date +%Y%m%d_%H%M%S)}"
    local output_file="$RECORD_DIR/${session_name}.mp4"
    
    # Record X11 session with ffmpeg
    ffmpeg -f x11grab -s 1920x1080 -i :0.0 \
           -f pulse -i default \
           -c:v libx264 -preset ultrafast -crf 23 \
           -c:a aac -b:a 128k \
           "$output_file" &
    
    echo $! > "/tmp/recording_${session_name}.pid"
    log_info "Started recording session: $session_name"
}

# Stop session recording
stop_recording() {
    local session_name="$1"
    local pid_file="/tmp/recording_${session_name}.pid"
    
    if [ -f "$pid_file" ]; then
        local pid=$(cat "$pid_file")
        kill "$pid" 2>/dev/null || true
        rm "$pid_file"
        log_info "Stopped recording session: $session_name"
    fi
}

# HTTP API for recording control
cat > "/opt/advanced-features/recording/recording-api.py" << 'PYEOF'
#!/usr/bin/env python3
import subprocess
import json
import os
from http.server import HTTPServer, BaseHTTPRequestHandler
import socketserver

class RecordingHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == '/recording/start':
            try:
                content_length = int(self.headers['Content-Length'])
                post_data = self.rfile.read(content_length)
                data = json.loads(post_data.decode())
                
                session_name = data.get('session_name', f"session_{int(time.time())}")
                
                subprocess.run(['/opt/advanced-features/recording/session-recorder.sh', 
                              'start_recording', session_name], check=True)
                
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                
                response = {'status': 'success', 'session': session_name}
                self.wfile.write(json.dumps(response).encode())
                
            except Exception as e:
                self.send_error(500, f"Recording start error: {str(e)}")
        
        elif self.path == '/recording/stop':
            try:
                content_length = int(self.headers['Content-Length'])
                post_data = self.rfile.read(content_length)
                data = json.loads(post_data.decode())
                
                session_name = data.get('session_name')
                
                subprocess.run(['/opt/advanced-features/recording/session-recorder.sh', 
                              'stop_recording', session_name], check=True)
                
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                
                response = {'status': 'success', 'session': session_name}
                self.wfile.write(json.dumps(response).encode())
                
            except Exception as e:
                self.send_error(500, f"Recording stop error: {str(e)}")

if __name__ == '__main__':
    PORT = 8085
    with socketserver.TCPServer(("", PORT), RecordingHandler) as httpd:
        print(f"Recording API server running on port {PORT}")
        httpd.serve_forever()
PYEOF

chmod +x /opt/advanced-features/recording/session-recorder.sh
EOF

# Mobile Touch and Gesture Support
cat > "/opt/advanced-features/mobile/touch-handler.js" << 'EOF'
// Enhanced mobile touch and gesture support for KasmVNC
class MobileTouchHandler {
    constructor() {
        this.setupTouchGestures();
        this.setupVirtualKeyboard();
        this.setupMobileOptimizations();
    }
    
    setupTouchGestures() {
        // Two-finger scroll
        document.addEventListener('touchstart', this.handleTouchStart.bind(this), {passive: false});
        document.addEventListener('touchmove', this.handleTouchMove.bind(this), {passive: false});
        document.addEventListener('touchend', this.handleTouchEnd.bind(this), {passive: false});
        
        // Pinch to zoom
        this.setupPinchZoom();
        
        // Long press for right-click
        this.setupLongPress();
    }
    
    handleTouchStart(e) {
        this.touchStartTime = Date.now();
        this.touchStartPos = {
            x: e.touches[0].clientX,
            y: e.touches[0].clientY
        };
        
        if (e.touches.length === 2) {
            this.twoFingerStart = {
                x1: e.touches[0].clientX,
                y1: e.touches[0].clientY,
                x2: e.touches[1].clientX,
                y2: e.touches[1].clientY
            };
        }
    }
    
    handleTouchMove(e) {
        if (e.touches.length === 2 && this.twoFingerStart) {
            // Two-finger scroll
            const deltaY = (e.touches[0].clientY + e.touches[1].clientY) / 2 - 
                          (this.twoFingerStart.y1 + this.twoFingerStart.y2) / 2;
            
            // Simulate scroll wheel
            const scrollEvent = new WheelEvent('wheel', {
                deltaY: -deltaY * 3,
                clientX: (e.touches[0].clientX + e.touches[1].clientX) / 2,
                clientY: (e.touches[0].clientY + e.touches[1].clientY) / 2
            });
            
            document.dispatchEvent(scrollEvent);
            e.preventDefault();
        }
    }
    
    handleTouchEnd(e) {
        // Reset touch tracking
        this.twoFingerStart = null;
    }
    
    setupPinchZoom() {
        let lastPinchDistance = 0;
        
        document.addEventListener('touchmove', (e) => {
            if (e.touches.length === 2) {
                const distance = Math.sqrt(
                    Math.pow(e.touches[0].clientX - e.touches[1].clientX, 2) +
                    Math.pow(e.touches[0].clientY - e.touches[1].clientY, 2)
                );
                
                if (lastPinchDistance > 0) {
                    const scale = distance / lastPinchDistance;
                    // Apply zoom to KasmVNC viewport
                    if (window.rfb && window.rfb.clipViewport) {
                        const currentScale = window.rfb.scale;
                        window.rfb.scale = Math.max(0.1, Math.min(3.0, currentScale * scale));
                    }
                }
                
                lastPinchDistance = distance;
                e.preventDefault();
            }
        });
        
        document.addEventListener('touchend', () => {
            lastPinchDistance = 0;
        });
    }
    
    setupLongPress() {
        let longPressTimer;
        
        document.addEventListener('touchstart', (e) => {
            longPressTimer = setTimeout(() => {
                // Trigger right-click context menu
                const rightClickEvent = new MouseEvent('contextmenu', {
                    clientX: e.touches[0].clientX,
                    clientY: e.touches[0].clientY,
                    button: 2
                });
                
                e.target.dispatchEvent(rightClickEvent);
            }, 500);
        });
        
        document.addEventListener('touchend', () => {
            clearTimeout(longPressTimer);
        });
        
        document.addEventListener('touchmove', () => {
            clearTimeout(longPressTimer);
        });
    }
    
    setupVirtualKeyboard() {
        // Create virtual keyboard toggle
        const keyboardToggle = document.createElement('button');
        keyboardToggle.innerHTML = '⌨️';
        keyboardToggle.style.cssText = `
            position: fixed;
            bottom: 20px;
            right: 20px;
            z-index: 10000;
            background: rgba(0,0,0,0.7);
            color: white;
            border: none;
            border-radius: 50%;
            width: 50px;
            height: 50px;
            font-size: 20px;
        `;
        
        keyboardToggle.addEventListener('click', () => {
            // Focus on hidden input to trigger mobile keyboard
            const hiddenInput = document.getElementById('mobile-keyboard-input') || 
                               this.createHiddenInput();
            hiddenInput.focus();
        });
        
        document.body.appendChild(keyboardToggle);
    }
    
    createHiddenInput() {
        const input = document.createElement('input');
        input.id = 'mobile-keyboard-input';
        input.style.cssText = `
            position: fixed;
            top: -100px;
            left: -100px;
            opacity: 0;
            pointer-events: none;
        `;
        
        input.addEventListener('input', (e) => {
            // Forward keyboard input to KasmVNC
            if (window.rfb) {
                for (let char of e.target.value) {
                    window.rfb.sendKey(char.charCodeAt(0));
                }
                e.target.value = '';
            }
        });
        
        document.body.appendChild(input);
        return input;
    }
    
    setupMobileOptimizations() {
        // Prevent mobile browser zoom on double-tap
        document.addEventListener('touchend', (e) => {
            e.preventDefault();
        });
        
        // Optimize viewport for mobile
        const viewport = document.querySelector('meta[name="viewport"]');
        if (viewport) {
            viewport.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';
        }
        
        // Add mobile-specific CSS
        const mobileStyles = document.createElement('style');
        mobileStyles.textContent = `
            @media (max-width: 768px) {
                body { overflow: hidden; }
                #KasmVNC_container { 
                    width: 100vw !important;
                    height: 100vh !important;
                }
                .KasmVNC_status { font-size: 16px !important; }
            }
        `;
        document.head.appendChild(mobileStyles);
    }
}

// Initialize mobile touch handler when DOM is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        new MobileTouchHandler();
    });
} else {
    new MobileTouchHandler();
}
EOF

# Make Python scripts executable
if [ -f /opt/advanced-features/clipboard/enhanced-clipboard.py ]; then
    chmod +x /opt/advanced-features/clipboard/enhanced-clipboard.py
fi
if [ -f /opt/advanced-features/file-transfer/file-transfer-server.py ]; then
    chmod +x /opt/advanced-features/file-transfer/file-transfer-server.py
fi
if [ -f /opt/advanced-features/multimonitor/monitor-api.py ]; then
    chmod +x /opt/advanced-features/multimonitor/monitor-api.py
fi
if [ -f /opt/advanced-features/recording/recording-api.py ]; then
    chmod +x /opt/advanced-features/recording/recording-api.py
fi

# Set ownership
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/opt/advanced-features"
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DEV_HOME}/Desktop"

log_info "Advanced features setup complete"
log_info "Services available on ports:"
log_info "- Enhanced Clipboard: 8082"
log_info "- File Transfer: 8083" 
log_info "- Monitor API: 8084"
log_info "- Recording API: 8085"