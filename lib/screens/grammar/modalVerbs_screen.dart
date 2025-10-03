import 'package:flutter/material.dart';

class ModalVerbsScreen extends StatelessWidget {
  const ModalVerbsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modal Verbs'),
        backgroundColor: Colors.teal,
      ),
      body: const Center(
        child: Text('Modal verbs lessons will be here'),
      ),
    );
  }
}
