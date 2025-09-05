#!/bin/bash

set -e

# Logging
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting user-data script at $(date)"

# Update system
echo "Updating system packages..."
yum update -y

# Install Docker
echo "Installing Docker..."
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
echo "Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

# Install nginx
echo "Installing nginx..."
amazon-linux-extras install nginx1 -y
systemctl enable nginx

# Install basic tools
echo "Installing tools..."
yum install -y git htop curl wget

# Create application directory
echo "Setting up directories..."
mkdir -p /opt/voice-agent
mkdir -p /var/log/voice-agent

# Create voice-agent user
useradd -r -s /bin/false voice-agent || echo "User already exists"
usermod -a -G docker voice-agent
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
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
    
    # Backend API - direct proxy
    location ~ ^/(health|initiate-call|webhook|call|ws)/ {
        proxy_pass http://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;
        proxy_send_timeout 86400;
    }
}

map $http_upgrade $connection_upgrade {
    default upgrade;
    '' close;
}
EOF

# Remove default nginx config
rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
rm -f /etc/nginx/conf.d/default.conf 2>/dev/null || true

# Test nginx config
nginx -t

# Create docker-compose.yml template
cat > /opt/voice-agent/docker-compose.yml << 'EOF'
version: '3.8'

services:
  backend:
    build: 
      context: ./server
      dockerfile: Dockerfile
    ports:
      - "8000:8000"
    environment:
      - AWS_DEFAULT_REGION=us-east-1
      - TWILIO_ACCOUNT_SID=${TWILIO_ACCOUNT_SID:-}
      - TWILIO_AUTH_TOKEN=${TWILIO_AUTH_TOKEN:-}
      - TWILIO_PHONE_NUMBER=${TWILIO_PHONE_NUMBER:-}
      - SERVER_URL=http://PUBLIC_IP_PLACEHOLDER
      - SERVER_HOST=PUBLIC_IP_PLACEHOLDER
    restart: unless-stopped
    volumes:
      - ./server:/app
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    ports:
      - "3000:80"
    environment:
      - VITE_API_URL=http://PUBLIC_IP_PLACEHOLDER:8000
    restart: unless-stopped
    depends_on:
      - backend
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
EOF

# Create systemd service for docker-compose
cat > /etc/systemd/system/voice-agent.service << 'EOF'
[Unit]
Description=AI Voice Agent Docker Compose
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
User=voice-agent
Group=voice-agent
WorkingDirectory=/opt/voice-agent
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
ExecReload=/usr/local/bin/docker-compose restart
TimeoutStartSec=300

[Install]
WantedBy=multi-user.target
EOF

# Create helper scripts
cat > /opt/voice-agent/start.sh << 'EOF'
#!/bin/bash
cd /opt/voice-agent
docker-compose up -d
systemctl start nginx
echo "✅ Voice agent started!"
EOF

cat > /opt/voice-agent/stop.sh << 'EOF'
#!/bin/bash
cd /opt/voice-agent
docker-compose down
echo "🛑 Voice agent stopped!"
EOF

cat > /opt/voice-agent/restart.sh << 'EOF'
#!/bin/bash
cd /opt/voice-agent
docker-compose restart
systemctl restart nginx
echo "🔄 Voice agent restarted!"
EOF

cat > /opt/voice-agent/logs.sh << 'EOF'
#!/bin/bash
cd /opt/voice-agent
echo "=== Backend Logs ==="
docker-compose logs -f backend
EOF

cat > /opt/voice-agent/status.sh << 'EOF'
#!/bin/bash
echo "=== Docker Containers ==="
cd /opt/voice-agent
docker-compose ps

echo ""
echo "=== Service Status ==="
systemctl status voice-agent --no-pager

echo ""
echo "=== Nginx Status ==="
systemctl status nginx --no-pager

echo ""
echo "=== Port Status ==="
netstat -tlnp | grep -E ':80|:3000|:8000'
EOF

# Make scripts executable
chmod +x /opt/voice-agent/*.sh

# Set permissions
chown -R voice-agent:voice-agent /opt/voice-agent

# Create .env template
cat > /opt/voice-agent/.env << 'EOF'
# Twilio Configuration
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_PHONE_NUMBER=

# AWS Configuration  
AWS_DEFAULT_REGION=us-east-1

# Server Configuration (will be set automatically)
SERVER_URL=
SERVER_HOST=
VITE_API_URL=
EOF

echo "User-data script completed at $(date)"
echo "Instance is ready for application deployment"
echo "Docker version: $(docker --version)"
echo "Docker Compose version: $(docker-compose --version)"