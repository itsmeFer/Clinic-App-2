import 'package:RoyalClinic/pasien/dashboardScreen.dart';
import 'package:RoyalClinic/screen/login.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';

// Import halaman login - sesuaikan dengan path yang benar

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final namaController = TextEditingController();
  final alamatController = TextEditingController();
  final tanggalLahirController = TextEditingController();
  String? jenisKelamin;
  String? currentFotoUrl;
  String? qrPayload;
  File? selectedImage;
  final ImagePicker _picker = ImagePicker();

  bool isLoading = false;
  bool isLoadingData = true;

  // --- Palette (teal-forward, ala Gojek vibes)
  static const Color kTeal = Color(0xFF00BFA5); // A700
  static const Color kTealDark = Color(0xFF00897B); // Teal 600
  static const Color kTealLight = Color(0xFF4DB6AC); // Teal 300
  static const Color kBg = Color(0xFFF6FFFD);

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Helper agar aman panggil setState
  void safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    fetchDataProfile();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, .1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.ease));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    namaController.dispose();
    alamatController.dispose();
    tanggalLahirController.dispose();
    super.dispose();
  }

  Future<void> fetchDataProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) {
      safeSetState(() => isLoadingData = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('http://10.227.74.71:8000/api/pasien/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        safeSetState(() {
          namaController.text = data['data']['nama_pasien'] ?? '';
          alamatController.text = data['data']['alamat'] ?? '';
          tanggalLahirController.text = data['data']['tanggal_lahir'] ?? '';
          jenisKelamin = data['data']['jenis_kelamin'];
          currentFotoUrl = data['data']['foto_pasien'];
          qrPayload = data['data']['qr_code_pasien'];
          isLoadingData = false;
        });
      } else {
        safeSetState(() => isLoadingData = false);
      }
    } catch (e) {
      if (!mounted) return;
      safeSetState(() => isLoadingData = false);
    }
  }

  // Fungsi Logout
  Future<void> _showLogoutDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.logout, color: Colors.red.shade600, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Keluar Akun',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: const Text(
            'Apakah Anda yakin ingin keluar dari akun ini? Anda perlu login kembali untuk menggunakan aplikasi.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Tutup dialog
              },
              child: Text(
                'Batal',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Tutup dialog
                _performLogout(); // Lakukan logout
              },
              child: const Text(
                'Ya, Keluar',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performLogout() async {
    // Show loading
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: kTealDark)),
    );

    try {
      // Clear semua data dari SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Tutup loading dialog
      if (mounted) Navigator.of(context).pop();

      // Navigasi ke halaman login dan hapus semua route sebelumnya
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Berhasil keluar dari akun'),
              ],
            ),
            backgroundColor: const Color(0xFF4CAF50),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      // Tutup loading dialog jika error
      if (mounted) Navigator.of(context).pop();

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Gagal logout: $e')),
              ],
            ),
            backgroundColor: const Color(0xFFE53935),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  Future<void> pickImage() async {
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Pilih Foto Profil',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                _buildPickTile(
                  ctx,
                  icon: Icons.photo_library,
                  title: 'Pilih dari Galeri',
                  onTap: () async {
                    if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                    final XFile? image = await _picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 900,
                      maxHeight: 900,
                      imageQuality: 85,
                    );
                    if (!mounted) return;
                    if (image != null) {
                      safeSetState(() => selectedImage = File(image.path));
                    }
                  },
                ),
                _buildPickTile(
                  ctx,
                  icon: Icons.camera_alt,
                  title: 'Ambil Foto',
                  onTap: () async {
                    if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                    final XFile? image = await _picker.pickImage(
                      source: ImageSource.camera,
                      maxWidth: 900,
                      maxHeight: 900,
                      imageQuality: 85,
                    );
                    if (!mounted) return;
                    if (image != null) {
                      safeSetState(() => selectedImage = File(image.path));
                    }
                  },
                ),
                if (currentFotoUrl != null || selectedImage != null)
                  _buildPickTile(
                    ctx,
                    icon: Icons.delete,
                    title: 'Hapus Foto',
                    iconColor: Colors.red,
                    tileColor: Colors.red.withOpacity(.06),
                    onTap: () {
                      if (Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
                      if (!mounted) return;
                      safeSetState(() {
                        selectedImage = null;
                        currentFotoUrl = null;
                      });
                    },
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  ListTile _buildPickTile(
    BuildContext ctx, {
    required IconData icon,
    required String title,
    Color? iconColor,
    Color? tileColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (tileColor ?? kTeal).withOpacity(.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor ?? kTealDark),
      ),
      title: Text(title),
      onTap: onTap,
    );
  }

  Future<void> updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    safeSetState(() => isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('http://10.227.74.71:8000/api/pasien/update'),
    );

    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    request.fields['nama_pasien'] = namaController.text;
    request.fields['alamat'] = alamatController.text;
    request.fields['tanggal_lahir'] = tanggalLahirController.text;
    if (jenisKelamin != null) {
      request.fields['jenis_kelamin'] = jenisKelamin!;
    }

    if (selectedImage != null) {
      request.files.add(
        await http.MultipartFile.fromPath('foto_pasien', selectedImage!.path),
      );
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      final data = jsonDecode(response.body);

      safeSetState(() => isLoading = false);

      if (response.statusCode == 200 && data['success'] == true) {
        _showSuccessSnackBar('Profil berhasil diperbarui');

        if (!mounted) return;

        // Navigasi ke MainWrapper (halaman utama dengan bottom navigation) dan hapus semua route sebelumnya
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainWrapper()),
          (route) => false,
        );
      } else {
        _showErrorSnackBar(data['message'] ?? 'Gagal update profil');
      }
    } catch (e) {
      if (!mounted) return;
      safeSetState(() => isLoading = false);
      _showErrorSnackBar('Kesalahan koneksi: $e');
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          DateTime.tryParse(tanggalLahirController.text) ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kTealDark,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (!mounted) return;
      safeSetState(() {
        tanggalLahirController.text =
            "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
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
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget buildProfileImage() {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 118,
            height: 118,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [kTealDark, kTeal, kTealLight, kTealDark],
                stops: [0.0, .33, .66, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: kTealDark.withOpacity(.25),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(3.0),
              child: ClipOval(
                child: Container(
                  color: Colors.white,
                  child: selectedImage != null
                      ? Image.file(selectedImage!, fit: BoxFit.cover)
                      : currentFotoUrl != null
                      ? Image.network(
                          'http://10.227.74.71:8000/storage/$currentFotoUrl',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _avatarPlaceholder();
                          },
                        )
                      : _avatarPlaceholder(),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -6,
            right: -6,
            child: GestureDetector(
              onTap: pickImage,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: kTealDark,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      alignment: Alignment.center,
      child: Icon(Icons.person, size: 64, color: kTealDark.withOpacity(.6)),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: kTeal.withOpacity(.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: kTealDark, size: 18),
              ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          readOnly: readOnly,
          onTap: onTap,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kTealDark, width: 1.6),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 1.4),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            suffixIcon: readOnly
                ? const Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: Icon(
                      Icons.calendar_today,
                      color: kTealDark,
                      size: 18,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _genderSelector() {
    final items = ['Laki-laki', 'Perempuan'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Jenis Kelamin',
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Row(
          children: items.map((e) {
            final bool selected = jenisKelamin == e;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: EdgeInsets.only(right: e == items.last ? 0 : 12),
                decoration: BoxDecoration(
                  color: selected ? kTealDark : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? kTealDark : Colors.grey.shade200,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: kTealDark.withOpacity(.25),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : [],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => safeSetState(() => jenisKelamin = e),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          e == 'Laki-laki' ? Icons.male : Icons.female,
                          size: 18,
                          color: selected ? Colors.white : kTealDark,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          e,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: kTealDark,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.grey.shade800),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Edit Profil',
        style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w800),
      ),
      centerTitle: true,
      actions: [
        // Tombol Logout di AppBar
        IconButton(
          icon: Icon(Icons.logout, color: Colors.red.shade600),
          onPressed: _showLogoutDialog,
          tooltip: 'Keluar Akun',
        ),
      ],
    );
  }

  Widget _saveBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.06),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: isLoading ? null : updateProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: kTealDark,
              disabledBackgroundColor: kTealDark.withOpacity(.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Menyimpan... ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Simpan Perubahan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: _buildAppBar(), // Tambahkan kembali AppBar dengan tombol logout
      bottomNavigationBar: _saveBar(),
      body: isLoadingData
          ? const Center(child: CircularProgressIndicator(color: kTealDark))
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header card (hint ala Gojek: friendly, rounded, subtle gradient)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFE0F2F1), Color(0xFFFAFFFD)],
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: kTealDark.withOpacity(.10),
                                      blurRadius: 14,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.verified_user,
                                  color: kTealDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Lengkapi data kamu ya. Biar layanan makin pas dan cepat.',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        buildProfileImage(),
                        const SizedBox(height: 10),
                        Text(
                          'Tap foto untuk mengubah',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 24),

                        _section(
                          title: 'Data Pribadi',
                          child: Column(
                            children: [
                              _buildTextField(
                                controller: namaController,
                                label: 'Nama Lengkap',
                                hint: 'Masukkan nama lengkap',
                                icon: Icons.person_outline,
                                validator: (v) => v!.isEmpty
                                    ? 'Nama tidak boleh kosong'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: alamatController,
                                label: 'Alamat',
                                hint: 'Masukkan alamat lengkap',
                                icon: Icons.location_on_outlined,
                                maxLines: 3,
                              ),
                              const SizedBox(height: 16),
                              _buildTextField(
                                controller: tanggalLahirController,
                                label: 'Tanggal Lahir',
                                hint: 'Pilih tanggal lahir',
                                readOnly: true,
                                onTap: _selectDate,
                              ),
                              const SizedBox(height: 16),
                              _genderSelector(),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        _section(
                          title: 'Kode QR Pasien',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if ((qrPayload ?? '').isNotEmpty)
                                Column(
                                  children: [
                                    // QR code
                                    Center(
                                      child: QrImageView(
                                        data:
                                            qrPayload!, // contoh payload: "PAS-000123"
                                        size: 180,
                                        version: QrVersions.auto,
                                        gapless: true,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    // Teks payload (biar petugas bisa ketik manual kalau perlu)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: kTeal.withOpacity(.06),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: SelectableText(
                                        qrPayload!,
                                        style: const TextStyle(
                                          letterSpacing: 0.4,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Qr di atas adalah kode unik untuk identifikasi pasien Anda.\n',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey.shade600,
                                        fontSize: 12.5,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 1,
                                    ),
                                  ],
                                )
                              else
                                Column(
                                  children: [
                                    const Icon(
                                      Icons.qr_code_2,
                                      size: 64,
                                      color: kTealDark,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'QR belum tersedia di profil.',
                                      style: TextStyle(
                                        color: Colors.grey.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Pastikan backend mengirim "qr_code_pasien" di endpoint profil\n'
                                      'atau buka Riwayat Kunjungan untuk memuat QR otomatis.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12.5,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Tambahan: Tombol Logout di bagian bawah (opsional)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(.04),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade600,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Pengaturan Akun',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _showLogoutDialog,
                                  icon: Icon(
                                    Icons.logout,
                                    color: Colors.red.shade600,
                                    size: 20,
                                  ),
                                  label: Text(
                                    'Keluar dari Akun',
                                    style: TextStyle(
                                      color: Colors.red.shade600,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    side: BorderSide(
                                      color: Colors.red.shade600,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 90), // space for bottom button
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
