class GalleryPhoto {
  final int id;
  final String photoUrl;
  final String? caption;
  final String? storagePath;

  const GalleryPhoto({
    required this.id,
    required this.photoUrl,
    this.caption,
    this.storagePath,
  });

  factory GalleryPhoto.fromMap(Map<String, dynamic> map) {
    return GalleryPhoto(
      id: map['id'] as int,
      photoUrl: map['photo_url'] as String,
      caption: map['caption'] as String?,
      storagePath: map['storage_path'] as String?,
    );
  }
}
