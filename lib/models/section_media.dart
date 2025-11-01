class SectionMedia {
  final String id;
  final String sectionId;
  final String mediaType; // image, audio, video
  final String mediaUrl;
  final String? caption;
  final int orderIndex;

  SectionMedia({
    required this.id,
    required this.sectionId,
    required this.mediaType,
    required this.mediaUrl,
    this.caption,
    required this.orderIndex,
  });

  factory SectionMedia.fromJson(Map<String, dynamic> json) {
    return SectionMedia(
      id: json['id'] as String,
      sectionId: json['section_id'] as String,
      mediaType: json['media_type'] as String? ?? 'image',
      mediaUrl: json['media_url'] as String,
      caption: json['caption'] as String?,
      orderIndex: json['order_index'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'section_id': sectionId,
    'media_type': mediaType,
    'media_url': mediaUrl,
    'caption': caption,
    'order_index': orderIndex,
  };

  @override
  String toString() =>
      'SectionMedia(id: $id, mediaType: $mediaType, mediaUrl: $mediaUrl)';
}