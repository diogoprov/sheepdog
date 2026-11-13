#!/bin/bash
# Uploads the committed dev/fase2 and launches one spot instance that runs the
# validation and terminates. Launching again with the same <run> resumes.
# Usage: dev/fase2/aws/launch.sh <bucket> <run> [type] [workers] [max_hours] [max_price] [script] [extra]
# script defaults to run_val2_v0.R; extra are arguments passed after the workers.
# The instance profile pcps-sim-ec2 writes only under fpcalib/, so the run lives
# in s3://<bucket>/fpcalib/runs/<run>/. max_price caps the hourly spot price.
set -euo pipefail
BUCKET=$1; RUN=$2; TYPE=${3:-c7a.16xlarge}; WORKERS=${4:-64}; MAX_HOURS=${5:-2}; MAX_PRICE=${6:-1.30}
SCRIPT=${7:-run_val2_v0.R}; EXTRA=${8:-}
cd "$(git rev-parse --show-toplevel)"
if ! git diff --quiet HEAD -- dev/fase2; then echo "Uncommitted changes; commit first." >&2; exit 1; fi
TAR=$(mktemp).tar.gz; UD=$(mktemp)
git archive --format=tar.gz -o "${TAR}" HEAD -- dev/fase2 ':!dev/fase2/results'
aws s3 cp "${TAR}" "s3://${BUCKET}/fpcalib/runs/${RUN}/code.tar.gz" --only-show-errors
sed -e "s|__BUCKET__|${BUCKET}|" -e "s|__RUN__|${RUN}|" -e "s|__WORKERS__|${WORKERS}|" \
  -e "s|__MAX_HOURS__|${MAX_HOURS}|" -e "s|__SCRIPT__|${SCRIPT}|" -e "s|__EXTRA__|${EXTRA}|" dev/fase2/aws/user_data.sh > "${UD}"
AMI=$(aws ec2 describe-images --owners amazon \
  --filters "Name=name,Values=al2023-ami-2023.*-kernel-*-x86_64" "Name=state,Values=available" \
  --query 'sort_by(Images, &CreationDate)[-1].ImageId' --output text)
aws ec2 run-instances --image-id "${AMI}" --instance-type "${TYPE}" \
  --instance-market-options "{\"MarketType\":\"spot\",\"SpotOptions\":{\"MaxPrice\":\"${MAX_PRICE}\",\"SpotInstanceType\":\"one-time\",\"InstanceInterruptionBehavior\":\"terminate\"}}" \
  --instance-initiated-shutdown-behavior terminate \
  --iam-instance-profile Name=pcps-sim-ec2 \
  --block-device-mappings '[{"DeviceName":"/dev/xvda","Ebs":{"VolumeSize":40,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
  --user-data "file://${UD}" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=fase2-${RUN}},{Key=project,Value=fpcalib}]" \
                       "ResourceType=volume,Tags=[{Key=Name,Value=fase2-${RUN}},{Key=project,Value=fpcalib}]" \
  --query 'Instances[0].InstanceId' --output text
rm -f "${TAR}" "${UD}"
