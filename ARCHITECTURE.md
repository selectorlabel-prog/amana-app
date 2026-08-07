# معمارية أمانة المستهدفة

## القرار

الواجهة الجديدة تعتمد Flutter codebase موحدًا، مع ثلاثة targets من المصدر
نفسه: `customer` و`provider` و`admin`. هذا يقلل تكرار التصميم والنماذج،
ويدعم Android وiOS وWeb وWindows. يمكن فصل كل target إلى package مستقل لاحقًا
إذا اختلفت دورة الإصدار أو الصلاحيات جذريًا.

تطبيقات Android الحالية محفوظة مؤقتًا كمصدر للمنطق والسلوك، لكنها ليست الأساس
متعدد المنصات. معرض Stitch في `web-app/` مرجع تصميم فقط.

## الهيكل

```text
apps/
  amana_flutter/       Flutter UI + role-aware navigation
backend/
  supabase/
    config.toml
    migrations/       PostgreSQL schema, RLS, Realtime
customer-app/          Android legacy (preserved)
provider-app/          Android legacy (preserved)
admin-app/             Android legacy (preserved)
app/                   Android legacy database owner (preserved)
core/                  Android legacy local data layer (preserved)
web-app/               Stitch static design reference
```

## حدود الثقة

1. Supabase Auth يصدر JWT ويتحقق منه.
2. `profiles.role` هو مصدر الدور، ولا يجوز للعميل تعديل عمود الدور.
3. RLS يمنع الوصول غير المصرح به حتى لو عُدّل تطبيق العميل.
4. العمليات المالية والعمولة وقبول العرض يجب تنفيذها داخل PostgreSQL
   functions/transactions، وليس بحسابات UI.
5. SQLite لاحقًا cache اختياري فقط، وليس مصدر الحقيقة.

## التوجيه حسب الدور

- يمكن أثناء التطوير اختيار الدور من البوابة.
- يمكن بناء target محدد:
  `--dart-define=AMANA_ROLE=customer|provider|admin`.
- بعد ربط Auth، يجب استبدال `ScaffoldSessionRoleSource` بمصدر جلسة يقرأ الدور
  الموثق من Backend، مع رفض route لا يطابق الدور.

## milestones التالية

1. تثبيت/تحديد Flutter SDK، ثم توليد platform shells وتشغيل الاختبارات.
2. إضافة Supabase Flutter client وبيئة config بلا أسرار داخل المصدر.
3. تنفيذ OTP وتدفق session والدور مع اختبارات RLS.
4. ربط الـ vertical slice المحلي المنفذ (إنشاء طلب، عرضه للمزود، عرض سعر،
   وقبول) مع Supabase بدل `DemoOrderFlow`.
5. اختبار وظائف المحفظة والعمولة الذرية المنفذة في migration
   `202607120002_order_workflow.sql` ضد Supabase محلي.
6. تحويل شاشات Stitch تدريجيًا إلى widgets، شاشة واحدة مكتملة وظيفيًا في كل
   مرة بدل نقل HTML.

## توليد المنصات عند توفر Flutter

من `apps/amana_flutter`:

```powershell
flutter create . --platforms=android,ios,web,windows
flutter pub get
flutter test
flutter run -d chrome --dart-define=AMANA_ROLE=admin
```

لا تشغّل `flutter create` من جذر المشروع كي لا يغيّر وحدات Android القديمة.
