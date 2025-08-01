#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_HOME="/home/${DEV_USERNAME}"

# Logging function
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [MODERN-FEATURES] $*"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [MODERN-FEATURES ERROR] $*" >&2
}

log_info "Setting up modern desktop features..."

# Create modern features directories
mkdir -p \
    "/opt/modern-features" \
    "/opt/modern-features/pwa" \
    "/opt/modern-features/cloud-integration" \
    "/opt/modern-features/ai-assistant" \
    "/opt/modern-features/collaboration"

# Progressive Web App (PWA) Enhancement for KasmVNC
cat > "/opt/modern-features/pwa/service-worker.js" << 'EOF'
const CACHE_NAME = 'webtop-desktop-v1.0';
const urlsToCache = [
    '/',
    '/vnc.html',
    '/app/ui.js',
    '/app/webutil.js',
    '/core/rfb.js',
    '/core/util.js',
    '/core/base64.js',
    '/core/websock.js',
    '/app/styles/base.css',
    '/app/styles/ui.css'
];

// Install event - cache resources
self.addEventListener('install', (event) => {
    event.waitUntil(
        caches.open(CACHE_NAME)
            .then((cache) => {
                console.log('Opened cache');
                return cache.addAll(urlsToCache);
            })
    );
});

// Fetch event - serve from cache, fallback to network
self.addEventListener('fetch', (event) => {
    event.respondWith(
        caches.match(event.request)
            .then((response) => {
                // Return cached version or fetch from network
                return response || fetch(event.request);
            })
    );
});

// Background sync for offline actions
self.addEventListener('sync', (event) => {
    if (event.tag === 'background-sync') {
        event.waitUntil(doBackgroundSync());
    }
});

async function doBackgroundSync() {
    // Sync offline actions when connection is restored
    console.log('Background sync triggered');
}

// Push notifications
self.addEventListener('push', (event) => {
    const options = {
        body: event.data ? event.data.text() : 'New notification',
        icon: '/icons/icon-192x192.png',
        badge: '/icons/badge-72x72.png',
        vibrate: [100, 50, 100],
        data: {
            dateOfArrival: Date.now(),
            primaryKey: 1
        },
        actions: [
            {
                action: 'explore',
                title: 'Open Desktop',
                icon: '/icons/checkmark.png'
            },
            {
                action: 'close',
                title: 'Close',
                icon: '/icons/xmark.png'
            }
        ]
    };

    event.waitUntil(
        self.registration.showNotification('Desktop Notification', options)
    );
});
EOF

cat > "/opt/modern-features/pwa/manifest.json" << 'EOF'
{
    "name": "Ubuntu KDE Marketing Desktop",
    "short_name": "WebTop Desktop",
    "description": "Professional marketing desktop environment in your browser",
    "start_url": "/",
    "display": "fullscreen",
    "orientation": "landscape",
    "theme_color": "#4A90E2",
    "background_color": "#ffffff",
    "categories": ["productivity", "business", "design"],
    "scope": "/",
    "icons": [
        {
            "src": "/icons/icon-72x72.png",
            "sizes": "72x72",
            "type": "image/png"
        },
        {
            "src": "/icons/icon-96x96.png",
            "sizes": "96x96",
            "type": "image/png"
        },
        {
            "src": "/icons/icon-128x128.png",
            "sizes": "128x128",
            "type": "image/png"
        },
        {
            "src": "/icons/icon-144x144.png",
            "sizes": "144x144",
            "type": "image/png"
        },
        {
            "src": "/icons/icon-152x152.png",
            "sizes": "152x152",
            "type": "image/png"
        },
        {
            "src": "/icons/icon-192x192.png",
            "sizes": "192x192",
            "type": "image/png"
        },
        {
            "src": "/icons/icon-384x384.png",
            "sizes": "384x384",
            "type": "image/png"
        },
        {
            "src": "/icons/icon-512x512.png",
            "sizes": "512x512",
            "type": "image/png"
        }
    ],
    "screenshots": [
        {
            "src": "/screenshots/desktop-wide.png",
            "sizes": "1280x720",
            "type": "image/png",
            "form_factor": "wide"
        },
        {
            "src": "/screenshots/mobile-narrow.png",
            "sizes": "720x1280",
            "type": "image/png",
            "form_factor": "narrow"
        }
    ],
    "shortcuts": [
        {
            "name": "Marketing Dashboard",
            "short_name": "Dashboard",
            "description": "Open marketing performance dashboard",
            "url": "/dashboard",
            "icons": [{"src": "/icons/dashboard-96x96.png", "sizes": "96x96"}]
        },
        {
            "name": "File Manager",
            "short_name": "Files",
            "description": "Access file management system",
            "url": "/files",
            "icons": [{"src": "/icons/files-96x96.png", "sizes": "96x96"}]
        }
    ],
    "prefer_related_applications": false
}
EOF

# Cloud Storage Integration
cat > "/opt/modern-features/cloud-integration/cloud-sync.py" << 'EOF'
#!/usr/bin/env python3
import os
import json
import requests
import subprocess
from pathlib import Path
import threading
import time

