#!/usr/bin/env bash
set -euo pipefail

# ====== Config (override via env if you want) ======
REGION="${REGION:-us-east-1}"
CLUSTER="${CLUSTER:-parcelpro}"
SERVICE="${SERVICE:-parcelpro-web}"

# If you already created these earlier, you can export them before running.
# Otherwise the script will attempt to resolve them by name.
SG="${SG:-}"           # e.g. sg-xxxxxxxx
TG_ARN="${TG_ARN:-}"   # e.g. arn:aws:elasticloadbalancing:...:targetgroup/parcelpro-tg/...

ALB_NAME="${ALB_NAME:-parcelpro-alb}"
TG_NAME="${TG_NAME:-parcelpro-tg}"
SG_NAME="${SG_NAME:-parcelpro-sg}"

echo "=== Inputs ================================"
echo "REGION        : $REGION"
echo "CLUSTER       : $CLUSTER"
echo "SERVICE       : $SERVICE"
echo "ALB_NAME      : $ALB_NAME"
echo "TG_NAME       : $TG_NAME"
echo "SG_NAME       : $SG_NAME"
echo "Provided SG   : ${SG:-<auto>}"
echo "Provided TG_ARN: ${TG_ARN:-<auto>}"
echo "==========================================="

# ----- Resolve Target Group ARN if not provided -----
if [[ -z "${TG_ARN}" ]]; then
  echo "Resolving TG ARN by name: $TG_NAME"
  TG_ARN="$(aws elbv2 describe-target-groups \
    --names "$TG_NAME" \
    --region "$REGION" \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text 2>/dev/null || true)"
  [[ -z "$TG_ARN" || "$TG_ARN" == "None" ]] && { echo "ERROR: Target group '$TG_NAME' not found. Export TG_ARN or create TG."; exit 1; }
fi

# ----- Resolve Security Group if not provided -----
if [[ -z "${SG}" ]]; then
  echo "Resolving SG by name: $SG_NAME"
  SG="$(aws ec2 describe-security-groups \
    --filters Name=group-name,Values="$SG_NAME" \
    --region "$REGION" \
    --query 'SecurityGroups[0].GroupId' \
    --output text 2>/dev/null || true)"
  [[ -z "$SG" || "$SG" == "None" ]] && { echo "ERROR: Security group '$SG_NAME' not found. Export SG or create SG."; exit 1; }
fi

# ----- Build list of public subnets in default VPC -----
echo "Finding default VPC public subnets…"
VPC="$(aws ec2 describe-vpcs --filters Name=isDefault,Values=true --region "$REGION" --query 'Vpcs[0].VpcId' --output text)"
SUBNETS_LIST="$(aws ec2 describe-subnets \
  --filters Name=vpc-id,Values="$VPC" Name=map-public-ip-on-launch,Values=true \
  --region "$REGION" \
  --query 'Subnets[].SubnetId' --output text)"
if [[ -z "$SUBNETS_LIST" ]]; then
  echo "ERROR: No public subnets found in default VPC $VPC"
  exit 1
fi

# Comma list (no spaces or brackets) for ECS shorthand
SUBNETS_CSV="$(echo "$SUBNETS_LIST" | tr '\t\n ' ',' | sed 's/,,*/,/g; s/^,//; s/,$//')"

echo "VPC           : $VPC"
echo "SUBNETS_LIST  : $SUBNETS_LIST"
echo "SUBNETS_CSV   : $SUBNETS_CSV"
echo "SG            : $SG"
echo "TG_ARN        : $TG_ARN"

# ----- Ensure cluster exists -----
echo "Ensuring ECS cluster '$CLUSTER' exists…"
CL_STATUS="$(aws ecs describe-clusters --clusters "$CLUSTER" --region "$REGION" --query 'clusters[0].status' --output text 2>/dev/null || true)"
if [[ "$CL_STATUS" != "ACTIVE" ]]; then
  aws ecs create-cluster --cluster-name "$CLUSTER" --region "$REGION" >/dev/null
  echo "Created cluster '$CLUSTER'."
fi

# ----- Create or update service -----
echo "Checking for existing service…"
SVC_STATUS="$(aws ecs describe-services \
  --cluster "$CLUSTER" --services "$SERVICE" \
  --region "$REGION" --query 'services[0].status' --output text 2>/dev/null || true)"

if [[ "$SVC_STATUS" == "ACTIVE" ]]; then
  echo "Service exists → forcing new deployment…"
  aws ecs update-service \
    --cluster "$CLUSTER" \
    --service "$SERVICE" \
    --force-new-deployment \
    --region "$REGION" >/dev/null
else
  echo "Service not found → creating…"
  aws ecs create-service \
    --cluster "$CLUSTER" \
    --service-name "$SERVICE" \
    --task-definition "$SERVICE" \
    --desired-count 1 \
    --launch-type FARGATE \
    --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS_CSV],securityGroups=[$SG],assignPublicIp=ENABLED}" \
    --load-balancers "targetGroupArn=$TG_ARN,containerName=web,containerPort=80" \
    --region "$REGION" >/dev/null
fi

echo "Waiting for service stability…"
aws ecs wait services-stable --cluster "$CLUSTER" --services "$SERVICE" --region "$REGION"
echo "✅ Service is stable."

# ----- Print ALB DNS for a quick health check -----
ALB_ARN="$(aws elbv2 describe-load-balancers --names "$ALB_NAME" --region "$REGION" --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || true)"
if [[ -n "$ALB_ARN" && "$ALB_ARN" != "None" ]]; then
  ALB_DNS="$(aws elbv2 describe-load-balancers --load-balancer-arns "$ALB_ARN" --region "$REGION" --query 'LoadBalancers[0].DNSName' --output text)"
  echo "ALB: http://$ALB_DNS"
  echo "Try: curl -fsS http://$ALB_DNS/api/health/ready && echo"
else
  echo "Note: ALB named '$ALB_NAME' not found (that’s ok if you didn’t create one)."
fi