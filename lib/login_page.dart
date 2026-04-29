import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:ui';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'widgets/animated_background.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _userIdController = TextEditingController();
  final _passwordController = TextEditingController();

  final _userIdFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  late AnimationController _entryController;
  late AnimationController _buttonController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _scaleAnim;

  bool _isObscure = true;
  bool _isLoggingIn = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      lowerBound: 0.95,
      upperBound: 1.0,
      value: 1.0,
    );

    _fadeAnim = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
        );

    _scaleAnim = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutBack,
    );

    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _buttonController.dispose();
    _userIdController.dispose();
    _passwordController.dispose();
    _userIdFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    // Play button animation
    await _buttonController.reverse();
    await _buttonController.forward();

    setState(() {
      _isLoggingIn = true;
      _errorMessage = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse('https://display.sriher.com/loginvalidationview'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'api_key':
                  '933cdb13cb54e31e694f82bf7f75f0144a9495036db0243b85dd855be53c06f2',
              'user_id': _userIdController.text.trim(),
              'password': _passwordController.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bool success =
            data is Map &&
            (data['status']?.toString().toLowerCase() == 'success' ||
                data['Success']?.toString().toLowerCase() == 'success');

        if (success) {
          final userInfo = data['data'];
          String name = "User";
          String role = "Admin";

          if (userInfo is Map) {
            name =
                userInfo['user_name']?.toString() ??
                userInfo['username']?.toString() ??
                userInfo['name']?.toString() ??
                userInfo['user_id']?.toString() ??
                _userIdController.text.trim();
            role = userInfo['role_name'] ?? userInfo['role'] ?? "Admin";
          } else if (data['username'] != null) {
            name = data['username'].toString();
          }

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('userName', name);
          await prefs.setString('userRole', role);

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const HomeScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  },
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        } else {
          setState(() {
            _errorMessage = data['message'] ?? "The Email or Password is wrong";
          });
        }
      } else {
        setState(() => _errorMessage = "Server error: ${response.statusCode}");
      }
    } catch (e) {
      _showError('Connection failed: $e');
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/login_bg.jpg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFF1F7FF).withOpacity(0.4),
                  Colors.white.withOpacity(0.1),
                ],
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: ScaleTransition(
                  scale: _scaleAnim,
                  child: _buildLoginCard(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginCard() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      margin: const EdgeInsets.symmetric(horizontal: 32.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE3F2FD), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.1),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      padding: const EdgeInsets.all(32.0),
      child: Form(
        key: _formKey,
        child:Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.7, end: 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (context, scale, child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: Image.asset(
        'assets/images/logo.png',
        height: 80, // 1. Slightly reduced height from 100 to 80
        errorBuilder: (c, e, s) => const Icon(
          Icons.display_settings,
          size: 40,
          color: Color(0xFF0D47A1),
        ),
      ),
    ),
    
    // 2. Add a specific (or even negative) gap here
 

    const Text(
      'Sign In',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Color(0xFF0D47A1),
        letterSpacing: 1.2,
      ),
    ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 6),
            const Text(
              'Welcome to SRIHER Display',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 28),
            _buildTextField(
              controller: _userIdController,
              hint: 'Email / User ID',
              icon: Icons.person_outline,
              focusNode: _userIdFocusNode,
              nextFocusNode: _passwordFocusNode,
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter your Email or User ID'
                  : null,
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _passwordController,
              hint: 'Password',
              icon: Icons.lock_outline,
              isPassword: true,
              focusNode: _passwordFocusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _isLoggingIn ? null : _handleLogin(),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Enter your password'
                  : null,
            ),
            const SizedBox(height: 15),
          ScaleTransition(
  scale: _buttonController,
  child: SizedBox(
    width: double.infinity,
    height: 50,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        // Use 8 for a modern, subtle curve. 
        // 4 is very sharp, 30 is a pill. 8-10 is the "sweet spot."
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8), 
        ),
        backgroundColor: const Color(0xFF0D47A1), // Professional SRIHER Navy
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      onPressed: _isLoggingIn ? null : _handleLogin,
      child: _isLoggingIn
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Colors.white,
                ),
              ),
            )
          : const Text(
              'Log in',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                letterSpacing: 2,
              ),
            ),
    ),
  ),
),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      validator: validator,
      controller: controller,
      focusNode: focusNode,
      obscureText: isPassword && _isObscure,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted ?? (nextFocusNode != null
          ? (_) => FocusScope.of(context).requestFocus(nextFocusNode)
          : null),
      style: const TextStyle(color: Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.black.withOpacity(0.35),
          fontSize: 13,
        ),
        prefixIcon: Icon(icon, color: Colors.blue.shade700, size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _isObscure ? Icons.visibility_off : Icons.visibility,
                  color: Colors.blue.shade300,
                  size: 18,
                ),
                onPressed: () => setState(() => _isObscure = !_isObscure),
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF1F7FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade100),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade100),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue.shade700, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
      ),
    );
  }
}
