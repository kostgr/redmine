#!/bin/bash

/usr/bin/mysqldump redmine | gzip >/tmp/backups/redmine_dbbackup_`date +%y_%m_%d`.gz

rsync -av --delete /var/redmine/files/ /tmp/backups/var/redmine/files

rsync -av --delete /etc/apache2/ /tmp/backups/etc/apache2

rsync -av --delete /opt/redmine/redmine-2.5-stable/ /tmp/backups/opt/redmine/redmine-2.5-stable

cp /etc/sysconfig/apache2 /tmp/backups/etc/sysconfig/apache2
