#!/usr/bin/env bash
# generate-image.sh — Генерирует картинку через Nano Banana 2 (nano-banana-2)
# с поддержкой русского текста на изображении. Двухшаговый метод для точного рендера текста.
#
# Использование:
#   ./generate-image.sh cover  "<визуальный промпт>" "<заголовок статьи>" <slug>
#   ./generate-image.sh image  "<визуальный промпт>" "<текст на картинке>" <slug> [ratio] [size]
#   ./generate-image.sh notext "<визуальный промпт>" <slug> [ratio] [size]
#
# Примеры:
#   ./generate-image.sh cover \
#       "Современный интерьер гостиной, AI визуализация, фотореалистично" \
#       "Как ИИ меняет дизайн интерьера в 2026 году" \
#       "ai-interior-2026"
#
#   ./generate-image.sh image \
#       "Схема работы нейросети, минималистичная инфографика, синие тона" \
#       "Как работает нейросеть" \
#       "how-nn-works" "16:9"
#
#   ./generate-image.sh notext \
#       "Минималистичный рабочий стол с ноутбуком, мягкий свет" \
#       "desk-photo" "1:1"

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
MODE="${1:?Укажи режим: cover | image | notext}"
VISUAL_PROMPT="${2:?Укажи визуальный промпт вторым аргументом}"

case "$MODE" in
  cover)
    TITLE_TEXT="${3:?Для cover укажи заголовок третьим аргументом}"
    SLUG="${4:?Укажи slug четвёртым аргументом}"
    ASPECT_RATIO="16:9"
    IMAGE_SIZE="${5:-1K}"
    ;;
  image)
    OVERLAY_TEXT="${3:?Для image укажи текст на картинке третьим аргументом}"
    SLUG="${4:?Укажи slug четвёртым аргументом}"
    ASPECT_RATIO="${5:-16:9}"
    IMAGE_SIZE="${6:-2K}"
    ;;
  notext)
    SLUG="${3:?Укажи slug третьим аргументом}"
    ASPECT_RATIO="${4:-16:9}"
    IMAGE_SIZE="${5:-1K}"
    ;;
  *)
    echo "❌ Неверный режим: $MODE. Используй: cover | image | notext" >&2
    exit 1
    ;;
esac

FILENAME="${SLUG}-$(date +%s).png"
TMPFILE="/tmp/${FILENAME}"

# ── Зависимости ───────────────────────────────────────────────────────────────
for cmd in curl jq python3; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "❌ Не установлен: $cmd" >&2; exit 1
  fi
done

# Приоритет моделей: nano-banana-2 > gemini-3-pro-image-preview > gemini-2.5-flash-image
MODELS=("nano-banana-2" "gemini-3-pro-image-preview" "gemini-2.5-flash-image")
API_BASE="${APIYI_BASE_URL:-https://api.apiyi.com}/v1beta/models"

# ── Функция: скачать изображение и вернуть base64 ────────────────────────────
url_to_base64() {
  local url="$1"
  local tmpimg
  tmpimg=$(mktemp /tmp/ref-XXXXXX).jpg
  if curl -s -L --max-time 15 -o "$tmpimg" "$url" && [[ -s "$tmpimg" ]]; then
    python3 -c "import base64; print(base64.b64encode(open('$tmpimg','rb').read()).decode())"
  fi
  rm -f "$tmpimg"
}

