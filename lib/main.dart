import 'package:flutter/material.dart';
import 'package:learning_english/core/config/supabase_config.dart';
import 'package:learning_english/helpers/notification_helper.dart';
import 'package:learning_english/screens/course/choose_course_screen.dart';
import 'package:learning_english/screens/course/course_lesson_detail_screen.dart';
import 'package:learning_english/screens/course/course_lessons_screen.dart';
import 'package:learning_english/screens/course/course_modules_screen.dart';
import 'package:learning_english/screens/course/final_test_screen.dart';
import 'package:learning_english/screens/course/placement_test_screen.dart';
import 'package:learning_english/screens/course/reading_lesson_screen.dart';
import 'package:learning_english/screens/drawer_screen.dart';
import 'package:learning_english/screens/auth/forgot_password_screen.dart';
import 'package:learning_english/screens/home_screen.dart';
import 'package:learning_english/screens/profile/infor_user_screen.dart';
import 'package:learning_english/screens/course/course_screen.dart';
import 'package:learning_english/screens/grammar/grammar_screen.dart';
import 'package:learning_english/screens/auth/signIn_screen.dart';
import 'package:learning_english/screens/auth/signUp_screen.dart';
import 'package:learning_english/screens/welcome_screen.dart';
import 'package:learning_english/services/auth_service.dart'; // Import AuthService
import 'dart:async';

import 'package:learning_english/services/google_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';


void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  //initialize Supabase
  await SupabaseConfig.initialize();

  // Initialize Google Sign In
  final googleAuth = GoogleAuthService();
  await googleAuth.initialize();
  await NotificationHelper().initialize();

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
      initialRoute: widget.isLoggedIn ? '/welcome' : '/signIn',
      routes: {
        '/signUp': (context) => SignUpScreen(),
        '/signIn': (context) => SignInScreen(),
        '/welcome': (context) => WelcomeScreen(),
        '/inforUser': (context) => InforUserScreen(),
        '/forgotPassword': (context) => ForgotPasswordScreen(),
        '/homedrawer': (context) => DrawerScreen(),
        '/home': (context) => const HomeScreen(),
        '/grammar': (context) => const GrammarScreen(),
        '/chooseCourse': (context) => const ChooseCourseScreen(),
        '/placementTest': (context) => const PlacementTestScreen(),
        '/courses': (context) => const CourseScreen(),
        '/courseModules': (context) {
          // ✅ Lấy courseId từ arguments
          final args = ModalRoute.of(context)?.settings.arguments as Map?;
          final courseId = args?['courseId'] as String?;
          
          if (courseId == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Lỗi')),
              body: const Center(child: Text('Course ID không tìm thấy')),
            );
          }

          return CourseModulesScreen(courseId: courseId);
        },
        '/courseLessons': (context) {
          // ✅ Lấy moduleId từ arguments
          final args = ModalRoute.of(context)?.settings.arguments as Map?;
          final moduleId = args?['moduleId'] as String?;
          
          if (moduleId == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Lỗi')),
              body: const Center(child: Text('Module ID không tìm thấy')),
            );
          }

          return CourseLessonsScreen(moduleId: moduleId);
        },
        '/lessonDetail': (context) {
        final args = ModalRoute.of(context)?.settings.arguments as Map?;
        final lessonId = args?['lessonId'] as String?;
        
        if (lessonId == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Lỗi')),
            body: const Center(child: Text('Lesson ID không tìm thấy')),
          );
        }

        return CourseLessonDetailScreen(lessonId: lessonId);
      },
        '/final-test': (context) {
        final args = ModalRoute.of(context)?.settings.arguments as Map?;
        return FinalTestScreen(
          testId: args?['testId'] ?? '',
          lessonId: args?['lessonId'],
          isPlacementTest: false, // ✅ Lesson test
          targetScore: args?['targetScore'] as double?,
        );
      },
      '/readingLesson': (context) {
        final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
        final lessonId = args['lessonId'] as String;
        
        return ReadingLessonScreen(lessonId: lessonId);
      },
      
      },
    );
  }
}