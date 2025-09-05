#!/bin/bash

set -e

echo "🚀 Starting AI Voice Agent deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get GitHub repository URL
echo "📝 Please enter your GitHub repository URL:"
read -p "Repository URL: " GITHUB_REPO

if [ -z "$GITHUB_REPO" ]; then
    echo -e "${RED}❌ Repository URL is required!${NC}"
    exit 1
fi

# Get branch name
echo "📝 Enter branch name (default: main):"
read -p "Branch: " GITHUB_BRANCH
GITHUB_BRANCH=${GITHUB_BRANCH:-main}

# Check terraform.tfvars
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

# Get instance IP
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

# Check if user-data completed or failed
echo "🔍 Checking instance initialization status..."
ssh -i ~/.ssh/voice-agent-key -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP << 'ENDSSH'
    echo "Checking user-data status..."
    
    # Check if user-data log exists
    if [ ! -f /var/log/user-data.log ]; then
        echo "❌ User-data log not found. Instance may not be ready."
        exit 1
    fi
    
    # Check for completion
    if grep -q "User-data script completed" /var/log/user-data.log; then
        echo "✅ User-data script completed successfully!"
    elif grep -q "error\|Error\|ERROR\|failed\|Failed\|FAILED" /var/log/user-data.log; then
        echo "❌ User-data script encountered errors:"
        tail -20 /var/log/user-data.log
        exit 1
    else
        echo "⏳ User-data script is still running..."
        echo "Last 10 lines of user-data log:"
        tail -10 /var/log/user-data.log
        
        # Wait a bit more
        echo "Waiting 60 more seconds..."
        sleep 60
        
        # Check again
        if grep -q "User-data script completed" /var/log/user-data.log; then
            echo "✅ User-data script completed!"
        else
            echo "❌ User-data script taking too long. Please check manually."
            echo "SSH: ssh -i ~/.ssh/voice-agent-key ec2-user@$INSTANCE_IP"
            echo "Logs: sudo tail -f /var/log/user-data.log"
            exit 1
        fi
    fi
ENDSSH

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Instance initialization failed. Please check manually:${NC}"
    echo "SSH: ssh -i ~/.ssh/voice-agent-key ec2-user@$INSTANCE_IP"
    echo "Logs: sudo tail -f /var/log/user-data.log"
    exit 1
fi

echo "📥 Setting up application..."
ssh -i ~/.ssh/voice-agent-key -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP << ENDSSH
    # Clone repository
    cd /opt/voice-agent
    sudo git clone -b $GITHUB_BRANCH $GITHUB_REPO .
    sudo chown -R voice-agent:voice-agent /opt/voice-agent
    
    # Get public IP
    PUBLIC_IP=\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
    
    # Setup Python backend
    echo "🐍 Setting up Python backend..."
    python3 -m venv venv
    source venv/bin/activate
    cd server
    pip install --upgrade pip
    pip install -r requirements.txt
    
    # Create backend .env
    cat > .env << EOF
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_PHONE_NUMBER=
AWS_DEFAULT_REGION=us-east-1
SERVER_URL=http://\$PUBLIC_IP
SERVER_HOST=\$PUBLIC_IP
EOF
    
    # Setup frontend
    echo "⚛️ Building React frontend..."
    cd /opt/voice-agent/frontend
    echo "VITE_API_URL=http://\$PUBLIC_IP:8000" > .env
    npm install
    npm run build
    
    # Set permissions
    sudo chown -R voice-agent:voice-agent /opt/voice-agent
    
    # Start services
    sudo systemctl daemon-reload
    sudo systemctl enable voice-agent
    sudo systemctl start voice-agent
    sudo systemctl start nginx
    
    echo "✅ Application setup completed!"
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
echo "   sudo nano /opt/voice-agent/server/.env"
echo "   sudo systemctl restart voice-agent"