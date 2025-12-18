import 'package:flutter/material.dart';
import 'package:learning_english/models/explore_list.dart';
import 'package:learning_english/services/explore_service.dart';
import 'package:learning_english/screens/flashcard/explore_list_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final ExploreService _exploreService = ExploreService();
  late Future<List<ExploreList>> _exploreLists;

  @override
  void initState() {
    super.initState();
    _refreshExploreLists();
  }

  void _refreshExploreLists() {
    setState(() {
      print('ExploreScreen: Bắt đầu tải lại danh sách Explore.');
      _exploreLists = _exploreService.getExploreLists();
    });
  }

  Future<int> _getWordCount(String listId) async {
    try {
      final words = await _exploreService.getExploreWords(listId);
      return words.length;
    } catch (e) {
      print('ExploreScreen (WordCount): Lỗi khi đếm số từ cho list $listId: $e');
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Modern App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            elevation: 0,
            automaticallyImplyLeading: false,
            backgroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
              title: const Text(
                'Khám Phá',
                style: TextStyle(
                  color: Color(0xFF1A1A2E),
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  letterSpacing: -0.5,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.blue[50]!.withOpacity(0.3),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: FutureBuilder<List<ExploreList>>(
              future: _exploreLists,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SliverFillRemaining(
                    child: _buildLoadingState(),
                  );
                }

                if (snapshot.hasError) {
                  return SliverFillRemaining(
                    child: _buildErrorState(snapshot.error.toString()),
                  );
                }

                final lists = snapshot.data ?? [];

                if (lists.isEmpty) {
                  return SliverFillRemaining(
                    child: _buildEmptyState(),
                  );
                }

                print('ExploreScreen: Tải thành công ${lists.length} List.');

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      return _ListItem(
                        list: lists[index],
                        getWordCount: _getWordCount,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ExploreListDetailScreen(
                                list: lists[index],
                              ),
                            ),
                          );
                          _refreshExploreLists();
                        },
                      );
                    },
                    childCount: lists.length,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  } 

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.blue[600]!,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Đang tải danh sách...',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Oops! Có lỗi xảy ra',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.explore_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Chưa có danh sách nào',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Hãy quay lại sau nhé!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListItem extends StatefulWidget {
  final ExploreList list;
  final Future<int> Function(String) getWordCount;
  final VoidCallback onTap;

  const _ListItem({
    required this.list,
    required this.getWordCount,
    required this.onTap,
  });

  @override
  State<_ListItem> createState() => _ListItemState();
}

class _ListItemState extends State<_ListItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: FutureBuilder<int>(
        future: widget.getWordCount(widget.list.id!),
        builder: (context, countSnapshot) {
          final wordCount = countSnapshot.data ?? 0;

          return GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) {
              setState(() => _isPressed = false);
              widget.onTap();
            },
            onTapCancel: () => setState(() => _isPressed = false),
            child: AnimatedScale(
              scale: _isPressed ? 0.97 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.blue[50]!.withOpacity(0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with icon
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue[600]!,
                                  Colors.blue[400]!,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blue.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.auto_stories_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.list.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 19,
                                color: Color(0xFF1A1A2E),
                                letterSpacing: -0.3,
                                height: 1.3,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: Colors.grey[400],
                          ),
                        ],
                      ),

                      // Description
                      if (widget.list.description != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          widget.list.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                            height: 1.6,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Stats Row
                      Row(
                        children: [
                          // Word Count
                          _StatBadge(
                            icon: Icons.menu_book_rounded,
                            label: '$wordCount từ',
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue[600]!,
                                Colors.blue[400]!,
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Followers Count
                          _StatBadge(
                            icon: Icons.favorite_rounded,
                            label: '${widget.list.followersCount ?? 0}',
                            gradient: LinearGradient(
                              colors: [
                                Colors.purple[600]!,
                                Colors.purple[400]!,
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Gradient gradient;

  const _StatBadge({
    required this.icon,
    required this.label,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}