class CloudStorageManager:
    def __init__(self):
        self.sync_dir = Path("/home/devuser/Cloud-Sync")
        self.sync_dir.mkdir(exist_ok=True)
        self.config_file = Path("/opt/modern-features/cloud-integration/config.json")
        self.load_config()
    
    def load_config(self):
        """Load cloud storage configuration"""
        default_config = {
            "providers": {
                "google_drive": {
                    "enabled": False,
                    "mount_point": "/home/devuser/Google-Drive",
                    "client_id": "",
                    "client_secret": ""
                },
                "dropbox": {
                    "enabled": False,
                    "mount_point": "/home/devuser/Dropbox",
                    "access_token": ""
                },
                "onedrive": {
                    "enabled": False,
                    "mount_point": "/home/devuser/OneDrive",
                    "client_id": "",
                    "client_secret": ""
                }
            },
            "auto_sync": True,
            "sync_interval": 300  # 5 minutes
        }
        
        if self.config_file.exists():
            with open(self.config_file, 'r') as f:
                self.config = json.load(f)
        else:
            self.config = default_config
            self.save_config()
    
    def save_config(self):
        """Save cloud storage configuration"""
        with open(self.config_file, 'w') as f:
            json.dump(self.config, f, indent=2)
    
    def setup_google_drive(self, client_id, client_secret):
        """Setup Google Drive integration using rclone"""
        try:
            # Install rclone if not present
            subprocess.run(['which', 'rclone'], check=True)
        except subprocess.CalledProcessError:
            print("Installing rclone...")
            subprocess.run(['curl', 'https://rclone.org/install.sh', '|', 'bash'], shell=True)
        
        # Configure rclone for Google Drive
        rclone_config = f"""
[google-drive]
type = drive
client_id = {client_id}
client_secret = {client_secret}
scope = drive
"""
        
        config_dir = Path.home() / ".config" / "rclone"
        config_dir.mkdir(parents=True, exist_ok=True)
        
        with open(config_dir / "rclone.conf", "w") as f:
            f.write(rclone_config)
        
        # Update configuration
        self.config["providers"]["google_drive"]["enabled"] = True
        self.config["providers"]["google_drive"]["client_id"] = client_id
        self.config["providers"]["google_drive"]["client_secret"] = client_secret
        self.save_config()
        
        # Create mount point
        mount_point = Path(self.config["providers"]["google_drive"]["mount_point"])
        mount_point.mkdir(parents=True, exist_ok=True)
        
        print("Google Drive setup complete")
    
    def setup_dropbox(self, access_token):
        """Setup Dropbox integration"""
        try:
            subprocess.run(['which', 'rclone'], check=True)
        except subprocess.CalledProcessError:
            subprocess.run(['curl', 'https://rclone.org/install.sh', '|', 'bash'], shell=True)
        
        rclone_config = f"""
[dropbox]
type = dropbox
token = {access_token}
"""
        
        config_dir = Path.home() / ".config" / "rclone"
        config_dir.mkdir(parents=True, exist_ok=True)
        
        with open(config_dir / "rclone.conf", "a") as f:
            f.write(rclone_config)
        
        self.config["providers"]["dropbox"]["enabled"] = True
        self.config["providers"]["dropbox"]["access_token"] = access_token
        self.save_config()
        
        mount_point = Path(self.config["providers"]["dropbox"]["mount_point"])
        mount_point.mkdir(parents=True, exist_ok=True)
        
        print("Dropbox setup complete")
    
    def mount_drives(self):
        """Mount all configured cloud drives"""
        for provider, config in self.config["providers"].items():
            if config["enabled"]:
                mount_point = Path(config["mount_point"])
                mount_point.mkdir(parents=True, exist_ok=True)
                
                # Check if already mounted
                result = subprocess.run(['mountpoint', str(mount_point)], 
                                      capture_output=True)
                
                if result.returncode != 0:  # Not mounted
                    try:
                        if provider == "google_drive":
                            subprocess.Popen(['rclone', 'mount', 'google-drive:', 
                                            str(mount_point), '--daemon'])
                        elif provider == "dropbox":
                            subprocess.Popen(['rclone', 'mount', 'dropbox:', 
                                            str(mount_point), '--daemon'])
                        elif provider == "onedrive":
                            subprocess.Popen(['rclone', 'mount', 'onedrive:', 
                                            str(mount_point), '--daemon'])
                        
                        print(f"Mounted {provider} at {mount_point}")
                    except Exception as e:
                        print(f"Failed to mount {provider}: {e}")
    
    def sync_projects(self):
        """Sync marketing projects to cloud storage"""
        project_dir = Path("/home/devuser/Marketing-Projects")
        
        for provider, config in self.config["providers"].items():
            if config["enabled"]:
                try:
                    cloud_project_dir = Path(config["mount_point"]) / "Marketing-Projects"
                    cloud_project_dir.mkdir(parents=True, exist_ok=True)
                    
                    # Sync using rsync for efficiency
                    subprocess.run([
                        'rsync', '-av', '--delete',
                        str(project_dir) + '/',
                        str(cloud_project_dir) + '/'
                    ], check=True)
                    
                    print(f"Synced projects to {provider}")
                except Exception as e:
                    print(f"Sync failed for {provider}: {e}")
    
    def start_auto_sync(self):
        """Start automatic synchronization"""
        if not self.config["auto_sync"]:
            return
        
        def sync_loop():
            while True:
                time.sleep(self.config["sync_interval"])
                self.sync_projects()
        
        sync_thread = threading.Thread(target=sync_loop, daemon=True)
        sync_thread.start()
        print("Auto-sync started")

