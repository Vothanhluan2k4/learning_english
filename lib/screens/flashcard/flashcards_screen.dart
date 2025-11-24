import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:learning_english/models/list_word.dart';
import 'package:learning_english/services/flashcard_service.dart';
import 'package:learning_english/screens/flashcard/create_deck_screen.dart';
import 'package:learning_english/screens/flashcard/review_session_screen.dart';
import 'package:learning_english/screens/flashcard/ReviewLearningScreen.dart';
import 'package:learning_english/screens/flashcard/explore_screen.dart';
import 'package:intl/intl.dart';
import 'dart:math';

// ====================================================================
// 1. DESIGN SYSTEM - COLORS & SPACING (Hệ thống Thiết kế)
// ====================================================================

/// Quản lý Bảng màu nhất quán cho toàn ứng dụng.
abstract class AppColors {
  // Primary Palette (Màu chủ đạo)
  static const Color primary = Color(0xFF6C5CE7); // Deep Purple/Indigo
  static const Color primaryLight = Color(0xFF9B8EF9);
  static const Color primaryDark = Color(0xFF5348C3);

  // Status/Accent Colors (Màu Trạng thái)
  static const Color success = Color(0xFF00A8E9A); // Modern Green (Đã hoàn thành)
  static const Color warning = Color(0xFFFFB300); // Amber (Cần ôn tập/Nhớ)
  static const Color error = Color(0xFFFF6B6B); // Red (Lỗi/Khẩn cấp)
  static const Color info = Color(0xFF00B894); // Secondary Color

  // Backgrounds & Text (Nền và Chữ)
  static const Color background = Color(0xFFF8F9FA); // Light Background
  static const Color card = Colors.white; // Pure White Card
  static const Color textPrimary = Color(0xFF2D3436); // Dark Gray Text
  static const Color textSecondary = Color(0xFF636E72); // Medium Gray Text
  static const Color border = Color(0xFFE0E0E0); // Light Gray Border
}

/// Quản lý hệ thống Khoảng cách nhất quán (Sử dụng bội số của 4 hoặc 8).
abstract class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}

