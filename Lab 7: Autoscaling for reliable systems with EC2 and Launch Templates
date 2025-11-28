This lab activity will demonstrate how to create a launch template and integrate it into an auto-scaling group. We will then simulate an unhealthy instance by terminating an EC2 instance and observe how EC2 auto-scaling will react.

## Prerequisite:

Before you start following the instructions below, you will need to have the following:

- VPC with at least 2 public subnets
- A security group without inbound rules and make sure it’s attached to your VPC, to create one go to the VPC console and click on security groups.


Once you have created the required resources, you can now proceed to the steps below.

## 1. Create a launch template.

1-a. Navigate to the EC2 console then go to Launch Templates.

1-b. Click create launch template.

1-c. In the Create launch template console, set the name and description of your template. Click the Auto Scaling guidance checkbox.

1-d. Select Amazon Linux 2 AMI ID, for the instance type just use t2.micro, and select Don’t include in launch template for key pair name

1-e. For network settings, choose the security group you created at the start of this lab. Leave subnet to "Do not include in template". Leave the rest of the settings as default, and click on create launch template.


## 2. Create an auto-scaling group.

2-a. Navigate to auto scaling groups. Click create auto scaling group


2-b. Set the name of your auto scaling group, then select your launch template and click next.

2-c. Select Adhere to launch template for the Instance purchase options and select your VPC and public subnets.


2-d. Leave the advance options as default.


2-e. Set the following values.

- Desired capacity: 2
- Minimum capacity: 2
- Maximum capacity: 4



2-f. Leave the notifications as default



2-g. Set the tags, use the key: Name

2-h. Review your configurations and click create autoscaling group


## 3. Test EC2 autoscaling

Now you have created the autoscaling group, let’s now test if our configuration will work properly.

3-a. Navigate to the EC2 console, and you’ll see that you have 2 running instances.


3-b. To test autoscaling, terminate one of the instances.


3-c. Wait for at least a minute and you’ll see that a new instance will be created automatically by EC2 auto-scaling.

4. Cleaning up

To delete the resources, first delete the autoscaling group the instances created will be automatically terminated.
