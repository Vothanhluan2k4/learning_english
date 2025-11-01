import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_english/models/list_word.dart';
import 'package:learning_english/services/flashcard_service.dart';

class CreateDeckScreen extends StatefulWidget {
  const CreateDeckScreen({super.key});

  @override
  State<CreateDeckScreen> createState() => _CreateDeckScreenState();
}

class _CreateDeckScreenState extends State<CreateDeckScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _userId;
  bool _isLoading = true;

  // --- ✨ Modern Color Scheme ---
  static const Color primaryColor = Color(0xFF6C5CE7);
  static const Color secondaryColor = Color(0xFF00B894);
  static const Color backgroundColor = Color(0xFFF5F6FA);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF2D3436);
  static const Color textSecondary = Color(0xFF636E72);

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

  // --- LOGIC FUNCTIONS (Unchanged) ---
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

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate() && _userId != null) {
      setState(() => _isLoading = true);
      try {
        final newList = ListWord(
          id: null,
          userId: _userId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
        );
        await FlashcardService().createListWord(newList);
        if (context.mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Tạo bộ thẻ thành công!'),
              backgroundColor: secondaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
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

  // --- ✨ UI BUILDERS (Redesigned for Responsiveness) ---

  @override
  Widget build(BuildContext context) {
    if (Supabase.instance.client.auth.currentUser?.id == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/signIn');
      });
      return const Scaffold(backgroundColor: backgroundColor);
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Tạo Bộ Thẻ Mới', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
        elevation: 0,
        backgroundColor: backgroundColor,
        foregroundColor: textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : _buildForm(context),
    );
  }

  Widget _buildForm(BuildContext context) {
    return SafeArea(
      child: Center(
        // ✨ NEW: Added Scrollbar for better web/desktop experience
        child: Scrollbar(
          child: SingleChildScrollView(
            // ✨ NEW: Use LayoutBuilder for adaptive padding
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Check if the screen is wide (like a tablet or web)
                final bool isWideScreen = constraints.maxWidth > 600;

                // Adjust padding based on screen width
                final a_padding = isWideScreen
                    ? const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0)
                    : const EdgeInsets.all(24.0);

                return Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    // Constrain the width on large screens
                    constraints: const BoxConstraints(maxWidth: 600),
                    // ✨ NEW: Wrap the form in a Card for better visual structure on web
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Padding(
                        padding: a_padding,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ✨ NEW: Added a header inside the card
                              const Text(
                                'Chi tiết bộ thẻ',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Điền thông tin dưới đây để tạo một bộ flashcard mới.',
                                style: TextStyle(fontSize: 14, color: textSecondary),
                              ),
                              const SizedBox(height: 32.0),

                              _buildTextField(
                                controller: _titleController,
                                label: 'Tiêu đề *',
                                hintText: 'VD: 100 từ vựng IELTS Band 8.0',
                                validator: (value) => value!.trim().isEmpty ? 'Tiêu đề không được để trống' : null,
                              ),
                              const SizedBox(height: 24.0),
                              _buildTextField(
                                controller: _descriptionController,
                                label: 'Mô tả',
                                hintText: 'Nhập mô tả (tùy chọn)',
                                maxLines: 4,
                              ),
                              const SizedBox(height: 32.0),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: _isLoading ? null : _submitForm,
                                  child: _isLoading
                                      ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                                  )
                                      : const Text('Tạo bộ thẻ'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: textSecondary),
            filled: true,
            fillColor: cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: primaryColor, width: 2),
            ),
          ),
          maxLines: maxLines,
          validator: validator,
        ),
      ],
    );
  }
}