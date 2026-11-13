import 'package:flutter/material.dart';

import 'welcome_screen.dart';

/// Kept for navigation compatibility — opens the unified auth screen on Register.
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const WelcomeScreen(initialRegister: true);
  }
}
