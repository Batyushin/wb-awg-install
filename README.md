# 🛡️ AmneziaWG Installer for Wiren Board

Автоматическая установка и управление VPN-туннелем **AmneziaWG** на контроллерах Wiren Board.

Скрипт предназначен для построения собственной VPN-инфраструктуры для удаленного доступа к щитам умного дома через VPS-серверы.

---

# 🌟 Возможности

- 🚀 Установка одной командой
- 🔧 Автоматическая сборка AmneziaWG под архитектуру контроллера
- 🔄 Безопасная переустановка
- ♻️ Полное удаление конфигурации
- 🛡️ Автоматическое восстановление DNS
- 🔌 Автозапуск VPN после перезагрузки
- ⚡ Быстрое переключение между VPS
- 📦 Поддержка ARMv6 / ARM64 / x86_64
- 🧹 Очистка старой конфигурации перед переустановкой
- 🔒 Безопасный ввод конфига через `/dev/tty`
- 💾 Backup старой конфигурации

---

# 🏗️ Сценарий использования

Скрипт идеально подходит для:

- подключения Wiren Board к VPS через AmneziaWG
- удаленного доступа к объектам
- LTE-модемов
- резервных VPN-каналов
- миграции между VPS
- собственной альтернативы Tailscale

---

# 🚀 Быстрый запуск

Подключитесь к Wiren Board по SSH и выполните:

```bash
curl -fsSL https://raw.githubusercontent.com/Batyushin/wb-awg-install/main/install_awg.sh | bash
```

После запуска:

1. Установятся зависимости
2. Скачается и соберется AmneziaWG
3. Скрипт попросит вставить конфиг
4. Поднимется VPN-туннель
5. Включится автозапуск

---

# 📋 Вставка конфига

После запуска вставьте конфиг AmneziaWG:

```ini
[Interface]
PrivateKey = XXXXXXXXXXXXXXXXXXXXX
Address = 10.81.0.10/24

[Peer]
PublicKey = XXXXXXXXXXXXXXXXXXXXX
Endpoint = vpn.example.com:51820
AllowedIPs = 10.81.0.0/24
PersistentKeepalive = 25
```

Для завершения ввода нажмите:

```text
CTRL+D
```

---

# 🔄 Перенос Wiren Board на другой VPS

Для полной переустановки и подключения к другому серверу:

```bash
curl -fsSL https://raw.githubusercontent.com/Batyushin/wb-awg-install/main/install_awg.sh | bash -s reinstall
```

Скрипт автоматически:

- остановит старый туннель
- удалит старую конфигурацию
- очистит интерфейс awg0
- запросит новый конфиг
- подключит контроллер к новому VPS

---

# ❌ Полное удаление

```bash
curl -fsSL https://raw.githubusercontent.com/Batyushin/wb-awg-install/main/install_awg.sh | bash -s remove
```

Удаляется:

- интерфейс `awg0`
- конфигурация VPN
- systemd-автозапуск
- маршруты AmneziaWG

---

# 📊 Проверка состояния

```bash
curl -fsSL https://raw.githubusercontent.com/Batyushin/wb-awg-install/main/install_awg.sh | bash -s status
```


```bash
ping -I awg0 -c 4 10.8.0.1
```

---

# 🏗️ Рекомендуемая схема сети

```text
                    ┌─────────────────────┐
                    │        ПК           │
                    │  Amnezia Client     │
                    └─────────┬───────────┘
                              │
                              │ VPN Tunnel
                              ▼
                  ┌─────────────────────────┐
                  │     VPS AmneziaWG       │
                  │      10.8.0.1           │
                  └─────────┬───────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
        ▼                   ▼                   ▼

┌────────────────┐ ┌────────────────┐ ┌────────────────┐
│  Wiren Board   │ │  Wiren Board   │ │  Wiren Board   │
│      #1        │ │      #2        │ │      #3        │
│   10.8.0.10    │ │   10.8.0.11    │ │   10.8.0.12    │
└────────────────┘ └────────────────┘ └────────────────┘
```

---

# 🧩 Поддерживаемые платформы

- Wiren Board 6
- Wiren Board 7
- Debian 11
- ARMv6
- ARM64
- x86_64

---

# 🔐 Особенности безопасности

Скрипт:

- не использует DNS из VPN-конфига
- автоматически восстанавливает `/etc/resolv.conf`
- делает backup старого конфига
- проверяет валидность конфигурации
- безопасно читает конфиг через `/dev/tty`
- переживает повторный запуск

---

# 🛠️ Репозиторий

GitHub:

```text
https://github.com/Batyushin/wb-awg-install
```

---

# ❤️ Автор

Разработка и поддержка:

- https://batyushin.ru
- https://t.me/BlogReD
