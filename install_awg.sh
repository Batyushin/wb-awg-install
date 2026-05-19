#!/usr/bin/env bash

set -Eeuo pipefail

# ============================================================
#  AmneziaWG Installer for Wiren Board
# ============================================================

VERSION="2.2"

# ============================================================
# Colors
# ============================================================

GREEN='\033[1;32m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
BLUE='\033[1;34m'
GRAY='\033[1;90m'
RESET='\033[0m'

# ============================================================
# Paths
# ============================================================

CONFIG_DIR="/etc/amnezia/amneziawg"
CONFIG_FILE="${CONFIG_DIR}/awg0.conf"
BACKUP_FILE="${CONFIG_DIR}/awg0.conf.backup"
DNS_BACKUP="/tmp/resolv.conf.backup"

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
# Error handler
# ============================================================

error_handler() {
    local line="$1"

    echo
    echo -e "${RED}Ошибка выполнения скрипта (line: ${line})${RESET}"
    echo

    restore_dns || true
    cleanup_temp || true

    exit 1
}

trap 'error_handler ${LINENO}' ERR

# ============================================================
# Root check
# ============================================================

check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo -e "${RED}Запустите скрипт от root${RESET}"
        exit 1
    fi
}

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

# ============================================================
# Header
# ============================================================

show_header() {
    echo
    echo -e "${CYAN}============================================================${RESET}"
    echo -e "${GREEN} AmneziaWG installer for Wiren Board${RESET}"
    echo -e "${GRAY} Version ${VERSION}${RESET}"
    echo -e "${CYAN}============================================================${RESET}"
    echo
}

# ============================================================
# DNS Management
# ============================================================

backup_dns() {
    if [[ ! -f "$DNS_BACKUP" ]]; then
        cp /etc/resolv.conf "$DNS_BACKUP" 2>/dev/null || true
        # Временно ставим надежные DNS для скачивания пакетов и исходников
        cat > /etc/resolv.conf <<EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF
    fi
}

restore_dns() {
    if [[ -f "$DNS_BACKUP" ]]; then
        cp "$DNS_BACKUP" /etc/resolv.conf
        rm -f "$DNS_BACKUP"
    fi
}

# ============================================================
# Cleanup Temporary Files
# ============================================================

cleanup_temp() {
    rm -rf /tmp/amneziawg-go /tmp/amneziawg-tools /tmp/go.tar.gz
}

# ============================================================
# Check internet
# ============================================================

check_internet() {
    echo -ne "${CYAN}Проверка интернета... ${RESET}"

    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${GREEN}OK${RESET}"
    else
        echo -e "${RED}Нет доступа в интернет${RESET}"
        restore_dns
        exit 1
    fi
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
# Backup config
# ============================================================

backup_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        cp "$CONFIG_FILE" "$BACKUP_FILE"
    fi
}

# ============================================================
# Restore backup
# ============================================================

restore_backup() {
    if [[ -f "$BACKUP_FILE" ]]; then
        cp "$BACKUP_FILE" "$CONFIG_FILE"
        systemctl restart awg-quick@awg0 || true

        echo
        echo -e "${YELLOW}Восстановлен предыдущий конфиг${RESET}"
    fi
}

