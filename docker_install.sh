#!/bin/bash

# ─────────────────────────────────────
# VARIABLES
# ─────────────────────────────────────
RPM_PATH="/appbin/Softwares/docker"
CERTS_PATH="/home/ec2-user/platform/SoftwareFiles/docker"
DOCKER_ROOT="/appdata/install/jenkins/Docker_Root"
ETC_DOCKER="/etc/docker"
LOG_FILE="/var/log/docker_install.log"

# ─────────────────────────────────────
# LOGGING
# ─────────────────────────────────────
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# ─────────────────────────────────────
# STEP 1 - CHECK DOCKER ALREADY EXISTS
# ─────────────────────────────────────
log "=== Check Docker ==="
if docker --version > /dev/null 2>&1; then
  log "Docker already installed: $(docker --version)"
  log "Nothing to do. Exiting."
  exit 0
else
  log "Docker not found. Proceeding..."
fi

# ─────────────────────────────────────
# STEP 2 - CHECK ROOT
# ─────────────────────────────────────
log "=== Check Root Access ==="
if [ "$EUID" -ne 0 ]; then
  log "ERROR: Please run as root"
  exit 1
else
  log "Root access OK"
fi

# ─────────────────────────────────────
# STEP 3 - INSTALL DEPENDENCIES
# ─────────────────────────────────────
log "=== Install Dependencies ==="

if rpm -q container-selinux > /dev/null 2>&1; then
  log "container-selinux already installed"
else
  yum install -y container-selinux || log "WARNING: container-selinux not available"
fi

if rpm -q libcgroup > /dev/null 2>&1; then
  log "libcgroup already installed"
else
  yum install -y libcgroup || log "WARNING: libcgroup not available"
fi

if rpm -q fuse-overlayfs > /dev/null 2>&1; then
  log "fuse-overlayfs already installed"
else
  yum install -y fuse-overlayfs || log "WARNING: fuse-overlayfs not available"
fi

if rpm -q slirp4netns > /dev/null 2>&1; then
  log "slirp4netns already installed"
else
  yum install -y slirp4netns || log "WARNING: slirp4netns not available"
fi

if rpm -q iptables > /dev/null 2>&1; then
  log "iptables already installed"
else
  yum install -y iptables || log "WARNING: iptables not available"
fi

# ─────────────────────────────────────
# STEP 4 - CHECK RPM FOLDER
# ─────────────────────────────────────
log "=== Check RPM Folder ==="
if [ -d "$RPM_PATH" ]; then
  log "RPM folder found: $RPM_PATH"
  ls $RPM_PATH
else
  log "ERROR: RPM folder not found at $RPM_PATH"
  exit 1
fi

# ─────────────────────────────────────
# STEP 5 - INSTALL DOCKER RPMs
# ─────────────────────────────────────
log "=== Install Docker RPMs ==="
cd $RPM_PATH
rpm -ivh *.rpm
if [ $? -eq 0 ]; then
  log "Docker RPMs installed successfully"
else
  log "ERROR: Docker RPM installation failed"
  exit 1
fi

# ─────────────────────────────────────
# STEP 6 - VERIFY DOCKER INSTALLED
# ─────────────────────────────────────
log "=== Verify Docker Installed ==="
if docker --version > /dev/null 2>&1; then
  log "Docker installed: $(docker --version)"
else
  log "ERROR: Docker not found after install"
  exit 1
fi

# ─────────────────────────────────────
# STEP 7 - CREATE JENKINS DOCKER FOLDER
# ─────────────────────────────────────
log "=== Create Jenkins Docker Folder ==="
if [ -d "$DOCKER_ROOT" ]; then
  log "Docker Root already exists, skipping"
else
  mkdir -p $DOCKER_ROOT
  chmod -R 750 $DOCKER_ROOT
  log "Docker Root created with 750 permissions"
fi

# ─────────────────────────────────────
# STEP 8 - CREATE /etc/docker FOLDER
# ─────────────────────────────────────
log "=== Create /etc/docker Folder ==="
if [ -d "$ETC_DOCKER" ]; then
  log "/etc/docker already exists, skipping"
else
  mkdir -p $ETC_DOCKER
  log "/etc/docker created"
fi

# ─────────────────────────────────────
# STEP 9 - CHECK CERTS
# ─────────────────────────────────────
log "=== Check Certs ==="
if [ -d "$CERTS_PATH" ]; then
  log "Certs found at: $CERTS_PATH"
  ls $CERTS_PATH
else
  log "ERROR: Certs not found at $CERTS_PATH"
  exit 1
fi

# ─────────────────────────────────────
# STEP 10 - COPY CERTS
# ─────────────────────────────────────
log "=== Copy Certs ==="
cp -r $CERTS_PATH/daemon.json \
      $CERTS_PATH/key.json \
      $CERTS_PATH/certs.d \
      $ETC_DOCKER/
if [ $? -eq 0 ]; then
  log "Certs copied successfully"
else
  log "ERROR: Certs copy failed"
  exit 1
fi

# ─────────────────────────────────────
# STEP 11 - CHANGE OWNERSHIP
# ─────────────────────────────────────
log "=== Change Ownership ==="
chown -R root:root $ETC_DOCKER/
if [ $? -eq 0 ]; then
  log "Ownership changed to root:root"
else
  log "ERROR: chown failed"
  exit 1
fi

# ─────────────────────────────────────
# ROOT WORK DONE
# NOW SWITCH TO JKSLAVE
# ─────────────────────────────────────
log "=== Switching to jkslave ==="

# check jkslave exists
if id jkslave > /dev/null 2>&1; then
  log "jkslave user found"
else
  log "ERROR: jkslave user not found"
  log "Please create jkslave user first"
  exit 1
fi

# check jkslave in docker group
if groups jkslave | grep docker > /dev/null 2>&1; then
  log "jkslave already in docker group"
else
  usermod -aG docker jkslave
  log "jkslave added to docker group"
fi

log "Switching to jkslave for docker operations"

# ─────────────────────────────────────
# STEP 12 - START DOCKER AS JKSLAVE
# ─────────────────────────────────────
log "=== Start Docker as jkslave ==="
if systemctl is-active docker > /dev/null 2>&1; then
  log "Docker already running"
else
  su - jkslave -c "systemctl start docker"
  if [ $? -eq 0 ]; then
    log "Docker started by jkslave"
  else
    log "ERROR: Docker failed to start"
    exit 1
  fi
fi

# enable on reboot
su - jkslave -c "systemctl enable docker"
log "Docker enabled on reboot"

# ─────────────────────────────────────
# STEP 13 - VERIFY DOCKER RUNNING
# ─────────────────────────────────────
log "=== Verify Docker Running ==="
su - jkslave -c "systemctl status docker"
if [ $? -eq 0 ]; then
  log "SUCCESS: Docker is running"
else
  log "ERROR: Docker is not running"
  exit 1
fi

# ─────────────────────────────────────
# STEP 14 - STOP DOCKER SOCKET AS JKSLAVE
# ─────────────────────────────────────
log "=== Stop Docker Socket as jkslee ==="
su - jkslave -c "systemctl stop docker.socket"
if [ $? -eq 0 ]; then
  log "Docker socket stopped by jkslave"
else
  log "WARNING: Could not stop docker socket"
fi

log "================================"
log "Docker Installation Complete!"
log "================================"
