# LeyLine DNS Service - Deployment Guide

## 🚀 Quick Deployment

### **Prerequisites**
- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- Docker installed
- Git repository access

### **1. Clone and Setup**
```bash
git clone https://github.com/your-username/leyline-dns-service.git
cd leyline-dns-service
```

### **2. Configure AWS**
```bash
aws configure
# Enter your AWS Access Key ID, Secret Access Key, and region
```

### **3. Deploy Infrastructure**
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

terraform init
terraform plan
terraform apply
```

### **4. Deploy Application**
```bash
# Build and push Docker image
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-west-2.amazonaws.com

docker build -t leyline-api .
docker tag leyline-api:latest <account-id>.dkr.ecr.us-west-2.amazonaws.com/leyline-api:latest
docker push <account-id>.dkr.ecr.us-west-2.amazonaws.com/leyline-api:latest

# Update ECS service
aws ecs update-service --cluster leyline-dev-cluster --service leyline-dev-service --force-new-deployment
```

## 📋 Detailed Deployment Steps

### **Phase 1: Infrastructure Setup**

#### **1.1 VPC and Networking**
```bash
# Deploy VPC with public/private subnets
terraform apply -target=module.vpc
```

#### **1.2 Security Groups**
```bash
# Deploy security groups
terraform apply -target=module.security_groups
```

#### **1.3 Application Load Balancer**
```bash
# Deploy ALB
terraform apply -target=module.alb
```

#### **1.4 Database and Cache**
```bash
# Deploy RDS and Redis
terraform apply -target=module.rds
terraform apply -target=module.redis
```

#### **1.5 ECS Cluster**
```bash
# Deploy ECS cluster
terraform apply -target=module.ecs_cluster
```

### **Phase 2: Application Deployment**

#### **2.1 Build and Push Container**
```bash
# Build Docker image
docker build -t leyline-api .

# Tag for ECR
docker tag leyline-api:latest <account-id>.dkr.ecr.us-west-2.amazonaws.com/leyline-api:latest

# Push to ECR
docker push <account-id>.dkr.ecr.us-west-2.amazonaws.com/leyline-api:latest
```

#### **2.2 Deploy ECS Service**
```bash
# Deploy ECS service
terraform apply -target=module.ecs_service
```

#### **2.3 Verify Deployment**
```bash
# Get ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test health endpoint
curl http://$ALB_DNS/health

# Test API endpoint
curl -H "X-API-Key: leyline-api-key-2024" http://$ALB_DNS/
```

## 🔧 Configuration Management

### **Environment Variables**

#### **Development**
```bash
DATABASE_URL=postgresql://leyline_user:password@localhost:5432/leyline_db
REDIS_URL=redis://localhost:6379
JWT_SECRET_KEY=dev-secret-key
ENVIRONMENT=development
```

#### **Production**
```bash
DATABASE_URL=postgresql://leyline_user:${DB_PASSWORD}@${RDS_ENDPOINT}:5432/leyline_db
REDIS_URL=redis://${REDIS_ENDPOINT}:6379
JWT_SECRET_KEY=${JWT_SECRET}
ENVIRONMENT=production
```

### **Secrets Management**

#### **AWS Secrets Manager**
```bash
# Create database password secret
aws secretsmanager create-secret \
  --name "leyline-dev-db-password" \
  --description "Database password for LeyLine DNS Service" \
  --secret-string "your-secure-password"

# Create JWT secret
aws secretsmanager create-secret \
  --name "leyline-dev-jwt-secret" \
  --description "JWT secret key for LeyLine DNS Service" \
  --secret-string "your-jwt-secret-key"
```

## 🚨 Monitoring Setup

### **Prometheus Configuration**
```yaml
# monitoring/prometheus.yml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'leyline-dns-service'
    static_configs:
      - targets: ['leyline-api:3000']
    metrics_path: '/metrics'
    basic_auth:
      username: 'prometheus'
      password: 'monitoring-password'
```

### **Grafana Dashboard**
1. Access Grafana at `http://localhost:3001`
2. Import dashboard from `monitoring/grafana/dashboards/leyline-dns-service.json`
3. Configure Prometheus data source

### **CloudWatch Integration**
```bash
# Enable CloudWatch Container Insights
aws ecs put-account-setting --name containerInsights --value enabled
```

## 🔒 Security Configuration

### **API Keys**
```bash
# Create API keys in Kong
curl -X POST http://localhost:8001/consumers/leyline-client/key-auth \
  --data "key=leyline-api-key-2024"

curl -X POST http://localhost:8001/consumers/admin/key-auth \
  --data "key=admin-key-2024"
```

### **SSL/TLS Setup**
```bash
# Request SSL certificate
aws acm request-certificate \
  --domain-name api.yourdomain.com \
  --validation-method DNS

# Configure ALB listener for HTTPS
terraform apply -target=module.alb
```

## 📊 Health Checks

### **Application Health**
```bash
# Health check
curl http://$ALB_DNS/health

# Readiness check
curl http://$ALB_DNS/ready

# Liveness check
curl http://$ALB_DNS/live
```

