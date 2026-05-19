#!/usr/bin/env bash

set -euo pipefail

# ============================================================
#  AmneziaWG installer for Wiren Board
# ============================================================

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
GRAY='\033[1;90m'
RESET='\033[0m'

CONFIG_DIR="/etc/amnezia/amneziawg"
CONFIG_FILE="${CONFIG_DIR}/awg0.conf"

# ============================================================
# Spinner
# ============================================================

spinner() {
    local pid=$1
    local delay=0.1
    local spin='|/-\'

    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spin#?}
        printf " [%c]  " "$spin"
        spin=$temp${spin%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done

    printf "    \b\b\b\b"
}

# ============================================================
# Root check
# ============================================================

if [[ "$EUID" -ne 0 ]]; then
    echo -e "${RED}Ошибка: запустите скрипт от root${RESET}"
    exit 1
fi

# ============================================================
# Detect architecture
# ============================================================

detect_go_arch() {

    case "$(uname -m)" in

        armv6l|armv7l)
            echo "linux-armv6l"
            ;;

        aarch64)
            echo "linux-arm64"
            ;;

        x86_64)
            echo "linux-amd64"
            ;;

        *)
            echo ""
            ;;
    esac
}

GO_ARCH=$(detect_go_arch)

if [[ -z "$GO_ARCH" ]]; then
    echo -e "${RED}Неподдерживаемая архитектура: $(uname -m)${RESET}"
    exit 1
fi

# ============================================================
# Header
# ============================================================

show_header() {

    echo
    echo -e "${CYAN}============================================================${RESET}"
    echo -e "${GREEN} AmneziaWG installer for Wiren Board${RESET}"
    echo -e "${CYAN}============================================================${RESET}"
    echo
}

# ============================================================
# Remove old installation
# ============================================================

remove_awg() {

    echo -e "${YELLOW}Удаление старой конфигурации...${RESET}"

    systemctl stop awg-quick@awg0 2>/dev/null || true
    systemctl disable awg-quick@awg0 2>/dev/null || true

    awg-quick down awg0 2>/dev/null || true

    ip link delete awg0 2>/dev/null || true

    rm -f /etc/systemd/system/multi-user.target.wants/awg-quick@awg0.service

    rm -f "$CONFIG_FILE"

    echo -e "${GREEN}Очистка завершена.${RESET}"
}

# ============================================================
# Install dependencies
# ============================================================

install_dependencies() {

    echo -ne "${CYAN}Установка зависимостей... ${RESET}"

    {
        apt-get update

        apt-get install -y \
            git \
            make \
            gcc \
            g++ \
            wget \
            curl \
            resolvconf \
            libmnl-dev \
            libelf-dev
    } >/dev/null 2>&1 &

    spinner $!

    echo -e "${GREEN}OK${RESET}"
}

# ============================================================
# Install Go
# ============================================================

install_go() {

    if command -v go >/dev/null 2>&1; then
        return
    fi

    echo -ne "${CYAN}Установка Go... ${RESET}"

    {
        wget -q \
            "https://go.dev/dl/go1.22.3.${GO_ARCH}.tar.gz" \
            -O /tmp/go.tar.gz

        rm -rf /usr/local/go

        tar -C /usr/local -xzf /tmp/go.tar.gz

    } >/dev/null 2>&1 &

    spinner $!

    export PATH=$PATH:/usr/local/go/bin

    echo -e "${GREEN}OK${RESET}"
}

# ============================================================
# Install amneziawg-go
# ============================================================

install_amneziawg_go() {

    if command -v amneziawg-go >/dev/null 2>&1; then
        return
    fi

    echo -ne "${CYAN}Сборка amneziawg-go... ${RESET}"

    {
        cd /tmp

        rm -rf amneziawg-go

        git clone https://github.com/amnezia-vpn/amneziawg-go.git \
            >/dev/null 2>&1

        cd amneziawg-go

        export PATH=$PATH:/usr/local/go/bin

        make >/dev/null 2>&1

        cp amneziawg-go /usr/bin/

        chmod +x /usr/bin/amneziawg-go

    } >/dev/null 2>&1 &

    spinner $!

    echo -e "${GREEN}OK${RESET}"
}

# ============================================================
# Install awg-tools
# ============================================================

