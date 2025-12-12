import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatLauncher extends StatefulWidget {
  final VoidCallback onClose;
  final double width;
  final double height;
  final String userEmail; // Email người dùng sau khi đăng nhập

  const ChatLauncher({
    super.key,
    required this.onClose,
    required this.userEmail,
    this.width = 320,
    this.height = 480,
  });

  static final List<Map<String, String>> _chatHistory = [];

  @override
  State<ChatLauncher> createState() => _ChatLauncherState();
}

class _ChatLauncherState extends State<ChatLauncher> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<Map<String, String>> get _messages => ChatLauncher._chatHistory;

  bool _isLoading = false;
  final String backend = "https://bikiet.app.n8n.cloud/webhook/vocab-chat";

  @override
  void initState() {
    super.initState();
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final message = _controller.text.trim();
    if (message.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({"sender": "user", "text": message});
      _controller.clear();
    });

    _focusNode.requestFocus();
    _scrollToBottom();
    await _callAgent(message);
  }

  Future<void> _callAgent(String message) async {
    setState(() => _isLoading = true);

    try {
      final resp = await http.post(
        Uri.parse(backend),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"session_id": widget.userEmail, "message": message}),
      );

      String reply = "Bingo AI đang bận, thử lại sau nhé 😊";

      if (resp.statusCode == 200) {
        try {
          final dynamic rawData = jsonDecode(resp.body);
          if (rawData is List && rawData.isNotEmpty) {
            for (var item in rawData) {
              if (item is Map<String, dynamic>) {
                if (item["json"] is Map && item["json"]["output"] != null) {
                  reply = item["json"]["output"].toString();
                  break;
                }
                if (item["output"] != null) {
                  reply = item["output"].toString();
                  break;
                }
              }
            }
          }
        } catch (e) {
          reply = "⚠️ Lỗi phân tích dữ liệu từ server: $e";
        }
      } else {
        reply = "⚠️ Lỗi server: ${resp.statusCode}";
      }

      _sendBotMessage(reply);
    } catch (e) {
      _sendBotMessage("⚠️ Không kết nối được: $e");
    }

    setState(() => _isLoading = false);
    _scrollToBottom();
  }

  void _sendBotMessage(String text) {
    setState(() {
      _messages.add({"sender": "bot", "text": text});
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  static void clearChatHistory() {
    ChatLauncher._chatHistory.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: Colors.indigo,
              automaticallyImplyLeading: false,
              title: const Text("Bingo AI"),
              actions: [
                IconButton(
                  icon: const Icon(Icons.shuffle),
                  onPressed: () => _callAgent("ôn tập từ vựng"),
                ),
                IconButton(
                  icon: const Icon(Icons.bar_chart),
                  onPressed: () => _callAgent("xem thống kê học tập"),
                ),
                IconButton(
                  icon: const Icon(Icons.lightbulb),
                  onPressed: () => _callAgent("gợi ý ôn tập"),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                ),
              ],
            ),
            body: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg["sender"] == "user";
                      return Align(
                        alignment: isUser
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: widget.width - 40,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 14,
                            ),
                            margin: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isUser
                                  ? Colors.indigo
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: isUser
                                ? Text(
                                    msg["text"] ?? "",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                    ),
                                  )
                                : MarkdownBody(
                                    data: msg["text"] ?? "",
                                    selectable: true,
                                    softLineBreak: true,
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          focusNode: _focusNode,
                          controller: _controller,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          decoration: const InputDecoration(
                            hintText: "Nhập tin nhắn...",
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.indigo),
                        onPressed: _isLoading ? null : _sendMessage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