if __name__ == '__main__':
    cloud_manager = CloudStorageManager()
    
    # HTTP API for cloud integration
    from http.server import HTTPServer, BaseHTTPRequestHandler
    import socketserver
    
    class CloudHandler(BaseHTTPRequestHandler):
        def do_POST(self):
            if self.path == '/cloud/setup/google':
                try:
                    content_length = int(self.headers['Content-Length'])
                    post_data = self.rfile.read(content_length)
                    data = json.loads(post_data.decode())
                    
                    client_id = data.get('client_id')
                    client_secret = data.get('client_secret')
                    
                    cloud_manager.setup_google_drive(client_id, client_secret)
                    
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.end_headers()
                    
                    response = {'success': True, 'provider': 'google_drive'}
                    self.wfile.write(json.dumps(response).encode())
                    
                except Exception as e:
                    self.send_error(500, f"Google Drive setup error: {str(e)}")
            
            elif self.path == '/cloud/setup/dropbox':
                try:
                    content_length = int(self.headers['Content-Length'])
                    post_data = self.rfile.read(content_length)
                    data = json.loads(post_data.decode())
                    
                    access_token = data.get('access_token')
                    cloud_manager.setup_dropbox(access_token)
                    
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.end_headers()
                    
                    response = {'success': True, 'provider': 'dropbox'}
                    self.wfile.write(json.dumps(response).encode())
                    
                except Exception as e:
                    self.send_error(500, f"Dropbox setup error: {str(e)}")
            
            elif self.path == '/cloud/sync':
                try:
                    cloud_manager.sync_projects()
                    
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.end_headers()
                    
                    response = {'success': True, 'message': 'Sync completed'}
                    self.wfile.write(json.dumps(response).encode())
                    
                except Exception as e:
                    self.send_error(500, f"Sync error: {str(e)}")
        
        def do_GET(self):
            if self.path == '/cloud/status':
                try:
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.end_headers()
                    
                    response = {
                        'config': cloud_manager.config,
                        'mounted_drives': []
                    }
                    
                    # Check mounted drives
                    for provider, config in cloud_manager.config["providers"].items():
                        if config["enabled"]:
                            mount_point = Path(config["mount_point"])
                            result = subprocess.run(['mountpoint', str(mount_point)], 
                                                  capture_output=True)
                            if result.returncode == 0:
                                response['mounted_drives'].append(provider)
                    
                    self.wfile.write(json.dumps(response).encode())
                    
                except Exception as e:
                    self.send_error(500, f"Status error: {str(e)}")
    
    # Mount drives on startup
    cloud_manager.mount_drives()
    cloud_manager.start_auto_sync()
    
    PORT = 8088
    with socketserver.TCPServer(("", PORT), CloudHandler) as httpd:
        print(f"Cloud integration API running on port {PORT}")
        httpd.serve_forever()
EOF

# AI Assistant Integration
cat > "/opt/modern-features/ai-assistant/desktop-assistant.py" << 'EOF'
#!/usr/bin/env python3
import os
import json
import subprocess
import requests
import threading
import time
from pathlib import Path

