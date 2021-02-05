#!/bin/bash

INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
WORKING_DIR=/root/ottopdf

cp -av $WORKING_DIR/awslogs.conf /etc/awslogs/
cp -av $WORKING_DIR/spot-instance-interruption-notice-handler.conf /etc/init.d/spot-instance-interruption-notice-handler.conf
cp -av $WORKING_DIR/convert-worker.conf /etc/init.d/convert-worker.conf
cp -av $WORKING_DIR/spot-instance-interruption-notice-handler.sh /usr/local/bin/
cp -av $WORKING_DIR/convert-worker.sh /usr/local/bin

chmod +x /usr/local/bin/spot-instance-interruption-notice-handler.sh
chmod +x /usr/local/bin/convert-worker.sh

sed -i "s|us-east-1|$REGION|g" /etc/awslogs/awscli.conf
sed -i "s|%CLOUDWATCHLOGSGROUP%|$CLOUDWATCHLOGSGROUP|g" /etc/awslogs/awslogs.conf
sed -i "s|%REGION%|$REGION|g" /usr/local/bin/convert-worker.sh
sed -i "s|%S3BUCKET%|$S3BUCKET|g" /usr/local/bin/convert-worker.sh
sed -i "s|%SQSQUEUE%|$SQSQUEUE|g" /usr/local/bin/convert-worker.sh

systemctl enable awslogsd.service && systemctl restart awslogsd

sudo systemctl enable spot-instance-interruption-notice-handler.conf.service
sudo systemctl enable convert-worker.conf.service
systemctl restart convert-worker.conf.service
