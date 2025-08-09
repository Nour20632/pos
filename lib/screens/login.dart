import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mk_optique/services/auth_service.dart';
import 'package:provider/provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _animationController;
  late AnimationController _logoController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _logoAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _logoAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _animationController.forward();
    _logoController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _logoController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDesktop = screenSize.width > 768;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E3A8A), // Blue 800
              Color(0xFF3B82F6), // Blue 500
              Color(0xFF60A5FA), // Blue 400
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isDesktop ? 40 : 24),
              child: AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildLoginCard(isDesktop),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard(bool isDesktop) {
    return Container(
      width: isDesktop ? 500 : double.infinity,
      padding: EdgeInsets.all(isDesktop ? 48 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo and Title Section
            _buildLogoSection(),
            SizedBox(height: isDesktop ? 40 : 32),

            // Form Fields
            _buildFormFields(),
            SizedBox(height: isDesktop ? 32 : 24),

            // Login Button
            _buildLoginButton(),
            SizedBox(height: isDesktop ? 24 : 16),

            // Footer
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Column(
      children: [
        // Animated Logo with MK Optique branding
        AnimatedBuilder(
          animation: _logoAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _logoAnimation.value,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glasses icon styled as MK logo
                    Icon(
                      Icons.remove_red_eye_outlined,
                      color: Colors.white,
                      size: 50,
                    ),
                    // MK text overlay
                    Positioned(
                      bottom: 15,
                      child: Text(
                        'MK',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),

        // Title and Subtitle
        const Text(
          'MK OPTIQUE',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A8A),
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Système de Gestion Moderne',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF6B7280),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 60,
          height: 3,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        // Username Field
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextFormField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Nom d\'utilisateur',
              prefixIcon: Icon(Icons.person_outline, color: Color(0xFF64748B)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(20),
              labelStyle: TextStyle(color: Color(0xFF64748B)),
            ),
            validator: (value) =>
                value?.isEmpty == true ? 'Nom d\'utilisateur requis' : null,
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(height: 20),

        // Password Field
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              prefixIcon: const Icon(
                Icons.lock_outline,
                color: Color(0xFF64748B),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFF64748B),
                ),
                onPressed: () => setState(() {
                  _obscurePassword = !_obscurePassword;
                }),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(20),
              labelStyle: const TextStyle(color: Color(0xFF64748B)),
            ),
            validator: (value) =>
                value?.isEmpty == true ? 'Mot de passe requis' : null,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _login(),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.login, color: Colors.white),
                  SizedBox(width: 12),
                  Text(
                    'Se connecter',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF64748B), size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Utilisez vos identifiants fournis par l\'administrateur',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '© 2024 MK OPTIQUE - Tous droits réservés',
          style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final success = await context.read<AuthService>().login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        final user = context.read<AuthService>().currentUser;
        // Navigation based on user role
        if (user?.role == 'employe') {
          context.push('/seller-dashboard');
        } else {
          context.push('/dashboard');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Text('Nom d\'utilisateur ou mot de passe incorrect'),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }
}
