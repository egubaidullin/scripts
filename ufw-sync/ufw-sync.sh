#!/usr/bin/env bash
# /opt/ufw-sync/ufw-sync.sh
# Версия: 2.0
# Совместимость: Ubuntu 24.04, legacy iptables
#
# Конфигурация читается из /etc/ufw-sync/ufw-sync.conf
# Запуск: sudo /opt/ufw-sync/ufw-sync.sh [--dry-run] [--help]
#
# Структура файлов:
#   /etc/ufw-sync/ufw-sync.conf  — конфигурация (порты, флаги)
#   /opt/configs/allowed_ips.txt — белый список IP (по одному на строку, # — комментарий)
#   /opt/ufw-sync/backups/       — резервные копии after.rules

set -euo pipefail

# ─────────────────────────────────────────────
# Константы (не меняются)
# ─────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-/etc/ufw-sync/ufw-sync.conf}"
CLOUDFLARE_IPV4_URL="https://www.cloudflare.com/ips-v4"
CLOUDFLARE_IPV6_URL="https://www.cloudflare.com/ips-v6"

# ─────────────────────────────────────────────
# Разбор аргументов командной строки
# ─────────────────────────────────────────────
ARG_DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) ARG_DRY_RUN=1 ;;
    --help|-h)
      echo "Использование: $0 [--dry-run] [--help]"
      echo "  --dry-run  Показать команды без выполнения"
      echo "  --help     Эта справка"
      echo ""
      echo "Конфиг: $CONFIG_FILE"
      exit 0
      ;;
    *) echo "Неизвестный аргумент: $arg" >&2; exit 1 ;;
  esac
done

# ─────────────────────────────────────────────
# Дефолтные значения (перекрываются конфигом)
# ─────────────────────────────────────────────
SSH_PORT=""
PUBLIC_PORTS_TCP="80 443"
PUBLIC_PORTS_UDP=""
WHITELIST_PORTS_TCP="81"
WHITELIST_PORTS_UDP=""
IP_FILE="/opt/configs/allowed_ips.txt"
LOG_FILE="/var/log/ufw_sync.log"
BACKUP_DIR="/opt/ufw-sync/backups"
ENABLE_CLOUDFLARE=1
ENABLE_DOCKER_NETWORKS=1
DOCKER_MASQUERADE_RANGE="172.16.0.0/12"
ENABLE_FAIL2BAN=1
DRY_RUN=0

# ─────────────────────────────────────────────
# Загрузка конфига
# ─────────────────────────────────────────────
if [ -f "$CONFIG_FILE" ]; then
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
else
  echo "ПРЕДУПРЕЖДЕНИЕ: Конфиг не найден: $CONFIG_FILE — используются дефолты" >&2
fi

# Аргумент --dry-run перекрывает конфиг
[ "$ARG_DRY_RUN" -eq 1 ] && DRY_RUN=1

# ─────────────────────────────────────────────
# Проверка прав
# ─────────────────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
  echo "ОШИБКА: Скрипт требует прав root. Запустите через sudo." >&2
  exit 1
fi

# ─────────────────────────────────────────────
# Инициализация логирования и директорий
# ─────────────────────────────────────────────
mkdir -p "$(dirname "$IP_FILE")" "$BACKUP_DIR" "$(dirname "$LOG_FILE")"
touch "$IP_FILE" "$LOG_FILE"
chmod 600 "$IP_FILE" "$LOG_FILE"

log()  { echo "[$(date --iso-8601=seconds)] $*" | tee -a "$LOG_FILE"; }
err()  { echo "[$(date --iso-8601=seconds)] ERROR: $*" | tee -a "$LOG_FILE" >&2; }
info() { echo "[$(date --iso-8601=seconds)] INFO:  $*" | tee -a "$LOG_FILE"; }
warn() { echo "[$(date --iso-8601=seconds)] WARN:  $*" | tee -a "$LOG_FILE" >&2; }

# Выполнить команду или показать (dry-run)
plan() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  [DRY-RUN] $*"
  else
    eval "$@"
  fi
}