# ── Функция: вызов Nano Banana 2 API ─────────────────────────────────────────
# Перебирает модели по приоритету: nano-banana-2 > gemini-3-pro-image-preview > gemini-2.5-flash-image
# Для каждой модели делает до 3 попыток перед переходом к следующей.
# COVER_REF_URLS — опциональная env-переменная, пробел-разделённый список URL референсов
call_nb2() {
  local prompt="$1"
  local ratio="$2"
  local size="$3"

  # Собираем parts: сначала референсы (если есть), затем текстовый промпт
  local parts_json="[]"

  if [[ -n "${COVER_REF_URLS:-}" ]]; then
    echo "🖼️  Загружаю референсы..." >&2
    for url in $COVER_REF_URLS; do
      local b64
      b64=$(url_to_base64 "$url")
      if [[ -n "$b64" ]]; then
        parts_json=$(echo "$parts_json" | jq \
          --arg data "$b64" \
          '. + [{inlineData: {mimeType: "image/jpeg", data: $data}}]')
        echo "  ✅ $url" >&2
      else
        echo "  ⚠️  Не удалось загрузить: $url" >&2
      fi
    done
  fi

  # Добавляем текстовый промпт последним
  parts_json=$(echo "$parts_json" | jq --arg p "$prompt" '. + [{text: $p}]')

  local payload
  payload=$(jq -n \
    --argjson parts "$parts_json" \
    --arg r "$ratio" \
    --arg s "$size" \
    '{
      contents: [{parts: $parts}],
      generationConfig: {
        responseModalities: ["IMAGE"],
        imageConfig: {aspectRatio: $r, imageSize: $s}
      }
    }')

  # Перебираем модели по приоритету с retry
  for model in "${MODELS[@]}"; do
    local api_url="${API_BASE}/${model}:generateContent"
    echo "🔄 Пробую модель: ${model}..." >&2
    local attempt
    for attempt in 1 2 3; do
      local resp
      resp=$(curl -s -X POST "$api_url" \
        -H "Authorization: Bearer ${APIYI_API_KEY}" \
        -H "Content-Type: application/json" \
        --max-time 120 \
        -d "$payload")

      # Проверяем успех
      if echo "$resp" | jq -e '.candidates[0].content.parts[] | select(.inlineData != null)' &>/dev/null 2>&1; then
        echo "✅ Модель ${model} — успех (попытка ${attempt})" >&2
        echo "$resp"
        return 0
      fi

      echo "⚠️  Попытка ${attempt}/3 не удалась для ${model}" >&2
      if (( attempt < 3 )); then
        sleep 5
      fi
    done
    echo "❌ Модель ${model} недоступна после 3 попыток, переключаюсь..." >&2
  done

  echo '{"error": {"message": "All models failed after retries"}}'
  return 1
}

