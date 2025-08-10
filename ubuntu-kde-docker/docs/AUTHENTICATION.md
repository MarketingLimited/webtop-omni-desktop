# Authentication & Security Guide

This guide covers the HTTP Basic Authentication system for VNC access, user management, and security best practices for the Ubuntu KDE Marketing Agency environment.

## Overview

The authentication system provides:
- HTTP Basic Authentication for VNC interfaces
- User management via command line tools
- Environment-based configuration
- SSL/TLS support for secure connections
- Role-based access control options

## Quick Setup

### 1. Enable Authentication

```bash
# Enable auth during container startup
./webtop.sh up --name=secure-container --auth

# Or enable manually
./auth-setup.sh generate .env
```

### 2. Add Users

```bash
# Add users via command line
./webtop.sh add-user admin:SecurePassword123
./webtop.sh add-user client:ClientPass456

# Or add via auth-setup script
./auth-setup.sh add admin:SecurePassword123
./auth-setup.sh add client ClientPass456
```

### 3. Test Authentication

```bash
# Check users
./webtop.sh list-users

# Test access
curl -u admin:SecurePassword123 http://localhost:32768/
```

## Authentication Configuration

### Environment Variables

Add to your `.env` file:

```bash
# HTTP Authentication for VNC
VNC_AUTH_ENABLED=true
VNC_AUTH_REALM="Marketing Agency VNC Access"
VNC_USERS="admin:SecureAdmin123,client1:ClientPass456,viewer:ViewPass789"
```

For production (`.env.production`):

```bash
# HTTP Authentication for VNC (Production)
VNC_AUTH_ENABLED=true
VNC_AUTH_REALM="Secure Marketing VNC Access"
VNC_USERS="admin:ComplexAdminP@ss2024!,client:SecureClient2024!"
```

### Manual Authentication File

Create authentication file directly:

```bash
# Initialize auth directory
mkdir -p auth

# Create .htpasswd file with users
htpasswd -bc auth/.htpasswd admin SecurePassword123
htpasswd -b auth/.htpasswd client ClientPassword456
htpasswd -b auth/.htpasswd viewer ViewerPassword789
```

## User Management

### Adding Users

```bash
# Method 1: Via webtop.sh
./webtop.sh add-user username:password

# Method 2: Via auth-setup.sh  
./auth-setup.sh add username:password
./auth-setup.sh add username password

# Method 3: Direct htpasswd
htpasswd -b auth/.htpasswd username password
```

### Removing Users

```bash
# Method 1: Via webtop.sh
./webtop.sh remove-user username

# Method 2: Via auth-setup.sh
./auth-setup.sh remove username

# Method 3: Direct editing
sed -i '/^username:/d' auth/.htpasswd
```

### Listing Users

```bash
# Method 1: Via webtop.sh
./webtop.sh list-users

# Method 2: Via auth-setup.sh
./auth-setup.sh list

# Method 3: Direct file viewing
cut -d: -f1 auth/.htpasswd
```

### Updating Passwords

```bash
# Update existing user password
./webtop.sh add-user username:newpassword

# Or via auth-setup
./auth-setup.sh add username:newpassword
```

## nginx Authentication Configuration

The nginx configuration automatically enables authentication when the `.htpasswd` file exists:

```nginx
# Main location for noVNC with optional authentication
location / {
    # Enable HTTP Basic Authentication if auth file exists
    auth_basic "VNC Access";
    auth_basic_user_file /etc/nginx/auth/.htpasswd;
    
    # ... proxy configuration
}

# WebSocket endpoint with authentication
location /websockify {
    # Enable HTTP Basic Authentication if auth file exists
    auth_basic "VNC Access";
    auth_basic_user_file /etc/nginx/auth/.htpasswd;
    
    # ... websocket configuration
}
```

### Localhost Bypass (Development)

For development, localhost access can bypass authentication:

```nginx
# Bypass authentication for localhost (development)
location ~* ^/(vnc_lite\.html|vnc\.html)$ {
    satisfy any;
    allow 127.0.0.1;
    allow ::1;
    auth_basic "VNC Access";
    auth_basic_user_file /etc/nginx/auth/.htpasswd;
    
    # ... proxy configuration
}
```

