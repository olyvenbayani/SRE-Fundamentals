**Time Estimate:** 15-20 minutes  
**Difficulty:** Beginner  
**Goal:** Experience the challenges of manual infrastructure management

## Why Are We Doing This?

Before we automate, let's experience the pain of manual infrastructure creation. This hands-on exercise will make you truly appreciate Infrastructure as Code! Plus, you'll understand what's actually being created when we automate it later.

Think of this as learning to cook from scratch before using a recipe app. The experience matters!

## What You'll Build

A basic VPC (Virtual Private Cloud) with:
- 1 VPC with custom CIDR block
- 1 Internet Gateway
- 2 Public Subnets in different Availability Zones
- 1 Route Table with internet access
- 1 Security Group for web traffic

This is a real-world foundation for hosting web applications!

---

## Step 1: Create the VPC

1. **Log into AWS Console** and navigate to the VPC service
   - Use the search bar at the top and type "VPC"
   - Click on "VPC" under Services

2. **Create VPC:**
   - Click the orange "Create VPC" button
   - **Name tag:** `manual-vpc-yourname` (replace "yourname" with your actual name)
   - **IPv4 CIDR block:** `10.0.0.0/16`
     - This gives you 65,536 IP addresses to work with!
   - Leave other settings as default
   - Click "Create VPC"

3. **Save the VPC ID!**
   - After creation, you'll see a VPC ID like `vpc-abc123def456`
   - Write this down or keep the tab open - you'll need it!

**What just happened?** You created an isolated network in AWS. Think of it as your own private data center in the cloud.

---

## Step 2: Create Internet Gateway

**Why?** Without an Internet Gateway, your VPC is isolated from the internet. We need this for public-facing resources!

1. **Navigate to Internet Gateways:**
   - Left sidebar → Click "Internet Gateways"
   
2. **Create Internet Gateway:**
   - Click "Create internet gateway"
   - **Name tag:** `manual-igw-yourname`
   - Click "Create internet gateway"

3. **Attach to VPC (IMPORTANT!):**
   - After creation, notice it says "State: Detached"
   - Click "Actions" → "Attach to VPC"
   - Select your `manual-vpc-yourname`
   - Click "Attach internet gateway"

**Checkpoint:** Your IGW should now show "State: Attached"

---

## Step 3: Create Public Subnets

**Why two subnets?** High availability! If one Availability Zone fails, the other keeps running.

### Subnet 1:

1. **Navigate to Subnets:**
   - Left sidebar → "Subnets"

2. **Create first subnet:**
   - Click "Create subnet"
   - **VPC ID:** Select your `manual-vpc-yourname`
   - **Subnet name:** `manual-public-subnet-1a`
   - **Availability Zone:** Choose the first one (e.g., us-east-1a)
   - **IPv4 CIDR block:** `10.0.1.0/24`
     - This gives you 256 IP addresses in this subnet
   - Click "Create subnet"

### Subnet 2:

3. **Create second subnet:**
   - Click "Create subnet" again
   - **VPC ID:** Select your `manual-vpc-yourname` (should be pre-selected)
   - **Subnet name:** `manual-public-subnet-1b`
   - **Availability Zone:** Choose a DIFFERENT zone (e.g., us-east-1b)
   - **IPv4 CIDR block:** `10.0.2.0/24`
   - Click "Create subnet"

**Pro tip:** Note how many clicks this took. Imagine doing this for 10 different environments!

---

## Step 4: Create and Configure Route Table

**Why?** Route tables tell traffic where to go. We need to route internet traffic to the Internet Gateway.

1. **Navigate to Route Tables:**
   - Left sidebar → "Route Tables"

2. **Create Route Table:**
   - Click "Create route table"
   - **Name:** `manual-public-rt`
   - **VPC:** Select your `manual-vpc-yourname`
   - Click "Create route table"

3. **Add Internet Route:**
   - Select your new route table
   - Bottom panel → "Routes" tab
   - Click "Edit routes"
   - Click "Add route"
     - **Destination:** `0.0.0.0/0` (this means "all internet traffic")
     - **Target:** Select "Internet Gateway" → Choose your `manual-igw-yourname`
   - Click "Save changes"

