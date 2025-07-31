// Dashboard JavaScript
let socket = null;
let currentSection = 'dashboard';
let activityLog = [];

// Initialize dashboard
document.addEventListener('DOMContentLoaded', function() {
    initializeWebSocket();
    initializeNavigation();
    loadSystemStats();
    loadContainers();
    showSection('dashboard');
});

// WebSocket connection
function initializeWebSocket() {
    const wsProtocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${wsProtocol}//${window.location.host}/ws`;
    
    socket = new WebSocket(wsUrl);
    
    socket.onopen = function(event) {
        console.log('WebSocket connected');
        addActivity('info', 'Connected to real-time updates');
    };
    
    socket.onmessage = function(event) {
        const data = JSON.parse(event.data);
        
        if (data.type === 'system_stats') {
            updateSystemStats(data.data);
        } else if (data.type === 'container_updates') {
            updateContainerStats(data.data);
        }
    };
    
    socket.onclose = function(event) {
        console.log('WebSocket disconnected');
        addActivity('warning', 'Real-time updates disconnected');
        // Attempt to reconnect after 5 seconds
        setTimeout(initializeWebSocket, 5000);
    };
    
    socket.onerror = function(error) {
        console.error('WebSocket error:', error);
        addActivity('error', 'WebSocket connection error');
    };
}

// Navigation
function initializeNavigation() {
    const navLinks = document.querySelectorAll('.nav-link[data-section]');
    navLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            const section = this.getAttribute('data-section');
            showSection(section);
            
            // Update active nav item
            navLinks.forEach(l => l.classList.remove('active'));
            this.classList.add('active');
        });
    });
}

function showSection(sectionName) {
    // Hide all sections
    const sections = document.querySelectorAll('.content-section');
    sections.forEach(section => {
        section.style.display = 'none';
    });
    
    // Show selected section
    const targetSection = document.getElementById(`${sectionName}-section`);
    if (targetSection) {
        targetSection.style.display = 'block';
        currentSection = sectionName;
        
        // Load section-specific data
        switch (sectionName) {
            case 'containers':
                loadContainers();
                break;
            case 'templates':
                loadTemplates();
                break;
            case 'backups':
                loadBackups();
                break;
            case 'monitoring':
                initializeCharts();
                break;
        }
    }
}

// System statistics
function loadSystemStats() {
    fetch('/api/system/stats')
        .then(response => response.json())
        .then(data => updateSystemStats(data))
        .catch(error => {
            console.error('Error loading system stats:', error);
            addActivity('error', 'Failed to load system statistics');
        });
}

function updateSystemStats(stats) {
    document.getElementById('cpu-usage').textContent = `${stats.cpu_usage.toFixed(1)}%`;
    document.getElementById('memory-usage').textContent = `${stats.memory_usage.toFixed(1)}%`;
    document.getElementById('disk-usage').textContent = `${stats.disk_usage.toFixed(1)}%`;
    document.getElementById('running-containers').textContent = `${stats.running_containers}/${stats.container_count}`;
}

// Container management
function loadContainers() {
    fetch('/api/containers')
        .then(response => response.json())
        .then(data => updateContainersTable(data.containers))
        .catch(error => {
            console.error('Error loading containers:', error);
            addActivity('error', 'Failed to load containers');
        });
}

function updateContainersTable(containers) {
    const tbody = document.getElementById('containers-tbody');
    tbody.innerHTML = '';
    
    containers.forEach(container => {
        const row = createContainerRow(container);
        tbody.appendChild(row);
    });
}

