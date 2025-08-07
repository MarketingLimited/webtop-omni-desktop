const http = require('http');
const express = require('express');
const WebSocket = require('ws');
const { spawn } = require('child_process');
const path = require('path');
const {
  RTCPeerConnection,
  nonstandard: { RTCAudioSource }
} = require('wrtc');

const PORT = process.env.WEBRTC_PORT || 8080;
const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

function buildIceServers() {
  const servers = [];
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

app.post('/offer', async (req, res) => {
  try {
    const pc = new RTCPeerConnection({ iceServers: buildIceServers() });
    const source = new RTCAudioSource();
    const track = source.createTrack();
    pc.addTrack(track);

    const silenceInterval = setInterval(() => {
      const silence = Buffer.alloc((48000 / 50) * 2);
      source.onData({
        samples: silence,
        sampleRate: 48000,
        channelCount: 1,
        bitsPerSample: 16
      });
    }, 20);

    await pc.setRemoteDescription(req.body);
    const answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    res.json(pc.localDescription);

    pc.onconnectionstatechange = () => {
      if (['closed', 'failed', 'disconnected'].includes(pc.connectionState)) {
        clearInterval(silenceInterval);
        pc.close();
        track.stop();
      }
    };
  } catch (err) {
    console.error('WebRTC error:', err);
    res.status(500).send(err.toString());
  }
});

const server = http.createServer(app);

const wss = new WebSocket.Server({ server });
wss.on('connection', (ws) => {
  const recorder = spawn('parecord', [
    '--format=s16le',
    '--rate=48000',
    '--channels=2',
    '--raw'
  ]);
  recorder.stdout.on('data', (data) => ws.send(data));
  ws.on('close', () => recorder.kill());
});

server.listen(PORT, () => {
  console.log(`WebRTC audio server listening on ${PORT}`);
});
