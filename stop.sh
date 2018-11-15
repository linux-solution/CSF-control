#!/bin/bash

# Remove related Cron jobs from Crontab
touch myCronjob
touch myNewCronjob

crontab -l > myCronjob

pattern='*IPBlock*'

while read CronJobList; do
	case $CronJobList in
		$pattern) continue;;
	esac

	echo "$CronJobList" >> myNewCronjob
done < "myCronjob"

crontab myNewCronjob

rm -rf myCronjob
rm -rf myNewCronjob

# Remove scripts.
rm -rf /etc/IPBlock.sh
