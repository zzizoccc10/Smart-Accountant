#!/usr/bin/env bash
# ============================================================================
# سكربت بناء تطبيق «المحاسب السهل» لنظام iOS
# يجب تشغيله على جهاز macOS مع Xcode مثبّت (قيد من Apple لا يمكن تجاوزه)
# ============================================================================
set -e

echo "=============================================="
echo "  بناء «المحاسب السهل» لنظام iOS"
echo "=============================================="

# التحقق من نظام التشغيل
if [[ "$(uname)" != "Darwin" ]]; then
  echo "❌ خطأ: بناء iOS يتطلب جهاز macOS. نظامك الحالي: $(uname)"
  exit 1
fi

# التحقق من Xcode
if ! command -v xcodebuild &> /dev/null; then
  echo "❌ خطأ: Xcode غير مثبّت. ثبّته من App Store ثم أعد المحاولة."
  exit 1
fi

echo "✓ النظام وXcode متوفّران"

# 1) جلب الحزم
echo "→ جلب حزم Dart..."
flutter pub get

# 2) تثبيت CocoaPods
echo "→ تثبيت CocoaPods..."
cd ios
pod install --repo-update
cd ..

# 3) تنظيف سابق
echo "→ تنظيف البناء السابق..."
flutter clean
flutter pub get
cd ios && pod install && cd ..

# 4) البناء
MODE="${1:-release}"
if [[ "$MODE" == "ipa" ]]; then
  echo "→ بناء ملف IPA (يتطلب حساب Apple Developer + فريق موقّع)..."
  flutter build ipa --release
  echo ""
  echo "✅ تم إنشاء ملف IPA في: build/ios/ipa/"
else
  echo "→ بناء تطبيق iOS بدون توقيع (للمحاكي/الاختبار)..."
  flutter build ios --release --no-codesign
  echo ""
  echo "✅ تم إنشاء تطبيق iOS في: build/ios/iphoneos/Runner.app"
  echo ""
  echo "لتشغيله على جهاز حقيقي، افتح المشروع في Xcode ووقّعه بحسابك:"
  echo "   open ios/Runner.xcworkspace"
fi

echo ""
echo "=============================================="
echo "  انتهى البناء بنجاح ✅"
echo "=============================================="
