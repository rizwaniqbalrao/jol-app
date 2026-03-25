import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:jol_app/screens/auth/controllers/auth_controller.dart';
import 'package:jol_app/screens/auth/services/deep_link_service.dart';
import 'package:jol_app/screens/auth/login_screen.dart';
import 'package:jol_app/screens/auth/verification_screen.dart';
import 'package:jol_app/screens/auth/reset_password_confirm_screen.dart';
import 'package:jol_app/screens/settings/change_password_screen.dart';
import 'package:jol_app/screens/dashboard/dashboard_screen.dart';
import 'package:jol_app/screens/play/controller/game_controller.dart';
import 'package:jol_app/screens/splash_screen.dart';
import 'package:jol_app/utils/app_routes.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';

// Add this at the top level (outside any class)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  MobileAds.instance.initialize();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 🔒 Lock app to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ChangeNotifierProvider(
      create: (_) => GameController(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'JOL APP',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      initialBinding: BindingsBuilder(() {
        Get.put(AuthController(), permanent: true);
        Get.put(DeepLinkService(), permanent: true);
      }),
      home: const SplashScreen(),
      getPages: [
        GetPage(name: AppRoutes.home, page: () => const DashboardScreen()),
        GetPage(name: AppRoutes.login, page: () => const LoginScreen()),
        GetPage(
            name: AppRoutes.verifyEmail,
            page: () => const VerificationScreen()),
        GetPage(
            name: AppRoutes.resetPasswordConfirm,
            page: () => const ResetPasswordConfirmScreen()),
        GetPage(
            name: AppRoutes.changePassword,
            page: () => const ChangePasswordScreen()),
        // We will add other pages as we refactor them
      ],
    );
  }
}
