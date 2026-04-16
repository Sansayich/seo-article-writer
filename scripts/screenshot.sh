#!/usr/bin/env bash
# screenshot.sh — Делает скриншот URL через Playwright и загружает на сервер по SSH
# Использование: ./screenshot.sh <URL> <slug> [width] [height]
# Пример: ./screenshot.sh "https://canva.com" "canva-homepage" 1280 800

set -euo pipefail

# ── Загрузка конфига ──────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config.env"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "❌ Не найден config.env. Скопируй config.env.example → config.env и заполни." >&2
  exit 1
fi
source "$CONFIG_FILE"

# ── Параметры ─────────────────────────────────────────────────────────────────
URL="${1:?Укажи URL первым аргументом}"
SLUG="${2:?Укажи slug вторым аргументом (напр. canva-homepage)}"
WIDTH="${3:-1280}"
HEIGHT="${4:-800}"

FILENAME="${SLUG}-$(date +%s).png"
TMPFILE="/tmp/${FILENAME}"

# ── Зависимости ───────────────────────────────────────────────────────────────
if ! command -v node &>/dev/null; then
  echo "❌ Node.js не установлен" >&2; exit 1
fi

# Устанавливаем playwright если нужно
if ! node -e "require('playwright')" 2>/dev/null; then
  echo "📦 Устанавливаю playwright..."
  npm install -g playwright 2>/dev/null || npm install playwright --prefix /tmp/pw
  npx playwright install chromium --with-deps 2>/dev/null || true
fi

# ── Скриншот через Node.js inline ─────────────────────────────────────────────
echo "📸 Делаю скриншот: $URL → $FILENAME"

node - <<EOF
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ args: ['--no-sandbox'] });
  const page = await browser.newPage();
  await page.setViewportSize({ width: ${WIDTH}, height: ${HEIGHT} });
  await page.goto('${URL}', { waitUntil: 'networkidle', timeout: 30000 });
  // Небольшая пауза для рендера динамических элементов
  await page.waitForTimeout(2000);
  await page.screenshot({ path: '${TMPFILE}', fullPage: false });
  await browser.close();
  console.log('✅ Скриншот сохранён: ${TMPFILE}');
})().catch(e => { console.error('❌', e.message); process.exit(1); });
EOF

# ── Загрузка на сервер по SSH ─────────────────────────────────────────────────
echo "🚀 Загружаю на сервер: ${SSH_USER}@${SSH_HOST}:${SERVER_IMG_PATH}/${FILENAME}"

# Создаём папку если нет
ssh -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no \
  "${SSH_USER}@${SSH_HOST}" \
  "mkdir -p ${SERVER_IMG_PATH}"

# Загружаем файл
scp -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no \
  "${TMPFILE}" \
  "${SSH_USER}@${SSH_HOST}:${SERVER_IMG_PATH}/${FILENAME}"

# ── Вывод публичного URL ───────────────────────────────────────────────────────
PUBLIC_URL="${IMG_BASE_URL}/${FILENAME}"
echo ""
echo "✅ Готово!"
echo "📎 URL картинки: ${PUBLIC_URL}"
echo "📝 Markdown: ![${SLUG}](${PUBLIC_URL})"
echo ""
echo "IMG_URL=${PUBLIC_URL}"

# Чистим tmp
rm -f "${TMPFILE}"
