import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<Map<String, String>> _messages = [];
  
  bool _isLoading = false;
  // TODO: Thay đổi URL này sau khi setup n8n workflow của bạn
  // Xem hướng dẫn tại docs/N8N_SETUP.md
  final String backend = "https://luanthanhvo.app.n8n.cloud/webhook/english-chat";

  @override
  void initState() {
    super.initState();
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

    const String errorReply = "😅 Hì, mình đang bị quá tải, bạn vui lòng thử lại sau nha!";

    try {
      final resp = await http.post(
        Uri.parse(backend),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message": message}),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      String reply = errorReply;

      if (resp.statusCode == 200) {
        try {
          final dynamic rawData = jsonDecode(resp.body);

          // Handle n8n response format: [{json: {output: "..."}}]
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
          // Handle direct response format: {output: "..."}
          else if (rawData is Map<String, dynamic> && rawData["output"] != null) {
            reply = rawData["output"].toString();
          }
          // Handle text response
          else if (rawData is String) {
            reply = rawData;
          }
        } catch (e) {
          print('Parse error: $e');
          reply = errorReply;
        }
      } else if (resp.statusCode == 404) {
        reply = "❌ Không tìm thấy server. Vui lòng kiểm tra lại URL trong code.";
      } else if (resp.statusCode == 500) {
        reply = "⚠️ Server đang gặp sự cố. Vui lòng thử lại sau.";
      } else {
        reply = "😕 Có lỗi xảy ra (Status: ${resp.statusCode}). Vui lòng thử lại.";
      }

      _sendBotMessage(reply);
    } on Exception catch (e) {
      String errorMsg = errorReply;
      if (e.toString().contains('timeout')) {
        errorMsg = "⏱️ Yêu cầu bị timeout. Vui lòng thử lại.";
      } else if (e.toString().contains('SocketException')) {
        errorMsg = "🌐 Không có kết nối mạng. Vui lòng kiểm tra Internet.";
      }
      _sendBotMessage(errorMsg);
      print('Request error: $e');
    } catch (e) {
      _sendBotMessage(errorReply);
      print('Unknown error: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF2196F3),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "LQEnglish AI - English Tutor",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.smart_toy,
                          size: 80,
                          color: Color(0xFF2196F3).withOpacity(0.5),
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Xin chào! Tôi là LQEnglish AI",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2196F3),
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Trợ lý học tiếng Anh thông minh của bạn!",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Hỏi mình về:\n• Ngữ pháp\n• Từ vựng\n• Phát âm\n• Dịch câu",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isUser = msg["sender"] == "user";
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.75,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: isUser ? Color(0xFF2196F3) : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: isUser
                                ? Text(
                                    msg["text"] ?? "",
                                    style: const TextStyle(color: Colors.white, fontSize: 15),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    focusNode: _focusNode,
                    controller: _controller,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      hintText: "Nhập tin nhắn...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF2196F3),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _isLoading ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}