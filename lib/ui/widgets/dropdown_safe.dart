// ============================================================================
// أدوات مساعدة لضمان أمان القوائم المنسدلة
// الغرض: منع اختفاء الشاشة (Assertion) عندما تكون قيمة الحقل المحددة غير موجودة
// ضمن عناصر القائمة (مثال: عنصر محذوف أو مخزن افتراضي غير مُنشأ).
// ============================================================================

/// يُرجع القيمة إن كانت ضمن المتاح، وإلا يُرجع null
T? safeValue<T>(T? value, Iterable<T> available) {
  if (value == null) return null;
  return available.contains(value) ? value : null;
}

/// يُرجع القيمة إن كانت ضمن المتاح، وإلا أول قيمة متاحة (أو null)
T? safeValueOrFirst<T>(T? value, List<T> available) {
  if (value != null && available.contains(value)) return value;
  return available.isEmpty ? null : available.first;
}
