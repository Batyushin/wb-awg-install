# 🛡️ AmneziaWG Install for Wiren Board

Скрипт для быстрой и полностью автоматической установки туннеля **AmneziaWG** на контроллерах умного дома Wiren Board.

**AmneziaWG** — это форк WireGuard с обфускацией (защитой от DPI). Трафик маскируется под обычный UDP-шум, что позволяет стабильно работать через LTE-модемы, мобильных операторов и провайдеров с агрессивной блокировкой VPN.

---

# 🌟 Возможности

- 🚀 Установка в одну команду
- 🔧 Полностью автоматическая сборка AmneziaWG под архитектуру контроллера
- 🔄 Идемпотентная установка (повторный запуск не ломает систему)
- ♻️ Полное удаление и переустановка
- 🔌 Автозапуск VPN после перезагрузки
- 🛡️ Автоматическая настройка PersistentKeepalive
- 📦 Поддержка ARMv6 / ARM64 / x86_64
- 🧹 Автоматическая очистка старой конфигурации
- ⚡ Быстрое переключение между VPS

---

# 🚀 Быстрый запуск

Подключитесь к контроллеру Wiren Board по SSH и выполните:

```bash
curl -fsSL https://raw.githubusercontent.com/Batyushin/wb-awg-install/main/install_awg.sh | bash
```

После запуска скрипт:

1. Установит зависимости
2. Скачает и соберет AmneziaWG
3. Попросит вставить конфиг
4. Поднимет VPN-туннель
5. Добавит автозапуск

---

# 📋 Вставка конфига

После запуска вставьте ваш конфиг AmneziaWG:

```ini
[Interface]
PrivateKey = XXXXX
Address = 10.81.0.10/24

[Peer]
PublicKey = XXXXX
Endpoint = vpn.example.com:51820
AllowedIPs = 10.81.0.0/24
PersistentKeepalive = 25
```

После вставки нажмите:

```text
CTRL+D
```

---

# 🔄 Перенос на другой VPS

Для полной очистки старой конфигурации и подключения к новому серверу:

```bash
curl -fsSL https://raw.githubusercontent.com/Batyushin/wb-awg-install/main/install_awg.sh | bash -s reinstall
```

Скрипт автоматически:

- остановит старый туннель
- удалит старую конфигурацию
- очистит интерфейс awg0
- запросит новый конфиг
- подключит контроллер к другому VPS

---

# ❌ Полное удаление AmneziaWG

```bash
curl -fsSL https://raw.githubusercontent.com/Batyushin/wb-awg-install/main/install_awg.sh | bash -s remove
```

Удаляется:

- интерфейс `awg0`
- systemd-сервис
- конфиги AmneziaWG
- бинарники AmneziaWG

---

# 📊 Проверка состояния

```bash
curl -fsSL https://raw.githubusercontent.com/Batyushin/wb-awg-install/main/install_awg.sh | bash -s status
```

---

# 🏗️ Пример схемы

```text
Wiren Board #1 ─┐
Wiren Board #2 ─┼──► VPS AmneziaWG
Wiren Board #3 ─┘
```

---

# ⚠️ Рекомендации по подсетям

Для нескольких VPS рекомендуется использовать разные подсети:

```text
VPS-1 → 10.81.0.0/24
VPS-2 → 10.82.0.0/24
VPS-3 → 10.83.0.0/24
```

Это позволит избежать проблем маршрутизации при масштабировании.

---

# 🧩 Поддерживаемые платформы

- Wiren Board 6
- Wiren Board 7
- Debian 11
- ARMv6
- ARM64
- x86_64

---

# 🛠️ Репозиторий

GitHub:

```text
https://github.com/Batyushin/wb-awg-install
```

---

# 📄 Лицензия

MIT License

---

# ❤️ Автор

Разработка и поддержка:

- https://batyushin.ru
- https://t.me/BlogReD
