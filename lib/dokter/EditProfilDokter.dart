import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileDokter extends StatefulWidget {
  final Map<String, dynamic> dokterData;

  const EditProfileDokter({Key? key, required this.dokterData}) : super(key: key);

  @override
  State<EditProfileDokter> createState() => _EditProfileDokterState();
}

class _EditProfileDokterState extends State<EditProfileDokter> 
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  
  @override
  bool get wantKeepAlive => true;

  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final _pengalamanController = TextEditingController();
  final _noHpController = TextEditingController();
  
  bool isLoading = false;
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  
  List<dynamic> spesialisList = [];
  int? selectedSpesialisId;

  // Animation controllers
  late AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;
  late AnimationController _scaleAnimationController;
  late Animation<double> _scaleAnimation;

  // Focus nodes for better UX
  final List<FocusNode> _focusNodes = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeFocusNodes();
    _initializeData();
    _loadSpesialisList();
  }

  void _initializeAnimations() {
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _scaleAnimationController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimationController.forward();
  }

  void _initializeFocusNodes() {
    for (int i = 0; i < 5; i++) {
      _focusNodes.add(FocusNode());
    }
  }

  void _initializeData() {
    _namaController.text = widget.dokterData['nama_dokter'] ?? '';
    _deskripsiController.text = widget.dokterData['deskripsi_dokter'] ?? '';
    _pengalamanController.text = widget.dokterData['pengalaman'] ?? '';
    _noHpController.text = widget.dokterData['no_hp'] ?? '';
    selectedSpesialisId = widget.dokterData['jenis_spesialis_id'];
  }

  @override
  void dispose() {
    _fadeAnimationController.dispose();
    _scaleAnimationController.dispose();
    _namaController.dispose();
    _deskripsiController.dispose();
    _pengalamanController.dispose();
    _noHpController.dispose();
    _scrollController.dispose();
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadSpesialisList() async {
    try {
      final token = await getToken();
      
      final response = await http.get(
        Uri.parse('http://10.227.74.71:8000/api/getDataSpesialisasiDokter'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          setState(() {
            spesialisList = data['data'] ?? [];
          });
        } else {
          await _loadSpesialisListAlternative();
        }
      } else {
        await _loadSpesialisListAlternative();
      }
    } catch (e) {
      await _loadSpesialisListAlternative();
    }
  }

  Future<void> _loadSpesialisListAlternative() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.227.74.71:8000/api/getDataSpesialisasiDokter'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            spesialisList = data['data'] ?? [];
          });
        }
      }
    } catch (e) {
      setState(() {
        spesialisList = [
          {'id': 1, 'nama_spesialis': 'Umum'},
          {'id': 2, 'nama_spesialis': 'Jantung'},
          {'id': 3, 'nama_spesialis': 'Mata'},
          {'id': 4, 'nama_spesialis': 'Kulit'},
          {'id': 5, 'nama_spesialis': 'THT'},
          {'id': 6, 'nama_spesialis': 'Anak'},
        ];
      });
    }
  }

  Future<void> _pickImage() async {
    HapticFeedback.lightImpact();
    
    try {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => _buildImagePickerModal(),
      );
    } catch (e) {
      _showErrorSnackBar('Error memilih gambar: $e');
    }
  }

  Widget _buildImagePickerModal() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Container(
      margin: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Pilih Foto Profile',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildImageSourceOption(
                        icon: Icons.camera_alt_rounded,
                        label: 'Kamera',
                        onTap: () => _selectImageSource(ImageSource.camera),
                        color: Colors.teal,
                        isSmallScreen: isSmallScreen,
                      ),
                      _buildImageSourceOption(
                        icon: Icons.photo_library_rounded,
                        label: 'Galeri',
                        onTap: () => _selectImageSource(ImageSource.gallery),
                        color: Colors.blue,
                        isSmallScreen: isSmallScreen,
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Batal',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    required bool isSmallScreen,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: isSmallScreen ? 32 : 40,
              color: color,
            ),
            SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectImageSource(ImageSource source) async {
    Navigator.pop(context);
    
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
        });
        _showSuccessSnackBar('Foto berhasil dipilih');
      }
    } catch (e) {
      _showErrorSnackBar('Error memilih gambar: $e');
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    HapticFeedback.mediumImpact();
    _scaleAnimationController.forward().then((_) {
      _scaleAnimationController.reverse();
    });

    setState(() {
      isLoading = true;
    });

    try {
      final token = await getToken();
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.227.74.71:8000/api/dokter/update-profile'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      
      if (_namaController.text.isNotEmpty) {
        request.fields['nama_dokter'] = _namaController.text.trim();
      }
      if (_deskripsiController.text.isNotEmpty) {
        request.fields['deskripsi_dokter'] = _deskripsiController.text.trim();
      }
      if (_pengalamanController.text.isNotEmpty) {
        request.fields['pengalaman'] = _pengalamanController.text.trim();
      }
      if (_noHpController.text.isNotEmpty) {
        request.fields['no_hp'] = _noHpController.text.trim();
      }
      if (selectedSpesialisId != null) {
        request.fields['jenis_spesialis_id'] = selectedSpesialisId.toString();
      }

      if (_imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'foto_dokter',
          _imageFile!.path,
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _showSuccessSnackBar(data['message'] ?? 'Profile berhasil diupdate');
        Navigator.pop(context, true);
      } else {
        String errorMessage = 'Gagal update profile';
        if (data['errors'] != null) {
          Map<String, dynamic> errors = data['errors'];
          errorMessage = errors.values.first[0] ?? errorMessage;
        } else if (data['message'] != null) {
          errorMessage = data['message'];
        }
        
        _showErrorSnackBar(errorMessage);
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final isTablet = screenWidth >= 768;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(isSmallScreen),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isTablet ? 600 : double.infinity,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProfilePhotoSection(isSmallScreen),
                    SizedBox(height: isSmallScreen ? 20 : 24),
                    _buildFormSection(isSmallScreen),
                    SizedBox(height: isSmallScreen ? 24 : 32),
                    _buildSaveButton(isSmallScreen),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isSmallScreen) {
    return AppBar(
      title: Text(
        'Edit Profile Dokter',
        style: TextStyle(
          fontSize: isSmallScreen ? 18 : 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: Colors.teal.shade600,
      foregroundColor: Colors.white,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade600, Colors.teal.shade500],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePhotoSection(bool isSmallScreen) {
    double avatarRadius = isSmallScreen ? 60 : 70;
    
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 24 : 32),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.teal.shade50,
              Colors.white,
            ],
          ),
        ),
        child: Column(
          children: [
            Hero(
              tag: 'profile_photo',
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.teal.withOpacity(0.3),
                          spreadRadius: 4,
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: avatarRadius,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: _imageFile != null
                          ? FileImage(_imageFile!)
                          : (widget.dokterData['foto_dokter'] != null
                              ? NetworkImage(
                                  'http://10.227.74.71:8000/storage/${widget.dokterData['foto_dokter']}',
                                )
                              : null),
                      child: (_imageFile == null && widget.dokterData['foto_dokter'] == null)
                          ? Icon(
                              Icons.person_rounded,
                              size: avatarRadius * 0.7,
                              color: Colors.grey.shade400,
                            )
                          : null,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(25),
                        onTap: _pickImage,
                        child: Container(
                          padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade600,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.teal.withOpacity(0.4),
                                spreadRadius: 2,
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: isSmallScreen ? 18 : 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isSmallScreen ? 16 : 20),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.teal.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.teal.shade700,
                    size: isSmallScreen ? 16 : 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Ketuk untuk mengubah foto',
                    style: TextStyle(
                      color: Colors.teal.shade700,
                      fontSize: isSmallScreen ? 12 : 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection(bool isSmallScreen) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.edit_rounded,
                    color: Colors.teal.shade700,
                    size: isSmallScreen ? 20 : 24,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Informasi Dokter',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade700,
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 20 : 24),
            _buildFormFields(isSmallScreen),
          ],
        ),
      ),
    );
  }

  Widget _buildFormFields(bool isSmallScreen) {
    return Column(
      children: [
        _buildTextField(
          controller: _namaController,
          label: 'Nama Dokter',
          icon: Icons.person_outline_rounded,
          focusNode: _focusNodes[0],
          nextFocusNode: _focusNodes[1],
          isSmallScreen: isSmallScreen,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Nama dokter tidak boleh kosong';
            }
            return null;
          },
        ),
        SizedBox(height: isSmallScreen ? 16 : 20),
        
        _buildDropdownField(isSmallScreen),
        SizedBox(height: isSmallScreen ? 16 : 20),
        
        _buildTextField(
          controller: _noHpController,
          label: 'No. HP',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          focusNode: _focusNodes[2],
          nextFocusNode: _focusNodes[3],
          isSmallScreen: isSmallScreen,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'No HP tidak boleh kosong';
            }
            if (value.length < 10) {
              return 'No HP minimal 10 digit';
            }
            return null;
          },
        ),
        SizedBox(height: isSmallScreen ? 16 : 20),
        
        _buildTextField(
          controller: _pengalamanController,
          label: 'Pengalaman',
          icon: Icons.work_outline_rounded,
          focusNode: _focusNodes[3],
          nextFocusNode: _focusNodes[4],
          isSmallScreen: isSmallScreen,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Pengalaman tidak boleh kosong';
            }
            return null;
          },
        ),
        SizedBox(height: isSmallScreen ? 16 : 20),
        
        _buildTextField(
          controller: _deskripsiController,
          label: 'Deskripsi',
          icon: Icons.description_outlined,
          maxLines: isSmallScreen ? 4 : 5,
          focusNode: _focusNodes[4],
          isSmallScreen: isSmallScreen,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Deskripsi tidak boleh kosong';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLines,
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
    required bool isSmallScreen,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      maxLines: maxLines ?? 1,
      inputFormatters: inputFormatters,
      style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: isSmallScreen ? 14 : 16,
          color: Colors.grey.shade600,
        ),
        prefixIcon: Padding(
          padding: EdgeInsets.only(
            bottom: maxLines != null && maxLines > 1 ? 60 : 0,
          ),
          child: Icon(
            icon,
            size: isSmallScreen ? 20 : 24,
            color: Colors.teal.shade600,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 14 : 16,
          vertical: isSmallScreen ? 14 : 16,
        ),
      ),
      textInputAction: nextFocusNode != null ? TextInputAction.next : TextInputAction.done,
      onFieldSubmitted: (_) {
        if (nextFocusNode != null) {
          FocusScope.of(context).requestFocus(nextFocusNode);
        }
      },
      validator: validator,
    );
  }

  Widget _buildDropdownField(bool isSmallScreen) {
    return DropdownButtonFormField<int>(
      value: selectedSpesialisId,
      style: TextStyle(
        fontSize: isSmallScreen ? 14 : 16,
        color: Colors.black,
      ),
      decoration: InputDecoration(
        labelText: 'Spesialisasi',
        labelStyle: TextStyle(
          fontSize: isSmallScreen ? 14 : 16,
          color: Colors.grey.shade600,
        ),
        prefixIcon: Icon(
          Icons.medical_services_outlined,
          size: isSmallScreen ? 20 : 24,
          color: Colors.teal.shade600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 14 : 16,
          vertical: isSmallScreen ? 14 : 16,
        ),
      ),
      items: spesialisList.map<DropdownMenuItem<int>>((spesialis) {
        return DropdownMenuItem<int>(
          value: spesialis['id'],
          child: Text(
            spesialis['nama_spesialis'] ?? '',
            style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
          ),
        );
      }).toList(),
      onChanged: (value) {
        setState(() {
          selectedSpesialisId = value;
        });
      },
      validator: (value) {
        if (value == null) {
          return 'Pilih spesialisasi';
        }
        return null;
      },
      dropdownColor: Colors.white,
      icon: Icon(
        Icons.arrow_drop_down_rounded,
        color: Colors.teal.shade600,
      ),
    );
  }

  Widget _buildSaveButton(bool isSmallScreen) {
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Container(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : _updateProfile,
              icon: isLoading
                  ? SizedBox(
                      width: isSmallScreen ? 18 : 20,
                      height: isSmallScreen ? 18 : 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      Icons.save_rounded,
                      size: isSmallScreen ? 20 : 22,
                    ),
              label: Text(
                isLoading ? 'Menyimpan...' : 'Simpan Perubahan',
                style: TextStyle(
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal.shade600,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: isSmallScreen ? 16 : 18,
                  horizontal: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                shadowColor: Colors.teal.withOpacity(0.3),
              ),
            ),
          ),
        );
      },
    );
  }
}