#!/bin/bash
set -ex
htpasswd -c users.htpasswd admin1
ansible masters -m copy -a "src=users.htpasswd dest=/etc/origin/master/htpasswd"
