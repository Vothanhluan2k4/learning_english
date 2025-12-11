import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  final _picker = ImagePicker();
  final _cropController = CropController();
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Hiển thị chọn ảnh từ camera hoặc thư viện, crop, upload → trả URL
  Future<String?> pickCropAndUploadImage(BuildContext context) async {
    final source = await _showSourcePicker(context);
    if (source == null) return null;

    final pickedFile = await _picker.pickImage(source: source, imageQuality: 90);
    if (pickedFile == null) return null;

    final imageBytes = await File(pickedFile.path).readAsBytes();
    final croppedFile = await cropImageWithDialog(context, imageBytes, pickedFile.path);
    if (croppedFile == null) return null;

    return await _uploadToSupabase(croppedFile);
  }

  /// Mở bottom sheet chọn nguồn ảnh
  Future<ImageSource?> _showSourcePicker(BuildContext context) async {
    return await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Chọn ảnh đại diện',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.photo_library, color: Colors.blue),
                ),
                title: const Text(
                  'Chọn từ thư viện',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt, color: Colors.green),
                ),
                title: const Text(
                  'Chụp từ camera',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  /// Mở màn hình crop ảnh với frame LỚN
  Future<File?> cropImageWithDialog(BuildContext context, List<int> imageBytes, String originalPath) async {
    File? result;
    final Uint8List uint8Image = Uint8List.fromList(imageBytes);
    final cropController = CropController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        child: Container(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              // ========== HEADER ==========
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Cắt ảnh đại diện',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: Colors.grey[600],
                      iconSize: 28,
                    ),
                  ],
                ),
              ),

              // ========== CROP AREA (EXPANDED - chiếm hết không gian) ==========
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[300]!, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Crop(
                      controller: cropController,
                      image: uint8Image,
                      withCircleUi: true,
                      baseColor: Colors.grey[200]!,
                      maskColor: Colors.black.withOpacity(0.6),
                      radius: 180, // Tăng radius lên 180
                      onCropped: (resultCrop) async {
                        switch (resultCrop) {
                          case CropSuccess(:final croppedImage):
                            final croppedFile = File('${originalPath}_cropped.png');
                            await croppedFile.writeAsBytes(croppedImage);
                            result = croppedFile;
                            Navigator.of(context).pop();
                          case CropFailure(:final cause):
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Colors.white),
                                    const SizedBox(width: 12),
                                    Expanded(child: Text('Lỗi: $cause')),
                                  ],
                                ),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                            Navigator.of(context).pop();
                        }
                      },
                    ),
                  ),
                ),
              ),

              // ========== INSTRUCTIONS ==========
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.withOpacity(0.1),
                      Colors.blue.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        size: 20,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Kéo và thu phóng để điều chỉnh ảnh',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ========== BUTTONS ==========
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Row(
                  children: [
                    // Nút HỦY
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey[400]!, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Hủy',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Nút CẮT VÀ LƯU
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => cropController.cropCircle(),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.blue,
                          elevation: 2,
                          shadowColor: Colors.blue.withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(width: 8),
                            Text(
                              'Lưu',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return result;
  }

  /// Upload ảnh lên Supabase Storage và cập nhật vào bảng users
  Future<String?> _uploadToSupabase(File imageFile) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Người dùng chưa đăng nhập');

      final fileName =
          '${user.id}_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';

      // 1️⃣ Upload ảnh
      await _supabase.storage.from('avatars').upload(fileName, imageFile);

      // 2️⃣ Lấy URL
      final publicUrl = _supabase.storage.from('avatars').getPublicUrl(fileName);

      // 3️⃣ Cập nhật bảng users
      await _supabase.from('users').update({'avatar_url': publicUrl}).eq('auth_id', user.id);

      return publicUrl;
    } catch (e) {
      debugPrint('Lỗi upload Supabase: $e');
      return null;
    }
  }
}