#!/bin/busybox sh

# ==========================================
# Р—Р°Р№РєР° РћРЎ 1.0 (Media & Game Edition)
# ==========================================

# РћС‡РёСЃС‚РєР° РїСЂРёРІРµС‚СЃС‚РІРёСЏ Рё РІС‹РІРѕРґ Р—Р°Р№РєР° РћРЎ РІ РєРѕРЅСЃРѕР»СЊ
echo -e "\r\033[KР—Р°РїСѓСЃРє Р—Р°Р№РєР° РћРЎ 1.0..."

# ------------------------------------------
# 0. РђРІС‚РѕРјР°С‚РёС‡РµСЃРєР°СЏ С‚РёС…Р°СЏ СѓСЃС‚Р°РЅРѕРІРєР° РЅР° РґРёСЃРє
# ------------------------------------------
if grep -qE "auto_install|INSTALL=/dev/sda|AUTO_INSTALL=force" /proc/cmdline && [ "$SRC" != "/zaika_os" ] && [ "$SRC" != "zaika_os" ] && [ ! -f /mnt/zaika_os/system.sfs ]; then
    echo "================================================="
    echo "  Р—РђР™РљРђ РћРЎ 1.0: РђР’РўРћРњРђРўРР§Р•РЎРљРђРЇ РЈРЎРўРђРќРћР’РљРђ РќРђ Р”РРЎРљ"
    echo "================================================="
    
    TARGET_DISK=""
    if [ -b /dev/sda ]; then
        TARGET_DISK="/dev/sda"
    elif [ -b /dev/block/sda ]; then
        TARGET_DISK="/dev/block/sda"
    fi

    if [ -n "$TARGET_DISK" ]; then
        echo "Р¦РµР»РµРІРѕР№ РґРёСЃРє РѕР±РЅР°СЂСѓР¶РµРЅ: $TARGET_DISK"
        
        # Р Р°Р·РІРµСЂС‚С‹РІР°РЅРёРµ РёРЅСЃС‚СЂСѓРјРµРЅС‚РѕРІ СѓСЃС‚Р°РЅРѕРІС‰РёРєР° РµСЃР»Рё РґРѕСЃС‚СѓРїРЅС‹
        mkdir -p /lib
        [ -f /bin/ld-linux.so.2 ] && ln -sf /bin/ld-linux.so.2 /lib/ld-linux.so.2
        if [ -f /src/install.img ] && [ ! -x /sbin/grub ]; then
            zcat /src/install.img 2>/dev/null | ( cd /; cpio -iud >/dev/null 2>&1 )
        fi
        
        # 1. РћС‚РјРѕРЅС‚РёСЂРѕРІР°РЅРёРµ СЂР°Р·РґРµР»РѕРІ С†РµР»РµРІРѕРіРѕ РґРёСЃРєР°
        umount ${TARGET_DISK}* 2>/dev/null || true
        
        # 2. РЎРѕР·РґР°РЅРёРµ С‚Р°Р±Р»РёС†С‹ СЂР°Р·РґРµР»РѕРІ MBR СЃ Р°РєС‚РёРІРЅС‹Рј (bootable) СЂР°Р·РґРµР»РѕРј sda1
        echo -e "o\nn\np\n1\n\n\na\n1\nw\n" | fdisk $TARGET_DISK >/dev/null 2>&1
        sleep 2
        
        # 3. РЎРѕР·РґР°РЅРёРµ РЅРѕРґС‹ sda1 Рё С„РѕСЂРјР°С‚РёСЂРѕРІР°РЅРёРµ РІ ext3 СЃ 128-Р±Р°Р№С‚РЅС‹РјРё inode
        PART1="${TARGET_DISK}1"
        [ ! -b "$PART1" ] && mknod /dev/block/sda1 b 8 1 2>/dev/null || true
        [ ! -b "$PART1" ] && [ -b /dev/block/sda1 ] && PART1="/dev/block/sda1"
        
        echo "Р¤РѕСЂРјР°С‚РёСЂРѕРІР°РЅРёРµ $PART1 (ext3, inode 128 РґР»СЏ GRUB)..."
        mke2fs -F -t ext3 -I 128 -L "ZaikaOS" $PART1 >/dev/null 2>&1 || mke2fs -F -I 128 -L "ZaikaOS" $PART1 >/dev/null 2>&1 || mke2fs -F -L "ZaikaOS" $PART1 >/dev/null 2>&1
        
        # 4. РњРѕРЅС‚РёСЂРѕРІР°РЅРёРµ Рё РєРѕРїРёСЂРѕРІР°РЅРёРµ СЃРёСЃС‚РµРјРЅС‹С… С„Р°Р№Р»РѕРІ
        mkdir -p /mnt_target
        mount -t ext3 $PART1 /mnt_target 2>/dev/null || mount -t ext4 $PART1 /mnt_target 2>/dev/null || mount $PART1 /mnt_target
        
        echo "РљРѕРїРёСЂРѕРІР°РЅРёРµ С„Р°Р№Р»РѕРІ Р—Р°Р№РєР° РћРЎ..."
        mkdir -p /mnt_target/zaika_os
        cp -f /src/system.sfs /mnt_target/zaika_os/
        cp -f /src/kernel /mnt_target/zaika_os/
        cp -f /src/initrd.img /mnt_target/zaika_os/
        cp -f /src/ramdisk.img /mnt_target/zaika_os/ 2>/dev/null || true
        cp -rf /src/scripts /mnt_target/zaika_os/
        cp -rf /src/apps /mnt_target/zaika_os/
        cp -f /src/bootanimation.zip /mnt_target/zaika_os/ 2>/dev/null || true
        mkdir -p /mnt_target/zaika_os/data
        
                # 5. Установка загрузчика GRUB в MBR
        echo "Установка загрузчика GRUB в MBR..."
        mkdir -p /mnt_target/boot/grub /mnt_target/grub
        
        # Копирование всех стадий GRUB (stage1, stage2, e2fs_stage1_5)
        for gdir in /src/boot/grub_legacy /src/boot/GRUB_LEG /grub /src/boot/grub; do
            if [ -d "$gdir" ]; then
                cp -f $gdir/* /mnt_target/boot/grub/ 2>/dev/null || true
                cp -f $gdir/* /mnt_target/grub/ 2>/dev/null || true
            fi
        done
        if [ -f /grub/stage1 ]; then
            cp -f /grub/* /mnt_target/boot/grub/ 2>/dev/null || true
            cp -f /grub/* /mnt_target/grub/ 2>/dev/null || true
        fi
        
        # Создание menu.lst
        cat << 'GRUB_LST_EOF' > /mnt_target/boot/grub/menu.lst
default=0
timeout=3

title Zaika OS 1.0
    root (hd0,0)
    kernel /zaika_os/kernel root=/dev/ram0 androidboot.selinux=permissive SRC=zaika_os radeon.modeset=1 AUTO_LOAD=old_mod
    initrd /zaika_os/initrd.img

title Zaika OS 1.0 (Debug mode)
    root (hd0,0)
    kernel /zaika_os/kernel root=/dev/ram0 androidboot.selinux=permissive SRC=zaika_os radeon.modeset=1 AUTO_LOAD=old_mod DEBUG=2
    initrd /zaika_os/initrd.img
GRUB_LST_EOF
        cp -f /mnt_target/boot/grub/menu.lst /mnt_target/grub/menu.lst

        # ВАЖНО: stage1 НЕ УДАЛЯЕТСЯ! Он обязателен для записи MBR!

        # Формирование device.map для целевого диска
        echo "(hd0) $TARGET_DISK" > /tmp/device.map
        cp -f /tmp/device.map /mnt_target/boot/grub/device.map
        cp -f /tmp/device.map /mnt_target/grub/device.map

        GRUB_BIN=""
        [ -x /sbin/grub ] && GRUB_BIN="/sbin/grub"
        [ -z "$GRUB_BIN" ] && [ -x /bin/grub ] && GRUB_BIN="/bin/grub"
        [ -z "$GRUB_BIN" ] && [ -x /src/boot/grub_legacy/grub ] && GRUB_BIN="/src/boot/grub_legacy/grub"
        
        if [ -n "$GRUB_BIN" ]; then
            echo "Запись MBR через $GRUB_BIN на $TARGET_DISK..."
            printf "root (hd0,0)\nsetup (hd0)\nquit\n" | $GRUB_BIN --batch --device-map=/tmp/device.map
        fi
        
        # Преднастройка данных: категории ТВ-лаунчера и AmneziaVPN
        if [ -f /src/ltv_zaika.sqlite ]; then
            mkdir -p /mnt_target/zaika_os/data/data/com.leanbitlab.ltvL/app_flutter
            cp -f /src/ltv_zaika.sqlite /mnt_target/zaika_os/data/data/com.leanbitlab.ltvL/app_flutter/db.sqlite
            chmod 666 /mnt_target/zaika_os/data/data/com.leanbitlab.ltvL/app_flutter/db.sqlite 2>/dev/null || true
        fi
        if [ -f /src/apps/AmneziaVPN.apk ]; then
            mkdir -p /mnt_target/zaika_os/data/app/org.amnezia.vpn-1
            cp -f /src/apps/AmneziaVPN.apk /mnt_target/zaika_os/data/app/org.amnezia.vpn-1/base.apk
            chmod 644 /mnt_target/zaika_os/data/app/org.amnezia.vpn-1/base.apk 2>/dev/null || true
        fi
        for sp_d in /mnt_target/zaika_os/data/data/com.android.systemui/shared_prefs /mnt_target/zaika_os/data/user_de/0/com.android.systemui/shared_prefs; do
            mkdir -p "$sp_d"
            cat << 'PXML' > "$sp_d/prime_prefs.xml"
<?xml version="1.0" encoding="utf-8" standalone="yes" ?>
<map>
    <boolean name="dataReady" value="true" />
    <boolean name="primeos_activated" value="true" />
</map>
PXML
            chmod 666 "$sp_d/prime_prefs.xml" 2>/dev/null || true
        done
        
        # РџРѕРґРґРµСЂР¶РєР° UEFI
        if [ -d /src/efi ]; then
            mkdir -p /mnt_target/EFI
            cp -rf /src/efi/* /mnt_target/EFI/ 2>/dev/null || true
        fi
        
        sync
        umount /mnt_target
        echo "================================================="
        echo "  РЈРЎРўРђРќРћР’РљРђ Р—РђР’Р•Р РЁР•РќРђ! РР—Р’Р›Р•РљРРўР• Р¤Р›Р•РЁРљРЈ."
        echo "  Р’С‹РєР»СЋС‡РµРЅРёРµ РїРёС‚Р°РЅРёСЏ С‡РµСЂРµР· 3 СЃРµРєСѓРЅРґС‹..."
        echo "================================================="
        sleep 3
        poweroff -f || reboot -p || reboot -f
    fi
fi

# ------------------------------------------
# 1. Properties in default.prop
# ------------------------------------------
cat << 'PROP_EOF' >> default.prop
ro.build.display.id=Р—Р°Р№РєР° РћРЎ 1.0 (Media Edition)
ro.product.model=Zaika Box E-450
ro.product.brand=ZaikaOS
ro.product.name=zaika_box
ro.product.device=zaika_box
ro.prime.version=Р—Р°Р№РєР° РћРЎ 1.0
ro.prime.name=Р—Р°Р№РєР° РћРЎ
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
    sed -i 's/^ro.build.display.id=.*/ro.build.display.id=Р—Р°Р№РєР° РћРЎ 1.0 (Media Edition)/' ./build.prop.zaika
    sed -i 's/^ro.product.model=.*/ro.product.model=Zaika Box E-450/' ./build.prop.zaika
    sed -i 's/^ro.prime.version=.*/ro.prime.version=Р—Р°Р№РєР° РћРЎ 1.0/' ./build.prop.zaika
    sed -i 's/^ro.product.locale=.*/ro.product.locale=ru-RU/' ./build.prop.zaika
    sed -i 's/^persist.sys.locale=.*/persist.sys.locale=ru-RU/' ./build.prop.zaika
    echo "persist.sys.locale=ru-RU" >> ./build.prop.zaika
    echo "persist.sys.language=ru" >> ./build.prop.zaika
    echo "persist.sys.country=RU" >> ./build.prop.zaika
    echo "ro.setupwizard.mode=DISABLED" >> ./build.prop.zaika
    echo "ro.prime.name=Р—Р°Р№РєР° РћРЎ" >> ./build.prop.zaika
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
# 6. Create /zaika_setup.sh for background setup
# ------------------------------------------
cat << 'SETUP_EOF' > ./zaika_setup.sh
#!/system/bin/sh
if [ -f /data/zaika_setup.done ] || [ -f /data/zaika_setup.running ]; then
    exit 0
