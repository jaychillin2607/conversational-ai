#!/bin/bash

set -e

echo "🔄 Updating AI Voice Agent from GitHub..."

# Colors
GREEN='\033[0;32m'
NC='\033[0m'

# Get instance IP
INSTANCE_IP=$(terraform output -raw instance_public_ip)

echo "📥 Pulling latest code and updating application..."
ssh -i ~/.ssh/voice-agent-key -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP << 'ENDSSH'
    cd /opt/voice-agent
    
    # Stop services
    sudo systemctl stop voice-agent
    
    # Pull latest code
    sudo git pull origin main
    
    # Update backend dependencies
    source venv/bin/activate
    cd server
    pip install -r requirements.txt
    
    # Rebuild frontend
    cd /opt/voice-agent/frontend
    npm install
    npm run build
    
    # Set permissions
    sudo chown -R voice-agent:voice-agent /opt/voice-agent
    
    # Restart services
    sudo systemctl start voice-agent
    sudo systemctl restart nginx
    
    echo "✅ Application updated successfully!"
ENDSSH

echo -e "${GREEN}🎉 Update completed!${NC}"