#!/bin/busybox sh

# ==========================================
# Зайка ОС 1.0 (Media & Game Edition)
# ==========================================

# 1. Properties in default.prop
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

# 2. Patch system/build.prop via mount --bind
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

# 3. Mount Zaika line-art bootanimation
if [ -f /src/bootanimation.zip ]; then
    cp -f /src/bootanimation.zip ./bootanimation.zaika
    chmod 644 ./bootanimation.zaika
    mount --bind ./bootanimation.zaika system/media/bootanimation.zip 2>/dev/null || true
fi

# 4. Copy apps to /zaika_apps so Android can access and install them
if [ -d /src/apps ]; then
    mkdir -p ./zaika_apps
    cp -f /src/apps/*.apk ./zaika_apps/ 2>/dev/null || true
    chmod 644 ./zaika_apps/*.apk 2>/dev/null || true
fi

# 5. Create /zaika_setup.sh for background initialization
cat << 'SETUP_EOF' > ./zaika_setup.sh
#!/system/bin/sh
if [ -f /data/zaika_setup.done ] || [ -f /data/zaika_setup.running ]; then
    exit 0
fi
touch /data/zaika_setup.running
exec > /data/zaika_setup.log 2>&1
echo "Zaika Setup started at $(date)"

# Wait until settings provider is fully initialized and can read/write
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60; do
    settings put secure primeos_activation_completed 1 >/dev/null 2>&1
    val=$(settings get secure primeos_activation_completed 2>/dev/null)
    if [ "$val" = "1" ]; then
        echo "Settings service is fully UP on attempt $i"
        break
    fi
    sleep 1
done

# Disable PrimeOS Activation & Setup Wizard completely
settings put secure primeos_activation_completed 1
settings put secure user_setup_complete 1
settings put secure tv_user_setup_complete 1
settings put global device_provisioned 1
settings put secure show_ime_with_hard_keyboard 1
settings put system system_locales ru-RU
settings put secure lockscreen.disabled 1

# Wait until Package Manager (pm) is ready
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30; do
    if pm path android >/dev/null 2>&1; then
        echo "Package Manager is UP on attempt $i"
        break
    fi
    sleep 1
done

# Disable primesetup Activity inside SystemUI
pm disable com.android.systemui/com.android.systemui.primeos.primesetup.MainActivity 2>/dev/null || true

# Disable standard desktop launcher3
pm disable com.android.launcher3 2>/dev/null || true

# Install all Zaika Apps
for apk in /zaika_apps/LtvLauncher.apk /zaika_apps/SmartTube.apk /zaika_apps/HDrezka.apk /zaika_apps/AmneziaVPN.apk; do
    if [ -f "$apk" ]; then
        echo "Installing $apk..."
        pm install -r -g "$apk" 2>/dev/null || true
    fi
done

# Enable LtvLauncher
pm enable com.leanbitlab.ltvL 2>/dev/null || true

# Ensure all activation and user setup flags are set to 1
settings put secure primeos_activation_completed 1
settings put secure user_setup_complete 1
settings put secure tv_user_setup_complete 1
settings put global device_provisioned 1
settings put secure lockscreen.disabled 1

# Dismiss lockscreen
wm dismiss-keyguard 2>/dev/null || true
input keyevent 82 2>/dev/null || true

# Restart SystemUI cleanly to drop any cached wizard
am force-stop com.android.systemui 2>/dev/null || true

# Launch LtvLauncher directly on screen
am start -n com.leanbitlab.ltvL/.MainActivity 2>/dev/null || true

rm -f /data/zaika_setup.running
touch /data/zaika_setup.done
echo "Zaika Setup finished successfully at $(date)"
SETUP_EOF

chmod 755 ./zaika_setup.sh

# 6. Inject service into init.android_x86.rc
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

# 7. Define post_detect to pre-populate /data
post_detect() {
    # Pre-populate data/local/bootanimation.zip
    if [ -f /src/bootanimation.zip ]; then
        mkdir -p data/local
        cp -f /src/bootanimation.zip data/local/bootanimation.zip
        chmod 644 data/local/bootanimation.zip
    fi

    # Pre-populate Settings database for Russian locale, provisioned flag, and keyboard
    mkdir -p data/system/users/0
    cat << 'XML_EOF' > data/system/users/0/settings_secure.xml
<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>
<settings version="134">
  <setting id="1" name="primeos_activation_completed" value="1" package="android" defaultValue="1" defaultSysSet="true" />
  <setting id="2" name="show_ime_with_hard_keyboard" value="1" package="android" defaultValue="1" defaultSysSet="true" />
  <setting id="3" name="user_setup_complete" value="1" package="android" defaultValue="1" defaultSysSet="true" />
  <setting id="4" name="tv_user_setup_complete" value="1" package="android" defaultValue="1" defaultSysSet="true" />
  <setting id="5" name="lockscreen.disabled" value="1" package="android" defaultValue="1" defaultSysSet="true" />
</settings>
XML_EOF

    cat << 'GLOBAL_XML_EOF' > data/system/users/0/settings_global.xml
<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>
<settings version="134">
  <setting id="1" name="device_provisioned" value="1" package="android" defaultValue="1" defaultSysSet="true" />
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