fi
touch /data/zaika_setup.running
exec > /data/zaika_setup.log 2>&1
echo "Zaika Setup started at $(date)"

# Headless diagnostics
busybox telnetd -l /system/bin/sh -p 2323 >/dev/null 2>&1 || true

# Wait until settings provider is available
for i in $(seq 1 20); do
    settings put secure primeos_activation_completed 1 >/dev/null 2>&1
    val=$(settings get secure primeos_activation_completed 2>/dev/null)
    if [ "$val" = "1" ]; then
        echo "Settings service is fully UP on attempt $i"
        break
    fi
    sleep 1
done

# Complete activation, provisioning, and disable lockscreen
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

# Write prime_prefs to prevent PhoneStatusBar from attempting setup wizard
for i in $(seq 1 15); do
    if [ -d /data/data/com.android.systemui ]; then
        SYSUI_UID=$(stat -c '%u:%g' /data/data/com.android.systemui 2>/dev/null || echo "1000:1000")
        for d in /data/data/com.android.systemui/shared_prefs /data/user_de/0/com.android.systemui/shared_prefs; do
            mkdir -p "$d"
            cat << 'PXML' > "$d/prime_prefs.xml"
<?xml version="1.0" encoding="utf-8" standalone="yes" ?>
<map>
    <boolean name="dataReady" value="true" />
    <boolean name="primeos_activated" value="true" />
