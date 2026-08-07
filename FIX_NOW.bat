@echo off
echo ====================================
echo حل نهائي للمشكلة
echo ====================================
echo.

echo الخطوة 1: حذف cache...
rmdir /s /q .gradle 2>nul
rmdir /s /q build 2>nul
rmdir /s /q customer-app\build 2>nul
rmdir /s /q provider-app\build 2>nul
rmdir /s /q admin-app\build 2>nul
rmdir /s /q core\build 2>nul

echo الخطوة 2: تنظيف المشروع...
call gradlew.bat clean

echo.
echo الخطوة 3: بناء التطبيقات...
call gradlew.bat assembleDebug

echo.
echo ====================================
echo انتهى!
echo ====================================
pause
