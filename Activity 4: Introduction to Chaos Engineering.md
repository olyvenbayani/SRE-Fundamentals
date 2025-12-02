**Time Estimate:** 20 minutes  
**Format:** Guided discussion and scenario analysis  
**Goal:** Understand Chaos Engineering principles and prepare for hands-on experiments in Lab 9

---

## What is Chaos Engineering?

Chaos Engineering is the discipline of experimenting on a system to build confidence in its capability to withstand turbulent conditions in production.

**Key Principle:** "Break things on purpose, in controlled ways, before they break by accident in production."

### The Chaos Engineering Mindset

Instead of asking:
- ❌ "Will our system fail?"

Ask:
- ✅ "When and how will our system fail?"
- ✅ "What happens when it fails?"
- ✅ "Can we recover gracefully?"

---

## Part 1: Famous Outages - Learning from Failures (5 minutes)

### Case Study 1: AWS S3 Outage (February 2017)

**What happened:**
- An engineer was debugging an S3 billing issue
- Intended to remove a small number of servers
- Accidentally removed too many servers, including critical subsystems
- S3 in us-east-1 was down for ~4 hours
- Affected thousands of websites and apps

**Impact:**
- Major websites showed error pages
- Apps couldn't load images or files
- IoT devices stopped working
- Estimated billions of dollars in lost productivity

**What would Chaos Engineering have prevented?**
- Testing "what if S3 is unavailable?" before it happened
- Having fallback mechanisms in place
- Understanding blast radius of S3 dependency

### Case Study 2: GitLab Database Incident (January 2017)

**What happened:**
- Database replication was lagging
- Engineer tried to remove the replica to resync
- Accidentally ran delete command on PRIMARY database
- Lost 6 hours of production data
- Backups hadn't been tested and some were broken

**Impact:**
- 18 hours of reduced service
- Data loss for issues, comments, projects
- Public incident report became famous example

**What would Chaos Engineering have revealed?**
- Backup restoration had never been tested
- No safeguards for dangerous operations
- Recovery procedures were untested

### Discussion Questions:

1. **What do these incidents have in common?**
   - Human error during operations
   - Untested failure scenarios
   - Missing safeguards and redundancy

2. **Could Chaos Engineering have helped?**
   - Yes - testing dependencies, backup restoration, and failure modes
   - Building confidence in recovery procedures
   - Discovering weaknesses before production incidents

---

## Part 2: The Chaos Engineering Workflow (5 minutes)

### The Scientific Method for System Reliability

```
1. Define Steady State
   ↓
2. Form Hypothesis
   ↓
3. Introduce Chaos (Controlled Failure)
   ↓
4. Observe Behavior
   ↓
5. Learn & Improve
   ↓
(Repeat)
```

### Step 1: Define Steady State
**What does "normal" look like?**

Examples:
- ✅ "99% of requests complete in < 200ms"
- ✅ "Error rate < 0.1%"
- ✅ "No 5xx errors"
- ✅ "All health checks passing"

### Step 2: Form Hypothesis
**What do you think will happen?**

Examples:
- "If we terminate one instance, the load balancer will route around it with zero user impact"
- "If the database fails, the application will serve cached data for 5 minutes"
- "If network latency increases by 200ms, response time will increase but remain under SLO"

### Step 3: Introduce Chaos
**Inject realistic failures**

Common chaos experiments:
- 🔴 Terminate instances/containers
- 🔴 Inject network latency or packet loss
- 🔴 Fill up disk space
- 🔴 Spike CPU or memory
- 🔴 Make dependencies unavailable
- 🔴 Simulate AZ/region failures

### Step 4: Observe
**What actually happened?**

Monitor:
- Application metrics (latency, errors, throughput)
- Infrastructure metrics (CPU, memory, network)
- User experience (can they complete tasks?)
- Logs and traces

### Step 5: Learn & Improve
**Did reality match your hypothesis?**

- ✅ **Passed:** Great! Document and repeat regularly
- ❌ **Failed:** Found a weakness! Fix it and test again

