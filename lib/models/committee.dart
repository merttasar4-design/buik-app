class Committee {
  final int id;
  final String name;
  final String? whatsappLink;

  const Committee({required this.id, required this.name, this.whatsappLink});

  factory Committee.fromMap(Map<String, dynamic> map) {
    return Committee(
      id: map['id'] as int,
      name: map['name'] as String,
      whatsappLink: map['whatsapp_link'] as String?,
    );
  }
}
