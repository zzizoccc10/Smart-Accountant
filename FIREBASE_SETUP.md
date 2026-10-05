# 🔥 دليل Firebase — المحاسب السهل

> **حالة المشروع: مُتحقَّق منها ✅**
> المشروع مربوط بمشروع Firebase الحقيقي **`easy-accountant-1acb8`**.
> تم اختبار جميع الخدمات فعلياً من داخل بيئة التطوير (انظر قسم «نتائج التحقق»).

---

## 🎯 نتائج التحقق الفعلي (Live Check)

| الخدمة | الحالة | الدليل |
|---|---|---|
| **مفتاح API** | ✅ يعمل | استرجاع `projectId: 462002399803` |
| **Authentication (Email/Password)** | ✅ مُفعّلة | إنشاء مستخدم حقيقي نجح (idToken صالح) |
| **Firestore Database** | ✅ مُفعّلة | قراءة/كتابة/حذف مستند نجح (HTTP 200) |
| **FCM (الإشعارات)** | ✅ مُفعّلة | Firebase Installations أرجع fid + authToken |
| **Cloud Storage** | ⚪ غير مُفعّلة | غير مستخدمة في التطبيق حالياً (لا مشكلة) |

### 🌐 التحقق على الويب (E2E عبر متصفح حقيقي)

تم تشغيل التطبيق فعلياً في متصفح Chrome والتحقق من:

| الفحص | النتيجة |
|---|---|
| تحميل Firebase SDK من gstatic (v11.9.1) | ✅ app/auth/firestore/messaging/storage |
| تهيئة Firebase بدون أخطاء | ✅ `Initializing Firebase firebase_core/auth/firestore` |
| إنشاء حساب المالك على الويب | ✅ نجح وانتقل لشاشة تهيئة النظام |
| الكتابة الفعلية في Firestore | ✅ `companies/default_company/users/<id>` |
| قراءة البيانات من Firestore | ✅ Write/Listen channels تعمل (HTTP 200) |

> **ملاحظة تقنية مهمة**: كان هناك عطل دقيق — البناء كان يُعيد استخدام ملف
> `web_plugin_registrant.dart` قديم لا يتضمّن Firebase، فيُستبعَد كود الويب
> بالكامل. الحل: `flutter clean` قبل البناء. **دائماً نفّذ `flutter clean`
> عند تغيير إعدادات Firebase.**

### المشروع الحقيقي
```
project_id      : easy-accountant-1acb8
project_number  : 462002399803
android_app_id  : 1:462002399803:android:dfe82af1661b5a16974a1e
package_name    : com.easyaccountant.erp
api_key         : AIzaSyDAxvd7thR_bPN2mtehLwYEu7D_sYAkP8c
```

---

## ⚠️ ملاحظة مهمة حول `google-services.json`

الملف المرفوع سابقاً إلى المنصة كان **ملفاً وهمياً (placeholder)**:
```
❌ project_id: "unknown-project"
❌ api_key   : "placeholder-api-key-a87scz3v1tkr"
```

✅ تم **تصحيحه** باستخدام البيانات الحقيقية من `firebase-admin-sdk.json`:
```
✅ project_id: "easy-accountant-1acb8"
✅ api_key   : "AIzaSyDAxvd7thR_bPN2mtehLwYEu7D_sYAkP8c"
```

النسخة الصحيحة موجودة الآن في:
- `android/app/google-services.json` (مُدمجة في APK ✅)
- `tool/firebase/google-services.real.json` (نسخة مرجعية)

---

## 🔄 كيف يعمل التطبيق؟

- **محلياً (Offline-First)**: يعمل بالكامل عبر Hive دون إنترنت.
- **سحابياً (تلقائياً)**: عند توفّر المفاتيح، يتصل بـ Firebase للمزامنة + المستخدمين + الإشعارات.
- **الويب**: يعمل محلياً بأمان حتى تُضاف مفاتيح تطبيق الويب (انظر قسم «الويب»).

---

## 📱 أندرويد — جاهز ✅

كل شيء مُهيّأ. فقط:
```bash
cd /home/user/flutter_app
flutter build apk --release
```
القيم الحقيقية مُدمجة تلقائياً (مؤكَّد داخل APK).

---

## 🌐 الويب (اختياري) — يحتاج خطوة إضافية

حالياً الويب يعمل **محلياً فقط** لأن معرّف تطبيق الويب غير موجود.
لتفعيل السحابة على الويب:

1. افتح: https://console.firebase.google.com/ → مشروعك
2. **⚙️ Project settings** → **General** → **Your apps**
3. أضف تطبيق **Web** (أيقونة `</>`)
4. انسخ القيم وضعها في `lib/services/firebase_config.dart`:
   ```dart
   static const String webApiKey = '...';
   static const String webAppId = '1:462002399803:web:...';
   static const String webProjectId = 'easy-accountant-1acb8';
   static const String webAuthDomain = 'easy-accountant-1acb8.firebaseapp.com';
   ```
5. أضف النطاق في **Authentication → Settings → Authorized domains**

---

## 🍎 iOS (اختياري) — يحتاج GoogleService-Info.plist

1. في Firebase Console → أضف تطبيق **iOS**
2. **Bundle ID** بالضبط: `com.easyaccountant.erp`
3. حمّل `GoogleService-Info.plist` وارفعه للمنصة
4. الأداة ستضعه في `ios/Runner/` وتحدّث المفاتيح تلقائياً

---

