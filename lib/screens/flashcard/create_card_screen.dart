import 'package:flutter/material.dart';
import 'package:learning_english/models/word.dart';
import 'package:learning_english/services/flashcard_service.dart';
import 'package:file_picker/file_picker.dart';

// --- DESIGN SYSTEM ---
// Sử dụng màu sắc nhất quán. Tôi sẽ dùng PrimaryColor làm màu chủ đạo.
const Color primaryColor = Color(0xFF6C5CE7); // Deep Purple
const Color secondaryColor = Color(0xFF00B894); // Teal Green
const Color textPrimary = Color(0xFF2D3436);
const Color textSecondary = Color(0xFF636E72);
const double spacingMd = 16.0;
const double spacingLg = 24.0;
// ----------------------

class CreateCardScreen extends StatefulWidget {
  final String listWordId;

  const CreateCardScreen({super.key, required this.listWordId});

  @override
  State<CreateCardScreen> createState() => _CreateCardScreenState();
}

class _CreateCardScreenState extends State<CreateCardScreen> {
  final _formKey = GlobalKey<FormState>();

  // REQUIRED FIELDS
  final _wordController = TextEditingController();
  final _defineController = TextEditingController();

  // OPTIONAL FIELDS
  final _wordTypeController = TextEditingController();
  final _transcriptionController = TextEditingController();
  final _exampleController = TextEditingController();
  final _noteController = TextEditingController();

  // FILE UPLOAD
  FilePickerResult? _imageFileResult;
  bool _isExpanded = false; // Trạng thái của ExpansionTile

  @override
  void dispose() {
    _wordController.dispose();
    _defineController.dispose();
    _wordTypeController.dispose();
    _transcriptionController.dispose();
    _exampleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // ===================== HÀM XỬ LÝ =====================

  void _chooseFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      setState(() {
        _imageFileResult = result;
      });
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        final newWord = Word(
          id: null,
          listWordId: widget.listWordId,
          word: _wordController.text.trim(),
          define: _defineController.text.trim(),
          wordType: _wordTypeController.text.isNotEmpty ? _wordTypeController.text.trim() : null,
          transcription: _transcriptionController.text.isNotEmpty ? _transcriptionController.text.trim() : null,
          example: _exampleController.text.isNotEmpty ? _exampleController.text.trim() : null,
          note: _noteController.text.isNotEmpty ? _noteController.text.trim() : null,
          pictureUrl: null, // Sẽ được cập nhật sau khi upload (trong service layer)
        );

        // Gọi service để tạo từ và upload ảnh (nếu có)
        await FlashcardService().createWord(newWord, imageFile: _imageFileResult);

        if (context.mounted) {
          Navigator.pop(context, true); // Trả về true để reload
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Thêm thẻ thành công!'),
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
              content: Text('Lỗi khi thêm: $e'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    }
  }

  // ===================== GIAO DIỆN =====================

  // Hàm xây dựng TextField chung
  Widget _buildTextField(String label, TextEditingController controller, {String? hintText, int maxLines = 1, bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          required ? '$label *' : label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textPrimary),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primaryColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            isDense: true,
          ),
          validator: required
              ? (value) {
            if (value == null || value.isEmpty) {
              return 'Trường $label là bắt buộc.';
            }
            return null;
          }
              : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Tạo Thẻ Flashcard Mới', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
        backgroundColor: Colors.white,
        elevation: 1,
        surfaceTintColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(spacingLg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600), // Giới hạn chiều rộng cho màn hình lớn
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Required Fields ---
                  _buildTextField('Từ vựng (Word)', _wordController, hintText: 'Nhập từ tiếng Anh...', required: true),
                  const SizedBox(height: spacingMd),
                  _buildTextField('Định nghĩa (Define)', _defineController, hintText: 'Nhập nghĩa tiếng Việt...', maxLines: 3, required: true),
                  const SizedBox(height: spacingLg),

                  // --- Optional Fields (Expansion Tile) ---
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 5,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: spacingMd, vertical: 4),
                        childrenPadding: const EdgeInsets.fromLTRB(spacingMd, 0, spacingMd, spacingMd),
                        title: const Text(
                          'Thông tin chi tiết (Tùy chọn)',
                          style: TextStyle(color: primaryColor, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        leading: Icon(
                            Icons.expand_circle_down_outlined,
                            color: primaryColor.withOpacity(0.8),
                            size: 24
                        ),
                        onExpansionChanged: (bool expanded) => setState(() => _isExpanded = expanded),
                        trailing: Icon(
                          _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: primaryColor,
                        ),
                        initiallyExpanded: false,
                        children: [
                          const Divider(height: 1, color: Colors.grey),
                          const SizedBox(height: spacingMd),

                          // Row 1: Word Type & Transcription
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildTextField('Loại từ (N, V, Adj...)', _wordTypeController, hintText: 'N, V, Adj...')),
                              const SizedBox(width: spacingMd),
                              Expanded(child: _buildTextField('Phiên âm', _transcriptionController, hintText: '/trænˈskrɪpʃn/')),
                            ],
                          ),
                          const SizedBox(height: spacingMd),

                          // Row 2: Image Picker
                          _buildImagePicker(),
                          const SizedBox(height: spacingMd),

                          // Row 3: Example
                          _buildTextField('Ví dụ', _exampleController, hintText: 'Nhập ví dụ sử dụng từ...', maxLines: 3),
                          const SizedBox(height: spacingMd),

                          // Row 4: Note
                          _buildTextField('Ghi chú', _noteController, hintText: 'Ghi chú thêm...', maxLines: 3),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: spacingLg * 1.5),

                  // --- Submit Button ---
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _submitForm,
                      icon: const Icon(Icons.save_rounded, size: 24),
                      label: const Text('Lưu Thẻ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: spacingMd + 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        shadowColor: primaryColor.withOpacity(0.4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Hàm xây dựng UI chọn ảnh
  Widget _buildImagePicker() {
    final fileName = _imageFileResult?.files.single.name ?? 'Chưa chọn file';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ảnh minh họa',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: textPrimary),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: _chooseFile,
              icon: const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text('Chọn file'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                foregroundColor: textPrimary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                fileName,
                style: const TextStyle(color: textSecondary, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_imageFileResult != null)
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.red),
                onPressed: () => setState(() => _imageFileResult = null),
              ),
          ],
        ),
      ],
    );
  }
}