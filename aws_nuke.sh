#!/usr/bin/env bash
# aws-nuke-lite.sh
# WARNING: Irreversible destructive actions. Only run on accounts you own and intend to destroy.
# Requirements: awscli v2, jq
# Usage: ./aws-nuke-lite.sh
# Optional: to delete IAM resources too: ./aws-nuke-lite.sh --delete-iam

set -euo pipefail

DELETE_IAM=false

for arg in "$@"; do
  case $arg in
    --delete-iam) DELETE_IAM=true ;;
    *) ;;
  esac
done

echo "This script will attempt to delete many AWS resources across ALL regions."
echo "It will not delete Organizations root entities or the AWS account itself."
echo
read -p "Type EXACTLY: I UNDERSTAND DELETE EVERYTHING   : " CONFIRM
if [ "$CONFIRM" != "I UNDERSTAND DELETE EVERYTHING" ]; then
  echo "Confirmation mismatch. Exiting."
  exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "Operating on AWS Account: $ACCOUNT_ID"

# Get regions
REGIONS=$(aws ec2 describe-regions --query "Regions[].RegionName" --output text)

# 1) Delete CloudFormation stacks (all regions) first
echo "=== Deleting CloudFormation stacks (all regions) ==="
for r in $REGIONS; do
  echo "--- Region $r: CloudFormation stacks ---"
  stacks=$(aws cloudformation list-stacks --region $r --query "StackSummaries[?StackStatus!='DELETE_COMPLETE'].StackName" --output text 2>/dev/null || true)
  for s in $stacks; do
    echo "Deleting stack $s in $r"
    aws cloudformation delete-stack --stack-name "$s" --region "$r" || true
    # Wait up to 30m in background: we'll poll non-blocking for a short time later
  done
done

# Optional short wait/poll for stacks to start deleting (but don't block indefinitely)
echo "Waiting 10 seconds for stack deletes to start..."
sleep 10

# Helper: force delete S3 bucket (including versioned)
delete_bucket_force() {
  BUCKET="$1"
  echo "Emptying bucket: $BUCKET"
  # Remove incomplete multipart uploads
  aws s3api list-multipart-uploads --bucket "$BUCKET" --output json 2>/dev/null | jq -r '.Uploads[]? | .UploadId + "::::" + .Key' | while IFS= read -r u; do
    [ -z "$u" ] && continue
    uploadId=$(echo "$u" | cut -d: -f1)
    key=$(echo "$u" | cut -d: -f5-)
    aws s3api abort-multipart-upload --bucket "$BUCKET" --key "$key" --upload-id "$uploadId" || true
  done

  # If versioning enabled, delete all versions and delete markers
  if aws s3api get-bucket-versioning --bucket "$BUCKET" --output text 2>/dev/null | grep -q Enabled; then
    echo "Bucket is versioned; deleting versions..."
    aws s3api list-object-versions --bucket "$BUCKET" --output json \
      | jq -c '.Versions[]?, .DeleteMarkers[]?' \
      | while read -r obj; do
          key=$(echo "$obj" | jq -r .Key)
          ver=$(echo "$obj" | jq -r .VersionId)
          if [ "$key" != "null" ] && [ "$ver" != "null" ]; then
            aws s3api delete-object --bucket "$BUCKET" --key "$key" --version-id "$ver" || true
          fi
        done
  else
    # Non-versioned: recursive remove
    aws s3 rm "s3://$BUCKET" --recursive || true
  fi

  # Finally delete bucket
  aws s3api delete-bucket --bucket "$BUCKET" 2>/dev/null || true
  echo "Deleted bucket: $BUCKET (if empty and permitted)."
}

# 2) Delete global S3 buckets
echo "=== Deleting S3 buckets (global) ==="
buckets=$(aws s3api list-buckets --query "Buckets[].Name" --output text || true)
for b in $buckets; do
  echo "Processing S3 bucket: $b"
  read -p "Delete bucket $b? (yes/no) : " yn
  if [ "$yn" = "yes" ]; then
    delete_bucket_force "$b"
  else
    echo "Skipping $b"
  fi
done