## SSL/TLS Configuration

### Generate SSL Certificates

```bash
# Create SSL directory
mkdir -p ssl

# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/marketing.key \
  -out ssl/marketing.crt \
  -subj "/CN=marketing.yourdomain.com/O=Marketing Agency/C=US"

# Or generate for specific client
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/client-acme.key \
  -out ssl/client-acme.crt \
  -subj "/CN=acme.yourdomain.com/O=ACME Corp/C=US"
```

### Configure SSL in nginx

Update `nginx.conf` for SSL:

```nginx
server {
    listen 443 ssl http2;
    server_name marketing.yourdomain.com;

    # SSL configuration
    ssl_certificate /etc/nginx/ssl/marketing.crt;
    ssl_certificate_key /etc/nginx/ssl/marketing.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-Content-Type-Options nosniff;

    # Authentication and proxy configuration
    location / {
        auth_basic "Secure VNC Access";
        auth_basic_user_file /etc/nginx/auth/.htpasswd;
        
        proxy_pass http://webtop;
        # ... additional proxy settings
    }
}
```

### Let's Encrypt SSL (Production)

For production deployments with valid domain names:

```bash
# Install certbot
sudo apt update
sudo apt install certbot python3-certbot-nginx

# Generate certificate
sudo certbot --nginx -d marketing.yourdomain.com

# Test automatic renewal
sudo certbot renew --dry-run
```

## Advanced Authentication

### Role-Based Access Control

Create different authentication realms for different access levels:

```nginx
# Admin access (full control)
location /admin {
    auth_basic "Admin Access";
    auth_basic_user_file /etc/nginx/auth/.htpasswd-admin;
    # ... proxy configuration
}

# Client access (restricted)
location /client {
    auth_basic "Client Access";
    auth_basic_user_file /etc/nginx/auth/.htpasswd-client;
    # ... proxy configuration
}

# Viewer access (read-only)
location /viewer {
    auth_basic "Viewer Access";
    auth_basic_user_file /etc/nginx/auth/.htpasswd-viewer;
    # ... proxy configuration
}
```

### Multiple Authentication Files

```bash
# Create role-specific auth files
htpasswd -bc auth/.htpasswd-admin admin SuperSecureAdmin123
htpasswd -bc auth/.htpasswd-client client1 ClientPass456
htpasswd -b auth/.htpasswd-client client2 ClientPass789
htpasswd -bc auth/.htpasswd-viewer viewer1 ViewPass123
htpasswd -b auth/.htpasswd-viewer viewer2 ViewPass456
```

### JWT Authentication (Advanced)

For more sophisticated authentication, consider implementing JWT:

```nginx
# Requires nginx-jwt module or lua-resty-jwt
location / {
    access_by_lua_block {
        local jwt = require "resty.jwt"
        
        # JWT validation logic
        local jwt_token = ngx.var.cookie_auth_token
        if not jwt_token then
            ngx.status = 401
            ngx.say("Unauthorized")
            ngx.exit(401)
        end
        
        # Verify JWT token
        local jwt_obj = jwt:verify("your-secret-key", jwt_token)
        if not jwt_obj.valid then
            ngx.status = 401
            ngx.say("Invalid token")
            ngx.exit(401)
        end
    }
    
    proxy_pass http://webtop;
}
```

## Security Best Practices

### Password Security

1. **Use strong passwords** (minimum 12 characters, mixed case, numbers, symbols)
2. **Rotate passwords regularly** (every 90 days for production)
3. **Don't reuse passwords** across different environments
4. **Store passwords securely** (use password managers)

```bash
# Generate secure passwords
openssl rand -base64 32

# Or use pwgen if available
pwgen -s 16 1
```

### Environment Security

```bash
# Development environment (.env)
VNC_AUTH_ENABLED=false  # Disabled for ease of development
VNC_AUTH_REALM="Development Environment"

# Production environment (.env.production)
VNC_AUTH_ENABLED=true   # Always enabled
VNC_AUTH_REALM="Production VNC Access"
VNC_USERS="admin:$(openssl rand -base64 32),client:$(openssl rand -base64 24)"
```