log "═══════════════════════════════════════════════════"
log "ufw-sync v2.0 запущен$([ "$DRY_RUN" -eq 1 ] && echo ' [DRY-RUN]' || true)"
log "Конфиг: $CONFIG_FILE"
[ "$DRY_RUN" -eq 1 ] && log "РЕЖИМ DRY-RUN: команды показаны, но не выполнены"

# ─────────────────────────────────────────────
# Авто-определение SSH порта
# ─────────────────────────────────────────────
if [ -z "$SSH_PORT" ]; then
  SSH_PORT=$(grep -E "^Port\s+" /etc/ssh/sshd_config 2>/dev/null \
             | awk '{print $2}' | head -n1 || true)
  SSH_PORT="${SSH_PORT:-22}"
  info "Авто-определён SSH порт: $SSH_PORT"
else
  info "SSH порт из конфига: $SSH_PORT"
fi

# ─────────────────────────────────────────────
# 1. Определение текущего IP (защита от самоблокировки)
# ─────────────────────────────────────────────
CURRENT_IP=""

# Метод 1: SSH_CLIENT (наиболее надёжный при прямом SSH)
if [ -n "${SSH_CLIENT-}" ]; then
  CURRENT_IP=$(echo "$SSH_CLIENT" | awk '{print $1}')
  info "Текущий IP из SSH_CLIENT: $CURRENT_IP"
fi

# Метод 2: Поиск через who для sudo-сессии
if [ -z "$CURRENT_IP" ] && [ -n "${SUDO_USER-}" ]; then
  CURRENT_IP=$(who | grep "^${SUDO_USER}\s" | awk '{print $NF}' \
               | tr -d '()' | grep -E '^[0-9a-f.:]+$' | head -n1 || true)
  [ -n "$CURRENT_IP" ] && info "Текущий IP из who: $CURRENT_IP"
fi

# Метод 3: Активные TCP-соединения на SSH-порт
if [ -z "$CURRENT_IP" ]; then
  CURRENT_IP=$(ss -tnp "sport = :${SSH_PORT}" 2>/dev/null \
               | awk 'NR>1 {print $5}' | sed 's/:[0-9]*$//' \
               | grep -v '^127\.' | head -n1 || true)
  [ -n "$CURRENT_IP" ] && info "Текущий IP из ss: $CURRENT_IP"
fi

if [ -z "$CURRENT_IP" ]; then
  warn "Не удалось определить текущий IP! Убедитесь, что SSH_PORT=${SSH_PORT} верный."
  warn "Для безопасности добавьте свой IP вручную в $IP_FILE до запуска."
else
  # Автодобавление в белый список
  if ! grep -Fxq "$CURRENT_IP" "$IP_FILE"; then
    echo "$CURRENT_IP" >> "$IP_FILE"
    info "Авто-добавлен текущий IP $CURRENT_IP → $IP_FILE"
  fi
fi

# ─────────────────────────────────────────────
# 2. Бэкап after.rules
# ─────────────────────────────────────────────
if [ -f "/etc/ufw/after.rules" ] && [ "$DRY_RUN" -eq 0 ]; then
  BACKUP_FILE="$BACKUP_DIR/after.rules.$(date +%Y%m%d_%H%M%S)"
  cp /etc/ufw/after.rules "$BACKUP_FILE"
  info "Бэкап after.rules → $BACKUP_FILE"
  # Хранить последние 10 бэкапов
  ls -t "$BACKUP_DIR"/after.rules.* 2>/dev/null | tail -n +11 | xargs rm -f || true
fi

# ─────────────────────────────────────────────
# 3. Запись after.rules (NAT для Docker + DOCKER-USER)
# ─────────────────────────────────────────────
info "Конфигурирование /etc/ufw/after.rules..."
if [ "$DRY_RUN" -eq 0 ]; then
  cat > /etc/ufw/after.rules <<EOF
# /etc/ufw/after.rules — управляется ufw-sync, не редактировать вручную
# Обновлено: $(date --iso-8601=seconds)

# ── NAT: MASQUERADE для Docker-контейнеров (доступ в интернет) ──────────────
*nat
:POSTROUTING ACCEPT [0:0]
-A POSTROUTING -s ${DOCKER_MASQUERADE_RANGE} ! -o docker+ -j MASQUERADE
COMMIT

