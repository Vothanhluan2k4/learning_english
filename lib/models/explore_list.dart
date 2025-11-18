class ExploreList {
  final String? id;
  final String title;
  final String? description;
  final DateTime? createdAt;
  final int? followersCount;

  ExploreList({
    this.id,
    required this.title,
    this.description,
    this.createdAt,
    this.followersCount,
  });

  factory ExploreList.fromJson(Map<String, dynamic> json) {
    return ExploreList(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      followersCount: json['followers_count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      if (description != null) 'description': description,
      'followers_count': followersCount,
    };
  }
}