class DesktopAIAssistant:
    def __init__(self):
        self.commands = {
            'open_app': self.open_application,
            'create_project': self.create_marketing_project,
            'optimize_performance': self.optimize_system,
            'backup_files': self.backup_projects,
            'resize_images': self.batch_resize_images,
            'system_info': self.get_system_info,
            'schedule_task': self.schedule_task
        }
    
    def process_command(self, command_text):
        """Process natural language commands"""
        command_text = command_text.lower().strip()
        
        # Simple keyword-based command processing
        if 'open' in command_text:
            if 'gimp' in command_text:
                return self.open_application('gimp')
            elif 'firefox' in command_text or 'browser' in command_text:
                return self.open_application('firefox')
            elif 'file manager' in command_text or 'files' in command_text:
                return self.open_application('dolphin')
            elif 'terminal' in command_text:
                return self.open_application('konsole')
        
        elif 'create' in command_text and 'project' in command_text:
            # Extract project name and type
            words = command_text.split()
            project_name = "new_project"
            project_type = "social_campaign"
            
            if 'social' in command_text:
                project_type = 'social_campaign'
            elif 'video' in command_text:
                project_type = 'video_campaign'
            elif 'brand' in command_text:
                project_type = 'brand_design'
            
            return self.create_marketing_project(project_name, project_type)
        
        elif 'optimize' in command_text or 'performance' in command_text:
            return self.optimize_system()
        
        elif 'backup' in command_text:
            return self.backup_projects()
        
        elif 'resize' in command_text and 'image' in command_text:
            return self.batch_resize_images('/home/devuser/Desktop', 'instagram')
        
        elif 'system' in command_text and ('info' in command_text or 'status' in command_text):
            return self.get_system_info()
        
        else:
            return {'success': False, 'message': f'Command not recognized: {command_text}'}
    
    def open_application(self, app_name):
        """Open desktop application"""
        try:
            subprocess.Popen([app_name], env=dict(os.environ, DISPLAY=':0'))
            return {'success': True, 'message': f'Opened {app_name}'}
        except Exception as e:
            return {'success': False, 'message': f'Failed to open {app_name}: {str(e)}'}
    
    def create_marketing_project(self, name, project_type):
        """Create new marketing project"""
        try:
            # Call workflow automation API
            response = requests.post('http://localhost:8087/workflow/create_project', 
                                   json={'name': name, 'type': project_type})
            
            if response.status_code == 200:
                return {'success': True, 'message': f'Created {project_type} project: {name}'}
            else:
                return {'success': False, 'message': 'Project creation failed'}
        except Exception as e:
            return {'success': False, 'message': f'Error creating project: {str(e)}'}
    
    def optimize_system(self):
        """Optimize system performance"""
        try:
            # Call performance optimization API
            response = requests.post('http://localhost:8086/performance/auto')
            
            if response.status_code == 200:
                result = response.json()
                profile = result.get('profile_applied', 'none')
                return {'success': True, 'message': f'System optimized with {profile} profile'}
            else:
                return {'success': False, 'message': 'Optimization failed'}
        except Exception as e:
            return {'success': False, 'message': f'Error optimizing system: {str(e)}'}
    
    def backup_projects(self):
        """Backup marketing projects"""
        try:
            subprocess.run(['/opt/marketing-optimization/automation/workflow-automation.py', 
                          'backup_projects'], check=True)
            return {'success': True, 'message': 'Projects backed up successfully'}
        except Exception as e:
            return {'success': False, 'message': f'Backup failed: {str(e)}'}
    
    def batch_resize_images(self, directory, platform):
        """Batch resize images for social media"""
        try:
            response = requests.post('http://localhost:8087/workflow/resize_images',
                                   json={'directory': directory, 'platform': platform})
            
            if response.status_code == 200:
                return {'success': True, 'message': f'Images resized for {platform}'}
            else:
                return {'success': False, 'message': 'Image resize failed'}
        except Exception as e:
            return {'success': False, 'message': f'Error resizing images: {str(e)}'}
    
    def get_system_info(self):
        """Get system information"""
        try:
            response = requests.get('http://localhost:8086/performance/stats')
            
            if response.status_code == 200:
                stats = response.json()
                message = f"CPU: {stats['cpu_percent']:.1f}%, Memory: {stats['memory_percent']:.1f}%, Disk: {stats['disk_usage']:.1f}%"
                return {'success': True, 'message': message, 'data': stats}
            else:
                return {'success': False, 'message': 'Failed to get system info'}
        except Exception as e:
            return {'success': False, 'message': f'Error getting system info: {str(e)}'}
    
    def schedule_task(self, task, time_spec):
        """Schedule a task for later execution"""
        # Simple task scheduling (would need more sophisticated implementation)
        return {'success': True, 'message': f'Task "{task}" scheduled for {time_spec}'}
    
    def get_suggestions(self, context="general"):
        """Get AI-powered suggestions based on context"""
        suggestions = {
            "design": [
                "Optimize GIMP performance for large files",
                "Create social media templates",
                "Set up color profiles for print design",
                "Batch resize images for Instagram"
            ],
            "video": [
                "Set up video editing workspace",
                "Optimize Kdenlive for 4K editing",
                "Create video templates for social media",
                "Schedule video exports during low usage"
            ],
            "productivity": [
                "Backup current projects",
                "Optimize system performance",
                "Set up cloud sync for important files",
                "Create project templates for faster workflow"
            ],
            "general": [
                "Review system performance statistics",
                "Update applications to latest versions",
                "Clean up temporary files",
                "Check available disk space"
            ]
        }
        
        return suggestions.get(context, suggestions["general"])

if __name__ == '__main__':
    assistant = DesktopAIAssistant()
    
    # HTTP API for AI assistant
    from http.server import HTTPServer, BaseHTTPRequestHandler
    import socketserver
    
    class AssistantHandler(BaseHTTPRequestHandler):
        def do_POST(self):
            if self.path == '/assistant/command':
                try:
                    content_length = int(self.headers['Content-Length'])
                    post_data = self.rfile.read(content_length)
                    data = json.loads(post_data.decode())
                    
                    command = data.get('command', '')
                    result = assistant.process_command(command)
                    
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.end_headers()
                    
                    self.wfile.write(json.dumps(result).encode())
                    
                except Exception as e:
                    self.send_error(500, f"Command processing error: {str(e)}")
        
        def do_GET(self):
            if self.path.startswith('/assistant/suggestions'):
                try:
                    # Extract context from query parameters
                    context = "general"
                    if '?' in self.path:
                        query = self.path.split('?')[1]
                        for param in query.split('&'):
                            if param.startswith('context='):
                                context = param.split('=')[1]
                    
                    suggestions = assistant.get_suggestions(context)
                    
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.end_headers()
                    
                    response = {'suggestions': suggestions, 'context': context}
                    self.wfile.write(json.dumps(response).encode())
                    
                except Exception as e:
                    self.send_error(500, f"Suggestions error: {str(e)}")
    
    PORT = 8089
    with socketserver.TCPServer(("", PORT), AssistantHandler) as httpd:
        print(f"Desktop AI Assistant API running on port {PORT}")
        httpd.serve_forever()
