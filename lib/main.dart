import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/register_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MogurApp());
}

class MogurApp extends StatelessWidget {
  const MogurApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mogur App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0077C2)),
        useMaterial3: true,
        fontFamily: 'Roboto', 
      ),
      home: const AnimatedSplashScreen(),
    );
  }
}

class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.repeat(reverse: true);

    _checkSecurityAndNavigate();
  }

  Future<void> _checkSecurityAndNavigate() async {
    await Future.delayed(const Duration(seconds: 3));

    Widget nextScreen;
    
    // 1. Cek Sesi Auth di HP
    final user = AuthService.currentUser;

    if (user != null && user.emailVerified) {
      nextScreen = const MainNavigation(); // Langsung Dashboard
    } else {
      // 2. Cek Database Global (Sudah ada pemilik belum?)
      bool hasOwner = await ApiService.checkAnyUserExists();

      if (hasOwner) {
        nextScreen = const LoginScreen(); // Sudah ada -> Login
      } else {
        nextScreen = const RegisterScreen(); // Kosong -> Register
      }
    }

    _controller.stop();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => nextScreen,
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 800),
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Image.asset(
              'assets/logo_mogur.png',
              width: 200,
            ),
          ),
        ),
      ),
    );
  }
}