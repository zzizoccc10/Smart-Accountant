// ============================================================================
// شاشة قراءة الباركود بالكاميرا — MobileScanner
// تُرجع نص الباركود المقروء إلى الشاشة المستدعية، أو تبحث عن الصنف مباشرة
// ============================================================================
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/permission_service.dart';
import '../../theme/app_theme.dart';

class BarcodeScannerScreen extends StatefulWidget {
  /// وضع الاختيار: يرجِع الباركود كنص عبر Navigator.pop(code)
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.qrCode,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.itf,
      BarcodeFormat.codabar,
    ],
  );

  bool _handled = false;
  bool _denied = false;
  bool _torch = false;

  @override
  void initState() {
    super.initState();
    _ensurePermission();
  }

  Future<void> _ensurePermission() async {
    if (kIsWeb) return;
    final status = await PermissionService.request(Permission.camera);
    if (!mounted) return;
    setState(() => _denied = !status.isGranted);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.trim().isEmpty) return;
    _handled = true;
    Navigator.pop(context, raw.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('مسح الباركود'),
        actions: [
          IconButton(
            tooltip: 'الفلاش',
            icon: Icon(_torch ? Icons.flash_on : Icons.flash_off),
            onPressed: () async {
              await _controller.toggleTorch();
              setState(() => _torch = !_torch);
            },
          ),
        ],
      ),
      body: _denied
          ? _deniedView()
          : Stack(
              children: [
                Positioned.fill(
                  child: kIsWeb
                      ? _webNotice()
                      : MobileScanner(
                          controller: _controller,
                          onDetect: _onDetect,
                        ),
                ),
                // إطار التوجيه
                Center(
                  child: Container(
                    width: 260,
                    height: 180,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary, width: 3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: const Center(
                    child: Text(
                      'وجّه الكاميرا نحو الباركود',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _webNotice() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'ماسح الباركود بالكاميرا متاح داخل تطبيق الأندرويد.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ),
    );
  }

  Widget _deniedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography, size: 60, color: AppColors.warning),
            const SizedBox(height: 16),
            const Text('لا يمكن الوصول للكاميرا',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'يرجى منح صلاحية الكاميرا لمسح الباركود.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _ensurePermission,
              icon: const Icon(Icons.check_circle),
              label: const Text('طلب الصلاحية'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => PermissionService.openSettings(),
              icon: const Icon(Icons.settings, color: Colors.white),
              label: const Text('فتح الإعدادات',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
