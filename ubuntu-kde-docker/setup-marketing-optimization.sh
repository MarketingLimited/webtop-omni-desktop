#!/bin/bash
set -euo pipefail

DEV_USERNAME="${DEV_USERNAME:-devuser}"
DEV_HOME="/home/${DEV_USERNAME}"

# Logging function
log_info() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [MARKETING-OPT] $*"
}

log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [MARKETING-OPT ERROR] $*" >&2
}

log_info "Setting up marketing agency optimizations..."

# Create marketing optimization directories
mkdir -p \
    "/opt/marketing-optimization" \
    "/opt/marketing-optimization/profiles" \
    "/opt/marketing-optimization/automation" \
    "/opt/marketing-optimization/performance" \
    "/opt/marketing-optimization/workflows" \
    "${DEV_HOME}/Marketing-Projects" \
    "${DEV_HOME}/Marketing-Projects/Social-Media" \
    "${DEV_HOME}/Marketing-Projects/Design-Assets" \
    "${DEV_HOME}/Marketing-Projects/Video-Content" \
    "${DEV_HOME}/Marketing-Projects/Campaign-Materials" \
    "${DEV_HOME}/Marketing-Projects/Client-Work" \
    "${DEV_HOME}/Marketing-Projects/Templates"

# Graphics and Design Performance Optimization
cat > "/opt/marketing-optimization/performance/graphics-optimization.sh" << 'EOF'
#!/bin/bash

# GIMP Performance Optimization
optimize_gimp() {
    log_info "Optimizing GIMP for marketing workflows..."
    
    mkdir -p "${DEV_HOME}/.config/GIMP/2.10"
    
    cat > "${DEV_HOME}/.config/GIMP/2.10/gimprc" << 'GIMPEOF'
# Marketing-optimized GIMP configuration
(tile-cache-size 2048M)
(use-opencl yes)
(swap-compression 0)
(num-processors 4)
(interpolation-type cubic)
(default-image-sizing 300)
(default-units pixels)
(transparency-type checkerboard)
(layer-preview-size large)
(undo-levels 50)

# Marketing-specific settings
(default-rgb-color-profile "sRGB")
(default-cmyk-color-profile "ISO Coated v2 300%")
(color-management-mode convert)
(color-management-display-intent perceptual)
GIMPEOF

    # Install marketing-focused GIMP plugins
    mkdir -p "${DEV_HOME}/.config/GIMP/2.10/plug-ins"
    
    # Social media templates
    cat > "${DEV_HOME}/.config/GIMP/2.10/templates/social-media-templates.txt" << 'TEMPLATES'
Instagram Post: 1080x1080 pixels, 72 DPI
Instagram Story: 1080x1920 pixels, 72 DPI
Facebook Post: 1200x630 pixels, 72 DPI
Facebook Cover: 820x312 pixels, 72 DPI
Twitter Header: 1500x500 pixels, 72 DPI
LinkedIn Post: 1200x627 pixels, 72 DPI
YouTube Thumbnail: 1280x720 pixels, 72 DPI
Pinterest Pin: 735x1102 pixels, 72 DPI
TEMPLATES
}

# Inkscape Performance Optimization
optimize_inkscape() {
    log_info "Optimizing Inkscape for vector design..."
    
    mkdir -p "${DEV_HOME}/.config/inkscape"
    
    cat > "${DEV_HOME}/.config/inkscape/preferences.xml" << 'INKSCAPEEOF'
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<inkscape>
  <group id="rendering">
    <group id="cairo-renderer">
      <attr name="antialias" value="2"/>
      <attr name="dithering" value="1"/>
    </group>
  </group>
  <group id="tools">
    <group id="marker">
      <attr name="mode" value="2"/>
    </group>
  </group>
  <group id="ui">
    <group id="toolbar">
      <attr name="small" value="0"/>
    </group>
  </group>
  <group id="performance">
    <attr name="max_undo" value="50"/>
    <attr name="simplification_threshold" value="0.002"/>
  </group>
</inkscape>
INKSCAPEEOF
}

