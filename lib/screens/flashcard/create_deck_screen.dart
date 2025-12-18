import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_english/models/list_word.dart';
import 'package:learning_english/services/flashcard_service.dart';
import 'package:flutter/services.dart'; // Import cần thiết cho Haptic Feedback

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
  bool _isSaving = false; // Biến trạng thái riêng cho nút Lưu

  // --- ✨ Modern Color Scheme ---
  static const Color primaryColor = Color(0xFF1E88E5);
  static const Color secondaryColor = Color(0xFF00B894);
  static const Color backgroundColor = Color(0xFFF5F6FA);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF2D3436);
  static const Color textSecondary = Color(0xFF636E72);
  static const Color accentError = Color(0xFFFF6B6B);

  @override
  void initState() {
    super.initState();
    _initializeUser();
    // Thêm listener để cập nhật widget mô phỏng khi nhập liệu
    _titleController.addListener(_updateFormState);
    _descriptionController.addListener(_updateFormState);
  }

  @override
  void dispose() {
    _titleController.removeListener(_updateFormState);
    _descriptionController.removeListener(_updateFormState);
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Cập nhật trạng thái Widget (dùng cho mô phỏng)
  void _updateFormState() {
    // Chỉ cần gọi setState để rebuild phần mô phỏng nhỏ
    setState(() {});
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
    // Thêm Haptic Feedback nhẹ khi nhấn nút
    HapticFeedback.lightImpact();

    if (_formKey.currentState!.validate() && _userId != null) {
      setState(() => _isSaving = true); // Bật trạng thái lưu
      try {
        final newList = ListWord(
          id: null,
          userId: _userId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
        );
        await FlashcardService().createListWord(newList);
        if (context.mounted) {
          // Trả về true để màn hình cha refresh
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
            SnackBar(
              content: Text('Lỗi: $e'),
              backgroundColor: accentError,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    } else if (_userId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lỗi: Không thể xác định người dùng'),
            backgroundColor: accentError,
          ),
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
      // AppBar đơn giản, chỉ có nút Đóng
      appBar: AppBar(
        elevation: 0,
        backgroundColor: backgroundColor,
        foregroundColor: textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 28),
          onPressed: () => Navigator.of(context).pop(), // Pop không trả về giá trị
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
        child: Scrollbar(
          child: SingleChildScrollView(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isWideScreen = constraints.maxWidth > 600;
                final a_padding = isWideScreen
                    ? const EdgeInsets.symmetric(horizontal: 40.0, vertical: 32.0)
                    : const EdgeInsets.all(24.0);

                return Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Card(
                      elevation: 4, // Tăng elevation nhẹ
                      shadowColor: Colors.black.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200, width: 0.5),
                      ),
                      child: Padding(
                        padding: a_padding,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // --- Header ---
                              const Text(
                                'Tạo Bộ Thẻ Mới',
                                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Tổ chức kiến thức của bạn thành các bộ flashcard.',
                                style: TextStyle(fontSize: 14, color: textSecondary),
                              ),
                              const SizedBox(height: 32.0),

                              // --- Live Preview ---
                              _buildDeckPreview(),
                              const SizedBox(height: 32.0),

                              // --- Input Fields ---
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
                                hintText: 'Nhập mô tả (tùy chọn, tối đa 3 dòng)',
                                maxLines: 3,
                              ),
                              const SizedBox(height: 32.0),

                              // --- Submit Button ---
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
                                    elevation: 4,
                                    shadowColor: primaryColor.withOpacity(0.4),
                                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: _isSaving ? null : _submitForm, // Sử dụng _isSaving
                                  child: _isSaving
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

  // ✨ NEW: Widget mô phỏng thẻ (Live Preview)
  Widget _buildDeckPreview() {
    final title = _titleController.text.trim().isEmpty
        ? 'Bộ Thẻ Mới Của Bạn'
        : _titleController.text;
    final description = _descriptionController.text.trim().isEmpty
        ? 'Đây là nơi bạn có thể thêm mô tả.'
        : _descriptionController.text;

    return Container(
      padding: const EdgeInsets.all(16),
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.style_rounded, color: primaryColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(fontSize: 13, color: textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          const Text(
            'Chưa có từ',
            style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500),
          ),
        ],
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
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: accentError, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: const BorderSide(color: accentError, width: 2),
            ),
          ),
          maxLines: maxLines,
          validator: validator,
        ),
      ],
    );
  }
}