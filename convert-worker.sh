#!/bin/bash

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=%REGION%
S3BUCKET=%S3BUCKET%
S3BUCKETDESTINATION=%S3BUCKETDESTINATION%
SQSQUEUE=%SQSQUEUE%
AUTOSCALINGGROUP=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=aws:autoscaling:groupName" | jq -r '.Tags[0].Value')

while sleep 5; do 

  JSON=$(aws sqs --output=json get-queue-attributes \
    --queue-url $SQSQUEUE \
    --attribute-names ApproximateNumberOfMessages)
  MESSAGES=$(echo "$JSON" | jq -r '.Attributes.ApproximateNumberOfMessages')

  if [ $MESSAGES -eq 0 ]; then

    continue

  fi

  JSON=$(aws sqs --output=json receive-message --queue-url $SQSQUEUE)
  RECEIPT=$(echo "$JSON" | jq -r '.Messages[] | .ReceiptHandle')
  BODY=$(echo "$JSON" | jq -r '.Messages[] | .Body')

  if [ -z "$RECEIPT" ]; then

    logger "$0: Empty receipt. Something went wrong."
    continue

  fi

  logger "$0: Found $MESSAGES messages in $SQSQUEUE. Details: JSON=$JSON, RECEIPT=$RECEIPT, BODY=$BODY"

  INPUT=$(echo "$BODY" | jq -r '.Records[0] | .s3.object.key')
  FNAME=$(echo $INPUT | rev | cut -f2 -d"." | rev | tr '[:upper:]' '[:lower:]')
  FEXT=$(echo $INPUT | rev | cut -f1 -d"." | rev | tr '[:upper:]' '[:lower:]')

  if [ "$FEXT" = "zip" ]; then

    logger "$0: Found work to convert. Details: INPUT=$INPUT, FNAME=$FNAME, FEXT=$FEXT"

    logger "$0: Running: aws autoscaling set-instance-protection --instance-ids $INSTANCE_ID --auto-scaling-group-name $AUTOSCALINGGROUP --protected-from-scale-in"

    export PATH=/var/task/texlive/2017/bin/x86_64-linux/:$PATH

    export PERL5LIB=/var/task/texlive/2017/tlpkg/TeXLive/

    aws autoscaling set-instance-protection --instance-ids $INSTANCE_ID --auto-scaling-group-name $AUTOSCALINGGROUP --protected-from-scale-in

    aws s3 cp s3://$S3BUCKET/$INPUT /tmp/latex/

    unzip /tmp/latex/compile.zip -d /tmp/latex/

    cd /tmp/latex/

    PATHFILE=$(find /tmp/latex/tmp/ -name '*.txt' -exec cat {} \;)

    latexmk -interaction=batchmode -shell-escape -pdf -output-directory=/tmp/latex /tmp/latex/template.tex -f
#    convert /tmp/$INPUT /tmp/$FNAME.pdf

    logger "$0: Convert done. Copying to S3 and cleaning up"

    logger "$0: Running: aws s3 cp /tmp/latex/laudo_qualificacao.pdf s3://$S3BUCKETDESTINATION/$PATHFILE"

    cp /tmp/latex/template.pdf /tmp/latex/laudo_qualificacao.pdf

    aws s3 cp /tmp/latex/laudo_qualificacao.pdf s3://$S3BUCKETDESTINATION/$PATHFILE

    rm -rf /tmp/latex/*

    # pretend to do work for 60 seconds in order to catch the scale in protection
    sleep 60

    logger "$0: Running: aws sqs --output=json delete-message --queue-url $SQSQUEUE --receipt-handle $RECEIPT"

    aws sqs --output=json delete-message --queue-url $SQSQUEUE --receipt-handle $RECEIPT

    logger "$0: Running: aws autoscaling set-instance-protection --instance-ids $INSTANCE_ID --auto-scaling-group-name $AUTOSCALINGGROUP --no-protected-from-scale-in"

    aws autoscaling set-instance-protection --instance-ids $INSTANCE_ID --auto-scaling-group-name $AUTOSCALINGGROUP --no-protected-from-scale-in

  else

    logger "$0: Skipping message - file not of type jpg, png, or gif. Deleting message from queue"

    aws sqs --output=json delete-message --queue-url $SQSQUEUE --receipt-handle $RECEIPT

  fi

done