# Video Editing Performance (for marketing videos)
optimize_video_editing() {
    log_info "Optimizing video editing performance..."
    
    # Kdenlive optimization for marketing videos
    mkdir -p "${DEV_HOME}/.config"
    
    cat > "${DEV_HOME}/.config/kdenliverc" << 'KDENLIVEEOF'
[capture]
decklink_parameters=format=8bit_yuv
defaultcapture=screen
grab_extension=mov
grab_parameters=-f x11grab -show_region 1 -framerate 30
v4l_extension=mpg
v4l_parameters=-f video4linux2 -i /dev/video0 -framerate 30

[misc]
default_profile_path=/usr/share/kdenlive/profiles/
defaultprojectfolder=/home/devuser/Marketing-Projects/Video-Content
profile_fps_filter=30

[timeline]
trackheight=50
zoneclicks=1

[unmanaged]
defaultprojectfolder=/home/devuser/Marketing-Projects/Video-Content
widgetstyle=Fusion

[env]
defaultprojectformat=atsc_1080p_30
ffmpegpath=/usr/bin/ffmpeg
ffplaypath=/usr/bin/ffplay
ffprobepath=/usr/bin/ffprobe
meltpath=/usr/bin/melt
KDENLIVEEOF

    # Create video project templates
    mkdir -p "${DEV_HOME}/Marketing-Projects/Video-Content/Templates"
    
    cat > "${DEV_HOME}/Marketing-Projects/Video-Content/Templates/social-media-specs.txt" << 'VIDEOTEMPLATE'
Social Media Video Specifications:

Instagram Feed (Square): 1080x1080, 30fps, max 60s
Instagram Stories: 1080x1920, 30fps, max 15s
Instagram Reels: 1080x1920, 30fps, max 90s
Facebook Feed: 1920x1080, 30fps, max 240s
YouTube Short: 1080x1920, 30fps, max 60s
YouTube Standard: 1920x1080, 30fps, any length
TikTok: 1080x1920, 30fps, max 180s
LinkedIn: 1920x1080, 30fps, max 600s
Twitter: 1920x1080, 30fps, max 140s

Recommended bitrates:
- 1080p: 8-12 Mbps
- 720p: 5-8 Mbps
- Vertical (9:16): 6-10 Mbps
VIDEOTEMPLATE
}

optimize_gimp
optimize_inkscape
optimize_video_editing
EOF

# Marketing Tools Performance Profiles
cat > "/opt/marketing-optimization/profiles/performance-profiles.py" << 'EOF'
#!/usr/bin/env python3
import os
import subprocess
import json
import psutil
from pathlib import Path