# ── Функция: сохранить base64 картинку из ответа API ─────────────────────────
extract_and_save() {
  local response="$1"
  local outfile="$2"

  if echo "$response" | jq -e '.error' &>/dev/null 2>&1; then
    echo "❌ API ошибка:" >&2
    echo "$response" | jq '.error' >&2
    return 1
  fi

  local b64
  b64=$(echo "$response" | jq -r '
    .candidates[0].content.parts[]
    | select(.inlineData != null)
    | .inlineData.data
  ' 2>/dev/null | head -1)

  if [[ -z "$b64" ]]; then
    echo "❌ API не вернул изображение. Полный ответ:" >&2
    echo "$response" | jq '.' >&2
    return 1
  fi

  python3 - <<PYEOF
import base64
data = """$b64"""
with open("$outfile", "wb") as f:
    f.write(base64.b64decode(data))
print("✅ Сохранено: $outfile")
PYEOF
}

# ══════════════════════════════════════════════════════════════════════════════
echo "═══════════════════════════════════════════════════"
echo "🍌 Nano Banana 2 | Режим: $MODE | $ASPECT_RATIO $IMAGE_SIZE"
echo "═══════════════════════════════════════════════════"

# ── ОБЛОЖКА СТАТЬИ (cover) ────────────────────────────────────────────────────
# Всегда 16:9, крупный заголовок на русском, дизайн в стиле журнала/блога
if [[ "$MODE" == "cover" ]]; then
  echo "📝 Заголовок: $TITLE_TEXT"
  echo "🖼️  Визуал:   $VISUAL_PROMPT"
  echo ""

  PROMPT="Generate a blog article cover image (16:9, magazine style).

Visual scene: ${VISUAL_PROMPT}

Text overlay requirements:
- Large bold headline in Russian: \"${TITLE_TEXT}\"
- Place headline in the lower third OR center of the image
- Use a dark semi-transparent background strip behind the text for readability
- Font: clean sans-serif, large, white or light color
- Text must be clearly readable against the background
- CRITICAL: ALL text on the image MUST be in Russian (Cyrillic script ONLY). Do NOT include ANY English words, labels, or inscriptions anywhere on the image.

Design style:
- Modern, professional blog/magazine cover
- High contrast between text and background
- No other text elements, no watermarks, no English text
- High quality output"

# ── ИЛЛЮСТРАЦИЯ С ТЕКСТОМ (image) ─────────────────────────────────────────────
# Иллюстрирует конкретный раздел. Текст — подпись/лейбл на русском.
elif [[ "$MODE" == "image" ]]; then
  echo "📝 Текст: $OVERLAY_TEXT"
  echo "🖼️  Визуал: $VISUAL_PROMPT"
  echo ""

  # Двухшаговый метод: для длинного текста (>25 символов) разбиваем на строки
  TEXT_LEN=${#OVERLAY_TEXT}
  echo "📏 Длина текста: $TEXT_LEN символов"

  if (( TEXT_LEN > 25 )); then
    # Разбиваем текст на части по словам (не более 25 символов на строку)
    TEXT_FORMATTED=$(python3 -c "
text = '$OVERLAY_TEXT'
words = text.split()
lines, line = [], ''
for w in words:
    if len(line) + len(w) + 1 <= 25:
        line = (line + ' ' + w).strip()
    else:
        if line: lines.append(line)
        line = w
if line: lines.append(line)
print(' / '.join(lines))
")
    echo "📐 Разбит на строки: $TEXT_FORMATTED"
  else
    TEXT_FORMATTED="$OVERLAY_TEXT"
  fi

  PROMPT="Generate an illustration for a blog article section.

Visual concept: ${VISUAL_PROMPT}

Text to render on the image:
- Label or caption in Russian: \"${OVERLAY_TEXT}\"
- Render as: \"${TEXT_FORMATTED}\" (use line breaks where / appears)
- Place text in a visually natural position (top, bottom, or center)
- Text must be legible: use contrasting color and optionally a subtle background
- CRITICAL: ALL text on the image MUST be in Russian (Cyrillic script ONLY). Do NOT include ANY English words, labels, or inscriptions anywhere on the image.

Style: informational blog illustration, clean, modern, no watermarks, no extra text, no English text"

# ── ИЛЛЮСТРАЦИЯ БЕЗ ТЕКСТА (notext) ──────────────────────────────────────────
else
  echo "🖼️  Визуал: $VISUAL_PROMPT"
  echo ""

  PROMPT="${VISUAL_PROMPT}

Style: high-quality blog article illustration. No text, no watermarks, no labels, no English inscriptions."
fi

# ── Генерация ─────────────────────────────────────────────────────────────────
echo "🚀 Отправляю запрос в Nano Banana 2..."
RESPONSE=$(call_nb2 "$PROMPT" "$ASPECT_RATIO" "$IMAGE_SIZE")
extract_and_save "$RESPONSE" "$TMPFILE"

# ── Загрузка на сервер по SSH ─────────────────────────────────────────────────
echo ""
echo "📁 Размер: $(du -sh "$TMPFILE" | cut -f1)"
echo "🚀 Загружаю → ${SSH_USER}@${SSH_HOST}:${SERVER_IMG_PATH}/${FILENAME}"

ssh -i "${SSH_KEY_PATH}" \
    -o StrictHostKeyChecking=no \
    -o ConnectTimeout=10 \
    "${SSH_USER}@${SSH_HOST}" \
    "mkdir -p ${SERVER_IMG_PATH}"

scp -i "${SSH_KEY_PATH}" \
    -o StrictHostKeyChecking=no \
    "${TMPFILE}" \
    "${SSH_USER}@${SSH_HOST}:${SERVER_IMG_PATH}/${FILENAME}"

# ── Вывод результата ──────────────────────────────────────────────────────────
PUBLIC_URL="${IMG_BASE_URL}/${FILENAME}"

echo ""
echo "═══════════════════════════════════════════════════"
echo "✅ ГОТОВО!"
echo "📎 URL:      ${PUBLIC_URL}"
echo "📝 Markdown: ![${SLUG}](${PUBLIC_URL})"
echo "IMG_URL=${PUBLIC_URL}"
echo "═══════════════════════════════════════════════════"

rm -f "${TMPFILE}"
