#!/bin/bash

set -e

echo "🚀 Starting AI Voice Agent deployment with Docker..."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get GitHub repository URL
echo "📝 Please enter your GitHub repository URL:"
read -p "Repository URL: " GITHUB_REPO

if [ -z "$GITHUB_REPO" ]; then
    echo -e "${RED}❌ Repository URL is required!${NC}"
    exit 1
fi

echo "📝 Enter branch name (default: main):"
read -p "Branch: " GITHUB_BRANCH
GITHUB_BRANCH=${GITHUB_BRANCH:-main}

if [ ! -f "terraform.tfvars" ]; then
    echo -e "${RED}❌ terraform.tfvars not found!${NC}"
    exit 1
fi

echo "📋 Initializing Terraform..."
terraform init

echo "🔍 Planning infrastructure..."
terraform plan

echo "🏗️  Creating infrastructure..."
terraform apply -auto-approve

INSTANCE_IP=$(terraform output -raw instance_public_ip)
echo -e "${GREEN}✅ Infrastructure created! Instance IP: ${INSTANCE_IP}${NC}"

echo "⏳ Waiting for instance to be ready..."
sleep 90

# Wait for SSH
echo "🔌 Waiting for SSH connection..."
for i in {1..30}; do
    if nc -z $INSTANCE_IP 22; then
        echo "SSH is ready!"
        break
    fi
    echo "Attempt $i/30: Still waiting for SSH..."
    sleep 10
done

# Check user-data completion
echo "🔍 Waiting for initialization..."
ssh -i ~/.ssh/voice-agent-key -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP << 'ENDSSH'
    for i in {1..20}; do
        if [ -f /var/log/user-data.log ] && grep -q "User-data script completed" /var/log/user-data.log; then
            echo "✅ User-data completed!"
            break
        elif [ -f /var/log/user-data.log ] && grep -q -E "error|Error|failed|Failed" /var/log/user-data.log; then
            echo "❌ User-data failed!"
            tail -20 /var/log/user-data.log
            exit 1
        else
            echo "⏳ Waiting... ($i/20)"
            sleep 30
        fi
    done
ENDSSH

echo "📥 Deploying application with Docker..."
ssh -i ~/.ssh/voice-agent-key -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP << ENDSSH
    # Clone repository
    cd /opt/voice-agent
    sudo git clone -b $GITHUB_BRANCH $GITHUB_REPO .
    
    # Get public IP
    PUBLIC_IP=\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
    
    # Update docker-compose.yml with real IP
    sudo sed -i "s/PUBLIC_IP_PLACEHOLDER/\$PUBLIC_IP/g" docker-compose.yml
    
    # Create .env file
    cat > .env << EOF
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_PHONE_NUMBER=
AWS_DEFAULT_REGION=us-east-1
SERVER_URL=http://\$PUBLIC_IP
SERVER_HOST=\$PUBLIC_IP
VITE_API_URL=http://\$PUBLIC_IP:8000
EOF
    
    # Set permissions
    sudo chown -R voice-agent:voice-agent /opt/voice-agent
    
    # Build and start containers
    echo "🐳 Building Docker containers..."
    sudo -u voice-agent docker-compose build
    
    echo "🚀 Starting services..."
    sudo systemctl daemon-reload
    sudo systemctl enable voice-agent
    sudo systemctl start voice-agent
    sudo systemctl start nginx
    
    # Wait a moment and check status
    sleep 10
    /opt/voice-agent/status.sh
ENDSSH

echo -e "${GREEN}🎉 Deployment completed!${NC}"
echo ""
echo "📱 Your application:"
echo "   Frontend: http://$INSTANCE_IP"
echo "   Backend:  http://$INSTANCE_IP:8000"
echo "   Health:   http://$INSTANCE_IP:8000/health"
echo ""
echo "📝 Next: Add your Twilio credentials:"
echo "   ssh -i ~/.ssh/voice-agent-key ec2-user@$INSTANCE_IP"
echo "   sudo nano /opt/voice-agent/.env"
echo "   cd /opt/voice-agent && sudo -u voice-agent docker-compose restart"
echo ""
echo "🔍 Monitor:"
echo "   ssh -i ~/.ssh/voice-agent-key ec2-user@$INSTANCE_IP"
echo "   /opt/voice-agent/status.sh"
echo "   /opt/voice-agent/logs.sh"