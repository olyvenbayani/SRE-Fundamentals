**Time Estimate:** 20-25 minutes  
**Difficulty:** Beginner  
**Goal:** Learn Infrastructure as Code with AWS CloudFormation

## Why CloudFormation?

After the manual clicking marathon in Activity 1, you're ready for the magic of Infrastructure as Code (IaC)! CloudFormation lets you define your infrastructure in a template file, and AWS creates everything for you automatically.

**Think of it like this:**
- Manual = Following verbal directions to cook
- CloudFormation = Following a written recipe that works every time

## What You'll Learn

- How to write CloudFormation templates (YAML format)
- How to deploy infrastructure using templates
- How to update existing infrastructure safely
- Why IaC is a game-changer for SREs

---

## Step 1: Understand the CloudFormation Template

Create a file called `vpc-infrastructure.yaml` on your computer.

**Pro tip:** Use a text editor like VS Code, not Word! YAML is sensitive to spacing.

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'VPC Infrastructure - The Same Setup, But Automated!'

Parameters:
  EnvironmentName:
    Description: Environment name prefix for resources
    Type: String
    Default: dev
    AllowedValues:
      - dev
      - staging
      - prod

  VpcCIDR:
    Description: IP range (CIDR notation) for this VPC
    Type: String
    Default: 10.0.0.0/16

Resources:
  # VPC
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: !Ref VpcCIDR
      EnableDnsHostnames: true
      EnableDnsSupport: true
      Tags:
        - Key: Name
          Value: !Sub '${EnvironmentName}-vpc'
        - Key: ManagedBy
          Value: CloudFormation
        - Key: Environment
          Value: !Ref EnvironmentName

  # Internet Gateway
  InternetGateway:
    Type: AWS::EC2::InternetGateway
    Properties:
      Tags:
        - Key: Name
          Value: !Sub '${EnvironmentName}-igw'

  # Attach Internet Gateway to VPC
  AttachGateway:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId: !Ref VPC
      InternetGatewayId: !Ref InternetGateway

  # Public Subnet 1
  PublicSubnet1:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.1.0/24
      AvailabilityZone: !Select [0, !GetAZs '']
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: !Sub '${EnvironmentName}-public-subnet-1'
        - Key: Type
          Value: Public

  # Public Subnet 2
  PublicSubnet2:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.2.0/24
      AvailabilityZone: !Select [1, !GetAZs '']
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: !Sub '${EnvironmentName}-public-subnet-2'
        - Key: Type
          Value: Public

  # Route Table for Public Subnets
  PublicRouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: !Sub '${EnvironmentName}-public-rt'

  # Route to Internet Gateway
  PublicRoute:
    Type: AWS::EC2::Route
    DependsOn: AttachGateway
    Properties:
      RouteTableId: !Ref PublicRouteTable
      DestinationCidrBlock: 0.0.0.0/0
      GatewayId: !Ref InternetGateway

  # Associate Public Subnet 1 with Route Table
  SubnetRouteTableAssociation1:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnet1
      RouteTableId: !Ref PublicRouteTable

  # Associate Public Subnet 2 with Route Table
  SubnetRouteTableAssociation2:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnet2
      RouteTableId: !Ref PublicRouteTable

  # Security Group for Web Traffic
  WebSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupName: !Sub '${EnvironmentName}-web-sg'
      GroupDescription: Allow HTTP and HTTPS traffic
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
          Value: !Sub '${EnvironmentName}-web-sg'

Outputs:
  VPCId:
    Description: VPC ID
    Value: !Ref VPC
    Export:
      Name: !Sub '${EnvironmentName}-VPC-ID'

  PublicSubnet1Id:
    Description: Public Subnet 1 ID
    Value: !Ref PublicSubnet1
    Export:
      Name: !Sub '${EnvironmentName}-PublicSubnet1-ID'

  PublicSubnet2Id:
    Description: Public Subnet 2 ID
    Value: !Ref PublicSubnet2
    Export:
      Name: !Sub '${EnvironmentName}-PublicSubnet2-ID'

  WebSecurityGroupId:
    Description: Web Security Group ID
    Value: !Ref WebSecurityGroup
    Export:
      Name: !Sub '${EnvironmentName}-WebSG-ID'

  VPCCidr:
    Description: VPC CIDR Block
    Value: !GetAtt VPC.CidrBlock
```

### Template Breakdown (What Does This Mean?)

**1. Parameters** (Top of template)
```yaml
Parameters:
  EnvironmentName:
    Type: String
    Default: dev
