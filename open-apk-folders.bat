@echo off
echo ================================================
echo       فتح مجلدات APK - Open APK Folders
echo ================================================
echo.

echo [1] فتح مجلد تطبيق العملاء...
if exist "customer-app\build\outputs\apk\debug\" (
    start explorer "customer-app\build\outputs\apk\debug"
    echo ✅ تم فتح مجلد تطبيق العملاء
) else (
    echo ❌ المجلد غير موجود - لم يتم البناء بعد
    echo    قم ببناء التطبيق أولاً باستخدام build-apks.bat
)

echo.
echo [2] فتح مجلد تطبيق المزودين...
if exist "provider-app\build\outputs\apk\debug\" (
    start explorer "provider-app\build\outputs\apk\debug"
    echo ✅ تم فتح مجلد تطبيق المزودين
) else (
    echo ❌ المجلد غير موجود - لم يتم البناء بعد
)

echo.
echo [3] فتح مجلد تطبيق الإدارة...
if exist "admin-app\build\outputs\apk\debug\" (
    start explorer "admin-app\build\outputs\apk\debug"
    echo ✅ تم فتح مجلد تطبيق الإدارة
) else (
    echo ❌ المجلد غير موجود - لم يتم البناء بعد
)

echo.
echo ================================================
echo.
pause
