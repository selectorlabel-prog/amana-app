# 🔧 دليل حل المشاكل - Troubleshooting Guide

## المشاكل الشائعة وحلولها

### ❌ Problem 1: "Gradle not found" أو "gradlew command not found"

**السبب:** ملف gradlew غير موجود أو لا يعمل

**الحل:**
```bash
# تأكد من وجود الملفات
dir gradlew
dir gradlew.bat

# إذا لم تكن موجودة، شغل:
gradle wrapper
```

---

### ❌ Problem 2: "Android SDK not found"

**السبب:** Android SDK غير مثبت أو غير معرّف

**الحل 1 - ثبت Android Studio:**
1. حمّل Android Studio من: https://developer.android.com/studio
2. ثبّته وافتحه
3. دعه يحمّل Android SDK تلقائياً

**الحل 2 - عرّف المتغيرات يدوياً:**
```bash
# في PowerShell
$env:ANDROID_HOME = "C:\Users\$env:USERNAME\AppData\Local\Android\Sdk"
$env:PATH += ";$env:ANDROID_HOME\platform-tools"
```

---

### ❌ Problem 3: "Compilation failed" أو أخطاء Kotlin

**السبب:** مشكلة في الكود أو المكتبات

**الحل:**
```bash
# 1. نظّف المشروع
./gradlew clean

# 2. امسح cache
./gradlew clean build --refresh-dependencies

# 3. في PowerShell، امسح Gradle cache
Remove-Item -Recurse -Force "$env:USERPROFILE\.gradle\caches"

# 4. أعد البناء
./gradlew assembleDebug
```

---

### ❌ Problem 4: "Could not resolve dependencies"

**السبب:** مشكلة في تحميل المكتبات من الإنترنت

**الحل:**
```bash
# 1. تأكد من الإنترنت
ping google.com

# 2. حاول مع --refresh-dependencies
./gradlew clean assembleDebug --refresh-dependencies

# 3. إذا كنت خلف proxy، عرّفه في gradle.properties
# HTTP_PROXY_HOST=proxy.example.com
# HTTP_PROXY_PORT=8080
```

---

### ❌ Problem 5: "Namespace mismatch" أو package errors

**السبب:** تضارب في أسماء الـ packages

**تم الحل:** ✅ قمت بتصليح هذا للتو!

النطاقات الصحيحة:
- `com.amana.customer` للعملاء
- `com.amana.provider` للمزودين
- `com.amana.admin` للإدارة
- `com.amana.core` للمشترك

---

### ❌ Problem 6: "Java version mismatch"

**السبب:** إصدار Java خاطئ

**الحل:**
```bash
# تحقق من إصدار Java
java -version

# يجب أن يكون Java 11 أو 17
# إذا كان مختلف، حمّل Java 11:
# https://adoptium.net/
```

---

### ❌ Problem 7: Build بطيء جداً

**السبب:** أول بناء يحمّل المكتبات

**الحل:**
- انتظر، أول مرة تأخذ 5-15 دقيقة
- المرات القادمة ستكون أسرع (1-3 دقائق)
- تأكد من سرعة الإنترنت

---

### ❌ Problem 8: "Out of memory" أثناء البناء

**السبب:** Gradle يحتاج ذاكرة أكثر

**الحل:**
أنشئ ملف `gradle.properties` في مجلد المشروع:
```properties
org.gradle.jvmargs=-Xmx2048m -XX:MaxPermSize=512m
org.gradle.parallel=true
org.gradle.caching=true
```

---

### ❌ Problem 9: "Permission denied" على gradlew

**السبب:** الملف لا يملك صلاحيات التنفيذ

**الحل (Windows):**
```bash
# في PowerShell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# أو شغّل:
.\gradlew.bat assembleDebug
```

**الحل (Mac/Linux):**
```bash
chmod +x gradlew
./gradlew assembleDebug
```

---

### ❌ Problem 10: خطأ في core module

**السبب:** ملفات core غير متزامنة

**الحل:**
```bash
# 1. ابن core أولاً
./gradlew :core:build

# 2. ثم ابن التطبيقات
./gradlew assembleDebug
```

---

## 🧪 اختبار البناء خطوة بخطوة

### الخطوة 1: تنظيف
```bash
./gradlew clean
```
يجب أن يمر بدون أخطاء ✅

### الخطوة 2: بناء core
```bash
./gradlew :core:build
```
يجب أن ينجح ✅

### الخطوة 3: بناء customer-app
```bash
./gradlew :customer-app:assembleDebug
```
يجب أن ينجح ✅

### الخطوة 4: بناء الباقي
```bash
./gradlew :provider-app:assembleDebug
./gradlew :admin-app:assembleDebug
```

---

## 📋 Checklist قبل البناء

```
☐ Android SDK مثبت
☐ ANDROID_HOME معرّف
☐ Java 11+ مثبت
☐ الإنترنت متصل
☐ gradlew موجود في مجلد المشروع
☐ settings.gradle.kts موجود
☐ build.gradle.kts موجود
```

---

## 🚀 إذا فشل كل شيء - الحل النهائي

### الطريقة السهلة:
1. **ثبت Android Studio**
2. **افتح المشروع فيه**
3. **دع Android Studio يصلح المشاكل تلقائياً**
4. **اضغط Build → Rebuild Project**
5. **ثم Build → Build Bundle(s) / APK(s) → Build APK(s)**

ستحصل على APK جاهزة! ✅

---

## 📞 طلب المساعدة

إذا استمرت المشاكل، أرسل لي:

1. **رسالة الخطأ الكاملة** من Terminal
2. **نتيجة هذه الأوامر:**
```bash
java -version
./gradlew --version
echo $env:ANDROID_HOME
```
3. **لقطة شاشة** من الخطأ

وسأساعدك فوراً! 🤝

---

## ✅ التحقق من النجاح

بعد البناء الناجح، يجب أن تجد:
```
✅ customer-app/build/outputs/apk/debug/customer-app-debug.apk
✅ provider-app/build/outputs/apk/debug/provider-app-debug.apk
✅ admin-app/build/outputs/apk/debug/admin-app-debug.apk
```

كل ملف حوالي 5-8 MB ✅
