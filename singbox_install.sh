cat << 'EOF' > singbox_install.sh
#!/bin/bash

# --- 基础颜色定义 ---
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
PLAIN='\033[0m'

echo -e "${BLUE}=== Sing-box Hysteria2 + Reality 自动化安装脚本 ===${PLAIN}"

# 1. 用户输入配置信息
read -p "请输入你的域名 (例如 is.essaysea.top): " DOMAIN
read -p "请输入你的邮箱 (用于申请证书): " EMAIL
read -p "请输入 Hy2 的密码 (默认 s462HpJGOEnX0zKF): " HY2_PASS
HY2_PASS=${HY2_PASS:-s462HpJGOEnX0zKF}
read -p "请输入 Hy2 的 UDP 监听端口 (默认 48575): " HY2_PORT
HY2_PORT=${HY2_PORT:-48575}

# 2. 检查端口占用
check_port() {
    local port=$1
    if lsof -i :$port >/dev/null 2>&1; then
        echo -e "${RED}[警告] 端口 $port 已被占用，请先停止相关服务 (如 Nginx 或 X-UI)${PLAIN}"
        exit 1
    fi
}
check_port 443
check_port $HY2_PORT

# 3. 安装 Sing-box
echo -e "${GREEN}[1/5] 正在安装 Sing-box 官方内核...${PLAIN}"
bash <(curl -fsSL https://sing-box.app/deb-install.sh)

# 4. 生成密钥参数
echo -e "${GREEN}[2/5] 正在生成协议密钥参数...${PLAIN}"
UUID=$(sing-box generate uuid)
KEYPAIR=$(sing-box generate reality-keypair)
PRIVATE_KEY=$(echo "$KEYPAIR" | grep "Private Key" | awk '{print $3}')
PUBLIC_KEY=$(echo "$KEYPAIR" | grep "Public Key" | awk '{print $3}')
SID=$(sing-box generate rand --hex 8)

# 5. 写入配置文件
echo -e "${GREEN}[3/5] 正在写入配置文件 /etc/sing-box/config.json ...${PLAIN}"
cat << JSON > /etc/sing-box/config.json
{
  "log": { "level": "info", "timestamp": true },
  "inbounds": [
    {
      "type": "hysteria2",
      "tag": "hy2-in",
      "listen": "::",
      "listen_port": $HY2_PORT,
      "users": [{ "password": "$HY2_PASS" }],
      "tls": {
        "enabled": true,
        "server_name": "$DOMAIN",
        "acme": { "domain": "$DOMAIN", "email": "$EMAIL" }
      }
    },
    {
      "type": "vless",
      "tag": "reality-in",
      "listen": "::",
      "listen_port": 443,
      "sniffing": { "enabled": true, "dest_override": ["http", "tls", "quic"] },
      "users": [{ "uuid": "$UUID", "flow": "xtls-rprx-vision" }],
      "tls": {
        "enabled": true,
        "server_name": "www.icould.com",
        "reality": {
          "enabled": true,
          "handshake": { "server": "www.icould.com", "server_port": 443 },
          "private_key": "$PRIVATE_KEY",
          "short_id": ["$SID"]
        }
      }
    }
  ],
  "outbounds": [{ "type": "direct", "tag": "direct" }]
}
JSON

# 6. 启动服务
echo -e "${GREEN}[4/5] 正在启动服务...${PLAIN}"
systemctl enable --now sing-box

# 7. 输出客户端配置信息
echo -e "\n${BLUE}=== 安装完成！请保存以下客户端配置信息 ===${PLAIN}"
echo -e "${GREEN}--- Hysteria2 节点 ---${PLAIN}"
echo -e "地址: $DOMAIN : $HY2_PORT"
echo -e "密码: $HY2_PASS"
echo -e "SNI: $DOMAIN"
echo -e "\n${GREEN}--- VLESS Reality 节点 ---${PLAIN}"
echo -e "地址: $DOMAIN : 443"
echo -e "UUID: $UUID"
echo -e "Flow: xtls-rprx-vision"
echo -e "PublicKey: $PUBLIC_KEY"
echo -e "ShortID: $SID"
echo -e "SNI/ServerNames: www.microsoft.com"
EOF

chmod +x singbox_install.sh
