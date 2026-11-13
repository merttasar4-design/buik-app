import 'package:flutter/material.dart';

import '../models/announcement.dart';
import '../services/supabase_service.dart';
import '../theme/colors.dart';
import '../theme/ui.dart';
import '../widgets/secondary_menu_drawer.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  late Future<List<Announcement>> _announcementsFuture;
  bool _canPost = false;
  bool _canManage = false;

  @override
  void initState() {
    super.initState();
    _announcementsFuture = _load();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await fetchMyRole();
    if (mounted) {
      setState(() {
        _canPost = isCoordinatorRole(role);
        _canManage = isBoardRole(role);
      });
    }
  }

  Future<List<Announcement>> _load() async {
    final rows = await supabase
        .from('announcements')
        .select()
        .order('created_at', ascending: false);
    return rows.map((row) => Announcement.fromMap(row)).toList();
  }

  Future<void> _refresh() async {
    setState(() {
      _announcementsFuture = _load();
    });
    await _announcementsFuture;
  }

  Future<void> _openCreateDialog() async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    bool isSubmitting = false;
    String? errorText;
    final created = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = context.colors;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: colors.background,
            title: Text('Yeni Duyuru', style: TextStyle(color: colors.ink)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: TextStyle(color: colors.ink),
                  decoration: InputDecoration(
                    labelText: 'Başlık',
                    labelStyle: TextStyle(color: colors.muted),
                  ),
                ),
                TextField(
                  controller: bodyController,
                  maxLines: 4,
                  style: TextStyle(color: colors.ink),
                  decoration: InputDecoration(
                    labelText: 'İçerik',
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
                        if (titleController.text.trim().isEmpty ||
                            bodyController.text.trim().isEmpty) {
                          setDialogState(
                            () => errorText = 'Başlık ve içerik zorunludur.',
                          );
                          return;
                        }
                        setDialogState(() {
                          errorText = null;
                          isSubmitting = true;
                        });
                        try {
                          await supabase.from('announcements').insert({
                            'title': titleController.text.trim(),
                            'body': bodyController.text.trim(),
                          });
                          if (!context.mounted) return;
                          Navigator.of(context).pop(true);
                        } catch (e) {
                          if (!context.mounted) return;
                          setDialogState(() {
                            isSubmitting = false;
                            errorText = 'Yayınlanamadı. Lütfen tekrar deneyin.';
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
                    : const Text('Yayınla', style: TextStyle(color: buikBrand)),
              ),
            ],
          ),
        );
      },
    );
    if (created == true) {
      await _refresh();
    }
  }

  Future<void> _openEditDialog(Announcement item) async {
    final titleController = TextEditingController(text: item.title);
    final bodyController = TextEditingController(text: item.body);
    bool isSubmitting = false;
    String? errorText;
    final updated = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = context.colors;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor: colors.background,
            title: Text('Duyuruyu Düzenle', style: TextStyle(color: colors.ink)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  style: TextStyle(color: colors.ink),
                  decoration: InputDecoration(
                    labelText: 'Başlık',
                    labelStyle: TextStyle(color: colors.muted),
                  ),
                ),
                TextField(
                  controller: bodyController,
                  maxLines: 4,
                  style: TextStyle(color: colors.ink),
                  decoration: InputDecoration(
                    labelText: 'İçerik',
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
                        if (titleController.text.trim().isEmpty ||
                            bodyController.text.trim().isEmpty) {
                          setDialogState(
                            () => errorText = 'Başlık ve içerik zorunludur.',
                          );
                          return;
                        }
                        setDialogState(() {
                          errorText = null;
                          isSubmitting = true;
                        });
                        try {
                          await supabase.from('announcements').update({
                            'title': titleController.text.trim(),
                            'body': bodyController.text.trim(),
                          }).eq('id', item.id);
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
    if (updated == true) {
      await _refresh();
    }
  }

  Future<void> _deleteAnnouncement(Announcement item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colors = context.colors;
        return AlertDialog(
          backgroundColor: colors.background,
          title: Text('Duyuruyu Sil', style: TextStyle(color: colors.ink)),
          content: Text(
            '"${item.title}" silinsin mi?',
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
      await supabase.from('announcements').delete().eq('id', item.id);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Silinemedi. Lütfen tekrar deneyin.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const SecondaryMenuDrawer(),
      appBar: AppBar(
        title: const Text(
          'DUYURULAR',
          style: TextStyle(
            color: buikBrand,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
      ),
      floatingActionButton: _canPost
          ? FloatingActionButton(
              heroTag: 'announcementsAdd',
              tooltip: 'Yeni Duyuru',
              backgroundColor: buikBrand,
              foregroundColor: Colors.white,
              onPressed: _openCreateDialog,
              child: const Icon(Icons.add),
            )
          : null,
      body: RefreshIndicator(
        color: buikBrand,
        onRefresh: _refresh,
        child: FutureBuilder<List<Announcement>>(
          future: _announcementsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: buikBrand),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Duyurular yüklenemedi. Lütfen tekrar deneyin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.muted),
                ),
              );
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return const BuikEmptyState(
                icon: Icons.campaign_outlined,
                message: 'Henüz duyuru yok.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => BuikFadeIn(
                delay: Duration(milliseconds: 40 * index),
                child: _AnnouncementCard(
                  item: items[index],
                  onEdit: _canManage
                      ? () => _openEditDialog(items[index])
                      : null,
                  onDelete: _canManage
                      ? () => _deleteAnnouncement(items[index])
                      : null,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.item, this.onEdit, this.onDelete});

  final Announcement item;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: buikCardDecoration(context, color: colors.brandSoft),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.title,
                  style: TextStyle(
                    color: colors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                _formatDate(item.createdAt),
                style: TextStyle(color: colors.mutedLight, fontSize: 11),
              ),
              if (onEdit != null)
                IconButton(
                  tooltip: 'Düzenle',
                  icon: Icon(
                    Icons.edit_outlined,
                    color: colors.mutedLight,
                    size: 18,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: onEdit,
                ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Sil',
                  icon: Icon(
                    Icons.delete_outline,
                    color: colors.mutedLight,
                    size: 18,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(item.body, style: TextStyle(color: colors.muted)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
}
