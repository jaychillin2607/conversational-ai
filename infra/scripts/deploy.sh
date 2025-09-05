#!/bin/bash
# scripts/deploy.sh - Simple deployment with Twilio creds

set -e

echo "🚀 Deploying AI Voice Agent..."

# Get repo URL
echo "📝 GitHub repository URL:"
read -p "Repository URL: " GITHUB_REPO

if [ -z "$GITHUB_REPO" ]; then
    echo "❌ Repository URL required!"
    exit 1
fi

# Get Twilio credentials
echo ""
echo "📞 Twilio Configuration:"
read -p "Twilio Account SID: " TWILIO_ACCOUNT_SID
read -p "Twilio Auth Token: " TWILIO_AUTH_TOKEN
read -p "Twilio Phone Number (with +): " TWILIO_PHONE_NUMBER

if [ -z "$TWILIO_ACCOUNT_SID" ] || [ -z "$TWILIO_AUTH_TOKEN" ] || [ -z "$TWILIO_PHONE_NUMBER" ]; then
    echo "❌ All Twilio credentials are required!"
    exit 1
fi

# Deploy infrastructure
echo "🏗️ Creating infrastructure..."
terraform init
terraform apply -auto-approve

INSTANCE_IP=$(terraform output -raw instance_public_ip)
echo "✅ Instance IP: $INSTANCE_IP"

# Wait for SSH
echo "⏳ Waiting for SSH..."
sleep 60
while ! nc -z $INSTANCE_IP 22; do sleep 10; done

# Deploy app
echo "📦 Deploying application..."
ssh -i ~/.ssh/voice-agent-key -o StrictHostKeyChecking=no ec2-user@$INSTANCE_IP << ENDSSH
    # Wait for Docker
    while ! docker ps &>/dev/null; do sleep 5; done
    
    # Clone and build
    git clone $GITHUB_REPO app
    cd app
    
    # Get public IP
    PUBLIC_IP=\$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
    
    # Build backend
    cd server
    docker build -t voice-backend .
    
    # Build frontend with API URL
    cd ../frontend
    echo "VITE_API_URL=http://\$PUBLIC_IP:8000" > .env
    docker build -t voice-frontend .
    
    # Run backend with all environment variables
    docker run -d --name backend -p 8000:8000 \
        -e AWS_DEFAULT_REGION=us-east-1 \
        -e TWILIO_ACCOUNT_SID=$TWILIO_ACCOUNT_SID \
        -e TWILIO_AUTH_TOKEN=$TWILIO_AUTH_TOKEN \
        -e TWILIO_PHONE_NUMBER=$TWILIO_PHONE_NUMBER \
        -e SERVER_URL=http://\$PUBLIC_IP \
        -e SERVER_HOST=\$PUBLIC_IP \
        --restart unless-stopped \
        voice-backend
    
    # Run frontend
    docker run -d --name frontend -p 80:80 \
        --restart unless-stopped \
        voice-frontend
    
    echo "✅ Containers running!"
    docker ps
    
    # Test backend health
    sleep 5
    curl -f http://localhost:8000/health && echo "✅ Backend healthy!" || echo "❌ Backend not responding"
ENDSSH

echo "🎉 Deployment Complete!"
echo ""
echo "📱 Your Application:"
echo "   Frontend: http://$INSTANCE_IP"
echo "   Backend:  http://$INSTANCE_IP:8000"
echo "   Health:   http://$INSTANCE_IP:8000/health"
echo ""
echo "🔍 Debug commands:"
echo "   ssh -i ~/.ssh/voice-agent-key ec2-user@$INSTANCE_IP"
echo "   docker logs backend"
echo "   docker logs frontend"