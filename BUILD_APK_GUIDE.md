# 📦 دليل بناء وتثبيت APK

## طريقة سريعة (3 خطوات)

### الخطوة 1️⃣: بناء APK

**الطريقة الأولى - استخدم الملف الجاهز:**
اضغط مرتين على ملف:
```
build-apks.bat
```
سيبني الثلاثة تطبيقات تلقائياً! ⚡

**الطريقة الثانية - من Terminal:**
```bash
# في مجلد المشروع
./gradlew assembleDebug
```

### الخطوة 2️⃣: احصل على APK

بعد البناء، ستجد الملفات في:

```
📂 المشروع/
   📂 customer-app/build/outputs/apk/debug/
      📱 customer-app-debug.apk  (تطبيق العملاء)
   
   📂 provider-app/build/outputs/apk/debug/
      📱 provider-app-debug.apk  (تطبيق المزودين)
   
   📂 admin-app/build/outputs/apk/debug/
      📱 admin-app-debug.apk     (تطبيق الإدارة)
```

### الخطوة 3️⃣: ثبّت على هاتفك

#### الطريقة الأولى (بدون كابل):
1. انسخ ملف APK إلى هاتفك:
   - عبر WhatsApp
   - عبر Bluetooth
   - عبر Google Drive
   - عبر USB كنسخ ملف عادي

2. افتح الملف على هاتفك

3. اسمح بالتثبيت من مصادر غير معروفة:
   - الإعدادات → الأمان
   - فعّل "مصادر غير معروفة"
   - أو "السماح من هذا المصدر"

4. اضغط "تثبيت"

#### الطريقة الثانية (بكابل USB):
```bash
# وصّل هاتفك بالكمبيوتر
# فعّل تصحيح USB على الهاتف
# ثم شغّل:

adb install customer-app\build\outputs\apk\debug\customer-app-debug.apk
```

---

## بناء نسخة Release (للإنتاج)

إذا أردت نسخة محسّنة وأصغر حجماً:

```bash
# بناء Release
./gradlew assembleRelease

# الملفات ستكون في:
# customer-app/build/outputs/apk/release/customer-app-release-unsigned.apk
```

**ملاحظة:** نسخة Release تحتاج توقيع (Signing) للتثبيت.

---

## استكشاف الأخطاء

### ❌ "Build failed"
```bash
# نظّف المشروع
./gradlew clean

# أعد البناء
./gradlew assembleDebug
```

### ❌ "لا يمكن التثبيت على الهاتف"

**السبب:** التطبيق مثبت بإصدار مختلف

**الحل:**
1. احذف التطبيق القديم من الهاتف
2. ثبّت النسخة الجديدة

### ❌ "مصادر غير معروفة محظورة"

**الحل (Android 8+):**
1. اضغط على ملف APK
2. ستظهر رسالة
3. اضغط "الإعدادات"
4. فعّل "السماح من هذا المصدر"

**الحل (Android 7 وأقدم):**
1. الإعدادات
2. الأمان
3. فعّل "مصادر غير معروفة"

---

## معلومات إضافية

### حجم التطبيقات:
- تطبيق العملاء: ~5-8 MB
- تطبيق المزودين: ~5-8 MB
- تطبيق الإدارة: ~4-6 MB

### متطلبات الهاتف:
- ✅ Android 7.0 (API 24) أو أحدث
- ✅ 20 MB مساحة فارغة
- ✅ RAM 1GB على الأقل

### صلاحيات التطبيق:
- 📍 الموقع الجغرافي (للخرائط)
- 🌐 الإنترنت (اختياري - للتطوير المستقبلي)

---

## أوامر مفيدة

```bash
# بناء جميع التطبيقات Debug
./gradlew assembleDebug

# بناء تطبيق واحد فقط
./gradlew :customer-app:assembleDebug

# بناء مع تنظيف
./gradlew clean assembleDebug

# بناء Release (محسّنة)
./gradlew assembleRelease

# عرض معلومات البناء
./gradlew --version

# عرض جميع المهام المتاحة
./gradlew tasks
```

---

## الخلاصة السريعة

```bash
# 1. بناء
./gradlew assembleDebug

# 2. الملفات في
customer-app/build/outputs/apk/debug/customer-app-debug.apk
provider-app/build/outputs/apk/debug/provider-app-debug.apk
admin-app/build/outputs/apk/debug/admin-app-debug.apk

# 3. انسخ لهاتفك وثبّت!
```

---

## أو استخدم الملف الجاهز! 🚀

فقط اضغط مرتين على:
```
build-apks.bat
```

وستحصل على الثلاثة تطبيقات جاهزة! ✨

---

**ملاحظة مهمة:** 
هذه نسخ Debug (تجريبية). للإنتاج الفعلي، ستحتاج بناء نسخة Release موقّعة.

لكن للتجربة والاختبار، نسخة Debug كافية تماماً! ✅
