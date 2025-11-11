#!/bin/bash
# ==================================================
# Dante SOCKS5 Server 自动部署脚本（系统用户认证版）
# 用法:
#   sudo bash install_dante.sh <用户名> <密码> <端口>
# ==================================================

set -e

if [ $# -ne 3 ]; then
    echo "用法: $0 <用户名> <密码> <端口>"
    exit 1
fi

PROXY_USER="$1"
PROXY_PASS="$2"
PROXY_PORT="$3"

echo "开始安装 Dante SOCKS5 Server..."
echo "用户名: $PROXY_USER"
echo "端口: $PROXY_PORT"

export DEBIAN_FRONTEND=noninteractive

# === 预设 iptables-persistent 选项，避免交互 ===
echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | sudo debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | sudo debconf-set-selections

# === 安装依赖 ===
sudo apt update -y
sudo apt install -y dante-server net-tools curl iptables-persistent > /dev/null

# === 自动检测默认出口网卡 ===
NET_IF=$(ip route get 8.8.8.8 2>/dev/null | awk '{for(i=1;i<=NF;i++){if($i=="dev"){print $(i+1)}}}' | head -n1)
if [ -z "$NET_IF" ]; then
    NET_IF=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -n1)
fi
echo "检测到网卡: $NET_IF"

# === 创建系统用户 ===
if id "$PROXY_USER" &>/dev/null; then
    echo "用户 $PROXY_USER 已存在，更新密码..."
    echo "${PROXY_USER}:${PROXY_PASS}" | sudo chpasswd
else
    echo "创建用户 $PROXY_USER..."
    sudo useradd -m -s /usr/sbin/nologin "$PROXY_USER"
    echo "${PROXY_USER}:${PROXY_PASS}" | sudo chpasswd
fi

# === Dante 配置文件 ===
sudo bash -c "cat > /etc/danted.conf" <<EOF
logoutput: /var/log/danted.log

internal: ${NET_IF} port = ${PROXY_PORT}
external: ${NET_IF}

user.notprivileged: nobody

# 使用系统 PAM 认证（系统用户）
method: username
clientmethod: none

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}

socks pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    command: connect bind udpassociate
    log: connect disconnect error
}
EOF

# === 启动并设置自启 ===
sudo systemctl enable danted
sudo systemctl restart danted

# === 防火墙放行端口 ===
echo "配置防火墙，开放端口 ${PROXY_PORT}..."

if command -v ufw >/dev/null 2>&1; then
    sudo ufw allow ${PROXY_PORT}/tcp || true
    echo "ufw 已放行端口 ${PROXY_PORT}"
else
    sudo iptables -I INPUT -p tcp --dport ${PROXY_PORT} -j ACCEPT
    sudo DEBIAN_FRONTEND=noninteractive netfilter-persistent save
    echo "iptables 已放行端口 ${PROXY_PORT}"
fi

# === 输出结果 ===
SERVER_IP=$(curl -s ifconfig.me || hostname -I | awk '{print $1}')
echo "✅ Dante SOCKS5 安装完成（系统用户认证）"
echo "===================================="
echo "  地址: ${SERVER_IP}"
echo "  端口: ${PROXY_PORT}"
echo "  用户: ${PROXY_USER}"
echo "  密码: ${PROXY_PASS}"
echo "===================================="
echo "测试命令:"
echo "  curl --socks5 --proxy-user ${PROXY_USER}:${PROXY_PASS} -x socks5h://${SERVER_IP}:${PROXY_PORT} http://ipinfo.io/ip"
echo "===================================="
