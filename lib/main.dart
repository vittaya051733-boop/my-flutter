import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'email_verification_helper.dart';
import 'email_verification_screen.dart';
import 'phone_auth_screen.dart';
import 'firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'dart:async'; // เพิ่ม: จัดการ async error/timeout ให้ไม่ทำให้แอปเด้ง
import 'register_shop_blank.dart';
import 'contract_screen.dart';
import 'shop_registration_screen.dart';
import 'post_verification_intro_screen.dart';
import 'navigation_helper.dart';
import 'utils/app_colors.dart';
import 'services/notification_service.dart';

// เพิ่ม: สวิตช์บังคับใช้ App Check Debug ผ่าน --dart-define=APP_CHECK_DEBUG=true
const bool kAppCheckForceDebug =
    bool.fromEnvironment('APP_CHECK_DEBUG', defaultValue: false);

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // ดักจับ error ระดับเฟรมเวิร์ก (ไม่ให้แอปหลุด)
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
    };

    // ดักจับ error ระดับ engine/แพลตฟอร์ม ให้ไม่ทำให้แอปเด้ง
    WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
      // สามารถส่ง log ไปเก็บได้ที่นี่
      return true; // กลืน error ไว้
    };

    // แทน ErrorWidget (จอแดง) ด้วย widget เงียบๆ เพื่อไม่ให้ผู้ใช้เห็น error
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return const SizedBox.shrink();
    };

    try {
      // ป้องกันการ initialize ซ้ำ (เช่นตอน hot restart)
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (e) {
      final msg = e.toString();
      // ถ้าเป็น duplicate-app ให้ข้ามและใช้อินสแตนซ์เดิม
      if (!(msg.contains('duplicate-app') || msg.contains('already exists'))) {
        runApp(ErrorApp(error: msg));
        return;
      }
    }

  // พยายามเปิดใช้ App Check แต่ถ้าล้มเหลว/ช้าเกินไป ให้ไปต่อได้
    try {
      await FirebaseAppCheck.instance
          .activate(
            // ถ้ากำหนด APP_CHECK_DEBUG=true จะบังคับใช้ Debug provider
            androidProvider: kAppCheckForceDebug
                ? AndroidProvider.debug
                : (kReleaseMode
                    ? AndroidProvider.playIntegrity
                    : AndroidProvider.debug),
          )
          .timeout(const Duration(seconds: 5)); // กันค้าง
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);

      // เพิ่ม: พิมพ์ Debug Token ออกมาใน Console ทุกครั้งที่แอปเริ่มทำงาน (เฉพาะ Debug Mode)
      if (kDebugMode) {
        FirebaseAppCheck.instance.onTokenChange.listen((token) {
          debugPrint('App Check Debug Token: $token');
        });
      }

      // พยายามดึงโทเคน (ช่วยให้เห็น debug token ใน log ครั้งแรก)
      try {
        await FirebaseAppCheck.instance
            .getToken(true)
            .timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('Could not get App Check token on startup: $e');
      }
    } catch (_) {
      // กลืนทุก error ของ App Check เพื่อให้แอปรันได้ก่อน
    }

    // Initialize FCM + Local Notifications
    try {
      await NotificationService().initialize();
    } catch (e) {
      debugPrint('Notification init error: $e');
    }

    runApp(const MyApp());
  }, (error, stack) {
    // เก็บ/แสดง log ได้ตามต้องการ
  });
}

// A simple widget to display a critical error, like Firebase failing to initialize.
class ErrorApp extends StatelessWidget {
  final String error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Firebase Initialization Error')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Error initializing Firebase:',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                ),
                SizedBox(height: 8),
                Text(error),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const String appFontFamily = 'Prompt';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Van Merchant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.light,
        ),
        // Set the global font family once (cheaper than applying a TextTheme each build)
        fontFamily: appFontFamily,
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          titleTextStyle: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          centerTitle: true,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: AppColors.accentDark,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: AppColors.accent,
          actionTextColor: Colors.white,
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      routes: {
        '/login': (context) {
          final serviceType = ModalRoute.of(context)?.settings.arguments as String?;
          return LoginScreen(serviceType: serviceType);
        },
        '/register': (context) {
          final serviceType = ModalRoute.of(context)?.settings.arguments as String?;
          return RegisterScreen(serviceType: serviceType);
        },
        '/forgot': (context) => const ForgotPasswordScreen(),
        '/phone_auth': (context) => const PhoneAuthScreen(),
        '/email-verification': (context) => const EmailVerificationScreen(),
        '/email-helper': (context) {
          final email = ModalRoute.of(context)?.settings.arguments as String?;
          return EmailVerificationHelper(prefilledEmail: email);
        },
        '/post-verification-intro': (context) {
          final serviceType = ModalRoute.of(context)?.settings.arguments as String?;
          return PostVerificationIntroScreen(serviceType: serviceType);
        },
        '/contract-intro': (context) => const RegisterShopBlankScreen(),
        '/contract': (context) {
          final serviceType = ModalRoute.of(context)?.settings.arguments as String?;
          return ContractScreen(serviceType: serviceType);
        },
        '/shop-registration': (context) {
          final serviceType = ModalRoute.of(context)?.settings.arguments as String?;
          return ShopRegistrationScreen(serviceType: serviceType);
        },
        '/home': (context) => const HomeScreen(),
      },
      home: StreamBuilder<User?>(
        // กลืน error ของสตรีม Auth เพื่อให้ไม่ทำให้แอปเด้ง
        stream: FirebaseAuth.instance.authStateChanges().handleError((e, stackTrace) {
          // Log the error for debugging purposes, but don't crash the app.
          debugPrint('Error in authStateChanges stream: $e');
          // การคืนค่า null จะทำให้ StreamBuilder เข้าเงื่อนไข snapshot.hasData == false
          // และแสดง WelcomeScreen ซึ่งปลอดภัยกว่าการปล่อยให้แอปแครช
        }, test: (e) => true), // ดักจับ error ทุกประเภท
        builder: (context, snapshot) {
          // ถ้าเกิด error จาก Firebase (เช่น App Check invalid) ให้ไปหน้า Login ชั่วคราว
          if (snapshot.hasError) {
            return const WelcomeScreen();
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          return snapshot.hasData ? const AuthWrapper() : const WelcomeScreen();
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && mounted) {
      // ใช้ NavigationHelper เพื่อตรวจสอบและนำทาง
      // การใช้ replace: true จะแทนที่หน้าจอปัจจุบัน (AuthWrapper)
      // เพื่อไม่ให้ผู้ใช้กด back กลับมาหน้านี้ได้
      await NavigationHelper.navigateBasedOnUserStatus(context, user, replace: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // แสดงหน้าจอ Loading ขณะกำลังตรวจสอบและนำทาง
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('กำลังตรวจสอบข้อมูล...'),
          ],
        ),
      ),
    );
  }
}