function createContainerRow(container) {
    const row = document.createElement('tr');
    const status = container.stats.status || 'unknown';
    const statusClass = status === 'running' ? 'running' : 'stopped';
    
    row.innerHTML = `
        <td>
            <strong>${container.name}</strong>
            <br><small class="text-muted">${container.config.name}</small>
        </td>
        <td>
            <span class="status-indicator ${statusClass}"></span>
            <span class="container-status ${statusClass}">${status}</span>
        </td>
        <td>
            ${container.stats.cpu_percent || 'N/A'}%
            ${container.stats.cpu_percent ? 
                `<div class="progress progress-sm mt-1">
                    <div class="progress-bar" role="progressbar" style="width: ${container.stats.cpu_percent}%"></div>
                </div>` : ''
            }
        </td>
        <td>
            ${container.stats.memory_percent ? container.stats.memory_percent.toFixed(1) : 'N/A'}%
            ${container.stats.memory_usage_mb ? 
                `<br><small class="text-muted">${container.stats.memory_usage_mb}MB</small>` : ''
            }
        </td>
        <td>
            <small>
                HTTP: ${container.config.ports?.http || 'N/A'}<br>
                SSH: ${container.config.ports?.ssh || 'N/A'}
            </small>
        </td>
        <td class="container-actions">
            <div class="action-buttons">
                ${status === 'running' ? 
                    `<button class="btn btn-sm btn-warning" onclick="stopContainer('${container.name}')">
                        <i class="fas fa-stop"></i> Stop
                    </button>
                    <button class="btn btn-sm btn-info" onclick="restartContainer('${container.name}')">
                        <i class="fas fa-redo"></i> Restart
                    </button>` :
                    `<button class="btn btn-sm btn-success" onclick="startContainer('${container.name}')">
                        <i class="fas fa-play"></i> Start
                    </button>`
                }
                <button class="btn btn-sm btn-primary" onclick="openContainer('${container.name}')">
                    <i class="fas fa-external-link-alt"></i> Open
                </button>
                <button class="btn btn-sm btn-secondary" onclick="viewContainerLogs('${container.name}')">
                    <i class="fas fa-file-alt"></i> Logs
                </button>
                <button class="btn btn-sm btn-info" onclick="backupContainer('${container.name}')">
                    <i class="fas fa-save"></i> Backup
                </button>
                <button class="btn btn-sm btn-danger" onclick="deleteContainer('${container.name}')">
                    <i class="fas fa-trash"></i> Delete
                </button>
            </div>
        </td>
    `;
    
    return row;
}

function updateContainerStats(containerUpdates) {
    if (currentSection !== 'containers') return;
    
    containerUpdates.forEach(update => {
        const row = document.querySelector(`tr[data-container="${update.name}"]`);
        if (row) {
            // Update CPU and memory stats
            const cpuCell = row.querySelector('.cpu-stats');
            const memoryCell = row.querySelector('.memory-stats');
            
            if (cpuCell && update.stats.cpu_percent) {
                cpuCell.textContent = `${update.stats.cpu_percent}%`;
            }
            
            if (memoryCell && update.stats.memory_percent) {
                memoryCell.textContent = `${update.stats.memory_percent.toFixed(1)}%`;
            }
        }
    });
}

// Container actions
function startContainer(containerName) {
    fetch(`/api/containers/${containerName}/start`, { method: 'POST' })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                addActivity('success', `Container ${containerName} started`);
                loadContainers();
            } else {
                addActivity('error', `Failed to start container ${containerName}: ${data.error}`);
            }
        })
        .catch(error => {
            console.error('Error starting container:', error);
            addActivity('error', `Error starting container ${containerName}`);
        });
}

function stopContainer(containerName) {
    fetch(`/api/containers/${containerName}/stop`, { method: 'POST' })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                addActivity('success', `Container ${containerName} stopped`);
                loadContainers();
            } else {
                addActivity('error', `Failed to stop container ${containerName}: ${data.error}`);
            }
        })
        .catch(error => {
            console.error('Error stopping container:', error);
            addActivity('error', `Error stopping container ${containerName}`);
        });
}

function restartContainer(containerName) {
    fetch(`/api/containers/${containerName}/restart`, { method: 'POST' })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                addActivity('success', `Container ${containerName} restarted`);
                loadContainers();
            } else {
                addActivity('error', `Failed to restart container ${containerName}: ${data.error}`);
            }
        })
        .catch(error => {
            console.error('Error restarting container:', error);
            addActivity('error', `Error restarting container ${containerName}`);
        });
}

