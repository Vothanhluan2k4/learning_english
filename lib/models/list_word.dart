class ListWord {
  final String? id;
  final String userId; // Giữ nguyên userId, dùng nó cho creatorId
  final String title;
  final String? description;

  // Thuộc tính mới cần thiết cho giao diện
  final int? wordCount;
  // Thêm một getter để gọi userId bằng tên creatorId
  String get creatorId => userId;

  const ListWord({
    this.id,
    required this.userId,
    required this.title,
    this.description,
    this.wordCount, // Thêm vào constructor
  });

  // Tạo instance từ JSON (cập nhật để bao gồm wordCount)
  factory ListWord.fromJson(Map<String, dynamic> json) {
    return ListWord(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      // GIẢ ĐỊNH: Supabase trả về 'word_count' hoặc bạn tính toán nó sau
      // Nếu bạn lấy nó từ một view/join:
      wordCount: json['word_count'] as int?,
    );
  }

  // Chuyển instance thành JSON (thường không cần gửi wordCount lên)
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'title': title,
      if (description != null) 'description': description,
    };
  }
}