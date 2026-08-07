@echo off
echo ================================================
echo        اختبار بناء مشروع أمانة
echo         Testing Amana Build
echo ================================================
echo.

echo [*] تنظيف المشروع...
echo [*] Cleaning project...
call gradlew clean

echo.
echo [*] جاري بناء تطبيق العملاء...
echo [*] Building Customer App...
call gradlew :customer-app:assembleDebug

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ================================================
    echo  ❌ فشل بناء تطبيق العملاء
    echo  ❌ Customer App Build Failed
    echo ================================================
    echo.
    echo الأخطاء المحتملة:
    echo 1. Android SDK غير مثبت
    echo 2. متغيرات البيئة غير معرفة
    echo 3. مشكلة في الإنترنت (تحميل المكتبات)
    echo.
    echo الحلول:
    echo 1. ثبت Android Studio
    echo 2. شغل sync في Android Studio أولاً
    echo 3. تأكد من اتصال الإنترنت
    echo.
    pause
    exit /b 1
)

echo.
echo ================================================
echo  ✅ نجح بناء تطبيق العملاء!
echo  ✅ Customer App Built Successfully!
echo ================================================
echo.
echo ستجد ملف APK في:
echo customer-app\build\outputs\apk\debug\customer-app-debug.apk
echo.
pause
