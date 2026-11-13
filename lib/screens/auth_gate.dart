import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import 'welcome_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.home});

  final Widget home;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.isLoading) {
          return Scaffold(
            backgroundColor: Colors.green[600],
            body: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }
        if (!auth.isLoggedIn) {
          return const WelcomeScreen();
        }
        return widget.home;
      },
    );
  }
}
