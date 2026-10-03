#!/usr/bin/env python3
# ============================================================================
# أداة الربط التلقائي مع Firebase — المحاسب السهل
# ----------------------------------------------------------------------------
# تقرأ ملف google-services.json (أندرويد) و GoogleService-Info.plist (iOS)
# وتُولّد القيم داخل lib/services/firebase_config.dart تلقائياً.
#
# الاستخدام:
#   python3 tool/link_firebase.py <path-to-google-services.json> [GoogleService-Info.plist]
#
# بعد التشغيل:
#   flutter pub get && flutter build apk --release
# ============================================================================
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CONFIG_DART = os.path.join(ROOT, 'lib', 'services', 'firebase_config.dart')
ANDROID_APP_DIR = os.path.join(ROOT, 'android', 'app')
IOS_RUNNER_DIR = os.path.join(ROOT, 'ios', 'Runner')


def die(msg):
    print(f'❌ {msg}')
    sys.exit(1)


def ok(msg):
    print(f'✅ {msg}')


def info(msg):
    print(f'ℹ️  {msg}')


def read_android(path):
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    project = data.get('project_info', {})
    project_id = project.get('project_id', '')
    sender_id = project.get('project_number', '')
    storage_bucket = project.get('storage_bucket', '')
    clients = data.get('client', [])
    if not clients:
        die('لا يوجد client داخل google-services.json')
    # نبحث عن تطبيق أندرويد بالمعرّف المطلوب، وإلا نأخذ الأول
    target = None
    for c in clients:
        info_block = c.get('client_info', {})
        android_info = info_block.get('android_client_info', {})
        pkg = android_info.get('package_name', '')
        if pkg == 'com.easyaccountant.erp':
            target = c
            break
    if target is None:
        target = clients[0]
        info('لم أجد معرّف com.easyaccountant.erp — سأستخدم أول تطبيق أندرويد')
    client_info = target.get('client_info', {})
    app_id = client_info.get('mobilesdk_app_id', '')
    api_key = ''
    for k in target.get('api_key', []):
        api_key = k.get('current_key', '')
        break
    return {
        'project_id': project_id,
        'sender_id': sender_id,
        'storage_bucket': storage_bucket,
        'app_id': app_id,
        'api_key': api_key,
    }


def read_ios(path):
    # plist بصيغة XML — قراءة بسيطة بمطابقة المفاتيح
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    def grab(key):
        m = re.search(
            rf'<key>{re.escape(key)}</key>\s*<string>([^<]*)</string>', content)
        return m.group(1).strip() if m else ''

    return {
        'project_id': grab('PROJECT_ID'),
        'sender_id': grab('GCM_SENDER_ID'),
        'storage_bucket': grab('STORAGE_BUCKET'),
        'app_id': grab('GOOGLE_APP_ID'),
        'api_key': grab('API_KEY'),
        'bundle_id': grab('BUNDLE_ID') or 'com.easyaccountant.erp',
        'auth_domain': grab('REVERSED_CLIENT_ID'),
    }


def update_dart(android, ios=None, web=None):
    with open(CONFIG_DART, 'r', encoding='utf-8') as f:
        src = f.read()

    def set_val(name, value):
        nonlocal src
        pattern = rf'(static const String {name} = )([^;]*)(;)'
        repl = rf"\g<1>'{value}'\g<3>"
        src, n = re.subn(pattern, repl, src)
        if n == 0:
            die(f'لم أجد المتغيّر {name} في firebase_config.dart')

    # Android
    set_val('androidApiKey', android['api_key'])
    set_val('androidAppId', android['app_id'])
    set_val('androidMessagingSenderId', android['sender_id'])
    set_val('androidProjectId', android['project_id'])

    # iOS
    if ios:
        set_val('iosApiKey', ios['api_key'])
        set_val('iosAppId', ios['app_id'])
        set_val('iosMessagingSenderId', ios['sender_id'])
        set_val('iosProjectId', ios['project_id'])
        set_val('iosStorageBucket', ios['storage_bucket'])
        set_val('iosBundleId', ios['bundle_id'])

    # Web (نستخدم نفس مشروع أندرويد — يجب إضافة قيم الويب من Firebase Console)
    if web:
        set_val('webApiKey', web['api_key'])
        set_val('webAppId', web['app_id'])
        set_val('webMessagingSenderId', web['sender_id'])
        set_val('webProjectId', web['project_id'])
        set_val('webAuthDomain', web.get('auth_domain', f"{web['project_id']}.firebaseapp.com"))
        set_val('webStorageBucket', web.get('storage_bucket', android['storage_bucket']))

    with open(CONFIG_DART, 'w', encoding='utf-8') as f:
        f.write(src)


def copy_android_file(path):
    os.makedirs(ANDROID_APP_DIR, exist_ok=True)
    dest = os.path.join(ANDROID_APP_DIR, 'google-services.json')
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    with open(dest, 'w', encoding='utf-8') as f:
        f.write(content)
    ok(f'نُسخ google-services.json إلى {dest}')


def copy_ios_file(path):
    os.makedirs(IOS_RUNNER_DIR, exist_ok=True)
    dest = os.path.join(IOS_RUNNER_DIR, 'GoogleService-Info.plist')
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()
    with open(dest, 'w', encoding='utf-8') as f:
        f.write(content)
    ok(f'نُسخ GoogleService-Info.plist إلى {dest}')


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        die('مرّر مسار google-services.json على الأقل')

    android_path = sys.argv[1]
    ios_path = sys.argv[2] if len(sys.argv) > 2 else None

    if not os.path.isfile(android_path):
        die(f'الملف غير موجود: {android_path}')

    android = read_android(android_path)
    info(f"مشروع أندرويد: {android['project_id']}")
    copy_android_file(android_path)

    ios = None
    if ios_path and os.path.isfile(ios_path):
        ios = read_ios(ios_path)
        info(f"مشروع iOS: {ios['project_id']}")
        copy_ios_file(ios_path)

    # نستخدم بيانات أندرويد للويب إن لم تُوفّر بيانات ويب مستقلة
    update_dart(android, ios=ios, web=android)

    ok('تم تحديث lib/services/firebase_config.dart بالقيم الجديدة')
    print()
    print('الخطوات التالية:')
    print('  1) flutter pub get')
    print('  2) flutter build apk --release')
    print('  3) فعّل Authentication (Email/Password) و Firestore في Firebase Console')


if __name__ == '__main__':
    main()
