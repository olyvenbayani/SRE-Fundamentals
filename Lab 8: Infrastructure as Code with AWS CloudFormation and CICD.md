Welcome to Lab 8 of the SRE Workshop! This hands-on activity introduces you to Infrastructure as Code (IaC) by comparing manual CI/CD pipeline setup versus automated deployment using AWS CloudFormation. You'll experience firsthand how IaC improves reliability, consistency, and repeatability in SRE practices. We'll deploy a simple CI/CD pipeline for a web application using both approaches, then reflect on the benefits of automation.

This guide is designed for beginners with basic AWS knowledge. Each step includes explanations, troubleshooting tips, and clear comparisons between manual and IaC approaches. We'll use AWS Free Tier resources where possible, but monitor your usage to avoid unexpected charges.

**Time Estimate:** 90-120 minutes.  
**Goals:**  
- Understand the concept of Infrastructure as Code (IaC).  
- Experience the pain points of manual infrastructure setup.  
- Learn how to automate infrastructure deployment with AWS CloudFormation.  
- Deploy a simple CI/CD pipeline both manually and with IaC.  
- Compare the two approaches and understand IaC benefits for SRE.

**Prerequisites:**  
- AWS account (free tier eligible—sign up at aws.amazon.com if needed).  
- Basic understanding of CI/CD concepts.  
- Familiarity with AWS Console from previous labs.  
- GitHub account (free).  
- Basic knowledge of YAML format.

**Important Notes:**  
- Costs: Most resources are free tier eligible, but CodePipeline and CodeBuild have limits. Clean up after lab to avoid charges.  
- Regions: Use us-east-1 (N. Virginia) for consistency.  
- Time commitment: The manual approach takes longer; that's intentional to demonstrate IaC value!

---

## Part 1: Manual CI/CD Pipeline Setup (The Hard Way)

### Step 1: Prepare Your Sample Application

**Why?** We need a simple application to deploy. We'll use a basic static website stored in GitHub.

1. **Fork the Sample Repository:**
   - Go to: https://github.com/aws-samples/aws-codepipeline-s3-aws-codedeploy_linux (or create your own simple repo with an `index.html`)
   - Alternative: Create a new GitHub repository named `simple-webapp-lab8`
   - Add a simple `index.html` file:
     ```html
     <!DOCTYPE html>
     <html>
     <head>
         <title>Lab 8 - IaC Demo</title>
         <style>
             body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
             h1 { color: #FF9900; }
         </style>
     </head>
     <body>
         <h1>Welcome to Lab 8!</h1>
         <p>This is a demo for Infrastructure as Code with AWS CloudFormation.</p>
         <p>Version: 1.0 (Manual Setup)</p>
     </body>
     </html>
     ```
   - Commit and push to your repository.

2. **Note your repository details:**
   - Repository owner (your GitHub username)
   - Repository name
   - Branch name (usually `main` or `master`)

**Explanation:** This simple HTML site will be deployed through our CI/CD pipeline. The version number helps us verify deployments.

---

### Step 2: Create an S3 Bucket for Hosting (Manual)

**Why?** S3 can host static websites. This is our deployment target.

1. **Navigate to S3:**
   - AWS Console > S3 > Create bucket
   
2. **Configure the bucket:**
   - Bucket name: `lab8-manual-webapp-{your-name}` (must be globally unique, replace `{your-name}`)
   - Region: us-east-1
   - Uncheck "Block all public access" (we need public access for website hosting)
   - Acknowledge the warning about public access
   - Leave other settings as default
   - Create bucket

3. **Enable static website hosting:**
   - Click on your bucket > Properties tab
   - Scroll to "Static website hosting" > Edit
   - Enable static website hosting
   - Index document: `index.html`
   - Save changes
   - Note the bucket website endpoint (e.g., `http://lab8-manual-webapp-yourname.s3-website-us-east-1.amazonaws.com`)

4. **Add a bucket policy for public read access:**
   - Permissions tab > Bucket policy > Edit
   - Add this policy (replace `YOUR-BUCKET-NAME`):
     ```json
     {
       "Version": "2012-10-17",
       "Statement": [
         {
           "Sid": "PublicReadGetObject",
           "Effect": "Allow",
           "Principal": "*",
           "Action": "s3:GetObject",
           "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME/*"
         }
       ]
     }
     ```
   - Save changes

**Troubleshooting:**  
- Bucket name taken? Add more unique identifiers (date, numbers).  
- Access denied errors? Ensure public access settings are correct.

