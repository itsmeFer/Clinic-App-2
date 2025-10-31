import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  
  // Step 1: Email
  final TextEditingController _emailController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();
  
  // Step 2: OTP
  final TextEditingController _otpController = TextEditingController();
  final _otpFormKey = GlobalKey<FormState>();
  Timer? _timer;
  int _remainingTime = 300; // 5 minutes in seconds
  
  // Step 3: New Password
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final _passwordFormKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  int _currentStep = 0;
  String _userEmail = '';

  // Animation controllers
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
    _pageController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _remainingTime = 300;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingTime > 0) {
          _remainingTime--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  // Step 1: Send OTP
  Future<void> _sendOTP() async {
    if (!_emailFormKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://10.61.209.71:8000/api/forgot-password/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController.text.trim()}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _userEmail = _emailController.text.trim();
        _showSuccessSnackBar('Kode OTP telah dikirim ke email Anda');
        _startTimer();
        _nextStep();
      } else {
        _showErrorSnackBar(data['message'] ?? 'Gagal mengirim OTP');
      }
    } catch (e) {
      _showErrorSnackBar('Terjadi kesalahan koneksi. Silakan coba lagi.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Step 2: Resend OTP
  Future<void> _resendOTP() async {
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://10.61.209.71:8000/api/forgot-password/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _userEmail}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _showSuccessSnackBar('Kode OTP baru telah dikirim');
        _startTimer();
        _otpController.clear();
      } else {
        _showErrorSnackBar(data['message'] ?? 'Gagal mengirim ulang OTP');
      }
    } catch (e) {
      _showErrorSnackBar('Terjadi kesalahan koneksi. Silakan coba lagi.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Step 3: Reset Password
  Future<void> _resetPassword() async {
    if (!_passwordFormKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://10.61.209.71:8000/api/forgot-password/reset'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _userEmail,
          'otp': _otpController.text.trim(),
          'new_password': _newPasswordController.text,
          'new_password_confirmation': _confirmPasswordController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _showSuccessSnackBar('Password berhasil direset!');
        _timer?.cancel();
        
        // Navigate back to login after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      } else {
        _showErrorSnackBar(data['message'] ?? 'Gagal mereset password');
      }
    } catch (e) {
      _showErrorSnackBar('Terjadi kesalahan koneksi. Silakan coba lagi.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _nextStep() {
    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
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

  String? _validateOTP(String? value) {
    if (value == null || value.isEmpty) {
      return 'Kode OTP tidak boleh kosong';
    }
    if (value.length != 6) {
      return 'Kode OTP harus 6 digit';
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
    if (value != _newPasswordController.text) {
      return 'Konfirmasi password tidak cocok';
    }
    return null;
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
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      
                      // Header with back button and progress
                      _buildHeader(isTablet),
                      
                      SizedBox(height: isTablet ? 40 : 32),
                      
                      // Logo and Title Section
                      _buildHeaderSection(isTablet),
                      
                      SizedBox(height: isTablet ? 40 : 32),

                      // Content Pages
                      Container(
                        height: 500,
                        child: PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildEmailStep(isTablet),
                            _buildOTPStep(isTablet),
                            _buildPasswordStep(isTablet),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isTablet) {
    return Row(
      children: [
        IconButton(
          onPressed: _currentStep == 0 ? () => Navigator.pop(context) : _previousStep,
          icon: Icon(
            Icons.arrow_back,
            color: Colors.grey.shade700,
            size: isTablet ? 28 : 24,
          ),
        ),
        Expanded(
          child: Container(
            height: 4,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(3, (index) {
                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                    decoration: BoxDecoration(
                      color: index <= _currentStep 
                        ? const Color(0xFF00897B) 
                        : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        SizedBox(width: isTablet ? 48 : 40),
      ],
    );
  }

  Widget _buildHeaderSection(bool isTablet) {
    final titles = ['Reset Password', 'Verifikasi OTP', 'Password Baru'];
    final subtitles = [
      'Masukkan email untuk reset password',
      'Masukkan kode yang dikirim ke email',
      'Buat password baru untuk akun Anda'
    ];
    final icons = [Icons.email_outlined, Icons.lock_outline, Icons.lock_reset];

    return Column(
      children: [
        // Icon with Animation
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 800),
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Container(
                width: isTablet ? 80 : 70,
                height: isTablet ? 80 : 70,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00897B).withOpacity(0.15),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  icons[_currentStep],
                  size: isTablet ? 40 : 35,
                  color: const Color(0xFF00897B),
                ),
              ),
            );
          },
        ),
        
        SizedBox(height: isTablet ? 24 : 20),
        
        // Title
        Text(
          titles[_currentStep],
          style: TextStyle(
            fontSize: isTablet ? 28 : 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF00897B),
            letterSpacing: 0.5,
          ),
        ),
        
        SizedBox(height: isTablet ? 12 : 8),
        
        // Subtitle
        Text(
          subtitles[_currentStep],
          style: TextStyle(
            fontSize: isTablet ? 16 : 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildEmailStep(bool isTablet) {
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
        child: Form(
          key: _emailFormKey,
          child: Column(
            children: [
              SizedBox(height: isTablet ? 20 : 16),
              
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'Masukkan email Anda',
                icon: Icons.email_outlined,
                validator: _validateEmail,
                isTablet: isTablet,
                keyboardType: TextInputType.emailAddress,
              ),
              
              SizedBox(height: isTablet ? 40 : 32),
              
              _buildActionButton(
                text: 'Kirim Kode OTP',
                onPressed: _isLoading ? null : _sendOTP,
                isTablet: isTablet,
              ),
              
              SizedBox(height: isTablet ? 20 : 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOTPStep(bool isTablet) {
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
        child: Form(
          key: _otpFormKey,
          child: Column(
            children: [
              SizedBox(height: isTablet ? 20 : 16),
              
              // Email info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00897B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Kode dikirim ke: $_userEmail',
                  style: TextStyle(
                    fontSize: isTablet ? 14 : 13,
                    color: const Color(0xFF00897B),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              
              SizedBox(height: isTablet ? 20 : 16),
              
              // Timer info
              if (_remainingTime > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    'Kedaluwarsa dalam ${_formatTime(_remainingTime)}',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: isTablet ? 13 : 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    'Kode OTP sudah kedaluwarsa',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: isTablet ? 13 : 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              
              SizedBox(height: isTablet ? 24 : 20),
              
              _buildTextField(
                controller: _otpController,
                label: 'Kode OTP',
                hint: '000000',
                icon: Icons.vpn_key_outlined,
                validator: _validateOTP,
                isTablet: isTablet,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: TextStyle(
                  fontSize: isTablet ? 20 : 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
              
              SizedBox(height: isTablet ? 16 : 12),
              
              // Resend button
              TextButton(
                onPressed: _remainingTime == 0 && !_isLoading ? _resendOTP : null,
                child: Text(
                  _remainingTime == 0 ? 'Kirim Ulang Kode' : 'Kirim Ulang (${_formatTime(_remainingTime)})',
                  style: TextStyle(
                    color: _remainingTime == 0 ? const Color(0xFF00897B) : Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 14 : 13,
                  ),
                ),
              ),
              
              SizedBox(height: isTablet ? 24 : 20),
              
              _buildActionButton(
                text: 'Verifikasi',
                onPressed: _isLoading ? null : () {
                  if (_otpFormKey.currentState!.validate()) {
                    _nextStep();
                  }
                },
                isTablet: isTablet,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordStep(bool isTablet) {
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
        child: Form(
          key: _passwordFormKey,
          child: Column(
            children: [
              SizedBox(height: isTablet ? 20 : 16),
              
              _buildTextField(
                controller: _newPasswordController,
                label: 'Password Baru',
                hint: 'Minimal 6 karakter',
                icon: Icons.lock_outline,
                obscureText: _obscureNewPassword,
                validator: _validatePassword,
                isTablet: isTablet,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey.shade500,
                    size: isTablet ? 24 : 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureNewPassword = !_obscureNewPassword;
                    });
                  },
                ),
              ),
              
              SizedBox(height: isTablet ? 24 : 20),
              
              _buildTextField(
                controller: _confirmPasswordController,
                label: 'Konfirmasi Password',
                hint: 'Ulangi password baru',
                icon: Icons.lock_outline,
                obscureText: _obscureConfirmPassword,
                validator: _validateConfirmPassword,
                isTablet: isTablet,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey.shade500,
                    size: isTablet ? 24 : 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
              ),
              
              SizedBox(height: isTablet ? 40 : 32),
              
              _buildActionButton(
                text: 'Reset Password',
                onPressed: _isLoading ? null : _resetPassword,
                isTablet: isTablet,
              ),
              
              SizedBox(height: isTablet ? 20 : 16),
            ],
          ),
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
    TextInputType? keyboardType,
    TextAlign? textAlign,
    int? maxLength,
    TextStyle? style,
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
          keyboardType: keyboardType,
          textAlign: textAlign ?? TextAlign.start,
          maxLength: maxLength,
          style: style ?? TextStyle(
            fontSize: isTablet ? 16 : 15,
            color: Colors.black87,
          ),
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
            counterText: maxLength != null ? '' : null,
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

  Widget _buildActionButton({
    required String text,
    required VoidCallback? onPressed,
    required bool isTablet,
  }) {
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
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? SizedBox(
                height: isTablet ? 24 : 20,
                width: isTablet ? 24 : 20,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                text,
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
}