class MarketingPerformanceManager:
    def __init__(self):
        self.profiles = {
            'design': {
                'name': 'Design & Graphics',
                'apps': ['gimp', 'inkscape', 'krita', 'blender'],
                'cpu_priority': 'high',
                'memory_limit': '80%',
                'gpu_acceleration': True,
                'disk_cache': 'large'
            },
            'video': {
                'name': 'Video Editing',
                'apps': ['kdenlive', 'obs', 'ffmpeg'],
                'cpu_priority': 'realtime',
                'memory_limit': '90%',
                'gpu_acceleration': True,
                'disk_cache': 'huge'
            },
            'social': {
                'name': 'Social Media Management',
                'apps': ['google-chrome', 'firefox', 'discord'],
                'cpu_priority': 'normal',
                'memory_limit': '60%',
                'gpu_acceleration': False,
                'disk_cache': 'normal'
            },
            'presentation': {
                'name': 'Presentations & Meetings',
                'apps': ['libreoffice', 'zoom', 'teams'],
                'cpu_priority': 'high',
                'memory_limit': '70%',
                'gpu_acceleration': True,
                'disk_cache': 'normal'
            }
        }
    
    def apply_profile(self, profile_name):
        """Apply performance profile for marketing workflows"""
        if profile_name not in self.profiles:
            print(f"Profile {profile_name} not found")
            return False
        
        profile = self.profiles[profile_name]
        print(f"Applying {profile['name']} performance profile...")
        
        # Adjust CPU governor
        self._set_cpu_performance(profile['cpu_priority'])
        
        # Configure memory management
        self._configure_memory(profile['memory_limit'])
        
        # Set application priorities
        self._optimize_applications(profile['apps'], profile['cpu_priority'])
        
        # Configure GPU acceleration
        if profile['gpu_acceleration']:
            self._enable_gpu_acceleration()
        
        print(f"{profile['name']} profile applied successfully")
        return True
    
    def _set_cpu_performance(self, priority):
        """Configure CPU performance based on priority"""
        try:
            if priority == 'realtime':
                # Set performance governor
                subprocess.run(['cpufreq-set', '-g', 'performance'], check=False)
            elif priority == 'high':
                subprocess.run(['cpufreq-set', '-g', 'ondemand'], check=False)
            else:
                subprocess.run(['cpufreq-set', '-g', 'powersave'], check=False)
        except:
            pass  # Fail silently if cpufreq tools not available
    
    def _configure_memory(self, limit):
        """Configure memory management"""
        try:
            # Configure swappiness based on memory usage
            if limit == '90%':
                subprocess.run(['sysctl', 'vm.swappiness=10'], check=False)
            elif limit == '80%':
                subprocess.run(['sysctl', 'vm.swappiness=20'], check=False)
            else:
                subprocess.run(['sysctl', 'vm.swappiness=60'], check=False)
        except:
            pass
    
    def _optimize_applications(self, apps, priority):
        """Set process priorities for marketing applications"""
        nice_values = {
            'realtime': -10,
            'high': -5,
            'normal': 0,
            'low': 10
        }
        
        nice_val = nice_values.get(priority, 0)
        
        for app in apps:
            try:
                # Find and adjust process priority
                for proc in psutil.process_iter(['pid', 'name']):
                    if app.lower() in proc.info['name'].lower():
                        os.system(f"renice {nice_val} -p {proc.info['pid']}")
            except:
                pass
    
    def _enable_gpu_acceleration(self):
        """Enable GPU acceleration for graphics applications"""
        try:
            # Set environment variables for GPU acceleration
            os.environ['LIBGL_ALWAYS_INDIRECT'] = '0'
            os.environ['__GL_SYNC_TO_VBLANK'] = '1'
            os.environ['GALLIUM_HUD'] = 'fps'
        except:
            pass
    
    def get_system_stats(self):
        """Get current system performance statistics"""
        stats = {
            'cpu_percent': psutil.cpu_percent(interval=1),
            'memory_percent': psutil.virtual_memory().percent,
            'disk_usage': psutil.disk_usage('/').percent,
            'running_processes': len(psutil.pids())
        }
        return stats
    
    def auto_optimize(self):
        """Automatically optimize based on running applications"""
        running_apps = []
        
        for proc in psutil.process_iter(['name']):
            try:
                running_apps.append(proc.info['name'].lower())
            except:
                pass
        
        # Determine best profile based on running apps
        profile_scores = {}
        for profile_name, profile in self.profiles.items():
            score = 0
            for app in profile['apps']:
                if any(app in running_app for running_app in running_apps):
                    score += 1
            profile_scores[profile_name] = score
        
        # Apply best matching profile
        if profile_scores:
            best_profile = max(profile_scores, key=profile_scores.get)
            if profile_scores[best_profile] > 0:
                self.apply_profile(best_profile)
                return best_profile
        
        return None

if __name__ == '__main__':
    manager = MarketingPerformanceManager()
    
    # HTTP API for performance management
    from http.server import HTTPServer, BaseHTTPRequestHandler
    import socketserver
    
    class PerformanceHandler(BaseHTTPRequestHandler):
        def do_POST(self):
            if self.path == '/performance/profile':
                try:
                    content_length = int(self.headers['Content-Length'])
                    post_data = self.rfile.read(content_length)
                    data = json.loads(post_data.decode())
                    
                    profile_name = data.get('profile')
                    success = manager.apply_profile(profile_name)
                    
                    self.send_response(200 if success else 400)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.end_headers()
                    
                    response = {'success': success, 'profile': profile_name}
                    self.wfile.write(json.dumps(response).encode())
                    
                except Exception as e:
                    self.send_error(500, f"Profile error: {str(e)}")
            
            elif self.path == '/performance/auto':
                try:
                    applied_profile = manager.auto_optimize()
                    
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.end_headers()
                    
                    response = {'profile_applied': applied_profile}
                    self.wfile.write(json.dumps(response).encode())
                    
                except Exception as e:
                    self.send_error(500, f"Auto-optimization error: {str(e)}")
        
        def do_GET(self):
            if self.path == '/performance/stats':
                try:
                    stats = manager.get_system_stats()
                    
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.end_headers()
                    
                    self.wfile.write(json.dumps(stats).encode())
                    
                except Exception as e:
                    self.send_error(500, f"Stats error: {str(e)}")
    
    PORT = 8086
    with socketserver.TCPServer(("", PORT), PerformanceHandler) as httpd:
        print(f"Marketing performance API running on port {PORT}")
        httpd.serve_forever()