---

### Step 3: Create IAM Roles for CodePipeline and CodeBuild (Manual)

**Why?** AWS services need permissions to access other services. This is tedious but necessary.

**Create CodePipeline Role:**

1. AWS Console > IAM > Roles > Create role
2. Trusted entity: AWS service > CodePipeline > Next
3. Permissions: AWS managed policy `AWSCodePipelineFullAccess`
4. Add additional permissions:
   - Click "Create policy" (opens new tab)
   - JSON tab, paste:
     ```json
     {
       "Version": "2012-10-17",
       "Statement": [
         {
           "Effect": "Allow",
           "Action": [
             "s3:*",
             "codebuild:*",
             "codestar-connections:*"
           ],
           "Resource": "*"
         }
       ]
     }
     ```
   - Name: `Lab8-CodePipeline-S3-Policy`
   - Create policy
5. Back to create role tab, refresh policies, attach `Lab8-CodePipeline-S3-Policy`
6. Role name: `Lab8-CodePipeline-Role-Manual`
7. Create role

**Create CodeBuild Role:**

1. IAM > Roles > Create role
2. Trusted entity: AWS service > CodeBuild > Next
3. Attach policies:
   - `AmazonS3FullAccess`
   - `CloudWatchLogsFullAccess`
4. Role name: `Lab8-CodeBuild-Role-Manual`
5. Create role

**Explanation:** These roles define what actions CodePipeline and CodeBuild can perform. Manual creation is error-prone!

**Troubleshooting:**  
- Missing permissions? Add them to the role's policy later if pipeline fails.

---

### Step 4: Create a CodeBuild Project (Manual)

**Why?** CodeBuild will "build" our application (in this case, just prepare files for deployment).

1. **Navigate to CodeBuild:**
   - AWS Console > CodeBuild > Create build project

2. **Configure project:**
   - Project name: `Lab8-BuildProject-Manual`
   - Source provider: GitHub
   - Connect to GitHub: Follow OAuth prompts to authorize AWS
   - Repository: Select your repository
   - Branch/tag: `refs/heads/main` (or your branch name)
   
3. **Environment:**
   - Environment image: Managed image
   - Operating system: Amazon Linux 2
   - Runtime: Standard
   - Image: aws/codebuild/amazonlinux2-x86_64-standard:4.0
   - Service role: Existing service role
   - Role name: `Lab8-CodeBuild-Role-Manual`

