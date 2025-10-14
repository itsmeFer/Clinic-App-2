import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileDokter extends StatefulWidget {
  final Map<String, dynamic> dokterData;

  const EditProfileDokter({Key? key, required this.dokterData}) : super(key: key);

  @override
  State<EditProfileDokter> createState() => _EditProfileDokterState();
}

class _EditProfileDokterState extends State<EditProfileDokter> {
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

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadSpesialisList();
  }

  void _initializeData() {
    _namaController.text = widget.dokterData['nama_dokter'] ?? '';
    _deskripsiController.text = widget.dokterData['deskripsi_dokter'] ?? '';
    _pengalamanController.text = widget.dokterData['pengalaman'] ?? '';
    _noHpController.text = widget.dokterData['no_hp'] ?? '';
    selectedSpesialisId = widget.dokterData['jenis_spesialis_id'];
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadSpesialisList() async {
    try {
      final token = await getToken();
      
      print('Loading spesialis from: https://admin.royal-klinik.cloud/api/getDataSpesialisasiDokter');
      
      final response = await http.get(
        Uri.parse('https://admin.royal-klinik.cloud/api/getDataSpesialisasiDokter'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('Spesialis Response Status: ${response.statusCode}');
      print('Spesialis Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Parsed data: $data');
        
        if (data['success'] == true) {
          setState(() {
            spesialisList = data['data'] ?? [];
          });
          print('Spesialis list loaded: ${spesialisList.length} items');
          for (var spesialis in spesialisList) {
            print('Spesialis: ${spesialis['id']} - ${spesialis['nama_spesialis']}');
          }
        } else {
          print('API returned success: false');
          print('Message: ${data['message']}');
        }
      } else {
        print('HTTP Error: ${response.statusCode}');
        await _loadSpesialisListAlternative();
      }
    } catch (e) {
      print('Error loading spesialis: $e');
      await _loadSpesialisListAlternative();
    }
  }

  Future<void> _loadSpesialisListAlternative() async {
    try {
      print('Trying alternative endpoint without auth...');
      
      final response = await http.get(
        Uri.parse('https://admin.royal-klinik.cloud/api/getDataSpesialisasiDokter'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('Alternative Response Status: ${response.statusCode}');
      print('Alternative Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            spesialisList = data['data'] ?? [];
          });
          print('Alternative: Spesialis list loaded: ${spesialisList.length} items');
        }
      }
    } catch (e) {
      print('Alternative loading error: $e');
      
      setState(() {
        spesialisList = [
          {'id': 1, 'nama_spesialis': 'Umum'},
          {'id': 2, 'nama_spesialis': 'Jantung'},
          {'id': 3, 'nama_spesialis': 'Mata'},
          {'id': 4, 'nama_spesialis': 'Kulit'},
        ];
      });
      print('Using fallback data: ${spesialisList.length} items');
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final token = await getToken();
      
      print('Nama Dokter: ${_namaController.text}');
      print('Deskripsi: ${_deskripsiController.text}');
      print('Pengalaman: ${_pengalamanController.text}');
      print('No HP: ${_noHpController.text}');
      print('Spesialis ID: $selectedSpesialisId');
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://admin.royal-klinik.cloud/api/dokter/update-profile'),
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

      print('Request fields: ${request.fields}');

      if (_imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'foto_dokter',
          _imageFile!.path,
        ));
        print('Image added: ${_imageFile!.path}');
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final data = jsonDecode(response.body);

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200 && data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'Profile berhasil diupdate'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        String errorMessage = 'Gagal update profile';
        if (data['errors'] != null) {
          Map<String, dynamic> errors = data['errors'];
          errorMessage = errors.values.first[0] ?? errorMessage;
        } else if (data['message'] != null) {
          errorMessage = data['message'];
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive breakpoints
        bool isTablet = constraints.maxWidth >= 768;
        bool isDesktop = constraints.maxWidth >= 1024;
        
        // Calculate responsive dimensions
        double maxWidth = isDesktop ? 800 : isTablet ? 600 : double.infinity;
        double horizontalPadding = isDesktop ? 32 : isTablet ? 24 : 16;
        double cardSpacing = isTablet ? 24 : 16;
        
        return Scaffold(
          backgroundColor: isTablet ? Colors.grey.shade100 : Colors.grey.shade50,
          appBar: _buildAppBar(context, isTablet),
          body: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: cardSpacing,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildProfilePhotoSection(context, isTablet, cardSpacing),
                      SizedBox(height: cardSpacing),
                      _buildFormSection(context, isTablet, cardSpacing),
                      SizedBox(height: cardSpacing * 1.5),
                      _buildSaveButton(context, isTablet),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isTablet) {
    return AppBar(
      title: Text(
        'Edit Profile Dokter',
        style: TextStyle(
          fontSize: isTablet ? 20 : 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      backgroundColor: Colors.teal,
      foregroundColor: Colors.white,
      elevation: isTablet ? 4 : 0,
      centerTitle: isTablet,
      
    );
  }

  Widget _buildProfilePhotoSection(BuildContext context, bool isTablet, double spacing) {
    double avatarRadius = isTablet ? 60 : 50;
    double cameraIconSize = isTablet ? 20 : 16;
    
    return Card(
      elevation: isTablet ? 6 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
      ),
      child: Container(
        padding: EdgeInsets.all(isTablet ? 32 : 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
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
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
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
                                'https://admin.royal-klinik.cloud/storage/${widget.dokterData['foto_dokter']}',
                              )
                            : null),
                    child: (_imageFile == null && widget.dokterData['foto_dokter'] == null)
                        ? Icon(
                            Icons.person,
                            size: avatarRadius,
                            color: Colors.grey.shade400,
                          )
                        : null,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Container(
                      padding: EdgeInsets.all(isTablet ? 12 : 8),
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: cameraIconSize,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isTablet ? 20 : 16),
            Text(
              'Ketuk ikon kamera untuk mengubah foto',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection(BuildContext context, bool isTablet, double spacing) {
    return Card(
      elevation: isTablet ? 6 : 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isTablet ? 16 : 12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informasi Dokter',
              style: TextStyle(
                fontSize: isTablet ? 20 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade700,
              ),
            ),
            SizedBox(height: isTablet ? 24 : 16),
            _buildResponsiveFormFields(isTablet),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveFormFields(bool isTablet) {
    // For tablet/desktop, use 2 columns for some fields
    if (isTablet) {
      return Column(
        children: [
          // Row 1: Nama and Spesialisasi
          Row(
            children: [
              Expanded(child: _buildTextField('nama', isTablet)),
              const SizedBox(width: 16),
              Expanded(child: _buildDropdownField(isTablet)),
            ],
          ),
          SizedBox(height: isTablet ? 20 : 16),
          
          // Row 2: No HP and Pengalaman  
          Row(
            children: [
              Expanded(child: _buildTextField('noHp', isTablet)),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField('pengalaman', isTablet)),
            ],
          ),
          SizedBox(height: isTablet ? 20 : 16),
          
          // Row 3: Deskripsi (full width)
          _buildTextField('deskripsi', isTablet),
        ],
      );
    } else {
      // Mobile: single column
      return Column(
        children: [
          _buildTextField('nama', isTablet),
          const SizedBox(height: 16),
          _buildDropdownField(isTablet),
          const SizedBox(height: 16),
          _buildTextField('noHp', isTablet),
          const SizedBox(height: 16),
          _buildTextField('pengalaman', isTablet),
          const SizedBox(height: 16),
          _buildTextField('deskripsi', isTablet),
        ],
      );
    }
  }

  Widget _buildTextField(String type, bool isTablet) {
    TextEditingController controller;
    String label;
    IconData icon;
    TextInputType? keyboardType;
    int? maxLines;
    String validationMessage;

    switch (type) {
      case 'nama':
        controller = _namaController;
        label = 'Nama Dokter';
        icon = Icons.person_outline;
        validationMessage = 'Nama dokter tidak boleh kosong';
        break;
      case 'noHp':
        controller = _noHpController;
        label = 'No. HP';
        icon = Icons.phone_outlined;
        keyboardType = TextInputType.phone;
        validationMessage = 'No HP tidak boleh kosong';
        break;
      case 'pengalaman':
        controller = _pengalamanController;
        label = 'Pengalaman';
        icon = Icons.work_outline;
        validationMessage = 'Pengalaman tidak boleh kosong';
        break;
      case 'deskripsi':
        controller = _deskripsiController;
        label = 'Deskripsi';
        icon = Icons.description_outlined;
        maxLines = isTablet ? 5 : 4;
        validationMessage = 'Deskripsi tidak boleh kosong';
        break;
      default:
        throw ArgumentError('Invalid field type: $type');
    }

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines ?? 1,
      style: TextStyle(fontSize: isTablet ? 16 : 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: isTablet ? 16 : 14),
        prefixIcon: Padding(
          padding: EdgeInsets.only(bottom: maxLines != null && maxLines > 1 ? 60 : 0),
          child: Icon(icon, size: isTablet ? 24 : 20),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
          borderSide: const BorderSide(color: Colors.teal, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16 : 12,
          vertical: isTablet ? 16 : 12,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return validationMessage;
        }
        return null;
      },
    );
  }

  Widget _buildDropdownField(bool isTablet) {
    return DropdownButtonFormField<int>(
      value: selectedSpesialisId,
      style: TextStyle(fontSize: isTablet ? 16 : 14, color: Colors.black),
      decoration: InputDecoration(
        labelText: 'Spesialisasi',
        labelStyle: TextStyle(fontSize: isTablet ? 16 : 14),
        prefixIcon: Icon(Icons.medical_services_outlined, size: isTablet ? 24 : 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
          borderSide: const BorderSide(color: Colors.teal, width: 2),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16 : 12,
          vertical: isTablet ? 16 : 12,
        ),
      ),
      items: spesialisList.map<DropdownMenuItem<int>>((spesialis) {
        return DropdownMenuItem<int>(
          value: spesialis['id'],
          child: Text(
            spesialis['nama_spesialis'] ?? '',
            style: TextStyle(fontSize: isTablet ? 16 : 14),
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
    );
  }

  Widget _buildSaveButton(BuildContext context, bool isTablet) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: isTablet ? 400 : double.infinity,
      ),
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : _updateProfile,
        icon: isLoading
            ? SizedBox(
                width: isTablet ? 20 : 18,
                height: isTablet ? 20 : 18,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(
                Icons.save_outlined,
                size: isTablet ? 22 : 20,
              ),
        label: Text(
          isLoading ? 'Menyimpan...' : 'Simpan Perubahan',
          style: TextStyle(
            fontSize: isTablet ? 18 : 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            vertical: isTablet ? 20 : 16,
            horizontal: isTablet ? 32 : 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isTablet ? 12 : 8),
          ),
          elevation: isTablet ? 4 : 2,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _namaController.dispose();
    _deskripsiController.dispose();
    _pengalamanController.dispose();
    _noHpController.dispose();
    super.dispose();
  }
}