---

## Part 3: Design Your Own Chaos Experiments (8 minutes)

### Scenario 1: E-Commerce Website

**System Architecture:**
- Web application (3 instances behind load balancer)
- Database (single RDS instance)
- Redis cache
- S3 for product images
- Payment gateway (external API)

**Your Task:** Design 3 chaos experiments

**Example Experiment:**
```
Title: Database Unavailability
Hypothesis: If RDS fails, cache will serve product listings for 10 minutes
Chaos Action: Stop RDS instance
Expected Outcome: 
  - Product browsing works (from cache)
  - Checkout fails gracefully with error message
  - System recovers when RDS restarts
Blast Radius: Checkout disabled, browsing OK
```

**Now design experiments for:**

1. **What if one web server crashes?**
   - Hypothesis: _________________________________
   - Expected outcome: _________________________________
   - How would you verify? _________________________________

2. **What if S3 is unavailable?**
   - Hypothesis: _________________________________
   - Expected outcome: _________________________________
   - How would you verify? _________________________________

3. **What if the payment gateway is slow (500ms latency)?**
   - Hypothesis: _________________________________
   - Expected outcome: _________________________________
   - How would you verify? _________________________________

### Scenario 2: Video Streaming Service

**System Architecture:**
- Frontend (CloudFront CDN)
- API servers (Auto Scaling group)
- Video storage (S3)
- User database (DynamoDB)
- Recommendation engine (separate microservice)

**Design 2 chaos experiments:**

1. **Experiment focusing on availability:**
   - Component: _________________________________
   - Failure scenario: _________________________________
   - Hypothesis: _________________________________

2. **Experiment focusing on performance degradation:**
   - Component: _________________________________
   - Failure scenario: _________________________________
   - Hypothesis: _________________________________

---

## Part 4: Chaos Engineering Best Practices (2 minutes)

### Start Small, Scale Gradually

**Phases of Chaos Engineering Adoption:**

1. **🟢 Phase 1: Staging Environment**
   - Test on non-production first
   - Learn tools and processes
   - Build confidence

2. **🟡 Phase 2: Production (Low Blast Radius)**
   - Small experiments during business hours
   - Single instance failures
   - Limited scope
   - Team monitoring actively

3. **🟠 Phase 3: Production (Higher Blast Radius)**
   - Multi-instance failures
   - AZ failures
   - Dependency failures
   - Still during business hours with team ready

