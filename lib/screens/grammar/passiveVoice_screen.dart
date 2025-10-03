import 'package:flutter/material.dart';

class PassiveVoiceScreen extends StatelessWidget {
  const PassiveVoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Passive Voice'),
        backgroundColor: Colors.red,
      ),
      body: const Center(
        child: Text('Passive voice lessons will be here'),
      ),
    );
  }
}