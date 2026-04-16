# Площадка: Блог designbot.ru

## Публикация
- **Блог:** designbot.ru/blog
- **Способ:** Prisma Blog API (MDX-контент)
- **UTM:** без UTM (свой блог)

## API

### Авторизация
Все запросы к admin API требуют заголовок:
```
Authorization: Bearer YOUR_ADMIN_TOKEN
```
Токен — в config.env (`DESIGNBOT_ADMIN_TOKEN`).

### Создание статьи
```bash
curl -X POST "https://designbot.ru/api/admin/blog/posts" \
  -H "Authorization: Bearer $DESIGNBOT_ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Заголовок статьи",
    "slug": "zagolovok-statji",
    "contentMdx": "## Раздел\n\nТекст статьи в формате MDX...",
    "status": "published",
    "cover": "https://your-server.ru/img/articles/cover.png",
    "coverAlt": "Описание обложки",
    "excerpt": "Краткое описание для превью (150-200 символов)",
    "seoTitle": "SEO Title — до 65 символов | DesignBot",
    "seoDescription": "SEO Description — до 160 символов с CTA",
    "categorySlug": "dizajn-interera",
    "tagSlugs": ["ii-dizajn", "remont", "vizualizacija"],
    "internalLinks": ["slug-statji-1", "slug-statji-2", "slug-statji-3"]
  }'
```

### Загрузка изображений
```bash
curl -X POST "https://designbot.ru/api/admin/blog/upload" \
  -H "Authorization: Bearer $DESIGNBOT_ADMIN_TOKEN" \
  -F "file=@/tmp/screenshot.png"
```
Ответ: `{"url": "https://designbot.ru/uploads/blog/screenshot-abc123.png"}`

### Получение тегов
```bash
curl "https://designbot.ru/api/admin/blog/tags" \
  -H "Authorization: Bearer $DESIGNBOT_ADMIN_TOKEN"
```

### Получение категорий
```bash
curl "https://designbot.ru/api/admin/blog/categories" \
  -H "Authorization: Bearer $DESIGNBOT_ADMIN_TOKEN"
```

### Получение последних статей (для перелинковки)
```bash
curl "https://designbot.ru/api/admin/blog/posts?limit=20&fields=slug,title" \
  -H "Authorization: Bearer $DESIGNBOT_ADMIN_TOKEN"
```

## Формат контента

MDX (Markdown + JSX). **Только Markdown, никакого HTML.**

```markdown
## Заголовок раздела

![Alt-текст изображения](https://your-server.ru/img/articles/image.png)
*Подпись под изображением*

Текст абзаца. Ссылка на [другую статью](/blog/slug-drugoj-statji) блога.

### Подзаголовок

| Колонка 1 | Колонка 2 | Колонка 3 |
|-----------|-----------|-----------|
| Данные    | Данные    | Данные    |

- Пункт списка 1
- Пункт списка 2
```

## Перелинковка

### Разделы сайта (для CTA)
| Страница | Путь | Когда ссылаться |
|----------|------|-----------------|
| Генератор | /generate | «Попробуйте сами» |
| Галерея | /gallery | «Примеры работ» |
| Цены | /pricing | «Тарифы и цены» |
| Стили | /styles | При упоминании конкретного стиля |

### Существующие категории
- `dizajn-interera` — Дизайн интерьера
- `remont` — Ремонт
- `ii-tekhnologii` — ИИ и технологии
- `lajfhaki` — Лайфхаки

### Существующие теги
Перед публикацией ОБЯЗАТЕЛЬНО получи актуальный список тегов через API.
Примеры существующих тегов:
- `ii-dizajn` — ИИ-дизайн
- `skandinavskij-stil` — Скандинавский стиль
- `remont-kvartiry` — Ремонт квартиры
- `vizualizacija` — Визуализация

## Особенности площадки
- **НИКАКОГО АНГЛИЙСКОГО ТЕКСТА НА КАРТИНКАХ!** Все надписи — ТОЛЬКО на русском языке.
- IndexNow автоматически уведомляет поисковики о новых статьях
- Минимум 3 internalLinks (slug'и связанных статей)
- Теги — переиспользовать существующие, не создавать новые без необходимости

## Продукт по умолчанию
**designbot** (файл: `projects/products/designbot.md`)
