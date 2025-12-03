Welcome to Lab 11! This advanced lab takes your chaos engineering skills to the next level. You'll use AWS Fault Injection Simulator (FIS) to inject sophisticated failures, conduct structured chaos experiments, analyze system behavior under stress, and build automated chaos testing into your workflow. This lab is designed to be challenging and will push you to think like a Site Reliability Engineer.

Unlike Lab 10's basic chaos experiments (manually terminating instances), this lab introduces controlled, repeatable chaos experiments using AWS managed services. You'll inject network latency, stress CPU resources, test cascading failures, and learn to design comprehensive GameDay scenarios.

**Time Estimate:** 120-150 minutes  

**Difficulty:** ⭐⭐⭐ Advanced

**Goals:**

- Master AWS Fault Injection Simulator (FIS)
- Design and execute structured chaos experiments
- Inject network failures (latency, packet loss)
- Stress test system resources (CPU, memory, I/O)
- Analyze system behavior using CloudWatch metrics
- Implement steady-state hypothesis validation
- Build automated chaos testing pipelines
- Conduct a full-scale GameDay exercise

**Prerequisites:**

- Completion of Lab 10 (basic chaos engineering)
- Completion of Lab 8 (CloudFormation multi-tier deployment)
- Strong understanding of AWS services (EC2, CloudWatch, IAM)
- Familiarity with observability concepts
- Python basics (for custom scripts)

**Important Notes:**

- **Costs:** FIS experiments have minimal costs (~$0.10-0.50 per experiment). Use free tier resources where possible.
- **Region:** Use **us-east-1** for full FIS feature availability
- **Production Warning:** Never run chaos experiments on production without proper planning, monitoring, and rollback procedures!

---

## What is AWS Fault Injection Simulator (FIS)?

AWS FIS is a fully managed chaos engineering service that makes it easier to improve resilience by injecting faults into your AWS workloads. Unlike manual chaos testing, FIS provides:

- **Controlled experiments** with safety guardrails
- **Pre-built actions** for common failure scenarios
- **Targeting precision** to affect specific resources
- **Stop conditions** to halt experiments if things go wrong
- **CloudWatch integration** for monitoring impacts
- **IAM-based permissions** for security

---

## Architecture Overview

You'll build and chaos-test this architecture:

```
┌─────────────────────────────────────────────────────────┐
│                  Application Load Balancer              │
│                 (with Target Groups)                     │
└──────┬────────────────────────┬─────────────────────────┘
       │                        │
   ┌───▼────────┐         ┌─────▼──────┐
   │  Primary   │         │  Backup    │
   │  Region    │         │  Region    │
   │  (us-e-1a) │         │  (us-e-1b) │
   └───┬────────┘         └─────┬──────┘
       │                        │
   [3 Instances]            [2 Instances]
       │                        │
   ┌───▼─────────────────────────▼──────┐
   │          RDS Database               │
   │      (Multi-AZ enabled)             │
   └─────────────────────────────────────┘
       │
   ┌───▼──────────────────────────────────┐
   │    CloudWatch + X-Ray Monitoring      │
   └───────────────────────────────────────┘
```

**Chaos Experiments We'll Run:**

1. Network latency injection
2. CPU stress testing
3. Instance termination (advanced targeting)
4. Database connection saturation
5. Multi-failure cascading scenarios
6. Full GameDay simulation

---

## Part 1: Infrastructure Setup

### Step 1: Deploy the Test Application

We'll deploy a more complex application than Lab 10 to make chaos experiments meaningful.

**Create `chaos-lab-infrastructure.yaml`:**

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Lab 11 - Advanced Chaos Engineering Infrastructure'

Parameters:
  EmailAddress:
    Type: String
    Description: Email for CloudWatch alarms
    AllowedPattern: ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$

