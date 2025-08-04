# Multi-Container Deployment Guide

This guide covers how to deploy and manage multiple Ubuntu KDE containers for different clients, teams, or environments using the enhanced webtop.sh script.

## Overview

The multi-container feature allows you to:
- Run multiple isolated environments with unique names
- Assign custom port mappings to avoid conflicts  
- Enable HTTP authentication per container
- Manage containers independently
- Track all containers in a central registry

## Quick Start

### 1. Basic Multi-Container Setup

```bash
# Start first container for Client A
./webtop.sh up --name=client-a --ports=32769:80,2223:22,7682:7681

# Start second container for Team B
./webtop.sh up --name=team-b --ports=32770:80,2224:22,7683:7681

# List all managed containers
./webtop.sh list
```

### 2. Container with Authentication

```bash
# Start secure container with HTTP authentication
./webtop.sh up --name=secure-client --ports=32771:80,2225:22,7684:7681 --auth

# Add custom VNC users
./webtop.sh add-user client1:SecurePass123
./webtop.sh add-user manager:ManagerPass456
```

### 3. Development vs Production

```bash
# Development container
./webtop.sh up --name=dev-team --config=dev --ports=32772:80,2226:22

# Production container with auth
./webtop.sh up --name=prod-client --config=prod --ports=32773:80,2227:22 --auth
```

## Container Naming Conventions

### Recommended Patterns

```bash
# Client-based naming
./webtop.sh up --name=client-acme
./webtop.sh up --name=client-techcorp
./webtop.sh up --name=client-startup

# Team-based naming  
./webtop.sh up --name=team-design
./webtop.sh up --name=team-dev
./webtop.sh up --name=team-marketing

# Project-based naming
./webtop.sh up --name=project-website
./webtop.sh up --name=project-mobile
./webtop.sh up --name=project-campaign

# Environment-based naming
./webtop.sh up --name=dev-environment
./webtop.sh up --name=staging-environment  
./webtop.sh up --name=prod-environment
```

## Port Management

### Default Port Ranges

| Service | Default | Range Start | Example Mapping |
|---------|---------|-------------|-----------------|
| noVNC   | 32768   | 32769       | 32769:80        |
| SSH     | 2222    | 2223        | 2223:22         |
| ttyd    | 7681    | 7682        | 7682:7681       |
| Audio   | 4713    | 4714        | 4714:4713       |

### Automatic Port Assignment

```bash
# Let the system assign the next available ports
./webtop.sh up --name=auto-client --auto-ports

# Or manually specify to avoid conflicts
./webtop.sh up --name=manual-client --ports=33000:80,2230:22,7690:7681
```

### Port Conflict Prevention

```bash
# Check what ports are in use
./webtop.sh list
docker ps --format "table {{.Names}}\t{{.Ports}}"

# Find next available port range
netstat -ln | grep :32768  # Check if port is in use
```

## Container Management

### Listing and Status

```bash
# List all managed containers
./webtop.sh list

# Show detailed status
./webtop.sh status

# Monitor resources for all containers
./webtop.sh monitor
```

### Switching Between Containers

```bash
# Switch context to specific container
./webtop.sh switch client-a

# Now commands will target the switched container
./webtop.sh logs --follow
./webtop.sh shell
./webtop.sh health
```

### Container Operations

```bash
# Stop specific container
./webtop.sh down --name=client-a

# Remove container completely
./webtop.sh remove client-a

# Restart container
./webtop.sh down --name=client-b
./webtop.sh up --name=client-b --ports=32770:80,2224:22
```

## Authentication Management

### Per-Container Authentication

```bash
# Enable auth during container creation
./webtop.sh up --name=secure-container --auth --ports=32774:80,2228:22

# Add users to authentication
./webtop.sh add-user client:password123
./webtop.sh add-user admin:securepass456

# List authenticated users
./webtop.sh list-users

# Remove user
./webtop.sh remove-user client
```

### Environment-Based Authentication

```bash
# Configure users in .env file
VNC_AUTH_ENABLED=true
VNC_AUTH_REALM="Client Portal"
VNC_USERS="client1:pass1,client2:pass2,admin:adminpass"

# Generate authentication from environment
./auth-setup.sh generate .env
```

## Advanced Configurations

### Container Profiles

Create reusable container configurations:

```bash
# Create profile directory
mkdir -p profiles

# Client profile
cat > profiles/client.env << EOF
VNC_AUTH_ENABLED=true
VNC_AUTH_REALM="Client Access Portal"
VNC_USERS="client:ClientPass123,support:SupportPass456"
MAX_MEMORY=4G
MAX_CPU=2
EOF

# Use profile
./webtop.sh up --name=client-xyz --profile=client --ports=32775:80,2229:22
```

