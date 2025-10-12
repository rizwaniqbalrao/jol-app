import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 👈 Add this
import 'package:jol_app/screens/auth/login_screen.dart';
import 'package:jol_app/screens/auth/signup_screen.dart';
import 'package:jol_app/screens/bnb/home_screen.dart';
import 'package:jol_app/screens/dashboard/dashboard_screen.dart';
import 'package:jol_app/screens/dashboard/notification_screen.dart';
import 'package:jol_app/screens/group/group_screen.dart';
import 'package:jol_app/screens/onboarding/onboarding_screen.dart';
import 'package:jol_app/screens/play/game_screen.dart';
import 'package:jol_app/screens/play/paly_screen.dart';
import 'package:jol_app/screens/play/result_screen.dart';
import 'package:jol_app/screens/play/start_game_screen.dart';
import 'package:jol_app/screens/play/submit_game_screen.dart';
import 'package:jol_app/screens/settings/account_screen.dart';
import 'package:jol_app/screens/settings/choose_color_screen.dart';
import 'package:jol_app/screens/settings/coupons_screen.dart';
import 'package:jol_app/screens/settings/edit_profile_screen.dart';
import 'package:jol_app/screens/settings/monetization_screen.dart';
import 'package:jol_app/screens/settings/money_screen.dart';
import 'package:jol_app/screens/settings/remove_adds_screen.dart';
import 'package:jol_app/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // 👈 Required before SystemChrome

  // 🔒 Lock app to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JOL APP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: GameScreen(),
    );
  }
}
