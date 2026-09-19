# Детальный план исправлений (Fix Plan)
## Устранение задержки загрузки, брендирование и автозапуск LtvLauncher

### 1. Анализ проблемы
- В Live-режиме каталог `/data` пересоздаётся в tmpfs при каждом старте.
- Синхронная установка 4 тяжёлых APK через `pm install` занимала **6 минут 20 секунд** процессорного времени (компиляция `dex2oat` на 1 ядре).
- На слабом неттопе AMD E-450 это вызывало ощущение «вечного зависания» на этапе «Запуск Android...».
- Сам экран «Запуск Android...» вызывался компонентом `FallbackHome`, пока в системе отсутствовал готовый Home-лаунчер.

### 2. Реализуемые исправления

#### А. Внедрение LtvLauncher в `/system/priv-app` (Initrd Hook)
В скрипте `/scripts/01-zaika-os.sh` добавляется прямое монтирование APK до старта Android Framework:
```sh
mount --bind ./zaika_apps/LtvLauncher.apk system/priv-app/Launcher3/Launcher3.apk
```
* **Эффект:**
  - Лаунчер готов с 0-й миллисекунды загрузки.
  - Экран `FallbackHome` («Запуск Android...») полностью исключён из цепочки запуска.
  - Лаунчер запускается как нативный полноэкранный системный интерфейс без оконных рамок DecoView (`_ [ ] X`).

#### Б. Фоновая асинхронная установка медиа-приложений
В скрипте `zaika_setup.sh` установка оставшихся APK выносится в фоновый процесс:
```sh
(
    pm install -r -g /data/zaika_apps/SmartTube.apk
    pm install -r -g /data/zaika_apps/HDrezka.apk
    pm install -r -g /data/zaika_apps/AmneziaVPN.apk
) &
```
* **Эффект:** Время старта до рабочего стола снижается с 6.5 минут до **10–15 секунд**.

#### В. Системный ребрендинг в `build.prop`
Подмена идентификаторов операционной системы:
- `ro.build.display.id=Зайка ОС 1.0 (Media & Game Edition)`
- `ro.product.name=ZaikaOS`
- `ro.product.device=zaika_x86_64`

#### Г. Отключение мешающих компонентов
- Отключение `FallbackHome` (`pm disable com.android.settings/.FallbackHome`).
- Отключение `SetupWizard` (`pm disable com.google.android.setupwizard`).