# 3) Region-by-region resource deletion
for r in $REGIONS; do
  echo
  echo "========================"
  echo " REGION: $r"
  echo "========================"

  # EC2: terminate instances
  echo "-> EC2: terminating instances in $r"
  insts=$(aws ec2 describe-instances --region "$r" --query "Reservations[].Instances[].InstanceId" --output text || true)
  if [ -n "$insts" ]; then
    aws ec2 terminate-instances --instance-ids $insts --region "$r" || true
  fi

  # Wait a few seconds
  sleep 3

  # EC2: Delete Auto Scaling Groups (force delete)
  echo "-> AutoScaling: deleting groups in $r"
  asgs=$(aws autoscaling describe-auto-scaling-groups --region "$r" --query "AutoScalingGroups[].AutoScalingGroupName" --output text || true)
  for g in $asgs; do
    echo "Deleting ASG $g"
    aws autoscaling update-auto-scaling-group --auto-scaling-group-name "$g" --min-size 0 --max-size 0 --desired-capacity 0 --region "$r" || true
    aws autoscaling delete-auto-scaling-group --auto-scaling-group-name "$g" --force-delete --region "$r" || true
  done
  # delete launch configurations
  lcs=$(aws autoscaling describe-launch-configurations --region "$r" --query "LaunchConfigurations[].LaunchConfigurationName" --output text || true)
  for lc in $lcs; do
    aws autoscaling delete-launch-configuration --launch-configuration-name "$lc" --region "$r" || true
  done

  # EC2: Release Elastic IPs
  echo "-> EC2: releasing Elastic IPs in $r"
  aws ec2 describe-addresses --region "$r" --query "Addresses[].AllocationId" --output text | while read -r alloc; do
    [ -z "$alloc" ] && continue
    aws ec2 release-address --allocation-id "$alloc" --region "$r" || true
  done || true

  # EC2: Delete security groups (non-default)
  echo "-> EC2: deleting non-default security groups in $r"
  aws ec2 describe-security-groups --region "$r" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text | while read -r sg; do
    [ -z "$sg" ] && continue
    aws ec2 delete-security-group --group-id "$sg" --region "$r" || true
  done || true

  # EC2: delete volumes
  echo "-> EC2: deleting unattached volumes in $r"
  aws ec2 describe-volumes --filters Name=status,Values=available --region "$r" --query "Volumes[].VolumeId" --output text | while read -r vol; do
    [ -z "$vol" ] && continue
    aws ec2 delete-volume --volume-id "$vol" --region "$r" || true
  done || true

  # EC2: Deregister AMIs owned by account and delete snapshots
  echo "-> EC2: deregistering AMIs in $r"
  amis=$(aws ec2 describe-images --owners self --region "$r" --query "Images[].ImageId" --output text || true)
  for ami in $amis; do
    echo "Deregistering AMI $ami"
    aws ec2 deregister-image --image-id "$ami" --region "$r" || true
    # delete related snapshots
    snaps=$(aws ec2 describe-snapshot-attribute --region "$r" --snapshot-id $(aws ec2 describe-snapshots --owner-ids self --region "$r" --query "Snapshots[?Description!=null && contains(Description, '$ami')].SnapshotId" --output text || true) --attribute createVolumePermission 2>/dev/null || true) || true
    # best-effort: delete snapshots owned by account (may include others)
    aws ec2 describe-snapshots --owner-ids self --region "$r" --query "Snapshots[].SnapshotId" --output text | while read -r snap; do
      [ -z "$snap" ] && continue
      aws ec2 delete-snapshot --snapshot-id "$snap" --region "$r" || true
    done || true
  done || true

  # ELBv2 / Classic / Target Groups
  echo "-> ELB: deleting load balancers in $r"
  aws elbv2 describe-load-balancers --region "$r" --query "LoadBalancers[].LoadBalancerArn" --output text | while read -r lb; do
    [ -z "$lb" ] && continue
    aws elbv2 delete-load-balancer --load-balancer-arn "$lb" --region "$r" || true
  done || true

  aws elbv2 describe-target-groups --region "$r" --query "TargetGroups[].TargetGroupArn" --output text | while read -r tg; do
    [ -z "$tg" ] && continue
    aws elbv2 delete-target-group --target-group-arn "$tg" --region "$r" || true
  done || true

  aws elb describe-load-balancers --region "$r" --query "LoadBalancerDescriptions[].LoadBalancerName" --output text | while read -r cl; do
    [ -z "$cl" ] && continue
    aws elb delete-load-balancer --load-balancer-name "$cl" --region "$r" || true
  done || true

  # RDS: delete instances (skip final snapshot)
  echo "-> RDS: deleting instances in $r"
  aws rds describe-db-instances --region "$r" --query "DBInstances[].DBInstanceIdentifier" --output text | while read -r db; do
    [ -z "$db" ] && continue
    echo "Deleting RDS instance $db (skip final snapshot)"
    aws rds delete-db-instance --db-instance-identifier "$db" --skip-final-snapshot --delete-automated-backups --region "$r" || true
  done || true

  # RDS clusters (Aurora)
  aws rds describe-db-clusters --region "$r" --query "DBClusters[].DBClusterIdentifier" --output text | while read -r c; do
    [ -z "$c" ] && continue
    echo "Deleting RDS cluster $c (skip final snapshot)"
    aws rds delete-db-cluster --db-cluster-identifier "$c" --skip-final-snapshot --region "$r" || true
  done || true

  # ElastiCache
  echo "-> ElastiCache: deleting clusters in $r"
  aws elasticache describe-cache-clusters --show-cache-node-info --region "$r" --query "CacheClusters[].CacheClusterId" --output text | while read -r ec; do
    [ -z "$ec" ] && continue
    aws elasticache delete-cache-cluster --cache-cluster-id "$ec" --region "$r" || true
  done || true

  # EFS: delete file systems (need to delete mount targets first)
  echo "-> EFS: deleting file systems in $r"
  aws efs describe-file-systems --region "$r" --query "FileSystems[].FileSystemId" --output text | while read -r fs; do
    [ -z "$fs" ] && continue
    echo "Removing mount targets for $fs"
    aws efs describe-mount-targets --file-system-id "$fs" --region "$r" --query "MountTargets[].MountTargetId" --output text | while read -r mt; do
      [ -z "$mt" ] && continue
      aws efs delete-mount-target --mount-target-id "$mt" --region "$r" || true
    done || true
    sleep 2
    aws efs delete-file-system --file-system-id "$fs" --region "$r" || true
  done || true

  # ECS: delete services & clusters, then deregister task definitions
  echo "-> ECS: deleting services and clusters in $r"
  aws ecs list-clusters --region "$r" --query "clusterArns[]" --output text | while read -r clusterArn; do
    [ -z "$clusterArn" ] && continue
    # drain services
    aws ecs list-services --cluster "$clusterArn" --region "$r" --query "serviceArns[]" --output text | while read -r srv; do
      [ -z "$srv" ] && continue
      aws ecs update-service --cluster "$clusterArn" --service "$srv" --desired-count 0 --region "$r" || true
      aws ecs delete-service --cluster "$clusterArn" --service "$srv" --region "$r" --force || true
    done || true

    # delete cluster
    aws ecs delete-cluster --cluster "$clusterArn" --region "$r" || true
  done || true

  # ECR: delete repositories
  echo "-> ECR: deleting repositories in $r"
  aws ecr describe-repositories --region "$r" --query "repositories[].repositoryName" --output text | while read -r repo; do
    [ -z "$repo" ] && continue
    echo "Deleting ECR repo $repo"
    aws ecr list-images --repository-name "$repo" --region "$r" --query "imageIds[*]" --output json | jq -c '.[]?' | while read -r image; do
      img=$(echo "$image" | jq -r '.imageDigest // empty, .imageTag // empty' | tr '\n' ' ' )
    done || true
    aws ecr delete-repository --repository-name "$repo" --region "$r" --force || true
  done || true

  # Lambda functions
  echo "-> Lambda: deleting functions in $r"
  aws lambda list-functions --region "$r" --query "Functions[].FunctionName" --output text | while read -r fn; do
    [ -z "$fn" ] && continue
    aws lambda delete-function --function-name "$fn" --region "$r" || true
  done || true

  # API Gateway (REST and HTTP)
  echo "-> API Gateway: removing REST APIs in $r"
  aws apigateway get-rest-apis --region "$r" --query "items[].id" --output text | while read -r api; do
    [ -z "$api" ] && continue
    aws apigateway delete-rest-api --rest-api-id "$api" --region "$r" || true
  done || true

  echo "-> API Gateway v2 (HTTP/WebSocket)"
  aws apigatewayv2 get-apis --region "$r" --query "Items[].ApiId" --output text | while read -r aid; do
    [ -z "$aid" ] && continue
    aws apigatewayv2 delete-api --api-id "$aid" --region "$r" || true
  done || true

  # SNS topics
  echo "-> SNS: deleting topics in $r"
  aws sns list-topics --region "$r" --query "Topics[].TopicArn" --output text | while read -r t; do
    [ -z "$t" ] && continue
    aws sns delete-topic --topic-arn "$t" --region "$r" || true
  done || true

  # SQS queues
  echo "-> SQS: deleting queues in $r"
  aws sqs list-queues --region "$r" --query "QueueUrls[]" --output text | while read -r q; do
    [ -z "$q" ] && continue
    aws sqs delete-queue --queue-url "$q" --region "$r" || true
  done || true

  # DynamoDB tables
  echo "-> DynamoDB: deleting tables in $r"
  aws dynamodb list-tables --region "$r" --query "TableNames[]" --output text | while read -r t; do
    [ -z "$t" ] && continue
    aws dynamodb delete-table --table-name "$t" --region "$r" || true
  done || true

  # CloudWatch: log groups and alarms
  echo "-> CloudWatch: deleting log groups and alarms in $r"
  aws logs describe-log-groups --region "$r" --query "logGroups[].logGroupName" --output text | while read -r lg; do
    [ -z "$lg" ] && continue
    aws logs delete-log-group --log-group-name "$lg" --region "$r" || true
  done || true
  aws cloudwatch describe-alarms --region "$r" --query "MetricAlarms[].AlarmName" --output text | while read -r a; do
    [ -z "$a" ] && continue
    aws cloudwatch delete-alarms --alarm-names "$a" --region "$r" || true
  done || true

  # Route53: hosted zones (skip AWS created ones) - hosted zones are global but listing returns hosted zone ids
  echo "-> Route53: (global) - will be handled after region loop"
