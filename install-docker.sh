#!/bin/bash
# Docker 二进制安装脚本（离线 PVE / ARM64 环境）
# 适用：Debian 12 (bookworm) + aarch64
# 如需 x86_64，请修改 ARCH 变量

set -e

ARCH="aarch64"                 # aarch64 或 x86_64
DOCKER_VERSION="27.3.1"       # Docker 版本
COMPOSE_ARCH="aarch64"         # compose 的架构标识
IMAGE_TGZ="${1:-miniorsync.tar.gz}"   # 待导入的镜像包（可选，第一个参数传入）

echo "=============================================="
echo "  Docker 二进制安装 (${ARCH})"
echo "=============================================="

# 1. 下载 Docker 静态二进制包
echo "[1/7] 下载 Docker 二进制包..."
wget -q --show-progress \
  "https://download.docker.com/linux/static/stable/${ARCH}/docker-${DOCKER_VERSION}.tgz" \
  -O docker.tgz

# 2. 解压并安装
echo "[2/7] 解压并安装..."
tar xzf docker.tgz
cp docker/* /usr/bin/
rm -rf docker/ docker.tgz

# 3. 下载 Docker Compose
echo "[3/7] 下载 Docker Compose..."
curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-linux-${COMPOSE_ARCH}" \
  -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# 4. 创建 systemd 服务
echo "[4/7] 创建 systemd 服务..."
cat > /etc/systemd/system/docker.service << 'EOF'
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com
After=network-online.target firewalld.service containerd.service
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/dockerd
ExecReload=/bin/kill -s HUP $MAINPID
TimeoutSec=0
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

# 5. 配置 Docker Daemon 参数（镜像加速、日志切分、驱动）
echo "[5/7] 配置 daemon.json..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
EOF

# 6. 重载 systemd 并启动 Docker
echo "[6/7] 重载 systemd 并启动 Docker..."
systemctl daemon-reload
systemctl enable --now docker

# 7. 验证
echo "[7/7] 验证..."
docker --version
docker-compose --version
systemctl is-active docker

echo ""
echo "=============================================="
echo "  安装完成！"
echo "=============================================="

# 可选：导入镜像
if [ -f "${IMAGE_TGZ}" ]; then
    echo "检测到镜像包 ${IMAGE_TGZ}，正在导入..."
    docker load -i "${IMAGE_TGZ}"
else
    echo "未检测到镜像包，跳过 docker load。"
    echo "如需导入，执行：docker load -i ${IMAGE_TGZ}"
fi
