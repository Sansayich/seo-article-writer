# Установка и настройка SEO Article Writer

Пошаговая инструкция по установке, настройке и первому запуску скилла.

## Чек-лист перед началом

- [ ] Claude Code установлен и работает (`claude --version`)
- [ ] Node.js 18+ установлен (`node --version`)
- [ ] SSH-доступ к серверу для хранения картинок (или альтернатива — S3/R2/локальный)
- [ ] Аккаунт ApiYi для генерации изображений
- [ ] (Опционально) Wordstat MCP для сбора семантики
- [ ] (Опционально) WordPress-блог для публикации в Дзен

---

## Шаг 1: Установка скилла

```bash
# Скопируй папку скилла в директорию навыков Claude Code
cp -r seo-article-writer-public ~/.claude/skills/seo-article-writer

# Установи зависимости (Playwright для скриншотов)
cd ~/.claude/skills/seo-article-writer
npm install

# Установи браузер для Playwright
npx playwright install chromium
```

## Шаг 2: Настройка config.env

```bash
cd ~/.claude/skills/seo-article-writer
cp config.env.example config.env
```

Открой `config.env` в редакторе и заполни все поля. Ниже — подробности по каждой секции.

---

## Получение API-ключей

### ApiYi (генерация изображений)

ApiYi предоставляет доступ к моделям генерации изображений (Nano Banana 2, Gemini Image и др.) через единый API.

