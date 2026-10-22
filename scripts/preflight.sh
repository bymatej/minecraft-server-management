#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.."
uname -a
cat /etc/os-release
docker version
docker compose version
docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'
docker volume ls
docker network ls
free -h
df -h .
nproc
ss -tulpen
systemctl is-active nginx
git remote -v
git status --short
git branch --show-current
printf '%s\n' 'Firewall (read-only; sudo may require your password):'
sudo -n ufw status verbose || true
sudo -n iptables -S DOCKER-USER || true
sudo -n ip6tables -S DOCKER-USER || true
