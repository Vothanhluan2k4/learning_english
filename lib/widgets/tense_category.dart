import 'package:flutter/material.dart';
import 'package:learning_english/widgets/tense.dart';

class TenseCategory {
  final String title;
  final Color color;
  final IconData icon;
  final List<Tense> tenses;

  TenseCategory({
    required this.title,
    required this.color,
    required this.icon,
    required this.tenses,
  });
}