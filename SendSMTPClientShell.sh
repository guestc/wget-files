#!/bin/bash
set -e

SERVICE_NAME="smtpsender"
APP_PATH="/home/SendSMTPClientLinux"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
CONFIG_FILE="/etc/${SERVICE_NAME}/config.env"

# 检查参数数量
if [ $# -ne 7 ]; then
  echo "用法: $0 <ARG1> <ARG2> <ARG3> <ARG4> <ARG5> <ARG6> <ARG7>"
  exit 1
fi

ARG1=$1
ARG2=$2
ARG3=$3
ARG4=$4
ARG5=$5
ARG6=$6
ARG7=$7

echo ">>> 开始部署 ${SERVICE_NAME}"

# 先停止服务
echo ">>> 停止服务 ${SERVICE_NAME} (如果在运行)"
sudo systemctl stop ${SERVICE_NAME} || echo "警告: 停止服务 ${SERVICE_NAME} 失败"

# 每次都重新下载程序
echo ">>> 重新下载 SendSMTPClientLinux 到 $APP_PATH"
curl -fsSL -o "$APP_PATH" "https://github.com/guestc/wget-files/releases/download/mail_1.2.85/SendSMTPClientLinux"
chmod +x "$APP_PATH"

# 保存参数到配置文件
echo ">>> 写入配置 $CONFIG_FILE"
sudo mkdir -p "$(dirname $CONFIG_FILE)"
sudo tee "$CONFIG_FILE" > /dev/null <<EOF
ARG1=$ARG1
ARG2=$ARG2
ARG3=$ARG3
ARG4=$ARG4
ARG5=$ARG5
ARG6=$ARG6
ARG7=$ARG7
EOF

# 每次都覆盖写入 systemd 服务文件
echo ">>> 写入 systemd 服务 $SERVICE_FILE"
sudo tee "$SERVICE_FILE" > /dev/null <<EOF
[Unit]
Description=SMTP Client Service
After=network.target

[Service]
Type=simple
EnvironmentFile=$CONFIG_FILE
ExecStart=$APP_PATH "\${ARG1}" "\${ARG2}" "\${ARG3}" "\${ARG4}" "\${ARG5}" "\${ARG6}" "\${ARG7}"
Restart=always
RestartSec=5
StandardOutput=append:/var/log/${SERVICE_NAME}.log
StandardError=append:/var/log/${SERVICE_NAME}.err

[Install]
WantedBy=multi-user.target
EOF

# 启动服务
echo ">>> 启动服务 ${SERVICE_NAME}"
sudo systemctl daemon-reload
sudo systemctl enable ${SERVICE_NAME}
sudo systemctl restart ${SERVICE_NAME}

echo ">>> 部署完成 ✅"
echo "查看状态: systemctl status ${SERVICE_NAME}"
echo "查看日志: journalctl -u ${SERVICE_NAME} -f"
