import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

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
  File? selectedImage;
  final ImagePicker _picker = ImagePicker();

  bool isLoading = false;
  bool isLoadingData = true;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    fetchDataProfile();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

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
      setState(() => isLoadingData = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://admin.royal-klinik.cloud/api/pasien/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          namaController.text = data['data']['nama_pasien'] ?? '';
          alamatController.text = data['data']['alamat'] ?? '';
          tanggalLahirController.text = data['data']['tanggal_lahir'] ?? '';
          jenisKelamin = data['data']['jenis_kelamin'];
          currentFotoUrl = data['data']['foto_pasien'];
          isLoadingData = false;
        });
      } else {
        setState(() => isLoadingData = false);
      }
    } catch (e) {
      setState(() => isLoadingData = false);
    }
  }

  Future<void> pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Pilih Foto Profil',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00897B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.photo_library,
                      color: Color(0xFF00897B),
                    ),
                  ),
                  title: const Text('Pilih dari Gallery'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    final XFile? image = await _picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 800,
                      maxHeight: 800,
                      imageQuality: 85,
                    );
                    if (image != null) {
                      setState(() {
                        selectedImage = File(image.path);
                      });
                    }
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00897B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Color(0xFF00897B),
                    ),
                  ),
                  title: const Text('Ambil Foto'),
                  onTap: () async {
                    Navigator.of(context).pop();
                    final XFile? image = await _picker.pickImage(
                      source: ImageSource.camera,
                      maxWidth: 800,
                      maxHeight: 800,
                      imageQuality: 85,
                    );
                    if (image != null) {
                      setState(() {
                        selectedImage = File(image.path);
                      });
                    }
                  },
                ),
                if (currentFotoUrl != null || selectedImage != null)
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.delete, color: Colors.red),
                    ),
                    title: const Text('Hapus Foto'),
                    onTap: () {
                      Navigator.of(context).pop();
                      setState(() {
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

  Future<void> updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('https://admin.royal-klinik.cloud/api/pasien/update'),
    );

    request.headers['Authorization'] = 'Bearer $token';

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

      final data = jsonDecode(response.body);
      setState(() => isLoading = false);

      if (response.statusCode == 200 && data['success'] == true) {
        _showSuccessSnackBar('Profil berhasil diperbarui');
        Navigator.pop(context, true);
      } else {
        _showErrorSnackBar(data['message'] ?? 'Gagal update profil');
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Kesalahan koneksi: $e');
    }
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate:
          DateTime.tryParse(tanggalLahirController.text) ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00897B),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        tanggalLahirController.text =
            "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  void _showSuccessSnackBar(String message) {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Widget buildProfileImage() {
    return Center(
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF00897B), width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00897B).withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: selectedImage != null
                  ? Image.file(
                      selectedImage!,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                    )
                  : currentFotoUrl != null
                  ? Image.network(
                      'https://admin.royal-klinik.cloud/storage/$currentFotoUrl',
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 120,
                          height: 120,
                          color: const Color(0xFF00897B).withOpacity(0.1),
                          child: const Icon(
                            Icons.person,
                            size: 60,
                            color: Color(0xFF00897B),
                          ),
                        );
                      },
                    )
                  : Container(
                      width: 120,
                      height: 120,
                      color: const Color(0xFF00897B).withOpacity(0.1),
                      child: const Icon(
                        Icons.person,
                        size: 60,
                        color: Color(0xFF00897B),
                      ),
                    ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: pickImage,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF00897B),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
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
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
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
            prefixIcon: icon != null
                ? Container(
                    margin: const EdgeInsets.only(left: 12, right: 12),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00897B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: const Color(0xFF00897B), size: 20),
                  )
                : null,
            suffixIcon: readOnly
                ? const Icon(
                    Icons.calendar_today,
                    color: Color(0xFF00897B),
                    size: 20,
                  )
                : null,
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FFFE),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.grey.shade700),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profil',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
      ),
      body: isLoadingData
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00897B)),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        buildProfileImage(),
                        const SizedBox(height: 12),
                        Text(
                          'Tap foto untuk mengubah',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 40),
                        _buildTextField(
                          controller: namaController,
                          label: 'Nama Lengkap',
                          hint: 'Masukkan nama lengkap Anda',
                          icon: Icons.person_outline,
                          validator: (v) =>
                              v!.isEmpty ? 'Nama tidak boleh kosong' : null,
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: alamatController,
                          label: 'Alamat',
                          hint: 'Masukkan alamat lengkap Anda',
                          icon: Icons.location_on_outlined,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: tanggalLahirController,
                          label: 'Tanggal Lahir',
                          hint: 'Pilih tanggal lahir Anda',
                          readOnly: true,
                          onTap: _selectDate,
                        ),
                        const SizedBox(height: 20),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Jenis Kelamin',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: DropdownButtonFormField<String>(
                                value: jenisKelamin,
                                decoration: const InputDecoration(
                                  hintText: 'Pilih jenis kelamin',
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: Color(0xFF00897B),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Laki-laki',
                                    child: Text('Laki-laki'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Perempuan',
                                    child: Text('Perempuan'),
                                  ),
                                ],
                                onChanged: (val) =>
                                    setState(() => jenisKelamin = val),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        Container(
                          width: double.infinity,
                          height: 50,
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
                            onPressed: isLoading ? null : updateProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
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
                                        'Menyimpan...',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  )
                                : const Text(
                                    'Simpan Perubahan',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