4. **Buildspec:**
   - Use a buildspec file
   - (We'll create `buildspec.yml` in the repository later)

5. **Artifacts:**
   - Type: Amazon S3
   - Bucket name: Select your `lab8-manual-webapp-{your-name}` bucket
   - Name: Leave empty (will use project name)
   - Artifacts packaging: None

6. **Logs:**
   - CloudWatch logs - enabled (default)

7. **Create build project**

**Explanation:** CodeBuild executes build instructions defined in `buildspec.yml`. We'll add that file next.

---

### Step 5: Add buildspec.yml to Your Repository

**Why?** This file tells CodeBuild what to do with your code.

1. **In your GitHub repository, create `buildspec.yml`:**
   ```yaml
   version: 0.2
   
   phases:
     install:
       runtime-versions:
         nodejs: 16
     build:
       commands:
         - echo "Build started on `date`"
         - echo "No build needed for static site, just copying files..."
   
   artifacts:
     files:
       - '**/*'
     name: BuildArtifact
   ```

2. **Commit and push to GitHub**

**Explanation:** For a static site, we don't compile anything, just package files as artifacts.

---

### Step 6: Create CodePipeline (Manual)

**Why?** CodePipeline orchestrates the CI/CD flow: source → build → deploy.

1. **Navigate to CodePipeline:**
   - AWS Console > CodePipeline > Create pipeline

2. **Pipeline settings:**
   - Pipeline name: `Lab8-Pipeline-Manual`
   - Service role: Existing service role
   - Role name: `Lab8-CodePipeline-Role-Manual`
   - Allow AWS CodePipeline to create a service role: Leave unchecked
   - Next

3. **Add source stage:**
   - Source provider: GitHub (Version 2)
   - Connection: Create new connection
     - Connection name: `Lab8-GitHub-Connection`
     - Follow prompts to authorize GitHub app
   - Repository name: Select your repository
   - Branch name: `main`
   - Output artifact format: CodePipeline default
   - Next

4. **Add build stage:**
   - Build provider: AWS CodeBuild
   - Project name: `Lab8-BuildProject-Manual`
   - Next

5. **Add deploy stage:**
   - Deploy provider: Amazon S3
   - Bucket: `lab8-manual-webapp-{your-name}`
   - Extract file before deploy: Checked
   - Next

6. **Review and create pipeline**

**Explanation:** The pipeline automatically runs when you push to GitHub, builds with CodeBuild, and deploys to S3.

**Troubleshooting:**  
- Pipeline fails? Check IAM role permissions.  
- GitHub connection issues? Ensure the GitHub app is authorized.

---

### Step 7: Test the Manual Pipeline

**Why?** Verify everything works.

1. **Watch the pipeline execute:**
   - CodePipeline console > View pipeline
   - Each stage (Source, Build, Deploy) should show progress
   - Wait for all stages to succeed (green checkmarks)

2. **Verify deployment:**
   - Open your S3 bucket website endpoint in a browser
   - You should see your HTML page with "Version: 1.0 (Manual Setup)"

3. **Test the CI/CD flow:**
   - Edit `index.html` in GitHub
   - Change version to "1.1 (Manual - Updated)"
   - Commit and push
   - Watch the pipeline automatically trigger and deploy
   - Refresh your website to see the update

**Explanation:** This proves the manual pipeline works, but note how many steps it took!

**Troubleshooting:**  
- Deployment doesn't show? Check S3 bucket policy and website hosting settings.  
- Old version still showing? Clear browser cache or wait a minute.

---

### Step 8: Document Your Manual Experience

**Why?** Reflecting on pain points highlights IaC benefits.

Create a file `manual-notes.md` and note:
- How long did setup take?
- How many console screens did you navigate?
- What could go wrong if you had to recreate this in another region?
- How would you share this setup with a teammate?

**Key Pain Points:**  
- **Time-consuming:** Many manual clicks and configurations  
- **Error-prone:** Easy to misconfigure permissions or settings  
- **Not repeatable:** Hard to recreate exactly  
- **No version control:** Changes aren't tracked  
- **Documentation burden:** Must manually document each step

---

## Part 2: Infrastructure as Code with CloudFormation (The Right Way)

### Step 9: Clean Up Manual Resources (Optional)

**Why?** To clearly demonstrate IaC creates everything fresh, you can delete manual resources. Or keep them for comparison.

If deleting:
1. CodePipeline console > Delete pipeline `Lab8-Pipeline-Manual`
2. CodeBuild > Delete build project `Lab8-BuildProject-Manual`
3. S3 > Empty and delete bucket `lab8-manual-webapp-{your-name}`
4. IAM > Delete roles `Lab8-CodePipeline-Role-Manual` and `Lab8-CodeBuild-Role-Manual`

**Or:** Just use different names for IaC resources (recommended to compare side-by-side).

---

### Step 10: Create CloudFormation Template

**Why?** A single YAML file will define ALL infrastructure: S3 bucket, IAM roles, CodeBuild project, and CodePipeline.

Create a file `pipeline-infrastructure.yaml`:

```yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: 'Lab 8 - Complete CI/CD Pipeline Infrastructure using CloudFormation'

Parameters:
  GitHubOwner:
    Type: String
    Description: GitHub repository owner (your username)
  
  GitHubRepo:
    Type: String
    Description: GitHub repository name
    Default: simple-webapp-lab8
  
  GitHubBranch:
    Type: String
    Description: GitHub branch name
    Default: main
  
  GitHubConnectionArn:
    Type: String
    Description: ARN of the CodeStar Connections connection to GitHub (create manually first)

Resources:
  # S3 Bucket for website hosting
  WebsiteBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub 'lab8-iac-webapp-${AWS::AccountId}'
      WebsiteConfiguration:
        IndexDocument: index.html
      PublicAccessBlockConfiguration:
        BlockPublicAcls: false
        BlockPublicPolicy: false
        IgnorePublicAcls: false
        RestrictPublicBuckets: false

  # Bucket policy for public read access
  WebsiteBucketPolicy:
    Type: AWS::S3::BucketPolicy
    Properties:
      Bucket: !Ref WebsiteBucket
      PolicyDocument:
        Statement:
          - Sid: PublicReadGetObject
            Effect: Allow
            Principal: '*'
            Action: 's3:GetObject'
            Resource: !Sub '${WebsiteBucket.Arn}/*'

  # S3 Bucket for CodePipeline artifacts
  ArtifactBucket:
    Type: AWS::S3::Bucket
    Properties:
      BucketName: !Sub 'lab8-pipeline-artifacts-${AWS::AccountId}'
      VersioningConfiguration:
        Status: Enabled

  # IAM Role for CodePipeline
  CodePipelineRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: Lab8-CodePipeline-Role-IaC
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: codepipeline.amazonaws.com
            Action: 'sts:AssumeRole'
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/AWSCodePipelineFullAccess
      Policies:
        - PolicyName: CodePipelinePolicy
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - Effect: Allow
                Action:
                  - 's3:*'
                  - 'codebuild:*'
                  - 'codestar-connections:UseConnection'
                Resource: '*'

  # IAM Role for CodeBuild
  CodeBuildRole:
    Type: AWS::IAM::Role
    Properties:
      RoleName: Lab8-CodeBuild-Role-IaC
      AssumeRolePolicyDocument:
        Version: '2012-10-17'
        Statement:
          - Effect: Allow
            Principal:
              Service: codebuild.amazonaws.com
            Action: 'sts:AssumeRole'
      ManagedPolicyArns:
        - arn:aws:iam::aws:policy/AmazonS3FullAccess
        - arn:aws:iam::aws:policy/CloudWatchLogsFullAccess

  # CodeBuild Project
  BuildProject:
    Type: AWS::CodeBuild::Project
    Properties:
      Name: Lab8-BuildProject-IaC
      ServiceRole: !GetAtt CodeBuildRole.Arn
      Artifacts:
        Type: CODEPIPELINE
      Environment:
        Type: LINUX_CONTAINER
        ComputeType: BUILD_GENERAL1_SMALL
        Image: aws/codebuild/amazonlinux2-x86_64-standard:4.0
      Source:
        Type: CODEPIPELINE
        BuildSpec: buildspec.yml
      LogsConfig:
        CloudWatchLogs:
          Status: ENABLED

  # CodePipeline
  Pipeline:
    Type: AWS::CodePipeline::Pipeline
    Properties:
      Name: Lab8-Pipeline-IaC
      RoleArn: !GetAtt CodePipelineRole.Arn
      ArtifactStore:
        Type: S3
        Location: !Ref ArtifactBucket
      Stages:
        - Name: Source
          Actions:
            - Name: SourceAction
              ActionTypeId:
                Category: Source
                Owner: AWS
                Provider: CodeStarSourceConnection
                Version: '1'
              Configuration:
                ConnectionArn: !Ref GitHubConnectionArn
                FullRepositoryId: !Sub '${GitHubOwner}/${GitHubRepo}'
                BranchName: !Ref GitHubBranch
                OutputArtifactFormat: CODE_ZIP
              OutputArtifacts:
                - Name: SourceOutput
        
        - Name: Build
          Actions:
            - Name: BuildAction
              ActionTypeId:
                Category: Build
                Owner: AWS
                Provider: CodeBuild
                Version: '1'
              Configuration:
                ProjectName: !Ref BuildProject
              InputArtifacts:
                - Name: SourceOutput
              OutputArtifacts:
                - Name: BuildOutput
        
        - Name: Deploy
          Actions:
            - Name: DeployAction
              ActionTypeId:
                Category: Deploy
                Owner: AWS
                Provider: S3
                Version: '1'
              Configuration:
                BucketName: !Ref WebsiteBucket
                Extract: true
              InputArtifacts:
                - Name: BuildOutput

Outputs:
  WebsiteURL:
    Description: URL of the website hosted on S3
    Value: !GetAtt WebsiteBucket.WebsiteURL
  
  PipelineName:
    Description: Name of the CodePipeline
    Value: !Ref Pipeline
  
  WebsiteBucketName:
    Description: Name of the S3 bucket hosting the website
    Value: !Ref WebsiteBucket
```

**Explanation:**  
- **One file, entire infrastructure:** Everything we created manually is now code  
- **Parameters:** Make the template reusable  
- **Resources:** Define all AWS services with proper dependencies  
- **Outputs:** Provide useful information after stack creation  
- **Note:** The GitHub connection must be created first (one-time manual step for security)

---

### Step 11: Create GitHub Connection for CloudFormation

**Why?** GitHub connections can't be fully automated due to OAuth security. We create this once, then reference it in CloudFormation.

1. **AWS Console > CodePipeline > Settings > Connections**
2. **Create connection:**
   - Provider: GitHub
   - Connection name: `Lab8-GitHub-Connection-IaC`
   - Connect to GitHub > Install a new app or use existing
   - Authorize AWS Connector for GitHub
3. **Copy the connection ARN** (looks like: `arn:aws:codestar-connections:us-east-1:123456789012:connection/abc-123`)
4. **Note this ARN** – you'll use it in the next step

**Explanation:** This is the only manual prerequisite. Everything else is automated!

---

### Step 12: Update Your HTML for IaC Version

**Why?** Distinguish IaC deployment from manual.

Update `index.html` in your repository:
```html
<!DOCTYPE html>
<html>
<head>
    <title>Lab 8 - IaC Demo</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; }
        h1 { color: #FFD700; }
        .badge { background: #FF9900; padding: 10px 20px; border-radius: 5px; display: inline-block; margin-top: 20px; }
    </style>
</head>
<body>
    <h1>🚀 Welcome to Lab 8 - IaC Edition!</h1>
    <p>This infrastructure was deployed using AWS CloudFormation.</p>
    <div class="badge">Version: 2.0 (IaC Automated)</div>
    <p style="margin-top: 30px;">
        <strong>Benefits of IaC:</strong><br>
        ✅ Version controlled<br>
        ✅ Repeatable<br>
        ✅ Fast deployment<br>
        ✅ Consistent environments
    </p>
</body>
</html>
```

Commit and push to GitHub.

---

### Step 13: Deploy Infrastructure with CloudFormation

**Why?** Watch as one command creates everything!

1. **Upload template to S3 (or use local file):**
   - Option A: AWS Console > CloudFormation > Create stack > Upload template file
   - Option B: Use AWS CLI (faster for repeated deployments)

2. **Using AWS Console:**
   - AWS Console > CloudFormation > Create stack > With new resources
   - Template source: Upload a template file
   - Upload `pipeline-infrastructure.yaml`
   - Next

3. **Specify stack details:**
   - Stack name: `Lab8-IaC-Pipeline-Stack`
   - Parameters:
     - GitHubOwner: `your-github-username`
     - GitHubRepo: `simple-webapp-lab8`
     - GitHubBranch: `main`
     - GitHubConnectionArn: `paste-your-connection-arn-from-step-11`
   - Next

4. **Configure stack options:**
   - Tags (optional): Key=`Lab`, Value=`Lab8-IaC`
   - Permissions: Leave default
   - Next

5. **Review:**
   - Acknowledge: "I acknowledge that AWS CloudFormation might create IAM resources"
   - Create stack

6. **Watch the magic happen:**
   - Events tab shows real-time progress
   - Resources tab shows each resource being created
   - Wait 3-5 minutes for `CREATE_COMPLETE` status

**Alternative - Using AWS CLI (Advanced):**
```bash
aws cloudformation create-stack \
  --stack-name Lab8-IaC-Pipeline-Stack \
  --template-body file://pipeline-infrastructure.yaml \
  --parameters \
    ParameterKey=GitHubOwner,ParameterValue=your-username \
    ParameterKey=GitHubRepo,ParameterValue=simple-webapp-lab8 \
    ParameterKey=GitHubBranch,ParameterValue=main \
    ParameterKey=GitHubConnectionArn,ParameterValue=your-connection-arn \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

**Explanation:**  
- CloudFormation reads the template and creates resources in the correct order  
- Dependencies are managed automatically (e.g., roles before pipeline)  
- `CAPABILITY_NAMED_IAM` acknowledges creating named IAM resources

**Troubleshooting:**  
- Stack creation fails? Check Events tab for specific error  
- IAM permission errors? Ensure your AWS user can create stacks  
- Parameter validation errors? Double-check GitHub connection ARN format

---

### Step 14: Verify IaC Deployment

**Why?** Confirm everything works and compare with manual approach.

1. **Check stack outputs:**
   - CloudFormation > Stacks > Lab8-IaC-Pipeline-Stack > Outputs tab
   - Copy the `WebsiteURL` value
   - Open in browser – see your updated IaC version page!

2. **Verify pipeline:**
   - CodePipeline console > `Lab8-Pipeline-IaC`
   - Pipeline should have executed automatically
   - All stages should be green (Success)

3. **Test the CI/CD flow:**
   - Edit `index.html` in GitHub
   - Change version to "2.1 (IaC - Updated)"
   - Add a line: `<p>Infrastructure changes are now version controlled!</p>`
   - Commit and push
   - Watch pipeline automatically trigger
   - Refresh website to see changes

**Explanation:** The IaC pipeline works identically to manual, but was created in minutes vs. hours!

---

### Step 15: Compare Manual vs. IaC Approaches

**Why?** This comparison solidifies understanding of IaC benefits for SRE.

Create a comparison document in your repository: `comparison.md`

```markdown
# Manual vs. IaC Comparison - Lab 8

## Setup Time
- **Manual:** 60-90 minutes of clicking through AWS Console
- **IaC:** 5-10 minutes (after template is written)

## Reproducibility
- **Manual:** Must repeat all steps, high chance of errors
- **IaC:** Run same template, identical results every time

## Documentation
- **Manual:** Requires separate written guide (this lab!)
- **IaC:** Template IS the documentation

## Version Control
- **Manual:** Changes not tracked, no diff/history
- **IaC:** Full Git history, code review possible

## Multi-Environment
- **Manual:** Repeat all steps for dev/staging/prod
- **IaC:** Same template with different parameters

## Team Collaboration
- **Manual:** Hard to share knowledge, tribal knowledge
- **IaC:** Pull request workflow, reviewable changes

## Error Detection
- **Manual:** Find errors at runtime
- **IaC:** CloudFormation validates before creating

## Cleanup
- **Manual:** Must delete resources individually
- **IaC:** Delete entire stack in one action

## SRE Benefits
- **Reliability:** Consistent, tested configurations
- **Repeatability:** Disaster recovery becomes trivial
- **Scalability:** Easily create multiple environments
- **Auditability:** All changes tracked in version control
```
---

## Key Takeaways

✅ **IaC transforms infrastructure management:** From manual, error-prone processes to automated, reliable deployments  

✅ **CloudFormation as IaC tool:** Declarative templates define desired state, AWS handles implementation  

✅ **SRE benefits:**
   - **Reliability:** Eliminates configuration drift and manual errors
   - **Repeatability:** Identical environments every time
   - **Speed:** Deploy in minutes instead of hours
   - **Auditability:** Git history of all infrastructure changes
   - **Disaster Recovery:** Restore entire environments quickly

✅ **CI/CD with IaC:** Pipelines become code, following software development best practices  

✅ **Team collaboration:** Infrastructure changes go through code review, just like application code

---

## Troubleshooting Guide

**CloudFormation Stack Creation Fails:**
- Check Events tab for specific error messages
- Common issues:
  - IAM permission errors: Ensure your user can create IAM roles
  - Parameter validation: Verify GitHub connection ARN format
  - Resource naming conflicts: Use unique stack names

**Pipeline Not Triggering:**
- Verify GitHub connection is "Available" status
- Check CodePipeline execution history for errors
- Ensure repository and branch names are correct

**Website Not Accessible:**
- Confirm S3 bucket policy allows public access
- Check that website hosting is enabled
- Verify the URL format: `http://bucket-name.s3-website-region.amazonaws.com`

**Build Failures:**
- Check CodeBuild logs in CloudWatch
- Verify `buildspec.yml` syntax
- Ensure all file paths in buildspec are correct

**Stack Deletion Stuck:**
- Empty S3 buckets before deleting stack
- Check for resources created outside the stack (e.g., ENIs from VPC)
- Use "Retain" deletion policy for resources you want to keep

---

## Additional Resources

- [AWS CloudFormation Documentation](https://docs.aws.amazon.com/cloudformation/)
- [CloudFormation Best Practices](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/best-practices.html)
- [AWS CodePipeline User Guide](https://docs.aws.amazon.com/codepipeline/)
- [Infrastructure as Code Book by Kief Morris](https://www.oreilly.com/library/view/infrastructure-as-code/9781098114664/)
- [SRE Book - Chapter on Release Engineering](https://sre.google/sre-book/release-engineering/)

---

**Congratulations!** You've completed Lab 8! You now understand the fundamental difference between manual infrastructure management and Infrastructure as Code. You've seen firsthand how IaC improves reliability, repeatability, and speed—core SRE principles.

**Next Steps:**
- Explore other IaC tools: Terraform, AWS CDK, Pulumi
- Apply IaC to your own projects
- Learn about GitOps: IaC + Git + CI/CD = Infrastructure automation nirvana

Save this guide as `lab8-guide.md`. Ready to take SRE to the next level with IaC? 🚀
