#!/bin/bash

# ─────────────────────────────────────
# VARIABLES
# ─────────────────────────────────────
RPM_PATH="/appbin/Softwares/docker"
CERTS_PATH="/home/rmpci/platform/SoftwareFiles/docker"
DOCKER_ROOT="/appdata/install/jenkins/Docker_Root"
ETC_DOCKER="/etc/docker"
TARGET_USER="jkslave"
LOG_FILE="/var/log/docker_install.log"

# ─────────────────────────────────────
# LOGGING
# ─────────────────────────────────────
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

# ═══════════════════════════════════════
# STEP 1 - CHECK DOCKER ALREADY INSTALLED
# ═══════════════════════════════════════
log "=== Step 1: Check Docker ==="
if docker --version > /dev/null 2>&1; then
  log "Docker already installed: $(docker --version)"
  log "Nothing to do. Exiting."
  exit 0
else
  log "Docker not found. Proceeding..."
fi

# ═══════════════════════════════════════
# STEP 2 - CHECK ROOT ACCESS
# ═══════════════════════════════════════
log "=== Step 2: Check Root Access ==="
if [ "$(id -u)" -ne 0 ]; then
  log "ERROR: Please run as root"
  exit 1
else
  log "Root access OK"
fi

# ═══════════════════════════════════════
# STEP 3 - INSTALL DEPENDENCIES
# ═══════════════════════════════════════
log "=== Step 3: Install Dependencies ==="

# container-selinux
if rpm -q container-selinux > /dev/null 2>&1; then
  log "container-selinux already installed"
else
  yum install -y container-selinux || log "WARNING: container-selinux not available"
fi

# libcgroup
if rpm -q libcgroup > /dev/null 2>&1; then
  log "libcgroup already installed"
else
  yum install -y libcgroup || log "WARNING: libcgroup not available"
fi

# fuse-overlayfs
if rpm -q fuse-overlayfs > /dev/null 2>&1; then
  log "fuse-overlayfs already installed"
else
  yum install -y fuse-overlayfs || log "WARNING: fuse-overlayfs not available"
fi

# slirp4netns
if rpm -q slirp4netns > /dev/null 2>&1; then
  log "slirp4netns already installed"
else
  yum install -y slirp4netns || log "WARNING: slirp4netns not available"
fi

# iptables
if rpm -q iptables > /dev/null 2>&1; then
  log "iptables already installed"
else
  yum install -y iptables || log "WARNING: iptables not available"
fi

# ═══════════════════════════════════════
# STEP 4 - CHECK RPM FOLDER EXISTS
# ═══════════════════════════════════════
log "=== Step 4: Check RPM Folder ==="
if [ -d "$RPM_PATH" ]; then
  log "RPM folder found: $RPM_PATH"
  ls $RPM_PATH
else
  log "ERROR: RPM folder not found at $RPM_PATH"
  exit 1
fi

# ═══════════════════════════════════════
# STEP 5 - CHECK RPM FILES EXIST
# ═══════════════════════════════════════
log "=== Step 5: Check RPM Files ==="
cd $RPM_PATH

# check each rpm file exists
if ls containerd.io*.rpm > /dev/null 2>&1; then
  log "OK: containerd.io found"
else
  log "ERROR: containerd.io rpm not found"
  exit 1
fi

if ls docker-ce-[0-9]*.rpm > /dev/null 2>&1; then
  log "OK: docker-ce found"
else
  log "ERROR: docker-ce rpm not found"
  exit 1
fi

if ls docker-ce-cli*.rpm > /dev/null 2>&1; then
  log "OK: docker-ce-cli found"
else
  log "ERROR: docker-ce-cli rpm not found"
  exit 1
fi

if ls docker-buildx-plugin*.rpm > /dev/null 2>&1; then
  log "OK: docker-buildx-plugin found"
else
  log "ERROR: docker-buildx-plugin rpm not found"
  exit 1
fi

if ls docker-compose-plugin*.rpm > /dev/null 2>&1; then
  log "OK: docker-compose-plugin found"
else
  log "ERROR: docker-compose-plugin rpm not found"
  exit 1
fi

if ls docker-scan-plugin*.rpm > /dev/null 2>&1; then
  log "OK: docker-scan-plugin found"
else
  log "ERROR: docker-scan-plugin rpm not found"
  exit 1
fi

log "All RPM files found"

# ═══════════════════════════════════════
# STEP 6 - INSTALL DOCKER RPMs
# ═══════════════════════════════════════
log "=== Step 6: Install Docker RPMs ==="
rpm -ivh *.rpm
if [ $? -eq 0 ]; then
  log "All Docker RPMs installed successfully"
else
  log "ERROR: RPM installation failed"
  exit 1
fi

# ═══════════════════════════════════════
# STEP 7 - VERIFY DOCKER VERSION
# ═══════════════════════════════════════
log "=== Step 7: Verify Docker Version ==="
if docker --version > /dev/null 2>&1; then
  log "OK: $(docker --version)"
else
  log "ERROR: Docker not found after install"
  exit 1
