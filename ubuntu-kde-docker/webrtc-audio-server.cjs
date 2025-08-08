const http = require('http');
const express = require('express');
const WebSocket = require('ws');
const { spawn } = require('child_process');
const path = require('path');

// Try to load wrtc, fallback gracefully if not available
let wrtc, RTCPeerConnection, RTCAudioSource;
try {
  wrtc = require('wrtc');
  RTCPeerConnection = wrtc.RTCPeerConnection;
  RTCAudioSource = wrtc.nonstandard.RTCAudioSource;
} catch (err) {
  console.warn('wrtc not available, WebRTC disabled:', err.message);
}

const PORT = process.env.WEBRTC_PORT || process.env.AUDIO_PORT || 8080;
const app = express();

// Enable CORS for all routes
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Authorization');
  if (req.method === 'OPTIONS') {
    res.sendStatus(200);
  } else {
    next();
  }
});

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    webrtc: !!RTCPeerConnection,
    websocket: true,
    timestamp: new Date().toISOString()
  });
});

// Build ICE servers configuration
function buildIceServers() {
  const servers = [];
  
  // Add default STUN servers
  servers.push({ urls: 'stun:stun.l.google.com:19302' });
  servers.push({ urls: 'stun:stun1.l.google.com:19302' });
  
  // Add custom servers if configured
  if (process.env.WEBRTC_STUN_SERVER) {
    servers.push({ urls: process.env.WEBRTC_STUN_SERVER });
  }
  if (process.env.WEBRTC_TURN_SERVER) {
    servers.push({
      urls: process.env.WEBRTC_TURN_SERVER,
      username: process.env.WEBRTC_TURN_USERNAME,
      credential: process.env.WEBRTC_TURN_PASSWORD
    });
  }
  return servers;
}

// WebRTC offer endpoint
app.post('/offer', async (req, res) => {
  if (!RTCPeerConnection || !RTCAudioSource) {
    return res.status(503).json({ error: 'WebRTC not available, use WebSocket fallback' });
  }

  try {
    const pc = new RTCPeerConnection({ iceServers: buildIceServers() });
    const source = new RTCAudioSource();
    const track = source.createTrack();
    const stream = new wrtc.MediaStream();
    pc.addTrack(track, stream);

    // Create audio capture process
    const audioProcess = spawn('parecord', [
      '--device=virtual_speaker.monitor',
      '--format=s16le',
      '--rate=48000',
      '--channels=1',
      '--raw'
    ]);

    // Process audio data and send to WebRTC
    audioProcess.stdout.on('data', (data) => {
      try {
        if (pc.connectionState === 'connected') {
          source.onData({
            samples: data,
            sampleRate: 48000,
            channelCount: 1,
            bitsPerSample: 16
          });
        }
      } catch (err) {
        console.warn('Audio processing error:', err.message);
      }
    });

    audioProcess.on('error', (err) => {
      console.error('Audio capture error:', err.message);
    });

    await pc.setRemoteDescription(req.body);
    const answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    res.json(pc.localDescription);

    pc.onconnectionstatechange = () => {
      console.log('WebRTC connection state:', pc.connectionState);
      if (['closed', 'failed', 'disconnected'].includes(pc.connectionState)) {
        audioProcess.kill();
        pc.close();
        track.stop();
      }
    };

    // Cleanup after 5 minutes of inactivity
    setTimeout(() => {
      if (pc.connectionState !== 'closed') {
        audioProcess.kill();
        pc.close();
        track.stop();
      }
    }, 300000);

  } catch (err) {
    console.error('WebRTC error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Create HTTP server
const server = http.createServer(app);

// WebSocket server for fallback audio streaming
const wss = new WebSocket.Server({ 
  server,
  path: '/audio-stream'
});

wss.on('connection', (ws, req) => {
  console.log('WebSocket audio connection established');
  
  // Create audio capture process for WebSocket
  const recorder = spawn('parecord', [
    '--device=virtual_speaker.monitor',
    '--format=s16le',
    '--rate=44100',
    '--channels=2',
    '--raw'
  ]);

  let isConnected = true;

  recorder.stdout.on('data', (data) => {
    if (isConnected && ws.readyState === WebSocket.OPEN) {
      try {
        ws.send(data);
      } catch (err) {
        console.warn('WebSocket send error:', err.message);
      }
    }
  });

  recorder.on('error', (err) => {
    console.error('Audio recorder error:', err.message);
  });

  ws.on('close', () => {
    console.log('WebSocket audio connection closed');
    isConnected = false;
    recorder.kill();
  });

  ws.on('error', (err) => {
    console.error('WebSocket error:', err.message);
    isConnected = false;
    recorder.kill();
  });

  // Send initial connection confirmation
  ws.send(JSON.stringify({ type: 'connected', timestamp: Date.now() }));
});

// Start server
server.listen(PORT, '0.0.0.0', () => {
  console.log(`Audio bridge server listening on port ${PORT}`);
  console.log(`WebRTC endpoint: http://localhost:${PORT}/offer`);
  console.log(`WebSocket endpoint: ws://localhost:${PORT}/audio-stream`);
  console.log(`Health check: http://localhost:${PORT}/health`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('Shutting down audio bridge server...');
  server.close(() => {
    process.exit(0);
  });
});
