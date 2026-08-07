@echo off
cd /d C:\Users\Administrator.user-HP\AndroidStudioProjects\amana_app
echo START %DATE% %TIME% > C:\Users\Administrator.user-HP\AndroidStudioProjects\amana\app8080.log
call "C:\flutter\flutter_windows_3.44.2-stable\flutter\bin\flutter.bat" run -d web-server --web-hostname=127.0.0.1 --web-port=8080 --no-web-resources-cdn --verbose >> C:\Users\Administrator.user-HP\AndroidStudioProjects\amana\app8080.log 2>&1
echo EXIT %ERRORLEVEL% %DATE% %TIME% >> C:\Users\Administrator.user-HP\AndroidStudioProjects\amana\app8080.log