EOF

# Marketing Workflow Automation
cat > "/opt/marketing-optimization/automation/workflow-automation.py" << 'EOF'
#!/usr/bin/env python3
import os
import json
import subprocess
import schedule
import time
from datetime import datetime
from pathlib import Path

class MarketingWorkflowAutomation:
    def __init__(self):
        self.project_dir = Path("/home/devuser/Marketing-Projects")
        self.backup_dir = Path("/home/devuser/Marketing-Backups")
        self.backup_dir.mkdir(exist_ok=True)
    
    def setup_project_template(self, project_name, project_type):
        """Create standardized project structure"""
        project_path = self.project_dir / project_name
        project_path.mkdir(exist_ok=True)
        
        # Create standard directories based on project type
        if project_type == 'social_campaign':
            dirs = ['assets', 'posts', 'stories', 'videos', 'analytics', 'drafts']
        elif project_type == 'brand_design':
            dirs = ['logos', 'brand_guide', 'assets', 'mockups', 'finals', 'source_files']
        elif project_type == 'video_campaign':
            dirs = ['raw_footage', 'audio', 'graphics', 'exports', 'thumbnails', 'scripts']
        elif project_type == 'website_content':
            dirs = ['images', 'copy', 'mockups', 'assets', 'finals']
        else:
            dirs = ['assets', 'drafts', 'finals', 'archive']
        
        for dir_name in dirs:
            (project_path / dir_name).mkdir(exist_ok=True)
        
        # Create project brief template
        brief_template = f"""
# {project_name} - Project Brief

## Project Overview
- **Project Type**: {project_type.replace('_', ' ').title()}
- **Start Date**: {datetime.now().strftime('%Y-%m-%d')}
- **Client/Brand**: 
- **Campaign Goal**: 
- **Target Audience**: 
- **Budget**: 
- **Deadline**: 

## Deliverables
- [ ] 
- [ ] 
- [ ] 

## Brand Guidelines
- **Colors**: 
- **Fonts**: 
- **Tone**: 
- **Style**: 

## Social Media Specifications
- **Platform**: 
- **Dimensions**: 
- **Format**: 
- **Duration** (if video): 

## Notes
"""
        
        with open(project_path / "project_brief.md", "w") as f:
            f.write(brief_template)
        
        print(f"Created project template: {project_name}")
        return str(project_path)
    
    def batch_resize_images(self, directory, platform="instagram"):
        """Batch resize images for social media platforms"""
        sizes = {
            'instagram': {'post': '1080x1080', 'story': '1080x1920'},
            'facebook': {'post': '1200x630', 'cover': '820x312'},
            'twitter': {'post': '1200x675', 'header': '1500x500'},
            'linkedin': {'post': '1200x627', 'company': '1128x191'},
            'youtube': {'thumbnail': '1280x720', 'banner': '2560x1440'}
        }
        
        if platform not in sizes:
            print(f"Platform {platform} not supported")
            return
        
        input_dir = Path(directory)
        for size_type, dimensions in sizes[platform].items():
            output_dir = input_dir / f"{platform}_{size_type}"
            output_dir.mkdir(exist_ok=True)
            
            # Use ImageMagick to resize images
            for img_file in input_dir.glob("*.{jpg,jpeg,png,gif}"):
                if img_file.is_file():
                    output_file = output_dir / f"{img_file.stem}_{platform}_{size_type}{img_file.suffix}"
                    subprocess.run([
                        'convert', str(img_file), 
                        '-resize', dimensions + '^',
                        '-gravity', 'center',
                        '-extent', dimensions,
                        str(output_file)
                    ], check=False)
        
        print(f"Batch resized images for {platform}")
    
    def backup_projects(self):
        """Automated daily backup of marketing projects"""
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        backup_name = f"marketing_backup_{timestamp}.tar.gz"
        backup_path = self.backup_dir / backup_name
        
        # Create compressed backup
        subprocess.run([
            'tar', '-czf', str(backup_path),
            '-C', str(self.project_dir.parent),
            self.project_dir.name
        ], check=False)
        
        # Keep only last 7 backups
        backups = sorted(self.backup_dir.glob("marketing_backup_*.tar.gz"))
        if len(backups) > 7:
            for old_backup in backups[:-7]:
                old_backup.unlink()
        
        print(f"Created backup: {backup_name}")
    
    def generate_social_media_report(self):
        """Generate daily social media content report"""
        report_date = datetime.now().strftime('%Y-%m-%d')
        report_file = self.project_dir / f"daily_report_{report_date}.md"
        
        # Count files by type
        image_count = len(list(self.project_dir.rglob("*.{jpg,jpeg,png,gif}")))
        video_count = len(list(self.project_dir.rglob("*.{mp4,mov,avi,mkv}")))
        project_count = len([d for d in self.project_dir.iterdir() if d.is_dir()])
        
        report_content = f"""
# Daily Marketing Report - {report_date}

## Project Statistics
- **Active Projects**: {project_count}
- **Images Created**: {image_count}
- **Videos Created**: {video_count}

## Recent Activity
"""
        
        # Find recently modified files
        recent_files = []
        for file_path in self.project_dir.rglob("*"):
            if file_path.is_file():
                mod_time = datetime.fromtimestamp(file_path.stat().st_mtime)
                if (datetime.now() - mod_time).days < 1:
                    recent_files.append((file_path, mod_time))
        
        recent_files.sort(key=lambda x: x[1], reverse=True)
        
        for file_path, mod_time in recent_files[:10]:
            relative_path = file_path.relative_to(self.project_dir)
            report_content += f"- {mod_time.strftime('%H:%M')} - {relative_path}\n"
        
        with open(report_file, "w") as f:
            f.write(report_content)
        
        print(f"Generated daily report: {report_file}")
    
    def setup_automation_schedule(self):
        """Setup automated tasks schedule"""
        # Daily backup at 2 AM
        schedule.every().day.at("02:00").do(self.backup_projects)
        
        # Daily report at 6 PM
        schedule.every().day.at("18:00").do(self.generate_social_media_report)
        
        # Weekly cleanup at Sunday 3 AM
        schedule.every().sunday.at("03:00").do(self.cleanup_temp_files)
        
        print("Automation schedule configured")
    
    def cleanup_temp_files(self):
        """Clean up temporary files and old drafts"""
        # Remove temp files older than 7 days
        for temp_file in self.project_dir.rglob("*.tmp"):
            if (datetime.now() - datetime.fromtimestamp(temp_file.stat().st_mtime)).days > 7:
                temp_file.unlink()
        
        # Remove old drafts
        for draft_dir in self.project_dir.rglob("drafts"):
            if draft_dir.is_dir():
                for draft_file in draft_dir.iterdir():
                    if (datetime.now() - datetime.fromtimestamp(draft_file.stat().st_mtime)).days > 30:
                        draft_file.unlink()
        
        print("Cleanup completed")