done

# 4) Global services and cross-region cleanups

# Route53 hosted zones (public/private) - careful: skip the ones not owned by account (check if HostedZone's Config.PrivateZone or if name ends with amazonaws)
echo "=== Route53: deleting hosted zones owned by account ==="
aws route53 list-hosted-zones --query "HostedZones[]" --output json | jq -c '.[]' | while read -r hz; do
  zoneid=$(echo "$hz" | jq -r .Id | sed 's|/hostedzone/||')
  name=$(echo "$hz" | jq -r .Name)
  # Skip aws default zones that can't be deleted
  echo "Processing zone $name ($zoneid)"
  # Get record sets (exclude SOA and NS)
  records=$(aws route53 list-resource-record-sets --hosted-zone-id "$zoneid" --query "ResourceRecordSets[?Type!='NS'&&Type!='SOA']" --output json)
  if [ "$(echo "$records" | jq 'length')" -gt 0 ]; then
    # Build change batch to delete all non-NS/SOA records
    changes=$(echo "$records" | jq -c '[.[] | {Action: "DELETE", ResourceRecordSet: .}]')
    if [ "$(echo "$changes" | jq 'length')" -gt 0 ]; then
      echo "Deleting non-NS/SOA records in $name"
      aws route53 change-resource-record-sets --hosted-zone-id "$zoneid" --change-batch "{\"Changes\": $changes}" || true
    fi
  fi
  echo "Deleting hosted zone $name"
  aws route53 delete-hosted-zone --id "$zoneid" || true
