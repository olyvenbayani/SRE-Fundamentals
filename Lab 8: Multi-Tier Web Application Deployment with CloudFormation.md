# Lab 8: Multi-Tier Web Application Deployment with CloudFormation

Welcome to Lab 8! In this hands-on lab, you'll use AWS CloudFormation to build a **production-ready multi-tier web application** from scratch. 

This lab is designed for beginners but will challenge you to think critically about infrastructure design, CloudFormation best practices, and troubleshooting. You'll deploy everything as code, update your infrastructure, and experience the full power of Infrastructure as Code.

**Time Estimate:** 90-120 minutes  

**Goals:**

- Build a complete web application infrastructure using CloudFormation
- Implement auto-scaling groups with load balancing
- Create CloudWatch alarms and SNS notifications for monitoring
- Understand CloudFormation dependencies and resource relationships
- Practice updating and modifying infrastructure via stack updates
- Master Infrastructure as Code best practices

**Prerequisites:**

- AWS account (free tier eligible)
- Completion of Lab 4 or basic familiarity with EC2 and CloudWatch
- Understanding of basic networking concepts (VPC, subnets, security groups)
- Familiarity with YAML format from Lab 8 (recommended but not required)

**Important Notes:**

- **Costs:** Most resources are free tier eligible. Clean up thoroughly to avoid charges.
- **Region:** Use **us-east-1 (N. Virginia)** for consistency and availability.
- **Challenges ahead:** Some steps intentionally require problem-solving. Read error messages carefully!

---

## Architecture Overview

Before diving in, let's understand what you'll build:

```
┌─────────────────────────────────────────────────────────────┐
│                    Internet Gateway                          │
└────────────────────┬────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────────────┐
│                Application Load Balancer                     │
│              (Distributes traffic, health checks)            │
└────────┬───────────────────────────┬────────────────────────┘
         │                           │
    ┌────▼─────┐              ┌──────▼────┐
    │  EC2     │              │  EC2      │
    │Instance 1│              │Instance 2 │
    │(Web App) │              │(Web App)  │
    └──────────┘              └───────────┘
         │                           │
    Auto Scaling Group (Min: 2, Max: 4)
    - Automatically replaces unhealthy instances
    - Scales based on CPU utilization
         │
    ┌────▼──────────────────────────────┐
    │      CloudWatch Alarms             │
    │  - High CPU Alert                  │
    │  - Unhealthy Target Alert          │
    └────┬──────────────────────────────┘
         │
    ┌────▼──────────────────────────────┐
    │      SNS Topic (Email Alerts)      │
    └────────────────────────────────────┘
```

**What makes it "self-healing"?**

1. **Auto Scaling Group:** Automatically replaces failed instances
2. **Health Checks:** Load balancer detects and stops routing to unhealthy instances
3. **CloudWatch Alarms:** Alerts you when issues occur
4. **Multi-AZ Deployment:** Instances spread across availability zones for resilience

---

## Part 1: Understanding the CloudFormation Template

### Step 1: Create Your Working Directory

Let's organize our lab files properly.

1. **Create a new directory for this lab:**

   ```bash
   mkdir -p ~/lab8-cloudformation
   cd ~/lab8-cloudformation
   ```

2. **Verify you're in the right directory:**

   ```bash
   pwd
   # Should show: /Users/your-username/lab8-cloudformation
   ```

**Why?** Keeping files organized makes it easier to manage templates and troubleshoot.

---

### Step 2: Create the Base CloudFormation Template

We'll build the template in stages to help you understand each component.

**Create a file named `web-app-infrastructure.yaml`:**

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Lab 8 - Self-Healing Web Application with Auto Scaling, Load Balancer, and Monitoring'