if __name__ == '__main__':
    automation = MarketingWorkflowAutomation()
    
    # HTTP API for workflow automation
    from http.server import HTTPServer, BaseHTTPRequestHandler
    import socketserver
    
    class WorkflowHandler(BaseHTTPRequestHandler):
        def do_POST(self):
            if self.path == '/workflow/create_project':
                try:
                    content_length = int(self.headers['Content-Length'])
                    post_data = self.rfile.read(content_length)
                    data = json.loads(post_data.decode())
                    
                    project_name = data.get('name')
                    project_type = data.get('type', 'general')
                    
                    project_path = automation.setup_project_template(project_name, project_type)
                    
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.end_headers()
                    
                    response = {'success': True, 'path': project_path}
                    self.wfile.write(json.dumps(response).encode())
                    
                except Exception as e:
                    self.send_error(500, f"Project creation error: {str(e)}")
            
            elif self.path == '/workflow/resize_images':
                try:
                    content_length = int(self.headers['Content-Length'])
                    post_data = self.rfile.read(content_length)
                    data = json.loads(post_data.decode())
                    
                    directory = data.get('directory')
                    platform = data.get('platform', 'instagram')
                    
                    automation.batch_resize_images(directory, platform)
                    
                    self.send_response(200)
                    self.send_header('Content-Type', 'application/json')
                    self.send_header('Access-Control-Allow-Origin', '*')
                    self.end_headers()
                    
                    response = {'success': True, 'platform': platform}
                    self.wfile.write(json.dumps(response).encode())
                    
                except Exception as e:
                    self.send_error(500, f"Image resize error: {str(e)}")
    
    # Setup automation schedule
    automation.setup_automation_schedule()
    
    # Start API server
    PORT = 8087
    with socketserver.TCPServer(("", PORT), WorkflowHandler) as httpd:
        print(f"Marketing workflow API running on port {PORT}")
        
        # Run scheduled tasks in background
        def run_schedule():
            while True:
                schedule.run_pending()
                time.sleep(60)
        
        import threading
        schedule_thread = threading.Thread(target=run_schedule, daemon=True)
        schedule_thread.start()
        
        httpd.serve_forever()
