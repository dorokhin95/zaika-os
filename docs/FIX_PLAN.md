# Генеральный план исправлений «Зайка ОС 1.0»
Последнее обновление: 2026-09-19

---

## ПРИОРИТЕТ 1 (КРИТИЧНО): Исправить зависание на неттопе

### Проблема
После установки на `/dev/sda` неттоп с AMD E-450 (Radeon HD 6320) зависает на синем экране.

### Причина
Параметр ядра `radeon.modeset=1` несовместим с этим GPU в режиме Android-x86.

### Исправление в `01-zaika-os.sh` — строка menu.lst
```
# БЫЛО:
kernel /zaika_os/kernel root=/dev/ram0 androidboot.selinux=permissive SRC=zaika_os radeon.modeset=1 quiet

# СТАЛО (диагностический режим для проверки):
kernel /zaika_os/kernel root=/dev/ram0 androidboot.selinux=permissive SRC=zaika_os nomodeset

# СТАЛО (после подтверждения что nomodeset работает — финальный вариант):
kernel /zaika_os/kernel root=/dev/ram0 androidboot.selinux=permissive SRC=zaika_os nomodeset quiet
```

**Шаги:**
1. В `01-zaika-os.sh` заменить `radeon.modeset=1 quiet` → `nomodeset` (без quiet для диагностики)
2. Пересобрать ISO
3. Прошить на флешку, установить на неттоп
4. Если загрузилась — добавить `quiet` и сделать финальный ISO

---

## ПРИОРИТЕТ 2 (ВЫСОКИЙ): Правильные категории в LtvLauncher

### Проблема
Лаунчер показывает «TV Apps», «Non-TV Apps», «Favorites» вместо 6 плиток по ТЗ.

### Причина
Файл `/data/data/com.leanbitlab.ltvL/app_flutter/db.sqlite` не преднастроен.

### Структура БД (выявлена реверс-инжинирингом)
```sql
TABLE categories: id, name, sort, type, row_height, columns_count, order
TABLE apps: package_name, name, version, hidden, last_launched_at
TABLE apps_categories: category_id, app_package_name, order
```

### Нужная конфигурация по ТЗ
```sql
-- Категории
INSERT INTO categories VALUES (1, '🎬 Фильмы',     0, 0, 110, 6, 0);
INSERT INTO categories VALUES (2, '▶ YouTube',      0, 0, 110, 6, 1);
INSERT INTO categories VALUES (3, '🎮 Игры',        0, 0, 110, 6, 2);
INSERT INTO categories VALUES (4, '🌐 Браузер',     0, 0, 110, 6, 3);
INSERT INTO categories VALUES (5, '⚙ Настройки',   0, 0, 110, 6, 4);
INSERT INTO categories VALUES (6, '🛡 VPN',         0, 0, 110, 6, 5);
INSERT INTO categories VALUES (7, '🖥 Рабочий стол', 0, 0, 110, 6, 6);

-- Приложения по категориям
(1) com.falcofemoralis.hdrezkaapp → 🎬 Фильмы
(2) org.smarttube.stable         → ▶ YouTube
(3) com.floydwiz.gamingcenter    → 🎮 Игры
(4) com.android.chrome           → 🌐 Браузер
(5) com.android.settings         → ⚙ Настройки
(6) org.amnezia.vpn              → 🛡 VPN
(7) com.android.launcher3        → 🖥 Рабочий стол
```

### Исправление
1. Сгенерировать `ltv_config.sqlite` локально (Python)
2. Встроить в `post_detect()` в `01-zaika-os.sh`:
   ```sh
   mkdir -p data/data/com.leanbitlab.ltvL/app_flutter
   cp /src/ltv_config.sqlite data/data/com.leanbitlab.ltvL/app_flutter/db.sqlite
   chmod 660 data/data/com.leanbitlab.ltvL/app_flutter/db.sqlite
   chown 1000:1000 data/data/com.leanbitlab.ltvL/app_flutter/db.sqlite
   ```
3. Добавить `ltv_config.sqlite` в ISO как `/src/ltv_config.sqlite`

---

## ПРИОРИТЕТ 2 (ВЫСОКИЙ): AmneziaVPN — правильный x86 APK

### Проблема
Android на AMD E-450 работает как x86 (32-bit), а в ISO лежит `AmneziaVPN.apk` с ABI `x86_64` — не устанавливается.

### Исправление
1. Использовать `AmneziaVPN_4.8.11.0_android_7_x86.apk` (уже скачан локально, 85 МБ)
2. Переименовать в `AmneziaVPN.apk` в папке `/src/apps/` в ISO
3. Пакет: `org.amnezia.vpn`

---

## ПРИОРИТЕТ 3 (СРЕДНИЙ): Убрать DecoView / рамку окна

### Причина
PrimeOS оборачивает приложения из `/data/app` в Freeform. LtvLauncher видит как пользовательское приложение, а не системный HOME.

### Варианты исправления
**Вариант A (предпочтительный):** Поместить LtvLauncher в `/system/priv-app/`:
```sh
mkdir -p system/priv-app/LtvLauncher
cp /src/apps/LtvLauncher.apk system/priv-app/LtvLauncher/LtvLauncher.apk
chmod 644 system/priv-app/LtvLauncher/LtvLauncher.apk
```
Тогда PrimeOS воспринимает его как системное HOME-приложение без Freeform.

**Вариант B:** Добавить в `/system/etc/primeos_freeform_blacklist.xml`:
```xml
<package name="com.leanbitlab.ltvL" />
```

---

## ПРИОРИТЕТ 3 (СРЕДНИЙ): Убрать «Запуск Android...»

### Исправление
Уже частично реализовано (prime_prefs.xml + settings put). Нужно добавить в `zaika_setup.sh`:
```sh
# Убить FallbackHome до его запуска
pm disable com.android.settings/.FallbackHome 2>/dev/null || true
# Патч строки "starting_android" в Settings.apk (расширенное исправление)
```

---

## ПРИОРИТЕТ 4 (ПЛАНОВО): Загрузить ISO в GitHub Releases

### Проблема
В репозитории `dorokhin95/zaika-os` теги `v1.0.0` и `v1.0.1` существуют, но ISO-файл не прикреплён ни к одному релизу. OTA-скрипт нерабочий.

### Исправление
1. После пересборки финального ISO загрузить через `gh release create v1.0.2 ZaikaOS-1.0-x86_64.iso`
2. Обновить `version.json` с `sha256` и `download_url`
3. Проверить работу `zaika-ota.sh`

---

## Порядок выполнения работ

```
[1] Исправить nomodeset в 01-zaika-os.sh
[2] Заменить AmneziaVPN.apk на x86 версию
[3] Сгенерировать ltv_config.sqlite и встроить в скрипт
[4] Пересобрать ISO
[5] Прошить флешку → установить на неттоп → проверить загрузку
[6] Если загружается → проверить категории и VPN
[7] Загрузить ISO в GitHub Releases как v1.0.2
[8] Проверить OTA-обновление
```
