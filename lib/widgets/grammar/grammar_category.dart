import 'package:flutter/material.dart';

class GrammarCategory {
  final String title;
  final String description;
  final Color color;
  final IconData icon;
  final Function screen;
  final int lessonCount;

  const GrammarCategory({
    required this.title,
    required this.description,
    required this.color,
    required this.icon,
    required this.screen,
    required this.lessonCount,
  });
}