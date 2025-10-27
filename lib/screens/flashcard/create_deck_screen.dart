import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_english/models/list_word.dart';
import 'package:learning_english/service/flashcard_service.dart';

class CreateDeckScreen extends StatefulWidget {
  const CreateDeckScreen({super.key});

  @override
  State<CreateDeckScreen> createState() => _CreateDeckScreenState();
}

class _CreateDeckScreenState extends State<CreateDeckScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _userId; // Lưu userId từ bảng users
  bool _isLoading = true; // Trạng thái loading khi khởi tạo user

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Khởi tạo userId từ authId
  Future<void> _initializeUser() async {
    try {
      final authId = Supabase.instance.client.auth.currentUser?.id;
      if (authId == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final response = await Supabase.instance.client
          .from('users')
          .select('id')
          .eq('auth_id', authId)
          .maybeSingle();

      if (response == null) {
        await Supabase.instance.client.from('users').insert({
          'auth_id': authId,
          'full_name': Supabase.instance.client.auth.currentUser?.userMetadata?['full_name'] ?? 'User',
          'email': Supabase.instance.client.auth.currentUser?.email ?? '',
        });
        final newResponse = await Supabase.instance.client
            .from('users')
            .select('id')
            .eq('auth_id', authId)
            .maybeSingle();
        _userId = newResponse?['id'] as String?;
      } else {
        _userId = response['id'] as String?;
      }
    } catch (e) {
      print('Error initializing user: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Xử lý submit form để tạo bộ thẻ mới
  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate() && _userId != null) {
      try {
        setState(() => _isLoading = true);
        final newList = ListWord(
          id: null, // Supabase tự tạo UUID
          userId: _userId!,
          title: _titleController.text,
          description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        );
        await FlashcardService().createListWord(newList);
        if (context.mounted) {
          Navigator.pop(context, true); // Trả về true khi thành công
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tạo bộ thẻ thành công!')),
          );
          _titleController.clear();
          _descriptionController.clear();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    } else if (_userId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lỗi: Không thể xác định người dùng')),
        );
      }
    }
  }

  // Kiểm tra đăng nhập và trả về widget tương ứng
  Widget _checkAuthAndBuild(BuildContext context) {
    final authId = Supabase.instance.client.auth.currentUser?.id;
    if (authId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/signIn');
      });
      return const SizedBox.shrink();
    }

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tạo Bộ Thẻ Mới')),
      body: _buildForm(context),
    );
  }

  // Xây dựng form nhập liệu
  Widget _buildForm(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Tiêu đề',
                border: OutlineInputBorder(),
                hintText: 'Nhập tiêu đề bộ thẻ',
              ),
              validator: (value) =>
              value!.isEmpty ? 'Tiêu đề không được để trống' : null,
            ),
            const SizedBox(height: 16.0),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Mô tả',
                border: OutlineInputBorder(),
                hintText: 'Nhập mô tả (tùy chọn)',
              ),
            ),
            const SizedBox(height: 16.0),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              onPressed: _submitForm,
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _checkAuthAndBuild(context);
  }
}