fi

# ═══════════════════════════════════════
# STEP 8 - CREATE JENKINS DOCKER FOLDER
# ═══════════════════════════════════════
log "=== Step 8: Create Jenkins Docker Folder ==="
if [ -d "$DOCKER_ROOT" ]; then
  log "Docker Root already exists, skipping"
else
  mkdir -p $DOCKER_ROOT
  log "Docker Root created"
fi

# set permissions
chmod -R 750 $DOCKER_ROOT

# verify permissions
PERMS=$(stat -c "%a" "$DOCKER_ROOT")
if [ "$PERMS" == "750" ]; then
  log "OK: Permissions verified as 750"
else
  log "ERROR: Permission verification failed: $PERMS"
  exit 1
fi

# ═══════════════════════════════════════
# STEP 9 - CREATE /etc/docker FOLDER
# ═══════════════════════════════════════
log "=== Step 9: Create /etc/docker Folder ==="
if [ -d "$ETC_DOCKER" ]; then
  log "/etc/docker already exists, skipping"
else
  mkdir -p $ETC_DOCKER
  log "/etc/docker created"
fi

# ═══════════════════════════════════════
# STEP 10 - CHECK CERT FILES
# ═══════════════════════════════════════
log "=== Step 10: Check Cert Files ==="
cd $CERTS_PATH

# check daemon.json
if [ -f "daemon.json" ]; then
  log "OK: daemon.json found"
else
  log "ERROR: daemon.json not found in $CERTS_PATH"
  exit 1
fi

# check key.json
if [ -f "key.json" ]; then
  log "OK: key.json found"
else
  log "ERROR: key.json not found in $CERTS_PATH"
  exit 1
fi

# check certs.d
if [ -d "certs.d" ]; then
  log "OK: certs.d found"
else
  log "ERROR: certs.d not found in $CERTS_PATH"
  exit 1
fi

# ═══════════════════════════════════════
# STEP 11 - COPY CERTS
# ═══════════════════════════════════════
log "=== Step 11: Copy Certs ==="
cp -r daemon.json key.json certs.d $ETC_DOCKER/
if [ $? -eq 0 ]; then
  log "Certs copied successfully"
else
  log "ERROR: Certs copy failed"
  exit 1
fi

# verify certs copied
if [ -f "$ETC_DOCKER/daemon.json" ] && \
   [ -f "$ETC_DOCKER/key.json" ] && \
   [ -d "$ETC_DOCKER/certs.d" ]; then
  log "OK: All certs verified in $ETC_DOCKER"
else
  log "ERROR: Cert verification failed"
  exit 1
fi

# ═══════════════════════════════════════
# STEP 12 - CHANGE OWNERSHIP
# ═══════════════════════════════════════
log "=== Step 12: Change Ownership ==="
chown -R root:root $ETC_DOCKER/
if [ $? -eq 0 ]; then
  log "Ownership changed to root:root"
else
  log "ERROR: chown failed"
  exit 1
fi

# verify ownership
OWNER=$(stat -c '%U:%G' "$ETC_DOCKER")
if [ "$OWNER" = "root:root" ]; then
  log "OK: Ownership verified as root:root"
else
  log "ERROR: Ownership verification failed: $OWNER"
  exit 1
fi

# ═══════════════════════════════════════
# STEP 13 - CHECK JKSLAVE USER
# ═══════════════════════════════════════
log "=== Step 13: Check jkslave ==="

# check jkslave exists
if id "$TARGET_USER" > /dev/null 2>&1; then
  log "jkslave user found"
else
  log "ERROR: jkslave user not found"
  exit 1
fi

# add jkslave to docker group
groupadd -f docker
usermod -aG docker "$TARGET_USER"
log "jkslave added to docker group"

# ═══════════════════════════════════════
# STEP 14 - START DOCKER AS JKSLAVE
# ═══════════════════════════════════════
log "=== Step 14: Start Docker as jkslave ==="
if systemctl is-active docker > /dev/null 2>&1; then
  log "Docker already running"
else
  runuser -l "$TARGET_USER" -c "sudo systemctl start docker"
  if [ $? -eq 0 ]; then
    log "Docker started by jkslave"
  else
    log "ERROR: Docker failed to start"
    exit 1
  fi
fi

# enable docker on reboot
runuser -l "$TARGET_USER" -c "sudo systemctl enable docker"
log "Docker enabled on reboot"

# ═══════════════════════════════════════
# STEP 15 - VERIFY DOCKER RUNNING
# ═══════════════════════════════════════
log "=== Step 15: Verify Docker Running ==="
runuser -l "$TARGET_USER" -c "sudo systemctl status docker --no-pager | head -n 5"
if [ $? -eq 0 ]; then
  log "SUCCESS: Docker is running"
else
  log "ERROR: Docker is not running"
  exit 1
fi

# verify docker CLI as jkslave
runuser -l "$TARGET_USER" -c "docker --version"
runuser -l "$TARGET_USER" -c "docker ps"

log "================================"
log "Docker Installation Complete!"
log "================================"
