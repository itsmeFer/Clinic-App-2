import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

class TestimoniPage extends StatefulWidget {
  const TestimoniPage({super.key});

  @override
  State<TestimoniPage> createState() => _TestimoniPageState();
}

class _TestimoniPageState extends State<TestimoniPage> {
  List<dynamic> testimoniList = [];
  bool isLoading = true;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    fetchTestimoni();
  }

  Future<void> fetchTestimoni() async {
    try {
      if (mounted) {
        setState(() {
          isLoading = true;
          errorMessage = '';
        });
      }

      final response = await http.get(
        Uri.parse('https://admin.royal-klinik.cloud/api/getDataTestimoni'),
      );

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            testimoniList = data['Data Testimoni'] ?? [];
            isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            errorMessage = 'Gagal memuat data testimoni (${response.statusCode})';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Terjadi kesalahan: $e';
          isLoading = false;
        });
      }
    }
  }

  void _showAddTestimoniDialog() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    
    if (token == null || token.isEmpty) {
      if (!mounted) return;
      _showErrorSnackBar('Anda harus login terlebih dahulu untuk memberikan testimoni');
      return;
    }

    int? pasienId = prefs.getInt('pasien_id');
    
    if (pasienId == null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Container(
          color: Colors.black.withOpacity(0.5),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF00897B)),
                  SizedBox(height: 16),
                  Text(
                    'Memuat data profil...',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      
      try {
        final profileResponse = await http.get(
          Uri.parse('https://admin.royal-klinik.cloud/api/pasien/profile'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );

        if (mounted) Navigator.pop(context);

        if (profileResponse.statusCode == 200) {
          final profileData = jsonDecode(profileResponse.body);
          if (profileData['success'] == true && profileData['data'] != null) {
            pasienId = profileData['data']['id'];
            
            await prefs.setInt('pasien_id', pasienId!);
            
            if (profileData['data']['nama_pasien'] != null) {
              await prefs.setString('nama_pasien', profileData['data']['nama_pasien']);
            }
          } else {
            if (!mounted) return;
            _showErrorSnackBar('Gagal mengambil data profil. Silakan coba lagi.');
            return;
          }
        } else {
          if (!mounted) return;
          _showErrorSnackBar('Sesi login telah berakhir. Silakan login kembali.');
          return;
        }
      } catch (e) {
        if (mounted) Navigator.pop(context);
        
        if (!mounted) return;
        _showErrorSnackBar('Terjadi kesalahan. Silakan periksa koneksi internet.');
        return;
      }
    }

    showDialog(
      context: context,
      builder: (context) => AddTestimoniDialog(
        pasienId: pasienId!,
        token: token,
        onSuccess: () {
          fetchTestimoni();
        },
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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Testimoni Pasien',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchTestimoni,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddTestimoniDialog,
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Tambah Testimoni',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        elevation: 4,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00897B),
              ),
            )
          : errorMessage.isNotEmpty
              ? Container(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red.shade300,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Oops! Terjadi Kesalahan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          errorMessage,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: fetchTestimoni,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00897B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.refresh),
                          label: const Text(
                            'Coba Lagi',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : testimoniList.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Icon(
                                Icons.rate_review_outlined,
                                size: 48,
                                color: Colors.grey.shade400,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Belum Ada Testimoni',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Jadilah yang pertama memberikan testimoni',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: fetchTestimoni,
                      color: const Color(0xFF00897B),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: testimoniList.length,
                        itemBuilder: (context, index) {
                          final testimoni = testimoniList[index];
                          return TestimoniCard(testimoni: testimoni);
                        },
                      ),
                    ),
    );
  }
}

class AddTestimoniDialog extends StatefulWidget {
  final int pasienId;
  final String token;
  final VoidCallback onSuccess;

  const AddTestimoniDialog({
    super.key,
    required this.pasienId,
    required this.token,
    required this.onSuccess,
  });

  @override
  State<AddTestimoniDialog> createState() => _AddTestimoniDialogState();
}

