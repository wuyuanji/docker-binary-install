# Docker 二进制安装方案（离线 PVE / ARM64 环境）

针对 **离线安装 PVE** 且 apt 源指向本地 `file:///tmp/pve/` 的服务器，通过**静态二进制**方式安装 Docker 与 Docker Compose，不干扰 PVE 现有环境。

---

## 适用环境

| 项目 | 说明 |
|------|------|
| 操作系统 | Debian 12 (bookworm) |
| 架构 | aarch64 (ARM64) |
| 特殊场景 | 离线 PVE，apt 源为本地 file:// |
| 外网访问 | 可访问 `download.docker.com` |

> 若为 x86_64 架构，仅需将下载地址中的 `aarch64` 替换为 `x86_64`。

---

## 安装步骤

### 1. 下载 Docker 静态二进制包

```bash
# ARM64 架构
wget https://download.docker.com/linux/static/stable/aarch64/docker-27.3.1.tgz

# x86_64 架构（如有需要）
# wget https://download.docker.com/linux/static/stable/x86_64/docker-27.3.1.tgz
```

### 2. 解压并安装

```bash
tar xzvf docker-27.3.1.tgz

# 复制二进制到系统目录
cp docker/* /usr/bin/

# 清理临时文件
rm -rf docker/ docker-27.3.1.tgz
```

### 3. 下载 Docker Compose（独立二进制）

```bash
# ARM64 架构
curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-aarch64 \
  -o /usr/local/bin/docker-compose

# x86_64 架构（如有需要）
# curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-x86_64 \
#   -o /usr/local/bin/docker-compose

chmod +x /usr/local/bin/docker-compose
```

### 4. 创建 systemd 服务（开机自启）

> 二进制解压安装的 Docker **默认不会自动生成 systemd 服务文件**，需手动创建 `docker.service`。

创建 `/etc/systemd/system/docker.service`：

```ini
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
```

### 5. 配置 Docker Daemon 参数（可选但建议）

创建 `/etc/docker/daemon.json`，配置镜像加速、日志切分及驱动：

```bash
mkdir -p /etc/docker
cat << 'EOF' > /etc/docker/daemon.json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  }
}
EOF
```

### 6. 重载 systemd 并启动 Docker

```bash
# 重新加载 systemd 配置
systemctl daemon-reload

# 设置开机自启并立即启动
systemctl enable --now docker

# 检查运行状态
systemctl status docker
```

### 7. 验证与加载镜像

```bash
# 验证 Docker 正常运行
docker --version
docker-compose --version
docker run hello-world

# 导入镜像（如 MiniIO 同步镜像）
docker load -i miniorsync.tar.gz
```

---

## 为什么选择二进制安装（而非 apt）

| 对比项 | 二进制安装 | apt 安装 |
|--------|-----------|----------|
| 依赖 apt 源 | ❌ 不需要 | ✅ 需要 |
| 干扰 PVE 离线源 | ❌ 不干扰 | ⚠️ 可能冲突 |
| 卸载便利性 | ✅ 删除即可 | 需 apt 卸载 |
| 环境可控性 | ✅ 完全独立 | 一般 |

---

## 注意事项

1. **Docker 版本**：`27.3.1` 为示例版本，可根据需要调整，[可用的 stable 版本列表](https://download.docker.com/linux/static/stable/aarch64/)。
2. **containerd**：静态包内已包含 `containerd`、`dockerd`、`docker` 等组件，无需额外安装。
3. **数据目录**：默认 `/var/lib/docker`，如需迁移到独立磁盘（如 `/data/docker`），需在 `dockerd` 启动参数中配置 `--data-root`。

---

## 附：完整一键脚本

见 [install-docker.sh](./install-docker.sh)
