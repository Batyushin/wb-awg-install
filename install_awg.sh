#!/bin/bash

# --- ОПРЕДЕЛЕНИЕ ЦВЕТОВ ---
GREEN='\e[1;32m'
CYAN='\e[1;36m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
GRAY='\e[1;30m'
RESET='\e[0m'

# Функция для анимации ожидания
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

echo -e "\n${CYAN}============================================================${RESET}"
echo -e "${GREEN}🛡️  Установка и настройка туннеля AmneziaWG для Wiren Board${RESET}"
echo -e "${CYAN}============================================================${RESET}"
echo -e "\n${YELLOW}📋 Вставьте содержимое вашего конфига AmneziaWG ниже.${RESET}"
echo -e "${GRAY}(После вставки текста нажмите Enter два раза подряд)${RESET}\n"

# Читаем ввод пользователя
mkdir -p /etc/amnezia/amneziawg
rm -f /etc/amnezia/amneziawg/awg0.tmp
empty_count=0

while IFS= read -r line; do
    line="${line//$'\r'/}"
    if [[ -z "$line" ]]; then
        empty_count=$((empty_count + 1))
        if [[ $empty_count -ge 2 ]]; then
            break
        fi
    else
        empty_count=0
    fi
    echo "$line" >> /etc/amnezia/amneziawg/awg0.tmp
done

echo -e "\n${GREEN}✅ Конфигурация принята! Начинаем установку...${RESET}"

# --- ХИРУРГИЧЕСКАЯ ЗАЧИСТКА ---
if ip link show awg0 > /dev/null 2>&1; then
    echo -e "${YELLOW}⏳ Очистка старой конфигурации...${RESET}"
    awg-quick down awg0 2>/dev/null
    ip addr flush dev awg0 2>/dev/null
    ip link delete awg0 2>/dev/null
fi

mv /etc/amnezia/amneziawg/awg0.tmp /etc/amnezia/amneziawg/awg0.conf

# --- АВТОМАТИЧЕСКАЯ ЗАЩИТА КОНФИГА ---
TUNNEL_IP=$(grep -i '^Address' /etc/amnezia/amneziawg/awg0.conf | cut -d '=' -f 2 | tr -d ' ' | cut -d '/' -f 1)
SUBNET="$(echo $TUNNEL_IP | cut -d '.' -f 1-3).0/24"
sed -i "s|^AllowedIPs.*|AllowedIPs = ${SUBNET}|i" /etc/amnezia/amneziawg/awg0.conf

if grep -qi '^PersistentKeepalive' /etc/amnezia/amneziawg/awg0.conf; then
    sed -i "s|^PersistentKeepalive.*|PersistentKeepalive = 25|i" /etc/amnezia/amneziawg/awg0.conf
else
    echo "PersistentKeepalive = 25" >> /etc/amnezia/amneziawg/awg0.conf
fi
chmod 600 /etc/amnezia/amneziawg/awg0.conf

# --- СБОРКА И УСТАНОВКА ---
if ! command -v awg-quick &> /dev/null || ! command -v amneziawg-go &> /dev/null; then
    echo -e "\n${YELLOW}⚙️  Начинаем сборку (это займет пару минут)...${RESET}"
    
    echo -ne "${CYAN}📦 Установка зависимостей... ${RESET}"
    { apt-get update && apt-get install -y git make curl resolvconf wget gcc g++ libmnl-dev libelf-dev; } >/dev/null 2>&1 &
    spinner $!
    echo -e "${GREEN}Готово!${RESET}"

    if [ ! -d "/usr/local/go" ]; then
        echo -ne "${CYAN}📦 Загрузка и установка Go... ${RESET}"
        { wget -q https://go.dev/dl/go1.22.3.linux-armv6l.tar.gz -O /tmp/go.tar.gz && tar -C /usr/local -xzf /tmp/go.tar.gz; } &
        spinner $!
        echo -e "${GREEN}Готово!${RESET}"
    fi
    export PATH=$PATH:/usr/local/go/bin

    echo -ne "${CYAN}🛠️  Сборка ядра amneziawg-go... ${RESET}"
    { cd /tmp && rm -rf amneziawg-go && git clone https://github.com/amnezia-vpn/amneziawg-go.git >/dev/null 2>&1 && cd amneziawg-go && make >/dev/null 2>&1 && cp amneziawg-go /usr/bin/; } &
    spinner $!
    echo -e "${GREEN}Готово!${RESET}"

    echo -ne "${CYAN}🛠️  Сборка инструментов awg-tools... ${RESET}"
    { cd /tmp && rm -rf amneziawg-tools && git clone https://github.com/amnezia-vpn/amneziawg-tools.git >/dev/null 2>&1 && cd amneziawg-tools/src && make >/dev/null 2>&1 && make install >/dev/null 2>&1; } &
    spinner $!
    echo -e "${GREEN}Готово!${RESET}"
    
    rm -rf /tmp/amneziawg-* /tmp/go.tar.gz
else
    echo -e "\n${GREEN}✅ AmneziaWG уже установлена.${RESET}"
fi

# Запуск
echo -e "${CYAN}🔌 Запускаем туннель awg0...${RESET}"
systemctl daemon-reload >/dev/null 2>&1
systemctl enable awg-quick@awg0 >/dev/null 2>&1
systemctl restart awg-quick@awg0 >/dev/null 2>&1

SN=$(wb-gen-serial -s)
echo -e "\n${GREEN}============================================================${RESET}"
echo -e "${GREEN}🎉 УСПЕШНО!${RESET} Туннель поднят на контроллере: ${YELLOW}${SN}${RESET}"
echo -e "${GREEN}============================================================${RESET}\n"
echo -e "IP адрес контроллера: ${BLUE}${TUNNEL_IP}${RESET}\n"
echo -e "${GRAY}Разработка и поддержка: batyushin.ru | t.me/BlogReD${RESET}"
echo -e "${GREEN}============================================================${RESET}\n"
