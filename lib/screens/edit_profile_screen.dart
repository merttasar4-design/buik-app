import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../theme/colors.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.initialData});

  final Map<String, dynamic> initialData;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final _fullNameController = TextEditingController(
    text: widget.initialData['full_name'] as String? ?? '',
  );
  late final _phoneController = TextEditingController(
    text: widget.initialData['phone'] as String? ?? '',
  );
  late final _departmentController = TextEditingController(
    text: widget.initialData['department'] as String? ?? '',
  );
  late final _classYearController = TextEditingController(
    text: widget.initialData['class_year'] as String? ?? '',
  );

  String? _avatarUrl;
  File? _pickedImage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _avatarUrl = widget.initialData['avatar_url'] as String?;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _departmentController.dispose();
    _classYearController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _pickedImage = File(picked.path));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fotoğraf seçilemedi. Lütfen tekrar deneyin.')));
    }
  }

  Future<void> _save() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    if (_fullNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ad Soyad alanı boş bırakılamaz.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      String? avatarUrl = _avatarUrl;
      if (_pickedImage != null) {
        final path = '${user.id}/avatar.jpg';
        await supabase.storage
            .from('avatars')
            .upload(
              path,
              _pickedImage!,
              fileOptions: const FileOptions(upsert: true),
            );
        avatarUrl =
            '${supabase.storage.from('avatars').getPublicUrl(path)}?t=${DateTime.now().millisecondsSinceEpoch}';
      }

      await supabase
          .from('profiles')
          .update({
            'full_name': _fullNameController.text.trim(),
            'phone': _phoneController.text.trim(),
            'department': _departmentController.text.trim(),
            'class_year': _classYearController.text.trim(),
            'avatar_url': ?avatarUrl,
          })
          .eq('id', user.id);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kaydedilemedi. Lütfen tekrar deneyin.')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Profili Düzenle',
          style: TextStyle(color: buikBrand, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: buikBrand),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: context.colors.brandSoft,
                      backgroundImage: _pickedImage != null
                          ? FileImage(_pickedImage!)
                          : (_avatarUrl != null
                                ? NetworkImage(_avatarUrl!)
                                : null),
                      child: _pickedImage == null && _avatarUrl == null
                          ? const Icon(
                              Icons.person,
                              size: 48,
                              color: buikBrand,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: buikBrand,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          _field('Ad Soyad', _fullNameController),
          const SizedBox(height: 16),
          _field(
            'Telefon',
            _phoneController,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          _field('Bölüm', _departmentController),
          if (widget.initialData['role'] != 'mezun') ...[
            const SizedBox(height: 16),
            _field('Sınıf', _classYearController),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: buikBrand,
                foregroundColor: Colors.white,
              ),
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'KAYDET',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: context.colors.ink),
      decoration: InputDecoration(
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
      ),
    );
  }
}
