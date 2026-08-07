@echo off
cd /d C:\Users\Administrator.user-HP\AndroidStudioProjects\amana_admin
echo START %DATE% %TIME% > C:\Users\Administrator.user-HP\AndroidStudioProjects\amana\admin7390.log
call "C:\flutter\flutter_windows_3.44.2-stable\flutter\bin\flutter.bat" run -d web-server --web-hostname=127.0.0.1 --web-port=7390 --no-web-resources-cdn --verbose >> C:\Users\Administrator.user-HP\AndroidStudioProjects\amana\admin7390.log 2>&1
echo EXIT %ERRORLEVEL% %DATE% %TIME% >> C:\Users\Administrator.user-HP\AndroidStudioProjects\amana\admin7390.log