// ====================================================================
// 2. FLASHCARDS SCREEN
// ====================================================================

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> with SingleTickerProviderStateMixin {
  late Future<List<ListWord>> _listWordsFuture;
  late TabController _tabController;

  // Sử dụng GETTER không static hoặc STATIC FINAL cho màu sắc
  // để tránh lỗi biên dịch 'Invalid constant value' liên quan đến opacity
  // (Dựa trên kinh nghiệm trước đây của bạn).
  Color get primaryColor => AppColors.primary;
  Color get secondaryColor => AppColors.info;
  Color get accentColor => AppColors.error;
  Color get backgroundColor => AppColors.background;
  Color get cardColor => AppColors.card;
  Color get textPrimary => AppColors.textPrimary;
  Color get textSecondary => AppColors.textSecondary;
  Color get successColor => AppColors.success;
  Color get warningColor => AppColors.warning;
  Color get errorColor => AppColors.error;
  Color get borderColor => AppColors.border;


  final List<Color> _availableColors = const [
    // Neutral & White
    Color(0xFFFFFFFF), // Pure White
    Color(0xFFF8F9FA), // Off White
    Color(0xFFF5F5F5), // Light Gray

    // Warm Pastels
    Color(0xFFFFE5E5), // Light Rose
    Color(0xFFFFD1DC), // Pink Blush
    Color(0xFFFFC0CB), // Classic Pink
    Color(0xFFFFF5E5), // Peach Cream
    Color(0xFFFFE0B2), // Apricot

    // Cool Pastels
    Color(0xFFE5F5FF), // Sky Blue
    Color(0xFFB0E0E6), // Powder Blue
    Color(0xFFE0F2F1), // Mint Cream

    // Green Tones
    Color(0xFFD0F0C0), // Tea Green
    Color(0xFFE5FFE5), // Honeydew

    // Purple & Lavender
    Color(0xFFE6E6FA), // Lavender
    Color(0xFFF5E5FF), // Light Purple
    Color(0xFFE1BEE7), // Lilac
  ];

  // Utility function to parse hex color (giữ nguyên logic)
  Color _colorFromHex(String? hexColor) {
    if (hexColor == null || hexColor.isEmpty) {
      return cardColor;
    }

    String cleanedHex = hexColor.replaceAll("#", "");
    if (cleanedHex.length == 6) {
      cleanedHex = "FF" + cleanedHex;
    }
    if (cleanedHex.length != 8) {
      return cardColor;
    }
    try {
      return Color(int.parse(cleanedHex, radix: 16));
    } catch (e) {
      return cardColor;
    }
  }

  Future<void> _updateDeckColor(ListWord list, Color color) async {
    // ... (Giữ nguyên logic cập nhật màu sắc)
    final hexValue = color.value.toRadixString(16).padLeft(8, '0');
    final hexColor = '#${hexValue.substring(2).toUpperCase()}';

    try {
      await FlashcardService().updateListColor(list.id!, hexColor);

      if (mounted) {
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: AppSpacing.sm),
                Text('Đã cập nhật màu nền!'),
              ],
            ),
            backgroundColor: successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.sm)),
            duration: const Duration(seconds: 2),
          ),
        );

        _refreshListWords();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text('Lỗi khi cập nhật màu: $e')),
              ],
            ),
            backgroundColor: errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.sm)),
          ),
        );
      }
    }
  }

  void _showColorPicker(ListWord list) {
    // ... (Giữ nguyên logic color picker nhưng cập nhật spacing và color)
    showDialog(
      context: context,
      builder: (dialogContext) {
        Color selectedColor = _colorFromHex(list.backgroundColor);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.md)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                    ),
                    child: Icon(Icons.palette, color: primaryColor, size: AppSpacing.lg),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  const Text('Chọn màu nền', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: selectedColor,
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.style_rounded,
                          color: selectedColor.computeLuminance() > 0.5 ? textPrimary : Colors.white,
                          size: AppSpacing.xl,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          list.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: selectedColor.computeLuminance() > 0.5 ? textPrimary : Colors.white,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Chọn màu:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textSecondary),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: _availableColors.map((color) {
                      final isSelected = selectedColor.value == color.value;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            selectedColor = color;
                          });
                        },
                        child: Container(
                          width: 40, // Giảm kích thước color picker
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: primaryColor, width: 3)
                                : Border.all(color: borderColor, width: 2),
                            boxShadow: isSelected
                                ? [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.3),
                                blurRadius: AppSpacing.sm,
                                offset: const Offset(0, 2),
                              ),
                            ]
                                : [],
                          ),
                          child: isSelected
                              ? Icon(
                            Icons.check,
                            color: color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                            size: AppSpacing.md,
                          )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text('Hủy', style: TextStyle(color: textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () {
                    _updateDeckColor(list, selectedColor);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.sm)),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  ),
                  child: const Text('Lưu', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshListWords();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (ModalRoute.of(context)?.isCurrent == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshListWords();
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshListWords() {
    setState(() {
      _listWordsFuture = FlashcardService().getListWords();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/signIn');
      });
      return Scaffold(backgroundColor: backgroundColor);
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [_buildHeader(context)];
        },
        body: LayoutBuilder(
          builder: (context, constraints) {
            // Đảm bảo nội dung căn giữa và có giới hạn chiều rộng cho Website
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMyListsTab(context),
                    _buildLearningTab(),
                    _buildExploreTab(),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  SliverAppBar _buildHeader(BuildContext context) {
    return SliverAppBar(
      backgroundColor: backgroundColor,
      elevation: 0,
      pinned: true,
      floating: true,
      forceElevated: true,
      shadowColor: Colors.black.withOpacity(0.1),
      toolbarHeight: 0, 
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: TabBar(
              controller: _tabController,
              indicatorColor: primaryColor,
              labelColor: primaryColor,
              unselectedLabelColor: textSecondary,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              indicatorSize: TabBarIndicatorSize.label, // Indicator chuyên nghiệp hơn
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              tabs: const [
                Tab(text: 'Bộ thẻ'),
                Tab(text: 'Đang học'),
                Tab(text: 'Khám phá'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        side: BorderSide(color: secondaryColor.withOpacity(0.5)),
      ),
      color: secondaryColor.withOpacity(0.08),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline_rounded, color: secondaryColor, size: AppSpacing.lg),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Mẹo: Bạn có thể tạo flashcards từ các từ đã highlight trong trang chi tiết từ vựng.',
                style: TextStyle(color: textPrimary, height: 1.4, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyListsTab(BuildContext context) {
    return FutureBuilder<List<ListWord>>(
      future: _listWordsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Lỗi: ${snapshot.error}'));
        }
        final lists = snapshot.data ?? [];
        return Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoBanner(),
                _buildDeckGrid(context, lists),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon( // Sử dụng TextButton.icon cho thẩm mỹ hơn
                      icon: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: primaryColor),
                      label: const Text(
                        "Xem tất cả bộ thẻ",
                        style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        _tabController.animateTo(1);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 48, color: primaryColor.withOpacity(0.8)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Tạo bộ thẻ đầu tiên', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateDeckScreen()),
                ).then((result) {
                  if (result == true) _refreshListWords();
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.sm)),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLearningTab() {
    return FutureBuilder<List<ListWord>>(
      future: _listWordsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return _buildEmptyState(
            icon: Icons.error_outline,
            title: 'Lỗi tải dữ liệu',
            message: 'Vui lòng thử lại sau.',
          );
        }

        final lists = snapshot.data!;
        final activeLists = lists.where((l) => (l.wordCount ?? 0) > 0).toList();

        if (activeLists.isEmpty) {
          return _buildEmptyState(
            icon: Icons.auto_stories_outlined,
            title: 'Bắt đầu học thôi!',
            message: 'Tạo hoặc chọn một bộ thẻ để bắt đầu học và theo dõi tiến trình tại đây.',
          );
        }

        final Map<String, Map<String, int>> progressCache = {};

        return FutureBuilder(
          future: Future.wait(activeLists.map((list) async {
            // Lấy tiến trình cho từng list
            final progress = await FlashcardService().getProgress(list.id!);
            int total = progress['total'] ?? 0;
            int studied = progress['studied'] ?? 0;
            int remembered = progress['remembered'] ?? 0;

            if (studied > total) studied = total;
            if (remembered > total) remembered = total;

            final toReview = max(0, total - studied - remembered);

            progressCache[list.id!] = {
              'total': total,
              'studied': studied,
              'remembered': remembered,
              'toReview': toReview, // Thêm toReview vào cache
            };

            return list;
          })),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: primaryColor));
            }

            int totalStudied = progressCache.values.fold(0, (sum, p) => sum + (p['studied'] ?? 0));
            int totalRemembered = progressCache.values.fold(0, (sum, p) => sum + (p['remembered'] ?? 0));
            int totalToReview = progressCache.values.fold(0, (sum, p) => sum + (p['toReview'] ?? 0));

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tổng quan học tập',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Thanh tiến trình tổng thể
                  _buildProgressBar(totalStudied, totalRemembered, totalToReview),
                  const SizedBox(height: AppSpacing.md),
                  // Thẻ thống kê
                  Row(
                    children: [
                      _buildStatCard('$totalStudied\nĐã học', successColor, Icons.auto_stories),
                      const SizedBox(width: AppSpacing.sm),
                      _buildStatCard('$totalRemembered\nĐã nhớ', warningColor, Icons.check_circle),
                      const SizedBox(width: AppSpacing.sm),
                      _buildStatCard('$totalToReview\nCần ôn tập', errorColor, Icons.refresh),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Bộ thẻ đang hoạt động:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Danh sách thẻ đang học
                  ...activeLists.map((list) {
                    final p = progressCache[list.id!] ??
                        {'total': 0, 'studied': 0, 'remembered': 0, 'toReview': 0};
                    final total = p['total']!;
                    final toReview = p['toReview']!;

                    return _buildActiveLearningCard(context, list, p, toReview);
                  }).toList(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Cải tiến: Thiết kế thanh tiến trình chuyên nghiệp hơn
  Widget _buildProgressBar(int studied, int remembered, int toReview) {
    final total = studied + remembered + toReview;
    if (total == 0) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildProgressNumber(studied, "Đã học", successColor),
            _buildProgressNumber(remembered, "Đã nhớ", warningColor),
            _buildProgressNumber(toReview, "Cần ôn tập", errorColor),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          height: AppSpacing.sm, // Giảm chiều cao thanh tiến trình
          decoration: BoxDecoration(
            color: borderColor,
            borderRadius: BorderRadius.circular(AppSpacing.xs),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.xs),
            child: Row(
              children: [
                if (studied > 0)
                  Expanded(
                    flex: studied,
                    child: Container(color: successColor),
                  ),
                if (remembered > 0)
                  Expanded(
                    flex: remembered,
                    child: Container(color: warningColor),
                  ),
                if (toReview > 0)
                  Expanded(
                    flex: toReview,
                    child: Container(color: errorColor),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Cải tiến: Thiết kế số liệu tiến trình
  Widget _buildProgressNumber(int count, String label, Color color) {
    return Column(
      children: [
        Text(
          "$count",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: textSecondary),
        ),
      ],
    );
  }

  Widget _buildExploreTab() {
    return const ExploreScreen();
  }

  Widget _buildDeckGrid(BuildContext context, List<ListWord> lists) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount = (screenWidth / 260).floor().clamp(2, 5); // Điều chỉnh kích thước thẻ

    List<Widget> deckCards = [
      _buildCreateDeckCard(context),
      ...lists.map((list) => _buildDeckItemCard(context, list)).toList(),
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.md),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.9,
      ),
      itemCount: deckCards.length,
      itemBuilder: (context, index) {
        // Giữ lại hiệu ứng Animation nhẹ
        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 300 + (index * 50)),
          tween: Tween<double>(begin: 0.0, end: 1.0),
          builder: (context, double value, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: Opacity(opacity: value, child: child),
            );
          },
          child: deckCards[index],
        );
      },
    );
  }

  // Cải tiến: Thẻ tạo mới
  Widget _buildCreateDeckCard(BuildContext context) {
    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreateDeckScreen()),
        );
        if (result == true) _refreshListWords();
      },
      borderRadius: BorderRadius.circular(AppSpacing.md),
      child: Card(
        elevation: 1, // Tăng elevation nhẹ
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
          // Sử dụng border màu primary nhẹ để tạo điểm nhấn
          side: BorderSide(color: primaryColor.withOpacity(0.4), width: 1.5),
        ),
        // Thêm màu nền nhẹ để tách biệt
        color: Colors.white.withOpacity(0.9),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline_rounded, color: primaryColor, size: AppSpacing.xl),
              const SizedBox(height: AppSpacing.sm),
              Text('Tạo bộ thẻ mới', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  // Cải tiến: Thẻ nội dung (Deck Item)
  Widget _buildDeckItemCard(BuildContext context, ListWord list) {
    final cardBackgroundColor = list.backgroundColor != null ? _colorFromHex(list.backgroundColor) : cardColor;
    final isLight = cardBackgroundColor.computeLuminance() > 0.5;

    final contentColor = isLight ? textPrimary : Colors.white;
    final secondaryContentColor = isLight ? textSecondary : Colors.white.withOpacity(0.7);
    final iconBgColor = isLight ? primaryColor.withOpacity(0.1) : Colors.white.withOpacity(0.2);

    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ReviewSessionScreen(list: list)),
        );
        if (result == true) _refreshListWords();
      },
      borderRadius: BorderRadius.circular(AppSpacing.md),
      child: Card(
        elevation: 4, // Tăng elevation cho cảm giác "nổi"
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.md),
          side: BorderSide(color: borderColor, width: 0.5), // Border mỏng
        ),
        color: cardBackgroundColor,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(AppSpacing.sm),
                    ),
                    child: Icon(Icons.style_rounded, color: contentColor, size: AppSpacing.lg),
                  ),
                  IconButton(
                    icon: Icon(Icons.palette_outlined, color: secondaryContentColor, size: 20),
                    onPressed: () => _showColorPicker(list),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                list.title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: contentColor), // Cỡ chữ lớn hơn
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                list.description ?? 'Không có mô tả',
                style: TextStyle(color: secondaryContentColor, fontSize: 13),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              // Thêm Divider mỏng
              Divider(color: secondaryContentColor.withOpacity(0.3), height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.layers_rounded, size: 14, color: secondaryContentColor),
                      const SizedBox(width: AppSpacing.xs),
                      Text('${list.wordCount ?? 0} từ', style: TextStyle(fontSize: 13, color: secondaryContentColor, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 12, color: secondaryContentColor),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        list.createdAt != null
                            ? DateFormat('dd/MM/yyyy').format(list.createdAt!)
                            : 'Không rõ',
                        style: TextStyle(fontSize: 12, color: secondaryContentColor),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Cải tiến: Thẻ thống kê
  Widget _buildStatCard(String text, Color color, IconData icon) {
    final lines = text.split('\n');
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppSpacing.md),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15), // Dùng màu thống kê cho shadow nhẹ
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: AppSpacing.lg),
            const SizedBox(height: AppSpacing.sm),
            Text(
              lines[0],
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.center,
            ),
            Text(
              lines[1],
              style: TextStyle(fontSize: 12, color: textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Cải tiến: Thẻ học tập đang hoạt động
  Widget _buildActiveLearningCard(BuildContext context, ListWord list, Map<String, int> progress, int toReview) {
    final int total = progress['total'] ?? 0;
    final int remembered = progress['remembered'] ?? 0;
    final double completion = total > 0 ? (remembered / total) : 0;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      elevation: 2, // Thêm elevation nhẹ
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.md)),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppSpacing.sm),
              ),
              child: Icon(Icons.style_rounded, color: primaryColor, size: AppSpacing.lg),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    list.title,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,        // khoảng cách ngang giữa 2 cụm
                    runSpacing: AppSpacing.xs,     // khoảng cách dọc khi xuống dòng
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule_outlined, size: 14, color: errorColor),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Cần ôn tập: $toReview',
                            style: const TextStyle(fontSize: 13, color: AppColors.error, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.done_all_rounded, size: 14, color: warningColor),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            'Đã nhớ: $remembered',
                            style: const TextStyle(fontSize: 13, color: AppColors.warning, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  LinearProgressIndicator(
                    value: completion,
                    backgroundColor: borderColor,
                    valueColor: AlwaysStoppedAnimation<Color>(successColor),
                    minHeight: 4,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Hoàn thành: ${((completion) * 100).toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 11, color: successColor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ReviewLearningScreen(list: list)),
                );
                if (result == true) _refreshListWords();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.sm)),
                elevation: 0,
              ),
              child: const Text('Học tiếp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}