function deleteContainer(containerName) {
    if (confirm(`Are you sure you want to delete container ${containerName}? This action cannot be undone.`)) {
        fetch(`/api/containers/${containerName}`, { method: 'DELETE' })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    addActivity('success', `Container ${containerName} deleted`);
                    loadContainers();
                } else {
                    addActivity('error', `Failed to delete container ${containerName}: ${data.error}`);
                }
            })
            .catch(error => {
                console.error('Error deleting container:', error);
                addActivity('error', `Error deleting container ${containerName}`);
            });
    }
}

function openContainer(containerName) {
    // Get container port from registry and open in new tab
    fetch('/api/containers')
        .then(response => response.json())
        .then(data => {
            const container = data.containers.find(c => c.name === containerName);
            if (container && container.config.ports?.http) {
                window.open(`http://localhost:${container.config.ports.http}`, '_blank');
            }
        });
}

function viewContainerLogs(containerName) {
    fetch(`/api/containers/${containerName}/logs`)
        .then(response => response.json())
        .then(data => {
            if (data.logs) {
                // Create modal to show logs
                showLogsModal(containerName, data.logs);
            } else {
                addActivity('error', `Failed to get logs for container ${containerName}`);
            }
        })
        .catch(error => {
            console.error('Error getting container logs:', error);
            addActivity('error', `Error getting logs for container ${containerName}`);
        });
}

function backupContainer(containerName) {
    const config = {
        container_name: containerName,
        backup_type: 'full',
        cloud_storage: false,
        retention_days: 30
    };
    
    fetch(`/api/containers/${containerName}/backup`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(config)
    })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                addActivity('success', `Container ${containerName} backed up successfully`);
            } else {
                addActivity('error', `Failed to backup container ${containerName}: ${data.error}`);
            }
        })
        .catch(error => {
            console.error('Error backing up container:', error);
            addActivity('error', `Error backing up container ${containerName}`);
        });
}

// Modal functions
function showCreateContainerModal() {
    const modal = new bootstrap.Modal(document.getElementById('createContainerModal'));
    modal.show();
}

function createContainer() {
    const form = document.getElementById('createContainerForm');
    const formData = new FormData(form);
    
    const config = {
        name: document.getElementById('containerName').value,
        environment: document.getElementById('environment').value,
        profile: document.getElementById('profile').value,
        enable_auth: document.getElementById('enableAuth').checked
    };
    
    fetch('/api/containers', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(config)
    })
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                addActivity('success', `Container ${config.name} created successfully`);
                const modal = bootstrap.Modal.getInstance(document.getElementById('createContainerModal'));
                modal.hide();
                form.reset();
                loadContainers();
            } else {
                addActivity('error', `Failed to create container ${config.name}: ${data.error}`);
            }
        })
        .catch(error => {
            console.error('Error creating container:', error);
            addActivity('error', `Error creating container ${config.name}`);
        });
}

function showLogsModal(containerName, logs) {
    // Create and show logs modal
    const modalHtml = `
        <div class="modal fade" id="logsModal" tabindex="-1">
            <div class="modal-dialog modal-lg">
                <div class="modal-content">
                    <div class="modal-header">
                        <h5 class="modal-title">Container Logs: ${containerName}</h5>
                        <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                    </div>
                    <div class="modal-body">
                        <pre style="background-color: #1e1e1e; color: #d4d4d4; padding: 1rem; border-radius: 0.25rem; max-height: 400px; overflow-y: auto;">${logs}</pre>
                    </div>
                    <div class="modal-footer">
                        <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Close</button>
                    </div>
                </div>
            </div>
        </div>
    `;
    
    // Remove existing modal if present
    const existingModal = document.getElementById('logsModal');
    if (existingModal) {
        existingModal.remove();
    }
    
    // Add modal to body
    document.body.insertAdjacentHTML('beforeend', modalHtml);
    
    // Show modal
    const modal = new bootstrap.Modal(document.getElementById('logsModal'));
    modal.show();
    
    // Clean up when modal is hidden
    document.getElementById('logsModal').addEventListener('hidden.bs.modal', function() {
        this.remove();
    });
}

