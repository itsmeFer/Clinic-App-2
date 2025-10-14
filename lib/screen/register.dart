import 'dart:async';
import 'dart:convert';
import 'package:RoyalClinic/screen/login.dart';
import 'package:RoyalClinic/pasien/dashboardScreen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with TickerProviderStateMixin {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> registerUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_agreeToTerms) {
      _showErrorSnackBar('Anda harus menyetujui syarat dan ketentuan');
      return;
    }

    final username = usernameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    setState(() => isLoading = true);

    try {
      print('Starting registration for user: $username');
      
      // Register the user
      final response = await http.post(
        Uri.parse('https://admin.royal-klinik.cloud/api/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
        }),
      );

      print('Registration response status: ${response.statusCode}');
      
      final data = jsonDecode(response.body);
      print('Registration response data: $data');

      if ((response.statusCode == 200 || response.statusCode == 201) && data['success'] == true) {
        print('Registration successful, starting auto-login');
        
        // Auto login after successful registration
        await _autoLogin(username, password);
        
      } else {
        print('Registration failed: ${data['message']}');
        setState(() => isLoading = false);
        _showErrorSnackBar(data['message'] ?? 'Registrasi gagal');
      }
    } catch (e) {
      print('Registration error: $e');
      setState(() => isLoading = false);
      _showErrorSnackBar('Terjadi kesalahan koneksi. Silakan coba lagi.');
    }
  }

  Future<void> _autoLogin(String username, String password) async {
    try {
      print('Starting auto-login process');
      
      final response = await http.post(
        Uri.parse('https://admin.royal-klinik.cloud/api/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'username': username, 'password': password}),
      );

      print('Auto-login response status: ${response.statusCode}');
      
      final data = jsonDecode(response.body);
      print('Auto-login response data: $data');

      if (response.statusCode == 200 && data['success'] == true) {
        print('Auto-login successful, saving user data');
        
        // Save login data to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['data']['token']);
        await prefs.setString('username', data['data']['user']['username']);
        await prefs.setString('role', data['data']['user']['role']);
        await prefs.setInt('user_id', data['data']['user']['id']);

        // Get profile data for pasien
        try {
          print('Fetching user profile');
          final profileResponse = await http.get(
            Uri.parse('https://admin.royal-klinik.cloud/api/pasien/profile'),
            headers: {
              'Authorization': 'Bearer ${data['data']['token']}',
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          );

          print('Profile response status: ${profileResponse.statusCode}');

          if (profileResponse.statusCode == 200) {
            final profileData = jsonDecode(profileResponse.body)['data'];
            await prefs.setInt('pasien_id', profileData['id']);
            print('Profile data saved successfully');
          }
        } catch (e) {
          print('Profile fetch failed: $e');
          // Continue even if profile fetch fails
        }

        // Stop loading state first
        if (mounted) {
          setState(() => isLoading = false);
        }

        // Show success message
        _showSuccessSnackBar('Selamat datang di Royal Clinic, $username!');

        // Small delay to show success message
        await Future.delayed(const Duration(milliseconds: 1000));
        
        if (mounted) {
          print('Navigating to dashboard');
          // Navigate directly to dashboard with clear navigation stack
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const MainWrapper(),
            ),
            (route) => false, // Remove all previous routes
          );
        }
      } else {
        print('Auto-login failed: ${data['message'] ?? 'Unknown error'}');
        // Auto-login failed, show success message for registration but redirect to login
        if (mounted) {
          setState(() => isLoading = false);
        }
        _showRegistrationSuccessDialog();
      }
    } catch (e) {
      print('Auto-login error: $e');
      // Auto-login failed due to network error
      if (mounted) {
        setState(() => isLoading = false);
      }
      _showRegistrationSuccessDialog();
    }
  }

  void _showRegistrationSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF4CAF50),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Registrasi Berhasil',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          content: const Text(
            'Akun Anda telah berhasil didaftarkan. Silakan login untuk melanjutkan menggunakan aplikasi Royal Clinic.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
          actions: [
            Container(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  
                  // Navigate to login page
                  Navigator.of(context).pushReplacement(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(-1.0, 0.0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        );
                      },
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'OK, Login Sekarang',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 14))),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 14))),
          ],
        ),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String? _validateUsername(String? value) {
    if (value == null || value.isEmpty) {
      return 'Username tidak boleh kosong';
    }
    if (value.length < 3) {
      return 'Username minimal 3 karakter';
    }
    if (value.contains(' ')) {
      return 'Username tidak boleh mengandung spasi';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email tidak boleh kosong';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Format email tidak valid';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password tidak boleh kosong';
    }
    if (value.length < 6) {
      return 'Password minimal 6 karakter';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Konfirmasi password tidak boleh kosong';
    }
    if (value != passwordController.text) {
      return 'Password tidak sama';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FFFE),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isTablet ? 400 : double.infinity,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 32 : 24,
                vertical: 24,
              ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20),

                        // Header Section
                        _buildHeaderSection(isTablet),
                        
                        SizedBox(height: isTablet ? 40 : 32),

                        // Register Form Card
                        _buildRegisterForm(isTablet),
                        
                        SizedBox(height: isTablet ? 24 : 20),

                        // Login Link
                        _buildLoginLink(),
                        
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(bool isTablet) {
    return Column(
      children: [
        // Logo with Animation
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 1000),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                width: isTablet ? 90 : 70,
                height: isTablet ? 90 : 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00897B).withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Image.asset(
                    'assets/gambar/logo.png',
                    width: isTablet ? 62 : 42,
                    height: isTablet ? 62 : 42,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            );
          },
        ),
        
        SizedBox(height: isTablet ? 20 : 16),
        
        // Title
        Text(
          'Daftar Akun',
          style: TextStyle(
            fontSize: isTablet ? 28 : 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF00897B),
            letterSpacing: 0.5,
          ),
        ),
        
        SizedBox(height: isTablet ? 8 : 6),
        
        Text(
          'Bergabunglah dengan Royal Clinic',
          style: TextStyle(
            fontSize: isTablet ? 16 : 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm(bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 28 : 20),
        child: Column(
          children: [
            // Username Field
            _buildTextField(
              controller: usernameController,
              label: 'Username',
              hint: 'Masukkan username unik',
              icon: Icons.person_outline,
              validator: _validateUsername,
              isTablet: isTablet,
            ),
            
            SizedBox(height: isTablet ? 20 : 16),
            
            // Email Field
            _buildTextField(
              controller: emailController,
              label: 'Email',
              hint: 'Masukkan alamat email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
              isTablet: isTablet,
            ),
            
            SizedBox(height: isTablet ? 20 : 16),
            
            // Password Field
            _buildTextField(
              controller: passwordController,
              label: 'Password',
              hint: 'Minimal 6 karakter',
              icon: Icons.lock_outline,
              obscureText: _obscurePassword,
              validator: _validatePassword,
              isTablet: isTablet,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey.shade500,
                  size: isTablet ? 22 : 20,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),
            
            SizedBox(height: isTablet ? 20 : 16),
            
            // Confirm Password Field
            _buildTextField(
              controller: confirmPasswordController,
              label: 'Konfirmasi Password',
              hint: 'Masukkan ulang password',
              icon: Icons.lock_outline,
              obscureText: _obscureConfirmPassword,
              validator: _validateConfirmPassword,
              isTablet: isTablet,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey.shade500,
                  size: isTablet ? 22 : 20,
                ),
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),
            ),
            
            SizedBox(height: isTablet ? 16 : 12),
            
            // Terms & Conditions
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _agreeToTerms,
                    onChanged: (value) {
                      setState(() {
                        _agreeToTerms = value ?? false;
                      });
                    },
                    activeColor: const Color(0xFF00897B),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _agreeToTerms = !_agreeToTerms;
                      });
                    },
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: isTablet ? 13 : 12,
                          color: Colors.grey.shade700,
                        ),
                        children: [
                          const TextSpan(text: 'Saya menyetujui '),
                          TextSpan(
                            text: 'Syarat & Ketentuan',
                            style: TextStyle(
                              color: const Color(0xFF00897B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const TextSpan(text: ' dan '),
                          TextSpan(
                            text: 'Kebijakan Privasi',
                            style: TextStyle(
                              color: const Color(0xFF00897B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: isTablet ? 28 : 20),
            
            // Register Button
            _buildRegisterButton(isTablet),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    required bool isTablet,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTablet ? 15 : 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: isTablet ? 15 : 14,
            color: Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: isTablet ? 14 : 13,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF00897B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF00897B),
                size: isTablet ? 20 : 18,
              ),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF00897B), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: isTablet ? 16 : 14,
            ),
            errorStyle: TextStyle(
              fontSize: isTablet ? 12 : 11,
              color: Colors.red.shade600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton(bool isTablet) {
    return Container(
      width: double.infinity,
      height: isTablet ? 52 : 46,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFF00897B), Color(0xFF4DB6AC)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00897B).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isLoading ? null : registerUser,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: isTablet ? 20 : 16,
                    width: isTablet ? 20 : 16,
                    child: const CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Mendaftarkan...',
                    style: TextStyle(
                      fontSize: isTablet ? 15 : 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              )
            : Text(
                'Daftar Sekarang',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'atau',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),
        
        const SizedBox(height: 20),
        
        // Login Link Button
        Container(
          width: double.infinity,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF00897B), width: 1.5),
          ),
          child: TextButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(-1.0, 0.0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    );
                  },
                ),
              );
            },
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.login_outlined,
                  color: const Color(0xFF00897B),
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Sudah Punya Akun? Login',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF00897B),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // App Info
        Text(
          'Royal Clinic Mobile App v1.0.0',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade400,
          ),
        ),
      ],
    );
  }
}