import 'package:app_links/app_links.dart';

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();

  Future<void> initDeepLinks() async {
    // Link khi app mở từ trạng thái tắt
    final initialLink = await _appLinks.getInitialLink();
    if (initialLink != null) {
      print("Initial Link: $initialLink");
      _handleLink(initialLink.toString());
    }

    // Link khi app đang chạy
    _appLinks.uriLinkStream.listen((uri) {
      print("Received Link: $uri");
      _handleLink(uri.toString());
    });
  }

  void _handleLink(String link) {
    if (link.contains("/verify")) {
      // Ví dụ: chuyển qua màn hình xác nhận
      print("Xử lý link xác nhận: $link");
    }
  }
}
