import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../theme/colors.dart';
import '../theme/ui.dart';
import 'main_shell.dart';
import 'mezun_shell.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    if (password.length < 6) {
      _showMessage('Şifre en az 6 karakter olmalı.');
      return;
    }
    if (password != confirm) {
      _showMessage('Şifreler eşleşmiyor.');
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await supabase.auth.updateUser(UserAttributes(password: password));
      if (!mounted) return;
      final role = await fetchMyRole();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              isMezunRole(role) ? const MezunShell() : const MainShell(),
        ),
        (_) => false,
      );
    } on AuthException catch (e) {
      _showMessage(translateAuthError(e.message));
    } catch (e) {
      _showMessage('Bir hata oluştu. Lütfen tekrar deneyin.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: buikBrand),
        title: const Text(
          'YENİ ŞİFRE BELİRLE',
          style: TextStyle(
            color: buikBrand,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            fontSize: 16,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BuikFadeIn(
              child: Icon(Icons.lock_reset, color: buikBrand, size: 40),
            ),
            const SizedBox(height: 24),
            BuikFadeIn(
              delay: const Duration(milliseconds: 80),
              child: TextField(
                controller: _passwordController,
                obscureText: _obscure1,
                style: TextStyle(color: context.colors.ink),
                decoration: _inputDecoration('Yeni Şifre').copyWith(
                  suffixIcon: IconButton(
                    tooltip: _obscure1 ? 'Şifreyi göster' : 'Şifreyi gizle',
                    icon: Icon(
                      _obscure1 ? Icons.visibility_off : Icons.visibility,
                      color: buikBrand,
                    ),
                    onPressed: () => setState(() => _obscure1 = !_obscure1),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            BuikFadeIn(
              delay: const Duration(milliseconds: 130),
              child: TextField(
                controller: _confirmController,
                obscureText: _obscure2,
                style: TextStyle(color: context.colors.ink),
                decoration: _inputDecoration('Şifreyi Onayla').copyWith(
                  suffixIcon: IconButton(
                    tooltip: _obscure2 ? 'Şifreyi göster' : 'Şifreyi gizle',
                    icon: Icon(
                      _obscure2 ? Icons.visibility_off : Icons.visibility,
                      color: buikBrand,
                    ),
                    onPressed: () => setState(() => _obscure2 = !_obscure2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            BuikFadeIn(
              delay: const Duration(milliseconds: 180),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buikBrand,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'ŞİFREYİ GÜNCELLE',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: context.colors.muted),
      filled: true,
      fillColor: context.colors.brandSoft,
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
