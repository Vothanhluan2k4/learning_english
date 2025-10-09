import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:learning_english/core/supabase_config.dart';
import 'package:learning_english/core/uni_links.dart';
import 'package:learning_english/screens/drawer_screen.dart';
import 'package:learning_english/screens/forgot_password_screen.dart';
import 'package:learning_english/screens/home_screen.dart';
import 'package:learning_english/screens/setting_screen.dart';
import 'package:learning_english/screens/flashcards_screen.dart';
import 'package:learning_english/screens/course_screen.dart';
import 'package:learning_english/screens/grammar_screen.dart';
import 'package:learning_english/screens/signIn_screen.dart';
import 'package:learning_english/screens/signUp_screen.dart';
import 'package:learning_english/screens/verify_otp_screen.dart' hide ForgotPasswordScreen;
import 'package:learning_english/screens/welcome_screen.dart';
import 'package:learning_english/service/auth_service.dart'; // Import AuthService
import 'dart:async';

import 'package:learning_english/service/google_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';


void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  //initialize Supabase
  await SupabaseConfig.initialize();
  final deepLinkService = DeepLinkService();
  await deepLinkService.initDeepLinks();

  // Initialize Google Sign In
  final googleAuth = GoogleAuthService();
  await googleAuth.initialize();


  runApp( MyApp(isLoggedIn: isLoggedIn));
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
  final _appLinks =  AppLinks();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    Future.delayed(Duration(seconds: 1), () {
      _checkLoginExpiry();
    });

    _expiryCheckTimer = Timer.periodic(
      Duration(hours: 1),
          (timer) => _checkLoginExpiry(),
    );

  }


  //Auth Check Login
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
        _navigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/signIn',
              (route) => false,
        );

        // Hiển thị thông báo
        final context = _navigatorKey.currentContext;
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
      navigatorKey: _navigatorKey,
      title: 'Lun English',
      theme: ThemeData(primaryColor: Colors.blue[450]),
      initialRoute: widget.isLoggedIn ? '/welcome' : '/signIn',
      routes: {
        '/signUp': (context) => SignUpScreen(),
        '/signIn': (context) => SignInScreen(),
        '/welcome': (context) => WelcomeScreen(),
        '/forgotPassword': (context) => ForgotPasswordScreen(),
        '/homedrawer': (context) => DrawerScreen(),
        '/home': (context) => const HomeScreen(),

      },
    );
  }
}