class Word {
  final String? id;
  final String listWordId;
  final String word;
  final String define;
  final String? pictureUrl;
  final String? wordType;
  final String? transcription;
  final String? example;
  final String? note;
  final DateTime? createdTime;

  Word({
    this.id,
    required this.listWordId,
    required this.word,
    required this.define,
    this.pictureUrl,
    this.wordType,
    this.transcription,
    this.example,
    this.note,
    this.createdTime,
  });

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      id: json['id'] as String?,
      listWordId: json['list_word_id'] as String,
      word: json['word'] as String,
      define: json['define'] as String,
      pictureUrl: json['picture_url'] as String?,
      wordType: json['word_type'] as String?,
      transcription: json['transcription'] as String?,
      example: json['example'] as String?,
      note: json['note'] as String?,
      createdTime: json['created_time'] != null
          ? DateTime.parse(json['created_time'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'list_word_id': listWordId,
      'word': word,
      'define': define,
      'picture_url': pictureUrl,
      'word_type': wordType,
      'transcription': transcription,
      'example': example,
      'note': note,
      'created_time': createdTime?.toIso8601String(),
    };
  }
}