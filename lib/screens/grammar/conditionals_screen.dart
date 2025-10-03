import 'package:flutter/material.dart';

class ConditionalsScreen extends StatelessWidget {
  const ConditionalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conditionals'),
        backgroundColor: Colors.purple,
      ),
      body: const Center(
        child: Text('Conditionals lessons will be here'),
      ),
    );
  }
}