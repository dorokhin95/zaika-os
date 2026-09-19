#!/bin/busybox sh

# ==========================================
# Зайка ОС 1.0 (Media & Game Edition)
# ==========================================

# ------------------------------------------
# 0. Автоматическая тихая установка на диск
# ------------------------------------------
if grep -qE "auto_install|INSTALL=/dev/sda|AUTO_INSTALL=force" /proc/cmdline && [ "$SRC" != "/zaika_os" ] && [ ! -f /mnt/zaika_os/system.sfs ]; then
    echo "================================================="
    echo "  ЗАЙКА ОС 1.0: АВТОМАТИЧЕСКАЯ УСТАНОВКА НА ДИСК"
    echo "================================================="
    
    # Определение блочного устройства
    TARGET_DISK=""
    if [ -b /dev/block/sda ]; then
        TARGET_DISK="/dev/block/sda"
    elif [ -b /dev/sda ]; then
        TARGET_DISK="/dev/sda"
    fi

    if [ -n "$TARGET_DISK" ]; then
        echo "Целевой диск обнаружен: $TARGET_DISK"
        
        # 1. Отмонтирование любых активных разделов на целевом диске
        umount ${TARGET_DISK}* 2>/dev/null || true
        
        # 2. Создание таблицы разделов MBR с одним разделом sda1 на весь диск
        echo -e "o\nn\np\n1\n\n\nw\n" | fdisk $TARGET_DISK >/dev/null 2>&1
        sleep 2
        
        # 3. Создание ноды sda1 и форматирование в ext4
        PART1="${TARGET_DISK}1"
        [ ! -b "$PART1" ] && mknod /dev/block/sda1 b 8 1 2>/dev/null || true
        [ ! -b "$PART1" ] && [ -b /dev/block/sda1 ] && PART1="/dev/block/sda1"
        
        echo "Форматирование $PART1 в ext4 (Зайка ОС)..."
        mke2fs -F -t ext4 -L "ZaikaOS" $PART1 >/dev/null 2>&1 || mkfs.ext4 -F -L "ZaikaOS" $PART1 >/dev/null 2>&1
        
        # 4. Монтирование и копирование системных файлов
        mkdir -p /mnt_target
        mount -t ext4 $PART1 /mnt_target
        
        echo "Копирование системных файлов Зайка ОС..."
        mkdir -p /mnt_target/zaika_os
        cp -f /src/system.sfs /mnt_target/zaika_os/
        cp -f /src/kernel /mnt_target/zaika_os/
        cp -f /src/initrd.img /mnt_target/zaika_os/
        cp -rf /src/scripts /mnt_target/zaika_os/
        cp -rf /src/apps /mnt_target/zaika_os/
        cp -f /src/bootanimation.zip /mnt_target/zaika_os/ 2>/dev/null || true
        mkdir -p /mnt_target/zaika_os/data
        
        # 5. Установка загрузчика GRUB
        echo "Установка загрузчика GRUB на жесткий диск..."
        mkdir -p /mnt_target/boot/grub
        if [ -d /src/boot/grub_legacy ]; then
            cp -f /src/boot/grub_legacy/stage1 /mnt_target/boot/grub/ 2>/dev/null || true
            cp -f /src/boot/grub_legacy/stage2 /mnt_target/boot/grub/ 2>/dev/null || true
            cp -f /src/boot/grub_legacy/e2fs_stage1_5 /mnt_target/boot/grub/ 2>/dev/null || true
        fi
        
        cat << 'GRUB_LST_EOF' > /mnt_target/boot/grub/menu.lst
default 0
timeout 1

title Zaika OS 1.0 (Media & Game Edition)
    root (hd0,0)
    kernel /zaika_os/kernel root=/dev/ram0 androidboot.selinux=permissive SRC=/zaika_os radeon.modeset=1 vga=current
    initrd /zaika_os/initrd.img
GRUB_LST_EOF

        if [ -x /src/boot/grub_legacy/grub ]; then
            echo "(hd0) $TARGET_DISK" > /tmp/device.map
            /src/boot/grub_legacy/grub --device-map /tmp/device.map << 'GRUB_RUN_EOF' >/dev/null 2>&1
