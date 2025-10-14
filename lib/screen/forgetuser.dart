import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ForgotUsernamePage extends StatefulWidget {
  const ForgotUsernamePage({super.key});

  @override
  State<ForgotUsernamePage> createState() => _ForgotUsernamePageState();
}

class _ForgotUsernamePageState extends State<ForgotUsernamePage> with TickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _isSuccess = false;
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
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendUsername() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('https://admin.royal-klinik.cloud/api/forgot-username'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _emailController.text.trim()}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _isSuccess = true;
          _resultMessage = data['message'] ?? 'Username telah dikirim ke email Anda';
        });
        _showSuccessSnackBar(_resultMessage);
        
        // Navigate back to login after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      } else {
        setState(() {
          _isSuccess = false;
          _resultMessage = data['message'] ?? 'Gagal mengirim username';
        });
        _showErrorSnackBar(_resultMessage);
      }
    } catch (e) {
      setState(() {
        _isSuccess = false;
        _resultMessage = 'Terjadi kesalahan koneksi. Silakan coba lagi.';
      });
      _showErrorSnackBar(_resultMessage);
    } finally {
      setState(() => _isLoading = false);
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
                      
                      // Header with back button
                      _buildHeader(isTablet),
                      
                      SizedBox(height: isTablet ? 40 : 32),
                      
                      // Logo and Title Section
                      _buildHeaderSection(isTablet),
                      
                      SizedBox(height: isTablet ? 48 : 40),

                      // Main Content
                      _isSuccess ? _buildSuccessCard(isTablet) : _buildEmailForm(isTablet),
                      
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
        SizedBox(width: isTablet ? 56 : 48), // Balance the back button
      ],
    );
  }

  Widget _buildHeaderSection(bool isTablet) {
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
                  _isSuccess ? Icons.mark_email_read : Icons.person_search,
                  size: isTablet ? 50 : 40,
                  color: const Color(0xFF00897B),
                ),
              ),
            );
          },
        ),
        
        SizedBox(height: isTablet ? 24 : 20),
        
        // Title
        Text(
          _isSuccess ? 'Username Terkirim!' : 'Lupa Username?',
          style: TextStyle(
            fontSize: isTablet ? 32 : 28,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF00897B),
            letterSpacing: 0.5,
          ),
        ),
        
        SizedBox(height: isTablet ? 12 : 8),
        
        // Subtitle
        Text(
          _isSuccess 
            ? 'Username telah dikirim ke email Anda'
            : 'Masukkan email untuk mendapatkan username',
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

              // Info card
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
                        'Kami akan mengirimkan username akun Anda ke email yang terdaftar dalam sistem.',
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
                text: 'Kirim Username',
                onPressed: _isLoading ? null : _sendUsername,
                isTablet: isTablet,
              ),
              
              SizedBox(height: isTablet ? 20 : 16),

              // Alternative options
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
            
            // Success icon
            Container(
              width: isTablet ? 80 : 70,
              height: isTablet ? 80 : 70,
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.check_circle,
                size: isTablet ? 40 : 35,
                color: const Color(0xFF4CAF50),
              ),
            ),
            
            SizedBox(height: isTablet ? 24 : 20),
            
            Text(
              'Email Terkirim!',
              style: TextStyle(
                fontSize: isTablet ? 24 : 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            
            SizedBox(height: isTablet ? 12 : 8),
            
            Text(
              _resultMessage,
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: isTablet ? 24 : 20),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.mail_outline,
                    color: Colors.blue.shade700,
                    size: isTablet ? 24 : 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Periksa Email Anda',
                          style: TextStyle(
                            fontSize: isTablet ? 14 : 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Username akun telah dikirim ke ${_emailController.text}',
                          style: TextStyle(
                            fontSize: isTablet ? 13 : 12,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: isTablet ? 32 : 24),
            
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