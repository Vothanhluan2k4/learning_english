class PlacementTestArgs {
  final String testId;
  final String? groupId; // Thay đổi từ final String sang final String?

  PlacementTestArgs({
    required this.testId,
    this.groupId, // Bỏ 'required'
  });
  // ...
  // Cập nhật toMap và fromMap để xử lý null:
  Map<String, dynamic> toMap() {
    return {
      'testId': testId,
      'groupId': groupId, // Không cần kiểm tra null ở đây
    };
  }
  factory PlacementTestArgs.fromMap(Map<String, dynamic> map) {
    return PlacementTestArgs(
      testId: map['testId'] ?? '',
      groupId: map['groupId'], // Lấy trực tiếp, chấp nhận null
    );
  }
}