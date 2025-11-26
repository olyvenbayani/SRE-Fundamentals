# Lab 4: Setting Up a CloudWatch Alarm and Alert System with EC2

Welcome to AWS Lab 4 of the SRE Workshop! This hands-on activity introduces you to monitoring Amazon EC2 instances using Amazon CloudWatch. You'll launch a simple EC2 instance, set up alarms for key metrics (like high CPU usage), and configure alerts to notify you via email or SMS when something goes wrong. We'll keep it personalized by using "lab4-{workshoper name}" in resource names (replace {workshoper name} with your actual name, e.g., "lab4-john-server" if your name is John). Optionally, run a sample app on the instance, but the focus is on beginner-friendly monitoring and alerting.

This guide is designed for absolute beginners with an AWS Free Tier account. Each step includes why we're doing it, screenshots aren't possible here but I'll describe where to click, and troubleshooting tips. We'll use the AWS Management Console for simplicity—no coding required unless you add the optional app.

**Time Estimate:** 45-60 minutes (plus 10-15 for optional app setup).  
**Goals:**  
- Launch an EC2 instance and understand basic monitoring.  
- Create CloudWatch alarms to detect issues (e.g., high CPU).  
- Set up notifications (alerts) via email or SMS.  
- Enable AWS Systems Manager for secure, SSH-less access to your instance.  
- Simulate an issue to trigger an alert and see it in action.  
- Clean up to avoid costs.

**Prerequisites:**  
- AWS account (free tier eligible—sign up at aws.amazon.com if needed).  
- Basic familiarity with AWS Console (from previous labs or tutorials).  
- Email address for notifications (and phone number if you want SMS).  
- Optional: SSH client (like Terminal on macOS/Linux, PuTTY on Windows) if adding the app.

**Important Notes:**  
- Costs: EC2 t2.micro is free tier (750 hours/month), but stop/delete after lab to avoid charges (~$0.01/hour if running).  
- Regions: Use us-east-1 for simplicity, but any works.
- Personalization: Throughout this lab, replace "{workshoper name}" with your name (e.g., "john" for John) to make resource names unique.

## Step 1: Launch an EC2 Instance
**Why?** EC2 is a virtual server in AWS. We'll launch one to monitor—think of it as your personalized "lab4-{workshoper name}-server" if we add an app.

1. Log in to AWS Console (console.aws.amazon.com) > Search for "EC2" > EC2 Dashboard > Launch instance.  
2. Name: `lab4-{workshoper name}-server`.  
3. Application and OS Images: Amazon Linux 2023 AMI (free tier eligible).  
4. Instance type: t2.micro (free tier).  
5. Key pair: Create new (name: `lab4-{workshoper name}-key`)—download the .pem file (for SSH later, if needed).  
6. Network settings: Allow SSH from "My IP" (secure), and HTTP/HTTPS from anywhere (for app access if added).  
7. Storage: Default 8 GiB gp3.  
8. Launch instance. Wait 2-3 minutes for "Running" status.  
9. Note the Public IPv4 address (e.g., 3.123.45.67)—you'll use it for access.
10. Also note the Instance ID (e.g., i-0123456789abcdef0)—used later.

**Troubleshooting:**  
- If launch fails: Check free tier limits or quotas (Services > Quotas > EC2).  
- No public IP? Edit VPC/subnet to enable auto-assign public IP.

