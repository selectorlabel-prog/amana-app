@echo off
echo ========================================
echo   تنظيف كامل وإعادة Sync
echo ========================================
echo.

echo الخطوة 1: حذف Gradle cache...
if exist "%USERPROFILE%\.gradle\caches" (
    rmdir /s /q "%USERPROFILE%\.gradle\caches"
    echo   ✓ تم حذف Gradle cache
)

echo.
echo الخطوة 2: حذف ملفات المشروع المؤقتة...
if exist ".gradle" rmdir /s /q ".gradle"
if exist ".idea" rmdir /s /q ".idea"
if exist "build" rmdir /s /q "build"
if exist "customer-app\build" rmdir /s /q "customer-app\build"
if exist "provider-app\build" rmdir /s /q "provider-app\build"
if exist "admin-app\build" rmdir /s /q "admin-app\build"
if exist "core\build" rmdir /s /q "core\build"
echo   ✓ تم!

echo.
echo الخطوة 3: سيتم تحميل Gradle 8.10...
echo   (قد يأخذ بضع دقائق في المرة الأولى)
echo.
call gradlew.bat --version
echo.

echo الخطوة 4: بناء المشروع...
call gradlew.bat clean assembleDebug --stacktrace
echo.

if exist "customer-app\build\outputs\apk\debug\customer-app-debug.apk" (
    echo ========================================
    echo   ✓ نجح البناء!
    echo ========================================
    echo.
    echo ملفات APK:
    dir /b customer-app\build\outputs\apk\debug\*.apk
    dir /b provider-app\build\outputs\apk\debug\*.apk
    dir /b admin-app\build\outputs\apk\debug\*.apk
) else (
    echo × فشل البناء
)

echo.
pause
