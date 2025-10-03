import 'package:flutter/material.dart';

class PronunciationItem {
  final String sound;
  final List<String> examples;
  final String vietnamese;

  PronunciationItem({
    required this.sound,
    required this.examples,
    required this.vietnamese,
  });
}