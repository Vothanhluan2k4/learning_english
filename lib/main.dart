import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:learning_english/core/supabase_config.dart';
import 'package:learning_english/core/uni_links.dart';
import 'package:learning_english/screens/drawer_screen.dart';
import 'package:learning_english/screens/home_screen.dart';
import 'package:learning_english/screens/setting_screen.dart';
import 'package:learning_english/screens/flashcard/flashcards_screen.dart';
import 'package:learning_english/screens/course_screen.dart';
import 'package:learning_english/screens/grammar_screen.dart';
import 'package:learning_english/screens/login_screen.dart';
import 'package:learning_english/screens/signIn_screen.dart';
import 'package:learning_english/screens/signUp_screen.dart';
import 'package:learning_english/service/auth_service.dart'; // Import AuthService
import 'dart:async';


void main() async{
  WidgetsFlutterBinding.ensureInitialized();

  //initialize Supabase
  await SupabaseConfig.initialize();
  final deepLinkService = DeepLinkService();
  await deepLinkService.initDeepLinks();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Timer? _expiryCheckTimer;
  final AuthService _authService = AuthService();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Kiểm tra ngay khi app khởi động
    Future.delayed(Duration(seconds: 1), () {
      _checkLoginExpiry();
    });

    // Kiểm tra định kỳ mỗi giờ
    _expiryCheckTimer = Timer.periodic(
      Duration(hours: 1),
          (timer) => _checkLoginExpiry(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kiểm tra khi app trở lại foreground
    if (state == AppLifecycleState.resumed) {
      _checkLoginExpiry();
    }
  }

  Future<void> _checkLoginExpiry() async {
    try {
      final isExpired = await _authService.checkLoginExpiry();

      if (isExpired) {
        // Chuyển về màn hình login
        navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/signIn',
              (route) => false,
        );

        // Hiển thị thông báo
        final context = navigatorKey.currentContext;
        if (context != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('Error in _checkLoginExpiry: $e');
    }
  }

  @override
  void dispose() {
    _expiryCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Lun English',
      theme: ThemeData(primaryColor: Colors.blue),
      initialRoute: '/signIn',
      routes: {
        '/signUp': (context) => SignUpScreen(),
        '/signIn': (context) => SignInScreen(),
        '/homedrawer': (context) => DrawerScreen(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}