Resources:
  # VPC and Networking
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.0.0.0/16
      EnableDnsHostnames: true
      EnableDnsSupport: true
      Tags:
        - Key: Name
          Value: Lab11-VPC

  InternetGateway:
    Type: AWS::EC2::InternetGateway
    Properties:
      Tags:
        - Key: Name
          Value: Lab11-IGW

  AttachGateway:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId: !Ref VPC
      InternetGatewayId: !Ref InternetGateway

  PublicSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.1.0/24
      AvailabilityZone: !Select [0, !GetAZs '']
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: Lab11-Public-1a

  PublicSubnet2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.2.0/24
      AvailabilityZone: !Select [1, !GetAZs '']
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: Lab11-Public-1b

  PublicRouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: Lab11-Public-RT

  PublicRoute:
    Type: AWS::EC2::Route
    DependsOn: AttachGateway
    Properties:
      RouteTableId: !Ref PublicRouteTable
      DestinationCidrBlock: 0.0.0.0/0
      GatewayId: !Ref InternetGateway

  SubnetRouteTableAssoc1:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnet1
      RouteTableId: !Ref PublicRouteTable

  SubnetRouteTableAssoc2:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnet2
      RouteTableId: !Ref PublicRouteTable

  # Security Groups
  ALBSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Allow HTTP to ALB
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          CidrIp: 0.0.0.0/0
      Tags:
        - Key: Name
          Value: Lab11-ALB-SG

  WebServerSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Allow traffic from ALB
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          SourceSecurityGroupId: !Ref ALBSecurityGroup
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: 0.0.0.0/0
      Tags:
        - Key: Name
          Value: Lab11-Web-SG

  # IAM Role for FIS
  FISRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: Lab11-FIS-Role
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: fis.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
      Policies:
        - PolicyName: FISExperimentPolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - ec2:DescribeInstances
                  - ec2:StopInstances
                  - ec2:TerminateInstances
                  - ec2:RebootInstances
                  - cloudwatch:DescribeAlarms
                Resource: '*'

  # Load Balancer
  ApplicationLoadBalancer:
    Type: AWS::ElasticLoadBalancingV2::LoadBalancer
    DependsOn: AttachGateway
    Properties:
      Name: Lab11-ALB
      Scheme: internet-facing
      Type: application
      Subnets:
        - !Ref PublicSubnet1
        - !Ref PublicSubnet2
      SecurityGroups:
        - !Ref ALBSecurityGroup
      Tags:
        - Key: Name
          Value: Lab11-ALB

  TargetGroup:
    Type: AWS::ElasticLoadBalancingV2::TargetGroup
    Properties:
      Name: Lab11-TG
      Port: 80
      Protocol: HTTP
      VpcId: !Ref VPC
      HealthCheckEnabled: true
      HealthCheckPath: /health
      HealthCheckIntervalSeconds: 10
      HealthCheckTimeoutSeconds: 5
      HealthyThresholdCount: 2
      UnhealthyThresholdCount: 3
      Tags:
        - Key: Name
          Value: Lab11-TG

  ALBListener:
    Type: AWS::ElasticLoadBalancingV2::Listener
    Properties:
      LoadBalancerArn: !Ref ApplicationLoadBalancer
      Port: 80
      Protocol: HTTP
      DefaultActions:
        - Type: forward
          TargetGroupArn: !Ref TargetGroup

  # Launch Template with enhanced monitoring
  LaunchTemplate:
    Type: AWS::EC2::LaunchTemplate
    Properties:
      LaunchTemplateName: Lab11-Template
      LaunchTemplateData:
        ImageId: !Sub '{{resolve:ssm:/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2}}'
        InstanceType: t2.micro
        SecurityGroupIds:
          - !Ref WebServerSecurityGroup
        IamInstanceProfile:
          Arn: !GetAtt InstanceProfile.Arn
        UserData:
          Fn::Base64: !Sub |
            #!/bin/bash
            yum update -y
            yum install -y httpd stress-ng amazon-cloudwatch-agent python3 pip
            
            # Install CloudWatch agent
            wget https://s3.amazonaws.com/amazoncloudwatch-agent/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm
            rpm -U ./amazon-cloudwatch-agent.rpm
            
            # Configure CloudWatch agent
            cat > /opt/aws/amazon-cloudwatch-agent/etc/config.json <<'EOF'
            {
              "metrics": {
                "namespace": "Lab11/ChaosApp",
                "metrics_collected": {
                  "cpu": {
                    "measurement": [{"name": "cpu_usage_idle", "rename": "CPU_IDLE", "unit": "Percent"}],
                    "metrics_collection_interval": 10
                  },
                  "mem": {
                    "measurement": [{"name": "mem_used_percent"}],
                    "metrics_collection_interval": 10
                  },
                  "netstat": {
                    "measurement": [{"name": "tcp_established"}],
                    "metrics_collection_interval": 10
                  }
                }
              }
            }
            EOF
            
            /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
              -a fetch-config \
              -m ec2 \
              -s \
              -c file:/opt/aws/amazon-cloudwatch-agent/etc/config.json
            
            # Start Apache
            systemctl start httpd
            systemctl enable httpd
            
            # Get instance metadata
            INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
            AZ=$(ec2-metadata --availability-zone | cut -d " " -f 2)
            
            # Create application
            cat > /var/www/html/index.html <<EOF
            <!DOCTYPE html>
            <html>
            <head>
                <title>Lab 11 - Chaos Engineering</title>
                <style>
                    body { font-family: 'Courier New', monospace; background: #0a0a0a; color: #00ff00; padding: 40px; }
                    .container { max-width: 900px; margin: 0 auto; border: 2px solid #00ff00; padding: 30px; }
                    h1 { color: #00ff00; text-shadow: 0 0 10px #00ff00; }
                    .metric { background: #1a1a1a; padding: 15px; margin: 10px 0; border-left: 4px solid #00ff00; }
                    .warning { color: #ffaa00; }
                    .status { display: inline-block; padding: 5px 15px; background: #00ff00; color: #0a0a0a; font-weight: bold; }
                </style>
                <script>
                    function updateMetrics() {
                        fetch('/metrics')
                            .then(r => r.json())
                            .then(data => {
                                document.getElementById('connections').textContent = data.connections || 'N/A';
                                document.getElementById('load').textContent = data.load || 'N/A';
                            });
                    }
                    setInterval(updateMetrics, 5000);
                    updateMetrics();
                </script>
            </head>
            <body>
                <div class="container">
                    <h1>⚡ CHAOS LAB 11: RESILIENCE TEST ENVIRONMENT</h1>
                    <p class="status">OPERATIONAL</p>
                    
                    <div class="metric">
                        <strong>Instance ID:</strong> $INSTANCE_ID<br>
                        <strong>Availability Zone:</strong> $AZ<br>
                        <strong>Architecture:</strong> Chaos-Ready Multi-AZ
                    </div>
                    
                    <div class="metric">
                        <strong>Live Metrics:</strong><br>
                        Active Connections: <span id="connections">Loading...</span><br>
                        System Load: <span id="load">Loading...</span>
                    </div>
                    
                    <div class="metric">
                        <p class="warning">⚠️ This system is designed for chaos testing</p>
                        <p>Current resilience features:</p>
                        <p>✓ Multi-AZ deployment</p>
                        <p>✓ Auto-scaling enabled</p>
                        <p>✓ Health monitoring</p>
                        <p>✓ FIS integration ready</p>
                    </div>
                </div>
            </body>
            </html>
            EOF
            
            # Create health endpoint
            echo "OK" > /var/www/html/health
            
            # Create metrics API endpoint
            cat > /var/www/cgi-bin/metrics <<'SCRIPT'
            #!/bin/bash
            echo "Content-Type: application/json"
            echo ""
            CONNECTIONS=$(netstat -an | grep ESTABLISHED | wc -l)
            LOAD=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}')
            echo "{\"connections\": $CONNECTIONS, \"load\": \"$LOAD\"}"
            SCRIPT
            chmod +x /var/www/cgi-bin/metrics
            
            # Enable CGI
            sed -i 's/#LoadModule cgid_module/LoadModule cgid_module/' /etc/httpd/conf.modules.d/01-cgi.conf
            systemctl restart httpd
        TagSpecifications:
          - ResourceType: instance
            Tags:
              - Key: Name
                Value: Lab11-ChaosInstance
              - Key: ChaosReady
                Value: 'true'

  # IAM Role for instances (CloudWatch access)
  InstanceRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: ec2.amazonaws.com
            Action: sts:AssumeRole
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy
      Tags:
        - Key: Name
          Value: Lab11-Instance-Role

  InstanceProfile:
    Type: AWS::IAM::InstanceProfile
    Properties:
      Roles:
        - !Ref InstanceRole

  # Auto Scaling Group
  AutoScalingGroup:
    Type: AWS::AutoScaling::AutoScalingGroup
    DependsOn:
      - TargetGroup
    Properties:
      AutoScalingGroupName: Lab11-ASG
      LaunchTemplate:
        LaunchTemplateId: !Ref LaunchTemplate
        Version: !GetAtt LaunchTemplate.LatestVersionNumber
      MinSize: 3
      MaxSize: 6
      DesiredCapacity: 5
      HealthCheckType: ELB
      HealthCheckGracePeriod: 300
      VPCZoneIdentifier:
        - !Ref PublicSubnet1
        - !Ref PublicSubnet2
      TargetGroupARNs:
        - !Ref TargetGroup
      Tags:
        - Key: Name
          Value: Lab11-ASG-Instance
          PropagateAtLaunch: true
        - Key: Environment
          Value: ChaosLab
          PropagateAtLaunch: true

  # SNS Topic for Alarms
  AlarmTopic:
    Type: AWS::SNS::Topic
    Properties:
      TopicName: Lab11-Chaos-Alarms
      Subscription:
        - Endpoint: !Ref EmailAddress
          Protocol: email

  # CloudWatch Alarms
  UnhealthyHostAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: Lab11-UnhealthyHosts
      AlarmDescription: Alert when targets are unhealthy
      MetricName: UnHealthyHostCount
      Namespace: AWS/ApplicationELB
      Statistic: Average
      Period: 60
      EvaluationPeriods: 2
      Threshold: 1
      ComparisonOperator: GreaterThanOrEqualToThreshold
      Dimensions:
        - Name: TargetGroup
          Value: !GetAtt TargetGroup.TargetGroupFullName
        - Name: LoadBalancer
          Value: !GetAtt ApplicationLoadBalancer.LoadBalancerFullName
      AlarmActions:
        - !Ref AlarmTopic

Outputs:
  LoadBalancerURL:
    Description: Application Load Balancer URL
    Value: !Sub 'http://${ApplicationLoadBalancer.DNSName}'
    Export:
      Name: !Sub '${AWS::StackName}-ALB-URL'
  
  FISRoleArn:
    Description: IAM Role ARN for FIS experiments
    Value: !GetAtt FISRole.Arn
    Export:
      Name: !Sub '${AWS::StackName}-FIS-Role'
  
  AutoScalingGroupName:
    Description: Auto Scaling Group Name
    Value: !Ref AutoScalingGroup
    Export:
      Name: !Sub '${AWS::StackName}-ASG'
```

**Deploy the infrastructure:**

1. Save the template as `chaos-lab-infrastructure.yaml`
2. AWS Console → CloudFormation → Create stack
3. Upload template
4. Stack name: `Lab11-Chaos-Infrastructure`
5. Parameters:
   - EmailAddress: `your-email@example.com`
6. Create stack
7. **Wait 8-10 minutes** for full deployment
8. **Confirm SNS subscription** in your email

**Verify deployment:**

- Open the Load Balancer URL from Outputs
- You should see the green "Chaos Lab" interface
- Refresh multiple times to see different instance IDs
- Check CloudWatch → Metrics → Lab11/ChaosApp for custom metrics

---

## Part 2: AWS Fault Injection Simulator Basics

### Step 2: Create Your First FIS Experiment Template

**Experiment: CPU Stress Test**

This experiment will stress CPU on a subset of instances to test if the system can handle partial degradation.

1. **AWS Console → FIS → Experiment templates → Create experiment template**

2. **Configure experiment:**
   - Name: `Lab11-CPU-Stress`
   - Description: `Inject CPU stress on 40% of instances`
   - IAM role: Select `Lab11-FIS-Role`

3. **Actions:**
   - Click **Add action**
   - Action name: `StressCPU`
   - Action type: Search for `aws:ssm:send-command`
   - Document ARN: `arn:aws:ssm:us-east-1::document/AWSFIS-Run-CPU-Stress`
   - Document parameters:

     ```json
     {
       "DurationSeconds": "180",
       "CPU": "80",
       "Workers": "2"
     }
     ```

   - Duration: `3 minutes`

4. **Targets:**
   - Click **Edit** next to the action
   - Target name: `ChaosInstances`
   - Resource type: `aws:ec2:instance`
   - Target method: `Resource tags`
   - Resource tags:
     - Key: `ChaosReady`
     - Value: `true`
   - Selection mode: `Percent`
   - Number of resources: `40`

5. **Stop conditions:**
   - Add stop condition
   - Source: `aws:cloudwatch:alarm`
   - Alarm: Select `Lab11-UnhealthyHosts`
   - This will stop the experiment if too many instances become unhealthy

6. **Create experiment template**

**Understanding what you created:**

- **Action**: Runs a Systems Manager (SSM) command to stress CPU
- **Target**: 40% of instances tagged `ChaosReady=true` (2 out of 5 instances)
- **Duration**: 3 minutes of CPU stress
- **Stop condition**: Halts if alarm triggers (safety guardrail)

---

### Step 3: Run the CPU Stress Experiment

**Before running:**

1. **Open monitoring dashboards:**
   - CloudWatch → Dashboards (create new if needed)
   - Add widgets for:
     - Target Healthy Host Count
     - ALB Request Count
     - Custom namespace: Lab11/ChaosApp → CPU_IDLE

2. **Open your application in browser:**
   - Keep refreshing to observe behavior

3. **Set up a monitoring script** (optional):

   ```bash
   # Run this in your terminal to monitor response times
   while true; do
     curl -o /dev/null -s -w "Time: %{time_total}s, HTTP: %{http_code}\n" \
       http://<your-alb-dns>/
     sleep 2
   done
   ```

**Run the experiment:**

1. FIS → Experiment templates → Select `Lab11-CPU-Stress`
2. **Start experiment**
3. Confirm by typing `start`
4. **Watch the experiment progress:**
   - Status shows "Running"
   - Monitor CloudWatch metrics
   - Watch application behavior

**What to observe:**

✅ **Expected behavior:**

- Some instances show high CPU (80%+)
- Application remains available (3 healthy instances)
- Response times may increase slightly
- No 5xx errors
- Load balancer routes around stressed instances

❌ **Unexpected issues:**

- Complete outage (stop experiment immediately)
- Unhealthy host alarm triggers
- Massive response time degradation

**Document your findings:**

```
Experiment: CPU Stress (40% of instances)
Hypothesis: System remains available with 2/5 instances stressed
Duration: 3 minutes
Results:
- Availability: [  ]% 
- Avg Response Time: [  ]ms
- Errors: [  ] 5xx errors
- Recovery Time: [  ] seconds after experiment ended
Conclusion: ✅ Pass / ❌ Fail
Lessons Learned:
```

---

### Step 4: Network Latency Injection

**Challenge your understanding of distributed systems!**

Create a second experiment to inject network latency.

**Create experiment template:**

1. FIS → Create experiment template
2. Name: `Lab11-Network-Latency`
3. Description: `Inject 200ms network latency`
4. IAM role: `Lab11-FIS-Role`

5. **Action:**
   - Action name: `InjectLatency`
   - Action type: `aws:ssm:send-command`
   - Document: `AWSFIS-Run-Network-Latency`
   - Parameters:

     ```json
     {
       "DurationSeconds": "300",
       "DelayMilliseconds": "200",
       "Interface": "eth0"
     }
     ```

6. **Targets:**
   - Same as before (40% of ChaosReady instances)

7. **Stop conditions:**
   - Add CloudWatch alarm: `Lab11-UnhealthyHosts`
   - Add custom stop condition:
     - Create new alarm for ALB Target Response Time > 5 seconds

**Run and observe:**

**Hypothesis:** "Adding 200ms latency to 40% of instances will increase avg response time but maintain < 1 second total"

Monitor:

- ALB Target Response Time metric
- Application behavior
- User experience

**Challenge question:**
If 2 out of 5 instances have +200ms latency, what's the probability a user hits a slow instance on 3 consecutive requests?

Answer: ___________

---

## Part 3: Advanced Chaos Scenarios

### Step 5: Cascade Failure Simulation

**Objective:** Test what happens when failures cascade through the system.

**Scenario:** Stress CPU → causes slow responses → triggers timeout cascades → potential avalanche

**Create multi-action experiment:**

1. FIS → Create experiment template
2. Name: `Lab11-Cascade-Failure`
3. Configure **sequential actions:**

   **Action 1: Initial Stress**
   - Name: `InitialCPUStress`
   - Type: `aws:ssm:send-command`
   - Document: `AWSFIS-Run-CPU-Stress`
   - Duration: 2 minutes
   - Target: 20% of instances

   **Action 2: Increase Pressure**  
   - Name: `IncreasedStress`
   - Type: `aws:ssm:send-command`
   - Document: `AWSFIS-Run-CPU-Stress`
   - Duration: 2 minutes
   - Target: 40% of instances
   - Start after: `InitialCPUStress` completes

   **Action 3: Network Degradation**
   - Name: `NetworkLatency`
   - Type: `aws:ssm:send-command`
   - Document: `AWSFIS-Run-Network-Latency`
   - Duration: 2 minutes
   - Target: 60% of instances
   - Start after: `IncreasedStress` completes

**Set up comprehensive monitoring:**

Create CloudWatch dashboard with:

- Healthy/Unhealthy target count
- Request count
- Response time (p50, p95, p99)
- HTTP 5xx error rate
- Custom CPU metrics

**Run the experiment:**

Document at each stage:

- Stage 1 (20% CPU stressed): _________
- Stage 2 (40% CPU stressed): _________
- Stage 3 (60% latency): _________
- Recovery: _________

**Analysis questions:**

1. At what point did the system start degrading noticeably?
2. Did the Auto Scaling Group respond? How many instances were added?
3. What was the maximum response time observed?
4. How long did full recovery take?

---

### Step 6: Instance Termination with Targeting

**Advanced targeting challenge:** Terminate instances in a specific AZ to simulate AZ failure.

1. **Create experiment:**
   - Name: `Lab11-AZ-Failure-Simulation`
   - Action type: `aws:ec2:terminate-instances`
   - Target: Instances in availability zone `us-east-1a` only
   - Percentage: 100% (all instances in that AZ)

2. **Add targets with filters:**

   ```json
   {
     "ResourceTags": [
       {"Key": "ChaosReady", "Value": "true"}
     ],
     "Availability Zones": ["us-east-1a"]
   }
   ```

3. **Stop conditions:**
   - Unhealthy host count > 3
   - HTTP 5xx error rate > 5%

**Before running:**

- Note current instance distribution across AZs
- Ensure you have instances in both us-east-1a and us-east-1b

**Run and observe:**

- Do instances in us-east-1b handle all traffic?
- How fast does Auto Scaling replace instances?
- Does the ASG balance across AZs after recovery?

---

## Part 4: GameDay - Full Chaos Exercise

### Step 7: Conduct a Structured GameDay

A GameDay is a planned chaos engineering event where the team responds to injected failures.

**GameDay Scenario: "Black Friday Stress Test"**

**Premise:** Your application must survive Black Friday traffic with infrastructure failures.

**Setup (30 minutes before):**

1. **Assemble roles:**
   - Incident Commander (you)
   - Monitoring Lead (watch dashboards)
   - Communications (document timeline)

2. **Define success criteria:**
   - SLO: 99.5% availability
   - Response time p95 < 2 seconds
   - Zero customer-facing errors

3. **Prepare runbooks:**
   - How to scale manually
   - How to terminate experiments
   - Rollback procedures

**GameDay Timeline (60 minutes):**

**T-0:00 - Baseline**

- Verify all systems healthy
- Record baseline metrics
- Start monitoring

**T+5:00 - Failure Injection Wave 1**

- Run: CPU Stress on 40% instances
- Observe: Does monitoring detect it?
- Action: Should you scale? Or wait?

**T+15:00 - Failure Injection Wave 2**

- Run: Network latency on 60% instances
- Observe: Compound effect of CPU + latency
- Action: Incident response procedures

**T+25:00 - Surprise Failure** (prepare this secretly)

- Run: Terminate 2 random instances simultaneously
- This simulates unexpected infrastructure failure
- Test: Can team diagnose and respond?

**T+35:00 - Recovery Phase**

- Stop all experiments
- Observe: How long to full recovery?
- Document: What automation worked? What didn't?

**T+45:00 - Postmortem**

- Review timeline
- Calculate SLO achievement
- Identify improvements

**GameDay Report Template:**

```markdown
# GameDay Report: Black Friday Stress Test

## Executive Summary
- Duration: 60 minutes
- Failures Injected: [list]
- SLO Achievement: [  ]%
- Incidents: [number]

## Timeline
| Time | Event | System Response | Team Action | Outcome |
|------|-------|-----------------|-------------|---------|
| T+0  |       |                 |             |         |

## Metrics
- Uptime: [  ]%
- P95 Response Time: [  ]ms
- Error Rate: [  ]%
- MTTR: [  ] minutes

## What Went Well
- [Success 1]
- [Success 2]

## What Needs Improvement
- [Gap 1]
- [Gap 2]

## Action Items
- [ ] [Improvement 1]
- [ ] [Improvement 2]
```

---

## Part 5: Automated Chaos Testing

### Step 8: Schedule Recurring Chaos Experiments

**Make chaos part of your CI/CD pipeline!**

**Option 1: EventBridge Scheduled Experiments**

1. **Create EventBridge rule:**
   - Service: EventBridge
   - Create rule
   - Name: `Weekly-Chaos-Test`
   - Schedule: `cron(0 14 ? * MON *)` (Every Monday at 2 PM UTC)

2. **Target:**
   - AWS service: FIS
   - Experiment template: Select your template
   - Role: Create new role with FIS permissions

**Option 2: Lambda-Triggered Chaos**

Create a Lambda function to run experiments based on custom logic:

```python
import boto3
import json

fis = boto3.client('fis')

def lambda_handler(event, context):
    """
    Trigger FIS experiment when deployment completes
    """
    # Get experiment template ID from environment
    experiment_template_id = 'EXT...'
    
    # Start experiment
    response = fis.start_experiment(
        experimentTemplateId=experiment_template_id,
        tags={'Source': 'AutomatedChaos', 'Trigger': 'PostDeployment'}
    )
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'experimentId': response['experiment']['id'],
            'status': 'Started'
        })
    }
```

**Deploy this Lambda:**

- Trigger: SNS topic or CodePipeline event
- Permissions: FIS start experiment
- Environment vars: Experiment template ID

---

### Step 9: Chaos Testing Metrics & Analysis

**Build a chaos engineering dashboard:**

1. **CloudWatch dashboard widgets:**
   - Experiment count (by status)
   - Blast radius (% instances affected)
   - Mean time to detection (MTTD)
   - Mean time to recovery (MTTR)

2. **Custom metrics to track:**

   ```python
   # Pseudo-code for chaos metrics
   chaos_experiments_run = Counter()
   chaos_stop_conditions_triggered = Counter()
   chaos_mttr = Histogram()
   
   # After each experiment:
   cloudwatch.put_metric_data(
       Namespace='ChaosEngineering',
       MetricData=[
           {
               'MetricName': 'ExperimentsRun',
               'Value': 1,
               'Unit': 'Count'
           },
           {
               'MetricName': 'MTTR',
               'Value': recovery_time_seconds,
               'Unit': 'Seconds'
           }
       ]
   )
   ```

3. **Analyze trends:**
   - Are experiments passing more consistently?
   - Is MTTR decreasing over time?
   - Which failure types cause the most impact?

---

## Part 6: Advanced Challenges

### Challenge 1: Database Chaos

**Objective:** Test application behavior when database becomes slow/unavailable.

**Setup RDS:**

1. Add RDS PostgreSQL to your CloudFormation (Multi-AZ)
2. Modify application to connect to database
3. Add database health endpoint

**Chaos experiments:**

- Inject network latency between instances and RDS
- Force RDS failover (promote read replica)
- Stress database with connection saturation

**Tools needed:**

- FIS action: `aws:rds:reboot-db-instances`
- Custom SSM document for connection stress

### Challenge 2: Multi-Region Chaos

**Objective:** Test failover between regions.

**Setup:**

- Deploy infrastructure in us-east-1 and us-west-2
- Configure Route 53 health checks
- Set up cross-region replication

**Chaos experiments:**

- Simulate entire region failure
- Test Route 53 failover time
- Verify data consistency

### Challenge 3: Advanced Observability

**Objective:** Correlate chaos events with business metrics.

**Setup:**

- Instrument application with AWS X-Ray
- Add custom business metrics (purchases, signups)
- Create correlation dashboard

**Analysis:**

- How does 200ms latency affect conversion rates?
- What's the relationship between p99 latency and revenue?
- Build SLO models with chaos data

### Challenge 4: Budget-Based Stop Conditions

**Objective:** Stop experiments if costs spike.

**Setup:**

- Monitor AWS Budgets API
- Create Lambda to check spend
- Add custom stop condition to FIS

**Implementation:**

```python
def check_budget_stop_condition():
    budgets = boto3.client('budgets')
    response = budgets.describe_budget(
        AccountId=account_id,
        BudgetName='ChaosExperimentBudget'
    )
    actual_spend = response['Budget']['CalculatedSpend']['ActualSpend']['Amount']
    if float(actual_spend) > threshold:
        return True  # Stop experiment
    return False
```

---

## Part 7: Cleanup

**Delete resources in order:**

1. **Stop all running FIS experiments**
   - FIS → Experiments → Stop any running

2. **Delete FIS experiment templates**
   - FIS → Experiment templates → Delete all

3. **Delete CloudFormation stack**
   - CloudFormation → Stacks → Lab11-Chaos-Infrastructure → Delete
   - This removes all infrastructure

4. **Delete CloudWatch dashboards** (if created)

5. **Remove EventBridge rules** (if created)

6. **Delete Lambda functions** (if created)

---

## Key Takeaways

✅ **Chaos engineering is essential** for building confidence in distributed systems

✅ **AWS FIS provides safety** through stop conditions and IAM controls

✅ **Start small** and gradually increase blast radius

✅ **Automate chaos testing** to catch regressions early

✅ **GameDays build muscle memory** for incident response

✅ **Observability is critical** - you can't chaos test what you can't measure

✅ **Hypothesis-driven experiments** provide structured learning

✅ **Continuous chaos** is better than one-time testing

---

## Real-World Applications

**E-commerce Platform:**

- Weekly GameDays before major sale events
- Automated chaos in staging before production deploys
- Verify 99.99% SLO under failures

**Financial Services:**

- Simulate network partitions between services
- Test circuit breaker effectiveness
- Verify disaster recovery procedures

**SaaS Application:**

- Continuous chaos in production (1% traffic)
- Test multi-tenant isolation
- Verify customer impact is minimal

---

## Further Learning

- [Principles of Chaos Engineering](https://principlesofchaos.org/)
- [AWS FIS Documentation](https://docs.aws.amazon.com/fis/)
- [Chaos Engineering Book by Casey Rosenthal](https://www.oreilly.com/library/view/chaos-engineering/9781491988459/)
- [Netflix Chaos Engineering Blog](https://netflixtechblog.com/tagged/chaos-engineering)
- [Google SRE Book - Testing for Reliability](https://sre.google/sre-book/testing-reliability/)

**Congratulations!** You've completed advanced chaos engineering training. You now have the skills to design, execute, and automate chaos experiments that build truly resilient systems.

---

*End of Lab 11*