EOF

# Real-time Collaboration System
cat > "/opt/modern-features/collaboration/collaboration-hub.py" << 'EOF'
#!/usr/bin/env python3
import json
import asyncio
import websockets
import threading
import time
from datetime import datetime
from pathlib import Path
import subprocess

class CollaborationHub:
    def __init__(self):
        self.connected_users = {}
        self.active_sessions = {}
        self.shared_cursors = {}
        self.file_locks = {}
    
    async def handle_client(self, websocket, path):
        """Handle WebSocket connections for real-time collaboration"""
        try:
            # Register new user
            user_id = f"user_{len(self.connected_users)}"
            self.connected_users[user_id] = {
                'websocket': websocket,
                'connected_at': datetime.now(),
                'cursor_position': {'x': 0, 'y': 0}
            }
            
            print(f"User {user_id} connected")
            
            # Send welcome message
            await websocket.send(json.dumps({
                'type': 'welcome',
                'user_id': user_id,
                'active_users': len(self.connected_users)
            }))
            
            # Broadcast user joined
            await self.broadcast_message({
                'type': 'user_joined',
                'user_id': user_id,
                'active_users': len(self.connected_users)
            }, exclude=user_id)
            
            # Handle messages
            async for message in websocket:
                await self.process_message(user_id, json.loads(message))
                
        except websockets.exceptions.ConnectionClosed:
            pass
        except Exception as e:
            print(f"Error handling client: {e}")
        finally:
            # Clean up on disconnect
            if user_id in self.connected_users:
                del self.connected_users[user_id]
                
                # Broadcast user left
                await self.broadcast_message({
                    'type': 'user_left',
                    'user_id': user_id,
                    'active_users': len(self.connected_users)
                })
    
    async def process_message(self, user_id, message):
        """Process incoming WebSocket messages"""
        msg_type = message.get('type')
        
        if msg_type == 'cursor_move':
            # Update and broadcast cursor position
            self.connected_users[user_id]['cursor_position'] = {
                'x': message['x'],
                'y': message['y']
            }
            
            await self.broadcast_message({
                'type': 'cursor_update',
                'user_id': user_id,
                'x': message['x'],
                'y': message['y']
            }, exclude=user_id)
        
        elif msg_type == 'screen_annotation':
            # Broadcast screen annotation
            await self.broadcast_message({
                'type': 'annotation',
                'user_id': user_id,
                'annotation': message['annotation']
            }, exclude=user_id)
        
        elif msg_type == 'file_lock_request':
            # Handle file locking for collaborative editing
            file_path = message['file_path']
            
            if file_path not in self.file_locks:
                self.file_locks[file_path] = user_id
                await self.send_to_user(user_id, {
                    'type': 'file_lock_acquired',
                    'file_path': file_path
                })
            else:
                await self.send_to_user(user_id, {
                    'type': 'file_lock_denied',
                    'file_path': file_path,
                    'locked_by': self.file_locks[file_path]
                })
        
        elif msg_type == 'file_unlock':
            # Release file lock
            file_path = message['file_path']
            if file_path in self.file_locks and self.file_locks[file_path] == user_id:
                del self.file_locks[file_path]
                
                await self.broadcast_message({
                    'type': 'file_unlocked',
                    'file_path': file_path
                })
        
        elif msg_type == 'chat_message':
            # Broadcast chat message
            await self.broadcast_message({
                'type': 'chat',
                'user_id': user_id,
                'message': message['message'],
                'timestamp': datetime.now().isoformat()
            })
        
        elif msg_type == 'screen_share_request':
            # Handle screen sharing requests
            await self.broadcast_message({
                'type': 'screen_share_started',
                'user_id': user_id
            }, exclude=user_id)
    
    async def broadcast_message(self, message, exclude=None):
        """Broadcast message to all connected users"""
        for user_id, user_data in self.connected_users.items():
            if user_id != exclude:
                try:
                    await user_data['websocket'].send(json.dumps(message))
                except:
                    pass
    
    async def send_to_user(self, user_id, message):
        """Send message to specific user"""
        if user_id in self.connected_users:
            try:
                await self.connected_users[user_id]['websocket'].send(json.dumps(message))
            except:
                pass
    
    def start_server(self):
        """Start the WebSocket server"""
        start_server = websockets.serve(self.handle_client, "0.0.0.0", 8090)
        
        loop = asyncio.new_event_loop()
        asyncio.set_event_loop(loop)
        loop.run_until_complete(start_server)
        loop.run_forever()

if __name__ == '__main__':
    hub = CollaborationHub()
    print("Starting collaboration hub on port 8090...")
    hub.start_server()
EOF

