import 'package:flutter/material.dart';

class PrepositionsScreen extends StatelessWidget {
  const PrepositionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prepositions'),
        backgroundColor: Colors.brown,
      ),
      body: const Center(
        child: Text('Prepositions lessons will be here'),
      ),
    );
  }
}