### **Infrastructure Health**
```bash
# ECS service status
aws ecs describe-services --cluster leyline-dev-cluster --services leyline-dev-service

# ALB target health
aws elbv2 describe-target-health --target-group-arn $(terraform output -raw target_group_arn)

# RDS instance status
aws rds describe-db-instances --db-instance-identifier leyline-dev-db
```

## 🔄 CI/CD Pipeline

### **GitHub Actions Setup**
1. Fork the repository
2. Configure GitHub Secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `ECR_REPOSITORY`
   - `ECS_CLUSTER`
   - `ECS_SERVICE`

### **Pipeline Triggers**
- **Push to main**: Full deployment pipeline
- **Push to develop**: Development deployment
- **Pull Request**: Security scan and testing only

## 🚨 Troubleshooting

### **Common Issues**

#### **Service Not Starting**
```bash
# Check ECS task logs
aws logs get-log-events \
  --log-group-name /ecs/leyline-dev \
  --log-stream-name ecs/leyline-api/<task-id>

# Check task definition
aws ecs describe-task-definition --task-definition leyline-dev-task
```

#### **Database Connection Issues**
```bash
# Check RDS instance status
aws rds describe-db-instances --db-instance-identifier leyline-dev-db

# Test database connectivity
psql -h <rds-endpoint> -U leyline_user -d leyline_db
```

#### **Redis Connection Issues**
```bash
# Check Redis cluster status
aws elasticache describe-cache-clusters --cache-cluster-id leyline-dev-redis

# Test Redis connectivity
redis-cli -h <redis-endpoint> ping
```

#### **ALB Health Check Failures**
```bash
# Check target group health
aws elbv2 describe-target-health --target-group-arn <target-group-arn>

# Check security group rules
aws ec2 describe-security-groups --group-ids <security-group-id>
```

### **Log Analysis**
```bash
# Application logs
aws logs tail /ecs/leyline-dev --follow

# ALB access logs
aws s3 cp s3://leyline-dev-alb-logs/alb-logs/ . --recursive

# CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=leyline-dev-service \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 300 \
  --statistics Average
```

## 📈 Scaling and Performance

### **Auto Scaling Configuration**
```bash
# Update auto scaling settings
aws application-autoscaling put-scaling-policy \
  --service-namespace ecs \
  --resource-id service/leyline-dev-cluster/leyline-dev-service \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-name leyline-dev-scaling-policy \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration file://scaling-policy.json
```

### **Performance Tuning**
```bash
# Update ECS task definition with optimized settings
aws ecs register-task-definition --cli-input-json file://task-definition.json

# Update ECS service
aws ecs update-service \
  --cluster leyline-dev-cluster \
  --service leyline-dev-service \
  --task-definition leyline-dev-task:2
```

## 🔄 Backup and Recovery

### **Database Backups**
```bash
# Create manual snapshot
aws rds create-db-snapshot \
  --db-instance-identifier leyline-dev-db \
  --db-snapshot-identifier leyline-dev-backup-$(date +%Y%m%d)

# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier leyline-dev-restored \
  --db-snapshot-identifier leyline-dev-backup-20240101
```

### **Infrastructure Backup**
```bash
# Export Terraform state
terraform state pull > terraform-state-backup.json

# Backup configuration files
tar -czf config-backup.tar.gz terraform/ monitoring/ .github/
```

## 🎯 Production Readiness Checklist

### **Security**
- [ ] SSL/TLS certificates configured
- [ ] API keys rotated regularly
- [ ] Secrets stored in AWS Secrets Manager
- [ ] Security groups follow least privilege
- [ ] WAF rules configured
- [ ] CloudTrail logging enabled

### **Monitoring**
- [ ] Prometheus metrics collection
- [ ] Grafana dashboards configured
- [ ] CloudWatch alarms set up
- [ ] Log aggregation working
- [ ] Alert notifications configured

### **Reliability**
- [ ] Multi-AZ deployment
- [ ] Auto-scaling configured
- [ ] Health checks working
- [ ] Graceful shutdown implemented
- [ ] Circuit breakers in place

### **Performance**
- [ ] Load testing completed
- [ ] Performance baselines established
- [ ] Caching strategies implemented
- [ ] Database optimization done
- [ ] CDN configured (if needed)

### **Operations**
- [ ] Runbooks documented
- [ ] Incident response procedures
- [ ] Backup and recovery tested
- [ ] Disaster recovery plan
- [ ] Cost monitoring enabled

## 📞 Support and Maintenance

### **Regular Maintenance Tasks**
- **Weekly**: Review logs and metrics
- **Monthly**: Update dependencies and security patches
- **Quarterly**: Review and update security policies
- **Annually**: Disaster recovery testing

### **Monitoring Alerts**
- Service availability < 99.9%
- Error rate > 1%
- Response time > 2 seconds
- Database connections > 80%
- Memory usage > 90%

### **Emergency Contacts**
- **On-call Engineer**: +1-555-0123
- **DevOps Team**: devops@company.com
- **Security Team**: security@company.com
- **AWS Support**: Enterprise Support Case

---

**For additional support, please refer to the main README.md or create an issue in the GitHub repository.**
