import 'package:flutter/material.dart';
import 'pronunciation_item.dart';

class PronunciationLesson {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final String duration;
  final String difficulty;
  final PronunciationContent content;

  PronunciationLesson({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.duration,
    required this.difficulty,
    required this.content,
  });
}

class PronunciationContent {
  final List<PronunciationSection> sections;

  PronunciationContent({required this.sections});
}

class PronunciationSection {
  final String title;
  final List<PronunciationItem> items;

  PronunciationSection({
    required this.title,
    required this.items,
  });
}