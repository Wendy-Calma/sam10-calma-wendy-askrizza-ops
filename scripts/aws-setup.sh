#!/bin/bash
# S3 bucket, SNS topic and SSM secrets. Idempotent.
# Usage: bash scripts/aws-setup.sh <alert email>
set -euo pipefail
EMAIL="${1:?usage: bash scripts/aws-setup.sh <alert email>}"
set -a; source deploy/settings.env; set +a
TAGS='Key=Project,Value=SAM10 Key=Owner,Value=askrizza'

echo "== S3 bucket $BUCKET"
if ! aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  aws s3api create-bucket --bucket "$BUCKET" --region "$AWS_REGION"
fi
aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "$BUCKET" --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-bucket-tagging --bucket "$BUCKET" --tagging 'TagSet=[{Key=Project,Value=SAM10},{Key=Owner,Value=askrizza}]'
aws s3api put-bucket-lifecycle-configuration --bucket "$BUCKET" --lifecycle-configuration '{
  "Rules":[
    {"ID":"expire-backups-14d","Status":"Enabled","Filter":{"Prefix":"backups/"},
     "Expiration":{"Days":14},"NoncurrentVersionExpiration":{"NoncurrentDays":7}},
    {"ID":"old-content-versions-30d","Status":"Enabled","Filter":{"Prefix":"content/"},
     "NoncurrentVersionExpiration":{"NoncurrentDays":30}}]}'
aws s3 cp content/knowledge.md "s3://$BUCKET/content/knowledge.md"

echo "== SNS topic sam10-alerts"
TOPIC_ARN=$(aws sns create-topic --name sam10-alerts --tags $TAGS --query TopicArn --output text)
aws sns subscribe --topic-arn "$TOPIC_ARN" --protocol email --notification-endpoint "$EMAIL" >/dev/null
echo "   Topic: $TOPIC_ARN (subscription pending confirmation)"

echo "== SSM Parameter Store secrets (/sam10/*)"
put_secret() {
  if aws ssm get-parameter --name "/sam10/$1" >/dev/null 2>&1; then
    echo "   /sam10/$1 already exists - kept"
  else
    aws ssm put-parameter --name "/sam10/$1" --type SecureString --value "$2" --tags $TAGS >/dev/null
    echo "   /sam10/$1 created"
  fi
}
put_secret CREDS_KEY          "$(openssl rand -hex 32)"
put_secret CREDS_IV           "$(openssl rand -hex 16)"
put_secret JWT_SECRET         "$(openssl rand -hex 32)"
put_secret JWT_REFRESH_SECRET "$(openssl rand -hex 32)"
put_secret MEILI_MASTER_KEY   "$(openssl rand -hex 32)"
if ! aws ssm get-parameter --name /sam10/LLM_API_KEY >/dev/null 2>&1; then
  read -rsp "   $LLM_PROVIDER API key: " LLM_KEY; echo
  put_secret LLM_API_KEY "$LLM_KEY"
  unset LLM_KEY
fi

echo
aws ssm describe-parameters --parameter-filters Key=Name,Option=BeginsWith,Values=/sam10/ \
  --query 'Parameters[].[Name,Type,LastModifiedDate]' --output table