# ============================================================
# Read config and setup routing
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
        echo -e "${RED}Конфиг пустой${RESET}"
        exit 1
    fi

    sed -i 's/\r//g' "$CONFIG_FILE"

    if ! grep -q "\[Interface\]" "$CONFIG_FILE"; then
        echo -e "${RED}Ошибка: отсутствует [Interface]${RESET}"
        exit 1
    fi

    if ! grep -q "\[Peer\]" "$CONFIG_FILE"; then
        echo -e "${RED}Ошибка: отсутствует [Peer]${RESET}"
        exit 1
    fi

    # Удаляем жестко заданные DNS
    sed -i '/^DNS/d' "$CONFIG_FILE"

    # Вычисляем подсеть
    TUNNEL_IP=$(grep -i '^Address' "$CONFIG_FILE" | head -n1 | cut -d '=' -f2 | tr -d ' ' | cut -d '/' -f 1)
    SUBNET=""
    if [[ -n "$TUNNEL_IP" ]]; then
        SUBNET="$(echo "$TUNNEL_IP" | cut -d '.' -f 1-3).0/24"
    else
        echo -e "${RED}Ошибка: Не удалось определить Address в конфиге${RESET}"
        exit 1
    fi

    # Интерактивное меню выбора маршрутизации
    echo -e "${CYAN}🌍 Выберите режим маршрутизации трафика:${RESET}"
    echo -e "  ${GREEN}[1] Только удаленный доступ${RESET} (Рекомендуется)"
    echo -e "      ${GRAY}В VPN пойдет только управление контроллером (например, ${SUBNET}).${RESET}"
    echo -e "      ${GRAY}Интернет на контроллере будет работать через родного провайдера.${RESET}"
    echo
    echo -e "  ${YELLOW}[2] Весь трафик через VPN${RESET} (Обход блокировок)"
    echo -e "      ${GRAY}ВЕСЬ интернет-трафик контроллера пойдет через туннель (0.0.0.0/0).${RESET}"
    echo -e "      ${GRAY}Полезно, если провайдер блокирует Telegram, обновления и т.д.${RESET}"
    echo

    while true; do
        read -p "$(echo -e ${CYAN}"Ваш выбор [1 или 2]: "${RESET})" routing_choice
        case $routing_choice in
            1)
                echo -e "${GREEN}✅ Выбран режим: Только удаленный доступ${RESET}"
                ROUTE_MODE="split"
                break
                ;;
            2)
                echo -e "${YELLOW}⚠️ Выбран режим: Весь трафик через VPN${RESET}"
                ROUTE_MODE="full"
                break
                ;;
            *)
                echo -e "${RED}Неверный ввод. Введите 1 или 2.${RESET}"
                ;;
        esac
    done
    echo

    # Вырезаем старые AllowedIPs, чтобы избежать дублей (работает и с GNU, и с BSD sed)
    sed -i -e '/^[Aa]llowed[Ii][Pp]s/d' "$CONFIG_FILE" 2>/dev/null || sed -i '/^AllowedIPs/d' "$CONFIG_FILE"

    # Прописываем новые маршруты
    if [[ "$ROUTE_MODE" == "split" ]]; then
        sed -i "/^\[Peer\]/a AllowedIPs = ${SUBNET}" "$CONFIG_FILE"
    else
        sed -i "/^\[Peer\]/a AllowedIPs = 0.0.0.0/0, ::/0" "$CONFIG_FILE"
    fi

    # Добавляем Keepalive для удержания туннеля, если его нет
    if ! grep -qi '^PersistentKeepalive' "$CONFIG_FILE"; then
        sed -i '/^\[Peer\]/a PersistentKeepalive = 25' "$CONFIG_FILE"
    fi

    chmod 600 "$CONFIG_FILE"
    echo -e "${GREEN}Конфиг успешно обработан и сохранен${RESET}"
}

# ============================================================
# Stop tunnel
# ============================================================

stop_tunnel() {
    systemctl stop awg-quick@awg0 2>/dev/null || true
    awg-quick down awg0 2>/dev/null || true
    ip link delete awg0 2>/dev/null || true
}

# ============================================================
# Start tunnel
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
        restore_dns
        cleanup_temp
        exit 1
    fi

    sleep 2

    if ! ip link show awg0 >/dev/null 2>&1; then
        echo -e "${RED}Интерфейс awg0 не поднялся${RESET}"
        
        restore_backup
        restore_dns
        cleanup_temp
        exit 1
    fi
}

# ============================================================
# Remove installation
# ============================================================

remove_awg() {
    echo -e "${YELLOW}Удаление AmneziaWG...${RESET}"

    stop_tunnel
    systemctl disable awg-quick@awg0 2>/dev/null || true
    rm -f /etc/systemd/system/multi-user.target.wants/awg-quick@awg0.service
    rm -rf "$CONFIG_DIR"
    
    echo -e "${GREEN}Удаление завершено${RESET}"
}

# ============================================================
# Status
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

main() {
    check_root
    show_header

    case "${1:-install}" in
        install)
            backup_dns
            check_internet

            install_dependencies
            install_go
            install_amneziawg_go
            install_awg_tools

            backup_config
            read_config
            stop_tunnel
            start_tunnel
            
            restore_dns
            cleanup_temp
            show_status
            ;;

        reinstall)
            backup_dns
            check_internet
            
            remove_awg

            install_dependencies
            install_go
            install_amneziawg_go
            install_awg_tools

            read_config
            start_tunnel
            
            restore_dns
            cleanup_temp
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
            echo "install   - установка"
            echo "reinstall - переустановка"
            echo "remove    - удаление"
            echo "status    - статус"
            echo

            exit 1
            ;;
    esac
}

main "$@"
