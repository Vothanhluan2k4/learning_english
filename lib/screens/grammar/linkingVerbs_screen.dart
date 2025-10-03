import 'package:flutter/material.dart';

class LinkingVerbsScreen extends StatelessWidget {
  const LinkingVerbsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Linking Verbs'),
        backgroundColor: Colors.green,
      ),
      body: const Center(
        child: Text('Linking verbs lessons will be here'),
      ),
    );
  }
}