## 🛠️ الأداة التلقائية للربط

```bash
cd /home/user/flutter_app
python3 tool/link_firebase.py <path-to-google-services.json> [GoogleService-Info.plist]
flutter pub get && flutter build apk --release
```

---

## 🗄️ بنية البيانات السحابية

```
companies/{companyId}/
  ├── users/            ← المستخدمون والصلاحيات
  ├── accounts/         ← دليل الحسابات
  ├── contacts/         ← العملاء والموردون
  ├── items/            ← الأصناف
  ├── categories/       ← التصنيفات
  ├── invoices/         ← الفواتير
  ├── payments/         ← السندات
  ├── expenses/         ← المصروفات
  ├── expense_categories/
  ├── movements/        ← حركات المخزون
  ├── inv_balances/     ← أرصدة المخزون
  ├── cashboxes/        ← الصناديق
  ├── warehouses/       ← المخازن
  ├── journals/         ← القيود المحاسبية
  ├── employees/        ← الموظفون
  ├── attendance/       ← الحضور
  ├── payroll/          ← الرواتب
  ├── currencies/       ← العملات
  ├── fixed_assets/     ← الأصول الثابتة
  ├── payment_allocations/
  ├── branches/         ← الفروع
  ├── units/            ← الوحدات
  ├── cost_centers/     ← مراكز التكلفة
  ├── exchange_rates/   ← أسعار الصرف
  └── orders/           ← الطلبات
```
> **24 مجموعة** تُزامَن تلقائياً (Last-Write-Wins عبر `updatedAt`).

---

## 🔒 قواعد أمان Firestore (للتطوير)

> ⚠️ القواعد الحالية مفتوحة للاختبار. للإنتاج، قيّدها حسب المستخدم/الشركة.

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /companies/{companyId}/{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## 📋 ملخص الميزات

| الميزة | الحالة | الملف |
|---|---|---|
| نظام المستخدمين | ✅ | `models/user_models.dart` |
| الأدوار (6) | ✅ | owner/admin/accountant/sales/warehouse/viewer |
| الصلاحيات (32) | ✅ | `Perm` class |
| المصادقة | ✅ | `services/auth_service.dart` |
| المزامنة (24 مجموعة) | ✅ | `services/sync_service.dart` |
| الإشعارات (FCM) | ✅ | `services/push_notifications.dart` |
| إدارة المستخدمين | ✅ | `services/user_service.dart` |
| جلسة المستخدم | ✅ | `providers/session_provider.dart` |
| شاشة الدخول | ✅ | `ui/auth/login_screen.dart` |
| إدارة المستخدمين | ✅ | `ui/settings/users_screen.dart` |
| نموذج المستخدم | ✅ | `ui/settings/user_form.dart` |
| شاشة المزامنة | ✅ | `ui/settings/sync_screen.dart` |

---

## 📍 أين أجد الشاشات؟

**الإعدادات** → قسم **«المستخدمون والسحابة»**:
- 👥 المستخدمون والصلاحيات
- ☁️ المزامنة السحابية (مع مؤشر الحالة + تشخيص)

**عند أول تشغيل**: شاشة إعداد حساب المالك.

---

## 🔒 تأمين قواعد Firestore للإنتاج

### الوضع الحالي (تطوير)
القواعد مفتوحة للاختبار. التطبيق يكتب لـ Firestore **بدون مصادقة**.

### الترقية للأمان الكامل (خطوتان)

**الخطوة 1 — فعّل تسجيل الدخول المجهول (Anonymous):**
1. Firebase Console → **Authentication** → **Sign-in method**
2. فعّل **Anonymous** → Save
3. (اختياري) فعّل **Email/Password** لتسجيل دخول المستخدمين الحقيقيين

> التطبيق يسجّل دخولاً مجهولاً **تلقائياً** عند التشغيل (في `main.dart`)،
> فيصبح كل مستخدم مُصادَقاً عليه دون أي إزعاج. إن كان المزوّد غير مُفعّل،
> يتخطى التطبيق الخطوة بهدوء ويكمل محلياً.

**الخطوة 2 — طبّق القواعد المقيّدة:**
الملف `firestore.rules` جاهز في المشروع. انشرها بأحد الطريقتين:

- **عبر CLI:**
  ```bash
  cd /home/user/flutter_app
  firebase login
  firebase deploy --only firestore:rules
  ```
- **يدوياً:** Firestore → **Rules** → الصق محتوى `firestore.rules` → **Publish**

### القواعد المُطبّقة
```
match /companies/{companyId}/{document=**} {
  allow read:  if request.auth != null;   // أي مستخدم مُصادَق
  allow write: if request.auth != null;   // (يمكن تشديدها بالتحقق من العضوية)
}
match /{document=**} { allow read, write: if false; }  // رفض الباقي
```

### ⚠️ ترتيب مهم
طبّق **الخطوة 1 قبل الخطوة 2** — وإلا ستفشل الكتابة (لأن التطبيق لم يُصادَق بعد).

| الحالة | المصادقة المجهولة | القواعد | النتيجة |
|---|---|---|---|
| الآن (تطوير) | ❌ | مفتوحة | ✅ يعمل (غير آمن) |
| بعد الخطوة 1 فقط | ✅ | مفتوحة | ✅ يعمل |
| بعد الخطوتين | ✅ | مقيّدة | ✅ يعمل **وآمن** ✅ |
| الخطوة 2 بدون 1 | ❌ | مقيّدة | ❌ تفشل الكتابة |
