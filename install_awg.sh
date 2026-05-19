#!/bin/bash

# --- ОПРЕДЕЛЕНИЕ ЦВЕТОВ ---
GREEN='\e[1;32m'
CYAN='\e[1;36m'
YELLOW='\e[1;33m'
BLUE='\e[1;34m'
GRAY='\e[1;30m'
RESET='\e[0m'

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

echo -e "\n${GREEN}✅ Конфигурация успешно принята! Начинаем установку...${RESET}"

# Останавливаем текущий туннель, если он работал
if ip link show awg0 > /dev/null 2>&1; then
    echo -e "${YELLOW}⏳ Останавливаем старый туннель...${RESET}"
    awg-quick down awg0 2>/dev/null
fi

# Применяем новый конфиг
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
# ------------------------------------

chmod 600 /etc/amnezia/amneziawg/awg0.conf

# Проверяем, установлена ли AmneziaWG
if ! command -v awg-quick &> /dev/null; then
    echo -e "\n${YELLOW}⚙️  AmneziaWG не найдена. Начинаем автоматическую сборку ядра...${RESET}"
    echo -e "${GRAY}Это займет пару минут, подождите...${RESET}"
    
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    apt-get update >/dev/null 2>&1 && apt-get install -y git make curl resolvconf wget >/dev/null 2>&1

    LATEST_GO=$(curl -s https://go.dev/VERSION?m=text | head -n 1)
    wget -qO- "https://go.dev/dl/${LATEST_GO}.linux-armv6l.tar.gz" | tar -C /usr/local -xzf -
    export PATH=/usr/local/go/bin:$PATH

    cd /tmp
    rm -rf amneziawg-go amneziawg-tools
    git clone https://github.com/amnezia-vpn/amneziawg-go.git >/dev/null 2>&1
    cd amneziawg-go
    make >/dev/null 2>&1
    cp amneziawg-go /usr/bin/

    cd /tmp
    git clone https://github.com/amnezia-vpn/amneziawg-tools.git >/dev/null 2>&1
    cd amneziawg-tools/src
    make >/dev/null 2>&1
    make install >/dev/null 2>&1
    
    rm -rf /tmp/amneziawg-*
    echo -e "${GREEN}✅ Сборка успешно завершена!${RESET}"
else
    echo -e "\n${GREEN}✅ AmneziaWG уже установлена. Обновляем конфигурацию.${RESET}"
fi

# Запускаем туннель
echo -e "${CYAN}🔌 Запускаем туннель awg0...${RESET}"
systemctl daemon-reload >/dev/null 2>&1
systemctl enable awg-quick@awg0 >/dev/null 2>&1
systemctl restart awg-quick@awg0 >/dev/null 2>&1

# Получаем данные
SN=$(wb-gen-serial -s)

echo -e "\n${GREEN}============================================================${RESET}"
echo -e "${GREEN}🎉 УСПЕШНО!${RESET} Туннель поднят на контроллере: ${YELLOW}${SN}${RESET}"
echo -e "${GREEN}============================================================${RESET}\n"

echo -e "Теперь вы можете управлять Wiren Board по этой ссылке:"
echo -e "👉 ${BLUE}http://${TUNNEL_IP}${RESET}\n"

echo -e "${GRAY}Разработка и поддержка:${RESET}"
echo -e "🌐 ${CYAN}batyushin.ru${RESET}"
echo -e "🚀 ${CYAN}https://t.me/BlogReD${RESET}"
echo -e "${GREEN}============================================================${RESET}\n"
