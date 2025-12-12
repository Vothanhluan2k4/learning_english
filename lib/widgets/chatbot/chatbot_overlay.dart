import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ← Đảm bảo đã import Supabase
import 'chat_launcher.dart';

class ChatbotOverlay extends StatefulWidget {
  final Widget child;

  const ChatbotOverlay({super.key, required this.child});

  @override
  State<ChatbotOverlay> createState() => _ChatbotOverlayState();
}

class _ChatbotOverlayState extends State<ChatbotOverlay> {
  bool _isChatOpen = false;

  void _toggleChat() {
    setState(() {
      _isChatOpen = !_isChatOpen;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Responsive sizing
    final chatWidth = screenWidth > 400 ? 340.0 : screenWidth * 0.9;
    final chatHeight = screenHeight > 600 ? 520.0 : screenHeight * 0.75;

    // Lấy email người dùng hiện tại từ Supabase Auth
    final currentUserEmail =
        Supabase.instance.client.auth.currentUser?.email ?? "guest@example.com";

    return Stack(
      children: [
        widget.child,

        // Chatbot chính
        if (_isChatOpen)
          Positioned(
            bottom: 80,
            right: screenWidth > 400 ? 16 : 8,
            left: screenWidth > 400 ? null : 8,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: chatWidth),
              child: ChatLauncher(
                userEmail: currentUserEmail, // ← TRUYỀN EMAIL ĐÚNG VÀO ĐÂY
                onClose: _toggleChat,
                width: chatWidth,
                height: chatHeight,
              ),
            ),
          ),

        // Nút mở/đóng chatbot
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton(
            backgroundColor: Colors.indigo,
            elevation: 8,
            onPressed: _toggleChat,
            child: AnimatedCrossFade(
              firstChild: const Icon(
                Icons.smart_toy,
                size: 28,
                color: Colors.white,
              ),
              secondChild: const Icon(
                Icons.close,
                size: 28,
                color: Colors.white,
              ),
              crossFadeState: _isChatOpen
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
            ),
          ),
        ),
      ],
    );
  }
}
