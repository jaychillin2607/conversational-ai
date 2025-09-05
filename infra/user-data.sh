#!/bin/bash

set -e

# Logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting user-data script at $(date)"

# Update system first
echo "Updating system packages..."
yum update -y

# Install basic tools first
echo "Installing basic tools..."
yum install -y git htop curl wget

# Install Python 3 (use what's available in Amazon Linux 2)
echo "Installing Python..."
yum install -y python3 python3-pip

# Install Node.js using Amazon Linux Extras (more compatible)
echo "Installing Node.js..."
amazon-linux-extras install nodejs18 -y

# Verify Node.js installation
node --version
npm --version

# Install nginx
echo "Installing nginx..."
amazon-linux-extras install nginx1 -y

# Create application directory
echo "Setting up application directories..."
mkdir -p /opt/voice-agent
mkdir -p /var/log/voice-agent

# Create voice-agent user for running the service
useradd -r -s /bin/false voice-agent || echo "User already exists"
usermod -a -G voice-agent ec2-user

# Set permissions
chown -R voice-agent:voice-agent /opt/voice-agent
chown -R voice-agent:voice-agent /var/log/voice-agent

# Configure nginx
echo "Configuring nginx..."
cat > /etc/nginx/conf.d/voice-agent.conf << 'EOF'
server {
    listen 80;
    server_name _;
    
    # Frontend - serve React app
    location / {
        root /opt/voice-agent/frontend/dist;
        try_files $uri $uri/ /index.html;
        index index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # Backend API proxy
    location /api/ {
        proxy_pass http://127.0.0.1:8000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;
    }
    
    # WebSocket proxy for voice calls
    location /ws/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
    }
    
    # Health check and other backend routes
    location ~ ^/(health|initiate-call|webhook|call)/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Remove default nginx config
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
rm -f /etc/nginx/conf.d/default.conf 2>/dev/null || true

# Test nginx config
nginx -t

# Create systemd service for the voice agent backend
echo "Creating systemd service..."
cat > /etc/systemd/system/voice-agent.service << 'EOF'
[Unit]
Description=AI Voice Agent FastAPI Backend
After=network.target

[Service]
Type=simple
User=voice-agent
Group=voice-agent
WorkingDirectory=/opt/voice-agent/server
Environment=PATH=/opt/voice-agent/venv/bin
Environment=PYTHONPATH=/opt/voice-agent/server
Environment=AWS_DEFAULT_REGION=us-east-1
ExecStart=/opt/voice-agent/venv/bin/python -m uvicorn server:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10
StandardOutput=append:/var/log/voice-agent/backend.log
StandardError=append:/var/log/voice-agent/backend-error.log

[Install]
WantedBy=multi-user.target
EOF

# Enable services
systemctl enable nginx

echo "User-data script completed at $(date)"
echo "Instance is ready for application deployment"