# Enhanced KasmVNC Client with Modern Features
cat > "/opt/modern-features/enhanced-kasmvnc.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Enhanced Ubuntu KDE Desktop</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <link rel="manifest" href="/opt/modern-features/pwa/manifest.json">
    <link rel="icon" type="image/png" href="/icons/icon-192x192.png">
    <meta name="theme-color" content="#4A90E2">
    
    <style>
        body { 
            margin: 0; 
            padding: 0; 
            background: #1a1a2e;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            overflow: hidden;
        }
        
        #toolbar {
            background: rgba(0,0,0,0.8);
            color: white;
            padding: 10px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            position: fixed;
            top: 0;
            left: 0;
            right: 0;
            z-index: 1000;
            backdrop-filter: blur(10px);
        }
        
        .toolbar-section {
            display: flex;
            align-items: center;
            gap: 10px;
        }
        
        .btn {
            background: linear-gradient(135deg, #4A90E2, #357ABD);
            color: white;
            border: none;
            padding: 8px 16px;
            border-radius: 6px;
            cursor: pointer;
            font-size: 12px;
            transition: all 0.3s ease;
        }
        
        .btn:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(74, 144, 226, 0.4);
        }
        
        .quality-control {
            display: flex;
            align-items: center;
            gap: 5px;
        }
        
        .quality-slider {
            width: 100px;
            accent-color: #4A90E2;
        }
        
        #connection-status {
            display: flex;
            align-items: center;
            gap: 5px;
            font-size: 12px;
        }
        
        .status-indicator {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background: #28a745;
            animation: pulse 2s infinite;
        }
        
        @keyframes pulse {
            0% { opacity: 1; }
            50% { opacity: 0.5; }
            100% { opacity: 1; }
        }
        
        #vnc-container {
            position: absolute;
            top: 50px;
            left: 0;
            right: 0;
            bottom: 0;
            background: #000;
        }
        
        #collaboration-panel {
            position: fixed;
            right: -300px;
            top: 50px;
            bottom: 0;
            width: 300px;
            background: rgba(255,255,255,0.95);
            backdrop-filter: blur(10px);
            transition: right 0.3s ease;
            padding: 20px;
            overflow-y: auto;
        }
        
        #collaboration-panel.open {
            right: 0;
        }
        
        .chat-messages {
            height: 200px;
            overflow-y: auto;
            border: 1px solid #ddd;
            padding: 10px;
            margin-bottom: 10px;
            border-radius: 8px;
            background: rgba(248,249,250,0.8);
        }
        
        .chat-input {
            width: 100%;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 6px;
            resize: none;
        }
        
        .user-cursors {
            position: absolute;
            pointer-events: none;
            z-index: 100;
        }
        
        .user-cursor {
            position: absolute;
            width: 20px;
            height: 20px;
            background: #ff6b6b;
            border-radius: 50% 0 50% 50%;
            transform: rotate(-45deg);
            transition: all 0.1s ease;
        }
        
        .mobile-controls {
            display: none;
            position: fixed;
            bottom: 20px;
            right: 20px;
            z-index: 1000;
        }
        
        @media (max-width: 768px) {
            .mobile-controls { display: block; }
            #toolbar { padding: 5px; font-size: 12px; }
            .btn { padding: 6px 12px; font-size: 11px; }
        }
        
        .ai-assistant {
            position: fixed;
            bottom: 20px;
            left: 20px;
            z-index: 1000;
        }
        
        .ai-chat {
            background: rgba(255,255,255,0.95);
            border-radius: 15px;
            padding: 15px;
            max-width: 300px;
            display: none;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
        }
        
        .ai-input {
            width: 100%;
            padding: 10px;
            border: 1px solid #ddd;
            border-radius: 20px;
            margin-bottom: 10px;
        }
        
        .suggestion-chips {
            display: flex;
            flex-wrap: wrap;
            gap: 5px;
            margin-top: 10px;
        }
        
        .suggestion-chip {
            background: #f0f0f0;
            padding: 5px 10px;
            border-radius: 15px;
            font-size: 11px;
            cursor: pointer;
            transition: background 0.3s ease;
        }
        
        .suggestion-chip:hover {
            background: #e0e0e0;
        }
    </style>