```
- Variables you can change without editing the template
- Like function arguments in programming!
- Example: Use "dev" for development, "prod" for production

**2. Resources** (Main section)
```yaml
Resources:
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: !Ref VpcCIDR
```
- Defines what to create (VPC, subnets, etc.)
- Each resource has a Type and Properties
- `!Ref` references other resources or parameters

**3. Intrinsic Functions** (The special `!` commands)
- `!Ref`: Get the ID of another resource
- `!Sub`: Substitute variables into strings
- `!GetAZs`: Get list of Availability Zones
- `!Select`: Pick an item from a list

**4. Outputs** (Bottom of template)
```yaml
Outputs:
  VPCId:
    Value: !Ref VPC
    Export:
      Name: !Sub '${EnvironmentName}-VPC-ID'
```
- Values you want to see or use in other stacks
- Can be exported for cross-stack references

**This template creates THE EXACT SAME infrastructure you made manually in Activity 1!**

---

## Step 2: Deploy Using CloudFormation Console

Time to see the magic! ✨

1. **Open AWS CloudFormation Console**
   - Search for "CloudFormation" in AWS Console

2. **Create Stack:**
   - Click orange "Create stack" button
   - Select "With new resources (standard)"

3. **Specify Template:**
   - **Template source:** Upload a template file
   - Click "Choose file"
   - Select your `vpc-infrastructure.yaml` file
   - Click "Next"

4. **Specify Stack Details:**
   - **Stack name:** `cfn-vpc-stack`
     - This is the name of your deployment
   - **Parameters:**
     - **EnvironmentName:** `dev`
     - **VpcCIDR:** `10.0.0.0/16` (keep default)
   - Click "Next"

5. **Configure Stack Options:**
   - **Tags** (optional): Add `Project: SRE-Workshop`
   - Leave everything else as default
   - Click "Next"

6. **Review:**
   - Scroll down and review everything
   - Check the box: "I acknowledge that AWS CloudFormation might create IAM resources"
   - Click "Submit"

---

## Step 3: Watch the Magic Happen! ✨

**This is where IaC becomes awesome!**

1. **Events Tab:**
   - You'll see real-time events as resources are created
   - Watch them turn from `CREATE_IN_PROGRESS` to `CREATE_COMPLETE`
   - Order matters! CloudFormation handles dependencies automatically

2. **Resources Tab:**
   - Shows all resources being created
   - Click any resource to see it in the AWS Console

3. **Template Tab:**
   - View your original template
   - It's now your living documentation!

**Typical creation time:** 2-3 minutes ⏱️

**Compare this to Activity 1:**
- Manual: 15-20 minutes + many clicks
- CloudFormation: 3 minutes + zero clicks (after initial setup)

---

## Step 4: Explore the Results

Once status shows `CREATE_COMPLETE`:

### Check the Outputs Tab
- VPCId: `vpc-abc123...`
- PublicSubnet1Id: `subnet-def456...`
- PublicSubnet2Id: `subnet-ghi789...`
- WebSecurityGroupId: `sg-jkl012...`

**These values are now available to other stacks!**

### Navigate to VPC Console
- Find your `dev-vpc`
- See all the resources with consistent naming
- Notice the `ManagedBy: CloudFormation` tag

### Compare with Manual VPC
Side-by-side comparison:

| Feature | Manual VPC | CloudFormation VPC |
|---------|------------|-------------------|
| **Time to create** | 15-20 min | 3 min |
| **Clicks required** | 30-50+ | ~10 |
| **Documentation** | Screenshots? | Template IS the docs |
| **Reproducible** | ❌ No | ✅ Yes |
| **Version controlled** | ❌ No | ✅ Yes |
| **Audit trail** | ❌ No | ✅ Yes (events) |
| **Can test first** | ❌ No | ✅ Yes (change sets) |

---

## Step 5: Make a Change (Infrastructure Updates Made Easy!)

Let's add a third subnet to see how updates work.

### Edit the Template

Open your `vpc-infrastructure.yaml` and add after `PublicSubnet2`:

```yaml
  # Public Subnet 3
  PublicSubnet3:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.3.0/24
      AvailabilityZone: !Select [2, !GetAZs '']
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: !Sub '${EnvironmentName}-public-subnet-3'
        - Key: Type
          Value: Public

  # Associate Public Subnet 3 with Route Table
  SubnetRouteTableAssociation3:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnet3
      RouteTableId: !Ref PublicRouteTable
```

And add to Outputs section:

```yaml
  PublicSubnet3Id:
    Description: Public Subnet 3 ID
    Value: !Ref PublicSubnet3
    Export:
      Name: !Sub '${EnvironmentName}-PublicSubnet3-ID'
