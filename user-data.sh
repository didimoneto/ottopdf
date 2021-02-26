#!/bin/bash

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
WORKING_DIR=/root/ottopdf

cp -av $WORKING_DIR/awslogs.conf /etc/awslogs/
cp -av $WORKING_DIR/spot-instance-interruption-notice-handler.service /etc/systemd/system/spot-instance-interruption-notice-handler.service
cp -av $WORKING_DIR/convert-worker.service /etc/systemd/system/convert-worker.service
cp -av $WORKING_DIR/spot-instance-interruption-notice-handler.sh /usr/local/bin/
cp -av $WORKING_DIR/convert-worker.sh /usr/local/bin

chmod +x /usr/local/bin/spot-instance-interruption-notice-handler.sh
chmod +x /usr/local/bin/convert-worker.sh

sed -i "s|us-east-1|$REGION|g" /etc/awslogs/awscli.conf
sed -i "s|%CLOUDWATCHLOGSGROUP%|$CLOUDWATCHLOGSGROUP|g" /etc/awslogs/awslogs.conf
sed -i "s|%REGION%|$REGION|g" /usr/local/bin/convert-worker.sh
sed -i "s|%S3BUCKET%|$S3BUCKET|g" /usr/local/bin/convert-worker.sh
sed -i "s|%S3BUCKETDESTINATION%|$S3BUCKETDESTINATION|g" /usr/local/bin/convert-worker.sh
sed -i "s|%SQSQUEUE%|$SQSQUEUE|g" /usr/local/bin/convert-worker.sh

systemctl enable awslogsd.service && systemctl restart awslogsd

systemctl enable spot-instance-interruption-notice-handler
systemctl enable convert-worker

systemctl start spot-instance-interruption-notice-handler
systemctl start convert-worker
