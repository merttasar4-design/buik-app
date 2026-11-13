import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../config/brand.dart';
import '../theme/colors.dart';
import '../theme/ui.dart';
import 'main_shell.dart';
import 'mezun_shell.dart';
import 'verify_signup_code_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isRegisterMode = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showMessage('E-posta ve şifre alanlarını doldurun.');
      return;
    }
    if (_isRegisterMode && password.length < 6) {
      _showMessage('Şifre en az 6 karakter olmalı.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (_isRegisterMode) {
        await supabase.auth.signUp(email: email, password: password);
        if (supabase.auth.currentSession == null) {
          if (!mounted) return;
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => VerifySignupCodeScreen(email: email),
            ),
          );
          return;
        }
      } else {
        await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
      if (!mounted) return;
      final role = await fetchMyRole();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              isMezunRole(role) ? const MezunShell() : const MainShell(),
        ),
      );
    } on AuthException catch (e) {
      _showMessage(translateAuthError(e.message));
    } catch (e) {
      _showMessage('Bir hata oluştu. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _forgotPassword() async {
    final emailController = TextEditingController(
      text: _emailController.text.trim(),
    );
    bool isSubmitting = false;
    String? errorText;
    final sent = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = context.colors;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: colors.background,
            title: Text(
              'Şifre Sıfırlama',
              style: TextStyle(color: colors.ink),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'E-posta adresinize şifre sıfırlama bağlantısı gönderilecek.',
                  style: TextStyle(color: colors.muted),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: colors.ink),
                  decoration: InputDecoration(
                    labelText: 'E-posta',
                    labelStyle: TextStyle(color: colors.muted),
                    filled: true,
                    fillColor: colors.brandSoft,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorText!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.of(context).pop(false),
                child: Text('Vazgeç', style: TextStyle(color: colors.muted)),
              ),
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final email = emailController.text.trim();
                        if (email.isEmpty) {
                          setDialogState(
                            () => errorText = 'E-posta alanı boş olamaz.',
                          );
                          return;
                        }
                        setDialogState(() {
                          errorText = null;
                          isSubmitting = true;
                        });
                        try {
                          await supabase.auth.resetPasswordForEmail(
                            email,
                            redirectTo: 'buik://reset-password',
                          );
                          if (!context.mounted) return;
                          Navigator.of(context).pop(true);
                        } on AuthException catch (e) {
                          setDialogState(() {
                            isSubmitting = false;
                            errorText = translateAuthError(e.message);
                          });
                        } catch (e) {
                          setDialogState(() {
                            isSubmitting = false;
                            errorText = 'Bir hata oluştu. Lütfen tekrar deneyin.';
                          });
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: buikBrand,
                        ),
                      )
                    : const Text(
                        'Gönder',
                        style: TextStyle(color: buikBrand),
                      ),
              ),
            ],
          ),
        );
      },
    );
    if (sent == true && mounted) {
      _showMessage('Şifre sıfırlama bağlantısı e-postanıza gönderildi.');
    }
  }

  void _continueAsGuest() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell()));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BuikFadeIn(
                  child: Image.asset(Brand.logoAsset, height: 96),
                ),
                const SizedBox(height: 16),
                const BuikFadeIn(
                  delay: Duration(milliseconds: 60),
                  child: Text(
                    Brand.shortName,
                    style: TextStyle(
                      color: buikBrand,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                BuikFadeIn(
                  delay: const Duration(milliseconds: 120),
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: colors.ink),
                    decoration: _inputDecoration(context, 'E-posta'),
                  ),
                ),
                const SizedBox(height: 16),
                BuikFadeIn(
                  delay: const Duration(milliseconds: 170),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: TextStyle(color: colors.ink),
                    decoration: _inputDecoration(context, 'Şifre').copyWith(
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? 'Şifreyi göster'
                            : 'Şifreyi gizle',
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: buikBrand,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                BuikFadeIn(
                  delay: const Duration(milliseconds: 220),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: buikBrand,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isSubmitting ? null : _submit,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: _isSubmitting
                            ? const SizedBox(
                                key: ValueKey('loading'),
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isRegisterMode ? 'KAYIT OL' : 'GİRİŞ YAP',
                                key: ValueKey(_isRegisterMode),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() => _isRegisterMode = !_isRegisterMode),
                  child: Text(
                    _isRegisterMode
                        ? 'Zaten hesabın var mı? Giriş yap'
                        : 'Hesabın yok mu? Kayıt ol',
                    style: const TextStyle(color: buikBrand),
                  ),
                ),
                if (!_isRegisterMode)
                  TextButton(
                    onPressed: _isSubmitting ? null : _forgotPassword,
                    child: Text(
                      'Şifremi unuttum',
                      style: TextStyle(color: colors.mutedLight),
                    ),
                  ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _isSubmitting ? null : _continueAsGuest,
                  child: Text(
                    'Giriş yapmadan devam et',
                    style: TextStyle(
                      color: colors.muted,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(BuildContext context, String label) {
    final colors = context.colors;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colors.muted),
      filled: true,
      fillColor: colors.brandSoft,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: buikBrand.withValues(alpha: 0.4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: buikBrand, width: 2),
      ),
    );
  }
}