install_awg_tools() {

    if command -v awg-quick >/dev/null 2>&1; then
        return
    fi

    echo -ne "${CYAN}Сборка awg-tools... ${RESET}"

    {
        cd /tmp

        rm -rf amneziawg-tools

        git clone https://github.com/amnezia-vpn/amneziawg-tools.git \
            >/dev/null 2>&1

        cd amneziawg-tools/src

        make >/dev/null 2>&1
        make install >/dev/null 2>&1

    } >/dev/null 2>&1 &

    spinner $!

    echo -e "${GREEN}OK${RESET}"
}

# ============================================================
# Read config safely
# ============================================================

read_config() {

    mkdir -p "$CONFIG_DIR"

    echo
    echo -e "${YELLOW}📋 Вставьте конфиг AmneziaWG${RESET}"
    echo -e "${GRAY}Завершение ввода: CTRL+D${RESET}"
    echo

    cat > "$CONFIG_FILE" < /dev/tty

    echo

    if [[ ! -s "$CONFIG_FILE" ]]; then
        echo -e "${RED}Ошибка: конфиг пустой${RESET}"
        exit 1
    fi

    if ! grep -q "\[Interface\]" "$CONFIG_FILE"; then
        echo -e "${RED}Ошибка: отсутствует секция [Interface]${RESET}"
        exit 1
    fi

    if ! grep -q "\[Peer\]" "$CONFIG_FILE"; then
        echo -e "${RED}Ошибка: отсутствует секция [Peer]${RESET}"
        exit 1
    fi

    # Удаляем CRLF
    sed -i 's/\r//g' "$CONFIG_FILE"

    # Добавляем Keepalive если отсутствует
    if ! grep -qi '^PersistentKeepalive' "$CONFIG_FILE"; then

        sed -i '/^\[Peer\]/a PersistentKeepalive = 25' "$CONFIG_FILE"
    fi

    chmod 600 "$CONFIG_FILE"

    echo -e "${GREEN}Конфиг сохранен.${RESET}"
}

# ============================================================
# Backup current config
# ============================================================

backup_config() {

    if [[ -f "$CONFIG_FILE" ]]; then

        cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"
    fi
}

# ============================================================
# Restore backup
# ============================================================

restore_backup() {

    if [[ -f "${CONFIG_FILE}.backup" ]]; then

        cp "${CONFIG_FILE}.backup" "$CONFIG_FILE"

        systemctl restart awg-quick@awg0 || true

        echo -e "${YELLOW}Восстановлен предыдущий конфиг.${RESET}"
    fi
}

# ============================================================
# Start tunnel safely
# ============================================================

start_tunnel() {

    echo
    echo -e "${CYAN}🔌 Запуск туннеля...${RESET}"

    systemctl daemon-reload

    systemctl enable awg-quick@awg0 >/dev/null 2>&1

    if ! systemctl restart awg-quick@awg0; then

        echo
        echo -e "${RED}Ошибка запуска туннеля${RESET}"

        systemctl status awg-quick@awg0 --no-pager || true

        restore_backup

        exit 1
    fi

    sleep 2

    if ! ip link show awg0 >/dev/null 2>&1; then

        echo -e "${RED}Интерфейс awg0 не поднялся${RESET}"

        restore_backup

        exit 1
    fi
}

# ============================================================
# Show status
# ============================================================

show_status() {

    echo
    echo -e "${GREEN}============================================================${RESET}"
    echo -e "${GREEN}🎉 Туннель успешно поднят${RESET}"
    echo -e "${GREEN}============================================================${RESET}"

    if command -v wb-gen-serial >/dev/null 2>&1; then

        SN=$(wb-gen-serial -s)

        echo
        echo -e "Контроллер: ${YELLOW}${SN}${RESET}"
    fi

    TUNNEL_IP=$(grep '^Address' "$CONFIG_FILE" | head -n1 | cut -d '=' -f2 | xargs)

    echo -e "Tunnel IP: ${BLUE}${TUNNEL_IP}${RESET}"

    echo

    awg show || true

    echo
}

# ============================================================
# Main
# ============================================================

show_header

case "${1:-install}" in

    install)

        install_dependencies
        install_go
        install_amneziawg_go
        install_awg_tools

        backup_config

        read_config
        start_tunnel
        show_status
        ;;

    reinstall)

        remove_awg

        install_dependencies
        install_go
        install_amneziawg_go
        install_awg_tools

        read_config
        start_tunnel
        show_status
        ;;

    remove)

        remove_awg
        ;;

    status)

        systemctl status awg-quick@awg0 --no-pager
        ;;

    *)

        echo
        echo "Использование:"
        echo
        echo "install     - установка"
        echo "reinstall   - переустановка"
        echo "remove      - удаление"
        echo "status      - статус"
        echo

        exit 1
        ;;
esac