class _AddTestimoniDialogState extends State<AddTestimoniDialog> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _umurController = TextEditingController();
  final _pekerjaanController = TextEditingController();
  final _isiTestimoniController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  File? _selectedImage;
  File? _selectedVideo;
  bool _isLoading = false;
  
  bool _usePrivacyMode = false;
  String? _originalName;

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      String? nama = prefs.getString('nama_pasien');
      
      if (nama == null || nama.isEmpty) {
        nama = prefs.getString('username');
      }
      
      if (nama != null && nama.isNotEmpty) {
        setState(() {
          _originalName = nama;
          _namaController.text = nama!;
        });
        print('🔥 Auto-filled name: $nama');
      }
    } catch (e) {
      print('Error loading user name: $e');
    }
  }

  String _maskName(String name) {
    if (name.isEmpty || name.length <= 2) return name;
    
    List<String> words = name.split(' ');
    List<String> maskedWords = [];
    
    for (String word in words) {
      if (word.length <= 2) {
        maskedWords.add(word);
      } else {
        String first = word[0];
        String last = word[word.length - 1];
        String middle = '*' * (word.length - 2);
        maskedWords.add('$first$middle$last');
      }
    }
    
    return maskedWords.join(' ');
  }

  void _updateNameDisplay() {
    if (_originalName != null) {
      if (_usePrivacyMode) {
        _namaController.text = _maskName(_originalName!);
      } else {
        _namaController.text = _originalName!;
      }
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _umurController.dispose();
    _pekerjaanController.dispose();
    _isiTestimoniController.dispose();
    super.dispose();
  }

  Future<bool> _validateFileSize(File file, int maxSizeInMB, String fileType) async {
    final fileSize = await file.length();
    final maxSizeInBytes = maxSizeInMB * 1024 * 1024;
    
    if (fileSize > maxSizeInBytes) {
      if (!mounted) return false;
      _showErrorSnackBar('Ukuran $fileType maksimal ${maxSizeInMB}MB');
      return false;
    }
    return true;
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        
        if (await _validateFileSize(file, 2, 'foto')) {
          setState(() {
            _selectedImage = file;
          });
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      if (!mounted) return;
      _showErrorSnackBar('Gagal memilih foto: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );

      if (video != null) {
        final file = File(video.path);
        
        if (await _validateFileSize(file, 50, 'video')) {
          setState(() {
            _selectedVideo = file;
          });
        }
      }
    } catch (e) {
      print('Error picking video: $e');
      if (!mounted) return;
      _showErrorSnackBar('Gagal memilih video: $e');
    }
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
        duration: const Duration(seconds: 4),
      ),
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _submitTestimoni() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://admin.royal-klinik.cloud/api/create-data-testimoni'),
      );

      request.headers['Authorization'] = 'Bearer ${widget.token}';
      request.headers['Accept'] = 'application/json';

      request.fields['pasien_id'] = widget.pasienId.toString();
      request.fields['nama_testimoni'] = _namaController.text.trim();
      request.fields['umur'] = _umurController.text.trim();
      request.fields['pekerjaan'] = _pekerjaanController.text.trim();
      request.fields['isi_testimoni'] = _isiTestimoniController.text.trim();

      if (_selectedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'foto',
            _selectedImage!.path,
          ),
        );
      }

      if (_selectedVideo != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'video',
            _selectedVideo!.path,
          ),
        );
      }

      print('📤 Submitting testimoni...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          if (!mounted) return;
          Navigator.pop(context);
          _showSuccessSnackBar('Testimoni berhasil ditambahkan! Terima kasih atas berbagi pengalaman Anda.');
          widget.onSuccess();
        } else {
          _showErrorSnackBar(data['message'] ?? 'Gagal menambahkan testimoni');
        }
      } else if (response.statusCode == 422) {
        final data = json.decode(response.body);
        String errorMessage = 'Validasi gagal';
        
        if (data['errors'] != null) {
          final errors = data['errors'] as Map<String, dynamic>;
          if (errors.isNotEmpty) {
            errorMessage = errors.values.first[0];
          }
        } else if (data['message'] != null) {
          errorMessage = data['message'];
        }
        
        _showErrorSnackBar(errorMessage);
      } else if (response.statusCode == 401) {
        if (!mounted) return;
        _showErrorSnackBar('Sesi Anda telah berakhir. Silakan login kembali.');
        Navigator.pop(context);
      } else {
        _showErrorSnackBar('Gagal menambahkan testimoni (${response.statusCode})');
      }
    } catch (e) {
      print('❌ Error: $e');
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Terjadi kesalahan koneksi. Silakan periksa internet Anda dan coba lagi.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF00897B),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.rate_review,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Tambah Testimoni',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTextField(
                        controller: _namaController,
                        label: 'Nama Lengkap',
                        icon: Icons.person_outline,
                        readOnly: true,
                        helperText: _usePrivacyMode 
                            ? 'Mode Privasi: Nama diambil dari akun login dan disembunyikan untuk privasi'
                            : 'Nama diambil otomatis dari akun login Anda',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Nama harus diisi';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Privacy Settings Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.privacy_tip, 
                                     color: Colors.orange.shade700, size: 20),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Mode Privasi',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: _usePrivacyMode,
                                  onChanged: (value) {
                                    setState(() {
                                      _usePrivacyMode = value;
                                      _updateNameDisplay();
                                    });
                                  },
                                  activeColor: const Color(0xFF00897B),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _usePrivacyMode 
                                  ? 'Nama akan disembunyikan sebagian untuk melindungi privasi Anda'
                                  : 'Nama lengkap akan ditampilkan di testimoni publik',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      _buildTextField(
                        controller: _umurController,
                        label: 'Umur',
                        icon: Icons.cake_outlined,
                        keyboardType: TextInputType.number,
                        suffix: const Text('tahun'),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Umur harus diisi';
                          }
                          final age = int.tryParse(value);
                          if (age == null) {
                            return 'Umur harus berupa angka';
                          }
                          if (age < 1 || age > 150) {
                            return 'Umur harus antara 1-150 tahun';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      _buildTextField(
                        controller: _pekerjaanController,
                        label: 'Pekerjaan',
                        icon: Icons.work_outline,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Pekerjaan harus diisi';
                          }
                          if (value.length < 2) {
                            return 'Pekerjaan minimal 2 karakter';
                          }
                          if (value.length > 255) {
                            return 'Pekerjaan maksimal 255 karakter';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      _buildTextField(
                        controller: _isiTestimoniController,
                        label: 'Isi Testimoni',
                        icon: Icons.message_outlined,
                        hint: 'Ceritakan pengalaman Anda dengan layanan kami...',
                        maxLines: 4,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Isi testimoni harus diisi';
                          }
                          if (value.length < 10) {
                            return 'Testimoni minimal 10 karakter';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      
                      // Upload Section
                      Row(
                        children: [
                          Expanded(
                            child: _buildUploadButton(
                              onPressed: _pickImage,
                              icon: Icons.photo_camera_outlined,
                              label: _selectedImage == null 
                                  ? 'Foto' 
                                  : 'Foto ✓',
                              isSelected: _selectedImage != null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildUploadButton(
                              onPressed: _pickVideo,
                              icon: Icons.videocam_outlined,
                              label: _selectedVideo == null 
                                  ? 'Video' 
                                  : 'Video ✓',
                              isSelected: _selectedVideo != null,
                            ),
                          ),
                        ],
                      ),
                      
                      if (_selectedImage != null || _selectedVideo != null) ...[
                        const SizedBox(height: 12),
                        if (_selectedImage != null) _buildImagePreview(),
                        if (_selectedVideo != null) _buildVideoPreview(),
                      ],
                      
                      const SizedBox(height: 24),
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
                          onPressed: _isLoading ? null : _submitTestimoni,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isLoading
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'Mengirim...',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                )
                              : const Text(
                                  'Kirim Testimoni',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
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
    required String label,
    required IconData icon,
    String? hint,
    String? helperText,
    Widget? suffix,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool readOnly = false,
    String? Function(String?)? validator,
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
          keyboardType: keyboardType,
          maxLines: maxLines,
          readOnly: readOnly,
          style: const TextStyle(fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helperText,
            helperMaxLines: 2,
            suffix: suffix,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(
                left: 12,
                right: 12,
                top: 16,
                bottom: 16,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00897B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF00897B),
                    size: 20,
                  ),
                ),
              ),
            ),
            filled: true,
            fillColor: readOnly ? Colors.grey.shade50 : Colors.grey.shade50,
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required bool isSelected,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? const Color(0xFF00897B) : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
        color: isSelected ? const Color(0xFF00897B).withOpacity(0.1) : Colors.white,
      ),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(
          icon,
          size: 18,
          color: isSelected ? const Color(0xFF00897B) : Colors.grey.shade600,
        ),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? const Color(0xFF00897B) : Colors.grey.shade700,
          ),
        ),
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              _selectedImage!,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(15),
              ),
              child: IconButton(
                onPressed: () {
                  setState(() {
                    _selectedImage = null;
                  });
                },
                icon: const Icon(Icons.close, size: 16),
                color: Colors.white,
                constraints: const BoxConstraints(
                  minWidth: 30,
                  minHeight: 30,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF00897B).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF00897B)),
      ),
      child: Row(
        children: [
          const Icon(Icons.video_file, color: Color(0xFF00897B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedVideo!.path.split('/').last,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedVideo = null;
              });
            },
            icon: const Icon(Icons.close, size: 18),
            color: Colors.red,
            constraints: const BoxConstraints(
              minWidth: 30,
              minHeight: 30,
            ),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}

