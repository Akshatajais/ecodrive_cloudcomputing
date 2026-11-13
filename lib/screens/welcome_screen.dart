import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import '../widgets/eco_drive_logo.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, this.initialRegister = false});

  final bool initialRegister;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  late bool _isLogin;
  bool _obscure = true;
  bool _rememberMe = true;

  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _regPasswordCtrl = TextEditingController();
  final _carCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isLogin = !widget.initialRegister;
    _loadRememberedUsername();
  }

  Future<void> _loadRememberedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_me') ?? true;
    final saved = prefs.getString('remembered_username') ?? '';
    if (!mounted) return;
    setState(() {
      _rememberMe = remember;
      if (remember && saved.isNotEmpty) {
        _usernameCtrl.text = saved;
      }
    });
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _regPasswordCtrl.dispose();
    _carCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(
      username: _usernameCtrl.text,
      password: _passwordCtrl.text,
    );
    if (!mounted) return;
    if (ok) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', _rememberMe);
      if (_rememberMe) {
        await prefs.setString(
          'remembered_username',
          _usernameCtrl.text.trim(),
        );
      } else {
        await prefs.remove('remembered_username');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Login failed'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submitRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      name: _nameCtrl.text,
      phone: _phoneCtrl.text,
      password: _regPasswordCtrl.text,
      carNumber: _carCtrl.text,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Registration failed'),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<AuthProvider>().isBusy;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _AuthBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 16,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      const EcoDriveLogo(
                        size: 78,
                        showWordmark: true,
                        showTagline: true,
                      ),
                      const SizedBox(height: 22),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _AuthTabs(
                              isLogin: _isLogin,
                              onLogin: () => setState(() => _isLogin = true),
                              onRegister: () =>
                                  setState(() => _isLogin = false),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              _isLogin ? 'Welcome Back!' : 'Create Account',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF1B5E20),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isLogin
                                  ? 'Sign in to access your EcoDrive account'
                                  : 'Register to start monitoring emissions',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF689F38),
                              ),
                            ),
                            const SizedBox(height: 18),
                            if (_isLogin)
                              _LoginForm(
                                formKey: _loginFormKey,
                                usernameCtrl: _usernameCtrl,
                                passwordCtrl: _passwordCtrl,
                                obscure: _obscure,
                                rememberMe: _rememberMe,
                                busy: busy,
                                onToggleObscure: () =>
                                    setState(() => _obscure = !_obscure),
                                onRememberChanged: (v) =>
                                    setState(() => _rememberMe = v ?? true),
                                onSubmit: _submitLogin,
                                onSwitchRegister: () =>
                                    setState(() => _isLogin = false),
                              )
                            else
                              _RegisterForm(
                                formKey: _registerFormKey,
                                nameCtrl: _nameCtrl,
                                phoneCtrl: _phoneCtrl,
                                passwordCtrl: _regPasswordCtrl,
                                carCtrl: _carCtrl,
                                obscure: _obscure,
                                busy: busy,
                                onToggleObscure: () =>
                                    setState(() => _obscure = !_obscure),
                                onSubmit: _submitRegister,
                                onSwitchLogin: () =>
                                    setState(() => _isLogin = true),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthTabs extends StatelessWidget {
  const _AuthTabs({
    required this.isLogin,
    required this.onLogin,
    required this.onRegister,
  });

  final bool isLogin;
  final VoidCallback onLogin;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              selected: isLogin,
              icon: Icons.person_outline_rounded,
              label: 'Login',
              onTap: onLogin,
            ),
          ),
          Expanded(
            child: _TabButton(
              selected: !isLogin,
              icon: Icons.person_add_alt_1_rounded,
              label: 'Register',
              onTap: onRegister,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDCEDC8) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected
                  ? const Color(0xFF1B5E20)
                  : const Color(0xFF7CB342),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? const Color(0xFF1B5E20)
                    : const Color(0xFF7CB342),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.usernameCtrl,
    required this.passwordCtrl,
    required this.obscure,
    required this.rememberMe,
    required this.busy,
    required this.onToggleObscure,
    required this.onRememberChanged,
    required this.onSubmit,
    required this.onSwitchRegister,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController usernameCtrl;
  final TextEditingController passwordCtrl;
  final bool obscure;
  final bool rememberMe;
  final bool busy;
  final VoidCallback onToggleObscure;
  final ValueChanged<bool?> onRememberChanged;
  final VoidCallback onSubmit;
  final VoidCallback onSwitchRegister;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          TextFormField(
            controller: usernameCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: authFieldDecoration(
              hint: 'Phone number',
              icon: Icons.phone_outlined,
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter phone number' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: passwordCtrl,
            obscureText: obscure,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSubmit(),
            decoration: authFieldDecoration(
              hint: 'Password',
              icon: Icons.lock_outline_rounded,
              suffix: IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF7CB342),
                ),
              ),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Enter password' : null,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: rememberMe,
                  onChanged: onRememberChanged,
                  activeColor: const Color(0xFF2E7D32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Remember me',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF558B2F),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Use your registered phone number to sign in.',
                        style: GoogleFonts.poppins(),
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Forgot Password?',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _GradientButton(
            label: 'Login',
            busy: busy,
            onPressed: onSubmit,
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: "Don't have an account? ",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: onSwitchRegister,
                    child: Text(
                      'Register',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RegisterForm extends StatelessWidget {
  const _RegisterForm({
    required this.formKey,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.passwordCtrl,
    required this.carCtrl,
    required this.obscure,
    required this.busy,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onSwitchLogin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController passwordCtrl;
  final TextEditingController carCtrl;
  final bool obscure;
  final bool busy;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final VoidCallback onSwitchLogin;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          TextFormField(
            controller: nameCtrl,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: authFieldDecoration(
              hint: 'Full name',
              icon: Icons.badge_outlined,
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter name' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: authFieldDecoration(
              hint: 'Phone number',
              icon: Icons.phone_outlined,
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter phone';
              if (v.replaceAll(RegExp(r'\D'), '').length < 8) {
                return 'Enter a valid phone number';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: passwordCtrl,
            obscureText: obscure,
            textInputAction: TextInputAction.next,
            decoration: authFieldDecoration(
              hint: 'Password',
              icon: Icons.lock_outline_rounded,
              suffix: IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF7CB342),
                ),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter password';
              if (v.length < 4) return 'At least 4 characters';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: carCtrl,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSubmit(),
            decoration: authFieldDecoration(
              hint: 'Car number',
              icon: Icons.directions_car_outlined,
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter car number' : null,
          ),
          const SizedBox(height: 18),
          _GradientButton(
            label: 'Register',
            busy: busy,
            onPressed: onSubmit,
          ),
          const SizedBox(height: 16),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Already have an account? ',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: onSwitchLogin,
                    child: Text(
                      'Login',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF66BB6A), Color(0xFF2E7D32)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2E7D32).withValues(alpha: 0.28),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

InputDecoration authFieldDecoration({
  required String hint,
  required IconData icon,
  Widget? suffix,
}) {
  return InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, color: const Color(0xFF7CB342)),
    suffixIcon: suffix,
    filled: true,
    fillColor: const Color(0xFFF7FBF2),
    hintStyle: GoogleFonts.poppins(
      color: Colors.grey[500],
      fontSize: 13,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: const BorderSide(color: Color(0xFF66BB6A), width: 1.5),
    ),
  );
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'lib/assets/auth_background.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFFEAF6E0),
          ),
        ),
        // Soft wash so the form stays readable over the illustration.
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0.05),
                Colors.white.withValues(alpha: 0.28),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