4. **Associate Subnets:**
   - Bottom panel → "Subnet associations" tab
   - Click "Edit subnet associations"
   - Check BOTH of your subnets:
     - ✅ `manual-public-subnet-1a`
     - ✅ `manual-public-subnet-1b`
   - Click "Save associations"

**What just happened?** You told AWS: "Any traffic going to the internet (0.0.0.0/0) should go through the Internet Gateway"

---

## Step 5: Create Security Group

**Why?** Security groups are virtual firewalls. They control what traffic can reach your resources.

1. **Navigate to Security Groups:**
   - Left sidebar → "Security Groups"

2. **Create Security Group:**
   - Click "Create security group"
   - **Security group name:** `manual-web-sg`
   - **Description:** `Allow HTTP and HTTPS traffic`
   - **VPC:** Select your `manual-vpc-yourname`

3. **Add Inbound Rules:**
   - Scroll to "Inbound rules" section
   - Click "Add rule"
     - **Type:** HTTP
     - **Source:** Custom → `0.0.0.0/0` (anywhere on internet)
   - Click "Add rule" again
     - **Type:** HTTPS
     - **Source:** Custom → `0.0.0.0/0`
   
4. **Create Security Group:**
   - Scroll down and click "Create security group"

**Security note:** In production, you'd restrict sources more carefully. This is just for learning!

---

## Step 6: Verify Your Work

Take a screenshot or note these details:

- ✅ VPC ID: `vpc-____________`
- ✅ Internet Gateway: Attached
- ✅ Subnet 1: `10.0.1.0/24` in AZ-a
- ✅ Subnet 2: `10.0.2.0/24` in AZ-b
- ✅ Route Table: Has route to `0.0.0.0/0` via IGW
- ✅ Security Group: Allows HTTP/HTTPS

**Congratulations!** You've manually created a working VPC infrastructure! 🎉

---

## The Pain Points (Let's Be Honest!)

| Problem | Impact |
|---------|--------|
| ⏱️ **Time-consuming** | 15-20 minutes for basic setup |
| 🐛 **Error-prone** | Easy to misconfigure, hard to catch mistakes |
| 📝 **Documentation nightmare** | Screenshots get outdated instantly |
| 🔄 **Not reproducible** | Can't easily recreate in another region/account |
| 👥 **Knowledge silos** | Only you know how it was built |
| 🔍 **No audit trail** | Who changed what, when, and why? |
| 😰 **Stressful at scale** | Imagine doing this for 10 environments! |
| 🚫 **Can't easily test** | No way to validate before making changes |

---

## What's Next?

**Don't delete your VPC yet!** We'll use it for comparison in Activity 2.

In the next activity, you'll create the EXACT same infrastructure using CloudFormation. You'll see:
- ⚡ How much faster it is
- 🎯 How much more accurate it is
- 📚 How it becomes self-documenting
- 🔄 How easily you can replicate it
- 🎉 Why Infrastructure as Code is a game-changer!

**Before moving on:**
- Make sure you can access all the resources you created
- Keep your VPC ID handy
- Be ready to appreciate automation!

---

## Troubleshooting

**Can't find the VPC service?**
- Use the search bar at the top of AWS Console
- Type "VPC" and click the service

**Internet Gateway won't attach?**
- Make sure you selected the correct VPC
- Each VPC can only have one IGW attached

**Routes not working?**
- Verify the route destination is `0.0.0.0/0`
- Confirm the target is your Internet Gateway (not NAT Gateway!)
- Check that subnets are associated with the route table

**Lost track of what you created?**
- VPC Dashboard shows a summary
- Each resource has tags - use the Name tag to identify yours

**Want to start over?**
- Delete resources in reverse order: Security Group → Route Table → Subnets → Internet Gateway → VPC

---

## Key Takeaways

✅ Manual infrastructure creation is time-consuming and error-prone  
✅ It's difficult to reproduce and scale  
✅ Documentation becomes a burden  
✅ There's no easy way to track changes  
✅ This approach doesn't scale for SRE practices  

**The SRE Principle:** If you're doing it manually more than once, you should automate it!

Ready to see the automated way? Head to **Guided Activity 2: CloudFormation Stack Deployment**!

---

**Pro Tip:** Keep a log of all the resources you created (VPC ID, subnet IDs, etc.). You'll need these for comparison in the next activity, and you'll want to clean them up afterward to avoid charges.