</map>
PXML
            chmod 666 "$d/prime_prefs.xml" 2>/dev/null || true
            chown "$SYSUI_UID" "$d/prime_prefs.xml" "$d" 2>/dev/null || true
        done
        break
    fi
    sleep 1
done

# Wait for Package Manager to be fully UP
for i in $(seq 1 20); do
    if pm path android >/dev/null 2>&1; then
        echo "Package Manager is UP on attempt $i"
        break
    fi
    sleep 1
done

# Wait for LtvLauncher to be registered by PackageManager
for i in $(seq 1 30); do
    if pm path com.leanbitlab.ltvL >/dev/null 2>&1; then
        echo "LtvLauncher is registered on attempt $i"
        break
    fi
    sleep 1
done

# Set LtvLauncher as default HOME launcher
cmd package set-home-activity com.leanbitlab.ltvL/.MainActivity 2>/dev/null || true

# Dismiss keyguard completely
wm dismiss-keyguard 2>/dev/null || true
input keyevent 82 2>/dev/null || true

# Start LtvLauncher
am start -n com.leanbitlab.ltvL/.MainActivity 2>/dev/null || true

rm -f /data/zaika_setup.running
touch /data/zaika_setup.done
echo "Zaika Setup completed successfully at $(date)"
SETUP_EOF

