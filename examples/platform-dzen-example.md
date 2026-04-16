# Площадка: Дзен DesignBot

## Публикация
- **Блог:** blog.designbot.ru
- **Способ:** WordPress API -> автоэкспорт RSS -> Дзен
- **UTM:** `?utm_source=dzen&utm_medium=article`

## WordPress-переменные (из config.env)
- `WP_DESIGNBOT_URL`
- `WP_DESIGNBOT_USER`
- `WP_DESIGNBOT_PASS`

## Особенности площадки

### Формат контента
- Чистый HTML (без `<!DOCTYPE>`, `<head>`, `<style>`)
- Никаких `<table>` — Дзен не поддерживает. Используй `<ul>` списки
- Картинки по прямым URL с сервера

### Правила для Дзен
- Заголовок: интригующий, но не кликбейт (Дзен банит за кликбейт)
- Длина: 3000-5000 слов — длинные статьи ранжируются лучше
- Изображения: минимум 5 штук, формат 16:9
- **НИКАКОГО АНГЛИЙСКОГО ТЕКСТА НА КАРТИНКАХ!** Все надписи на AI-иллюстрациях — ТОЛЬКО на русском языке. В промптах: "All text labels in Russian only, no English text". Если при проверке на картинке есть английский текст — перегенерировать.
- Первая ссылка на продукт — во 2-3 абзаце

### Категории WordPress
- Дизайн интерьера (ID: 3)
- ИИ и технологии (ID: 5)
- Ремонт и обустройство (ID: 7)

### Перелинковка
Ссылки на другие статьи блога (берём из последних постов WP):
```bash
source config.env
curl -s "${WP_DESIGNBOT_URL}/wp-json/wp/v2/posts?per_page=20&_fields=id,title,link" \
  -u "${WP_DESIGNBOT_USER}:${WP_DESIGNBOT_PASS}" --insecure
```

## Продукт по умолчанию
**designbot** (файл: `projects/products/designbot.md`)
