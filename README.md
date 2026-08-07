# منصة أمانة

أمانة مشروع قيد التأسيس لمنصة خدمات مصغرة للسوق السوداني، تستهدف العميل
ومقدم الخدمة والإدارة. المشروع **ليس منتجًا مكتملًا أو جاهزًا للإنتاج**.

## ما الموجود الآن؟

- `apps/amana_flutter/`: أساس Flutter موحد للأدوار الثلاثة، مع RTL/العربية
  وتنقل متجاوب، ودورة طلب/عرض/قبول محلية قابلة للتجربة. هو scaffold وظيفي
  للمعمارية وليس تطبيقًا كامل الشاشات أو متصلًا بالخادم بعد.
- `backend/supabase/`: أساس Backend مركزي PostgreSQL/Auth/JWT/Realtime مع
  migrations وسياسات RLS أولية ووظائف ذرية لقبول العروض وخصم العمولة.
- `customer-app/`, `provider-app/`, `admin-app/`, `app/`, `core/`: تطبيقات
  Android قديمة محفوظة، وتعتمد أساسًا على SQLite محلية/اتصال بين التطبيقات
  على الجهاز. لا تمثل Backend متعدد الأجهزة.
- `web-app/`: معرض HTML ثابت لتصاميم Stitch، وليس تطبيق ويب إنتاجيًا.

الحالة الدقيقة موزعة إلى implemented/scaffold/mock/pending في
[`PROJECT_STATUS.md`](PROJECT_STATUS.md)، والقرار التقني في
[`ARCHITECTURE.md`](ARCHITECTURE.md).

## تشغيل Flutter scaffold

يتطلب Flutter SDK. لأن platform shells لم تُولد بعد، نفّذ مرة واحدة من مجلد
التطبيق:

```powershell
cd apps\amana_flutter
flutter create . --platforms=android,ios,web,windows
flutter pub get
flutter test
flutter run -d chrome
```

لتشغيل target محدد دون بوابة اختيار الدور:

```powershell
flutter run -d chrome --dart-define=AMANA_ROLE=admin
flutter run -d windows --dart-define=AMANA_ROLE=admin
flutter run -d <android-device> --dart-define=AMANA_ROLE=customer
```

اختيار الدور الحالي للتطوير فقط؛ المصادقة المركزية لم تُربط بعد.

## تشغيل Backend محلي

يتطلب Docker وSupabase CLI:

```powershell
cd backend
supabase start
supabase db reset
```

لا تضع مفاتيح حقيقية في المستودع. انسخ `backend/.env.example` إلى ملف `.env`
محلي عند بدء ربط العميل.

## معاينة تصاميم Stitch

```powershell
py -m http.server 8080 --directory web-app
```

ثم افتح `http://localhost:8080`. هذه معاينة مرجعية فقط؛ لا تُبنى منها APK.
