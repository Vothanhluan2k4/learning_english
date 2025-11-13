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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Khám phá",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: FutureBuilder<List<ExploreList>>(
        future: _exploreLists,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            print('ExploreScreen: Đang chờ dữ liệu...');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Đang tải danh sách...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            print('ExploreScreen: LỖI tải danh sách: ${snapshot.error}');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Lỗi tải dữ liệu',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final lists = snapshot.data ?? [];

          if (lists.isEmpty) {
            print('ExploreScreen: Dữ liệu tải thành công nhưng danh sách rỗng (RLS/CSDL trống).');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Chưa có danh sách nào',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            );
          }

          print('ExploreScreen: Tải thành công ${lists.length} List.');

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: lists.length,
            itemBuilder: (context, index) {
              final list = lists[index];

              return FutureBuilder<int>(
                future: _getWordCount(list.id!),
                builder: (context, countSnapshot) {
                  if (countSnapshot.connectionState == ConnectionState.done && countSnapshot.hasData) {
                    print('ExploreScreen (WordCount): List "${list.title}" có ${countSnapshot.data} từ.');
                  }

                  final wordCount = countSnapshot.data ?? 0;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async { // Bắt đầu AWAIT
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ExploreListDetailScreen(list: list),
                            ),
                          );
                          // Tải lại dữ liệu khi quay lại
                          _refreshExploreLists();
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title
                              Text(
                                list.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.black87,
                                  letterSpacing: -0.3,
                                ),
                              ),

                              // Description
                              if (list.description != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  list.description!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                    height: 1.5,
                                  ),
                                ),
                              ],

                              const SizedBox(height: 16),

                              // Stats Row
                              Row(
                                children: [
                                  // Word Count
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.library_books_outlined,
                                          size: 16,
                                          color: Colors.blue[700],
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '$wordCount từ',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  // Followers Count
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.purple[50],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.people_alt_outlined,
                                          size: 16,
                                          color: Colors.purple[700],
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${list.followersCount ?? 0}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.purple[700],
                                          ),
                                        ),
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
              );
            },
          );
        },
      ),
    );
  }
}