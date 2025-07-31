#!/usr/bin/env python3

"""
Web Management Interface for Webtop KDE Marketing Suite
Enterprise-grade web dashboard for container management
"""

import os
import json
import subprocess
import asyncio
from datetime import datetime, timedelta
from typing import Dict, List, Optional
from pathlib import Path

from fastapi import FastAPI, WebSocket, HTTPException, Depends, status
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from pydantic import BaseModel
import docker
import psutil
import secrets

# Configuration
WEB_PORT = int(os.getenv('WEBTOP_WEB_PORT', 8090))
WEB_HOST = os.getenv('WEBTOP_WEB_HOST', '0.0.0.0')
CONTAINER_REGISTRY = '.container-registry.json'
CONFIG_DIR = 'config'
BACKUP_DIR = 'backups'
TEMPLATE_DIR = 'templates'

# Security
security = HTTPBasic()
ADMIN_USERNAME = os.getenv('WEBTOP_WEB_USER', 'admin')
ADMIN_PASSWORD = os.getenv('WEBTOP_WEB_PASS', 'webtop123')

# FastAPI app
app = FastAPI(
    title="Webtop KDE Management Dashboard",
    description="Enterprise container management interface",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Templates and static files
templates = Jinja2Templates(directory="web/templates")
app.mount("/static", StaticFiles(directory="web/static"), name="static")

# Docker client
docker_client = docker.from_env()

# Pydantic models
class ContainerConfig(BaseModel):
    name: str
    environment: str = "development"
    profile: str = "standard"
    memory_limit: str = "8g"
    cpu_limit: str = "4"
    enable_auth: bool = False

class BackupConfig(BaseModel):
    container_name: str
    backup_type: str = "full"
    cloud_storage: bool = False
    retention_days: int = 30

class SystemStats(BaseModel):
    cpu_usage: float
    memory_usage: float
    disk_usage: float
    container_count: int
    running_containers: int

# Authentication
def authenticate(credentials: HTTPBasicCredentials = Depends(security)):
    correct_username = secrets.compare_digest(credentials.username, ADMIN_USERNAME)
    correct_password = secrets.compare_digest(credentials.password, ADMIN_PASSWORD)
    if not (correct_username and correct_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
            headers={"WWW-Authenticate": "Basic"},
        )
    return credentials.username

# Utility functions
def load_container_registry() -> Dict:
    """Load container registry from JSON file"""
    if os.path.exists(CONTAINER_REGISTRY):
        with open(CONTAINER_REGISTRY, 'r') as f:
            return json.load(f)
    return {}

def save_container_registry(registry: Dict):
    """Save container registry to JSON file"""
    with open(CONTAINER_REGISTRY, 'w') as f:
        json.dump(registry, f, indent=2)

def run_webtop_command(command: str) -> Dict:
    """Run webtop.sh command and return result"""
    try:
        result = subprocess.run(
            f"./webtop.sh {command}",
            shell=True,
            capture_output=True,
            text=True,
            timeout=30
        )
        return {
            "success": result.returncode == 0,
            "stdout": result.stdout,
            "stderr": result.stderr
        }
    except subprocess.TimeoutExpired:
        return {
            "success": False,
            "error": "Command timed out"
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }

def get_system_stats() -> SystemStats:
    """Get current system statistics"""
    cpu_usage = psutil.cpu_percent(interval=1)
    memory = psutil.virtual_memory()
    disk = psutil.disk_usage('.')
    
    # Count containers
    try:
        all_containers = docker_client.containers.list(all=True)
        webtop_containers = [c for c in all_containers if c.name.startswith('webtop-')]
        running_containers = [c for c in webtop_containers if c.status == 'running']
        
        return SystemStats(
            cpu_usage=cpu_usage,
            memory_usage=memory.percent,
            disk_usage=(disk.used / disk.total) * 100,
            container_count=len(webtop_containers),
            running_containers=len(running_containers)
        )
    except Exception:
        return SystemStats(
            cpu_usage=cpu_usage,
            memory_usage=memory.percent,
            disk_usage=(disk.used / disk.total) * 100,
            container_count=0,
            running_containers=0
        )

def get_container_stats(container_name: str) -> Dict:
    """Get statistics for a specific container"""
    try:
        container = docker_client.containers.get(f"webtop-{container_name}")
        stats = container.stats(stream=False)
        
        # Calculate CPU percentage
        cpu_delta = stats['cpu_stats']['cpu_usage']['total_usage'] - \
                   stats['precpu_stats']['cpu_usage']['total_usage']
        system_delta = stats['cpu_stats']['system_cpu_usage'] - \
                      stats['precpu_stats']['system_cpu_usage']
        cpu_percent = (cpu_delta / system_delta) * 100.0 if system_delta > 0 else 0.0
        
        # Calculate memory percentage
        memory_usage = stats['memory_stats']['usage']
        memory_limit = stats['memory_stats']['limit']
        memory_percent = (memory_usage / memory_limit) * 100.0 if memory_limit > 0 else 0.0
        
        return {
            "status": container.status,
            "cpu_percent": round(cpu_percent, 2),
            "memory_percent": round(memory_percent, 2),
            "memory_usage_mb": round(memory_usage / 1024 / 1024, 2),
            "memory_limit_mb": round(memory_limit / 1024 / 1024, 2),
            "network_rx_bytes": stats['networks'].get('eth0', {}).get('rx_bytes', 0),
            "network_tx_bytes": stats['networks'].get('eth0', {}).get('tx_bytes', 0),
        }
    except Exception as e:
        return {"error": str(e)}

# Routes
@app.get("/", response_class=HTMLResponse)
async def dashboard(username: str = Depends(authenticate)):
    """Main dashboard page"""
    return templates.TemplateResponse("dashboard.html", {
        "request": {},
        "username": username,
        "title": "Webtop Management Dashboard"
    })

@app.get("/api/system/stats")
async def api_system_stats(username: str = Depends(authenticate)):
    """Get system statistics"""
    return get_system_stats()

@app.get("/api/containers")
async def api_list_containers(username: str = Depends(authenticate)):
    """List all managed containers"""
    registry = load_container_registry()
    containers = []
    
    for name, config in registry.items():
        container_stats = get_container_stats(name)
        containers.append({
            "name": name,
            "config": config,
            "stats": container_stats
        })
    
    return {"containers": containers}

@app.post("/api/containers")
async def api_create_container(
    config: ContainerConfig,
    username: str = Depends(authenticate)
):
    """Create a new container"""
    command = f"up --name {config.name}"
    if config.environment != "development":
        command += f" --{config.environment}"
    if config.enable_auth:
        command += " --auth"
    
    result = run_webtop_command(command)
    return result

@app.delete("/api/containers/{container_name}")
async def api_delete_container(
    container_name: str,
    username: str = Depends(authenticate)
):
    """Delete a container"""
    result = run_webtop_command(f"remove {container_name}")
    return result

@app.post("/api/containers/{container_name}/start")
async def api_start_container(
    container_name: str,
    username: str = Depends(authenticate)
):
    """Start a container"""
    result = run_webtop_command(f"up --name {container_name}")
    return result

@app.post("/api/containers/{container_name}/stop")
async def api_stop_container(
    container_name: str,
    username: str = Depends(authenticate)
):
    """Stop a container"""
    try:
        container = docker_client.containers.get(f"webtop-{container_name}")
        container.stop()
        return {"success": True, "message": f"Container {container_name} stopped"}
    except Exception as e:
        return {"success": False, "error": str(e)}

@app.post("/api/containers/{container_name}/restart")
async def api_restart_container(
    container_name: str,
    username: str = Depends(authenticate)
):
    """Restart a container"""
    try:
        container = docker_client.containers.get(f"webtop-{container_name}")
        container.restart()
        return {"success": True, "message": f"Container {container_name} restarted"}
    except Exception as e:
        return {"success": False, "error": str(e)}

@app.get("/api/containers/{container_name}/logs")
async def api_container_logs(
    container_name: str,
    lines: int = 100,
    username: str = Depends(authenticate)
):
    """Get container logs"""
    try:
        container = docker_client.containers.get(f"webtop-{container_name}")
        logs = container.logs(tail=lines).decode('utf-8')
        return {"logs": logs}
    except Exception as e:
        return {"error": str(e)}

@app.post("/api/containers/{container_name}/backup")
async def api_backup_container(
    container_name: str,
    config: BackupConfig,
    username: str = Depends(authenticate)
):
    """Backup a container"""
    result = run_webtop_command(f"backup {container_name}")
    
    # If cloud storage is enabled, trigger cloud backup
    if config.cloud_storage and result.get("success"):
        cloud_result = run_webtop_command(f"backup-cloud {container_name}")
        result["cloud_backup"] = cloud_result
    
    return result

@app.get("/api/containers/{container_name}/backups")
async def api_list_backups(
    container_name: str,
    username: str = Depends(authenticate)
):
    """List backups for a container"""
    backup_path = Path(BACKUP_DIR)
    if not backup_path.exists():
        return {"backups": []}
    
    backups = []
    for backup_dir in backup_path.iterdir():
        if backup_dir.is_dir() and backup_dir.name.startswith(f"{container_name}_"):
            stat = backup_dir.stat()
            backups.append({
                "name": backup_dir.name,
                "created": datetime.fromtimestamp(stat.st_ctime).isoformat(),
                "size_mb": sum(f.stat().st_size for f in backup_dir.rglob('*') if f.is_file()) / 1024 / 1024
            })
    
    return {"backups": sorted(backups, key=lambda x: x["created"], reverse=True)}

@app.post("/api/containers/{container_name}/restore")
async def api_restore_container(
    container_name: str,
    backup_name: str,
    username: str = Depends(authenticate)
):
    """Restore a container from backup"""
    result = run_webtop_command(f"restore {container_name} {backup_name}")
    return result

@app.get("/api/templates")
async def api_list_templates(username: str = Depends(authenticate)):
    """List available templates"""
    result = run_webtop_command("template list")
    return result

@app.post("/api/templates")
async def api_create_template(
    container_name: str,
    template_name: str,
    username: str = Depends(authenticate)
):
    """Create a template from container"""
    result = run_webtop_command(f"template save {container_name} {template_name}")
    return result

@app.post("/api/templates/{template_name}/create")
async def api_create_from_template(
    template_name: str,
    container_name: str,
    username: str = Depends(authenticate)
):
    """Create container from template"""
    result = run_webtop_command(f"template create {container_name} {template_name}")
    return result

@app.get("/api/health")
async def api_health_check(username: str = Depends(authenticate)):
    """Get system health status"""
    result = run_webtop_command("health check")
    return result

@app.get("/api/performance")
async def api_performance_stats(username: str = Depends(authenticate)):
    """Get performance statistics"""
    result = run_webtop_command("performance report")
    return result

@app.post("/api/performance/optimize")
async def api_optimize_performance(
    container_name: Optional[str] = None,
    username: str = Depends(authenticate)
):
    """Optimize system or container performance"""
    if container_name:
        result = run_webtop_command(f"performance optimize container {container_name}")
    else:
        result = run_webtop_command("performance optimize auto")
    return result

# WebSocket for real-time updates
@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    try:
        while True:
            # Send system stats every 5 seconds
            stats = get_system_stats()
            await websocket.send_json({
                "type": "system_stats",
                "data": stats.dict()
            })
            
            # Send container updates
            registry = load_container_registry()
            container_updates = []
            for name in registry.keys():
                container_stats = get_container_stats(name)
                container_updates.append({
                    "name": name,
                    "stats": container_stats
                })
            
            await websocket.send_json({
                "type": "container_updates",
                "data": container_updates
            })
            
            await asyncio.sleep(5)
    except Exception as e:
        print(f"WebSocket error: {e}")
    finally:
        await websocket.close()

# Startup event
@app.on_event("startup")
async def startup_event():
    """Initialize web interface"""
    # Create necessary directories
    os.makedirs("web/templates", exist_ok=True)
    os.makedirs("web/static/css", exist_ok=True)
    os.makedirs("web/static/js", exist_ok=True)
    
    print(f"🌐 Webtop Web Management Interface starting on http://{WEB_HOST}:{WEB_PORT}")
    print(f"🔐 Login: {ADMIN_USERNAME} / {ADMIN_PASSWORD}")

if __name__ == "__main__":
    uvicorn.run(
        "web-interface:app",
        host=WEB_HOST,
        port=WEB_PORT,
        reload=False,
        access_log=True
    )