**Optional: Install a Sample App on EC2**  
- SSH in: `ssh -i "lab4-{workshoper name}-key.pem" ec2-user@<public-ip>` (chmod 400 lab4-{workshoper name}-key.pem first).  
- Install Python/Flask: `sudo yum update -y && sudo yum install python3 -y && pip3 install flask`.  
- Create a simple app.py: Use a basic Flask app or paste from previous labs.  
- Run: `python3 app.py` (access at http://<public-ip>:3000/success). For production, use screen/nohup.

## Step 2: Enable AWS Systems Manager Access
**Why?** AWS Systems Manager (SSM) lets you securely manage your EC2 instance without SSH keys—e.g., use Session Manager for browser-based shell access. It's safer and easier for troubleshooting. We'll enable it now so you can access the instance SSH-less if needed.

1. Create an IAM Role for SSM:  
   - Console > IAM > Roles > Create role.  
   - Trusted entity: AWS service > EC2.  
   - Permissions: Search and attach "AmazonSSMManagedInstanceCore" (this allows SSM access).  
   - Name: `ssm-lab4-{workshoper name}-role`. Note the role name.

2. Attach the Role to Your EC2 Instance:  
   - Console > EC2 > Instances > Select `lab4-{workshoper name}-server` > Actions > Security > Modify IAM role.  
   - Choose `ssm-lab4-{workshoper name}-role` > Update IAM role.  
   - Wait 1-2 minutes for the change to apply.

3. Verify SSM Access:  
   - Console > Systems Manager > Fleet Manager > Your instance should appear (refresh if not).  
   - To test: Systems Manager > Session Manager > Start session > Select your instance > Start.  
     - This opens a browser-based terminal—no SSH needed!

**Explanation:** SSM Agent is pre-installed on Amazon Linux 2023, so attaching the role enables it. Use Session Manager for secure access (logs all sessions).

**Troubleshooting:**  
- Instance not in Fleet Manager? Wait 5-10 minutes or check IAM role attachment. Ensure instance has internet access (public subnet or NAT).  
- Permission errors? Add "AmazonSSMFullAccess" to the role if needed (but Core is usually enough).  
- No Session Manager? Ensure your AWS region supports it (most do).

## Step 3: Explore CloudWatch Monitoring for EC2
**Why?** CloudWatch automatically collects metrics from EC2 (e.g., CPU, network)—no setup needed!

1. Console > CloudWatch > Metrics > All metrics > EC2 > Per-Instance Metrics.  
2. Select your instance (by ID or name tag).  
3. View graphs: E.g., CPUUtilization (percentage used). Refresh after a few minutes.  

**Explanation:** Metrics update every 5 minutes (basic) or 1 minute (detailed—enable for $0.01/metric/month). Logs are in CloudWatch Logs if you added the app.

**Troubleshooting:** No metrics? Wait 5-10 minutes after launch. Enable detailed monitoring in EC2 > Instance settings > Monitoring.

## Step 4: Create a CloudWatch Alarm
**Why?** Alarms watch metrics and trigger actions (like notifications) when thresholds are breached—e.g., alert if CPU > 70%.

1. Console > CloudWatch > Alarms > Create alarm.  
2. Select metric: Search "CPUUtilization" > EC2 > Per-Instance > Your instance.  
3. Statistic: Average, Period: 1 minute (enable detailed if needed).  
4. Conditions: Static > Greater > 70 (for high CPU).  
5. Additional: Treat missing data as "missing" (default).  
6. Actions: In alarm > Create new SNS topic (next step). Name alarm: `HighCPU-lab4-{workshoper name}-server`.  
7. Create.

**Explanation:** Alarm states: OK (normal), ALARM (breached), INSUFFICIENT_DATA (not enough info).

## Step 5: Set Up Alerts (Notifications)
**Why?** Alarms alone don't notify—use Amazon SNS (Simple Notification Service) for email/SMS.

1. In alarm creation (or SNS Console > Topics > Create topic): Standard type, Name: `lab4-{workshoper name}-alerts`.  
2. Create subscription: Protocol: Email, Endpoint: your-email@example.com. Confirm via email link.  
   - For SMS: Protocol: SMS, Endpoint: +1yourphonenumber (international format).  
   - For Slack: Use Application integration (webhook URL as HTTP endpoint).  
3. Back in alarm: Add notification > Alarm state trigger: In alarm > Send to SNS topic `lab4-{workshoper name}-alerts`.  
4. Finish alarm.

**Explanation:** SNS sends messages when alarm triggers. Test by subscribing and publishing a test message in SNS.

**Troubleshooting:** No confirmation email? Check spam. SMS not working? Verify phone in SNS > Mobile > Text messaging.

## Step 6: Simulate an Issue and Test the Alert
**Why?** See the system in action—generate load to trigger the alarm.

1. Access the instance via Session Manager (from Step 2): Start a session > Run commands.  
2. Install stress: `sudo yum install stress -y`.  
3. Run: `stress --cpu 2 --timeout 300` (high CPU for 5 minutes).  
4. Monitor: CloudWatch Metrics—watch CPU spike >70%.  
5. Wait 1-2 minutes: Alarm goes to ALARM state.  
6. Check email/SMS: Receive notification like "ALARM: HighCPU-lab4-{workshoper name}-server".  
7. Resolve: The stress stops automatically. CPU drops—alarm back to OK, optional resolved notification.

**Explanation:** This simulates a real issue (e.g., app overload). For a sample app, high traffic could trigger it. Using Session Manager keeps it secure.

**Troubleshooting:** No trigger? Ensure detailed monitoring enabled. No notification? Check SNS subscriptions status (Confirmed?).

## Step 7: Cleanup to Avoid Costs
**Why?** Free tier has limits—delete resources.

1. EC2 > Instances > Terminate `lab4-{workshoper name}-server`.  
2. CloudWatch > Alarms > Delete.  
3. SNS > Topics > Delete `lab4-{workshoper name}-alerts` (delete subscriptions first).  
4. IAM > Roles > Delete `ssm-lab4-{workshoper name}-role`.  
5. Delete key pair if not needed.

You've completed AWS Lab 4! You now know how to monitor EC2 with CloudWatch alarms, alerts, and secure access via Systems Manager. Reflect: How does SSM make management easier? (No keys, audited sessions.) Save as `aws-lab4-guide.md`. Ready for more?
