# 🛠️ دليل البناء خطوة بخطوة

## ⚠️ قبل البناء - تأكد من:

### 1. موقعك الصحيح
تأكد أنك في مجلد المشروع:
```
C:\Users\Administrator.user-HP\AndroidStudioProjects\amana
```

### 2. تثبيت المتطلبات

**الحد الأدنى:**
- ✅ JDK 11 أو أحدث

**للبناء الكامل بدون مشاكل:**
- ✅ Android Studio مثبت
- ✅ Android SDK موجود
- ✅ ANDROID_HOME معرّف

---

## 🚀 طريقة البناء

### الطريقة 1: الملف الجديد المحسّن (موصى به)

اضغط مرتين على:
```
BUILD.bat
```

هذا الملف الجديد سيعطيك:
- ✅ تفاصيل كل خطوة
- ✅ معلومات الأخطاء بوضوح
- ✅ التحقق من وجود الملفات
- ✅ فتح المجلدات تلقائياً

---

### الطريقة 2: من Terminal

افتح Terminal في Cursor:

```bash
# الخطوة 1: تنظيف
./gradlew clean

# الخطوة 2: بناء core
./gradlew :core:build

# الخطوة 3: بناء التطبيقات
./gradlew :customer-app:assembleDebug
./gradlew :provider-app:assembleDebug
./gradlew :admin-app:assembleDebug
```

---

### الطريقة 3: من Android Studio (الأسهل)

1. افتح Android Studio
2. افتح المشروع من:
   ```
   C:\Users\Administrator.user-HP\AndroidStudioProjects\amana
   ```
3. انتظر Sync (أول مرة تأخذ وقت)
4. **Build** → **Rebuild Project**
5. **Build** → **Build Bundle(s) / APK(s)** → **Build APK(s)**
6. اضغط **locate** عند الانتهاء

✅ سيفتح لك المجلد مباشرة!

---

## 📍 المسارات النهائية

بعد البناء الناجح:

```
✅ C:\Users\Administrator.user-HP\AndroidStudioProjects\amana\customer-app\build\outputs\apk\debug\customer-app-debug.apk

✅ C:\Users\Administrator.user-HP\AndroidStudioProjects\amana\provider-app\build\outputs\apk\debug\provider-app-debug.apk

✅ C:\Users\Administrator.user-HP\AndroidStudioProjects\amana\admin-app\build\outputs\apk\debug\admin-app-debug.apk
```

---

## ❓ حل المشاكل

### المشكلة 1: "Android SDK not found"

**الحل الأسهل:**
1. حمّل Android Studio
2. ثبّته
3. افتحه مرة واحدة (سيحمّل SDK تلقائياً)
4. أعد المحاولة

### المشكلة 2: Build بطيء جداً

**هذا طبيعي!**
- أول بناء: 10-20 دقيقة (يحمّل كل المكتبات)
- البناء الثاني: 2-5 دقائق فقط

### المشكلة 3: خطأ "Could not resolve"

**السبب:** مشكلة إنترنت

**الحل:**
```bash
./gradlew clean build --refresh-dependencies
```

### المشكلة 4: الملف لم يظهر حتى بعد النجاح

**تحقق:**
```bash
dir customer-app\build\outputs\apk\debug\*.apk
```

إذا ظهر الملف = ✅ موجود
إذا لم يظهر = ❌ البناء فشل فعلياً

---

## 💡 نصيحة ذهبية

**الطريقة الأضمن والأسهل:**

1. ثبت Android Studio
2. افتح المشروع فيه
3. File → Sync Project with Gradle Files
4. Build → Build APK(s)

✅ ستحصل على APK 100%!

---

## 📊 حجم الملفات المتوقع

```
customer-app-debug.apk:  4-8 MB
provider-app-debug.apk:  4-8 MB
admin-app-debug.apk:     3-6 MB
```

إذا الحجم أقل من 1 MB = ❌ مشكلة في البناء

---

## ✅ التحقق النهائي

بعد البناء، شغّل:
```
open-apk-folders.bat
```

يجب أن ترى الملفات الثلاثة! 🎉
