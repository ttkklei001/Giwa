#!/bin/bash
# ===============================================
#         Giwa 节点安装助手 / Setup Tool
# ===============================================

# 📌 作者: K2 Node
# 🔗 Telegram: https://t.me/+EaCiFDOghoM3Yzll
# 🐦 Twitter:  https://x.com/BtcK241918
# -----------------------------------------------

# ----- 颜色定义 -----
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

# ----- 变量 -----
REPO_URL="https://github.com/giwa-io/node.git"
NODE_DIR="$HOME/giwa-node"
ENV_FILE="$NODE_DIR/.env"

# ----- 输出函数 -----
log() { echo -e "${BLUE}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
error() { echo -e "${RED}[ERROR]${RESET} $1"; }

pause() { read -p "按 Enter 返回菜单..."; }

# ----- 安装精简依赖 + Docker + Docker Compose -----
install_env() {
  log "更新系统并安装精简依赖..."
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y curl git wget jq htop ncdu unzip ca-certificates software-properties-common

  # 安装 Docker
  if ! command -v docker >/dev/null 2>&1; then
    log "正在安装 Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    sudo systemctl enable docker --now
    rm get-docker.sh
    success "Docker 安装完成！"
  else
    log "Docker 已安装，跳过。"
  fi

  # 安装 Docker Compose
  if ! command -v docker-compose >/dev/null 2>&1; then
    log "正在安装 Docker Compose..."
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
    sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    success "Docker Compose 安装完成！"
  else
    log "Docker Compose 已安装，跳过。"
  fi

  sudo apt autoremove -y
  success "环境准备完成！"
}

# ----- 拉取仓库 -----
clone_repo() {
  if [ -d "$NODE_DIR" ]; then
    log "目录已存在，更新仓库..."
    cd "$NODE_DIR" && git pull
  else
    log "克隆 Giwa Node 仓库..."
    git clone "$REPO_URL" "$NODE_DIR"
  fi
  success "仓库准备完成！"
}

# ----- 配置环境文件 -----
config_env() {
  cd "$NODE_DIR" || exit
  if [ ! -f "$ENV_FILE" ]; then
    log "复制默认配置文件 .env.sepolia..."
    cp .env.sepolia .env
  fi

  echo -e "${YELLOW}请填写你的以太坊 RPC 和 Beacon 节点信息:${RESET}"
  read -p "输入 L1 RPC URL: " L1_RPC
  read -p "输入 L1 BEACON URL: " L1_BEACON

  sed -i "s|^L1_RPC_URL=.*|L1_RPC_URL=$L1_RPC|" "$ENV_FILE"
  sed -i "s|^L1_BEACON_URL=.*|L1_BEACON_URL=$L1_BEACON|" "$ENV_FILE"

  log "请选择同步模式:"
  echo "1) snap (推荐测试网)"
  echo "2) archive"
  echo "3) consensus"
  read -p "输入选项 (1-3): " MODE

  case $MODE in
    1) sed -i "s|^SYNC_MODE=.*|SYNC_MODE=snap|" "$ENV_FILE" ;;
    2) sed -i "s|^SYNC_MODE=.*|SYNC_MODE=archive|" "$ENV_FILE" ;;
    3) sed -i "s|^SYNC_MODE=.*|SYNC_MODE=consensus|" "$ENV_FILE" ;;
    *) error "无效选项，默认 snap"; sed -i "s|^SYNC_MODE=.*|SYNC_MODE=snap|" "$ENV_FILE" ;;
  esac

  success "环境配置完成！"
}

# ----- 一键安装环境（包含依赖 + Docker + 仓库 + 配置） -----
setup_env() {
  install_env
  clone_repo
  config_env
  success "环境安装与配置完成！"
}

# ----- 启动节点 -----
start_node() {
  cd "$NODE_DIR" || exit
  log "构建并启动 Giwa 节点..."
  docker compose build --parallel
  NETWORK_ENV=.env docker compose up -d
  success "节点已启动！"
}

# ----- 停止节点 -----
stop_node() {
  cd "$NODE_DIR" || exit
  log "停止 Giwa 节点..."
  docker compose down
  success "节点已停止！"
}

# ----- 清理节点数据 -----
clean_node() {
  cd "$NODE_DIR" || exit
  log "停止并清理所有数据..."
  docker compose down -v
  rm -rf ./execution_data
  success "数据已清理！"
}

# ----- 分菜单查看日志 -----
show_logs() {
  while true; do
    clear
    echo -e "${GREEN}===== Giwa 节点日志查看 / Log Viewer =====${RESET}"
    echo "1) 查看执行层日志 (Execution Layer)"
    echo "2) 查看共识层日志 (Consensus Layer)"
    echo "3) 返回主菜单"
    echo "-----------------------------------------------"
    read -p "请选择操作 [1-3]: " LOG_CHOICE

    case $LOG_CHOICE in
      1)
        log "正在查看执行层日志 (CTRL+C 退出)..."
        docker logs -f giwa-el
        pause
        ;;
      2)
        log "正在查看共识层日志 (CTRL+C 退出)..."
        docker logs -f giwa-cl
        pause
        ;;
      3)
        break
        ;;
      *)
        error "无效选择，请重新输入！"
        sleep 1
        ;;
    esac
  done
}

# ----- 主菜单 -----
menu() {
  clear
  echo -e "${GREEN}===== Giwa 节点安装助手 / Setup Tool =====${RESET}"
  echo "1) 安装环境 (依赖 + Docker + 仓库 + 配置)"
  echo "2) 启动节点"
  echo "3) 停止节点"
  echo "4) 清理节点数据"
  echo "5) 查看节点日志"
  echo "0) 退出"
  echo "-----------------------------------------------"
  read -p "请选择操作: " CHOICE

  case $CHOICE in
    1) setup_env ;;
    2) start_node ;;
    3) stop_node ;;
    4) clean_node ;;
    5) show_logs ;;
    0) exit 0 ;;
    *) error "无效选项" ;;
  esac
}

# ----- 主循环 -----
while true; do
  menu
  pause
done
