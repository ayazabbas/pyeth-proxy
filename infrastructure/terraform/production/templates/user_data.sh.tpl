#!/bin/bash
set -xe

# Save the output of this script to /var/log/user-data.log
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1


## INSTALL DOCKER & AWSCLI

apt-get update
apt-get install -y ca-certificates curl gnupg unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

curl -SL https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

groupadd -f docker
usermod -aG docker ubuntu


## CLONE APPLICATION REPO

sudo -u ubuntu ssh-keyscan -t rsa github.com >> /home/ubuntu/.ssh/known_hosts
cat <<EOF > /home/ubuntu/.ssh/id_ed25519
${GITHUB_SSH_KEY}
EOF
chown ubuntu:ubuntu /home/ubuntu/.ssh/id_ed25519
chmod 0600 /home/ubuntu/.ssh/id_ed25519
sudo -u ubuntu git clone --depth=1 git@github.com:ayazabbas/pyeth-proxy.git /home/ubuntu/pyeth-proxy


## CREATE SYSTEMD SERVICE

cat <<EOF > /etc/systemd/system/pyeth-proxy.service
[Unit]
  Description=pyeth-proxy: a Python API for proxying Ethereum RPC requests across multiple nodes or RPC providers

[Service]
  Type=simple
  Restart=always
  RestartSec=2s
  User=ubuntu
  WorkingDirectory=/home/ubuntu/pyeth-proxy
  Environment=IMAGE_TAG=${ECR_URL}/pyeth-proxy:latest
  Environment=RPC_PROVIDERS_HTTP=${RPC_PROVIDERS_HTTP}
  Environment=TIMEOUT_SECONDS=${TIMEOUT_SECONDS}
  Environment=LOKI_URL=${LOKI_URL}
  Environment=LOKI_USER=${LOKI_USER}
  Environment=LOKI_PASSWORD=${LOKI_PASSWORD}
  ExecStartPre=/bin/bash -c "aws ecr get-login-password --region ${ECR_REGION} | docker login --username AWS --password-stdin ${ECR_URL}"
  ExecStart=docker-compose up --abort-on-container-exit

[Install]
  WantedBy=multi-user.target
EOF


## START SYSTEMD SERVICE

systemctl start pyeth-proxy.service