1. Зарегистрируйся на [apiyi.com](https://apiyi.com)
2. Пополни баланс (минимум ~100 руб, хватает на десятки изображений)
3. В личном кабинете создай API-ключ
4. Скопируй ключ в `config.env`:
   ```
   APIYI_API_KEY="sk-ваш-ключ-здесь"
   ```

Скрипт использует модели в порядке приоритета:
- `nano-banana-2` — основная модель, лучше всего рендерит русский текст
- `gemini-3-pro-image-preview` — фоллбек
- `gemini-2.5-flash-image` — второй фоллбек

### WordPress Application Password (для публикации в Дзен)

Если планируешь публиковать через WordPress -> RSS -> Дзен:

1. Войди в WordPress Admin (`https://blog.example.ru/wp-admin`)
2. Перейди в **Users -> Edit (ваш профиль)**
3. Прокрути до секции **Application Passwords**
4. Введи имя (например: `claude-seo-writer`) и нажми **Add New**
5. Скопируй сгенерированный пароль (формат: `xxxx xxxx xxxx xxxx xxxx xxxx`)
6. Добавь в `config.env`:
   ```
   WP_MYPROJECT_URL="https://blog.example.ru"
   WP_MYPROJECT_USER="admin"
   WP_MYPROJECT_PASS="xxxx xxxx xxxx xxxx xxxx xxxx"
   ```

Имена переменных (`WP_MYPROJECT_*`) должны совпадать с тем, что указано в файле площадки (`projects/platforms/dzen-myproject.md`).

---

## Настройка сервера изображений

Скрипты генерируют картинки локально, затем загружают на сервер по SSH. Сервер отдаёт их через веб-сервер (nginx/apache) по публичному URL.

### Вариант A: Свой сервер (рекомендуется)

**Требования к серверу:**
- Linux (Ubuntu/Debian)
- SSH-доступ
- Nginx или Apache
- ~1 ГБ свободного места

**Настройка:**

1. Создай директорию для картинок:
   ```bash
   ssh your-server "mkdir -p /var/www/html/img/articles"
   ```

2. Настрой nginx для отдачи файлов:
   ```nginx
   # /etc/nginx/sites-available/images
   server {
       listen 80;
       server_name img.example.ru;  # или поддомен

       location /img/articles/ {
           alias /var/www/html/img/articles/;
           expires 30d;
           add_header Cache-Control "public, immutable";
       }
   }
   ```

3. Установи exiftool для очистки метаданных:
   ```bash
   ssh your-server "apt-get install -y libimage-exiftool-perl"
   ```

4. (Опционально) Установи Playwright для серверных скриншотов:
   ```bash
   ssh your-server "npm install -g playwright && npx playwright install chromium --with-deps"
   ```

5. Заполни в `config.env`:
   ```
   SSH_HOST="your-server.example.com"
   SSH_USER="root"
   SSH_KEY_PATH="~/.ssh/id_rsa"
   SERVER_IMG_PATH="/var/www/html/img/articles"
   IMG_BASE_URL="https://img.example.ru/img/articles"
   ```

### Вариант B: Amazon S3 / Cloudflare R2

Если не хочешь держать свой сервер — адаптируй скрипты для загрузки в S3/R2.

1. В `generate-image.sh` и `screenshot.sh` замени блок SSH-загрузки на:
   ```bash
   # Вместо scp + ssh:
   aws s3 cp "$TMPFILE" "s3://your-bucket/articles/${FILENAME}" --acl public-read
   # или для R2:
   # rclone copy "$TMPFILE" r2:your-bucket/articles/
   ```

2. `IMG_BASE_URL` будет:
   - S3: `https://your-bucket.s3.amazonaws.com/articles`
   - R2: `https://pub-xxx.r2.dev/articles` (или кастомный домен)

### Вариант C: Локальный сервер (для тестирования)

Для быстрого старта можно отдавать картинки с локального мака:

```bash
# Создай папку
mkdir -p ~/Public/img/articles

# Запусти простой HTTP-сервер
cd ~/Public && python3 -m http.server 8080 &

# В config.env:
# SERVER_IMG_PATH="$HOME/Public/img/articles"  # локальный путь
# IMG_BASE_URL="http://localhost:8080/img/articles"
```

В скриптах замени `scp`/`ssh` на простое `cp`. Подходит только для тестирования — картинки будут недоступны из интернета.

---

## Подключение WordPress-блога (для Дзен)

Схема работы: WordPress -> RSS -> Яндекс.Дзен.
Статьи публикуются в WordPress через REST API, Дзен подхватывает их из RSS-ленты.

### Шаг 1: Подготовь WordPress

1. Установи WordPress (если ещё нет). Подойдёт любой хостинг с WP.
2. Убедись что REST API доступен: `curl https://blog.example.ru/wp-json/wp/v2/posts` должен вернуть JSON.
3. Создай Application Password (см. выше).
4. Установи SEO-плагин (RankMath или Yoast) для заполнения meta-данных.

### Шаг 2: Настрой RSS для Дзен

1. RSS-лента WordPress по умолчанию: `https://blog.example.ru/feed/`
2. В Яндекс.Дзен (Студия Дзена): **Настройки -> RSS** -> добавь URL ленты
3. Дзен начнёт подтягивать новые посты автоматически (с задержкой 15-60 минут)

### Шаг 3: Создай профиль площадки

```bash
cp projects/platforms/_template.md \
   projects/platforms/dzen-myproject.md
```

Заполни файл:
- Домен блога
- WP-переменные (`WP_MYPROJECT_URL`, `WP_MYPROJECT_USER`, `WP_MYPROJECT_PASS`)
- UTM-метку
- Продукт по умолчанию

### Шаг 4: Проверь подключение

```bash
source config.env
curl -s "${WP_MYPROJECT_URL}/wp-json/wp/v2/posts?per_page=1&_fields=id,title" \
  -u "${WP_MYPROJECT_USER}:${WP_MYPROJECT_PASS}" --insecure
```

Должен вернуть JSON с последним постом. Если ошибка 401 — проверь пароль.

---

## Подключение Prisma/Next.js блога

Если у продукта есть собственный блог на Next.js + Prisma:

### Шаг 1: Определи API

Тебе нужно знать:
- URL создания поста: `POST /api/admin/blog/posts`
- URL загрузки изображений: `POST /api/admin/blog/upload`
- URL получения тегов: `GET /api/admin/blog/tags`
- URL получения категорий: `GET /api/admin/blog/categories`
- Авторизация (API-ключ, cookie, Bearer token)

### Шаг 2: Создай профиль площадки

```bash
cp projects/platforms/_template.md \
   projects/platforms/blog-mysite.md
```

Подробно опиши в файле:
- API endpoints
- Способ авторизации
- Формат контента (MDX)
- Таблицу перелинковки (какие страницы и статьи блога есть)
- Существующие категории и теги

Пример — в `examples/platform-prisma-blog-example.md`.

---

## Настройка Дзен (Яндекс.Дзен) через RSS

Яндекс.Дзен подхватывает статьи из RSS. Схема:

```
Claude -> WordPress API (draft) -> обложка -> publish -> RSS -> Дзен
```

### Важные правила:

1. **Пост публикуется ОДИН РАЗ.** `publish` -> RSS -> Дзен происходит мгновенно. Удалить из Дзена невозможно.
2. **Сначала обложка, потом publish.** Пост без обложки в Дзене выглядит ужасно.
3. **Никаких дублей.** Дзен помечает похожие статьи как дубли и не показывает в ленте.

### Проверка что RSS работает:

```bash
curl -s "https://blog.example.ru/feed/" | head -50
```

Должен показать XML с последними постами.

---

## Создание первого профиля продукта

### Автоматически (через онбординг)

Запусти Claude Code и скажи:
```
/seo-article-writer добавь продукт myproduct.ru
```

Скилл сам:
1. Спросит недостающую информацию
2. Просканирует сайт (главная, цены)
3. Сделает скриншоты
4. Создаст файл `projects/products/myproduct.md`
5. Покажет результат для подтверждения

### Вручную

```bash
cp projects/products/_template.md \
   projects/products/myproduct.md
```

Заполни все поля по шаблону. Пример — в `examples/product-example.md`.

---

## Создание первого профиля площадки

### Автоматически

Онбординг создаёт площадку вместе с продуктом, если она нужна.

### Вручную

```bash
cp projects/platforms/_template.md \
   projects/platforms/dzen-myproject.md
```

Заполни все поля. Примеры — в `examples/platform-dzen-example.md` и `examples/platform-prisma-blog-example.md`.

---

## Первая статья

После настройки конфига и создания профилей:

```
/seo-article-writer напиши SEO-статью для Дзен МойПроект на тему: лучшие инструменты для [ваша ниша] в 2026 году
```

Скилл пройдёт все 10 этапов и опубликует статью.

Для HTML-файла (без WordPress):
```
/seo-article-writer напиши SEO-статью на тему: как выбрать [продукт] — гайд для новичков
```

Результат — HTML-файл в `~/articles/`, который откроется в браузере.

---

## Батч-кампании (массовое написание)

Для массового производства статей:

1. Составь список тем (20-50 штук) в файле трекера
2. Запускай по одной статье за раз
3. Скилл автоматически вычёркивает опубликованные темы из трекера
4. Для параллельной работы — запусти несколько сессий Claude Code

Формат трекера (произвольный .md файл):

```markdown
## Кампания: Блог МойПродукт (осталось: 15)

- Тема статьи 1
- Тема статьи 2
- ...
```

---

## Устранение проблем

### `node: command not found`

NVM не загружен в неинтерактивном шелле. Добавь PATH перед вызовом скриптов:
```bash
export PATH="$(dirname $(which node)):$PATH"
```

### `config.env не найден`

Скрипты ищут config.env на уровень выше от `scripts/`. Убедись что файл на месте:
```bash
ls ~/.claude/skills/seo-article-writer/config.env
```

### `SSH: Permission denied`

- Проверь путь к ключу в `SSH_KEY_PATH`
- Проверь права: `chmod 600 ~/.ssh/id_rsa`
- Проверь что ключ добавлен на сервер: `ssh-copy-id user@server`

### `API error 401` (ApiYi)

- Проверь `APIYI_API_KEY` в config.env
- Проверь баланс на apiyi.com
- Попробуй: `curl -s https://api.apiyi.com/v1/models -H "Authorization: Bearer $APIYI_API_KEY"`

### `playwright не установлен`

```bash
cd ~/.claude/skills/seo-article-writer
npm install playwright
npx playwright install chromium
```

### Скриншот показывает Cloudflare / пустую страницу

Сайт блокирует автоматический доступ. Варианты:
1. Сними через сервер с русским IP (SSH + Playwright)
2. Найди скриншот в обзорных статьях через WebSearch
3. Сними вручную и загрузи на сервер

### Текст на обложке битый / нечитаемый

Нейросети иногда искажают русский текст. Решения:
- Перегенерируй (2-3 попытки обычно достаточно)
- Сократи заголовок
- Используй режим `notext` + подпись под картинкой

### WordPress: `rest_cannot_create`

- Проверь что Application Password создан правильно
- Проверь что REST API не заблокирован плагинами безопасности
- Проверь URL: `curl https://blog.example.ru/wp-json/wp/v2/`

### Дзен не подхватывает статьи

- Проверь RSS: `curl https://blog.example.ru/feed/`
- Убедись что пост в статусе `publish` (не `draft`)
- Подожди 15-60 минут — Дзен не обновляется мгновенно
- Проверь настройки RSS в Студии Дзена
