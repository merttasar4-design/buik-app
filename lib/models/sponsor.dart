class Sponsor {
  final int id;
  final String name;
  final String? logoUrl;
  final String? description;
  final String? websiteUrl;

  const Sponsor({
    required this.id,
    required this.name,
    this.logoUrl,
    this.description,
    this.websiteUrl,
  });

  factory Sponsor.fromMap(Map<String, dynamic> map) {
    return Sponsor(
      id: map['id'] as int,
      name: map['name'] as String,
      logoUrl: map['logo_url'] as String?,
      description: map['description'] as String?,
      websiteUrl: map['website_url'] as String?,
    );
  }
}
