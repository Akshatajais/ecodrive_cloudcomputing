import 'package:flutter/material.dart';

import 'welcome_screen.dart';

/// Kept for navigation compatibility — opens the unified auth screen on Login.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const WelcomeScreen(initialRegister: false);
  }
}