class TestimoniCard extends StatelessWidget {
  final dynamic testimoni;

  const TestimoniCard({super.key, required this.testimoni});

  String getVideoUrl(String? linkVideo) {
    if (linkVideo == null || linkVideo.isEmpty) return '';
    return 'https://admin.royal-klinik.cloud/storage/assets/$linkVideo';
  }

  void _showVideoDialog(BuildContext context, String videoUrl) {
    showDialog(
      context: context,
      builder: (context) => VideoPlayerDialog(videoUrl: videoUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = testimoni['link_video'] != null &&
        testimoni['link_video'].toString().isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00897B).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      testimoni['nama_testimoni'][0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00897B),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        testimoni['nama_testimoni'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.work_outline,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              testimoni['pekerjaan'],
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.cake_outlined,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${testimoni['umur']} tahun',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.format_quote,
                    color: const Color(0xFF00897B),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      testimoni['isi_testimoni'],
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (hasVideo)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      final videoUrl = getVideoUrl(testimoni['link_video']);
                      _showVideoDialog(context, videoUrl);
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFF00897B).withOpacity(0.1),
                      foregroundColor: const Color(0xFF00897B),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.play_circle_filled, size: 20),
                    label: const Text(
                      'Tonton Video Testimoni',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
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
}

class VideoPlayerDialog extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerDialog({super.key, required this.videoUrl});

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );

