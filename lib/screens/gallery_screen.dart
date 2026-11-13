import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/gallery_photo.dart';
import '../services/supabase_service.dart';
import '../theme/colors.dart';
import '../theme/ui.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  late Future<List<GalleryPhoto>> _photosFuture;
  bool _canManage = false;
  bool _isUploading = false;
  int _uploadTotal = 0;
  int _uploadDone = 0;
  bool _selectionMode = false;
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _photosFuture = _loadPhotos();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await fetchMyRole();
    if (mounted) setState(() => _canManage = isBoardRole(role));
  }

  Future<List<GalleryPhoto>> _loadPhotos() async {
    final rows = await supabase
        .from('gallery_photos')
        .select()
        .order('created_at', ascending: false);
    return rows.map((r) => GalleryPhoto.fromMap(r)).toList();
  }

  Future<void> _refresh() async {
    setState(() {
      _photosFuture = _loadPhotos();
    });
    await _photosFuture;
  }

  Future<void> _uploadPhoto() async {
    final List<XFile> picked;
    try {
      picked = await ImagePicker().pickMultiImage(
        maxWidth: 1600,
        imageQuality: 85,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Fotoğraf seçilemedi. Lütfen tekrar deneyin.')));
      return;
    }
    if (picked.isEmpty) return;

    setState(() {
      _isUploading = true;
      _uploadTotal = picked.length;
      _uploadDone = 0;
    });
    var failedCount = 0;
    for (final photo in picked) {
      try {
        final file = File(photo.path);
        final path =
            '${supabase.auth.currentUser!.id}/${DateTime.now().microsecondsSinceEpoch}.jpg';
        await supabase.storage
            .from('gallery')
            .upload(path, file, fileOptions: const FileOptions(upsert: true));
        final photoUrl = supabase.storage.from('gallery').getPublicUrl(path);
        await supabase.from('gallery_photos').insert({
          'photo_url': photoUrl,
          'storage_path': path,
          'uploaded_by': supabase.auth.currentUser!.id,
        });
      } catch (_) {
        failedCount++;
      }
      if (mounted) setState(() => _uploadDone++);
    }
    if (mounted) setState(() => _isUploading = false);
    await _refresh();
    if (!mounted) return;
    if (failedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$failedCount fotoğraf yüklenemedi.')),
      );
    }
  }

  void _openFullScreen(List<GalleryPhoto> photos, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            _PhotoViewerScreen(photos: photos, initialIndex: initialIndex),
      ),
    );
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(GalleryPhoto photo) {
    setState(() {
      if (_selectedIds.contains(photo.id)) {
        _selectedIds.remove(photo.id);
      } else {
        _selectedIds.add(photo.id);
      }
    });
  }

  String? _extractStoragePath(GalleryPhoto photo) {
    if (photo.storagePath != null && photo.storagePath!.isNotEmpty) {
      return photo.storagePath;
    }
    final marker = '/gallery/';
    final index = photo.photoUrl.indexOf(marker);
    if (index == -1) return null;
    return photo.photoUrl.substring(index + marker.length);
  }

  Future<void> _deleteSelected(List<GalleryPhoto> allPhotos) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.colors.background,
        title: Text(
          'Fotoğrafları Sil',
          style: TextStyle(color: context.colors.ink),
        ),
        content: Text(
          '${_selectedIds.length} fotoğrafı silmek istediğinize emin misiniz? Bu işlem geri alınamaz.',
          style: TextStyle(color: context.colors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Vazgeç', style: TextStyle(color: context.colors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final selectedPhotos = allPhotos
        .where((p) => _selectedIds.contains(p.id))
        .toList();
    final storagePaths = selectedPhotos
        .map(_extractStoragePath)
        .whereType<String>()
        .toList();

    try {
      if (storagePaths.isNotEmpty) {
        await supabase.storage.from('gallery').remove(storagePaths);
      }
      await supabase
          .from('gallery_photos')
          .delete()
          .inFilter('id', _selectedIds.toList());
      setState(() {
        _selectionMode = false;
        _selectedIds.clear();
      });
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
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          _selectionMode ? '${_selectedIds.length} seçildi' : 'GALERİ',
          style: const TextStyle(
            color: buikBrand,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        actions: _canManage
            ? [
                TextButton(
                  onPressed: _toggleSelectionMode,
                  child: Text(
                    _selectionMode ? 'İptal' : 'Seç',
                    style: const TextStyle(color: buikBrand),
                  ),
                ),
              ]
            : null,
      ),
      floatingActionButton: _canManage && !_selectionMode
          ? (_isUploading
                ? FloatingActionButton.extended(
                    heroTag: 'galleryUpload',
                    backgroundColor: buikBrand,
                    foregroundColor: Colors.white,
                    onPressed: null,
                    icon: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    label: Text('$_uploadDone/$_uploadTotal'),
                  )
                : FloatingActionButton(
                    heroTag: 'galleryUpload',
                    tooltip: 'Fotoğraf Yükle',
                    backgroundColor: buikBrand,
                    foregroundColor: Colors.white,
                    onPressed: _uploadPhoto,
                    child: const Icon(Icons.add_photo_alternate),
                  ))
          : null,
      body: RefreshIndicator(
        color: buikBrand,
        onRefresh: _refresh,
        child: FutureBuilder<List<GalleryPhoto>>(
          future: _photosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(
                child: CircularProgressIndicator(color: buikBrand),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Galeri yüklenemedi. Lütfen tekrar deneyin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.muted),
                ),
              );
            }
            final photos = snapshot.data ?? [];
            if (photos.isEmpty) {
              return const BuikEmptyState(
                icon: Icons.photo_library_outlined,
                message: 'Henüz fotoğraf yok.',
              );
            }
            return Stack(
              children: [
                GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                  ),
                  itemCount: photos.length,
                  itemBuilder: (context, index) {
                    final photo = photos[index];
                    final isSelected = _selectedIds.contains(photo.id);
                    return GestureDetector(
                      onTap: () => _selectionMode
                          ? _toggleSelected(photo)
                          : _openFullScreen(photos, index),
                      onLongPress: _canManage
                          ? () {
                              if (!_selectionMode) {
                                setState(() => _selectionMode = true);
                              }
                              _toggleSelected(photo);
                            }
                          : null,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Hero(
                              tag: 'gallery_${photo.id}',
                              child: Image.network(
                                photo.photoUrl,
                                fit: BoxFit.cover,
                                frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                  if (wasSynchronouslyLoaded) return child;
                                  return AnimatedOpacity(
                                    opacity: frame == null ? 0 : 1,
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOut,
                                    child: child,
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: context.colors.brandSoft,
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: context.colors.mutedLight,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_selectionMode)
                            Container(
                              color: isSelected
                                  ? Colors.black.withValues(alpha: 0.3)
                                  : Colors.transparent,
                            ),
                          if (_selectionMode)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: Icon(
                                isSelected
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: isSelected ? buikBrand : Colors.white70,
                                size: 22,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                if (_selectionMode && _selectedIds.isNotEmpty)
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: FloatingActionButton(
                      heroTag: 'deleteSelected',
                      tooltip: 'Seçilenleri Sil',
                      backgroundColor: Colors.redAccent,
                      onPressed: () => _deleteSelected(photos),
                      child: const Icon(Icons.delete),
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

class _PhotoViewerScreen extends StatefulWidget {
  const _PhotoViewerScreen({required this.photos, required this.initialIndex});

  final List<GalleryPhoto> photos;
  final int initialIndex;

  @override
  State<_PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<_PhotoViewerScreen> {
  late int _currentIndex;
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: Text(
          '${_currentIndex + 1} / ${widget.photos.length}',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.photos.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final photo = widget.photos[index];
              return Center(
                child: InteractiveViewer(
                  child: SizedBox.expand(
                    child: Hero(
                      tag: 'gallery_${photo.id}',
                      child: Image.network(
                        photo.photoUrl,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (_currentIndex > 0)
            Positioned(
              left: 4,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  tooltip: 'Önceki fotoğraf',
                  icon: const Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                    size: 36,
                  ),
                  onPressed: () => _goTo(_currentIndex - 1),
                ),
              ),
            ),
          if (_currentIndex < widget.photos.length - 1)
            Positioned(
              right: 4,
              top: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  tooltip: 'Sonraki fotoğraf',
                  icon: const Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 36,
                  ),
                  onPressed: () => _goTo(_currentIndex + 1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
