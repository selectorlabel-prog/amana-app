@echo off
setlocal enabledelayedexpansion

echo ========================================
echo   إعادة بناء مشروع Amana من الصفر
echo ========================================
echo.

echo [1/6] حذف جميع ملفات البناء السابقة...
for %%d in (.gradle build customer-app\build provider-app\build admin-app\build core\build) do (
    if exist "%%d" (
        echo   - حذف %%d
        rmdir /s /q "%%d" 2>nul
    )
)
echo   ✓ تم!
echo.

echo [2/6] حذف Android Studio cache...
if exist ".idea" (
    echo   - حذف .idea
    rmdir /s /q ".idea" 2>nul
)
if exist "*.iml" del /q "*.iml" 2>nul
echo   ✓ تم!
echo.

echo [3/6] تنظيف Gradle cache...
if exist "%USERPROFILE%\.gradle\caches" (
    echo   - حذف gradle caches
    rmdir /s /q "%USERPROFILE%\.gradle\caches" 2>nul
)
echo   ✓ تم!
echo.

echo [4/6] تنظيف المشروع...
echo   - تنفيذ gradlew clean
call gradlew.bat clean --no-daemon
if !errorlevel! neq 0 (
    echo   × فشل التنظيف
    pause
    exit /b 1
)
echo   ✓ تم!
echo.

echo [5/6] بناء جميع التطبيقات...
echo   - بناء customer-app
echo   - بناء provider-app  
echo   - بناء admin-app
echo.
call gradlew.bat assembleDebug --no-daemon --stacktrace
if !errorlevel! neq 0 (
    echo.
    echo   × فشل البناء - راجع الأخطاء أعلاه
    pause
    exit /b 1
)
echo   ✓ تم البناء!
echo.

echo [6/6] التحقق من ملفات APK...
set APK_COUNT=0
if exist "customer-app\build\outputs\apk\debug\customer-app-debug.apk" (
    set /a APK_COUNT+=1
    echo   ✓ customer-app-debug.apk
)
if exist "provider-app\build\outputs\apk\debug\provider-app-debug.apk" (
    set /a APK_COUNT+=1
    echo   ✓ provider-app-debug.apk
)
if exist "admin-app\build\outputs\apk\debug\admin-app-debug.apk" (
    set /a APK_COUNT+=1
    echo   ✓ admin-app-debug.apk
)
echo.

if !APK_COUNT! equ 3 (
    echo ========================================
    echo   ✓✓✓ نجح البناء بالكامل! ✓✓✓
    echo ========================================
    echo.
    echo ملفات APK الجاهزة:
    echo.
    echo 1. تطبيق العملاء:
    echo    customer-app\build\outputs\apk\debug\customer-app-debug.apk
    echo.
    echo 2. تطبيق مقدمي الخدمة:
    echo    provider-app\build\outputs\apk\debug\provider-app-debug.apk
    echo.
    echo 3. تطبيق الإدارة:
    echo    admin-app\build\outputs\apk\debug\admin-app-debug.apk
    echo.
    echo ========================================
) else (
    echo ========================================
    echo   × فشل البناء - تم إنشاء !APK_COUNT! من 3 فقط
    echo ========================================
)

echo.
pause