      await _controller.initialize();
      _controller.setLooping(false);
      _controller.play();

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Gagal memuat video: $e';
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Video Testimoni'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (_hasError)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else if (!_isInitialized)
            const Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(color: Colors.white),
            )
          else
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(_controller),
                  VideoControls(controller: _controller),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class VideoControls extends StatefulWidget {
  final VideoPlayerController controller;

  const VideoControls({super.key, required this.controller});

  @override
  State<VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<VideoControls> {
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      setState(() {});
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
      },
      child: Container(
        color: Colors.transparent,
        child: AnimatedOpacity(
          opacity: _showControls ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Center(
                  child: IconButton(
                    iconSize: 64,
                    icon: Icon(
                      widget.controller.value.isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        widget.controller.value.isPlaying
                            ? widget.controller.pause()
                            : widget.controller.play();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        _formatDuration(widget.controller.value.position),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: widget.controller.value.position.inSeconds
                              .toDouble(),
                          min: 0,
                          max: widget.controller.value.duration.inSeconds
                              .toDouble(),
                          onChanged: (value) {
                            widget.controller
                                .seekTo(Duration(seconds: value.toInt()));
                          },
                          activeColor: const Color(0xFF00897B),
                          inactiveColor: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      Text(
                        _formatDuration(widget.controller.value.duration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}