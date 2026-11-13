import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/sponsor.dart';
import '../models/sponsor_post.dart';
import '../services/supabase_service.dart';
import '../theme/colors.dart';
import '../theme/ui.dart';

class SponsorsScreen extends StatefulWidget {
  const SponsorsScreen({super.key});

  @override
  State<SponsorsScreen> createState() => _SponsorsScreenState();
}

class _SponsorsScreenState extends State<SponsorsScreen> {
  late Future<_SponsorsData> _dataFuture;
  bool _canManage = false;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await fetchMyRole();
    if (mounted) setState(() => _canManage = isBoardRole(role));
  }

  Future<_SponsorsData> _load() async {
    final sponsorRows = await supabase
        .from('sponsors')
        .select()
        .order('sort_order', ascending: true);
    final postRows = await supabase
        .from('sponsor_posts')
        .select('*, sponsors(name, logo_url)')
        .order('created_at', ascending: false);
    return _SponsorsData(
      sponsors: sponsorRows.map((r) => Sponsor.fromMap(r)).toList(),
      posts: postRows.map((r) => SponsorPost.fromMap(r)).toList(),
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _dataFuture = _load();
    });
    await _dataFuture;
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _deleteSponsor(Sponsor sponsor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = context.colors;
        return AlertDialog(
          backgroundColor: colors.background,
          title: Text('Sponsoru Sil', style: TextStyle(color: colors.ink)),
          content: Text(
            '"${sponsor.name}" silinsin mi?',
            style: TextStyle(color: colors.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Vazgeç', style: TextStyle(color: colors.muted)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    try {
      await supabase.from('sponsors').delete().eq('id', sponsor.id);
      await _refresh();
    } catch (e) {
      _showMessage('Silinemedi. Lütfen tekrar deneyin.');
    }
  }

  Future<void> _deletePost(SponsorPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = context.colors;
        return AlertDialog(
          backgroundColor: colors.background,
          title: Text('Gönderiyi Sil', style: TextStyle(color: colors.ink)),
          content: Text(
            'Bu gönderiyi silmek istediğinize emin misiniz?',
            style: TextStyle(color: colors.muted),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Vazgeç', style: TextStyle(color: colors.muted)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    try {
      if (post.imageUrl != null && post.imageUrl!.isNotEmpty) {
        final marker = '/sponsor-posts/';
        final index = post.imageUrl!.indexOf(marker);
        if (index != -1) {
          final path = post.imageUrl!.substring(index + marker.length);
          await supabase.storage.from('sponsor-posts').remove([path]);
        }
      }
      await supabase.from('sponsor_posts').delete().eq('id', post.id);
      await _refresh();
    } catch (e) {
      _showMessage('Silinemedi. Lütfen tekrar deneyin.');
    }
  }

  Future<String?> _uploadSponsorLogo(int sponsorId, File image) async {
    final path = 'logos/$sponsorId.jpg';
    await supabase.storage
        .from('sponsor-posts')
        .upload(path, image, fileOptions: const FileOptions(upsert: true));
    return '${supabase.storage.from('sponsor-posts').getPublicUrl(path)}'
        '?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _editSponsor(Sponsor sponsor) async {
    final nameController = TextEditingController(text: sponsor.name);
    final descController = TextEditingController(text: sponsor.description ?? '');
    final urlController = TextEditingController(text: sponsor.websiteUrl ?? '');
    File? pickedLogo;
    bool isSubmitting = false;
    String? errorText;
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = context.colors;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: colors.background,
            title: Text('Sponsoru Düzenle', style: TextStyle(color: colors.ink)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 800,
                          imageQuality: 85,
                        );
                        if (picked != null) {
                          setDialogState(() => pickedLogo = File(picked.path));
                        }
                      },
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: buikBrand.withValues(alpha: 0.15),
                        backgroundImage: pickedLogo != null
                            ? FileImage(pickedLogo!)
                            : (sponsor.logoUrl != null && sponsor.logoUrl!.isNotEmpty
                                  ? NetworkImage(sponsor.logoUrl!)
                                  : null),
                        child:
                            pickedLogo == null &&
                                (sponsor.logoUrl == null || sponsor.logoUrl!.isEmpty)
                            ? const Icon(Icons.add_a_photo_outlined, color: buikBrand)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: colors.ink),
                    decoration: InputDecoration(
                      labelText: 'Sponsor adı',
                      labelStyle: TextStyle(color: colors.muted),
                    ),
                  ),
                  TextField(
                    controller: descController,
                    style: TextStyle(color: colors.ink),
                    decoration: InputDecoration(
                      labelText: 'Açıklama',
                      labelStyle: TextStyle(color: colors.muted),
                    ),
                  ),
                  TextField(
                    controller: urlController,
                    style: TextStyle(color: colors.ink),
                    decoration: InputDecoration(
                      labelText: 'Website (https://...)',
                      labelStyle: TextStyle(color: colors.muted),
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
                        if (nameController.text.trim().isEmpty) {
                          setDialogState(
                            () => errorText = 'Sponsor adı zorunludur.',
                          );
                          return;
                        }
                        setDialogState(() {
                          errorText = null;
                          isSubmitting = true;
                        });
                        try {
                          String? logoUrl;
                          if (pickedLogo != null) {
                            logoUrl = await _uploadSponsorLogo(
                              sponsor.id,
                              pickedLogo!,
                            );
                          }
                          await supabase
                              .from('sponsors')
                              .update({
                                'name': nameController.text.trim(),
                                'description': descController.text.trim(),
                                'website_url': urlController.text.trim(),
                                'logo_url': ?logoUrl,
                              })
                              .eq('id', sponsor.id);
                          if (!context.mounted) return;
                          Navigator.of(context).pop(true);
                        } catch (e) {
                          if (!context.mounted) return;
                          setDialogState(() {
                            isSubmitting = false;
                            errorText = 'Kaydedilemedi. Lütfen tekrar deneyin.';
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
                    : const Text('Kaydet', style: TextStyle(color: buikBrand)),
              ),
            ],
          ),
        );
      },
    );
    if (updated == true) _refresh();
  }

  Future<void> _showSponsorActions(Sponsor sponsor) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.colors.background,
      builder: (context) {
        final colors = context.colors;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: buikBrand),
                title: Text('Düzenle', style: TextStyle(color: colors.ink)),
                onTap: () => Navigator.of(context).pop('edit'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
                onTap: () => Navigator.of(context).pop('delete'),
              ),
            ],
          ),
        );
      },
    );
    if (action == 'edit') {
      await _editSponsor(sponsor);
    } else if (action == 'delete') {
      await _deleteSponsor(sponsor);
    }
  }

  Future<void> _addSponsor() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final urlController = TextEditingController();
    File? pickedLogo;
    bool isSubmitting = false;
    String? errorText;
    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = context.colors;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: colors.background,
            title: Text('Yeni Sponsor', style: TextStyle(color: colors.ink)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        final picked = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 800,
                          imageQuality: 85,
                        );
                        if (picked != null) {
                          setDialogState(() => pickedLogo = File(picked.path));
                        }
                      },
                      child: CircleAvatar(
                        radius: 32,
                        backgroundColor: buikBrand.withValues(alpha: 0.15),
                        backgroundImage: pickedLogo != null
                            ? FileImage(pickedLogo!)
                            : null,
                        child: pickedLogo == null
                            ? const Icon(Icons.add_a_photo_outlined, color: buikBrand)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    style: TextStyle(color: colors.ink),
                    decoration: InputDecoration(
                      labelText: 'Sponsor adı',
                      labelStyle: TextStyle(color: colors.muted),
                    ),
                  ),
                  TextField(
                    controller: descController,
                    style: TextStyle(color: colors.ink),
                    decoration: InputDecoration(
                      labelText: 'Açıklama',
                      labelStyle: TextStyle(color: colors.muted),
                    ),
                  ),
                  TextField(
                    controller: urlController,
                    style: TextStyle(color: colors.ink),
                    decoration: InputDecoration(
                      labelText: 'Website (https://...)',
                      labelStyle: TextStyle(color: colors.muted),
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
                        if (nameController.text.trim().isEmpty) {
                          setDialogState(
                            () => errorText = 'Sponsor adı zorunludur.',
                          );
                          return;
                        }
                        setDialogState(() {
                          errorText = null;
                          isSubmitting = true;
                        });
                        try {
                          final inserted = await supabase
                              .from('sponsors')
                              .insert({
                                'name': nameController.text.trim(),
                                'description': descController.text.trim(),
                                'website_url': urlController.text.trim(),
                              })
                              .select()
                              .single();
                          if (pickedLogo != null) {
                            final logoUrl = await _uploadSponsorLogo(
                              inserted['id'] as int,
                              pickedLogo!,
                            );
                            await supabase
                                .from('sponsors')
                                .update({'logo_url': logoUrl})
                                .eq('id', inserted['id'] as int);
                          }
                          if (!context.mounted) return;
                          Navigator.of(context).pop(true);
                        } catch (e) {
                          if (!context.mounted) return;
                          setDialogState(() {
                            isSubmitting = false;
                            errorText = 'Eklenemedi. Lütfen tekrar deneyin.';
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
                    : const Text('Ekle', style: TextStyle(color: buikBrand)),
              ),
            ],
          ),
        );
      },
    );
    if (created == true) _refresh();
  }

  Future<void> _addPost(List<Sponsor> sponsors) async {
    if (sponsors.isEmpty) {
      _showMessage('Önce bir sponsor eklemelisiniz.');
      return;
    }
    Sponsor selectedSponsor = sponsors.first;
    File? pickedImage;
    final contentController = TextEditingController();
    final linkController = TextEditingController();
    final linkLabelController = TextEditingController();
    bool isSubmitting = false;
    String? errorText;

    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = context.colors;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: colors.background,
            title: Text(
              'Yeni Gönderi',
              style: TextStyle(color: colors.ink),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Sponsor>(
                    initialValue: selectedSponsor,
                    dropdownColor: colors.background,
                    style: TextStyle(color: colors.ink),
                    items: sponsors
                        .map(
                          (s) => DropdownMenuItem(value: s, child: Text(s.name)),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedSponsor = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: contentController,
                    maxLines: 3,
                    style: TextStyle(color: colors.ink),
                    decoration: InputDecoration(
                      labelText: 'İçerik',
                      labelStyle: TextStyle(color: colors.muted),
                    ),
                  ),
                  TextField(
                    controller: linkController,
                    style: TextStyle(color: colors.ink),
                    decoration: InputDecoration(
                      labelText: 'Link (opsiyonel, https://...)',
                      labelStyle: TextStyle(color: colors.muted),
                    ),
                  ),
                  TextField(
                    controller: linkLabelController,
                    style: TextStyle(color: colors.ink),
                    decoration: InputDecoration(
                      labelText: 'Buton metni (örn. Başvur)',
                      labelStyle: TextStyle(color: colors.muted),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1600,
                        imageQuality: 85,
                      );
                      if (picked != null) {
                        setDialogState(() => pickedImage = File(picked.path));
                      }
                    },
                    icon: const Icon(Icons.image, color: buikBrand),
                    label: Text(
                      pickedImage == null ? 'Görsel Ekle (opsiyonel)' : 'Görsel Seçildi',
                      style: const TextStyle(color: buikBrand),
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
                        if (contentController.text.trim().isEmpty) {
                          setDialogState(
                            () => errorText = 'İçerik zorunludur.',
                          );
                          return;
                        }
                        setDialogState(() {
                          errorText = null;
                          isSubmitting = true;
                        });
                        try {
                          String? imageUrl;
                          if (pickedImage != null) {
                            final path =
                                '${selectedSponsor.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
                            await supabase.storage
                                .from('sponsor-posts')
                                .upload(
                                  path,
                                  pickedImage!,
                                  fileOptions: const FileOptions(upsert: true),
                                );
                            imageUrl = supabase.storage
                                .from('sponsor-posts')
                                .getPublicUrl(path);
                          }
                          await supabase.from('sponsor_posts').insert({
                            'sponsor_id': selectedSponsor.id,
                            'content': contentController.text.trim(),
                            'image_url': imageUrl,
                            'link_url': linkController.text.trim().isEmpty
                                ? null
                                : linkController.text.trim(),
                            'link_label': linkLabelController.text.trim().isEmpty
                                ? null
                                : linkLabelController.text.trim(),
                          });
                          if (!context.mounted) return;
                          Navigator.of(context).pop(true);
                        } catch (e) {
                          if (!context.mounted) return;
                          setDialogState(() {
                            isSubmitting = false;
                            errorText = 'Paylaşılamadı. Lütfen tekrar deneyin.';
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
                    : const Text('Paylaş', style: TextStyle(color: buikBrand)),
              ),
            ],
          ),
        );
      },
    );
    if (created == true) _refresh();
  }

  Future<void> _editPost(SponsorPost post, List<Sponsor> sponsors) async {
    Sponsor selectedSponsor = sponsors.firstWhere(
      (s) => s.id == post.sponsorId,
      orElse: () => sponsors.first,
    );
    File? pickedImage;
    final contentController = TextEditingController(text: post.content);
    final linkController = TextEditingController(text: post.linkUrl ?? '');
    final linkLabelController = TextEditingController(text: post.linkLabel ?? '');
    bool isSubmitting = false;
    String? errorText;

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = context.colors;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: colors.background,
            title: Text('Gönderiyi Düzenle', style: TextStyle(color: colors.ink)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Sponsor>(
                    initialValue: selectedSponsor,
                    dropdownColor: colors.background,
                    style: TextStyle(color: colors.ink),
                    items: sponsors
                        .map(
                          (s) => DropdownMenuItem(value: s, child: Text(s.name)),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => selectedSponsor = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: contentController,
                    maxLines: 3,
                    style: TextStyle(color: colors.ink),
                    decoration: InputDecoration(
                      labelText: 'İçerik',
                      labelStyle: TextStyle(color: colors.muted),
                    ),
                  ),
                  TextField(
                    controller: linkController,
                    style: TextStyle(color: colors.ink),
                    decoration: InputDecoration(
                      labelText: 'Link (opsiyonel, https://...)',
                      labelStyle: TextStyle(color: colors.muted),
                    ),
                  ),
                  TextField(
                    controller: linkLabelController,
                    style: TextStyle(color: colors.ink),
                    decoration: InputDecoration(
                      labelText: 'Buton metni (örn. Başvur)',
                      labelStyle: TextStyle(color: colors.muted),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1600,
                        imageQuality: 85,
                      );
                      if (picked != null) {
                        setDialogState(() => pickedImage = File(picked.path));
                      }
                    },
                    icon: const Icon(Icons.image, color: buikBrand),
                    label: Text(
                      pickedImage == null
                          ? 'Görseli Değiştir (opsiyonel)'
                          : 'Yeni Görsel Seçildi',
                      style: const TextStyle(color: buikBrand),
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
                        if (contentController.text.trim().isEmpty) {
                          setDialogState(
                            () => errorText = 'İçerik zorunludur.',
                          );
                          return;
                        }
                        setDialogState(() {
                          errorText = null;
                          isSubmitting = true;
                        });
                        try {
                          String? imageUrl = post.imageUrl;
                          if (pickedImage != null) {
                            final path =
                                '${selectedSponsor.id}/${DateTime.now().millisecondsSinceEpoch}.jpg';
                            await supabase.storage
                                .from('sponsor-posts')
                                .upload(
                                  path,
                                  pickedImage!,
                                  fileOptions: const FileOptions(upsert: true),
                                );
                            imageUrl = supabase.storage
                                .from('sponsor-posts')
                                .getPublicUrl(path);
                          }
                          await supabase.from('sponsor_posts').update({
                            'sponsor_id': selectedSponsor.id,
                            'content': contentController.text.trim(),
                            'image_url': imageUrl,
                            'link_url': linkController.text.trim().isEmpty
                                ? null
                                : linkController.text.trim(),
                            'link_label': linkLabelController.text.trim().isEmpty
                                ? null
                                : linkLabelController.text.trim(),
                          }).eq('id', post.id);
                          if (!context.mounted) return;
                          Navigator.of(context).pop(true);
                        } catch (e) {
                          if (!context.mounted) return;
                          setDialogState(() {
                            isSubmitting = false;
                            errorText = 'Kaydedilemedi. Lütfen tekrar deneyin.';
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
                    : const Text('Kaydet', style: TextStyle(color: buikBrand)),
              ),
            ],
          ),
        );
      },
    );
    if (updated == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SPONSORLAR',
          style: TextStyle(
            color: buikBrand,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: buikBrand,
        onRefresh: _refresh,
        child: FutureBuilder<_SponsorsData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: buikBrand),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Yüklenemedi. Lütfen tekrar deneyin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.muted),
                ),
              );
            }
            final colors = context.colors;
            final data = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sponsorlarımız',
                      style: TextStyle(
                        color: colors.ink,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (_canManage)
                      IconButton(
                        tooltip: 'Sponsor Ekle',
                        icon: const Icon(Icons.add_circle, color: buikBrand),
                        onPressed: _addSponsor,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (data.sponsors.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.business_outlined, size: 18, color: colors.faint),
                        const SizedBox(width: 8),
                        Text(
                          'Henüz sponsor eklenmedi.',
                          style: TextStyle(color: colors.mutedLight, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    height: 88,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: data.sponsors.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final s = data.sponsors[index];
                        return GestureDetector(
                          onTap: () => _openUrl(s.websiteUrl),
                          onLongPress: _canManage
                              ? () => _showSponsorActions(s)
                              : null,
                          child: Column(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: buikBrand.withValues(alpha: 0.15),
                                backgroundImage:
                                    s.logoUrl != null && s.logoUrl!.isNotEmpty
                                    ? NetworkImage(s.logoUrl!)
                                    : null,
                                child: s.logoUrl == null || s.logoUrl!.isEmpty
                                    ? const Icon(Icons.business, color: buikBrand)
                                    : null,
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                width: 64,
                                child: Text(
                                  s.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'İlanlar & Duyurular',
                      style: TextStyle(
                        color: colors.ink,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (_canManage)
                      IconButton(
                        tooltip: 'Gönderi Ekle',
                        icon: const Icon(Icons.add_circle, color: buikBrand),
                        onPressed: () => _addPost(data.sponsors),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (data.posts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.campaign_outlined, size: 18, color: colors.faint),
                        const SizedBox(width: 8),
                        Text(
                          'Henüz gönderi yok.',
                          style: TextStyle(color: colors.mutedLight, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                else
                  ...data.posts.asMap().entries.map(
                    (entry) => BuikFadeIn(
                      delay: Duration(milliseconds: 40 * entry.key),
                      child: _PostCard(
                        post: entry.value,
                        onLinkTap: () => _openUrl(entry.value.linkUrl),
                        onEdit: _canManage
                            ? () => _editPost(entry.value, data.sponsors)
                            : null,
                        onDelete: _canManage
                            ? () => _deletePost(entry.value)
                            : null,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.onLinkTap,
    this.onEdit,
    this.onDelete,
  });

  final SponsorPost post;
  final VoidCallback onLinkTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: buikCardDecoration(context, color: colors.brandSoft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: buikBrand.withValues(alpha: 0.15),
                backgroundImage:
                    post.sponsorLogoUrl != null && post.sponsorLogoUrl!.isNotEmpty
                    ? NetworkImage(post.sponsorLogoUrl!)
                    : null,
                child: post.sponsorLogoUrl == null || post.sponsorLogoUrl!.isEmpty
                    ? const Icon(Icons.business, color: buikBrand, size: 18)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.sponsorName,
                      style: TextStyle(
                        color: colors.ink,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      _formatDate(post.createdAt),
                      style: TextStyle(color: colors.mutedLight, fontSize: 11),
                    ),
                  ],
                ),
              ),
              if (onEdit != null)
                IconButton(
                  tooltip: 'Düzenle',
                  icon: Icon(
                    Icons.edit_outlined,
                    color: colors.mutedLight,
                    size: 20,
                  ),
                  onPressed: onEdit,
                ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Sil',
                  icon: Icon(
                    Icons.delete_outline,
                    color: colors.mutedLight,
                    size: 20,
                  ),
                  onPressed: onDelete,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post.content,
            style: TextStyle(color: colors.ink, fontSize: 14),
          ),
          if (post.imageUrl != null && post.imageUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(post.imageUrl!, fit: BoxFit.cover),
            ),
          ],
          if (post.linkUrl != null && post.linkUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: buikBrand),
                ),
                onPressed: onLinkTap,
                child: Text(
                  post.linkLabel?.isNotEmpty == true
                      ? post.linkLabel!
                      : 'İncele',
                  style: const TextStyle(color: buikBrand, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class _SponsorsData {
  final List<Sponsor> sponsors;
  final List<SponsorPost> posts;

  const _SponsorsData({required this.sponsors, required this.posts});
}