### Custom Resource Limits

```bash
# Start container with specific resource limits
docker run -d \
  --name webtop-heavy-client \
  --memory=8g \
  --cpus=4 \
  -p 32776:80 \
  -p 2230:22 \
  webtop-kde-marketing
```

### SSL/TLS per Container

```bash
# Generate SSL certificate for container
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/client-a.key \
  -out ssl/client-a.crt \
  -subj "/CN=client-a.yourdomain.com"

# Configure nginx with custom SSL
# (See AUTHENTICATION.md for detailed SSL setup)
```

## Backup and Migration

### Container Configuration Backup

```bash
# Export container registry
cp .container-registry.json backups/registry-$(date +%Y%m%d).json

# Backup authentication files
tar -czf backups/auth-$(date +%Y%m%d).tar.gz auth/

# Backup container volumes
docker run --rm -v /data/ubuntu-kde-docker_webtop/config:/source -v $(pwd)/backups:/backup \
  alpine tar -czf /backup/volumes-$(date +%Y%m%d).tar.gz -C /source .
```

### Container Migration

```bash
# Export container
docker export client-a > backups/client-a-$(date +%Y%m%d).tar

# Import on new system
docker import backups/client-a-20241231.tar webtop-client-a:migrated
```

## Monitoring and Logging

### Multi-Container Monitoring

```bash
# Monitor all containers
./webtop.sh monitor

# Individual container stats
docker stats client-a team-b secure-client

# Container logs
./webtop.sh logs --name=client-a --follow
docker logs -f client-a
```

### Centralized Logging

```bash
# Collect logs from all containers
for container in $(./webtop.sh list --names-only); do
  docker logs $container > logs/${container}-$(date +%Y%m%d).log 2>&1
done
```

## Troubleshooting

### Common Issues

1. **Port Conflicts**
   ```bash
   # Error: Port already in use
   ./webtop.sh list  # Check existing port assignments
   netstat -ln | grep :32768  # Find conflicting process
   ```

2. **Container Name Conflicts**
   ```bash
   # Error: Container name already exists
   ./webtop.sh list  # Check existing containers
   ./webtop.sh remove old-container  # Remove if needed
   ```

3. **Authentication Issues**
   ```bash
   # Check auth file
   cat auth/.htpasswd
   
   # Regenerate authentication
   ./auth-setup.sh generate .env
   ```

4. **Resource Limits**
   ```bash
   # Check container resource usage
   docker stats
   
   # Adjust limits
   docker update --memory=8g --cpus=4 container-name
   ```

### Best Practices

1. **Use descriptive container names** that reflect their purpose
2. **Document port assignments** to avoid conflicts
3. **Enable authentication** for production containers
4. **Monitor resource usage** regularly
5. **Backup configurations** before major changes
6. **Use environment-specific configs** (.env, .env.production)
7. **Test port accessibility** before client handover

### Production Deployment

For production deployments with multiple clients:

1. **Use reverse proxy** (nginx) for SSL termination
2. **Configure proper DNS** for each client domain
3. **Enable authentication** for all containers
4. **Set up monitoring** and alerting
5. **Implement backup strategy** for data and configurations
6. **Use resource limits** to prevent resource exhaustion
7. **Document access credentials** securely

## Example: Complete Client Setup

```bash
#!/bin/bash
# Complete client onboarding script

CLIENT_NAME="acme-corp"
PORTS="33000:80,2250:22,7700:7681"
AUTH_USERS="acme-admin:SecureAdmin123,acme-user:SecureUser456"

# 1. Start container with authentication
./webtop.sh up --name=$CLIENT_NAME --ports=$PORTS --auth --config=prod

# 2. Configure authentication
echo "Setting up authentication for $CLIENT_NAME..."
IFS=',' read -ra USERS <<< "$AUTH_USERS"
for user_pass in "${USERS[@]}"; do
    ./webtop.sh add-user "$user_pass"
done

# 3. Setup development environment
./webtop.sh switch $CLIENT_NAME
./webtop.sh dev-setup

# 4. Show access information
echo "=== CLIENT SETUP COMPLETE ==="
echo "Client: $CLIENT_NAME"
echo "VNC Access: https://yourdomain.com:33000"
echo "SSH Access: ssh -p 2250 devuser@yourdomain.com"
echo "Users: ${AUTH_USERS//,/ }"
echo "=========================="
```

This provides a comprehensive foundation for managing multiple marketing agency environments with proper isolation, security, and scalability.
