class Tense {
  final String name;
  final String structure;
  final String usage;
  final List<String> examples;
  final String positiveForm;
  final String negativeForm;
  final String questionForm;
  final String? videoUrl;

  Tense({
    required this.name,
    required this.structure,
    required this.usage,
    required this.examples,
    required this.positiveForm,
    required this.negativeForm,
    required this.questionForm,
    this.videoUrl,
  });
}