Parameters:
  LatestAmiId:
    Type: AWS::SSM::Parameter::Value<AWS::EC2::Image::Id>
    Default: /aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2
    Description: Latest Amazon Linux 2 AMI ID (automatically retrieved)
  
  SshKeyName:
    Type: String
    Description: Name of an existing EC2 KeyPair for SSH access (leave empty if you don't need SSH)
    Default: ''
  
  YourEmail:
    Type: String
    Description: Email address for CloudWatch alarm notifications
    AllowedPattern: ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$
    ConstraintDescription: Must be a valid email address

Conditions:
  HasKeyName: !Not [!Equals [!Ref SshKeyName, '']]

Resources:
  # ============================================
  # NETWORKING RESOURCES
  # ============================================
  
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.0.0.0/16
      EnableDnsHostnames: true
      EnableDnsSupport: true
      Tags:
        - Key: Name
          Value: Lab8-VPC
  
  InternetGateway:
    Type: AWS::EC2::InternetGateway
    Properties:
      Tags:
        - Key: Name
          Value: Lab8-IGW
  
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
          Value: Lab8-PublicSubnet1
  
  PublicSubnet2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.2.0/24
      AvailabilityZone: !Select [1, !GetAZs '']
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: Lab8-PublicSubnet2
  
  PublicRouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: Lab8-PublicRouteTable
  
  PublicRoute:
    Type: AWS::EC2::Route
    DependsOn: AttachGateway
    Properties:
      RouteTableId: !Ref PublicRouteTable
      DestinationCidrBlock: 0.0.0.0/0
      GatewayId: !Ref InternetGateway
  
  SubnetRouteTableAssociation1:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnet1
      RouteTableId: !Ref PublicRouteTable
  
  SubnetRouteTableAssociation2:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnet2
      RouteTableId: !Ref PublicRouteTable
  
  # ============================================
  # SECURITY GROUPS
  # ============================================
  
  LoadBalancerSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Security group for Application Load Balancer
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          CidrIp: 0.0.0.0/0
          Description: Allow HTTP from anywhere
      SecurityGroupEgress:
        - IpProtocol: -1
          CidrIp: 0.0.0.0/0
          Description: Allow all outbound traffic
      Tags:
        - Key: Name
          Value: Lab8-ALB-SG
  
  WebServerSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Security group for web server instances
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          SourceSecurityGroupId: !Ref LoadBalancerSecurityGroup
          Description: Allow HTTP from Load Balancer only
      SecurityGroupEgress:
        - IpProtocol: -1
          CidrIp: 0.0.0.0/0
          Description: Allow all outbound traffic
      Tags:
        - Key: Name
          Value: Lab8-WebServer-SG
  
  # Add SSH access if KeyName is provided
  WebServerSSHIngress:
    Type: AWS::EC2::SecurityGroupIngress
    Condition: HasKeyName
    Properties:
      GroupId: !Ref WebServerSecurityGroup
      IpProtocol: tcp
      FromPort: 22
      ToPort: 22
      CidrIp: 0.0.0.0/0
      Description: Allow SSH from anywhere (for troubleshooting only)
  
  # ============================================
  # LOAD BALANCER
  # ============================================
  
  ApplicationLoadBalancer:
    Type: AWS::ElasticLoadBalancingV2::LoadBalancer
    DependsOn: AttachGateway
    Properties:
      Name: Lab8-ALB
      Scheme: internet-facing
      Type: application
      IpAddressType: ipv4
      Subnets:
        - !Ref PublicSubnet1
        - !Ref PublicSubnet2
      SecurityGroups:
        - !Ref LoadBalancerSecurityGroup
      Tags:
        - Key: Name
          Value: Lab8-ALB
  
  ALBTargetGroup:
    Type: AWS::ElasticLoadBalancingV2::TargetGroup
    Properties:
      Name: Lab8-TG
      Port: 80
      Protocol: HTTP
      VpcId: !Ref VPC
      HealthCheckEnabled: true
      HealthCheckPath: /
      HealthCheckProtocol: HTTP
      HealthCheckIntervalSeconds: 30
      HealthCheckTimeoutSeconds: 5
      HealthyThresholdCount: 2
      UnhealthyThresholdCount: 3
      TargetType: instance
      Tags:
        - Key: Name
          Value: Lab8-TargetGroup
  
  ALBListener:
    Type: AWS::ElasticLoadBalancingV2::Listener
    Properties:
      LoadBalancerArn: !Ref ApplicationLoadBalancer
      Port: 80
      Protocol: HTTP
      DefaultActions:
        - Type: forward
          TargetGroupArn: !Ref ALBTargetGroup
  
  # ============================================
  # AUTO SCALING
  # ============================================
  
  LaunchTemplate:
    Type: AWS::EC2::LaunchTemplate
    Properties:
      LaunchTemplateName: Lab8-WebServer-Template
      LaunchTemplateData:
        ImageId: !Ref LatestAmiId
        InstanceType: t2.micro
        KeyName: !If [HasKeyName, !Ref SshKeyName, !Ref 'AWS::NoValue']
        SecurityGroupIds:
          - !Ref WebServerSecurityGroup
        UserData:
          Fn::Base64: !Sub |
            #!/bin/bash
            # Update system
            yum update -y
            
            # Install Apache web server
            yum install -y httpd
            
            # Get instance metadata
            INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
            AZ=$(ec2-metadata --availability-zone | cut -d " " -f 2)
            
            # Create a colorful web page
            cat > /var/www/html/index.html <<'EOF'
            <!DOCTYPE html>
            <html>
            <head>
                <title>Lab 8 - Multi-Tier Application</title>
                <style>
                    body {
                        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                        color: white;
                        text-align: center;
                        padding: 50px;
                        margin: 0;
                    }
                    .container {
                        background: rgba(255, 255, 255, 0.1);
                        backdrop-filter: blur(10px);
                        border-radius: 20px;
                        padding: 40px;
                        max-width: 800px;
                        margin: 0 auto;
                        box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
                    }
                    h1 {
                        color: #FFD700;
                        font-size: 2.5em;
                        margin-bottom: 20px;
                    }
                    .status {
                        background: #28a745;
                        padding: 15px 30px;
                        border-radius: 10px;
                        display: inline-block;
                        margin: 20px 0;
                        font-size: 1.2em;
                        font-weight: bold;
                    }
                    .info-box {
                        background: rgba(255, 255, 255, 0.2);
                        border-radius: 10px;
                        padding: 20px;
                        margin: 20px 0;
                    }
                    .metric {
                        display: inline-block;
                        margin: 10px 20px;
                    }
                </style>
            </head>
            <body>
                <div class="container">
                    <h1>🚀 Multi-Tier Web Application</h1>
                    <div class="status">✅ Status: Healthy</div>
                    
                    <div class="info-box">
                        <h2>Instance Information</h2>
                        <div class="metric">
                            <strong>Instance ID:</strong><br>
                            <code>INSTANCE_ID_PLACEHOLDER</code>
                        </div>
                        <div class="metric">
                            <strong>Availability Zone:</strong><br>
                            <code>AZ_PLACEHOLDER</code>
                        </div>
                    </div>
                    
                    <div class="info-box">
                        <h2>Infrastructure as Code Principles</h2>
                        <p>✅ Automated deployment with CloudFormation</p>
                        <p>✅ Multi-AZ deployment for high availability</p>
                        <p>✅ Load balancing for traffic distribution</p>
                        <p>✅ Auto-scaling for elasticity</p>
                        <p>✅ Monitoring and alerting</p>
                        <p>✅ Repeatable and version-controlled infrastructure</p>
                    </div>
                    
                    <div class="info-box">
                        <h3>Load Balancer Test</h3>
                        <p>Refresh this page multiple times to see the load balancer<br>
                        distributing traffic across different instances!</p>
                        <p><small>Notice how the Instance ID changes as traffic is balanced.</small></p>
                    </div>
                </div>
            </body>
            </html>
            EOF
            
            # Replace placeholders with actual values
            sed -i "s/INSTANCE_ID_PLACEHOLDER/$INSTANCE_ID/g" /var/www/html/index.html
            sed -i "s/AZ_PLACEHOLDER/$AZ/g" /var/www/html/index.html
            
            # Start Apache
            systemctl start httpd
            systemctl enable httpd
        TagSpecifications:
          - ResourceType: instance
            Tags:
              - Key: Name
                Value: Lab8-WebServer
  
  AutoScalingGroup:
    Type: AWS::AutoScaling::AutoScalingGroup
    DependsOn: 
      - ALBTargetGroup
      - PublicSubnet1
      - PublicSubnet2
    Properties:
      AutoScalingGroupName: Lab8-ASG
      LaunchTemplate:
        LaunchTemplateId: !Ref LaunchTemplate
        Version: !GetAtt LaunchTemplate.LatestVersionNumber
      MinSize: 2
      MaxSize: 4
      DesiredCapacity: 2
      HealthCheckType: ELB
      HealthCheckGracePeriod: 300
      VPCZoneIdentifier:
        - !Ref PublicSubnet1
        - !Ref PublicSubnet2
      TargetGroupARNs:
        - !Ref ALBTargetGroup
      Tags:
        - Key: Name
          Value: Lab8-ASG-Instance
          PropagateAtLaunch: true
  
  # ============================================
  # SCALING POLICIES
  # ============================================
  
  ScaleUpPolicy:
    Type: AWS::AutoScaling::ScalingPolicy
    Properties:
      AutoScalingGroupName: !Ref AutoScalingGroup
      PolicyType: TargetTrackingScaling
      TargetTrackingConfiguration:
        PredefinedMetricSpecification:
          PredefinedMetricType: ASGAverageCPUUtilization
        TargetValue: 50.0
  
  # ============================================
  # MONITORING AND ALERTS
  # ============================================
  
  SNSTopic:
    Type: AWS::SNS::Topic
    Properties:
      TopicName: Lab8-Alerts
      DisplayName: Lab 8 CloudWatch Alarms
      Subscription:
        - Endpoint: !Ref YourEmail
          Protocol: email
  
  HighCPUAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: Lab8-HighCPU
      AlarmDescription: Triggers when average CPU utilization exceeds 70%
      MetricName: CPUUtilization
      Namespace: AWS/EC2
      Statistic: Average
      Period: 300
      EvaluationPeriods: 2
      Threshold: 70
      ComparisonOperator: GreaterThanThreshold
      Dimensions:
        - Name: AutoScalingGroupName
          Value: !Ref AutoScalingGroup
      AlarmActions:
        - !Ref SNSTopic
      TreatMissingData: notBreaching
  
  UnhealthyHostAlarm:
    Type: AWS::CloudWatch::Alarm
    Properties:
      AlarmName: Lab8-UnhealthyHosts
      AlarmDescription: Triggers when there are unhealthy targets in the target group
      MetricName: UnHealthyHostCount
      Namespace: AWS/ApplicationELB
      Statistic: Average
      Period: 60
      EvaluationPeriods: 2
      Threshold: 1
      ComparisonOperator: GreaterThanOrEqualToThreshold
      Dimensions:
        - Name: TargetGroup
          Value: !GetAtt ALBTargetGroup.TargetGroupFullName
        - Name: LoadBalancer
          Value: !GetAtt ApplicationLoadBalancer.LoadBalancerFullName
      AlarmActions:
        - !Ref SNSTopic
      TreatMissingData: notBreaching

Outputs:
  LoadBalancerURL:
    Description: URL of the Application Load Balancer
    Value: !Sub 'http://${ApplicationLoadBalancer.DNSName}'
    Export:
      Name: !Sub '${AWS::StackName}-ALB-URL'
  
  VPCId:
    Description: VPC ID
    Value: !Ref VPC
  
  AutoScalingGroupName:
    Description: Name of the Auto Scaling Group
    Value: !Ref AutoScalingGroup
  
  SNSTopicArn:
    Description: ARN of the SNS Topic for alerts
    Value: !Ref SNSTopic
```

**Save this file as `web-app-infrastructure.yaml`**

---

### Step 3: Understand the Template Structure

Before deploying, let's break down what this template does. Understanding the structure is crucial for troubleshooting later!

**Template Sections Explained:**

1. **Parameters:**
   - `LatestAmiId`: Automatically gets the latest Amazon Linux 2 AMI (no hardcoding!)
   - `SshKeyName`: Optional SSH key for troubleshooting
   - `YourEmail`: Where CloudWatch alarms will be sent

2. **Networking (VPC, Subnets, IGW):**
   - Creates a new VPC with two public subnets in different availability zones
   - Internet Gateway for internet access
   - Route tables to direct traffic

3. **Security Groups:**
   - `LoadBalancerSecurityGroup`: Allows HTTP (port 80) from internet
   - `WebServerSecurityGroup`: Allows HTTP only from load balancer (security best practice!)

4. **Load Balancer:**
   - `ApplicationLoadBalancer`: Distributes traffic across instances
   - `ALBTargetGroup`: Defines health check configuration
   - `ALBListener`: Listens on port 80 and forwards to target group

5. **Auto Scaling:**
   - `LaunchTemplate`: Defines instance configuration and startup script (UserData)
   - `AutoScalingGroup`: Maintains 2-4 instances across AZs, with ELB health checks

6. **Scaling Policy:**
   - `ScaleUpPolicy`: Automatically adds instances when CPU > 50%

7. **Monitoring:**
   - `SNSTopic`: Email notifications
   - `HighCPUAlarm`: Alerts on high CPU usage
   - `UnhealthyHostAlarm`: Alerts when instances fail health checks

**Key CloudFormation Features Demonstrated:**

- **Intrinsic Functions:**
  - `!Ref`: References other resources
  - `!GetAtt`: Gets attributes from resources
  - `!Sub`: String substitution
  - `!Select` and `!GetAZs`: Dynamically select availability zones
- **DependsOn**: Ensures resources are created in correct order
- **Conditions**: Conditional resource creation (SSH access only if key provided)

---

## Part 2: Deploying the Infrastructure

### Step 4: Create SSH Key Pair (Optional but Recommended)

Having SSH access will help you troubleshoot if needed.

1. **AWS Console → EC2 → Key Pairs → Create key pair**
2. **Settings:**
   - Name: `lab8-key`
   - Key pair type: RSA
   - Private key file format: .pem
3. **Create key pair** (file will download automatically)
4. **Save the file securely** in your lab directory

**On Mac/Linux, set proper permissions:**

```bash
chmod 400 ~/lab8-cloudformation/lab8-key.pem
```

**Why Optional?** The lab works without SSH, but having access helps verify instance configuration and troubleshoot issues.

---

### Step 5: Deploy the CloudFormation Stack

Time to launch your infrastructure!

1. **AWS Console → CloudFormation → Create stack → With new resources**

2. **Prepare template:**
   - Template source: **Upload a template file**
   - Click **Choose file** → Select `web-app-infrastructure.yaml`
   - Click **Next**

3. **Specify stack details:**
   - **Stack name:** `Lab8-SelfHealing-App`
   - **Parameters:**
     - LatestAmiId: Leave default (auto-populates latest Amazon Linux 2 AMI)
     - SshKeyName: `lab8-key` (or leave empty if you didn't create one)
     - YourEmail: `your-actual-email@example.com` (you'll receive confirmation)
   - Click **Next**

4. **Configure stack options:**
   - **Tags** (optional but good practice):
     - Key: `Lab`, Value: `Lab8`
     - Key: `Purpose`, Value: `SRE-Training`
   - Leave other settings as default
   - Click **Next**

5. **Review:**
   - Scroll through and verify parameters
   - **Acknowledge:** Check "I acknowledge that AWS CloudFormation might create IAM resources"
   - Click **Submit**

6. **Watch Stack Creation:**
   - **Events** tab: Shows real-time progress
   - **Resources** tab: Shows resources being created
   - **Expected time:** 5-8 minutes

**What's Happening Behind the Scenes?**

- CloudFormation creates resources in dependency order
- VPC and networking first, then security groups, then load balancer, then instances
- UserData scripts run on each EC2 instance to install Apache and create the web page

---

### Step 6: Confirm SNS Email Subscription

**IMPORTANT:** You must confirm your email subscription to receive alerts!

1. **Check your email** (within 2-3 minutes of stack creation)
2. **Look for:** "AWS Notification - Subscription Confirmation"
3. **Click:** "Confirm subscription" link
4. **Verify:** You should see a confirmation page in your browser

**Troubleshooting:**

- Email not received? Check spam folder
- Wrong email? Update stack with correct email and redeploy
- Didn't confirm? You won't receive CloudWatch alarm notifications

---

### Step 7: Verify Stack Creation

Let's make sure everything deployed successfully!

1. **CloudFormation Console:**
   - Stack status should show: **CREATE_COMPLETE** (green)
   - If **ROLLBACK_COMPLETE** (red), there was an error—skip to Step 15 for troubleshooting

2. **Check Outputs:**
   - Click **Outputs** tab
   - Copy the **LoadBalancerURL** value
   - Should look like: `http://lab8-alb-1234567890.us-east-1.elb.amazonaws.com`

3. **Open Application:**
   - Paste LoadBalancerURL into browser
   - **You should see:** A purple gradient page with "Self-Healing Web Application"
   - **Note the Instance ID and Availability Zone displayed**

4. **Refresh Multiple Times:**
   - Refresh the page 5-10 times
   - **Observation:** The Instance ID should alternate between two instances
   - **Why?** The load balancer distributes traffic across both instances

**If page doesn't load:**

- Wait 2-3 more minutes (instances may still be initializing)
- Wait 2-3 more minutes (instances may still be initializing)
- Check Security Group rules (Step 15)
- Verify Auto Scaling Group has 2 running instances (EC2 Console)

---

## Part 3: Understanding and Testing Your Infrastructure

### Step 8: Monitor Your Infrastructure

Let's explore the AWS Console to see all the resources CloudFormation created for you.

**Open these AWS Console pages in separate browser tabs:**

1. **CloudFormation → Stacks → Lab8-Multi-Tier-App**
    - Click **Resources** tab (see all 30+ resources created)
    - Click **Events** tab (see creation timeline)

2. **EC2 → Auto Scaling Groups → Lab8-ASG**
    - Click **Activity** tab (see scaling activities)
    - Click **Instance management** tab (see current instances)

3. **EC2 → Target Groups → Lab8-TG**
    - Click **Targets** tab (see health status of instances)

4. **CloudWatch → Alarms**
    - See your two alarms: `Lab8-HighCPU` and `Lab8-UnhealthyHosts`

5. **Your application URL** (from CloudFormation Outputs)
    - Keep this tab open to test the application

**Expected State:**

- Auto Scaling Group: 2 instances running, "Healthy" status
- Target Group: 2 targets, both "healthy"
- CloudWatch Alarms: Both in "OK" state (green)

---

### Step 9: Test Load Balancer Distribution

Now let's observe how the Application Load Balancer distributes traffic across multiple instances.

**1. Verify Load Balancing:**

- Open your application URL in a browser
- **Note the Instance ID** shown on the page (e.g., `i-0abc123def456`)
- **Refresh the page 10-15 times**
- **Observation:** The Instance ID should alternate between two different instances
- **This demonstrates:** The load balancer is distributing traffic using round-robin across healthy targets

**2. Understand What CloudFormation Created:**

Navigate to **CloudFormation → Stacks → Lab8-Multi-Tier-App → Resources tab**

**Find these key resources and understand their relationships:**

| Resource | Logical ID | Type | Purpose |
|----------|------------|------|---------|
| VPC | VPC | AWS::EC2::VPC | Isolated network for your application |
| Load Balancer | ApplicationLoadBalancer | AWS::ElasticLoadBalancingV2::LoadBalancer | Distributes traffic |
| Target Group | ALBTargetGroup | AWS::ElasticLoadBalancingV2::TargetGroup | Manages instance health checks |
| Auto Scaling Group | AutoScalingGroup | AWS::AutoScaling::AutoScalingGroup | Maintains desired instance count |
| Launch Template | LaunchTemplate | AWS::EC2::LaunchTemplate | Defines instance configuration |

**3. Explore the Template Designer:**

- CloudFormation → Stacks → Lab8-Multi-Tier-App → **Template** tab
- Click **View in Designer**
- **Observe:** Visual diagram showing resource dependencies
- **Notice:** Lines connecting resources show relationships (e.g., ASG depends on Target Group)

**Key IaC Insight:** All these resources and their dependencies were defined in YAML and created automatically in the correct order!

---

### Step 10: Test Auto-Scaling Based on Demand

Let's generate some CPU load and watch the Auto Scaling Group add instances.

**Challenge Mode:** I'll give you the concept—you figure out the implementation!

**Your Task:** Use SSH to connect to one of your instances and run a CPU stress test.

**Hints:**

1. Get instance public IP from EC2 Console
2. SSH using your key: `ssh -i lab8-key.pem ec2-user@<instance-public-ip>`
3. Install stress tool: `sudo yum install stress -y`
4. Run stress test: `stress --cpu 2 --timeout 300` (5 minutes)

**Alternative if no SSH key:**
Use EC2 Instance Connect (browser-based):

1. EC2 Console → Instances → Select instance → Connect
2. Choose "EC2 Instance Connect" → Connect
3. Run the stress commands above

**What to Watch:**

1. **CloudWatch Alarms:** `Lab8-HighCPU` should trigger within 5-10 minutes
2. **Auto Scaling Group:** Should launch additional instances (up to 4 total)
3. **Email:** You'll receive a high CPU alarm notification

**After 5 minutes:**

- Stress test ends automatically
- CPU drops back to normal
- After ~10 minutes, Auto Scaling Group scales back down to 2 instances

**Expected Behavior:**

- Normal state: 2 instances
- High CPU: Scales to 3-4 instances
- After load decreases: Scales back down to 2

---

### Step 11: Examine CloudFormation Template Features

Now that you've seen the infrastructure in action, let's understand HOW CloudFormation made this possible.

**CloudFormation Console → Stacks → Lab8-SelfHealing-App**

**Explore these features:**

1. **Template Tab:**
   - Click "View in Designer"
   - Visual representation of resource relationships
   - **Notice:** Lines show dependencies between resources

2. **Resources Tab:**
   - All 30+ resources created by the template
   - Click any resource → "View in console" to see it in its native AWS service

3. **Events Tab:**
   - Scroll to the bottom (earliest events)
   - **Notice the order:** VPC → Subnets → Internet Gateway → Security Groups → Load Balancer → Auto Scaling Group
   - CloudFormation automatically determined this order from dependencies!

4. **Parameters Tab:**
   - Shows the values you provided
   - These make the template reusable in different environments

5. **Outputs Tab:**
   - Application URL and other useful information
   - Can be referenced by other CloudFormation stacks

**Key Insight:** The template is both **documentation** and **automation**. Anyone can read it to understand the infrastructure, or deploy it to create an identical environment.

---

## Part 4: Troubleshooting Challenges

### Step 12: Intentional Challenge - Fix a Configuration Issue

**Scenario:** Your team wants to add HTTPS support (port 443) to the load balancer, but only HTTP (port 80) is currently allowed.

**Your Challenge:** Modify the CloudFormation template to allow HTTPS traffic.

**Requirements:**

1. Load Balancer Security Group should allow inbound traffic on port 443
2. Add a listener on the load balancer for port 443 (you can use a self-signed certificate or just configure the listener for now)

**Hints:**

- Look at the `LoadBalancerSecurityGroup` resource
- Add another `SecurityGroupIngress` rule
- (Optional advanced): Add an `ALBListener` resource for port 443

**Don't have an SSL certificate?** Just add the security group rule for now. The listener would require a certificate from AWS Certificate Manager.

**Steps to Update Stack:**

1. Edit your local `web-app-infrastructure.yaml` file
2. CloudFormation → Stacks → Lab8-SelfHealing-App → Update
3. Replace current template → Upload modified file
4. Next → Next → Update stack
5. Watch CloudFormation update only the changed resources!

**Solution (Security Group Rule Only):**

```yaml
LoadBalancerSecurityGroup:
  Type: AWS::EC2::SecurityGroup
  Properties:
    GroupDescription: Security group for Application Load Balancer
    VpcId: !Ref VPC
    SecurityGroupIngress:
      - IpProtocol: tcp
        FromPort: 80
        ToPort: 80
        CidrIp: 0.0.0.0/0
        Description: Allow HTTP from anywhere
      - IpProtocol: tcp
        FromPort: 443
        ToPort: 443
        CidrIp: 0.0.0.0/0
        Description: Allow HTTPS from anywhere
    SecurityGroupEgress:
      - IpProtocol: -1
        CidrIp: 0.0.0.0/0
        Description: Allow all outbound traffic
    Tags:
      - Key: Name
        Value: Lab8-ALB-SG
```

---

### Step 13: Troubleshooting Practice

**Scenario:** Suppose your application suddenly stops responding. Use these techniques to diagnose the issue.

**Debugging Checklist:**

1. **Check Load Balancer:**
   - EC2 → Load Balancers → Lab8-ALB
   - State should be "active"
   - Check listeners (should have port 80)

2. **Check Target Group Health:**
   - EC2 → Target Groups → Lab8-TG
   - Targets tab: Are instances healthy?
   - If unhealthy, click instance → Health status details → See reason

3. **Check Auto Scaling Group:**
   - EC2 → Auto Scaling Groups → Lab8-ASG
   - Activity history: Any failed launches?
   - Instance management: Are instances running?

4. **Check Security Groups:**
   - EC2 → Security Groups → Lab8-ALB-SG
   - Inbound rules: Port 80 from 0.0.0.0/0?
   - EC2 → Security Groups → Lab8-WebServer-SG
   - Inbound rules: Port 80 from ALB security group?

5. **Check VPC Networking:**
   - VPC → Route Tables → Lab8-PublicRouteTable
   - Routes: Should have 0.0.0.0/0 → Internet Gateway
   - VPC → Subnets: Both subnets should be associated with public route table

6. **Check Instance Logs (if you have SSH):**

   ```bash
   # Connect to instance
   ssh -i lab8-key.pem ec2-user@<instance-ip>
   
   # Check if Apache is running
   sudo systemctl status httpd
   
   # View Apache error logs
   sudo tail -f /var/log/httpd/error_log
   
   # Check if instance can reach internet
   ping -c 3 google.com
   ```

7. **Check CloudFormation Stack:**
   - CloudFormation → Stacks →Lab8-SelfHealing-App
   - Status: Should be CREATE_COMPLETE or UPDATE_COMPLETE
   - Events: Any failed resource updates?

**Common Issues and Fixes:**

| Issue | Likely Cause | Fix |
|-------|--------------|-----|
| 503 Service Unavailable | No healthy targets | Wait for instances to pass health checks, or check UserData script |
| Timeout loading page | Security group blocking traffic | Verify LoadBalancerSecurityGroup allows port 80 |
| Instances failing health checks | Application not running | SSH to instance, check `systemctl status httpd` |
| Stack creation failed | Invalid parameter or insufficient permissions | Check Events tab for specific error, fix template, recreate stack |
| Can't SSH to instance | Security group or no public IP | Add SSH rule to WebServerSecurityGroup, verify instance has public IP |

---

### Step 14: Advanced Challenge - Add a Custom CloudWatch Dashboard

**Challenge:** Create a CloudWatch Dashboard to visualize your application's health.

**Hint:** You can do this in the CloudFormation template or manually in the CloudWatch console.

**Manual Approach:**

1. CloudWatch → Dashboards → Create dashboard
2. Name: `Lab8-Dashboard`
3. Add widgets:
   - Line graph: EC2 CPUUtilization (by Auto Scaling Group)
   - Number widget: Healthy Host Count (from Target Group)
   - Number widget: Unhealthy Host Count (from Target Group)
   - Line graph: Request Count (from Load Balancer)

**CloudFormation Approach (Advanced):**
Add this resource to your template:

```yaml
CloudWatchDashboard:
  Type: AWS::CloudWatch::Dashboard
  Properties:
    DashboardName: Lab8-SelfHealing-Dashboard
    DashboardBody: !Sub |
      {
        "widgets": [
          {
            "type": "metric",
            "properties": {
              "metrics": [
                [ "AWS/EC2", "CPUUtilization", { "stat": "Average" } ]
              ],
              "period": 300,
              "stat": "Average",
              "region": "${AWS::Region}",
              "title": "CPU Utilization"
            }
          },
          {
            "type": "metric",
            "properties": {
              "metrics": [
                [ "AWS/ApplicationELB", "HealthyHostCount", { "stat": "Average" } ],
                [ ".", "UnHealthyHostCount", { "stat": "Average" } ]
              ],
              "period": 60,
              "stat": "Average",
              "region": "${AWS::Region}",
              "title": "Target Health"
            }
          }
        ]
      }
```

---

### Step 15: Common Errors and Solutions

**Error 1: Stack Creation Failed - "No default VPC available"**

- **Cause:** Your account might not have a default VPC
- **Solution:** The template creates its own VPC, so this shouldn't occur. If it does, check that you're in us-east-1 region.

**Error 2: "KeyName does not exist"**

- **Cause:** Specified SSH key doesn't exist in the region
- **Solution:** Create the key pair first (Step 4), or leave SshKeyName parameter empty

**Error 3: "Email address did not receive confirmation"**

- **Cause:** Email not sent or went to spam
- **Solution:** Check spam folder, or update stack with different email

**Error 4: "Application shows 503 error"**

- **Cause:** Instances not yet healthy, or UserData script failed
- **Solution:** Wait 5-7 minutes for instances to fully initialize. If persists, check EC2 instance logs.

**Error 5: Load balancer URL shows "Connection timed out"**

- **Cause:** Security group not allowing traffic on port 80
- **Solution:** Check `LoadBalancerSecurityGroup` ingress rules

**Error 6: Instances keep failing health checks**

- **Cause:** Apache not starting, or health check path incorrect
- **Solution:** SSH to instance, run `sudo systemctl status httpd`, check `/var/log/cloud-init-output.log`

**Error 7: "CREATE_FAILED - The following resource(s) failed to create: [AutoScalingGroup]"**

- **Cause:** Insufficient capacity in availability zones, or Launch Template invalid
- **Solution:** Check actual error message in Events tab. May need to change instance type or region.

**Error 8: Alarm not triggering during CPU stress test**

- **Cause:** Alarm threshold not reached, or alarm evaluation period not complete
- **Solution:** Increase stress duration, or check alarm configuration (threshold, period, evaluation periods)

**Debugging Process:**

1. Check CloudFormation Events tab for specific error
2. Google the exact error message (usually well-documented)
3. Verify all parameters are correct
4. Check AWS Service Quotas (Account might have limits)
5. Try deploying in a different region
6. Delete stack completely and recreate (if all else fails)

---

## Part 5: Infrastructure as Code Benefits

### Step 16: Exploring CloudFormation Stack Updates

One of the most powerful benefits of Infrastructure as Code is the ability to update your infrastructure reliably. Let's practice this.

**Challenge: Add Environment Tags to All Resources**

**Your Task:** Modify the CloudFormation template to add a common tag to all taggable resources.

**Steps:**

1. **Edit your `web-app-infrastructure.yaml` file:**
   - Add a new parameter at the top:

     ```yaml
     Environment:
       Type: String
       Description: Environment name (dev, staging, prod)
       Default: dev
       AllowedValues:
         - dev
         - staging
         - prod
     ```

2. **Add tags to your VPC resource:**

   ```yaml
   VPC:
     Type: AWS::EC2::VPC
     Properties:
       CidrBlock: 10.0.0.0/16
       EnableDnsHostnames: true
       EnableDnsSupport: true
       Tags:
         - Key: Name
           Value: Lab8-VPC
         - Key: Environment
           Value: !Ref Environment
   ```

3. **Update the Stack:**
   - CloudFormation → Stacks → Lab8-Multi-Tier-App → **Update**
   - **Replace current template** → Upload your modified file
   - Enter parameter value for Environment: `dev`
   - Next → Next → **Update stack**

4 **Watch CloudFormation Work:**

- **Events tab:** Shows "UPDATE_IN_PROGRESS"
- **Notice:** CloudFormation only modifies the VPC resource (adds tags)
- **No downtime:** Your application keeps running during the update!

**Key IaC Benefit:** Infrastructure changes are code changes—reviewable, testable, and safely deployable!

**What Just Happened?**

- CloudFormation detected only the VPC resource changed
- It applied the update without recreating other resources
- Your application remained available throughout
- The change is now version-controlled in your template

---

### Step 17: Understanding CloudFormation Stack Drift

**Scenario:** What if someone manually changes a resource outside of CloudFormation?

**This is called "drift"** —when actual infrastructure diverges from what's defined in your template.

**Try This Detection Exercise:**

1. **Manually modify a resource:**
   - EC2 → Load Balancers → Lab8-ALB
   - Actions → Edit attributes
   - Change "Idle timeout" from 60 to 120 seconds
   - Save changes

2. **Detect drift in CloudFormation:**
   - CloudFormation → Stacks → Lab8-Multi-Tier-App
   - **Stack actions** → **Detect drift**
   - Wait for detection to complete (~1 minute)
   - Click **View drift results**

3. **Examine the drift:**
   - Find the `ApplicationLoadBalancer` resource
   - Status shows: **MODIFIED**
   - Click to see specific property changes

**Why This Matters:**

- Manual changes break the "infrastructure as code" promise
- Drift detection helps you maintain a single source of truth
- Best practice: **Always make changes through CloudFormation**, not manually

**To Fix Drift:**

- Option 1: Update template to match reality (accept the manual change)
- Option 2: Re-run stack update to revert manual changes (enforce template)

---

### Step 18: Comparing Manual vs. IaC Deployment

**Thought Exercise:** Imagine deploying this infrastructure manually through the AWS Console.

**You would need to:**

1. Create VPC (5 minutes)
2. Create subnets in two AZs (5 minutes)
3. Create and attach Internet Gateway (3 minutes)
4. Configure route tables and associations (5 minutes)
5. Create two security groups with multiple rules (7 minutes)
6. Create Application Load Balancer (5 minutes)
7. Create Target Group with health check settings (5 minutes)
8. Create Listener (2 minutes)
9. Create Launch Template with UserData script (10 minutes)
10. Create Auto Scaling Group with complex settings (10 minutes)
11. Create SNS Topic and subscription (3 minutes)
12. Create two CloudWatch Alarms (8 minutes)
13. Test and troubleshoot (20+ minutes)

**Total time:** ~90 minutes (assuming no mistakes!)

**With CloudFormation:**

- Write template once: 30-60 minutes
- Deploy: 5-8 minutes
- Redeploy in different account/region: 5-8 minutes
- Update configuration: 3-5 minutes

**Benefits of IaC for SRE:**

1. **Repeatability:** Deploy identical infrastructure every time
2. **Version Control:** Track all infrastructure changes in Git
3. **Documentation:** Template is self-documenting
4. **Testing:** Test infrastructure changes in dev before prod
5. **Disaster Recovery:** Recreate entire environment from template
6. **Consistency:** No configuration drift between environments
7. **Collaboration:** Team members can review infrastructure changes via pull requests

---

## Part 6: Cleanup

### Step 18: Delete All Resources

**IMPORTANT:** Clean up to avoid ongoing charges!

**Correct Cleanup Process:**

1. **Delete CloudFormation Stack:**
   - CloudFormation → Stacks → Lab8-Multi-Tier-App
   - Select stack → Delete
   - Confirm deletion
   - Wait for status: `DELETE_COMPLETE` (5-7 minutes)

2. **Verify Deletion:**
   - CloudFormation shows stack deleted
   - EC2 → Instances: All Lab8 instances should be "Terminated"
   - EC2 → Load Balancers: Lab8-ALB should be deleted
   - VPC → Your VPCs: Lab8-VPC should be deleted

3. **Manual Cleanup (if needed):**
   - Sometimes load balancer takes time to delete
   - If stack deletion fails, manually delete:
     - Load balancer → Wait 2 minutes
     - Try deleting stack again

**Why is deletion so easy?**
CloudFormation tracks all resources it created and deletes them in reverse dependency order. No manual cleanup needed!

**Compare with manual approach:**

- Would need to remember every resource created
- Delete in correct order (instances → load balancer → target group → subnets → VPC)
- Easy to forget resources (leading to unexpected charges)

---

## Part 7: Extending Your Knowledge

### Step 19: Optional Advanced Exercises

**Exercise 1: Multi-Region Deployment**

- Deploy the same stack in `us-west-2`
- Modify template to add a resource prefix parameter
- Compare deployment times

**Exercise 2: Add RDS Database**

- Research AWS::RDS::DBInstance resource
- Add a database to your template
- Update UserData to connect web app to database

**Exercise 3: Implement Blue/Green Deployment**

- Create two identical Auto Scaling Groups
- Use weighted target groups
- Shift traffic gradually from old to new version

**Exercise 4: Add Parameter Store Integration**

- Store configuration in AWS Systems Manager Parameter Store
- Retrieve values in UserData script
- Update configuration without redeploying instances

**Exercise 5: Implement Custom Metrics**

- Add CloudWatch Agent to instances
- Send custom application metrics
- Create alarms based on custom metrics

**Exercise 6: Add AWS WAF**

- Research AWS::WAFv2::WebACL
- Add web application firewall to protect load balancer
- Create rules to block suspicious traffic

---

## Conclusion and Key Takeaways

**Congratulations!** You've successfully:

- ✅ Deployed a complete multi-tier web application using CloudFormation
- ✅ Implemented auto-scaling and load balancing for reliability
- ✅ Configured health checks and monitoring
- ✅ Set up CloudWatch alarms and SNS notifications
- ✅ Updated infrastructure via stack updates
- ✅ Detected and understood infrastructure drift
- ✅ Experienced the full Infrastructure as Code lifecycle

**Infrastructure as Code Principles Demonstrated:**

1. **Declarative Configuration:** Defined desired state, not procedural steps
2. **Version Control:** Infrastructure templates can be committed to Git
3. **Repeatability:** Same template produces identical results every time
4. **Documentation:** Template IS the documentation of your infrastructure
5. **Testing:** Changes can be tested in dev/staging before production
6. **Automation:** Infrastructure deployment is fully automated
7. **Drift Detection:** Maintain single source of truth for infrastructure

**Key CloudFormation Concepts Learned:**

- **Parameters:** Make templates reusable across environments
- **Intrinsic Functions:** (!Ref, !GetAtt, !Sub, !Select, !GetAZs)
- **Resource Dependencies:** (DependsOn, implicit dependencies)
- **Conditions:** Conditional resource creation
- **Outputs:** Share information between stacks
- **Stack Updates:** Modify infrastructure reliably
- **Drift Detection:** Identify manual changes
- **Resource Deletion:** Clean up entire environments effortlessly

**Real-World Applications:**

This pattern is foundational for modern cloud operations:

- **Multi-environment management:** Same template for dev/staging/prod
- **Disaster recovery:** Recreate infrastructure from templates instantly
- **Compliance:** Version-controlled infrastructure meets audit requirements  
- **Collaboration:** Teams review infrastructure changes via pull requests
- **CI/CD Integration:** Automate infrastructure deployment in pipelines

**Benefits Over Manual Configuration:**

| Aspect | Manual | Infrastructure as Code |
|--------|--------|------------------------|
| Time to deploy | 60-90 minutes | 5-8 minutes |
| Reproducibility | Error-prone | Perfect |
| Documentation | Separate docs needed | Self-documenting |
| Change tracking | None | Full Git history |
| Multi-region | Repeat all steps | Same template |
| Team collaboration | Tribal knowledge | Code review process |
| Error detection | Runtime | Pre-deployment validation |

**Next Steps:**

1. Practice modifying the template (add features, change configurations)
2. Explore other CloudFormation resource types (RDS, ElastiCache, Lambda)
3. Learn AWS CDK (Cloud Development Kit) for writing IaC in programming languages
4. Study Terraform as an alternative IaC tool
5. Investigate GitOps workflows (ArgoCD, Flux) for automated deployments

**Resources for Further Learning:**

- [AWS CloudFormation Documentation](https://docs.aws.amazon.com/cloudformation/)
- [AWS CloudFormation Best Practices](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/best-practices.html)
- [CloudFormation Template Reference](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-reference.html)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- Google's SRE Book: [https://sre.google/books/](https://sre.google/books/)

---

## Appendix: Quick Reference

**Important AWS Console Locations:**

- CloudFormation: Services → CloudFormation
- EC2 Instances: Services → EC2 → Instances
- Load Balancers: Services → EC2 → Load Balancers
- Auto Scaling Groups: Services → EC2 → Auto Scaling Groups
- CloudWatch Alarms: Services → CloudWatch → Alarms
- SNS Topics: Services → Simple Notification Service → Topics

**Common CloudFormation Commands (AWS CLI):**

```bash
# Create stack
aws cloudformation create-stack \
  --stack-name Lab8-SelfHealing-App \
  --template-body file://web-app-infrastructure.yaml \
  --parameters ParameterKey=YourEmail,ParameterValue=your-email@example.com \
  --capabilities CAPABILITY_NAMED_IAM

# Update stack
aws cloudformation update-stack \
  --stack-name Lab8-SelfHealing-App \
  --template-body file://web-app-infrastructure.yaml \
  --parameters ParameterKey=YourEmail,ParameterValue=your-email@example.com \
  --capabilities CAPABILITY_NAMED_IAM

# Delete stack
aws cloudformation delete-stack --stack-name Lab8-SelfHealing-App

# Describe stack
aws cloudformation describe-stacks --stack-name Lab8-SelfHealing-App

# View stack events
aws cloudformation describe-stack-events --stack-name Lab8-SelfHealing-App
```

**Troubleshooting Checklist:**

- [ ] Stack status is CREATE_COMPLETE or UPDATE_COMPLETE
- [ ] All parameters are valid (email format, key name exists)
- [ ] SNS subscription confirmed (check email)
- [ ] Auto Scaling Group has 2 running instances
- [ ] Both instances are healthy in Target Group
- [ ] Load balancer is in "active" state
- [ ] Security groups allow required traffic
- [ ] Route table has internet gateway route
- [ ] Instances have public IPs (if in public subnet)
- [ ] UserData script completed successfully (check logs)

**Thank you for completing Lab 8!** You now have hands-on experience with one of the most powerful tools in modern cloud infrastructure management. Keep practicing, keep experimenting, and keep building!

---

*End of Lab 8*
