#!/bin/bash
# Docker 二进制安装脚本（离线 PVE / ARM64 环境）
# 适用：Debian 12 (bookworm) + aarch64
# 如需 x86_64，请修改 ARCH 变量

set -e

ARCH="aarch64"                 # aarch64 或 x86_64
DOCKER_VERSION="27.3.1"       # Docker 版本
COMPOSE_ARCH="aarch64"         # compose 的架构标识

echo "=============================================="
echo "  Docker 二进制安装 (${ARCH})"
echo "=============================================="

# 1. 下载 Docker 静态二进制包
echo "[1/5] 下载 Docker 二进制包..."
wget -q --show-progress \
  "https://download.docker.com/linux/static/stable/${ARCH}/docker-${DOCKER_VERSION}.tgz" \
  -O docker.tgz

# 2. 解压并安装
echo "[2/5] 解压并安装..."
tar xzf docker.tgz
cp docker/* /usr/bin/
rm -rf docker/ docker.tgz

# 3. 下载 Docker Compose
echo "[3/5] 下载 Docker Compose..."
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-${COMPOSE_ARCH}" \
  -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# 4. 创建 systemd 服务
echo "[4/5] 创建 systemd 服务..."
cat > /etc/systemd/system/docker.service << 'EOF'
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target containerd.service
Wants=network-online.target
Requires=containerd.service

[Service]
Type=notify
ExecStart=/usr/bin/dockerd --containerd=/run/containerd/containerd.sock
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutStartSec=0
RestartSec=2
Restart=always
LimitNOFILE=infinity
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
Delegate=yes
KillMode=process
OOMScoreAdjust=-500

[Install]
WantedBy=multi-user.target
EOF

# 5. 启动并验证
echo "[5/5] 启动 Docker..."
systemctl daemon-reload
systemctl enable docker
systemctl start docker

echo ""
echo "=============================================="
echo "  安装完成！"
echo "=============================================="
docker --version
docker-compose --version
echo ""
echo "验证：docker run hello-world"
