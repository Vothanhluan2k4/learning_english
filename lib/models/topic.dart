class Topic {
  final String id;
  final String topicNameVi;
  final String topicNameEn;
  final String description;
  final DateTime createdAt;

  Topic({
    required this.id,
    required this.topicNameVi,
    required this.topicNameEn,
    required this.description,
    required this.createdAt,
  });

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'],
      topicNameVi: json['topic_name_vi'],
      topicNameEn: json['topic_name_en'],
      description: json['description'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'topic_name_vi': topicNameVi,
      'topic_name_en': topicNameEn,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }
}