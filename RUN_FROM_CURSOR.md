# 🚀 تشغيل التطبيق من Cursor مباشرة

## الطريقة الأولى: استخدام Gradle من Terminal

### 1. تأكد من إعداد Android SDK:

```bash
# تحقق من وجود Android SDK
echo $ANDROID_HOME
# يجب أن يظهر المسار مثل: C:\Users\...\AppData\Local\Android\Sdk
```

إذا لم يكن معرّفاً، أضفه:

```bash
# في Windows PowerShell
$env:ANDROID_HOME = "C:\Users\Administrator.user-HP\AppData\Local\Android\Sdk"
$env:PATH += ";$env:ANDROID_HOME\platform-tools;$env:ANDROID_HOME\tools"
```

### 2. وصّل جهاز أندرويد أو شغّل Emulator:

```bash
# تحقق من الأجهزة المتصلة
adb devices
```

يجب أن ترى:
```
List of devices attached
emulator-5554   device
# أو
XXXXXXXX        device  (جهازك)
```

### 3. بناء وتثبيت التطبيق:

```bash
# تطبيق العملاء
./gradlew :customer-app:installDebug
./gradlew :customer-app:installDebug && adb shell am start -n com.amana.customer/.MainActivity

# تطبيق المزودين
./gradlew :provider-app:installDebug
./gradlew :provider-app:installDebug && adb shell am start -n com.amana.provider/.MainActivity

# تطبيق الإدارة
./gradlew :admin-app:installDebug
./gradlew :admin-app:installDebug && adb shell am start -n com.amana.admin/.MainActivity
```

## الطريقة الثانية: إنشاء Scripts سريعة

### Windows (PowerShell):

أنشئ ملف `run-customer.ps1`:
```powershell
Write-Host "Building Customer App..." -ForegroundColor Green
./gradlew :customer-app:installDebug
if ($LASTEXITCODE -eq 0) {
    Write-Host "Starting app..." -ForegroundColor Green
    adb shell am start -n com.amana.customer/.MainActivity
} else {
    Write-Host "Build failed!" -ForegroundColor Red
}
```

شغّله:
```bash
powershell -ExecutionPolicy Bypass -File run-customer.ps1
```

### أو استخدم ملف .bat:

أنشئ `run-customer.bat`:
```batch
@echo off
echo Building Customer App...
call gradlew :customer-app:installDebug
if %ERRORLEVEL% EQU 0 (
    echo Starting app...
    adb shell am start -n com.amana.customer/.MainActivity
) else (
    echo Build failed!
)
pause
```

شغّله بنقرة مزدوجة أو:
```bash
.\run-customer.bat
```

## الطريقة الثالثة: مهام VS Code / Cursor

أنشئ ملف `.vscode/tasks.json`:

```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Run Customer App",
            "type": "shell",
            "command": "./gradlew :customer-app:installDebug && adb shell am start -n com.amana.customer/.MainActivity",
            "group": "build",
            "presentation": {
                "reveal": "always",
                "panel": "new"
            }
        },
        {
            "label": "Run Provider App",
            "type": "shell",
            "command": "./gradlew :provider-app:installDebug && adb shell am start -n com.amana.provider/.MainActivity",
            "group": "build"
        },
        {
            "label": "Run Admin App",
            "type": "shell",
            "command": "./gradlew :admin-app:installDebug && adb shell am start -n com.amana.admin/.MainActivity",
            "group": "build"
        },
        {
            "label": "Clean Build",
            "type": "shell",
            "command": "./gradlew clean",
            "group": "build"
        }
    ]
}
```

ثم:
1. اضغط `Ctrl+Shift+P`
2. اكتب "Run Task"
3. اختر المهمة

## الطريقة الرابعة: تشغيل مباشر على جهاز فيزيائي

### 1. فعّل وضع المطور على جهازك:
- الإعدادات → حول الهاتف
- اضغط على "رقم البناء" 7 مرات
- ارجع → خيارات المطور
- فعّل "تصحيح USB"

### 2. وصّل الجهاز بالكمبيوتر

### 3. شغّل:
```bash
adb devices
./gradlew :customer-app:installDebug
```

## الأوامر المفيدة:

```bash
# عرض logs التطبيق
adb logcat | grep "Amana"

# إلغاء تثبيت التطبيق
adb uninstall com.amana.customer
adb uninstall com.amana.provider
adb uninstall com.amana.admin

# مسح بيانات التطبيق
adb shell pm clear com.amana.customer

# أخذ screenshot
adb shell screencap /sdcard/screen.png
adb pull /sdcard/screen.png

# فتح shell على الجهاز
adb shell

# إعادة تشغيل adb
adb kill-server
adb start-server
```

## عرض قاعدة البيانات:

```bash
# الدخول للجهاز
adb shell

# الوصول لقاعدة البيانات
cd /data/data/com.amana.customer/databases
sqlite3 amana.db

# استعلامات SQL
.tables
SELECT * FROM users;
SELECT * FROM orders;
.exit
```

## استكشاف الأخطاء:

### "adb is not recognized"
```bash
# أضف Android SDK للـ PATH
$env:PATH += ";C:\Users\Administrator.user-HP\AppData\Local\Android\Sdk\platform-tools"
```

### "No devices found"
```bash
# تأكد من تشغيل Emulator أو اتصال الجهاز
adb devices
# إذا فارغ، جرب:
adb kill-server
adb start-server
```

### "Build failed"
```bash
# نظّف المشروع
./gradlew clean
# أعد البناء
./gradlew build
```

### "Permission denied"
```bash
# في PowerShell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## الخلاصة:

**نعم، يمكنك تشغيل التطبيق من Cursor مباشرة!** 🎉

لكن Android Studio أسهل للأسباب التالية:
- ✅ Emulator مدمج
- ✅ أدوات debugging متقدمة
- ✅ Layout Editor مرئي
- ✅ إدارة SDK تلقائية
- ✅ Logcat منظم

**اختر ما يناسبك:**
- 💻 **Cursor**: للبرمجة والتعديل السريع
- 📱 **Terminal**: للبناء والتثبيت
- 🎯 **Android Studio**: للتطوير الكامل والـ debugging

---

**نصيحة:** استخدم Cursor للبرمجة، وAndroid Studio للتشغيل والاختبار! ⚡
