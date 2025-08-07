#!/bin/bash
# Deploy and run audio fix on remote server

set -e

SERVER_IP="37.27.49.246"
SERVER_USER="deployer"
SERVER_PASS="zx93YJnt"
CONTAINER_NAME="webtop-kde"

echo "🚀 Deploying audio fix to server..."

# Copy the fix script to the server
echo "📤 Uploading fix script to server..."
sshpass -p "${SERVER_PASS}" scp -o StrictHostKeyChecking=no \
    "/Users/mohamedalmoelef/Documents/GitHub/webtop-omni-desktop/ubuntu-kde-docker/fix-novnc-audio.sh" \
    "${SERVER_USER}@${SERVER_IP}:/tmp/fix-novnc-audio.sh"

echo "🔧 Executing audio fix on server..."

# Execute the fix script inside the container
sshpass -p "${SERVER_PASS}" ssh -o StrictHostKeyChecking=no "${SERVER_USER}@${SERVER_IP}" << 'REMOTE_SCRIPT'
echo "🐳 Copying fix script into container..."
docker cp /tmp/fix-novnc-audio.sh webtop-kde:/tmp/fix-novnc-audio.sh

echo "🔧 Making script executable..."
docker exec webtop-kde chmod +x /tmp/fix-novnc-audio.sh

echo "🚀 Running audio fix inside container..."
docker exec webtop-kde /tmp/fix-novnc-audio.sh

echo "📊 Checking audio system status..."
docker exec webtop-kde bash -c '
    export XDG_RUNTIME_DIR=/run/user/1000
    echo "=== PulseAudio Status ==="
    su - devuser -c "export XDG_RUNTIME_DIR=/run/user/1000; pactl info | head -5"
    echo ""
    echo "=== Available Audio Devices ==="
    su - devuser -c "export XDG_RUNTIME_DIR=/run/user/1000; pactl list short sinks"
    echo ""
    echo "=== Audio Bridge Status ==="
    pgrep -f "webrtc-audio-server\|audio-bridge" || echo "No audio bridge process found"
    echo ""
    echo "=== Network Ports ==="
    netstat -tlnp | grep -E ":4713|:8080" || echo "Audio ports not listening"
'

echo ""
echo "✅ Audio fix deployment completed!"
echo ""
echo "🌐 Next steps:"
echo "1. Open your browser to: http://37.27.49.246:32768/vnc_audio.html"
echo "2. Click 'Connect Audio' in the noVNC interface"
echo "3. The 'Connection refused' error should now be resolved"
echo ""
echo "🧪 To test audio inside the desktop:"
echo "- Run the test script: ~/Desktop/Test Audio.sh"
echo "- Check KDE System Settings > Audio"
echo ""
REMOTE_SCRIPT

echo "🎉 Deployment completed successfully!"