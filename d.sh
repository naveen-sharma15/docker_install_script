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

# ─────────────────────────────────────
# STEP 1 - CHECK DOCKER
# ─────────────────────────────────────
log "=== Step 1: Check Docker ==="
if docker --version > /dev/null 2>&1; then
  log "Docker already installed: $(docker --version)"
  exit 0
else
  log "Docker not found. Proceeding..."
fi

# ─────────────────────────────────────
# STEP 2 - CHECK ROOT
# ─────────────────────────────────────
log "=== Step 2: Check Root ==="
if [ "$(id -u)" -ne 0 ]; then
  log "ERROR: Run as root"
  exit 1
else
  log "Root access OK"
fi

# ─────────────────────────────────────
# STEP 3 - INSTALL DEPENDENCIES
# ─────────────────────────────────────
log "=== Step 3: Install Dependencies ==="

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
log "=== Step 4: Check RPM Folder ==="
if [ -d "$RPM_PATH" ]; then
  log "RPM folder found"
  ls $RPM_PATH | tee -a $LOG_FILE
else
  log "ERROR: RPM folder not found at $RPM_PATH"
  exit 1
fi

# ─────────────────────────────────────
# STEP 5 - CHECK RPM FILES
# ─────────────────────────────────────
log "=== Step 5: Check RPM Files ==="
cd $RPM_PATH

if ls containerd.io*.rpm > /dev/null 2>&1; then
  log "OK: containerd.io found"
else
  log "ERROR: containerd.io not found"
  exit 1
fi

if ls docker-ce-[0-9]*.rpm > /dev/null 2>&1; then
  log "OK: docker-ce found"
else
  log "ERROR: docker-ce not found"
  exit 1
fi

if ls docker-ce-cli*.rpm > /dev/null 2>&1; then
  log "OK: docker-ce-cli found"
else
  log "ERROR: docker-ce-cli not found"
  exit 1
fi

if ls docker-buildx-plugin*.rpm > /dev/null 2>&1; then
  log "OK: docker-buildx-plugin found"
else
  log "ERROR: docker-buildx-plugin not found"
  exit 1
fi

if ls docker-compose-plugin*.rpm > /dev/null 2>&1; then
  log "OK: docker-compose-plugin found"
else
  log "ERROR: docker-compose-plugin not found"
  exit 1
fi

if ls docker-scan-plugin*.rpm > /dev/null 2>&1; then
  log "OK: docker-scan-plugin found"
else
  log "ERROR: docker-scan-plugin not found"
  exit 1
fi

log "All RPM files found"

# ─────────────────────────────────────
# STEP 6 - INSTALL DOCKER RPMs
# ─────────────────────────────────────
log "=== Step 6: Install Docker RPMs ==="
rpm -ivh *.rpm
if [ $? -eq 0 ]; then
  log "Docker RPMs installed successfully"
else
  log "ERROR: RPM installation failed"
  exit 1
fi

# ─────────────────────────────────────
# STEP 7 - VERIFY DOCKER VERSION
# ─────────────────────────────────────
log "=== Step 7: Verify Docker Version ==="
if docker --version > /dev/null 2>&1; then
  log "OK: $(docker --version)"
else
  log "ERROR: Docker not found after install"
  exit 1
fi

# ─────────────────────────────────────
# STEP 8 - CREATE JENKINS FOLDER
# ─────────────────────────────────────
log "=== Step 8: Create Jenkins Folder ==="
if [ -d "$DOCKER_ROOT" ]; then
  log "Jenkins folder already exists"
else
  mkdir -p $DOCKER_ROOT
  log "Jenkins folder created"
fi

chmod -R 750 $DOCKER_ROOT

PERMS=$(stat -c "%a" "$DOCKER_ROOT")
if [ "$PERMS" == "750" ]; then
  log "OK: Permissions set to 750"
else
  log "ERROR: Permission failed: $PERMS"
  exit 1
fi

# ─────────────────────────────────────
# STEP 9 - CREATE /etc/docker FOLDER
# ─────────────────────────────────────
log "=== Step 9: Create /etc/docker ==="
if [ -d "$ETC_DOCKER" ]; then
  log "/etc/docker already exists"
else
  mkdir -p $ETC_DOCKER
  log "/etc/docker created"
fi

# ─────────────────────────────────────
# STEP 10 - CHECK CERT FILES
# ─────────────────────────────────────
log "=== Step 10: Check Cert Files ==="
cd $CERTS_PATH

if [ -f "daemon.json" ]; then
  log "OK: daemon.json found"
else
  log "ERROR: daemon.json not found"
  exit 1
fi

if [ -f "key.json" ]; then
  log "OK: key.json found"
else
  log "ERROR: key.json not found"
  exit 1
fi

if [ -d "certs.d" ]; then
  log "OK: certs.d found"
else
  log "ERROR: certs.d not found"
  exit 1
fi

# ─────────────────────────────────────
# STEP 11 - COPY CERTS
# ─────────────────────────────────────
log "=== Step 11: Copy Certs ==="
cp -r daemon.json key.json certs.d $ETC_DOCKER/
if [ $? -eq 0 ]; then
  log "Certs copied successfully"
else
  log "ERROR: Certs copy failed"
  exit 1
fi

if [ -f "$ETC_DOCKER/daemon.json" ] && \
   [ -f "$ETC_DOCKER/key.json" ] && \
   [ -d "$ETC_DOCKER/certs.d" ]; then
  log "OK: All certs verified"
else
  log "ERROR: Cert verification failed"
  exit 1
fi

# ─────────────────────────────────────
# STEP 12 - CHANGE OWNERSHIP
# ─────────────────────────────────────
log "=== Step 12: Change Ownership ==="
chown -R root:root $ETC_DOCKER/
if [ $? -eq 0 ]; then
  log "Ownership set to root:root"
else
  log "ERROR: chown failed"
  exit 1
fi

OWNER=$(stat -c '%U:%G' "$ETC_DOCKER")
if [ "$OWNER" = "root:root" ]; then
  log "OK: Ownership verified"
else
  log "ERROR: Ownership failed: $OWNER"
  exit 1
fi

# ─────────────────────────────────────
# STEP 13 - CHECK JKSLAVE
# ─────────────────────────────────────
log "=== Step 13: Check jkslave ==="
if id "$TARGET_USER" > /dev/null 2>&1; then
  log "jkslave found"
else
  log "ERROR: jkslave not found"
  exit 1
fi

groupadd -f docker
usermod -aG docker "$TARGET_USER"
log "jkslave added to docker group"

# ─────────────────────────────────────
# STEP 14 - START DOCKER AS JKSLAVE
# ─────────────────────────────────────
log "=== Step 14: Start Docker ==="
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

runuser -l "$TARGET_USER" -c "sudo systemctl enable docker"
log "Docker enabled on reboot"

# ─────────────────────────────────────
# STEP 15 - VERIFY DOCKER RUNNING
# ─────────────────────────────────────
log "=== Step 15: Verify ==="
runuser -l "$TARGET_USER" -c "sudo systemctl status docker --no-pager | head -n 5"
if [ $? -eq 0 ]; then
  log "SUCCESS: Docker is running"
else
  log "ERROR: Docker is not running"
  exit 1
fi

runuser -l "$TARGET_USER" -c "docker --version"
runuser -l "$TARGET_USER" -c "docker ps"

log "================================"
log "Docker Installation Complete!"
log "Server : $(hostname)"
log "================================"