EOF

# Marketing Dashboard Web Interface
cat > "/opt/marketing-optimization/dashboard/marketing-dashboard.html" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Marketing Agency Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
        }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        .header { 
            background: rgba(255,255,255,0.95);
            padding: 20px;
            border-radius: 15px;
            margin-bottom: 20px;
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
        }
        .title { 
            font-size: 2.5em;
            font-weight: 700;
            color: #4A90E2;
            text-align: center;
        }
        .dashboard-grid { 
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
        }
        .card { 
            background: rgba(255,255,255,0.95);
            padding: 25px;
            border-radius: 15px;
            box-shadow: 0 8px 32px rgba(0,0,0,0.1);
            transition: transform 0.3s ease;
        }
        .card:hover { transform: translateY(-5px); }
        .card-title { 
            font-size: 1.5em;
            font-weight: 600;
            margin-bottom: 15px;
            color: #2C3E50;
        }
        .performance-controls { margin-bottom: 20px; }
        .btn { 
            background: linear-gradient(135deg, #4A90E2, #357ABD);
            color: white;
            border: none;
            padding: 12px 20px;
            border-radius: 8px;
            cursor: pointer;
            margin: 5px;
            font-weight: 500;
            transition: all 0.3s ease;
        }
        .btn:hover { 
            transform: translateY(-2px);
            box-shadow: 0 4px 16px rgba(74, 144, 226, 0.4);
        }
        .stats-grid { 
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 15px;
        }
        .stat-item { 
            text-align: center;
            padding: 15px;
            background: linear-gradient(135deg, #f8f9fa, #e9ecef);
            border-radius: 10px;
        }
        .stat-value { 
            font-size: 2em;
            font-weight: 700;
            color: #4A90E2;
        }
        .stat-label { 
            font-size: 0.9em;
            color: #666;
        }
        .project-form { margin-bottom: 20px; }
        .form-group { margin-bottom: 15px; }
        .form-control { 
            width: 100%;
            padding: 12px;
            border: 2px solid #e9ecef;
            border-radius: 8px;
            font-size: 14px;
            transition: border-color 0.3s ease;
        }
        .form-control:focus { 
            outline: none;
            border-color: #4A90E2;
        }
        .status-indicator { 
            display: inline-block;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-right: 8px;
        }
        .status-good { background: #28a745; }
        .status-warning { background: #ffc107; }
        .status-critical { background: #dc3545; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1 class="title">🎨 Marketing Agency Dashboard</h1>
        </div>
        
        <div class="dashboard-grid">
            <!-- Performance Management -->
            <div class="card">
                <h2 class="card-title">⚡ Performance Management</h2>
                <div class="performance-controls">
                    <button class="btn" onclick="applyProfile('design')">Design Mode</button>
                    <button class="btn" onclick="applyProfile('video')">Video Editing</button>
                    <button class="btn" onclick="applyProfile('social')">Social Media</button>
                    <button class="btn" onclick="applyProfile('presentation')">Presentations</button>
                    <button class="btn" onclick="autoOptimize()">Auto Optimize</button>
                </div>
                <div id="performance-status"></div>
            </div>
            
            <!-- System Statistics -->
            <div class="card">
                <h2 class="card-title">📊 System Stats</h2>
                <div class="stats-grid">
                    <div class="stat-item">
                        <div class="stat-value" id="cpu-usage">--</div>
                        <div class="stat-label">CPU Usage</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-value" id="memory-usage">--</div>
                        <div class="stat-label">Memory Usage</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-value" id="disk-usage">--</div>
                        <div class="stat-label">Disk Usage</div>
                    </div>
                    <div class="stat-item">
                        <div class="stat-value" id="processes">--</div>
                        <div class="stat-label">Processes</div>
                    </div>
                </div>
            </div>
            
            <!-- Project Creation -->
            <div class="card">
                <h2 class="card-title">📁 Create New Project</h2>
                <div class="project-form">
                    <div class="form-group">
                        <input type="text" class="form-control" id="project-name" placeholder="Project Name">
                    </div>
                    <div class="form-group">
                        <select class="form-control" id="project-type">
                            <option value="social_campaign">Social Media Campaign</option>
                            <option value="brand_design">Brand Design</option>
                            <option value="video_campaign">Video Campaign</option>
                            <option value="website_content">Website Content</option>
                        </select>
                    </div>
                    <button class="btn" onclick="createProject()">Create Project</button>
                </div>
            </div>
            
            <!-- File Transfer -->
            <div class="card">
                <h2 class="card-title">📤 File Management</h2>
                <div style="margin-bottom: 15px;">
                    <input type="file" id="file-input" multiple style="display: none;">
                    <button class="btn" onclick="document.getElementById('file-input').click()">
                        Upload Files
                    </button>
                    <button class="btn" onclick="openFileManager()">File Manager</button>
                </div>
                <div id="upload-status"></div>
            </div>
            
            <!-- Monitor Control -->
            <div class="card">
                <h2 class="card-title">🖥️ Display Management</h2>
                <div style="margin-bottom: 15px;">
                    <button class="btn" onclick="setMonitorLayout('single')">Single Monitor</button>
                    <button class="btn" onclick="setMonitorLayout('dual-horizontal')">Dual Horizontal</button>
                    <button class="btn" onclick="setMonitorLayout('dual-vertical')">Dual Vertical</button>
                </div>
            </div>
            
            <!-- Recording Control -->
            <div class="card">
                <h2 class="card-title">🎥 Session Recording</h2>
                <div style="margin-bottom: 15px;">
                    <button class="btn" onclick="startRecording()">Start Recording</button>
                    <button class="btn" onclick="stopRecording()">Stop Recording</button>
                </div>
                <div id="recording-status"></div>
            </div>
        </div>
    </div>

    <script>
        let currentRecordingSession = null;
        
        // Performance Management
        async function applyProfile(profile) {
            try {
                const response = await fetch('http://localhost:8086/performance/profile', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ profile })
                });
                
                const result = await response.json();
                document.getElementById('performance-status').innerHTML = 
                    `<span class="status-indicator status-good"></span>Applied ${profile} profile`;
            } catch (error) {
                console.error('Profile application failed:', error);
            }
        }
        
        async function autoOptimize() {
            try {
                const response = await fetch('http://localhost:8086/performance/auto', {
                    method: 'POST'
                });
                
                const result = await response.json();
                document.getElementById('performance-status').innerHTML = 
                    `<span class="status-indicator status-good"></span>Auto-optimized: ${result.profile_applied || 'No optimization needed'}`;
            } catch (error) {
                console.error('Auto optimization failed:', error);
            }
        }
        
        // System Statistics
        async function updateStats() {
            try {
                const response = await fetch('http://localhost:8086/performance/stats');
                const stats = await response.json();
                
                document.getElementById('cpu-usage').textContent = `${stats.cpu_percent.toFixed(1)}%`;
                document.getElementById('memory-usage').textContent = `${stats.memory_percent.toFixed(1)}%`;
                document.getElementById('disk-usage').textContent = `${stats.disk_usage.toFixed(1)}%`;
                document.getElementById('processes').textContent = stats.running_processes;
            } catch (error) {
                console.error('Stats update failed:', error);
            }
        }
        
        // Project Creation
        async function createProject() {
            const name = document.getElementById('project-name').value;
            const type = document.getElementById('project-type').value;
            
            if (!name) {
                alert('Please enter a project name');
                return;
            }
            
            try {
                const response = await fetch('http://localhost:8087/workflow/create_project', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ name, type })
                });
                
                const result = await response.json();
                alert(`Project created successfully: ${result.path}`);
                document.getElementById('project-name').value = '';
            } catch (error) {
                console.error('Project creation failed:', error);
                alert('Project creation failed');
            }
        }
        
        // Monitor Layout
        async function setMonitorLayout(layout) {
            try {
                const response = await fetch('http://localhost:8084/monitor/layout', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ layout })
                });
                
                const result = await response.json();
                console.log(`Monitor layout set to: ${layout}`);
            } catch (error) {
                console.error('Monitor layout change failed:', error);
            }
        }
        
        // Recording
        async function startRecording() {
            const sessionName = `session_${Date.now()}`;
            currentRecordingSession = sessionName;
            
            try {
                const response = await fetch('http://localhost:8085/recording/start', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ session_name: sessionName })
                });
                
                const result = await response.json();
                document.getElementById('recording-status').innerHTML = 
                    `<span class="status-indicator status-good"></span>Recording: ${sessionName}`;
            } catch (error) {
                console.error('Recording start failed:', error);
            }
        }
        
        async function stopRecording() {
            if (!currentRecordingSession) {
                alert('No active recording session');
                return;
            }
            
            try {
                const response = await fetch('http://localhost:8085/recording/stop', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ session_name: currentRecordingSession })
                });
                
                const result = await response.json();
                document.getElementById('recording-status').innerHTML = 
                    `<span class="status-indicator status-warning"></span>Recording stopped: ${currentRecordingSession}`;
                currentRecordingSession = null;
            } catch (error) {
                console.error('Recording stop failed:', error);
            }
        }
        
        function openFileManager() {
            // Open file manager in new tab/window
            window.open('/file-manager', '_blank');
        }
        
        // File Upload
        document.getElementById('file-input').addEventListener('change', async function(e) {
            const files = e.target.files;
            const uploadStatus = document.getElementById('upload-status');
            
            for (let file of files) {
                const formData = new FormData();
                formData.append('file', file);
                
                try {
                    uploadStatus.innerHTML = `<span class="status-indicator status-warning"></span>Uploading ${file.name}...`;
                    
                    const reader = new FileReader();
                    reader.onload = async function(e) {
                        const base64Content = btoa(e.target.result);
                        
                        const response = await fetch('http://localhost:8083/upload', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify({
                                filename: file.name,
                                content: base64Content
                            })
                        });
                        
                        const result = await response.json();
                        uploadStatus.innerHTML = `<span class="status-indicator status-good"></span>Uploaded: ${file.name}`;
                    };
                    
                    reader.readAsBinaryString(file);
                } catch (error) {
                    console.error('Upload failed:', error);
                    uploadStatus.innerHTML = `<span class="status-indicator status-critical"></span>Upload failed: ${file.name}`;
                }
            }
        });
        
        // Update stats every 5 seconds
        setInterval(updateStats, 5000);
        updateStats(); // Initial load
    </script>
</body>
</html>
EOF

# Make scripts executable
chmod +x /opt/marketing-optimization/performance/graphics-optimization.sh
chmod +x /opt/marketing-optimization/profiles/performance-profiles.py
chmod +x /opt/marketing-optimization/automation/workflow-automation.py

# Set ownership
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "/opt/marketing-optimization"
chown -R "${DEV_USERNAME}:${DEV_USERNAME}" "${DEV_HOME}/Marketing-Projects"

# Run graphics optimization
/opt/marketing-optimization/performance/graphics-optimization.sh

log_info "Marketing optimization setup complete"
log_info "Services available on ports:"
log_info "- Performance API: 8086"
log_info "- Workflow API: 8087"
log_info "- Dashboard: /opt/marketing-optimization/dashboard/marketing-dashboard.html"