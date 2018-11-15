#!/bin/bash

./stop.sh
chmod 777 IPBlock.sh
cp ./IPBlock.sh /etc/

crontab -l > myCronjob
echo "*/5 * * * * /etc/IPBlock.sh 2>&1 | tee /var/log/ipblock.log" >> myCronjob

crontab myCronjob
rm -rf myCronjob
