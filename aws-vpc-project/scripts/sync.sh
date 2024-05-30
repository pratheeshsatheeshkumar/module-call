#!/bin/bash                                                       
rsync -ave "ssh -i /home/ubuntu/module-call/aws-vpc-project/aws_key.pem"  /home/ubuntu/module-call/aws-vpc-project/backup_source/ ec2-user@13.127.244.113:~/backup_dest >> /home/ubuntu/module-call/aws-vpc-project/cronlog.txt 2>&1
echo "$(date)" >> /home/ubuntu/module-call/aws-vpc-project/date.txt