4. **🔴 Phase 4: Continuous Chaos**
   - Automated experiments
   - Random timing (like Netflix's Chaos Monkey)
   - GameDays: scheduled large-scale chaos events

### The Golden Rules

✅ **Have a rollback plan** - Always be able to stop the experiment immediately

✅ **Define blast radius** - Know the maximum impact before starting

✅ **Monitor everything** - You can't learn if you can't observe

✅ **Run during business hours** - Team should be available to respond

✅ **Get organizational buy-in** - Everyone should understand why you're breaking things

✅ **Document everything** - Record hypothesis, actions, and outcomes

❌ **Don't run experiments you can't stop**

❌ **Don't test in production without testing in staging first**

❌ **Don't skip the hypothesis step** - This is science, not random destruction

---

## Part 5: Chaos Engineering Tools Overview (Optional - if time permits)

### Popular Tools

| Tool | Description | Best For |
|------|-------------|----------|
| **AWS Fault Injection Simulator (FIS)** | Managed AWS service for chaos experiments | AWS-native environments |
| **Chaos Monkey** | Netflix tool - randomly terminates instances | EC2/Auto Scaling groups |
| **Gremlin** | Comprehensive SaaS platform | Enterprise teams, multi-cloud |
| **Litmus Chaos** | Open-source for Kubernetes | Kubernetes/container environments |
| **Chaos Toolkit** | Open-source framework | Custom experiments, any platform |
| **Pumba** | Docker chaos testing | Docker/container testing |

### Simple Manual Chaos (What We'll Do in Lab 9)

You don't need fancy tools to start! Manual chaos experiments:
- Terminate EC2 instances via console
- Stop services with `systemctl stop`
- Simulate latency with `tc` (traffic control)
- Fill disk with `dd`
- Stress CPU/memory with `stress` tool

---

## Reflection Questions

Before moving to Lab 9, discuss:

1. **Why is it safer to intentionally break things than to wait for them to break?**
   - You control the timing (business hours, team ready)
   - You define the scope (limited blast radius)
   - You learn before customers experience the issue

2. **What's the difference between Chaos Engineering and traditional testing?**
   - Traditional testing: "Does the code work correctly?"
   - Chaos Engineering: "Does the system behave correctly under failure?"
   - Chaos tests the entire system, including infrastructure, networking, dependencies

3. **How does Chaos Engineering relate to SRE principles?**
   - Reduces MTTR (practice recovery procedures)
   - Increases availability (find and fix weaknesses)
   - Builds error budgets confidence (know your failure modes)
   - Encourages designing for failure

4. **What might prevent a team from adopting Chaos Engineering?**
   - Fear of causing outages (address with small experiments first)
   - Lack of monitoring (can't observe effects)
   - Culture doesn't accept failure (education needed)
   - Insufficient redundancy (fix architecture first)

---

## Quick Quiz

Test your understanding before Lab 9:

**1. What is the first step in a chaos experiment?**
   - a) Introduce failure
   - b) Define steady state ✅
   - c) Hope for the best
   - d) Call the manager

**2. You terminate one instance and the entire site goes down. This means:**
   - a) Chaos Engineering doesn't work
   - b) You found a valuable weakness to fix ✅
   - c) You should never terminate instances
   - d) The experiment failed

**3. When should you run your first production chaos experiment?**
   - a) 3 AM on Sunday (no one is around)
   - b) During Black Friday (high traffic)
   - c) Business hours with team monitoring ✅
   - d) Never - too risky

**4. Netflix's Chaos Monkey:**
   - a) Randomly terminates instances in production ✅
   - b) Tests code for bugs
   - c) Monitors application performance
   - d) Deploys new features

**5. The goal of Chaos Engineering is to:**
   - a) Create more incidents
   - b) Build confidence in system resilience ✅
   - c) Make developers afraid
   - d) Prove the system is perfect

---

## Key Takeaways

Before moving to Lab 9, remember:

✅ **Chaos Engineering is proactive, not destructive** - It's about learning and improving

✅ **All systems will fail** - The question is whether they fail gracefully

✅ **Hypotheses are crucial** - This is science, not random breaking

✅ **Start small and scale up** - Build confidence gradually

✅ **Failures in chaos experiments are successes** - You found weaknesses before customers did!

✅ **Production testing is the only real test** - Staging can't replicate all real-world conditions

---

## What's Next: Lab 9 Preview

In Lab 9, you'll apply these principles hands-on:

1. **Deploy a fragile system** - Single instance (will fail catastrophically)
2. **Build resilience** - Add load balancer, auto-scaling, multi-AZ
3. **Run chaos experiments** - Terminate instances and watch recovery
4. **Measure improvements** - Compare availability before and after

**Get ready to break things! 💥**

---

## Additional Resources

- [Principles of Chaos Engineering](https://principlesofchaos.org/) - The manifesto
- [Chaos Engineering Book by Netflix](https://www.oreilly.com/library/view/chaos-engineering/9781491988459/)
- [AWS Chaos Engineering Blog](https://aws.amazon.com/blogs/architecture/chaos-engineering-on-aws/)
- [Google SRE Book - Testing for Reliability](https://sre.google/sre-book/testing-reliability/)
- [Netflix TechBlog - Chaos Engineering](https://netflixtechblog.com/tagged/chaos-engineering)

---

**Great work!** You now understand the "why" and "how" of Chaos Engineering. Let's move to Lab 9 to experience it hands-on! 🚀