done || true

# CloudFormation: wait and force-delete any stacks still present (best-effort)
echo "=== Ensuring remaining CloudFormation stacks are deleted (best-effort) ==="
for r in $REGIONS; do
  aws cloudformation list-stacks --region "$r" --query "StackSummaries[?StackStatus!='DELETE_COMPLETE'].StackName" --output text | while read -r s; do
    [ -z "$s" ] && continue
    echo "Forcing delete of stack $s in $r"
    aws cloudformation delete-stack --stack-name "$s" --region "$r" || true
  done || true
done

# Delete KMS keys by scheduling key deletion (can't immediately delete some keys)
echo "=== KMS keys: scheduling deletion (7 days) ==="
aws kms list-keys --query "Keys[].KeyId" --output text | while read -r kid; do
  [ -z "$kid" ] && continue
  echo "Scheduling deletion for KMS key $kid (7 days)"
  aws kms schedule-key-deletion --key-id "$kid" --pending-window-in-days 7 || true
done || true

# Delete CloudWatch log groups (global done per-region earlier) - also delete log streams etc already attempted.

# Delete CloudTrail trails (global)
echo "=== CloudTrail: deleting trails ==="
aws cloudtrail describe-trails --query "trailList[].Name" --output text | while read -r t; do
  [ -z "$t" ] && continue
  echo "Deleting CloudTrail: $t"
  aws cloudtrail delete-trail --name "$t" || true
