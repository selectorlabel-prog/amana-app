@echo off
echo ========================================
echo تنظيف كامل للمشروع وإعادة البناء
echo ========================================
echo.

echo [1/5] حذف مجلدات البناء القديمة...
if exist "build" rmdir /s /q "build"
if exist ".gradle" rmdir /s /q ".gradle"
if exist "customer-app\build" rmdir /s /q "customer-app\build"
if exist "provider-app\build" rmdir /s /q "provider-app\build"
if exist "admin-app\build" rmdir /s /q "admin-app\build"
if exist "core\build" rmdir /s /q "core\build"
echo تم!

echo.
echo [2/5] حذف Gradle cache...
if exist "%USERPROFILE%\.gradle\caches" rmdir /s /q "%USERPROFILE%\.gradle\caches"
echo تم!

echo.
echo [3/5] إعادة بناء المشروع...
call gradlew.bat clean
echo تم!

echo.
echo [4/5] بناء التطبيقات...
call gradlew.bat :customer-app:assembleDebug :provider-app:assembleDebug :admin-app:assembleDebug
echo تم!

echo.
echo [5/5] عرض مواقع ملفات APK...
echo.
echo ====================================
echo تم البناء بنجاح!
echo ====================================
echo.
echo مواقع ملفات APK:
echo.
echo 1. تطبيق العملاء:
echo    %cd%\customer-app\build\outputs\apk\debug\customer-app-debug.apk
echo.
echo 2. تطبيق مقدمي الخدمة:
echo    %cd%\provider-app\build\outputs\apk\debug\provider-app-debug.apk
echo.
echo 3. تطبيق الإدارة:
echo    %cd%\admin-app\build\outputs\apk\debug\admin-app-debug.apk
echo.
echo ====================================

pause
