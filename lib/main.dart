import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/supabase_config.dart';
import 'core/uni_links.dart';
import 'screens/course/chosse_course_screen.dart';
import 'screens/course/course_screen.dart';
import 'screens/drawer_screen.dart';
import 'screens/flashcard/flashcards_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/grammar_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile/infor_user_screen.dart';
import 'screens/setting_screen.dart';
import 'screens/signIn_screen.dart';
import 'screens/signUp_screen.dart';
import 'screens/verify_otp_screen.dart' hide ForgotPasswordScreen;
import 'screens/welcome_screen.dart';
import 'service/auth_service.dart';
import 'service/google_auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lấy trạng thái đăng nhập từ SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  // Khởi tạo các dịch vụ
  await _initializeServices();

  // Đồng bộ người dùng vào bảng users
  await _syncUser();

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

// Khởi tạo Supabase, deep links và Google Sign-In
Future<void> _initializeServices() async {
  await SupabaseConfig.initialize();
  final deepLinkService = DeepLinkService();
  await deepLinkService.initDeepLinks();
  final googleAuth = GoogleAuthService();
  await googleAuth.initialize();
}

// Đồng bộ người dùng vào bảng users nếu chưa tồn tại
Future<void> _syncUser() async {
  final supabase = Supabase.instance.client;
  final session = supabase.auth.currentSession;
  if (session == null) return;

  final authId = session.user.id;
  final existingUser = await supabase
      .from('users')
      .select('auth_id')
      .eq('auth_id', authId)
      .maybeSingle();

  if (existingUser == null) {
    await supabase.from('users').insert({
      'auth_id': authId,
      'full_name': session.user.userMetadata?['full_name'] ?? 'User',
      'email': session.user.email ?? '',
    });
  }
}

class MyApp extends StatefulWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  Timer? _expiryCheckTimer;
  final AuthService _authService = AuthService();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Kiểm tra phiên đăng nhập sau 1 giây
    Future.delayed(const Duration(seconds: 1), _checkLoginExpiry);

    // Kiểm tra định kỳ mỗi giờ
    _expiryCheckTimer = Timer.periodic(
      const Duration(hours: 1),
          (_) => _checkLoginExpiry(),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkLoginExpiry();
    }
  }

  // Kiểm tra và xử lý khi phiên đăng nhập hết hạn
  Future<void> _checkLoginExpiry() async {
    try {
      final isExpired = await _authService.checkLoginExpiry();
      if (isExpired && mounted) {
        _navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/signIn',
              (route) => false,
        );
        final context = _navigatorKey.currentContext;
        if (context != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
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
      navigatorKey: _navigatorKey,
      initialRoute: widget.isLoggedIn ? '/welcome' : '/signIn',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      routes: {
        '/signUp': (context) =>  SignUpScreen(),
        '/signIn': (context) =>  SignInScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        '/inforUser': (context) => const InforUserScreen(),
        '/forgotPassword': (context) => const ForgotPasswordScreen(),
        '/homedrawer': (context) => const DrawerScreen(),
        '/home': (context) => const HomeScreen(),
        '/chooseCourse': (context) => const ChooseCourseScreen(),
        '/course': (context) => const CourseScreen(),
        '/grammar': (context) => const GrammarScreen(),
        '/flashcards': (context) => const FlashcardsScreen(),
        '/settings': (context) => const SettingScreen(),
      },
    );
  }
}