### Container Security

```bash
# Start container with security options
docker run -d \
  --name secure-webtop \
  --security-opt no-new-privileges \
  --cap-drop ALL \
  --cap-add SYS_ADMIN \
  --read-only \
  --tmpfs /tmp \
  --tmpfs /run \
  webtop-kde-marketing
```

### Network Security

```bash
# Restrict network access
docker run -d \
  --name isolated-webtop \
  --network none \
  -p 127.0.0.1:32768:80 \
  webtop-kde-marketing

# Or use custom network with restrictions
docker network create --driver bridge marketing-secure
docker run -d \
  --name secure-webtop \
  --network marketing-secure \
  webtop-kde-marketing
```

## Troubleshooting Authentication

### Common Issues

1. **Authentication not working**
   ```bash
   # Check if auth file exists
   ls -la auth/.htpasswd
   
   # Verify nginx can read the file
   docker exec container-name cat /etc/nginx/auth/.htpasswd
   
   # Check nginx error logs
   docker exec container-name tail -f /var/log/nginx/error.log
   ```

2. **Users can't login**
   ```bash
   # Test password manually
   echo -n "password" | openssl passwd -apr1 -stdin
   
   # Compare with stored hash
   grep username auth/.htpasswd
   ```

3. **SSL certificate issues**
   ```bash
   # Check certificate validity
   openssl x509 -in ssl/marketing.crt -text -noout
   
   # Test SSL connection
   openssl s_client -connect localhost:443 -servername marketing.yourdomain.com
   ```

4. **Permission issues**
   ```bash
   # Fix auth file permissions
   chmod 644 auth/.htpasswd
   
   # Fix SSL certificate permissions
   chmod 644 ssl/marketing.crt
   chmod 600 ssl/marketing.key
   ```

### Debug Commands

```bash
# Enable nginx debug logging
docker exec container-name nginx -s reload

# Test authentication with curl
curl -v -u username:password http://localhost:32768/

# Check if auth is properly configured
docker exec container-name nginx -t

# Monitor nginx access logs
docker exec container-name tail -f /var/log/nginx/access.log
```

### Reset Authentication

```bash
# Remove all authentication
rm -f auth/.htpasswd

# Restart nginx to disable auth
docker exec container-name nginx -s reload

# Or recreate authentication
./auth-setup.sh generate .env
```

## Production Deployment Checklist

- [ ] SSL/TLS certificates configured
- [ ] Strong passwords for all users
- [ ] Authentication enabled for all VNC endpoints
- [ ] Security headers configured in nginx
- [ ] Firewall rules configured (only necessary ports open)
- [ ] Regular password rotation scheduled
- [ ] Backup strategy for authentication files
- [ ] Monitoring and logging configured
- [ ] Emergency access procedures documented
- [ ] User access regularly audited

## Integration Examples

### Client Onboarding Script

```bash
#!/bin/bash
# Client onboarding with authentication

CLIENT_NAME="$1"
CLIENT_DOMAIN="$2"
ADMIN_PASS="$(openssl rand -base64 16)"
CLIENT_PASS="$(openssl rand -base64 12)"

# Generate SSL certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout ssl/${CLIENT_NAME}.key \
  -out ssl/${CLIENT_NAME}.crt \
  -subj "/CN=${CLIENT_DOMAIN}/O=${CLIENT_NAME}/C=US"

# Create authentication
./auth-setup.sh add admin:${ADMIN_PASS}
./auth-setup.sh add ${CLIENT_NAME}:${CLIENT_PASS}

# Start container
./webtop.sh up --name=${CLIENT_NAME} --auth --ports=auto

echo "Client ${CLIENT_NAME} setup complete"
echo "Admin: admin / ${ADMIN_PASS}"
echo "Client: ${CLIENT_NAME} / ${CLIENT_PASS}"
echo "Domain: https://${CLIENT_DOMAIN}"
```

This authentication system provides enterprise-grade security for marketing agency deployments while maintaining ease of use and management.
## Related Documentation

- [Audio Diagnostics](AUDIO_DIAGNOSTICS.md)