// Templates
function loadTemplates() {
    fetch('/api/templates')
        .then(response => response.json())
        .then(data => updateTemplatesGrid(data))
        .catch(error => {
            console.error('Error loading templates:', error);
            addActivity('error', 'Failed to load templates');
        });
}

function updateTemplatesGrid(templates) {
    const grid = document.getElementById('templates-grid');
    grid.innerHTML = '';
    
    // Add template cards here
    grid.innerHTML = '<div class="col-12"><p class="text-muted">Templates will be displayed here</p></div>';
}

// Backups
function loadBackups() {
    // Load backups for all containers
    fetch('/api/containers')
        .then(response => response.json())
        .then(data => {
            const promises = data.containers.map(container => 
                fetch(`/api/containers/${container.name}/backups`)
                    .then(response => response.json())
                    .then(backups => ({ container: container.name, backups: backups.backups || [] }))
            );
            
            return Promise.all(promises);
        })
        .then(allBackups => updateBackupsTable(allBackups))
        .catch(error => {
            console.error('Error loading backups:', error);
            addActivity('error', 'Failed to load backups');
        });
}

function updateBackupsTable(allBackups) {
    const tbody = document.getElementById('backups-tbody');
    tbody.innerHTML = '';
    
    allBackups.forEach(containerBackups => {
        containerBackups.backups.forEach(backup => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td>${containerBackups.container}</td>
                <td>${backup.name}</td>
                <td>${new Date(backup.created).toLocaleString()}</td>
                <td>${backup.size_mb.toFixed(2)} MB</td>
                <td>
                    <button class="btn btn-sm btn-primary" onclick="restoreBackup('${containerBackups.container}', '${backup.name}')">
                        <i class="fas fa-undo"></i> Restore
                    </button>
                    <button class="btn btn-sm btn-danger" onclick="deleteBackup('${containerBackups.container}', '${backup.name}')">
                        <i class="fas fa-trash"></i> Delete
                    </button>
                </td>
            `;
            tbody.appendChild(row);
        });
    });
}

// Charts (placeholder)
function initializeCharts() {
    // Initialize performance charts here
    console.log('Initializing charts...');
}

// Activity log
function addActivity(type, message) {
    const activity = {
        type: type,
        message: message,
        timestamp: new Date()
    };
    
    activityLog.unshift(activity);
    if (activityLog.length > 50) {
        activityLog = activityLog.slice(0, 50);
    }
    
    updateActivityLog();
}

function updateActivityLog() {
    const logContainer = document.getElementById('activity-log');
    logContainer.innerHTML = '';
    
    activityLog.slice(0, 10).forEach(activity => {
        const item = document.createElement('div');
        item.className = 'timeline-item';
        
        const iconClass = {
            'success': 'fas fa-check',
            'error': 'fas fa-exclamation-triangle',
            'warning': 'fas fa-exclamation-circle',
            'info': 'fas fa-info-circle'
        }[activity.type] || 'fas fa-info-circle';
        
        item.innerHTML = `
            <div class="timeline-icon ${activity.type}">
                <i class="${iconClass}"></i>
            </div>
            <div class="timeline-content">
                <h6>${activity.message}</h6>
                <p>${activity.timestamp.toLocaleTimeString()}</p>
            </div>
        `;
        
        logContainer.appendChild(item);
    });
}

// Utility functions
function refreshAll() {
    loadSystemStats();
    if (currentSection === 'containers') {
        loadContainers();
    } else if (currentSection === 'templates') {
        loadTemplates();
    } else if (currentSection === 'backups') {
        loadBackups();
    }
    addActivity('info', 'Dashboard refreshed');
}