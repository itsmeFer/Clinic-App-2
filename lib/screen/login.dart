import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:RoyalClinic/screen/register.dart';
import 'package:RoyalClinic/pasien/dashboardScreen.dart';
import 'package:RoyalClinic/dokter/dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:RoyalClinic/screen/forgetpass.dart';
import 'package:RoyalClinic/screen/forgetuser.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadSavedCredentials();
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

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUsername = prefs.getString('saved_username');
    final savedPassword = prefs.getString('saved_password');
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (rememberMe && savedUsername != null && savedPassword != null) {
      setState(() {
        usernameController.text = savedUsername;
        passwordController.text = savedPassword;
        _rememberMe = rememberMe;
      });
    }
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_username', usernameController.text);
      await prefs.setString('saved_password', passwordController.text);
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('saved_username');
      await prefs.remove('saved_password');
      await prefs.setBool('remember_me', false);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> loginUser() async {
    if (!_formKey.currentState!.validate()) return;

    final username = usernameController.text.trim();
    final password = passwordController.text.trim();

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://10.61.209.71:8000/api/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'username': username, 'password': password}),
      );

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body);
      } catch (_) {}

      if (response.statusCode == 200 && (data['success'] == true)) {
        await _saveCredentials();

        final token = data['data']['token'] as String;
        final user = data['data']['user'] as Map<String, dynamic>;
        final role = (user['role'] as String?)?.toLowerCase() ?? '';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await prefs.setString('username', user['username'] ?? '');
        await prefs.setString('role', user['role'] ?? '');
        await prefs.setInt('user_id', (user['id'] as num?)?.toInt() ?? 0);

        // Kalau pasien, ambil profile pasien_id
        if (role == 'pasien') {
          try {
            final profileResponse = await http.get(
              Uri.parse('http://10.61.209.71:8000/api/pasien/profile'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            );
            if (profileResponse.statusCode == 200) {
              final profileData = jsonDecode(profileResponse.body)['data'];
              await prefs.setInt(
                'pasien_id',
                (profileData['id'] as num?)?.toInt() ?? 0,
              );
            }
          } catch (_) {}
        }

        _showSuccessSnackBar('Selamat datang, ${user['username']}!');
        if (role == 'dokter') {
          // simpan juga sebagai token khusus dokter
          await prefs.setString('dokter_token', token);
          // sanity check: pastikan token valid untuk route dokter
          final meRes = await http.get(
            Uri.parse('http://10.61.209.71:8000/api/dokter/get-data-dokter'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
            },
          );
          if (meRes.statusCode != 200) {
            // fallback: gunakan endpoint login-dokter untuk dapat token yang “benar”
            await _loginAsDokter(username, password);
            return; // _loginAsDokter akan navigate sendiri
          }
        }
        if (!mounted) return;
        if (role == 'dokter') {
          // Kalau ingin verifikasi lagi via endpoint khusus dokter, panggil _loginAsDokter:
          // await _loginAsDokter(username, password); return;

          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, a, b) => const DokterDashboard(),
              transitionsBuilder: (context, a, b, child) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(a),
                child: child,
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, a, b) => const MainWrapper(),
              transitionsBuilder: (context, a, b, child) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(a),
                child: child,
              ),
            ),
          );
        }
        return;
      }

      // --- Error handling ---
      if (response.statusCode == 401) {
        // Akan berisi "Username salah" ATAU "Password salah"
        final msg = (data['message'] as String?) ?? 'Kredensial tidak valid';
        _showErrorSnackBar(msg);
      } else if (response.statusCode == 403) {
        _showErrorSnackBar((data['message'] as String?) ?? 'Akses ditolak');
      } else if (response.statusCode == 422) {
        final errors = (data['errors'] ?? {}) as Map<String, dynamic>;
        final msgs = <String>[];
        for (final k in ['username', 'password']) {
          if (errors[k] is List && (errors[k] as List).isNotEmpty) {
            msgs.add((errors[k] as List).first.toString());
          }
        }
        _showErrorSnackBar(
          msgs.isNotEmpty
              ? msgs.join('\n')
              : (data['message'] ?? 'Validasi gagal'),
        );
      } else {
        _showErrorSnackBar(
          (data['message'] as String?) ?? 'Login gagal. Silakan coba lagi.',
        );
      }
    } catch (e) {
      _showErrorSnackBar('Terjadi kesalahan koneksi. Silakan coba lagi.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loginAsDokter(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('http://10.61.209.71:8000/api/login-dokter'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'username': username, 'password': password}),
      );

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body);
      } catch (_) {}

      if (response.statusCode == 200 && data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        final dokterToken = data['data']['token'];

        await prefs.setString('token', dokterToken); // optional (biar seragam)
        await prefs.setString(
          'dokter_token',
          dokterToken,
        ); // >>> penting untuk area dokter
        await prefs.setString('username', data['data']['user']['username']);
        await prefs.setString('role', data['data']['user']['role']);
        await prefs.setInt('user_id', data['data']['user']['id']);

        // ... lanjut snackbar & navigate

        _showSuccessSnackBar(
          'Selamat datang, Dr. ${data['data']['user']['username']}!',
        );

        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, a, b) => const DokterDashboard(),
              transitionsBuilder: (context, a, b, child) => SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1, 0),
                  end: Offset.zero,
                ).animate(a),
                child: child,
              ),
            ),
          );
        }
      } else if (response.statusCode == 401) {
        // Bisa "Username salah" atau "Password salah"
        _showErrorSnackBar(
          (data['message'] as String?) ?? 'Kredensial tidak valid',
        );
      } else if (response.statusCode == 403) {
        _showErrorSnackBar((data['message'] as String?) ?? 'Akses ditolak');
      } else if (response.statusCode == 422) {
        final errors = (data['errors'] ?? {}) as Map<String, dynamic>;
        final msgs = <String>[];
        for (final k in ['username', 'password']) {
          if (errors[k] is List && (errors[k] as List).isNotEmpty) {
            msgs.add((errors[k] as List).first.toString());
          }
        }
        _showErrorSnackBar(
          msgs.isNotEmpty
              ? msgs.join('\n')
              : (data['message'] ?? 'Validasi gagal'),
        );
      } else {
        _showErrorSnackBar(data['message'] ?? 'Login dokter gagal');
      }
    } catch (e) {
      _showErrorSnackBar('Login dokter gagal. Silakan coba lagi.');
    }
  }

  Future<void> _loginAsPasien(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', data['data']['token']);
      await prefs.setString('username', data['data']['user']['username']);
      await prefs.setString('role', data['data']['user']['role']);
      await prefs.setInt('user_id', data['data']['user']['id']);

      final profileResponse = await http.get(
        Uri.parse('http://10.61.209.71:8000/api/pasien/profile'),
        headers: {
          'Authorization': 'Bearer ${data['data']['token']}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (profileResponse.statusCode == 200) {
        final profileData = jsonDecode(profileResponse.body)['data'];
        await prefs.setInt('pasien_id', profileData['id']);
      }

      _showSuccessSnackBar(
        'Selamat datang, ${data['data']['user']['username']}!',
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MainWrapper(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(1.0, 0.0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  );
                },
          ),
        );
      }
    } catch (e) {
      _showErrorSnackBar('Login gagal. Silakan coba lagi.');
    }
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
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
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 14)),
            ),
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
                        const SizedBox(height: 40),

                        // Logo and Title Section
                        _buildHeaderSection(isTablet),

                        SizedBox(height: isTablet ? 48 : 40),

                        // Login Form Card
                        _buildLoginForm(isTablet),

                        SizedBox(height: isTablet ? 32 : 24),

                        // Additional Options
                        _buildAdditionalOptions(),

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
                width: isTablet ? 100 : 80,
                height: isTablet ? 100 : 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00897B).withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Image.asset(
                    'assets/gambar/logo.png',
                    width: isTablet ? 68 : 48,
                    height: isTablet ? 68 : 48,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            );
          },
        ),

        SizedBox(height: isTablet ? 24 : 20),

        // App Title
        Text(
          'Royal Clinic',
          style: TextStyle(
            fontSize: isTablet ? 32 : 28,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF00897B),
            letterSpacing: 0.5,
          ),
        ),

        SizedBox(height: isTablet ? 12 : 8),

        Text(
          'Masuk ke akun Anda',
          style: TextStyle(
            fontSize: isTablet ? 18 : 16,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(bool isTablet) {
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
        padding: EdgeInsets.all(isTablet ? 32 : 24),
        child: Column(
          children: [
            // Username Field
            _buildTextField(
              controller: usernameController,
              label: 'Username',
              hint: 'Masukkan username Anda',
              icon: Icons.person_outline,
              validator: _validateUsername,
              isTablet: isTablet,
            ),

            SizedBox(height: isTablet ? 24 : 20),

            // Password Field
            _buildTextField(
              controller: passwordController,
              label: 'Password',
              hint: 'Masukkan password Anda',
              icon: Icons.lock_outline,
              obscureText: _obscurePassword,
              validator: _validatePassword,
              isTablet: isTablet,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey.shade500,
                  size: isTablet ? 24 : 20,
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),
            ),

            SizedBox(height: isTablet ? 20 : 16),

            // Remember Me only (removed duplicate forgot password)
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _rememberMe,
                    onChanged: (value) {
                      setState(() {
                        _rememberMe = value ?? false;
                      });
                    },
                    activeColor: const Color(0xFF00897B),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Ingat saya',
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),

            SizedBox(height: isTablet ? 32 : 24),

            // Login Button
            _buildLoginButton(isTablet),
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
    required bool isTablet,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTablet ? 16 : 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: validator,
          style: TextStyle(fontSize: isTablet ? 16 : 15, color: Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: isTablet ? 15 : 14,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF00897B).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF00897B),
                size: isTablet ? 22 : 20,
              ),
            ),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF00897B), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: isTablet ? 18 : 16,
            ),
            errorStyle: TextStyle(
              fontSize: isTablet ? 13 : 12,
              color: Colors.red.shade600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(bool isTablet) {
    return Container(
      width: double.infinity,
      height: isTablet ? 56 : 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
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
        onPressed: isLoading ? null : loginUser,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? SizedBox(
                height: isTablet ? 24 : 20,
                width: isTablet ? 24 : 20,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                'Masuk',
                style: TextStyle(
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  Widget _buildAdditionalOptions() {
    return Column(
      children: [
        // Divider
        Row(
          children: [
            Expanded(child: Divider(color: Colors.grey.shade300)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'atau',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            ),
            Expanded(child: Divider(color: Colors.grey.shade300)),
          ],
        ),

        const SizedBox(height: 20),

        // Lupa Username dan Lupa Password
        Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const ForgotUsernamePage(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(1.0, 0.0),
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
                        Icons.person_search,
                        color: Colors.grey.shade600,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Lupa Username',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300, width: 1),
                ),
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            const ForgotPasswordPage(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                              return SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(1.0, 0.0),
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
                        Icons.lock_outline,
                        color: Colors.grey.shade600,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Lupa Password',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Register Link
        Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF00897B), width: 1.5),
          ),
          child: TextButton(
            onPressed: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      const RegisterPage(),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(1.0, 0.0),
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
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_add_outlined,
                  color: const Color(0xFF00897B),
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Daftar Akun Baru',
                  style: TextStyle(
                    fontSize: 16,
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
          style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
        ),
      ],
    );
  }

  void _showInfoDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: const Color(0xFF00897B)),
            const SizedBox(width: 8),
            const Text('Informasi'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Color(0xFF00897B))),
          ),
        ],
      ),
    );
  }
}