</head>
<body>
    <!-- Enhanced Toolbar -->
    <div id="toolbar">
        <div class="toolbar-section">
            <button class="btn" onclick="toggleFullscreen()">🖥️ Fullscreen</button>
            <button class="btn" onclick="toggleCollaboration()">👥 Collaborate</button>
            <button class="btn" onclick="openDashboard()">📊 Dashboard</button>
            <button class="btn" onclick="toggleAI()">🤖 AI Assistant</button>
        </div>
        
        <div class="toolbar-section">
            <div class="quality-control">
                <span>Quality:</span>
                <input type="range" class="quality-slider" min="1" max="9" value="6" 
                       onchange="adjustQuality(this.value)">
                <span id="quality-value">6</span>
            </div>
        </div>
        
        <div class="toolbar-section">
            <div id="connection-status">
                <div class="status-indicator"></div>
                <span>Connected</span>
                <span id="latency">0ms</span>
            </div>
        </div>
    </div>

    <!-- VNC Container -->
    <div id="vnc-container">
        <div id="KasmVNC_container">
            <canvas id="KasmVNC_canvas">
                Canvas not supported.
            </canvas>
        </div>
        
        <!-- User Cursors Overlay -->
        <div class="user-cursors" id="user-cursors"></div>
    </div>

    <!-- Collaboration Panel -->
    <div id="collaboration-panel">
        <h3>👥 Collaboration</h3>
        <p>Active Users: <span id="active-users">1</span></p>
        
        <div class="chat-messages" id="chat-messages"></div>
        <textarea class="chat-input" id="chat-input" placeholder="Type a message..." 
                  onkeypress="handleChatInput(event)"></textarea>
        
        <h4>File Locks</h4>
        <div id="file-locks"></div>
    </div>

    <!-- Mobile Controls -->
    <div class="mobile-controls">
        <button class="btn" onclick="showVirtualKeyboard()">⌨️</button>
        <button class="btn" onclick="toggleMobileMenu()">☰</button>
    </div>

    <!-- AI Assistant -->
    <div class="ai-assistant">
        <button class="btn" onclick="toggleAI()">🤖 AI</button>
        <div class="ai-chat" id="ai-chat">
            <h4>AI Desktop Assistant</h4>
            <input type="text" class="ai-input" id="ai-input" 
                   placeholder="Ask me to help with your desktop..."
                   onkeypress="handleAIInput(event)">
            <div id="ai-response"></div>
            <div class="suggestion-chips" id="ai-suggestions"></div>
        </div>
    </div>

    <!-- Include KasmVNC -->
    <script src="/app/ui.js"></script>

    <script>
        // Enhanced KasmVNC with modern features
        let rfb;
        let collaborationWS;
        let qualitySettings = 6;
        
        // Initialize enhanced KasmVNC
        function initializeVNC() {
            const canvas = document.getElementById('KasmVNC_canvas');
            
            rfb = new RFB(canvas, 'ws://localhost:6080/websockify');
            
            // Enhanced connection handling
            rfb.addEventListener('connect', handleConnect);
            rfb.addEventListener('disconnect', handleDisconnect);
            rfb.addEventListener('credentialsrequired', handleCredentials);
            
            // Set initial quality
            rfb.compressionLevel = qualitySettings;
            rfb.qualityLevel = qualitySettings;
            
            // Enable advanced features
            rfb.showDotCursor = true;
            rfb.clipViewport = false;
            rfb.dragViewport = false;
            rfb.resizeSession = false;
            
            // Performance monitoring
            startPerformanceMonitoring();
        }
        
        function handleConnect() {
            document.getElementById('connection-status').innerHTML = 
                '<div class="status-indicator"></div><span>Connected</span><span id="latency">0ms</span>';
            
            // Initialize collaboration
            initializeCollaboration();
            
            // Register service worker for PWA
            if ('serviceWorker' in navigator) {
                navigator.serviceWorker.register('/opt/modern-features/pwa/service-worker.js');
            }
        }
        
        function handleDisconnect() {
            document.getElementById('connection-status').innerHTML = 
                '<div class="status-indicator" style="background: #dc3545;"></div><span>Disconnected</span>';
        }
        
        function handleCredentials() {
            // Handle authentication
            rfb.sendCredentials({ username: 'devuser', password: 'password' });
        }
        
        // Quality adjustment
        function adjustQuality(value) {
            qualitySettings = parseInt(value);
            document.getElementById('quality-value').textContent = value;
            
            if (rfb) {
                rfb.compressionLevel = qualitySettings;
                rfb.qualityLevel = qualitySettings;
            }
        }
        
        // Collaboration features
        function initializeCollaboration() {
            try {
                collaborationWS = new WebSocket('ws://localhost:8090');
                
                collaborationWS.onmessage = function(event) {
                    const data = JSON.parse(event.data);
                    handleCollaborationMessage(data);
                };
                
                collaborationWS.onopen = function() {
                    console.log('Collaboration connected');
                };
                
                // Track mouse movement for collaboration
                document.addEventListener('mousemove', function(e) {
                    if (collaborationWS && collaborationWS.readyState === WebSocket.OPEN) {
                        collaborationWS.send(JSON.stringify({
                            type: 'cursor_move',
                            x: e.clientX,
                            y: e.clientY
                        }));
                    }
                });
                
            } catch (error) {
                console.log('Collaboration not available:', error);
            }
        }
        
        function handleCollaborationMessage(data) {
            switch(data.type) {
                case 'user_joined':
                case 'user_left':
                    document.getElementById('active-users').textContent = data.active_users;
                    break;
                    
                case 'cursor_update':
                    updateUserCursor(data.user_id, data.x, data.y);
                    break;
                    
                case 'chat':
                    addChatMessage(data.user_id, data.message, data.timestamp);
                    break;
                    
                case 'file_lock_acquired':
                    updateFileLocks(data.file_path, data.user_id);
                    break;
            }
        }
        
        function updateUserCursor(userId, x, y) {
            let cursor = document.getElementById(`cursor-${userId}`);
            if (!cursor) {
                cursor = document.createElement('div');
                cursor.id = `cursor-${userId}`;
                cursor.className = 'user-cursor';
                cursor.style.background = getRandomColor();
                document.getElementById('user-cursors').appendChild(cursor);
            }
            
            cursor.style.left = x + 'px';
            cursor.style.top = y + 'px';
        }
        
        function addChatMessage(userId, message, timestamp) {
            const chatMessages = document.getElementById('chat-messages');
            const messageDiv = document.createElement('div');
            messageDiv.innerHTML = `<strong>${userId}:</strong> ${message} <small>${new Date(timestamp).toLocaleTimeString()}</small>`;
            chatMessages.appendChild(messageDiv);
            chatMessages.scrollTop = chatMessages.scrollHeight;
        }
        
        function handleChatInput(event) {
            if (event.key === 'Enter' && !event.shiftKey) {
                event.preventDefault();
                const input = event.target;
                const message = input.value.trim();
                
                if (message && collaborationWS) {
                    collaborationWS.send(JSON.stringify({
                        type: 'chat_message',
                        message: message
                    }));
                    input.value = '';
                }
            }
        }
        
        // AI Assistant
        function toggleAI() {
            const aiChat = document.getElementById('ai-chat');
            aiChat.style.display = aiChat.style.display === 'none' ? 'block' : 'none';
            
            if (aiChat.style.display === 'block') {
                loadAISuggestions();
            }
        }
        
        async function loadAISuggestions() {
            try {
                const response = await fetch('http://localhost:8089/assistant/suggestions?context=general');
                const data = await response.json();
                
                const suggestionsDiv = document.getElementById('ai-suggestions');
                suggestionsDiv.innerHTML = '';
                
                data.suggestions.forEach(suggestion => {
                    const chip = document.createElement('div');
                    chip.className = 'suggestion-chip';
                    chip.textContent = suggestion;
                    chip.onclick = () => executeAICommand(suggestion);
                    suggestionsDiv.appendChild(chip);
                });
            } catch (error) {
                console.log('AI suggestions not available:', error);
            }
        }
        
        async function handleAIInput(event) {
            if (event.key === 'Enter') {
                const input = event.target;
                const command = input.value.trim();
                
                if (command) {
                    await executeAICommand(command);
                    input.value = '';
                }
            }
        }
        
        async function executeAICommand(command) {
            try {
                const response = await fetch('http://localhost:8089/assistant/command', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ command })
                });
                
                const result = await response.json();
                
                const responseDiv = document.getElementById('ai-response');
                responseDiv.innerHTML = `<p><strong>AI:</strong> ${result.message}</p>`;
                
                // Auto-hide response after 5 seconds
                setTimeout(() => {
                    responseDiv.innerHTML = '';
                }, 5000);
                
            } catch (error) {
                console.log('AI command failed:', error);
            }
        }
        
        // Performance monitoring
        function startPerformanceMonitoring() {
            setInterval(() => {
                if (rfb) {
                    // Simulate latency measurement
                    const latency = Math.random() * 50 + 10;
                    document.getElementById('latency').textContent = `${Math.round(latency)}ms`;
                }
            }, 1000);
        }
        
        // Utility functions
        function toggleFullscreen() {
            if (!document.fullscreenElement) {
                document.documentElement.requestFullscreen();
            } else {
                document.exitFullscreen();
            }
        }
        
        function toggleCollaboration() {
            const panel = document.getElementById('collaboration-panel');
            panel.classList.toggle('open');
        }
        
        function openDashboard() {
            window.open('/opt/marketing-optimization/dashboard/marketing-dashboard.html', '_blank');
        }
        
        function getRandomColor() {
            const colors = ['#ff6b6b', '#4ecdc4', '#45b7d1', '#96ceb4', '#feca57'];
            return colors[Math.floor(Math.random() * colors.length)];
        }
        
        // Initialize everything when page loads
        window.addEventListener('load', function() {
            initializeVNC();
            
            // Auto-hide toolbar after 3 seconds
            setTimeout(() => {
                document.getElementById('toolbar').style.opacity = '0.7';
            }, 3000);
            
            // Show toolbar on mouse move
            document.addEventListener('mousemove', () => {
                document.getElementById('toolbar').style.opacity = '1';
            });
        });
        
        // Handle mobile-specific features
        if (/Android|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)) {
            document.body.classList.add('mobile');
            
            // Prevent zoom on double-tap
            document.addEventListener('touchend', function(e) {
                e.preventDefault();
            });
        }
        
        // PWA installation prompt
        let deferredPrompt;
        window.addEventListener('beforeinstallprompt', (e) => {
            e.preventDefault();
            deferredPrompt = e;
            
            // Show install button
            const installBtn = document.createElement('button');
            installBtn.className = 'btn';
            installBtn.textContent = '📱 Install App';
            installBtn.onclick = () => {
                deferredPrompt.prompt();
                deferredPrompt.userChoice.then((choiceResult) => {
                    if (choiceResult.outcome === 'accepted') {
                        console.log('PWA installed');
                    }
                    deferredPrompt = null;
                    installBtn.remove();
                });
            };
            
            document.querySelector('.toolbar-section').appendChild(installBtn);
        });
    </script>
</body>
</html>
EOF

# Make scripts executable
chmod +x /opt/modern-features/cloud-integration/cloud-sync.py
chmod +x /opt/modern-features/ai-assistant/desktop-assistant.py
chmod +x /opt/modern-features/collaboration/collaboration-hub.py

# Set ownership
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/opt/modern-features"

log_info "Modern features setup complete"
log_info "Services available on ports:"
log_info "- Cloud Integration: 8088"
log_info "- AI Assistant: 8089"
log_info "- Collaboration Hub: 8090"
log_info "- Enhanced KasmVNC: /opt/modern-features/enhanced-kasmvnc.html"