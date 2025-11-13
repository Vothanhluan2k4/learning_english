class ExploreWord {
  final String? id;
  final String exploreListId;
  final String word;
  final String define;
  final String? pictureUrl;
  final String? wordType;
  final String? transcription;
  final String? example;
  final String? note;
  final DateTime? createdTime;

  ExploreWord({
    this.id,
    required this.exploreListId,
    required this.word,
    required this.define,
    this.pictureUrl,
    this.wordType,
    this.transcription,
    this.example,
    this.note,
    this.createdTime,
  });

  factory ExploreWord.fromJson(Map<String, dynamic> json) {
    return ExploreWord(
      id: json['id'],
      exploreListId: json['explore_list_id'],
      word: json['word'],
      define: json['define'],
      pictureUrl: json['picture_url'],
      wordType: json['word_type'],
      transcription: json['transcription'],
      example: json['example'],
      note: json['note'],
      createdTime: json['created_time'] != null ? DateTime.parse(json['created_time']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'explore_list_id': exploreListId,
      'word': word,
      'define': define,
      if (pictureUrl != null) 'picture_url': pictureUrl,
      if (wordType != null) 'word_type': wordType,
      if (transcription != null) 'transcription': transcription,
      if (example != null) 'example': example,
      if (note != null) 'note': note,
      if (createdTime != null) 'created_time': createdTime!.toIso8601String(),
    };
  }
}