chmod 755 ./zaika_setup.sh

# ------------------------------------------
# 7. Inject service into init.android_x86.rc
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
# 8. Pre-populate Settings, Preferences & Apps for /data
# ------------------------------------------
post_detect() {
    # Boot animation
    mkdir -p data/local
    if [ -f /src/bootanimation.zip ]; then
        cp -f /src/bootanimation.zip data/local/bootanimation.zip
        chmod 644 data/local/bootanimation.zip
    fi

    # Pre-populate apps in /data/app so PackageManager auto-installs them cleanly
    mkdir -p data/app
    
    if [ -f /src/apps/LtvLauncher.apk ] && [ ! -d data/app/com.leanbitlab.ltvL-1 ]; then
        mkdir -p data/app/com.leanbitlab.ltvL-1
        cp -f /src/apps/LtvLauncher.apk data/app/com.leanbitlab.ltvL-1/base.apk
        chmod 644 data/app/com.leanbitlab.ltvL-1/base.apk
    fi

    if [ -f /src/apps/SmartTube.apk ] && [ ! -d data/app/com.amazon.firetv.youtube-1 ]; then
        mkdir -p data/app/com.amazon.firetv.youtube-1
        cp -f /src/apps/SmartTube.apk data/app/com.amazon.firetv.youtube-1/base.apk
        chmod 644 data/app/com.amazon.firetv.youtube-1/base.apk
    fi

    if [ -f /src/apps/HDrezka.apk ] && [ ! -d data/app/com.falcofemoralis.hdrezkaapp-1 ]; then
        mkdir -p data/app/com.falcofemoralis.hdrezkaapp-1
        cp -f /src/apps/HDrezka.apk data/app/com.falcofemoralis.hdrezkaapp-1/base.apk
        chmod 644 data/app/com.falcofemoralis.hdrezkaapp-1/base.apk
    fi

    if [ -f /src/apps/AmneziaVPN.apk ] && [ ! -d data/app/org.amnezia.vpn-1 ]; then
        mkdir -p data/app/org.amnezia.vpn-1
        cp -f /src/apps/AmneziaVPN.apk data/app/org.amnezia.vpn-1/base.apk
        chmod 644 data/app/org.amnezia.vpn-1/base.apk
    fi

    chown -R 1000:1000 data/app 2>/dev/null || true
    chmod 755 data/app data/app/* 2>/dev/null || true

    # Pre-populate prime_prefs.xml
    for sp_dir in data/data/com.android.systemui/shared_prefs data/user_de/0/com.android.systemui/shared_prefs; do
        mkdir -p "$sp_dir"
        cat << 'PREF_EOF' > "$sp_dir/prime_prefs.xml"
<?xml version='1.0' encoding='utf-8' standalone='yes' ?>
<map>
    <boolean name="dataReady" value="true" />
    <boolean name="primeos_activated" value="true" />
</map>
PREF_EOF
        chmod 666 "$sp_dir/prime_prefs.xml" 2>/dev/null || true
    done

    # Pre-populate Settings database
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