done || true

# Delete CloudWatch Event Rules (EventBridge)
echo "=== EventBridge rules: deleting rules and targets ==="
aws events list-rules --query "Rules[].Name" --output text | while read -r rule; do
  [ -z "$rule" ] && continue
  echo "Removing targets and deleting rule: $rule"
  targets=$(aws events list-targets-by-rule --rule "$rule" --query "Targets[].Id" --output text || true)
  if [ -n "$targets" ]; then
    aws events remove-targets --rule "$rule" --ids $targets || true
  fi
  aws events delete-rule --name "$rule" || true
done || true

# ECR images and repositories (global done per-region earlier)
# Marketplace Entitlements: cannot be programmatically unsubscribed in many cases; manual.

# Delete snapshots owned by account (ec2 snapshots)
echo "=== EC2 snapshots: deleting snapshots owned by account ==="
aws ec2 describe-snapshots --owner-ids self --query "Snapshots[].SnapshotId" --output text | while read -r s; do
  [ -z "$s" ] && continue
  aws ec2 delete-snapshot --snapshot-id "$s" || true
done || true

# Delete AMIs handled regionally earlier (deregister), but attempt global deregister of remaining images
echo "=== Final AMI deregister attempts (across regions) ==="
for r in $REGIONS; do
  aws ec2 describe-images --owners self --region "$r" --query "Images[].ImageId" --output text | while read -r ami; do
    [ -z "$ami" ] && continue
    aws ec2 deregister-image --image-id "$ami" --region "$r" || true
  done || true
done

