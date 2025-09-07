#!/bin/bash

echo "Current: $(cat /proc/sys/fs/inotify/max_user_watches)"

sudo sysctl fs.inotify.max_user_watches=3097152 >/dev/null
sudo sysctl fs.inotify.max_user_instances=2048 >/dev/null
sudo sysctl fs.inotify.max_queued_events=65536 >/dev/null

# Make permanent
sudo sed -i '/fs.inotify.max_user_watches/d' /etc/sysctl.conf 2>/dev/null
sudo sed -i '/fs.inotify.max_user_instances/d' /etc/sysctl.conf 2>/dev/null
sudo sed -i '/fs.inotify.max_queued_events/d' /etc/sysctl.conf 2>/dev/null

echo "fs.inotify.max_user_watches=3097152" | sudo tee -a /etc/sysctl.conf >/dev/null
echo "fs.inotify.max_user_instances=2048" | sudo tee -a /etc/sysctl.conf >/dev/null
echo "fs.inotify.max_queued_events=65536" | sudo tee -a /etc/sysctl.conf >/dev/null

sudo sysctl -p >/dev/null

echo "Updated: $(cat /proc/sys/fs/inotify/max_user_watches)"