setup (hd0) (hd0,0)
quit
GRUB_RUN_EOF
        fi
        
        # Поддержка UEFI
        if [ -d /src/efi ]; then
            mkdir -p /mnt_target/EFI
            cp -rf /src/efi/* /mnt_target/EFI/ 2>/dev/null || true
        fi
        
        sync
        umount /mnt_target
        echo "================================================="
        echo "  УСТАНОВКА ЗАВЕРШЕНА! ИЗВЛЕКИТЕ ФЛЕШКУ."
        echo "  Перезагрузка через 3 секунды..."
        echo "================================================="
        sleep 3
        reboot -f
    fi
fi

# ------------------------------------------
# 1. Properties in default.prop
# ------------------------------------------
cat << 'PROP_EOF' >> default.prop
ro.build.display.id=Зайка ОС 1.0 (Media Edition)
ro.product.model=Zaika Box E-450
ro.product.brand=ZaikaOS
ro.product.name=zaika_box
ro.product.device=zaika_box
ro.prime.version=Зайка ОС 1.0
ro.zaika.version=1.0.0
ro.setupwizard.mode=DISABLED
setupwizard.theme=glif_light
ro.setupwizard.network_required=false
persist.sys.locale=ru-RU
persist.sys.language=ru
persist.sys.country=RU
ro.product.locale=ru-RU
qemu.hw.mainkeys=0
persist.sys.hard_keyboard=0
persist.sys.keyboard=1
PROP_EOF

# ------------------------------------------
# 2. Patch system/build.prop via mount --bind
# ------------------------------------------
if [ -f system/build.prop ]; then
    cp -f system/build.prop ./build.prop.zaika
    sed -i 's/^ro.build.display.id=.*/ro.build.display.id=Зайка ОС 1.0 (Media Edition)/' ./build.prop.zaika
    sed -i 's/^ro.product.model=.*/ro.product.model=Zaika Box E-450/' ./build.prop.zaika
    sed -i 's/^ro.prime.version=.*/ro.prime.version=Зайка ОС 1.0/' ./build.prop.zaika
    sed -i 's/^ro.product.locale=.*/ro.product.locale=ru-RU/' ./build.prop.zaika
    sed -i 's/^persist.sys.locale=.*/persist.sys.locale=ru-RU/' ./build.prop.zaika
    echo "persist.sys.locale=ru-RU" >> ./build.prop.zaika
    echo "persist.sys.language=ru" >> ./build.prop.zaika
    echo "persist.sys.country=RU" >> ./build.prop.zaika
    echo "ro.setupwizard.mode=DISABLED" >> ./build.prop.zaika
    echo "ro.prime.name=Зайка ОС" >> ./build.prop.zaika
    mount --bind ./build.prop.zaika system/build.prop 2>/dev/null || true
fi

# ------------------------------------------
# 3. Mount Zaika line-art bootanimation
# ------------------------------------------
if [ -f /src/bootanimation.zip ]; then
    cp -f /src/bootanimation.zip ./bootanimation.zaika
    chmod 644 ./bootanimation.zaika
    mount --bind ./bootanimation.zaika system/media/bootanimation.zip 2>/dev/null || true
fi

