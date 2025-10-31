import 'package:flutter/material.dart';
import 'package:learning_english/models/word.dart';
import 'package:learning_english/service/flashcard_service.dart';

class CreateCardScreen extends StatefulWidget {
  final String listWordId;

  const CreateCardScreen({super.key, required this.listWordId});

  @override
  State<CreateCardScreen> createState() => _CreateCardScreenState();
}

class _CreateCardScreenState extends State<CreateCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _wordController = TextEditingController();
  final _defineController = TextEditingController();

  // ===================== HÀM XỬ LÝ =====================

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        final newWord = Word(
          id: null,
          listWordId: widget.listWordId,
          word: _wordController.text,
          define: _defineController.text,
        );

        await FlashcardService().createWord(newWord);

        if (context.mounted) {
          Navigator.pop(context, true); // Trả về true để reload
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thêm thẻ thành công!')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e')),
          );
        }
      }
    }
  }

  // ===================== GIAO DIỆN =====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm Thẻ Mới')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _wordController,
                decoration: const InputDecoration(labelText: 'Từ'),
                validator: (value) =>
                value!.isEmpty ? 'Vui lòng nhập từ' : null,
              ),
              TextFormField(
                controller: _defineController,
                decoration: const InputDecoration(labelText: 'Định nghĩa'),
                validator: (value) =>
                value!.isEmpty ? 'Vui lòng nhập định nghĩa' : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text('Lưu'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
