import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditUserInfoScreen extends StatefulWidget {
  final String fieldName; // 'full_name', 'phone', 'date_of_birth'
  final String currentValue;
  final String userId;

  const EditUserInfoScreen({
    super.key,
    required this.fieldName,
    required this.currentValue,
    required this.userId,
  });

  @override
  State<EditUserInfoScreen> createState() => _EditUserInfoScreenState();
}

class _EditUserInfoScreenState extends State<EditUserInfoScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _controller;
  bool _isLoading = false;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentValue);

    if (widget.fieldName == 'date_of_birth' && widget.currentValue.isNotEmpty) {
      try {
        // Supabase thường lưu dạng YYYY-MM-DD
        List<String> dateParts = widget.currentValue.split('-');
        if (dateParts.length == 3) {
          _selectedDate = DateTime(
            int.parse(dateParts[0]), // year
            int.parse(dateParts[1]), // month
            int.parse(dateParts[2]), // day
          );
          // Hiển thị trên textfield dạng DD/MM/YYYY
          _controller.text =
          "${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}";
        }
      } catch (e) {
        _selectedDate = null;
        _controller.clear();
      }
    }
  }


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getTitle() {
    switch (widget.fieldName) {
      case 'full_name':
        return 'Chỉnh sửa họ và tên';
      case 'phone':
        return 'Chỉnh sửa số điện thoại';
      case 'date_of_birth':
        return 'Chỉnh sửa ngày sinh';
      default:
        return 'Chỉnh sửa thông tin';
    }
  }

  String _getLabel() {
    switch (widget.fieldName) {
      case 'full_name':
        return 'Họ và tên';
      case 'phone':
        return 'Số điện thoại';
      case 'date_of_birth':
        return 'Ngày sinh';
      default:
        return 'Thông tin';
    }
  }

  String? _validateInput(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Vui lòng nhập ${_getLabel().toLowerCase()}';
    }

    if (widget.fieldName == 'phone') {
      final phoneRegex = RegExp(r'^[0-9]{10,11}$');
      if (!phoneRegex.hasMatch(value.trim())) {
        return 'Số điện thoại không hợp lệ (10-11 chữ số)';
      }
    }

    if (widget.fieldName == 'full_name' && value.trim().length < 2) {
      return 'Họ tên phải có ít nhất 2 ký tự';
    }

    return null;
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0D9FE8),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _controller.text = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  Future<void> _saveChanges() async {
    if (widget.fieldName == 'date_of_birth') {
      if (_selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn ngày sinh')),
        );
        return;
      }
    } else if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final valueToSave = widget.fieldName == 'date_of_birth'
          ? _selectedDate!.toIso8601String().split('T')[0] // Lưu dưới dạng YYYY-MM-DD
          : _controller.text.trim();

      await _supabase
          .from('users')
          .update({widget.fieldName: valueToSave})
          .eq('auth_id', widget.userId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cập nhật thông tin thành công'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi cập nhật: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF0D9FE8)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF0D9FE8), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 3,
        shadowColor: Colors.black26,
        backgroundColor: Colors.blue,
        title: Text(
          _getTitle(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.fieldName == 'date_of_birth')
                GestureDetector(
                  onTap: _pickDate,
                  child: AbsorbPointer(
                    child: _buildTextField(
                      controller: _controller,
                      label: 'Ngày sinh',
                      icon: Icons.calendar_today_outlined,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Vui lòng chọn ngày sinh';
                        }
                        return null;
                      },
                    ),
                  ),
                )
              else
                _buildTextField(
                  controller: _controller,
                  label: _getLabel(),
                  icon: widget.fieldName == 'phone'
                      ? Icons.phone
                      : Icons.person_outline,
                  validator: _validateInput,
                ),

              const SizedBox(height: 30),

              Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isLoading
                          ? [Colors.grey, Colors.grey]
                          : const [Color(0xFF0D9FE8), Color(0xFF2AD1F0)],
                    ),
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                      width: 25,
                      height: 25,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Text(
                      'Lưu thay đổi',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}