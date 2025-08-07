import React from 'react'
import './App.css'

function App() {
  return (
    <div className="App">
      <header className="App-header">
        <h1>🎧 Ubuntu KDE WebTop - Audio Control</h1>
        <div className="status-container">
          <div className="status-card">
            <h2>📋 Container Information</h2>
            <p>This is a Docker-based Ubuntu KDE desktop environment with PipeWire audio support.</p>
            <p>The audio system runs inside the container and streams to your browser via WebRTC.</p>
          </div>
          
          <div className="status-card">
            <h2>🔊 Audio System Recovery</h2>
            <p>If experiencing audio issues, run the enhanced recovery script inside your container:</p>
            <code>docker exec &lt;container&gt; /usr/local/bin/enhanced-audio-recovery.sh</code>
          </div>
          
          <div className="status-card">
            <h2>🛠️ Quick Actions</h2>
            <p>• Access noVNC Desktop via your container's exposed port</p>
            <p>• Check container logs for PipeWire/WirePlumber status</p>
            <p>• Verify WebRTC bridge is running on port 8080</p>
          </div>
          
          <div className="status-card">
            <h2>📊 System Information</h2>
            <div className="system-info">
              <p><strong>Container Type:</strong> Ubuntu KDE WebTop</p>
              <p><strong>Audio System:</strong> PipeWire + WirePlumber</p>
              <p><strong>WebRTC Bridge:</strong> Port 8080 (HTTP) / 8081 (WebSocket)</p>
              <p><strong>VNC Access:</strong> Port varies (check container logs)</p>
            </div>
          </div>
        </div>
      </header>
    </div>
  )
}

export default App