```

### Update the Stack

1. **In CloudFormation Console:**
   - Select your `cfn-vpc-stack`
   - Click "Update"

2. **Prepare Template:**
   - Select "Replace current template"
   - Upload your modified `vpc-infrastructure.yaml`
   - Click "Next"

3. **Review Changes:**
   - Click "Next" through parameters (no changes)
   - Click "Next" through options
   - On final page, click "View change set"

4. **Change Set Preview (This is POWERFUL!):**
   - See exactly what will change:
     - ✅ Add: PublicSubnet3
     - ✅ Add: SubnetRouteTableAssociation3
     - 🟢 Modify: Outputs section
     - ⚪ No changes to existing resources!
   - Click "Execute change set"

5. **Watch the Update:**
   - Only new resources are created
   - Existing resources untouched
   - Takes ~1 minute

**This is smart updating!** CloudFormation knows what changed and only modifies what's necessary.

---

## Step 6: Understanding CloudFormation Benefits

### Benefit 1: Self-Documenting
```yaml
# The template IS the documentation!
# Anyone can read it and understand the infrastructure
# No need for separate wiki pages or screenshots
```

### Benefit 2: Version Control Ready
```bash
# Track changes over time
git add vpc-infrastructure.yaml
git commit -m "Added third public subnet for expanded capacity"
git push

# See history
git log --oneline vpc-infrastructure.yaml

# Rollback if needed
git revert HEAD
```

### Benefit 3: Reproducible
```bash
# Create identical infrastructure in ANY region
aws cloudformation create-stack \
  --stack-name prod-vpc-stack \
  --template-body file://vpc-infrastructure.yaml \
  --parameters ParameterKey=EnvironmentName,ParameterValue=prod \
  --region us-west-2
```

### Benefit 4: Testable
```bash
# Validate before deploying
aws cloudformation validate-template \
  --template-body file://vpc-infrastructure.yaml
```

### Benefit 5: Safe Updates
- Change sets show what will happen BEFORE it happens
- Rollback on failure
- No "oops, I deleted the wrong thing"

---

## Step 7: Clean Up (Optional - Keep for Activity 3!)

**Don't delete yet if you're continuing to Activity 3!**

But when you're ready:

1. **Delete Stack:**
   - Select `cfn-vpc-stack`
   - Click "Delete"
   - Confirm deletion

2. **Watch Cleanup:**
   - Resources deleted in reverse dependency order
   - CloudFormation handles the complexity
   - Takes ~2-3 minutes

3. **Verify:**
   - Stack status: `DELETE_COMPLETE`
   - All resources gone
   - No orphaned resources!

**Compare to manual cleanup:**
- Manual: Delete each resource individually, in correct order, hope you don't miss anything
- CloudFormation: One button, done!

---

## Key Takeaways

✅ **Infrastructure as Code is reproducible** - Same template = Same infrastructure  
✅ **Templates are self-documenting** - No need for separate docs  
✅ **Changes are safe and predictable** - Change sets show what will happen  
✅ **Automation saves time** - 3 minutes vs 15-20 minutes  
✅ **Version control ready** - Track changes over time  
✅ **Reduces human error** - No more "oops, wrong CIDR block"  

---

## Troubleshooting

**Stack creation failed?**
- Check the Events tab for error messages
- Common issues:
  - CIDR block already in use
  - Missing permissions
  - Resource limits exceeded

**Template syntax errors?**
- YAML is sensitive to indentation (use spaces, not tabs!)
- Validate with: `aws cloudformation validate-template`
- Use a YAML validator online

**Can't find my stack?**
- Make sure you're in the correct AWS region
- Check the filter dropdown (show all stacks)

**Resources in CREATE_COMPLETE but stack is ROLLBACK_COMPLETE?**
- One resource failed, so CloudFormation rolled back
- Check Events tab to see which resource failed and why

**Want to see what changed between versions?**
- Use Git diff: `git diff vpc-infrastructure.yaml`
- Or use CloudFormation change sets

---

## What's Next?

You've mastered Infrastructure as Code! But we can go further...

In **Activity 3**, you'll add CI/CD to automatically:
- ✅ Validate templates before deployment
- ✅ Deploy on every Git push
- ✅ Catch errors automatically
- ✅ Create a full deployment pipeline

**Before moving on:**
- Keep your CloudFormation stack (or be ready to recreate it)
- Understand how templates define infrastructure
- Appreciate how much easier this is than manual clicking!

Ready for full automation? Head to **Guided Activity 3: CI/CD Pipeline Setup**! 🚀

---

## Additional Resources

- **CloudFormation Template Reference:** https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/template-reference.html
- **Intrinsic Functions:** https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/intrinsic-function-reference.html
- **Best Practices:** https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/best-practices.html
- **Sample Templates:** https://github.com/awslabs/aws-cloudformation-templates

**Pro Tip:** Start simple and build complexity gradually. Even experienced engineers keep templates readable and well-commented!
