Welcome to Lab 10 of the SRE Workshop! This hands-on activity introduces you to designing reliable systems that can withstand failures. You'll learn about load balancing, redundancy, failover strategies, and get a gentle introduction to Chaos Engineering. We'll deploy a simple web application across multiple servers, then intentionally break things to see how resilience works in practice. Don't worry—this lab is designed to be easier and more fun than Lab 8!

This guide is designed for beginners. Each step includes clear explanations and troubleshooting tips. We'll use AWS Free Tier resources and focus on concepts over complexity.

**Time Estimate:** 60-75 minutes.  
**Goals:**  
- Understand the principles of designing for failure
- Deploy a multi-instance application with load balancing
- Implement redundancy across availability zones
- Experience failover in action
- Introduction to Chaos Engineering (breaking things on purpose!)
- Analyze and improve system reliability

**Prerequisites:**  
- AWS account (free tier eligible)
- Basic understanding of EC2 from previous labs
- Familiarity with Load Balancers (we'll explain as we go)
- Willingness to break things! 💥

**Important Notes:**  
- Costs: All resources are free tier eligible. Clean up after lab to avoid charges.
- Regions: Use us-east-1 for simplicity
- Fun factor: This lab involves intentionally breaking a working system—enjoy the chaos!

---

## Understanding Reliability Concepts

Before we start, let's understand key concepts:

### **Designing for Failure**
- Assume everything will fail eventually
- Build systems that continue working even when components fail
- "Hope is not a strategy" - plan for failures

### **Resilience Strategies**
- **Redundancy:** Multiple copies of components (if one fails, others continue)
- **Load Balancing:** Distribute traffic across multiple servers
- **Failover:** Automatic switching to backup when primary fails
- **Graceful Degradation:** System continues with reduced functionality

### **Chaos Engineering**
- Intentionally inject failures to test system resilience
- "Break things in production (on purpose) before they break on accident"
- Build confidence in system behavior during failures

---

## Part 1: Deploy a Baseline (Non-Resilient) System

### Step 1: Launch a Single EC2 Instance

**Why?** We'll start with a fragile, single-instance setup to understand what NOT to do.

1. **Navigate to EC2:**
   - AWS Console > EC2 > Launch instance

2. **Configure instance:**
   - Name: `lab9-single-instance`
   - AMI: Amazon Linux 2023
   - Instance type: t2.micro (free tier)
   - Key pair: Create new or use existing (`lab9-key`)
   - Network settings:
     - Create security group: `lab9-web-sg`
     - Allow SSH (port 22) from My IP
     - Allow HTTP (port 80) from Anywhere (0.0.0.0/0)
   - Advanced details > User data (paste this):
     ```bash
     #!/bin/bash
     yum update -y
     yum install -y httpd
     systemctl start httpd
     systemctl enable httpd
     
     # Create a simple webpage that shows instance info
     INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
     AVAILABILITY_ZONE=$(ec2-metadata --availability-zone | cut -d " " -f 2)
     
     cat > /var/www/html/index.html <<EOF
     <!DOCTYPE html>
     <html>
     <head>
         <title>Lab 9 - Reliability Test</title>
         <style>
             body { font-family: Arial; text-align: center; padding: 50px; background: #f0f0f0; }
             .container { background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); max-width: 600px; margin: 0 auto; }
             h1 { color: #FF9900; }
             .info { background: #232F3E; color: white; padding: 15px; border-radius: 5px; margin: 20px 0; }
             .status { color: #00AA00; font-weight: bold; }
         </style>
     </head>
     <body>
         <div class="container">
             <h1>🚀 Lab 9: Reliability Test Site</h1>
             <p class="status">✅ System is RUNNING</p>
             <div class="info">
                 <p><strong>Instance ID:</strong> $INSTANCE_ID</p>
                 <p><strong>Availability Zone:</strong> $AVAILABILITY_ZONE</p>
                 <p><strong>Architecture:</strong> Single Instance (NOT resilient)</p>
             </div>
             <p>This is a non-resilient deployment. If this instance fails, the entire site goes down!</p>
         </div>
     </body>
     </html>
     EOF
     ```

3. **Launch instance**
4. **Wait 2-3 minutes** for instance to be running

5. **Test the application:**
   - Copy the Public IPv4 address
   - Open in browser: `http://<public-ip>`
   - You should see the Lab 9 test site with instance details

**Explanation:** This user data script installs Apache web server and creates a webpage that displays which instance is serving the request. This helps us see load balancing and failover in action later.

**Troubleshooting:**  
- Can't access webpage? Check security group allows HTTP (port 80)
- Blank page? SSH into instance and check: `sudo systemctl status httpd`

---

### Step 2: Test the Fragility (Chaos Experiment #1)

**Why?** Experience how a single point of failure causes total outage.

1. **Keep the webpage open in your browser**
2. **In AWS Console > EC2 > Instances**
3. **Select `lab9-single-instance`**
4. **Instance state > Stop instance**
5. **Refresh the webpage in your browser**

**What happens?**  
❌ The site becomes completely unavailable  
❌ Users see "This site can't be reached"  
❌ 100% outage—no resilience!

**Document the observation:**
```
Chaos Experiment #1: Single Instance Failure
- Action: Stopped the only instance
- Result: Complete service outage
- Impact: 100% of users affected
- Recovery: Manual restart required
- Lesson: Single instance = single point of failure
```

6. **Restart the instance:** Instance state > Start instance
7. **Wait for it to be running again**

**Explanation:** This demonstrates why redundancy is critical. One failure = total outage.

---

## Part 2: Build a Resilient System with Load Balancing

### Step 3: Create a Launch Template

**Why?** A launch template defines instance configuration, making it easy to launch multiple identical instances.

1. **EC2 Console > Launch Templates > Create launch template**

2. **Configure template:**
   - Name: `lab9-web-server-template`
   - Description: `Template for resilient web servers`
   - Auto Scaling guidance: Check this box
   
3. **Application and OS Images:**
   - Amazon Linux 2023

4. **Instance type:**
   - t2.micro

5. **Key pair:**
   - Select your `lab9-key` (or existing key)

6. **Network settings:**
   - Security group: Select `lab9-web-sg` (created earlier)

7. **Advanced details > User data:**
   ```bash
   #!/bin/bash
   yum update -y
   yum install -y httpd
   systemctl start httpd
   systemctl enable httpd
   
   INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
   AVAILABILITY_ZONE=$(ec2-metadata --availability-zone | cut -d " " -f 2)
   
   cat > /var/www/html/index.html <<EOF
   <!DOCTYPE html>
   <html>
   <head>
       <title>Lab 9 - Resilient System</title>
       <style>
           body { font-family: Arial; text-align: center; padding: 50px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); }
           .container { background: white; padding: 30px; border-radius: 10px; box-shadow: 0 4px 20px rgba(0,0,0,0.2); max-width: 600px; margin: 0 auto; }
           h1 { color: #FF9900; }
           .info { background: #232F3E; color: white; padding: 15px; border-radius: 5px; margin: 20px 0; }
           .status { color: #00AA00; font-weight: bold; font-size: 1.2em; }
           .badge { display: inline-block; background: #FF9900; color: white; padding: 5px 15px; border-radius: 20px; margin: 5px; }
       </style>
   </head>
   <body>
       <div class="container">
           <h1>🛡️ Lab 9: Resilient System</h1>
           <p class="status">✅ System is RESILIENT</p>
           <div class="info">
               <p><strong>Serving Instance:</strong> $INSTANCE_ID</p>
               <p><strong>Availability Zone:</strong> $AVAILABILITY_ZONE</p>
               <p><strong>Architecture:</strong> Multi-AZ with Load Balancer</p>
           </div>
           <div>
               <span class="badge">Redundancy ✓</span>
               <span class="badge">Load Balanced ✓</span>
               <span class="badge">Auto-Healing ✓</span>
           </div>
           <p style="margin-top: 20px;">Even if this instance fails, others will serve your request!</p>
           <p><small>Refresh to see load balancing in action</small></p>
       </div>
   </body>
   </html>
   EOF
   
   # Add health check endpoint
   cat > /var/www/html/health <<EOF
   OK
   EOF
   ```

8. **Create launch template**

**Explanation:** The template ensures all instances are configured identically. The webpage now shows which specific instance is responding.

---

### Step 4: Create a Target Group

**Why?** Target groups define where the load balancer sends traffic and how it checks instance health.

1. **EC2 Console > Target Groups > Create target group**

2. **Configure:**
   - Target type: Instances
   - Target group name: `lab9-web-tg`
   - Protocol: HTTP
   - Port: 80
   - VPC: Select your default VPC
   - Protocol version: HTTP1

3. **Health checks:**
   - Health check protocol: HTTP
   - Health check path: `/health`
   - Advanced health check settings:
     - Healthy threshold: 2
     - Unhealthy threshold: 2
     - Timeout: 5 seconds
     - Interval: 10 seconds

4. **Next**

5. **Register targets:**
   - Don't register any yet (Auto Scaling will do this)
   - Click **Create target group**

**Explanation:** The `/health` endpoint lets the load balancer know if an instance is healthy. Unhealthy instances are automatically removed from rotation.

---

### Step 5: Create an Application Load Balancer

**Why?** The load balancer distributes traffic across multiple instances and routes around failures.

1. **EC2 Console > Load Balancers > Create load balancer**

2. **Select Application Load Balancer** (HTTP/HTTPS)

3. **Configure:**
   - Name: `lab9-web-alb`
   - Scheme: Internet-facing
   - IP address type: IPv4

4. **Network mapping:**
   - VPC: Your default VPC
   - Availability Zones: **Select at least 2 AZs** (e.g., us-east-1a and us-east-1b)
     - This is critical for resilience!

5. **Security groups:**
   - Create new security group or use `lab9-web-sg`
   - Ensure it allows HTTP (port 80) from anywhere

6. **Listeners and routing:**
   - Protocol: HTTP
   - Port: 80
   - Default action: Forward to `lab9-web-tg`

7. **Create load balancer**

8. **Wait 3-5 minutes** for state to be "Active"

9. **Copy the DNS name** (e.g., `lab9-web-alb-1234567890.us-east-1.elb.amazonaws.com`)

**Explanation:** The ALB is highly available across multiple AZs. Even if one AZ fails completely, the load balancer continues working.

**Troubleshooting:**  
- Load balancer stuck in "Provisioning"? Wait a few more minutes
- Can't create? Check you have at least 2 subnets in different AZs

---

### Step 6: Create an Auto Scaling Group

**Why?** Auto Scaling automatically maintains a desired number of healthy instances, replacing failed ones.

1. **EC2 Console > Auto Scaling Groups > Create Auto Scaling group**

2. **Choose launch template:**
   - Name: `lab9-web-asg`
   - Launch template: `lab9-web-server-template`
   - Next

3. **Network:**
   - VPC: Your default VPC
   - Availability Zones and subnets: Select **2 or more subnets in different AZs**
   - Next

4. **Load balancing:**
   - Attach to an existing load balancer
   - Choose from your load balancer target groups
   - Select `lab9-web-tg`
   - Health checks:
     - Turn on Elastic Load Balancing health checks
   - Next

5. **Group size:**
   - Desired capacity: **3**
   - Minimum capacity: **2**
   - Maximum capacity: **4**
   - Next

6. **Scaling policies:**
   - None (for this simple lab)
   - Next

7. **Notifications:** Skip > Next

8. **Tags:**
   - Key: `Name`, Value: `lab9-asg-instance`
   - Next

9. **Review and create Auto Scaling group**

10. **Wait 3-5 minutes** for instances to launch

11. **Verify instances:**
    - EC2 > Instances: You should see 3 new instances with names `lab9-asg-instance`
    - EC2 > Target Groups > `lab9-web-tg` > Targets tab: All instances should show "healthy"

**Explanation:** Auto Scaling ensures you always have the desired number of healthy instances. If one fails, it's automatically replaced.

---

### Step 7: Test the Resilient System

**Why?** Verify load balancing and redundancy are working.

1. **Open the load balancer URL in your browser:**
   - `http://<your-alb-dns-name>`
   - You should see the Lab 9 resilient system page

2. **Refresh multiple times (5-10 times):**
   - Notice the **Instance ID** changes
   - Notice the **Availability Zone** might change
   - This is load balancing in action!

3. **Open the page in multiple browser tabs:**
   - Different tabs might show different instances
   - Traffic is distributed across all healthy instances

**Explanation:** The load balancer uses a round-robin algorithm (by default) to distribute requests. Each refresh might hit a different instance.

**Optional - See distribution:**
```bash
# Run this command multiple times to see different instances respond
for i in {1..10}; do curl -s http://<your-alb-dns-name> | grep "Instance ID"; done
```

---

## Part 3: Chaos Engineering - Breaking Things on Purpose!

### Step 8: Chaos Experiment #2 - Single Instance Failure

**Why?** Test if the system remains available when one instance fails.

**Hypothesis:** "If we terminate one instance, the system should remain available with no user-visible impact."

1. **Keep the load balancer URL open in your browser**

2. **Note the current instance IDs serving requests:**
   - Refresh a few times and write down 2-3 instance IDs you see

3. **In EC2 Console > Instances:**
   - Select one of the Auto Scaling instances
   - Instance state > **Terminate instance**
   - Confirm termination

4. **Immediately start refreshing your browser:**
   - **What happens?** The site should remain available!
   - You might see the terminated instance's ID a couple more times (cached connections)
   - Soon, you'll only see the remaining healthy instances

5. **Monitor Auto Scaling recovery:**
   - EC2 > Auto Scaling Groups > `lab9-web-asg` > Activity tab
   - You should see: "Launching a new EC2 instance"
   - Auto Scaling detected we're below desired capacity (3) and launches a replacement

6. **Wait 3-5 minutes:**
   - A new instance appears in Instances list
   - Target group shows 3 healthy instances again
   - System fully recovered automatically!

**Document the results:**
```
Chaos Experiment #2: Single Instance Failure
- Action: Terminated one of three instances
- Hypothesis: System remains available
- Result: ✅ PASSED - No downtime observed
- Impact: 0% of users affected (load balancer routed around failure)
- Recovery: Automatic within 5 minutes
- Lesson: Redundancy + Auto Scaling = self-healing system
```

**Explanation:** This is the power of resilience! The load balancer detected the unhealthy instance via health checks and stopped sending traffic to it. Auto Scaling detected capacity below desired and launched a replacement.

---

### Step 9: Chaos Experiment #3 - Multiple Instance Failures

**Why?** Test the limits of resilience. What happens under extreme failure?

**Hypothesis:** "If we terminate 2 out of 3 instances, the system should remain available but degraded."

1. **Ensure all 3 instances are healthy first** (wait if needed from previous experiment)

2. **Keep the load balancer URL open**

3. **Terminate 2 instances simultaneously:**
   - Select two instances (leave at least one running)
   - Instance state > Terminate
   - Confirm

4. **Rapidly refresh the browser:**
   - **What happens?** 
     - Site remains available! (assuming 1 instance still healthy)
     - You only see the one surviving instance ID
     - Slower responses possible (more load on one instance)

5. **Monitor recovery:**
   - Auto Scaling launches 2 replacement instances
   - Within 5 minutes, back to full capacity

6. **Optional - Extreme test (terminate ALL 3):**
   - If you terminate all instances at once: brief outage until first replacement becomes healthy
   - This demonstrates the importance of minimum capacity settings

**Document the results:**
```
Chaos Experiment #3: Multiple Instance Failures
- Action: Terminated 2 of 3 instances (66% failure)
- Hypothesis: System remains available but degraded
- Result: ✅ PASSED - Minimal impact
- Impact: Possible slight degradation, no complete outage
- Recovery: Automatic within 5 minutes
- Lesson: Even extreme failures can be tolerated with proper design
```

---

### Step 10: Chaos Experiment #4 - Availability Zone Failure

**Why?** Test resilience against data center-level failures.

**Hypothesis:** "If an entire Availability Zone fails, the system continues in other AZs."

1. **Identify which AZs your instances are in:**
   - EC2 > Instances > Check Availability Zone column
   - Example: 2 in us-east-1a, 1 in us-east-1b

2. **Simulate AZ failure by terminating all instances in one AZ:**
   - Select all instances in one specific AZ (e.g., us-east-1a)
   - Terminate them

3. **Monitor the system:**
   - Site remains available (served from other AZ)
   - Load balancer automatically stops routing to the failed AZ
   - Auto Scaling launches replacements across available AZs

**Document the results:**
```
Chaos Experiment #4: Availability Zone Failure
- Action: Simulated entire AZ failure (terminated all instances in one AZ)
- Hypothesis: System continues in remaining AZ
- Result: ✅ PASSED - No downtime
- Impact: 0% of users affected
- Recovery: Automatic redistribution across AZs
- Lesson: Multi-AZ architecture provides data center-level resilience
```

**Explanation:** This is why we deployed across multiple AZs. Even if an entire data center fails, your application continues running.

---

### Step 11: Analyze System Reliability

**Why?** Quantify the reliability improvements.

Create a comparison document:

**Before (Single Instance):**
- Single point of failure: ✗
- Availability during instance failure: 0%
- Recovery time: Manual (10+ minutes)
- AZ failure tolerance: No
- Load distribution: N/A (one instance)
- Estimated uptime: ~95% (failures cause outages)

**After (Resilient Design):**
- Single point of failure: ✓ Eliminated
- Availability during instance failure: 100%
- Recovery time: Automatic (0-5 minutes)
- AZ failure tolerance: Yes
- Load distribution: Across 3+ instances
- Estimated uptime: ~99.9% (failures handled gracefully)

**Key Metrics:**
- **MTTR (Mean Time To Repair):** Reduced from 10+ minutes (manual) to ~3 minutes (automatic)
- **Blast radius:** Reduced from 100% of users to 0% (during single instance failure)
- **Redundancy factor:** 3x (3 instances for 1x capacity)

---

## Part 4: Introduction to Chaos Engineering Principles

### Step 12: Understanding Chaos Engineering

**What is Chaos Engineering?**
- The discipline of experimenting on a system to build confidence in its capability to withstand turbulent conditions
- "Break things on purpose in controlled ways"

**The Chaos Engineering Process:**

1. **Define steady state:** What does "normal" look like?
   - Example: Response time < 200ms, zero 5xx errors

2. **Hypothesize:** Predict what will happen during failure
   - Example: "Terminating one instance will not affect users"

3. **Inject failure:** Introduce real-world issues
   - Instance failures, network latency, AZ outages

4. **Observe:** Monitor system behavior
   - Did it match your hypothesis?

5. **Learn and improve:** Fix weaknesses found
   - Add more redundancy, improve health checks, etc.

**Popular Chaos Engineering Tools:**
- **AWS Fault Injection Simulator (FIS):** Managed chaos experiments
- **Chaos Monkey (Netflix):** Randomly terminates instances
- **Gremlin:** SaaS platform for chaos experiments
- **Litmus Chaos:** Kubernetes chaos engineering

**Best Practices:**
- Start small (single instance)
- Run during business hours (when team is available)
- Have rollback plans
- Automate experiments for continuous validation
- Gradually increase blast radius

---

### Step 13: Document Your Findings

Create a reliability report: `lab9-reliability-report.md`

```markdown
# Lab 9 Reliability Analysis Report

## System Architecture

**Initial Design (Non-Resilient):**
- Single EC2 instance
- No redundancy
- Single availability zone

**Improved Design (Resilient):**
- Application Load Balancer
- Auto Scaling Group (3 instances)
- Multi-AZ deployment (2+ AZs)
- Automated health checks
- Self-healing capabilities

## Chaos Experiments Summary

| Experiment | Failure Type | Impact | Recovery Time | Status |
|------------|--------------|--------|---------------|--------|
| #1 | Single instance (baseline) | 100% outage | Manual | ❌ FAIL |
| #2 | One instance (resilient) | 0% impact | ~3 min auto | ✅ PASS |
| #3 | Two instances (resilient) | Minimal | ~5 min auto | ✅ PASS |
| #4 | Entire AZ (resilient) | 0% impact | ~5 min auto | ✅ PASS |

## Reliability Improvements

**Metrics:**
- Availability increase: 95% → 99.9%
- MTTR decrease: 10+ minutes → 3 minutes
- Automation: 0% → 100%

**Resilience Strategies Implemented:**
✅ Redundancy (3 instances)
✅ Load balancing (ALB)
✅ Automatic failover (health checks)
✅ Multi-AZ deployment
✅ Auto-healing (Auto Scaling)
✅ Graceful degradation (survives partial failures)

## Recommendations for Further Improvement

1. **Add more AZs:** Deploy across 3 AZs for even better resilience
2. **Implement caching:** Reduce backend load, improve performance
3. **Add monitoring:** CloudWatch alarms for unhealthy instances
4. **Database redundancy:** Use RDS Multi-AZ or DynamoDB
5. **Automated chaos:** Schedule regular chaos experiments
6. **Disaster Recovery:** Multi-region deployment for regional failures

## Key Learnings

- Redundancy is not optional for reliable systems
- Automated recovery is faster and more reliable than manual
- Testing failures builds confidence
- Small investments in resilience yield large availability gains
- Chaos Engineering helps find weaknesses before users do
```

---

## Part 5: Improvements and Best Practices

### Step 14: (Optional) Add CloudWatch Monitoring

**Why?** Observability is crucial for reliability.

1. **Create CloudWatch Dashboard:**
   - CloudWatch > Dashboards > Create dashboard
   - Name: `Lab9-Reliability-Dashboard`

2. **Add widgets:**
   - **Target Health:** Shows number of healthy/unhealthy targets
   - **Request Count:** Total requests to load balancer
   - **Response Time:** Average latency
   - **HTTP 5xx Errors:** Server errors

3. **Set up alarms:**
   - Alarm when healthy instances < 2
   - Alarm when 5xx error rate > 5%
   - Send to SNS topic for email notifications

**Explanation:** You can't improve what you don't measure. Monitoring provides visibility into system behavior.

---

### Step 15: Cleanup

**Why?** Avoid unexpected AWS charges.

**Delete resources in this order:**

1. **Delete Auto Scaling Group:**
   - EC2 > Auto Scaling Groups > Select `lab9-web-asg` > Delete
   - This automatically terminates all ASG instances

2. **Delete Load Balancer:**
   - EC2 > Load Balancers > Select `lab9-web-alb` > Actions > Delete

3. **Delete Target Group:**
   - EC2 > Target Groups > Select `lab9-web-tg` > Actions > Delete

4. **Delete Launch Template:**
   - EC2 > Launch Templates > Select `lab9-web-server-template` > Actions > Delete

5. **Terminate the original single instance:**
   - EC2 > Instances > Terminate `lab9-single-instance`

6. **Delete Security Group (if not needed):**
   - EC2 > Security Groups > Delete `lab9-web-sg` (only if no instances use it)

7. **Delete CloudWatch Dashboard (if created):**
   - CloudWatch > Dashboards > Delete

**Verification:**
- Check EC2 > Instances: All terminated
- Check Load Balancers: None running
- Check Auto Scaling Groups: None active

---

## Key Takeaways

✅ **Single points of failure are unacceptable** in reliable systems

✅ **Redundancy is insurance** - costs resources but prevents outages

✅ **Load balancing** distributes load AND provides failover

✅ **Multi-AZ deployment** protects against data center failures

✅ **Auto Scaling** provides self-healing capabilities

✅ **Chaos Engineering** builds confidence through controlled failure injection

✅ **Automated recovery** is faster and more reliable than manual intervention

✅ **Design for failure** - assume everything will break, build accordingly

---

## Real-World Applications

**E-commerce site:**
- Can't afford downtime during Black Friday
- Multi-AZ deployment with Auto Scaling
- Chaos testing before peak season

**Banking application:**
- Requires 99.99% availability
- Multi-region deployment
- Automated failover tested monthly

**Streaming service:**
- Must handle instance failures gracefully
- Netflix's Chaos Monkey runs continuously
- Regional failover for large-scale outages

---

## Troubleshooting Guide

**Target group shows unhealthy instances:**
- Check security group allows HTTP (port 80)
- Verify Apache is running: SSH to instance, `sudo systemctl status httpd`
- Check health check path `/health` exists

**Load balancer returns 503 errors:**
- No healthy targets available
- Wait for instances to pass health checks (2 consecutive successful checks)

**Auto Scaling not launching instances:**
- Check service role permissions
- Verify launch template is valid
- Review Auto Scaling group activity history for errors

**Instances launch but immediately terminate:**
- Check user data script for errors
- View instance system logs in EC2 console
- Verify AMI is valid for selected instance type

---

## Additional Resources

- [AWS Well-Architected Framework - Reliability Pillar](https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/welcome.html)
- [Principles of Chaos Engineering](https://principlesofchaos.org/)
- [Netflix Chaos Engineering Blog](https://netflixtechblog.com/tagged/chaos-engineering)
- [AWS Fault Injection Simulator](https://aws.amazon.com/fis/)
- [SRE Book - Chapter on Embracing Risk](https://sre.google/sre-book/embracing-risk/)

---

**Congratulations!** You've completed Lab 9! You now understand how to design reliable systems, implement redundancy and load balancing, and use Chaos Engineering to build confidence in your systems. Most importantly, you've experienced firsthand how proper architecture turns failures from disasters into non-events.

**Remember:** In production, failures are inevitable. The question isn't "if" but "when." Design accordingly! 🛡️

Save this guide and your reliability report. Ready to build unbreakable systems? 🚀