# ── FILTER: DOCKER-USER (UFW интеграция) ────────────────────────────────────
*filter
:ufw-user-forward - [0:0]
:DOCKER-USER - [0:0]

# Передать управление в ufw-user-forward
-A DOCKER-USER -j ufw-user-forward

# Разрешить ответы на установленные соединения (CRUCIAL для outbound трафика)
-A DOCKER-USER -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN

# Разрешить DNS из контейнеров
-A DOCKER-USER -p udp --dport 53 -j RETURN
-A DOCKER-USER -p tcp --dport 53 -j RETURN

# Разрешить HTTP/HTTPS из контейнеров
-A DOCKER-USER -p tcp --dport 80 -j RETURN
-A DOCKER-USER -p tcp --dport 443 -j RETURN

# Разрешить трафик из приватных сетей (RFC 1918)
-A DOCKER-USER -j RETURN -s 10.0.0.0/8
-A DOCKER-USER -j RETURN -s 172.16.0.0/12
-A DOCKER-USER -j RETURN -s 192.168.0.0/16

COMMIT
EOF
  info "after.rules записан"
else
  echo "  [DRY-RUN] Записать /etc/ufw/after.rules (NAT + DOCKER-USER)"
fi

# ─────────────────────────────────────────────
# 4. Сброс UFW и базовая политика
# ─────────────────────────────────────────────
log "Сброс UFW..."
plan "ufw --force reset"
plan "ufw default deny incoming"
plan "ufw default allow outgoing"
plan "ufw allow in on lo comment 'loopback'"

# ─────────────────────────────────────────────
# 5. Антиблокировка: SSH и текущий IP
# ─────────────────────────────────────────────
if [ -n "$CURRENT_IP" ]; then
  plan "ufw allow from ${CURRENT_IP} to any comment 'ANTI-LOCKOUT current session'"
fi
plan "ufw allow ${SSH_PORT}/tcp comment 'SSH'"

# ─────────────────────────────────────────────
# 6. Публичные порты (открыты всем)
# ─────────────────────────────────────────────
info "Открываем публичные порты..."
for port in $PUBLIC_PORTS_TCP; do
  plan "ufw allow ${port}/tcp comment 'public TCP'"
  plan "ufw route allow ${port}/tcp comment 'public TCP docker route'"
done
for port in $PUBLIC_PORTS_UDP; do
  plan "ufw allow ${port}/udp comment 'public UDP'"
  plan "ufw route allow ${port}/udp comment 'public UDP docker route'"
done

# ─────────────────────────────────────────────
# 7. Whitelist-only порты (только для IP из IP_FILE)
# ─────────────────────────────────────────────
info "Применяем whitelist (файл: $IP_FILE)..."

if [ ! -s "$IP_FILE" ]; then
  warn "Файл белого списка пуст: $IP_FILE — whitelist-порты недоступны!"
fi

while IFS= read -r line || [ -n "$line" ]; do
  # Пропустить пустые строки и комментарии
  case "$line" in ''|\#*) continue ;; esac
  ip=$(echo "$line" | xargs)  # trim

  # Базовая валидация (IPv4/IPv6/CIDR)
  if ! echo "$ip" | grep -qE '^[0-9a-fA-F.:\/]+$'; then
    warn "Пропущен некорректный IP: '$ip'"
    continue
  fi

  info "  → Whitelist: $ip"

  # Whitelist TCP порты
  for port in $WHITELIST_PORTS_TCP; do
    plan "ufw allow from ${ip} to any port ${port} proto tcp comment 'whitelist TCP'"
    plan "ufw route allow from ${ip} to any port ${port} proto tcp comment 'whitelist TCP docker'"
  done

  # Whitelist UDP порты
  for port in $WHITELIST_PORTS_UDP; do
    plan "ufw allow from ${ip} to any port ${port} proto udp comment 'whitelist UDP'"
    plan "ufw route allow from ${ip} to any port ${port} proto udp comment 'whitelist UDP docker'"
  done

done < "$IP_FILE"

