#!/bin/bash
# ===============================================
#         Giwa 节点安装助手 / Setup Tool
# ===============================================

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

REPO_URL="https://github.com/giwa-io/node.git"
NODE_DIR="$HOME/giwa-node"
ENV_FILE="$NODE_DIR/.env"

log() { echo -e "${BLUE}[INFO]${RESET} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${RESET} $1"; }
error() { echo -e "${RED}[ERROR]${RESET} $1"; }

# ---------------------------
# 安装依赖与 Docker/Docker Compose
# ---------------------------
install_env() {
    log "更新系统并安装依赖..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl git wget jq htop ncdu unzip ca-certificates software-properties-common

    if ! command -v docker >/dev/null; then
        log "安装 Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        sudo systemctl enable docker --now
        rm get-docker.sh
        success "Docker 安装完成！"
    else
        log "Docker 已安装，跳过"
    fi

    if ! command -v docker-compose >/dev/null; then
        log "安装 Docker Compose..."
        DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)
        sudo curl -L "https://github.com/docker/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        success "Docker Compose 安装完成！"
    else
        log "Docker Compose 已安装，跳过"
    fi

    sudo apt autoremove -y
    success "环境准备完成！"
}

# ---------------------------
# 克隆或更新仓库
# ---------------------------
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

# ---------------------------
# 配置 .env
# ---------------------------
config_env() {
    cd "$NODE_DIR" || exit
    if [ ! -f "$ENV_FILE" ]; then
        log "复制默认配置文件 .env.sepolia..."
        cp .env.sepolia .env
    fi

    read -p "输入 L1 RPC URL (Infura/Alchemy): " L1_RPC
    read -p "输入 L1 Beacon URL (OnFinality): " L1_BEACON

    sed -i "s|^OP_NODE_L1_ETH_RPC=.*|OP_NODE_L1_ETH_RPC=$L1_RPC|" "$ENV_FILE"
    sed -i "s|^OP_NODE_L1_BEACON=.*|OP_NODE_L1_BEACON=$L1_BEACON|" "$ENV_FILE"

    if ! grep -q "OP_NODE_L1_ETH_RPC_TLS_SKIP_VERIFY" "$ENV_FILE"; then
        echo "OP_NODE_L1_ETH_RPC_TLS_SKIP_VERIFY=true" >> "$ENV_FILE"
    fi

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

# ---------------------------
# 启动节点
# ---------------------------
start_node() {
    cd "$NODE_DIR" || exit
    log "构建并启动节点..."
    docker compose build --parallel
    docker compose up -d

    sleep 5
    for name in giwa-el giwa-cl; do
        status=$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null || echo "false")
        if [ "$status" != "true" ]; then
            error "容器 $name 未启动，请检查 docker logs $name"
        else
            success "容器 $name 已启动"
        fi
    done
}

# ---------------------------
# 停止节点
# ---------------------------
stop_node() {
    cd "$NODE_DIR" || exit
    log "停止 Giwa 节点..."
    docker compose down
    success "节点已停止"
}

# ---------------------------
# 清理节点
# ---------------------------
clean_node() {
    cd "$NODE_DIR" || exit
    log "停止并清理数据..."
    docker compose down -v
    rm -rf ./execution_data ./consensus_data
    success "节点数据已清理"
}

# ---------------------------
# 查看日志
# ---------------------------
show_logs() {
    while true; do
        clear
        echo -e "${YELLOW}===== 查看节点日志 =====${RESET}"
        echo "1) 执行层日志 (EL)"
        echo "2) 共识层日志 (CL)"
        echo "0) 返回"
        read -p "选择日志类型: " LOG_CHOICE
        case $LOG_CHOICE in
            1) docker logs -f giwa-el ;;
            2) docker logs -f giwa-cl ;;
            0) break ;;
            *) error "无效选项" ;;
        esac
    done
}

# ---------------------------
# 主菜单（显示署名信息）
# ---------------------------
menu() {
    while true; do
        clear
        echo -e "${GREEN}===== Giwa 节点安装助手 =====${RESET}"
        echo -e "${BLUE}📌 作者: K2 Node${RESET}"
        echo -e "${BLUE}🔗 Telegram: https://t.me/+EaCiFDOghoM3Yzll${RESET}"
        echo -e "${BLUE}🐦 Twitter: https://x.com/BtcK241918${RESET}"
        echo "-----------------------------------------------"
        echo "1) 安装环境 (依赖 + Docker + 仓库 + 配置)"
        echo "2) 启动节点"
        echo "3) 停止节点"
        echo "4) 清理节点数据"
        echo "5) 查看节点日志"
        echo "0) 退出"
        read -p "请选择操作: " CHOICE

        case $CHOICE in
            1) install_env; clone_repo; config_env ;;
            2) start_node ;;
            3) stop_node ;;
            4) clean_node ;;
            5) show_logs ;;
            0) exit 0 ;;
            *) error "无效选择" ;;
        esac
    done
}

# ---------------------------
# 启动菜单
# ---------------------------
menu
