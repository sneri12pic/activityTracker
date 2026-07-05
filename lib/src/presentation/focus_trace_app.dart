import 'package:flutter/material.dart';

import 'screens/onboarding_screen.dart';

class FocusTraceApp extends StatelessWidget {
  const FocusTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FocusTrace',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5BC0EB),
          brightness: Brightness.dark,
          surface: const Color(0xFF070A10),
        ),
        scaffoldBackgroundColor: const Color(0xFF070A10),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF070A10),
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const OnboardingGate(),
    );
  }
}
