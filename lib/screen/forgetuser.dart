import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ForgotUsernamePage extends StatefulWidget {
  const ForgotUsernamePage({super.key});

  @override
  State<ForgotUsernamePage> createState() => _ForgotUsernamePageState();
}

class _ForgotUsernamePageState extends State<ForgotUsernamePage>
    with TickerProviderStateMixin {
  // STEP 1
  final TextEditingController _emailController = TextEditingController();

  // STEP 2
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newUsernameController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isSuccess = false;       // tampilkan kartu sukses (mis. username sekarang)
  bool _otpSent = false;         // sudah kirim OTP → pindah ke step 2
  bool _wantsChange = false;     // toggle: ganti username?

  String _resultMessage = '';

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
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
    );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _newUsernameController.dispose();
    super.dispose();
  }

  // ===========================
  // VALIDATORS
  // ===========================
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email tidak boleh kosong';
    }
    if (!RegExp(r'^[\w\.-]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
      return 'Format email tidak valid';
    }
    return null;
  }

  String? _validateUsername(String? v) {
    if (v == null || v.trim().isEmpty) return 'Username tidak boleh kosong';
    if (v.trim().length < 3) return 'Username minimal 3 karakter';
    if (!RegExp(r'^[A-Za-z0-9_.-]+$').hasMatch(v.trim())) {
      return 'Hanya huruf, angka, titik, garis bawah, dan minus';
    }
    return null;
  }

  // ===========================
  // API CALLS
  // ===========================
  // STEP 1: Kirim OTP ke email
  Future<void> _sendUsernameOTP() async {
    if (!_formKey.currentState!.validate()) return;
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('http://10.61.209.71:8000/api/forgot-username/send-otp'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': _emailController.text.trim()}),
      );

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body);
      } catch (_) {}

      if (!mounted) return;

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _otpSent = true;
          _isSuccess = false;
          _resultMessage =
              data['message'] ?? 'Kode OTP telah dikirim ke email Anda';
        });
        _showSuccessSnackBar(_resultMessage);
      } else if (response.statusCode == 404) {
        _showErrorSnackBar(
            (data['message'] as String?) ?? 'Email tidak ditemukan dalam sistem');
      } else if (response.statusCode == 422) {
        final errors = (data['errors'] ?? {}) as Map<String, dynamic>;
        final msgs = <String>[];
        if (errors['email'] is List && (errors['email'] as List).isNotEmpty) {
          msgs.add((errors['email'] as List).first.toString());
        }
        _showErrorSnackBar(
            msgs.isNotEmpty ? msgs.join('\n') : (data['message'] ?? 'Validasi gagal'));
      } else {
        _showErrorSnackBar(
            (data['message'] as String?) ?? 'Gagal mengirim OTP');
      }
    } catch (_) {
      if (!mounted) return;
      _showErrorSnackBar('Terjadi kesalahan koneksi. Silakan coba lagi.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // STEP 2: Verifikasi OTP (opsional ganti username)
  Future<void> _verifyOrChange() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    final wantsChange = _wantsChange;
    final newUsername = _newUsernameController.text.trim();

    if (otp.length != 6) {
      _showErrorSnackBar('Kode OTP harus 6 digit.');
      return;
    }
    if (wantsChange) {
      final err = _validateUsername(newUsername);
      if (err != null) {
        _showErrorSnackBar(err);
        return;
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final body = {
        'email': email,
        'otp': otp,
        if (wantsChange) 'new_username': newUsername,
      };

      final resp = await http.post(
        Uri.parse(
            'http://10.61.209.71:8000/api/forgot-username/verify-or-change'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      );

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(resp.body);
      } catch (_) {}

      if (!mounted) return;

      if (resp.statusCode == 200 && data['success'] == true) {
        if (wantsChange) {
          _showSuccessSnackBar(
              'Username berhasil diganti. Silakan login dengan username baru.');
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) Navigator.pop(context);
          });
        } else {
          final uname = (data['data']?['username'] ?? '-') as String;
          setState(() {
            _isSuccess = true;
            _resultMessage = 'Username Anda: $uname';
          });
          _showSuccessSnackBar(_resultMessage);
        }
      } else if (resp.statusCode == 410) {
        _showErrorSnackBar('Kode OTP sudah kedaluwarsa. Minta kode baru.');
      } else if (resp.statusCode == 400) {
        _showErrorSnackBar('Kode OTP tidak valid.');
      } else if (resp.statusCode == 404) {
        _showErrorSnackBar('Email tidak ditemukan dalam sistem.');
      } else if (resp.statusCode == 409) {
        _showErrorSnackBar('Username sudah dipakai, silakan pilih yang lain.');
      } else if (resp.statusCode == 422) {
        final errors = (data['errors'] ?? {}) as Map<String, dynamic>;
        final msgs = <String>[];
        for (final k in ['email', 'otp', 'new_username']) {
          if (errors[k] is List && (errors[k] as List).isNotEmpty) {
            msgs.add((errors[k] as List).first.toString());
          }
        }
        _showErrorSnackBar(
            msgs.isNotEmpty ? msgs.join('\n') : (data['message'] ?? 'Validasi gagal'));
      } else {
        _showErrorSnackBar(
            (data['message'] as String?) ?? 'Gagal memproses permintaan.');
      }
    } catch (_) {
      if (!mounted) return;
      _showErrorSnackBar('Terjadi kesalahan koneksi. Silakan coba lagi.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ===========================
  // UI HELPERS
  // ===========================
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

  // ===========================
  // BUILD
  // ===========================
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

                      // Header with back button
                      _buildHeader(isTablet),

                      SizedBox(height: isTablet ? 40 : 32),

                      // Logo and Title Section
                      _buildHeaderSection(isTablet),

                      SizedBox(height: isTablet ? 48 : 40),

                      // Main Content (3 state)
                      _isSuccess
                          ? _buildSuccessCard(isTablet)
                          : (_otpSent
                              ? _buildOTPForm(isTablet)
                              : _buildEmailForm(isTablet)),

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
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back,
            color: Colors.grey.shade700,
            size: isTablet ? 28 : 24,
          ),
        ),
        Expanded(
          child: Text(
            'Lupa Username',
            style: TextStyle(
              fontSize: isTablet ? 18 : 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(width: isTablet ? 56 : 48),
      ],
    );
  }

  Widget _buildHeaderSection(bool isTablet) {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 800),
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
                child: Icon(
                  _isSuccess
                      ? Icons.verified
                      : (_otpSent ? Icons.verified_user : Icons.person_search),
                  size: isTablet ? 50 : 40,
                  color: const Color(0xFF00897B),
                ),
              ),
            );
          },
        ),
        SizedBox(height: isTablet ? 24 : 20),
        Text(
          _isSuccess
              ? 'Berhasil Diverifikasi'
              : (_otpSent ? 'Verifikasi OTP' : 'Lupa Username?'),
          style: TextStyle(
            fontSize: isTablet ? 32 : 28,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF00897B),
            letterSpacing: 0.5,
          ),
        ),
        SizedBox(height: isTablet ? 12 : 8),
        Text(
          _isSuccess
              ? 'Berikut username akun Anda'
              : (_otpSent
                  ? 'Masukkan OTP. Opsional: ganti username baru'
                  : 'Masukkan email untuk menerima OTP'),
          style: TextStyle(
            fontSize: isTablet ? 18 : 16,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // STEP 1 UI
  Widget _buildEmailForm(bool isTablet) {
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
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: isTablet ? 20 : 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF00897B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF00897B).withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: const Color(0xFF00897B),
                      size: isTablet ? 24 : 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Kami akan mengirimkan kode OTP ke email yang terdaftar.',
                        style: TextStyle(
                          fontSize: isTablet ? 14 : 13,
                          color: const Color(0xFF00897B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isTablet ? 32 : 24),
              _buildTextField(
                controller: _emailController,
                label: 'Email Terdaftar',
                hint: 'Masukkan email akun Anda',
                icon: Icons.email_outlined,
                validator: _validateEmail,
                isTablet: isTablet,
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: isTablet ? 40 : 32),
              _buildActionButton(
                text: 'Kirim OTP',
                onPressed: _isLoading ? null : _sendUsernameOTP,
                isTablet: isTablet,
              ),
              SizedBox(height: isTablet ? 20 : 16),
              Center(
                child: Column(
                  children: [
                    Text(
                      'Sudah ingat username?',
                      style: TextStyle(
                        fontSize: isTablet ? 14 : 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Kembali ke Login',
                        style: TextStyle(
                          fontSize: isTablet ? 14 : 13,
                          color: const Color(0xFF00897B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // STEP 2 UI
  Widget _buildOTPForm(bool isTablet) {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
              controller: _otpController,
              label: 'Kode OTP (6 digit)',
              hint: 'Masukkan kode OTP',
              icon: Icons.verified_user,
              validator: (v) =>
                  (v == null || v.length != 6) ? 'OTP harus 6 digit' : null,
              isTablet: isTablet,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Ganti username?',
                    style: TextStyle(
                      fontSize: isTablet ? 14 : 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Switch(
                  value: _wantsChange,
                  activeColor: const Color(0xFF00897B),
                  onChanged: (v) => setState(() => _wantsChange = v),
                ),
              ],
            ),

            if (_wantsChange) ...[
              const SizedBox(height: 8),
              _buildTextField(
                controller: _newUsernameController,
                label: 'Username Baru',
                hint: 'Masukkan username baru',
                icon: Icons.person_outline,
                validator: _validateUsername,
                isTablet: isTablet,
              ),
            ],

            SizedBox(height: isTablet ? 24 : 20),
            _buildActionButton(
              text: _wantsChange ? 'Ganti Username' : 'Tampilkan Username',
              onPressed: _isLoading ? null : _verifyOrChange,
              isTablet: isTablet,
            ),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () => setState(() {
                        _otpSent = false;
                        _wantsChange = false;
                        _otpController.clear();
                        _newUsernameController.clear();
                      }),
              child: const Text('Kirim ulang OTP ke email lain'),
            ),
          ],
        ),
      ),
    );
  }

  // SUCCESS CARD (tampilkan username saat tidak ganti)
  Widget _buildSuccessCard(bool isTablet) {
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
            SizedBox(height: isTablet ? 20 : 16),
            Container(
              width: isTablet ? 80 : 70,
              height: isTablet ? 80 : 70,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: const Icon(
                Icons.check_circle,
                size: 40,
                color: Color(0xFF4CAF50),
              ),
            ),
            SizedBox(height: isTablet ? 24 : 20),
            Text(
              'Berhasil Diverifikasi!',
              style: TextStyle(
                fontSize: isTablet ? 24 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: isTablet ? 12 : 8),
            Text(
              _resultMessage, // "Username Anda: xxx"
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isTablet ? 24 : 20),
            _buildActionButton(
              text: 'Kembali ke Login',
              onPressed: () => Navigator.pop(context),
              isTablet: isTablet,
            ),
            SizedBox(height: isTablet ? 20 : 16),
          ],
        ),
      ),
    );
  }

  // REUSABLE INPUT & BUTTON
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    required bool isTablet,
    TextInputType? keyboardType,
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
          validator: validator,
          keyboardType: keyboardType,
          style: TextStyle(
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
