@echo off
echo ========================================
echo إصلاح Gradle وبناء المشروع
echo ========================================
echo.

echo [الخطوة 1] حذف جميع ملفات البناء...
if exist ".gradle" (
    echo حذف .gradle...
    rmdir /s /q ".gradle"
)
if exist "build" (
    echo حذف build...
    rmdir /s /q "build"
)
if exist "customer-app\build" rmdir /s /q "customer-app\build"
if exist "provider-app\build" rmdir /s /q "provider-app\build"
if exist "admin-app\build" rmdir /s /q "admin-app\build"
if exist "core\build" rmdir /s /q "core\build"
echo تم!

echo.
echo [الخطوة 2] حذف Gradle Cache...
if exist "%USERPROFILE%\.gradle\caches\modules-2" (
    rmdir /s /q "%USERPROFILE%\.gradle\caches\modules-2"
)
echo تم!

echo.
echo [الخطوة 3] Gradle Sync...
call gradlew.bat --refresh-dependencies
echo تم!

echo.
echo [الخطوة 4] تنظيف المشروع...
call gradlew.bat clean
echo تم!

echo.
echo [الخطوة 5] بناء جميع التطبيقات...
call gradlew.bat :customer-app:assembleDebug :provider-app:assembleDebug :admin-app:assembleDebug
echo.

echo ========================================
if exist "customer-app\build\outputs\apk\debug\customer-app-debug.apk" (
    echo ✓ تم البناء بنجاح!
    echo.
    echo ملفات APK:
    echo 1. customer-app\build\outputs\apk\debug\customer-app-debug.apk
    echo 2. provider-app\build\outputs\apk\debug\provider-app-debug.apk
    echo 3. admin-app\build\outputs\apk\debug\admin-app-debug.apk
) else (
    echo × فشل البناء - راجع الأخطاء أعلاه
)
echo ========================================
echo.
pause
