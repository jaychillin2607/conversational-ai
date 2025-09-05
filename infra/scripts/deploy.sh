#!/bin/bash

set -e

echo "🚀 Starting AI Voice Agent deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get GitHub repository URL
echo "📝 Please enter your GitHub repository URL (e.g., https://github.com/username/ai-voice-agent.git):"
read -p "Repository URL: " GITHUB_REPO

if [ -z "$GITHUB_REPO" ]; then
    echo -e "${RED}❌ Repository URL is required!${NC}"
    exit 1
fi

# Optional: Get branch name
echo "📝 Enter branch name (default: main):"
read -p "Branch: " GITHUB_BRANCH
GITHUB_BRANCH=${GITHUB_BRANCH:-main}

# Check if terraform.tfvars exists
if [ ! -f "terraform.tfvars" ]; then
    echo -e "${RED}❌ terraform.tfvars not found!${NC}"
    echo "Please copy terraform.tfvars.example to terraform.tfvars and fill in your values"
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

echo "⏳ Waiting for instance to be ready (this may take 2-3 minutes)..."
sleep 60

# Wait for SSH to be available
echo "🔌 Waiting for SSH connection..."
while ! nc -z $INSTANCE_IP 22; do
    sleep 10
    echo "Still waiting for SSH..."
done

echo "📥 Cloning repository and setting up application..."
ssh -i ~/.ssh/voice-agent-key -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP << ENDSSH
    # Wait for user-data to complete
    while [ ! -f /var/log/user-data.log ] || ! grep -q "User-data script completed" /var/log/user-data.log; do
        echo "Waiting for instance initialization to complete..."
        sleep 30
    done
    
    echo "Instance initialization completed!"
    
    # Clone the repository
    cd /opt/voice-agent
    sudo git clone -b $GITHUB_BRANCH $GITHUB_REPO .
    
    # Set permissions
    sudo chown -R voice-agent:voice-agent /opt/voice-agent
    
    # Get public IP for configuration
    PUBLIC_IP=\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
    
    # Setup Python backend
    echo "🐍 Setting up Python backend..."
    cd /opt/voice-agent
    python3 -m venv venv
    source venv/bin/activate
    cd server
    pip install --upgrade pip
    pip install -r requirements.txt
    
    # Create .env file for backend
    cat > .env << EOF
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_PHONE_NUMBER=
AWS_DEFAULT_REGION=us-east-1
SERVER_URL=http://\$PUBLIC_IP
SERVER_HOST=\$PUBLIC_IP
EOF
    
    echo "⚛️ Building React frontend..."
    cd /opt/voice-agent/frontend
    
    # Create .env file for frontend
    echo "VITE_API_URL=http://\$PUBLIC_IP:8000" > .env
    
    # Install dependencies and build
    npm install
    npm run build
    
    # Set final permissions
    sudo chown -R voice-agent:voice-agent /opt/voice-agent
    
    # Start services
    echo "🚀 Starting services..."
    sudo systemctl daemon-reload
    sudo systemctl enable voice-agent
    sudo systemctl start voice-agent
    sudo systemctl start nginx
    
    echo "✅ Application deployed and started successfully!"
ENDSSH

echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
echo ""
echo "📱 Access your application:"
echo "   Frontend: http://$INSTANCE_IP"
echo "   Backend:  http://$INSTANCE_IP:8000"
echo "   Health:   http://$INSTANCE_IP:8000/health"
echo ""
echo "🔧 SSH into instance:"
echo "   ssh -i ~/.ssh/voice-agent-key ec2-user@$INSTANCE_IP"
echo ""
echo "📝 Next steps:"
echo "   1. SSH into the instance"
echo "   2. Edit /opt/voice-agent/server/.env with your Twilio credentials"
echo "   3. Restart the service: sudo systemctl restart voice-agent"
echo ""
echo "🔍 Monitor logs:"
echo "   sudo tail -f /var/log/voice-agent/backend.log"