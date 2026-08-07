@echo off
echo ================================================
echo        بناء تطبيقات أمانة - Amana Apps
echo ================================================
echo.

echo [1/3] جاري بناء تطبيق العملاء...
call gradlew :customer-app:assembleDebug
if %ERRORLEVEL% NEQ 0 (
    echo ❌ فشل بناء تطبيق العملاء
    pause
    exit /b 1
)
echo ✅ تم بناء تطبيق العملاء بنجاح

echo.
echo [2/3] جاري بناء تطبيق المزودين...
call gradlew :provider-app:assembleDebug
if %ERRORLEVEL% NEQ 0 (
    echo ❌ فشل بناء تطبيق المزودين
    pause
    exit /b 1
)
echo ✅ تم بناء تطبيق المزودين بنجاح

echo.
echo [3/3] جاري بناء تطبيق الإدارة...
call gradlew :admin-app:assembleDebug
if %ERRORLEVEL% NEQ 0 (
    echo ❌ فشل بناء تطبيق الإدارة
    pause
    exit /b 1
)
echo ✅ تم بناء تطبيق الإدارة بنجاح

echo.
echo ================================================
echo           تم البناء بنجاح! ✅
echo ================================================
echo.
echo ستجد ملفات APK في:
echo.
echo 📱 تطبيق العملاء:
echo    customer-app\build\outputs\apk\debug\customer-app-debug.apk
echo.
echo 📱 تطبيق المزودين:
echo    provider-app\build\outputs\apk\debug\provider-app-debug.apk
echo.
echo 📱 تطبيق الإدارة:
echo    admin-app\build\outputs\apk\debug\admin-app-debug.apk
echo.
echo ================================================
echo          انسخ الملفات لهاتفك وثبّتها!
echo ================================================
echo.

REM فتح مجلد الملفات
echo هل تريد فتح مجلد التطبيقات؟ (Y/N)
set /p OPEN="اختيارك: "
if /i "%OPEN%"=="Y" (
    start explorer "customer-app\build\outputs\apk\debug"
)

pause