# ------------------------------------------
# 4. Copy apps to /zaika_apps
# ------------------------------------------
if [ -d /src/apps ]; then
    mkdir -p ./zaika_apps
    cp -f /src/apps/*.apk ./zaika_apps/ 2>/dev/null || true
    chmod 644 ./zaika_apps/*.apk 2>/dev/null || true
fi

# ------------------------------------------
# 5. Patch SystemUI with Bunny Start Button
# ------------------------------------------
if [ -f ./zaika_apps/SystemUI_zaika.apk ] && [ -f system/priv-app/SystemUI/SystemUI.apk ]; then
    mount --bind ./zaika_apps/SystemUI_zaika.apk system/priv-app/SystemUI/SystemUI.apk 2>/dev/null || true
fi

# ------------------------------------------
# 6. Dual-Interface Launcher Architecture
# ------------------------------------------
# LtvLauncher becomes the primary Home launcher (fullscreen, no DecoView frame)
# Original Launcher3 (Desktop) is kept as secondary privileged app
if [ -f ./zaika_apps/LtvLauncher.apk ]; then
    if [ -f system/priv-app/gameCentre/gameCentre.apk ] && [ -f system/priv-app/Launcher3/Launcher3.apk ]; then
        # Preserve original Launcher3 inside gameCentre slot
        mount --bind system/priv-app/Launcher3/Launcher3.apk system/priv-app/gameCentre/gameCentre.apk 2>/dev/null || true
    fi
    # Mount LtvLauncher directly as primary Launcher3
    mount --bind ./zaika_apps/LtvLauncher.apk system/priv-app/Launcher3/Launcher3.apk 2>/dev/null || true
fi

# ------------------------------------------
# 7. Create /zaika_setup.sh for background setup
# ------------------------------------------
cat << 'SETUP_EOF' > ./zaika_setup.sh
#!/system/bin/sh
if [ -f /data/zaika_setup.done ] || [ -f /data/zaika_setup.running ]; then
    exit 0
fi
touch /data/zaika_setup.running
exec > /data/zaika_setup.log 2>&1
echo "Zaika Setup started at $(date)"

# Wait until settings provider is available
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    settings put secure primeos_activation_completed 1 >/dev/null 2>&1
    val=$(settings get secure primeos_activation_completed 2>/dev/null)
    if [ "$val" = "1" ]; then
        echo "Settings service is fully UP on attempt $i"
        break
    fi
    sleep 1
done

# Set complete activation, provisioning, and disable lockscreen completely
settings put secure primeos_activation_completed 1
settings put secure primeos_activated 1
settings put global primeos_activation_completed 1
settings put global primeos_activated 1
settings put system primeos_activation_completed 1
settings put system primeos_activated 1
settings put secure user_setup_complete 1
settings put secure tv_user_setup_complete 1
settings put global device_provisioned 1
settings put secure show_ime_with_hard_keyboard 1
settings put system system_locales ru-RU
settings put secure lockscreen.disabled 1

# Disable FallbackHome so it never intercepts focus
pm disable com.android.settings/.FallbackHome 2>/dev/null || true

# Wait for Package Manager
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
    if pm path android >/dev/null 2>&1; then
        echo "Package Manager is UP on attempt $i"
        break
    fi
    sleep 1
done

# Dismiss keyguard immediately
wm dismiss-keyguard 2>/dev/null || true
input keyevent 82 2>/dev/null || true

# Install media apps asynchronously in the background so boot is instant!
(
    for apk in /zaika_apps/SmartTube.apk /zaika_apps/HDrezka.apk /zaika_apps/AmneziaVPN.apk; do
        if [ -f "$apk" ]; then
            echo "Installing $apk in background..." >> /data/zaika_setup.log
            pm install -r -g "$apk" >> /data/zaika_setup.log 2>&1
        fi
    done
    echo "All background apps installed at $(date)" >> /data/zaika_setup.log
) &

rm -f /data/zaika_setup.running
touch /data/zaika_setup.done
echo "Zaika Setup completed successfully at $(date)"
SETUP_EOF

chmod 755 ./zaika_setup.sh

# ------------------------------------------
# 8. Inject service into init.android_x86.rc
# ------------------------------------------
if [ -f init.android_x86.rc ]; then
    cat << 'RC_EOF' >> init.android_x86.rc

service zaika_setup /system/bin/sh /zaika_setup.sh
    class main
    user root
    group root system
    oneshot
    seclabel u:r:init:s0

on property:init.svc.zygote=running
    start zaika_setup
RC_EOF
fi

# ------------------------------------------
# 9. Pre-populate Settings database for /data
# ------------------------------------------
post_detect() {
    mkdir -p data/local
    if [ -f /src/bootanimation.zip ]; then
        cp -f /src/bootanimation.zip data/local/bootanimation.zip
        chmod 644 data/local/bootanimation.zip
    fi

    mkdir -p data/system/users/0
    cat << 'XML_EOF' > data/system/users/0/settings_secure.xml
<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>
<settings version="134">
  <setting id="1" name="primeos_activation_completed" value="1" package="android" defaultValue="1" defaultSysSet="true" />
  <setting id="2" name="primeos_activated" value="1" package="android" defaultValue="1" defaultSysSet="true" />
  <setting id="3" name="show_ime_with_hard_keyboard" value="1" package="android" defaultValue="1" defaultSysSet="true" />
  <setting id="4" name="user_setup_complete" value="1" package="android" defaultValue="1" defaultSysSet="true" />
  <setting id="5" name="tv_user_setup_complete" value="1" package="android" defaultValue="1" defaultSysSet="true" />
  <setting id="6" name="lockscreen.disabled" value="1" package="android" defaultValue="1" defaultSysSet="true" />
</settings>
XML_EOF

    cat << 'GLOBAL_XML_EOF' > data/system/users/0/settings_global.xml
<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>
<settings version="134">
  <setting id="1" name="device_provisioned" value="1" package="android" defaultValue="1" defaultSysSet="true" />
  <setting id="2" name="primeos_activation_completed" value="1" package="android" defaultValue="1" defaultSysSet="true" />
  <setting id="3" name="primeos_activated" value="1" package="android" defaultValue="1" defaultSysSet="true" />
</settings>
GLOBAL_XML_EOF

    cat << 'SYS_XML_EOF' > data/system/users/0/settings_system.xml
<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>
<settings version="134">
  <setting id="1" name="system_locales" value="ru-RU" package="android" defaultValue="ru-RU" defaultSysSet="true" />
</settings>
SYS_XML_EOF

    chown -R 1000:1000 data/system 2>/dev/null || true
    chmod 600 data/system/users/0/settings_*.xml 2>/dev/null || true
    chmod 700 data/system/users/0 2>/dev/null || true
    chmod 775 data/system 2>/dev/null || true
}