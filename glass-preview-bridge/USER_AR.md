# معاينة أمانة في لوحة Glass — بدون CanvasKit

## التغيير الجذري
المعاينة صارت ملفات PNG+HTML في `glass-preview-bridge/live/` تتحدّث كل ثانيتين. لا تفتح Flutter مباشرة في Glass.

## كيف تعيد الفتح
افتح `glass-preview-bridge/live/market.html` و `admin.html` (أو `http://127.0.0.1:8100` و `:8101` إن فشل مسار الملف).

## أمر واحد
```powershell
powershell -ExecutionPolicy Bypass -File scripts\start_glass_previews.ps1
```
(أضف `-ForceFlutter` لإعادة مصادر Flutter الثابتة على 8095/7400)
