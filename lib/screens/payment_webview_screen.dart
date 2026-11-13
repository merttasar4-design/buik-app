import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/colors.dart';

/// iyzico'nun hosted ödeme sayfasını açar. Ödeme tamamlanınca iyzico,
/// sunucumuzdaki payment-callback fonksiyonuna yönlenir; o fonksiyon da
/// bu WebView'i `buik://payment-result?status=success|failed` adresine
/// yönlendirir. Bu ekran o adresi yakalayıp sonucu döndürür.
class PaymentWebViewScreen extends StatefulWidget {
  const PaymentWebViewScreen({super.key, required this.paymentPageUrl});

  final String paymentPageUrl;

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() {
            _isLoading = true;
            _errorMessage = null;
          }),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (error) {
            if (error.isForMainFrame == false) return;
            setState(() {
              _isLoading = false;
              _errorMessage =
                  'Ödeme sayfası yüklenemedi. Bağlantınızı kontrol edip tekrar deneyin.';
            });
          },
          onNavigationRequest: (request) {
            if (request.url.startsWith('buik://payment-result')) {
              final uri = Uri.parse(request.url);
              final success = uri.queryParameters['status'] == 'success';
              Navigator.of(context).pop(success);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentPageUrl));
  }

  void _retry() {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });
    _controller.loadRequest(Uri.parse(widget.paymentPageUrl));
  }

  Future<bool> _confirmLeave() async {
    if (_errorMessage != null) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.colors.background,
        title: const Text('Ödemeden çıkılsın mı?'),
        content: const Text(
          'Ödeme işlemi henüz tamamlanmadı. Şimdi çıkarsanız işlem iptal edilir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Vazgeç', style: TextStyle(color: context.colors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Çık', style: TextStyle(color: buikBrand)),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  Future<void> _handlePopAttempt() async {
    final leave = await _confirmLeave();
    if (!leave) return;
    if (!mounted) return;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handlePopAttempt();
      },
      child: Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          backgroundColor: context.colors.background,
          elevation: 0,
          iconTheme: const IconThemeData(color: buikBrand),
          title: const Text('ÖDEME', style: TextStyle(color: buikBrand)),
        ),
        body: Stack(
          children: [
            if (_errorMessage == null) WebViewWidget(controller: _controller),
            if (_isLoading)
              const Center(child: CircularProgressIndicator(color: buikBrand)),
            if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_off_rounded, size: 48, color: context.colors.mutedLight),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: context.colors.muted),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _retry,
                        style: ElevatedButton.styleFrom(backgroundColor: buikBrand),
                        child: const Text('Tekrar Dene'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
