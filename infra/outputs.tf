# EC2 Instance Public IP
output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.voice_agent.public_ip
}

# EC2 Instance ID
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.voice_agent.id
}

# EC2 Instance Public DNS
output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.voice_agent.public_dns
}

# Frontend URL
output "frontend_url" {
  description = "URL to access the React frontend"
  value       = "http://${aws_instance.voice_agent.public_ip}"
}

# Backend URL
output "backend_url" {
  description = "URL to access the FastAPI backend"
  value       = "http://${aws_instance.voice_agent.public_ip}:8000"
}

# Backend Health Check URL
output "backend_health_url" {
  description = "URL to check backend health"
  value       = "http://${aws_instance.voice_agent.public_ip}:8000/health"
}

# SSH Connection Command
output "ssh_connection" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/voice-agent-key ec2-user@${aws_instance.voice_agent.public_ip}"
}

# Security Group ID
output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.voice_agent_sg.id
}

# Instance Zone
output "availability_zone" {
  description = "Availability zone where the instance is deployed"
  value       = aws_instance.voice_agent.availability_zone
}

# Quick Access URLs (formatted for easy copy-paste)
output "quick_access" {
  description = "Quick access information"
  value = {
    frontend    = "http://${aws_instance.voice_agent.public_ip}"
    backend     = "http://${aws_instance.voice_agent.public_ip}:8000"
    health      = "http://${aws_instance.voice_agent.public_ip}:8000/health"
    ssh         = "ssh -i ~/.ssh/voice-agent-key ec2-user@${aws_instance.voice_agent.public_ip}"
    public_ip   = aws_instance.voice_agent.public_ip
  }
}