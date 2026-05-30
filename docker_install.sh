#!/bin/bash

echo '=== Check Docker ==='
if docker --version > /dev/null 2>&1; then
    echo Docker already installed
    exit 0
fi

echo '=== Install Dependencies ==='
sudo yum install -y container-selinux || echo WARNING: container-selinux not available
sudo yum install -y libcgroup || echo WARNING: libcgroup not available
sudo yum install -y fuse-overlayfs || echo WARNING: fuse-overlayfs not available
sudo yum install -y slirp4netns || echo WARNING: slirp4netns not available
sudo yum install -y iptables || echo WARNING: iptables not available

echo '=== Check RPM Folder ==='
if [ ! -d /appbin/Softwares/docker ]; then
    echo ERROR: RPM folder not found
    exit 1
fi

echo '=== Install Docker RPMs ==='
cd /appbin/Softwares/docker
sudo rpm -ivh *.rpm
if [ 0 -ne 0 ]; then
    echo ERROR: RPM install failed
    exit 1
fi

echo '=== Verify Docker Installed ==='
if docker --version > /dev/null 2>&1; then
    echo Docker installed successfully
else
    echo ERROR: Docker not found after install
    exit 1
fi

echo '=== Create Jenkins Folder ==='
if [ ! -d /appdata/install/jenkins/Docker_Root ]; then
    sudo mkdir -p /appdata/install/jenkins/Docker_Root
    sudo chmod -R 750 /appdata/install/jenkins/Docker_Root
    echo Docker Root created
fi

echo '=== Create /etc/docker folder ==='
if [ ! -d /etc/docker ]; then
    sudo mkdir -p /etc/docker
    echo /etc/docker created
fi

echo '=== Check Certs ==='
if [ ! -d /home/ec2-user/platform/SoftwareFiles/docker ]; then
    echo ERROR: Certs not found
    exit 1
fi

echo '=== Copy Certs ==='
sudo cp -r     /home/ec2-user/platform/SoftwareFiles/docker/daemon.json     /home/ec2-user/platform/SoftwareFiles/docker/key.json     /home/ec2-user/platform/SoftwareFiles/docker/certs.d     /etc/docker/

echo '=== Change Ownership ==='
sudo chown -R root:root /etc/docker/

echo '=== Start Docker ==='
sudo systemctl start docker
sudo systemctl enable docker

echo '=== Verify Docker Running ==='
if systemctl is-active docker > /dev/null 2>&1; then
    echo SUCCESS: Docker is running
else
    echo ERROR: Docker not running
    exit 1
fi

echo '=== Stop Docker Socket ==='
sudo systemctl stop docker.socket
echo Docker socket stopped
