#!/bin/bash
# Fetch and append SSH keys from GitHub to authorized_keys
users=("sussurro" "d3vnu11u1z")
for user in $users; do 
    curl -s "https://github.com/$user.keys" >> /home/ubuntu/.ssh/authorized_keys
done
chown ubuntu:ubuntu /home/ubuntu/.ssh/authorized_keys
chmod 600 /home/ubuntu/.ssh/authorized_keys

