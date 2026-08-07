@echo off
cd /d C:\Users\Administrator.user-HP\AndroidStudioProjects\amana_app
call C:\flutter\flutter_windows_3.44.2-stable\flutter\bin\flutter.bat run -d web-server --web-hostname=127.0.0.1 --web-port=8094 --release --no-web-resources-cdn --base-href=/ > C:\Users\Administrator.user-HP\AndroidStudioProjects\amana\app8094.log 2>&1
