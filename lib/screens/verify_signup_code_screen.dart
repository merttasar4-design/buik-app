import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../theme/colors.dart';
import '../theme/ui.dart';
import 'main_shell.dart';
import 'mezun_shell.dart';

/// Kayıt sonrası gösterilen 6 haneli e-posta doğrulama kodu ekranı.
/// `{{ .Token }}` içeren mail şablonuyla eşleşir — deep link'e ihtiyaç yok.
class VerifySignupCodeScreen extends StatefulWidget {
  const VerifySignupCodeScreen({super.key, required this.email});

  final String email;

  @override
  State<VerifySignupCodeScreen> createState() =>
      _VerifySignupCodeScreenState();
}

class _VerifySignupCodeScreenState extends State<VerifySignupCodeScreen>
    with SingleTickerProviderStateMixin {
  static const _codeLength = 6;
  static const _resendCooldownSeconds = 45;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late final AnimationController _shakeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  bool _isVerifying = false;
  bool _verified = false;
  String? _errorText;
  int _resendCooldown = _resendCooldownSeconds;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
    _startResendCooldown();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _shakeController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCooldown() {
    setState(() => _resendCooldown = _resendCooldownSeconds);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _resendCooldown--);
      if (_resendCooldown <= 0) timer.cancel();
    });
  }

  void _onChanged(String value) {
    if (_isVerifying || _verified) return;
    if (_errorText != null) {
      setState(() => _errorText = null);
    } else {
      setState(() {});
    }
    if (value.length == _codeLength) _verify(value);
  }

  Future<void> _verify(String code) async {
    setState(() => _isVerifying = true);
    try {
      await supabase.auth.verifyOTP(
        type: OtpType.signup,
        email: widget.email,
        token: code,
      );
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _verified = true;
      });
      final role = await fetchMyRole();
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              isMezunRole(role) ? const MezunShell() : const MainShell(),
        ),
        (route) => false,
      );
    } on AuthException catch (e) {
      _fail(translateAuthError(e.message));
    } catch (e) {
      _fail('Bir hata oluştu. Lütfen tekrar deneyin.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isVerifying = false;
      _errorText = message;
    });
    _controller.clear();
    _shakeController.forward(from: 0);
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0) return;
    try {
      await supabase.auth.resend(type: OtpType.signup, email: widget.email);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Yeni kod gönderildi.')));
      _startResendCooldown();
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(translateAuthError(e.message))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              IconButton(
                onPressed: _verified ? null : () => Navigator.of(context).pop(),
                icon: Icon(Icons.arrow_back, color: colors.ink),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  child: _verified
                      ? _SuccessView(key: const ValueKey('success'))
                      : _buildForm(context, colors),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, BuikColors colors) {
    final digits = _controller.text;
    return Column(
      key: const ValueKey('form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        BuikFadeIn(
          child: Text(
            'E-postanı Doğrula',
            style: TextStyle(
              color: colors.ink,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 10),
        BuikFadeIn(
          delay: const Duration(milliseconds: 60),
          child: Text.rich(
            TextSpan(
              style: TextStyle(color: colors.muted, fontSize: 14, height: 1.4),
              children: [
                const TextSpan(text: 'Doğrulama kodunu '),
                TextSpan(
                  text: widget.email,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: buikBrand,
                  ),
                ),
                const TextSpan(text: ' adresine gönderdik.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        BuikFadeIn(
          delay: const Duration(milliseconds: 120),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _focusNode.requestFocus(),
            child: AnimatedBuilder(
              animation: _shakeController,
              builder: (context, child) {
                final t = _shakeController.value;
                final dx = sin(t * pi * 6) * (1 - t) * 10;
                return Transform.translate(offset: Offset(dx, 0), child: child);
              },
              child: Stack(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(_codeLength, (i) {
                      final filled = i < digits.length;
                      final active = i == digits.length && _focusNode.hasFocus;
                      return _CodeBox(
                        char: filled ? digits[i] : '',
                        active: active,
                        error: _errorText != null,
                      );
                    }),
                  ),
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.01,
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        autofocus: true,
                        enabled: !_isVerifying,
                        keyboardType: TextInputType.number,
                        maxLength: _codeLength,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: _onChanged,
                        showCursor: false,
                        style: const TextStyle(color: Colors.transparent),
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: _errorText != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text(
                    _errorText!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 20),
        if (_isVerifying)
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: buikBrand),
          ),
        const SizedBox(height: 28),
        BuikFadeIn(
          delay: const Duration(milliseconds: 160),
          child: TextButton(
            onPressed: _resendCooldown > 0 ? null : _resend,
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Text(
              _resendCooldown > 0
                  ? 'Kodu tekrar gönder ($_resendCooldown sn)'
                  : 'Kodu tekrar gönder',
              style: TextStyle(
                color: _resendCooldown > 0 ? colors.mutedLight : buikBrand,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Doğrulama kodu kutusu — boşken hafif soluk, aktifken marka renginde
/// parlayan kenarlık, hata anında kırmızı, dolunca rakam sıçrayarak beliriyor.
class _CodeBox extends StatelessWidget {
  const _CodeBox({required this.char, required this.active, required this.error});

  final String char;
  final bool active;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final filled = char.isNotEmpty;
    final borderColor = error
        ? Colors.redAccent
        : active
        ? buikBrand
        : filled
        ? buikBrand.withValues(alpha: 0.55)
        : colors.faint;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: 44,
      height: 54,
      decoration: BoxDecoration(
        color: colors.brandSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: active ? 2 : 1.4),
        boxShadow: active
            ? [
                BoxShadow(
                  color: buikBrand.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: AnimatedScale(
        scale: filled ? 1.0 : 0.6,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: filled ? 1 : 0,
          duration: const Duration(milliseconds: 160),
          child: Text(
            char,
            style: TextStyle(
              color: colors.ink,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Doğrulama başarılı olunca kısaca gösterilen, yeşil ışıltılı onay rozeti.
class _SuccessView extends StatelessWidget {
  const _SuccessView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      key: const ValueKey('success-center'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 420),
            curve: Curves.elasticOut,
            builder: (context, value, child) =>
                Transform.scale(scale: value, child: child),
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.35),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xFF22C55E),
                size: 44,
              ),
            ),
          ),
          const SizedBox(height: 24),
          BuikFadeIn(
            child: Text(
              'Doğrulandı!',
              style: TextStyle(
                color: colors.ink,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          BuikFadeIn(
            delay: const Duration(milliseconds: 80),
            child: Text(
              'E-posta adresin onaylandı.',
              style: TextStyle(color: colors.muted, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