# ─────────────────────────────────────────────
# 8. Cloudflare IP
# ─────────────────────────────────────────────
if [ "${ENABLE_CLOUDFLARE}" -eq 1 ]; then
  if command -v curl &>/dev/null; then
    info "Обновление Cloudflare IP..."

    CF_IPV4=$(curl -fsS --max-time 10 "$CLOUDFLARE_IPV4_URL" 2>/dev/null || true)
    CF_IPV6=$(curl -fsS --max-time 10 "$CLOUDFLARE_IPV6_URL" 2>/dev/null || true)

    if [ -z "$CF_IPV4" ] && [ -z "$CF_IPV6" ]; then
      warn "Не удалось получить Cloudflare IP (нет сети или URL недоступен)"
    fi

    for ip in $CF_IPV4 $CF_IPV6; do
      [ -z "$ip" ] && continue
      for port in $PUBLIC_PORTS_TCP; do
        plan "ufw allow from ${ip} to any port ${port} proto tcp comment 'cloudflare'"
        plan "ufw route allow from ${ip} to any port ${port} proto tcp comment 'cloudflare docker'"
      done
    done
    info "Cloudflare IP применены"
  else
    warn "curl не найден — пропускаем Cloudflare IP"
  fi
else
  info "Cloudflare IP: отключено (ENABLE_CLOUDFLARE=0)"
fi

# ─────────────────────────────────────────────
# 9. Docker-подсети
# ─────────────────────────────────────────────
if [ "${ENABLE_DOCKER_NETWORKS}" -eq 1 ] && command -v docker &>/dev/null; then
  info "Добавление Docker-подсетей..."
  while IFS= read -r net; do
    subnets=$(docker network inspect "$net" \
              --format '{{range .IPAM.Config}}{{.Subnet}} {{end}}' 2>/dev/null || true)
    for subnet in $subnets; do
      [ -z "$subnet" ] && continue
      plan "ufw allow from ${subnet} comment 'docker network: ${net}'" >/dev/null
      info "  → Docker сеть ${net}: $subnet"
    done
  done < <(docker network ls --format '{{.Name}}')
fi

# ─────────────────────────────────────────────
# 10. Включение UFW
# ─────────────────────────────────────────────
log "Включение UFW..."
plan "ufw --force enable"
plan "ufw reload"

# ─────────────────────────────────────────────
# 11. Fail2Ban
# ─────────────────────────────────────────────
if [ "${ENABLE_FAIL2BAN}" -eq 1 ] && command -v fail2ban-client &>/dev/null; then
  info "Настройка Fail2Ban ignoreip..."

  IGNORE_IPS="127.0.0.1/8 ::1"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|\#*) continue ;; esac
    ip=$(echo "$line" | xargs)
    IGNORE_IPS="${IGNORE_IPS} ${ip}"
  done < "$IP_FILE"

  F2B_CONF="/etc/fail2ban/jail.d/ufw-sync-ignoreip.conf"
  NEW_CONTENT="[DEFAULT]
ignoreip = ${IGNORE_IPS}"

  if [ "$DRY_RUN" -eq 0 ]; then
    mkdir -p "$(dirname "$F2B_CONF")"
    # Обновить только если изменилось
    OLD_CONTENT=$(cat "$F2B_CONF" 2>/dev/null || true)
    if [ "$OLD_CONTENT" != "$NEW_CONTENT" ]; then
      echo "$NEW_CONTENT" > "$F2B_CONF"
      if fail2ban-client -t >/dev/null 2>&1; then
        systemctl restart fail2ban
        info "Fail2Ban перезапущен с новым ignoreip"
      else
        err "Fail2Ban: ошибка конфигурации, перезапуск отменён"
      fi
    else
      info "Fail2Ban ignoreip не изменился — пропускаем"
    fi
  else
    echo "  [DRY-RUN] Записать $F2B_CONF:"
    echo "$NEW_CONTENT" | sed 's/^/    /'
  fi
fi

# ─────────────────────────────────────────────
# Итог
# ─────────────────────────────────────────────
log "═══════════════════════════════════════════════════"
log "ufw-sync завершён$([ "$DRY_RUN" -eq 1 ] && echo ' [DRY-RUN — изменений не применено]' || true)"
if [ "$DRY_RUN" -eq 0 ]; then
  log "Статус UFW:"
  ufw status numbered 2>/dev/null | tee -a "$LOG_FILE" || true
fi
exit 0
