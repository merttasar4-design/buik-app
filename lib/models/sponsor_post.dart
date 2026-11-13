class SponsorPost {
  final int id;
  final int? sponsorId;
  final String sponsorName;
  final String? sponsorLogoUrl;
  final String content;
  final String? imageUrl;
  final String? linkUrl;
  final String? linkLabel;
  final DateTime createdAt;

  const SponsorPost({
    required this.id,
    required this.sponsorId,
    required this.sponsorName,
    this.sponsorLogoUrl,
    required this.content,
    this.imageUrl,
    this.linkUrl,
    this.linkLabel,
    required this.createdAt,
  });

  factory SponsorPost.fromMap(Map<String, dynamic> map) {
    final sponsor = map['sponsors'] as Map?;
    return SponsorPost(
      id: map['id'] as int,
      sponsorId: map['sponsor_id'] as int?,
      sponsorName: sponsor?['name'] as String? ?? 'Sponsor',
      sponsorLogoUrl: sponsor?['logo_url'] as String?,
      content: map['content'] as String,
      imageUrl: map['image_url'] as String?,
      linkUrl: map['link_url'] as String?,
      linkLabel: map['link_label'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
