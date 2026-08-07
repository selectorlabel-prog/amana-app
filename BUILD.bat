@echo off
chcp 65001 >nul
echo.
echo ╔════════════════════════════════════════════════════════╗
echo ║         بناء تطبيقات أمانة - Amana Build            ║
echo ╚════════════════════════════════════════════════════════╝
echo.

REM التحقق من وجود gradlew
if not exist "gradlew.bat" (
    echo ❌ خطأ: ملف gradlew.bat غير موجود
    echo.
    echo الحل: تأكد من أنك في مجلد المشروع الصحيح
    echo المسار الصحيح: C:\Users\Administrator.user-HP\AndroidStudioProjects\amana
    echo.
    pause
    exit /b 1
)

echo ✅ تم العثور على ملفات المشروع
echo.

REM عرض معلومات Java
echo ═══ معلومات النظام ═══
java -version 2>&1 | findstr "version"
if %ERRORLEVEL% NEQ 0 (
    echo ❌ تحذير: Java غير مثبت أو غير معرّف في PATH
    echo.
)
echo.

REM التنظيف
echo [الخطوة 1/4] تنظيف المشروع...
echo ════════════════════════════════════════
call gradlew.bat clean
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ فشل التنظيف!
    echo.
    echo الأسباب المحتملة:
    echo - Android SDK غير مثبت
    echo - مشكلة في الإنترنت
    echo.
    pause
    exit /b 1
)
echo ✅ تم التنظيف بنجاح
echo.
echo.

REM بناء core
echo [الخطوة 2/4] بناء الوحدة الأساسية (core)...
echo ════════════════════════════════════════
call gradlew.bat :core:build
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ فشل بناء core!
    echo.
    pause
    exit /b 1
)
echo ✅ تم بناء core بنجاح
echo.
echo.

REM بناء تطبيق العملاء
echo [الخطوة 3/4] بناء تطبيق العملاء...
echo ════════════════════════════════════════
call gradlew.bat :customer-app:assembleDebug
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ فشل بناء تطبيق العملاء!
    echo.
    echo راجع الأخطاء أعلاه
    echo.
    pause
    exit /b 1
)
echo ✅ تم بناء تطبيق العملاء بنجاح
echo    📍 المسار: customer-app\build\outputs\apk\debug\customer-app-debug.apk
echo.
echo.

REM بناء تطبيق المزودين
echo [الخطوة 4/4] بناء تطبيق المزودين...
echo ════════════════════════════════════════
call gradlew.bat :provider-app:assembleDebug
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ⚠️  تحذير: فشل بناء تطبيق المزودين
    echo    لكن تطبيق العملاء جاهز!
    echo.
) else (
    echo ✅ تم بناء تطبيق المزودين بنجاح
    echo    📍 المسار: provider-app\build\outputs\apk\debug\provider-app-debug.apk
    echo.
)

REM بناء تطبيق الإدارة
call gradlew.bat :admin-app:assembleDebug >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo ✅ تم بناء تطبيق الإدارة بنجاح
    echo    📍 المسار: admin-app\build\outputs\apk\debug\admin-app-debug.apk
    echo.
)

echo.
echo ╔════════════════════════════════════════════════════════╗
echo ║                   ✅ اكتمل البناء!                   ║
echo ╚════════════════════════════════════════════════════════╝
echo.

REM التحقق من وجود الملفات
echo ═══ التحقق من الملفات ═══
echo.

set FOUND=0

if exist "customer-app\build\outputs\apk\debug\customer-app-debug.apk" (
    echo ✅ customer-app-debug.apk موجود
    for %%A in ("customer-app\build\outputs\apk\debug\customer-app-debug.apk") do echo    الحجم: %%~zA bytes
    set FOUND=1
) else (
    echo ❌ customer-app-debug.apk غير موجود
)

if exist "provider-app\build\outputs\apk\debug\provider-app-debug.apk" (
    echo ✅ provider-app-debug.apk موجود
    for %%A in ("provider-app\build\outputs\apk\debug\provider-app-debug.apk") do echo    الحجم: %%~zA bytes
    set FOUND=1
) else (
    echo ❌ provider-app-debug.apk غير موجود
)

if exist "admin-app\build\outputs\apk\debug\admin-app-debug.apk" (
    echo ✅ admin-app-debug.apk موجود
    for %%A in ("admin-app\build\outputs\apk\debug\admin-app-debug.apk") do echo    الحجم: %%~zA bytes
    set FOUND=1
) else (
    echo ⚠️  admin-app-debug.apk غير موجود
)

echo.

if %FOUND% EQU 1 (
    echo ╔════════════════════════════════════════════════════════╗
    echo ║      هل تريد فتح مجلد الملفات؟                      ║
    echo ╚════════════════════════════════════════════════════════╝
    echo.
    set /p OPEN="اكتب Y لفتح المجلد أو N للخروج: "
    if /i "%OPEN%"=="Y" (
        if exist "customer-app\build\outputs\apk\debug\" (
            start explorer "customer-app\build\outputs\apk\debug"
        )
        if exist "provider-app\build\outputs\apk\debug\" (
            start explorer "provider-app\build\outputs\apk\debug"
        )
        if exist "admin-app\build\outputs\apk\debug\" (
            start explorer "admin-app\build\outputs\apk\debug"
        )
    )
) else (
    echo ════════════════════════════════════════════════════════
    echo ⚠️  لم يتم العثور على أي ملف APK
    echo.
    echo راجع الأخطاء أعلاه أو جرب:
    echo 1. افتح المشروع في Android Studio
    echo 2. اضغط Build → Rebuild Project
    echo 3. ثم Build → Build APK
    echo ════════════════════════════════════════════════════════
)

echo.
pause
