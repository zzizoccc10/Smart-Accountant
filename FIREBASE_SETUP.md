# 🔥 دليل تفعيل Firebase — المحاسب السهل

التطبيق **يعمل بالكامل محلياً** الآن. لتفعيل السحابة (مزامنة + إشعارات + مستخدمين)،
نفّذ الخطوات التالية (5 دقائق):

---

## الخطوة 1: أنشئ تطبيق أندرويد في Firebase Console

1. افتح: https://console.firebase.google.com/
2. اختر مشروعك → **⚙️ Project settings** → تبويب **General**
3. انزل إلى **Your apps** → اضغط أيقونة **Android** لإضافة تطبيق
4. أدخل **Android package name** بالضبط:
   ```
   com.easyaccountant.erp
   ```
   ⚠️ **مهم جداً**: يجب أن يطابق هذا الاسم حرفياً وإلا لن يعمل.
5. (اختياري) اسم التطبيق: المحاسب السهل
6. اضغط **Register app** → **Download google-services.json**

---

## الخطوة 2: فعّل الخدمات في Firebase Console

### أ) المصادقة (Authentication)
1. القائمة الجانبية → **Build** → **Authentication** → **Get started**
2. تبويب **Sign-in method** → فعّل **Email/Password** → **Enable** → Save

### ب) قاعدة البيانات (Firestore)
1. القائمة الجانبية → **Build** → **Firestore Database** → **Create database**
2. اختر **Production mode** أو **Test mode** (للتجربة اختر Test)
3. اختر موقعاً قريباً (مثل `europe-west` أو `me-central`)

### ج) الإشعارات (Cloud Messaging) — مُفعّلة تلقائياً
- لا تحتاج إعداداً — تعمل بمجرد إضافة google-services.json.

---

## الخطوة 3: ارفع الملف إلى المنصة

ارفع ملف `google-services.json` إلى تبويب **Firebase** في المنصة.
سأقوم تلقائياً بـ:
- نسخه إلى `android/app/google-services.json`
- توليد مفاتيح `lib/services/firebase_config.dart`
- إعادة بناء التطبيق

### (بديل) الربط اليدوي عبر الأداة
```bash
cd /home/user/flutter_app
python3 tool/link_firebase.py /path/to/google-services.json
flutter pub get
flutter build apk --release
```

---

## الخطوة 4: قواعد أمان Firestore (للتطوير)

في **Firestore** → تبويب **Rules**، الصق:

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

> ⚠️ هذه القواعد للتطوير فقط. للإنتاج، قيّدها حسب المستخدم/الشركة.

---

## بنية البيانات السحابية

```
companies/
  {companyId}/
    ├── users/          ← المستخدمون
    ├── accounts/       ← دليل الحسابات
    ├── contacts/       ← العملاء والموردون
    ├── items/          ← الأصناف
    ├── invoices/       ← الفواتير
    ├── payments/       ← السندات
    ├── journals/       ← القيود
    ├── warehouses/     ← المخازن
    ├── cashboxes/      ← الصناديق
    └── ... (كل الجداول)
```

---

## ملخص الميزات المُضافة

| الميزة | الحالة | الملف |
|---|---|---|
| **نظام المستخدمين** | ✅ جاهز | `models/user_models.dart` |
| **الأدوار (6 أدوار)** | ✅ جاهز | owner/admin/accountant/sales/warehouse/viewer |
| **الصلاحيات الدقيقة (32)** | ✅ جاهز | `Perm` class |
| **المصادقة** | ✅ جاهز | `services/auth_service.dart` |
| **المزامنة** | ✅ جاهز | `services/sync_service.dart` |
| **الإشعارات (FCM)** | ✅ جاهز | `services/push_notifications.dart` |
| **شاشة الدخول** | ✅ جاهز | `ui/auth/login_screen.dart` |
| **إدارة المستخدمين** | ✅ جاهز | `ui/settings/users_screen.dart` |
| **شاشة المزامنة** | ✅ جاهز | `ui/settings/sync_screen.dart` |

---

## أين أجد الشاشات في التطبيق؟

- **الإعدادات** → قسم **«المستخدمون والسحابة»**:
  - المستخدمون والصلاحيات
  - المزامنة السحابية

- **عند أول تشغيل**: شاشة إعداد حساب المالك.
