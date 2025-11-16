// lib/models/list_word.dart

class ListWord {
  final String? id;
  final String userId;
  final String title;
  final String? description;
  final DateTime? createdAt;
  final int? wordCount;
  final String? backgroundColor;
  // ✨ THÊM 2 TRƯỜNG CÒN THIẾU NÀY
  final int? rememberedCount;
  final int? toReviewCount;

  const ListWord({
    this.id,
    required this.userId,
    required this.title,
    this.description,
    this.createdAt,
    this.wordCount,
    this.backgroundColor,
    // ✨ THÊM 2 TRƯỜNG VÀO CONSTRUCTOR
    this.rememberedCount,
    this.toReviewCount,
  });

  factory ListWord.fromJson(Map<String, dynamic> json) {
    return ListWord(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      description: json['description'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      wordCount: json['word_count'],
      backgroundColor: json['background_color'],
      // ✨ THÊM 2 DÒNG NÀY ĐỂ ĐỌC DỮ LIỆU TỪ SUPABASE
      rememberedCount: json['remembered_count'],
      toReviewCount: json['to_review_count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'title': title,
      if (description != null) 'description': description,
      if (backgroundColor != null) 'background_color': backgroundColor,
    };
  }
}