# Optionally delete IAM resources (users, groups, roles, policies)
if [ "$DELETE_IAM" = true ]; then
  echo "=== Deleting IAM resources (users, roles, policies) ==="
  # Detach and delete inline and managed policies for users
  aws iam list-users --query "Users[].UserName" --output text | while read -r u; do
    [ -z "$u" ] && continue
    echo "Cleaning user $u"
    aws iam list-user-policies --user-name "$u" --query "PolicyNames[]" --output text | while read -r ip; do
      aws iam delete-user-policy --user-name "$u" --policy-name "$ip" || true
    done || true
    aws iam list-attached-user-policies --user-name "$u" --query "AttachedPolicies[].PolicyArn" --output text | while read -r pap; do
      aws iam detach-user-policy --user-name "$u" --policy-arn "$pap" || true
    done || true
    # Remove access keys
    aws iam list-access-keys --user-name "$u" --query "AccessKeyMetadata[].AccessKeyId" --output text | while read -r ak; do
      [ -z "$ak" ] && continue
      aws iam delete-access-key --user-name "$u" --access-key-id "$ak" || true
    done || true
    aws iam delete-user --user-name "$u" || true
  done || true

  # Roles
  aws iam list-roles --query "Roles[].RoleName" --output text | while read -r rname; do
    [ -z "$rname" ] && continue
    echo "Cleaning role $rname"
    aws iam list-role-policies --role-name "$rname" --query "PolicyNames[]" --output text | while read -r rp; do
      aws iam delete-role-policy --role-name "$rname" --policy-name "$rp" || true
    done || true
    aws iam list-attached-role-policies --role-name "$rname" --query "AttachedPolicies[].PolicyArn" --output text | while read -r rp2; do
      aws iam detach-role-policy --role-name "$rname" --policy-arn "$rp2" || true
    done || true
    # Remove instance profile associations, then delete instance profiles
    aws iam list-instance-profiles-for-role --role-name "$rname" --query "InstanceProfiles[].InstanceProfileName" --output text | while read -r ipn; do
      [ -z "$ipn" ] && continue
      aws iam remove-role-from-instance-profile --instance-profile-name "$ipn" --role-name "$rname" || true
      aws iam delete-instance-profile --instance-profile-name "$ipn" || true
    done || true
    aws iam delete-role --role-name "$rname" || true
  done || true

  # Policies
  echo "Deleting customer-managed policies"
  aws iam list-policies --scope Local --query "Policies[].Arn" --output text | while read -r par; do
    [ -z "$par" ] && continue
    # detach from entities first
    aws iam list-entities-for-policy --policy-arn "$par" --query "PolicyRoles[].RoleName" --output text | while read -r rn; do aws iam detach-role-policy --role-name "$rn" --policy-arn "$par" || true; done || true
    aws iam list-entities-for-policy --policy-arn "$par" --query "PolicyUsers[].UserName" --output text | while read -r un; do aws iam detach-user-policy --user-name "$un" --policy-arn "$par" || true; done || true
    aws iam list-entities-for-policy --policy-arn "$par" --query "PolicyGroups[].GroupName" --output text | while read -r gn; do aws iam detach-group-policy --group-name "$gn" --policy-arn "$par" || true; done || true
    aws iam delete-policy --policy-arn "$par" || true
  done || true
else
  echo "IAM deletion skipped. Use --delete-iam to remove IAM resources (dangerous)."
fi

echo
echo "=== FINAL SWEEP: taggable resource remover via Resource Groups Tagging API ==="
# This will find taggable resources (many types) and attempt deletion via service-specific calls when possible.
aws resourcegroupstaggingapi get-resources --resource-type-filters '*' --query "ResourceTagMappingList[].ResourceARN" --output text | while read -r arn; do
  [ -z "$arn" ] && continue
  echo "Found resource ARN (attempting delete where obvious): $arn"
  # best-effort heuristics:
  case "$arn" in
    arn:aws:rds:*) id=$(echo "$arn" | awk -F: '{print $NF}'); echo "Deleting RDS resource $id"; aws rds delete-db-instance --db-instance-identifier "$id" --skip-final-snapshot --region ${arn#arn:aws:rds:} || true ;;
    arn:aws:ecs:*) cluster=$(echo "$arn" | awk -F/ '{print $2}'); echo "Deleting ECS cluster $cluster"; aws ecs delete-cluster --cluster "$cluster" --region ${arn#arn:aws:ecs:} || true ;;
    arn:aws:ecr:*) repo=$(basename "$arn"); echo "Deleting ECR repo $repo"; aws ecr delete-repository --repository-name "$repo" --force --region ${arn#arn:aws:ecr:} || true ;;
    arn:aws:s3:::*) b=$(echo "$arn" | sed 's|arn:aws:s3:::||'); echo "Deleting S3 $b"; delete_bucket_force "$b" || true ;;
    *) echo "No automatic action defined for $arn (you may need to remove manually)." ;;
  esac
done || true

echo
echo "Cleanup complete (best-effort)."
echo "Notes / next steps:"
echo " - Some services like KMS keys were scheduled for deletion (7 days)."
echo " - Marketplace subscriptions, AWS Organizations, service-linked resources, and some managed services may require manual removal."
echo " - If CloudFormation stacks remain, check their events to identify blocking resources and remove them manually."
echo " - If you used --delete-iam, IAM changes were performed; validate that there are no leftover principals."
echo
echo "Done."
