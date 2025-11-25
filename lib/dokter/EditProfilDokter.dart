import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // ✅ Import Font Awesome

// Import shared sidebar with prefix
import 'Sidebar.dart' as Sidebar;

class EditProfilDokter extends StatefulWidget {
  final Map<String, dynamic> dokterData;

  const EditProfilDokter({
    Key? key,
    required this.dokterData,
  }) : super(key: key);

  @override
  _EditProfilDokterState createState() => _EditProfilDokterState();
}

class _EditProfilDokterState extends State<EditProfilDokter> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _noHpController = TextEditingController();
  final _pengalamanController = TextEditingController();
  final _deskripsiController = TextEditingController();

  bool _isLoading = false;
  bool _isSidebarCollapsed = false;
  Map<String, dynamic>? _currentDokterData;
  File? _selectedImage;
  String? _currentImageUrl;
  List<Map<String, dynamic>> _spesialisasiList = [];
  int? _selectedSpesialisasiId;
  List<Map<String, dynamic>> _poliList = [];
  List<int> _selectedPoliIds = [];

  @override
  void initState() {
    super.initState();
    _currentDokterData = widget.dokterData;
    _initializeDataAsync();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _noHpController.dispose();
    _pengalamanController.dispose();
    _deskripsiController.dispose();
    super.dispose();
  }

  // ===== ASYNC INITIALIZATION =====
  Future<void> _initializeDataAsync() async {
    _initializeData();
    
    await Future.wait([
      _loadSpesialisasi(),
      _loadPoli(),
    ]);
    
    setState(() {
      _initializeData();
    });
  }

  // ===== NAVIGATION HANDLERS =====
  void _handleSidebarNavigation(Sidebar.SidebarPage page) {
    if (page == Sidebar.SidebarPage.profilDokter) return;
    
    Sidebar.NavigationHelper.navigateToPage(
      context, 
      page, 
      dokterData: _currentDokterData
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await Sidebar.NavigationHelper.showLogoutConfirmation(context);
    if (confirm) {
      await Sidebar.NavigationHelper.logout(context);
    }
  }

  // ===== DATA INITIALIZATION =====
  void _initializeData() {
    if (_currentDokterData != null) {
      // Set basic fields
      _namaController.text = _currentDokterData!['nama_dokter']?.toString() ?? '';
      _noHpController.text = _currentDokterData!['no_hp']?.toString() ?? '';
      _pengalamanController.text = _currentDokterData!['pengalaman']?.toString() ?? '';
      _deskripsiController.text = _currentDokterData!['deskripsi_dokter']?.toString() ?? '';
      
      // Set image URL
      if (_currentDokterData!['foto_dokter'] != null) {
        _currentImageUrl = 'http://10.19.0.247:8000/storage/${_currentDokterData!['foto_dokter']}';
      }
      
      // Set spesialisasi
      if (_currentDokterData!['jenis_spesialis_id'] != null) {
        _selectedSpesialisasiId = int.tryParse(_currentDokterData!['jenis_spesialis_id'].toString());
      } else if (_currentDokterData!['jenis_spesialis'] != null && _currentDokterData!['jenis_spesialis'] is Map) {
        _selectedSpesialisasiId = int.tryParse(_currentDokterData!['jenis_spesialis']['id'].toString());
      }

      // Process poli relationships - support many-to-many
      _selectedPoliIds = [];
      
      // Check Laravel relationship data
      var poliRelationData = _currentDokterData!['poli'] ?? _currentDokterData!['polis'];
      
      if (poliRelationData != null && poliRelationData is List && poliRelationData.isNotEmpty) {
        for (final poliItem in poliRelationData) {
          if (poliItem is Map) {
            // Direct poli object
            if (poliItem['id'] != null) {
              final poliId = int.tryParse(poliItem['id'].toString());
              if (poliId != null && !_selectedPoliIds.contains(poliId)) {
                _selectedPoliIds.add(poliId);
              }
            }
            // Pivot data
            else if (poliItem['pivot'] != null && poliItem['pivot']['poli_id'] != null) {
              final poliId = int.tryParse(poliItem['pivot']['poli_id'].toString());
              if (poliId != null && !_selectedPoliIds.contains(poliId)) {
                _selectedPoliIds.add(poliId);
              }
            }
            // Pivot table structure
            else if (poliItem['poli_id'] != null) {
              final poliId = int.tryParse(poliItem['poli_id'].toString());
              if (poliId != null && !_selectedPoliIds.contains(poliId)) {
                _selectedPoliIds.add(poliId);
              }
            }
          }
        }
      }
      
      // Check custom backend fields
      if (_selectedPoliIds.isEmpty) {
        final customPoliFields = ['all_poli', 'poli_list', 'dokter_poli'];
        
        for (final fieldName in customPoliFields) {
          final customData = _currentDokterData![fieldName];
          if (customData != null && customData is List && customData.isNotEmpty) {
            for (final item in customData) {
              if (item is Map && item['id'] != null) {
                final poliId = int.tryParse(item['id'].toString());
                if (poliId != null && !_selectedPoliIds.contains(poliId)) {
                  _selectedPoliIds.add(poliId);
                }
              }
            }
            break;
          }
        }
      }
      
      // Legacy single poli_id fallback
      if (_selectedPoliIds.isEmpty && _currentDokterData!['poli_id'] != null) {
        final poliId = int.tryParse(_currentDokterData!['poli_id'].toString());
        if (poliId != null) {
          _selectedPoliIds.add(poliId);
        }
      }
      
      // Remove duplicates
      _selectedPoliIds = _selectedPoliIds.toSet().toList();
    }
  }

  // ===== API METHODS =====
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadSpesialisasi() async {
    try {
      final token = await _getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('http://10.19.0.247:8000/api/getDataSpesialisasiDokter'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        List<dynamic> spesialisasiData = [];
        
        if (data is Map) {
          if (data['success'] == true && data['data'] is List) {
            spesialisasiData = data['data'];
          } else if (data['data'] is List) {
            spesialisasiData = data['data'];
          } else if (data['spesialisasi'] is List) {
            spesialisasiData = data['spesialisasi'];
          }
        } else if (data is List) {
          spesialisasiData = data;
        }

        if (spesialisasiData.isNotEmpty) {
          setState(() {
            _spesialisasiList = List<Map<String, dynamic>>.from(spesialisasiData);
          });
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadPoli() async {
    try {
      final token = await _getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('http://10.19.0.247:8000/api/getDataPoli'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        List<dynamic> poliData = [];
        
        if (data is Map) {
          if (data['success'] == true && data['data'] is List) {
            poliData = data['data'];
          } else if (data['data'] is List) {
            poliData = data['data'];
          } else if (data.containsKey('poli') && data['poli'] is List) {
            poliData = data['poli'];
          }
        } else if (data is List) {
          poliData = data;
        }

        setState(() {
          _poliList = List<Map<String, dynamic>>.from(poliData);
        });
      }
    } catch (e) {
      setState(() {
        _poliList = [];
      });
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final token = await _getToken();
      if (token == null) {
        _showErrorSnackBar('Token tidak ditemukan. Silakan login ulang.');
        return;
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.19.0.247:8000/api/dokter/update-profile'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      // Add form fields
      request.fields['nama_dokter'] = _namaController.text.trim();
      request.fields['no_hp'] = _noHpController.text.trim();
      request.fields['pengalaman'] = _pengalamanController.text.trim();
      request.fields['deskripsi_dokter'] = _deskripsiController.text.trim();
      
      if (_selectedSpesialisasiId != null) {
        request.fields['jenis_spesialis_id'] = _selectedSpesialisasiId.toString();
      }

      // Send poli data for many-to-many relationship
      if (_selectedPoliIds.isNotEmpty) {
        request.fields['poli_ids'] = jsonEncode(_selectedPoliIds);
        request.fields['poli_ids_csv'] = _selectedPoliIds.join(',');
        
        // Send as individual array items for form data compatibility
        for (int i = 0; i < _selectedPoliIds.length; i++) {
          request.fields['poli_ids[$i]'] = _selectedPoliIds[i].toString();
        }
      } else {
        request.fields['poli_ids'] = jsonEncode([]);
      }

      // Add image if selected
      if (_selectedImage != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'foto_dokter',
          _selectedImage!.path,
        ));
      }

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      final data = json.decode(responseBody);

      if (response.statusCode == 200 && data['success'] == true) {
        await _refreshDokterData();
        _showSuccessSnackBar('Profil berhasil diperbarui');
        Navigator.pop(context, _currentDokterData);
      } else {
        final errorMessage = data['message'] ?? 
                           data['error'] ?? 
                           data['errors']?.toString() ??
                           'Gagal memperbarui profil';
        _showErrorSnackBar(errorMessage);
      }
    } catch (e) {
      _showErrorSnackBar('Terjadi kesalahan: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshDokterData() async {
    try {
      final token = await _getToken();
      if (token == null) return;

      final response = await http.get(
        Uri.parse('http://10.19.0.247:8000/api/dokter/get-data-dokter?include_poli=true'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && 
            data['Data Dokter'] is List && 
            data['Data Dokter'].isNotEmpty) {
          
          setState(() {
            _currentDokterData = data['Data Dokter'].first;
          });
          
          _initializeData();
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        final file = File(image.path);
        final fileSize = await file.length();
        
        if (fileSize > 5 * 1024 * 1024) {
          _showErrorSnackBar('Ukuran foto maksimal 5MB');
          return;
        }

        setState(() {
          _selectedImage = file;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Gagal memilih gambar: $e');
    }
  }

  // ===== UI HELPER METHODS =====
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;
    final isMobile = screenWidth < 768;

    return Scaffold(
      body: Row(
        children: [
          // Shared Sidebar
          if (isDesktop || isTablet) 
            Sidebar.SharedSidebar(
              currentPage: Sidebar.SidebarPage.profilDokter,
              dokterData: _currentDokterData,
              isCollapsed: _isSidebarCollapsed,
              onToggleCollapse: () {
                setState(() {
                  _isSidebarCollapsed = !_isSidebarCollapsed;
                });
              },
              onNavigate: _handleSidebarNavigation,
              onLogout: _handleLogout,
            ),

          // Main Content Area
          Expanded(
            child: Column(
              children: [
                // Shared Top Header Bar
                Sidebar.SharedTopHeader(
                  currentPage: Sidebar.SidebarPage.profilDokter,
                  dokterData: _currentDokterData,
                  isMobile: isMobile,
                ),

                // Main Content
                Expanded(child: _buildMainContent(isMobile)),
              ],
            ),
          ),
        ],
      ),
      // Shared Mobile Drawer
      drawer: isMobile ? Sidebar.SharedMobileDrawer(
        currentPage: Sidebar.SidebarPage.profilDokter,
        dokterData: _currentDokterData,
        onNavigate: _handleSidebarNavigation,
        onLogout: _handleLogout,
      ) : null,
    );
  }

  Widget _buildMainContent(bool isMobile) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header Card
              _buildProfileHeaderCard(isMobile),
              const SizedBox(height: 24),

              // Form Fields
              _buildFormFields(isMobile),
              const SizedBox(height: 32),

              // Action Buttons
              _buildActionButtons(isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeaderCard(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0891B2), Color(0xFF06B6D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0891B2).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Profile Image
          Stack(
            children: [
              Container(
                width: isMobile ? 80 : 100,
                height: isMobile ? 80 : 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  color: Colors.white.withOpacity(0.2),
                ),
                child: ClipOval(
                  child: _selectedImage != null
                      ? Image.file(_selectedImage!, fit: BoxFit.cover)
                      : _currentImageUrl != null
                          ? Image.network(
                              _currentImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  _buildDefaultAvatar(isMobile),
                            )
                          : _buildDefaultAvatar(isMobile),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: InkWell(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: FaIcon( // ✅ Changed to FaIcon
                      FontAwesomeIcons.camera,
                      color: const Color(0xFF0891B2),
                      size: isMobile ? 16 : 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: isMobile ? 16 : 20),

          // Profile Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Profil Dokter',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dr. ${_namaController.text.isNotEmpty ? _namaController.text : "Dokter"}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FaIcon( // ✅ Changed to FaIcon
                        FontAwesomeIcons.pen,
                        color: Colors.white,
                        size: isMobile ? 14 : 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Editing',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isMobile ? 12 : 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(bool isMobile) {
    return Container(
      color: Colors.grey.shade200,
      child: FaIcon( // ✅ Changed to FaIcon
        FontAwesomeIcons.userDoctor,
        color: Colors.grey.shade400,
        size: isMobile ? 40 : 50,
      ),
    );
  }

  Widget _buildFormFields(bool isMobile) {
    return Column(
      children: [
        // Informasi Dokter Section
        _buildSectionCard(
          'Informasi Dokter',
          FontAwesomeIcons.userDoctor, // ✅ Changed to FontAwesome
          const Color(0xFF0891B2),
          [
            _buildTextFormField(
              controller: _namaController,
              label: 'Nama Dokter',
              hint: 'Masukkan nama lengkap',
              icon: FontAwesomeIcons.userDoctor, // ✅ Changed to FontAwesome
              validator: (value) =>
                  value?.trim().isEmpty ?? true ? 'Nama tidak boleh kosong' : null,
              isMobile: isMobile,
            ),
            const SizedBox(height: 16),
            _buildDropdownField(
              label: 'Spesialisasi',
              hint: 'Pilih spesialisasi',
              icon: FontAwesomeIcons.stethoscope, // ✅ Changed to FontAwesome
              value: _selectedSpesialisasiId,
              items: _spesialisasiList,
              displayField: 'nama_spesialis',
              onChanged: (value) => setState(() => _selectedSpesialisasiId = value),
              isMobile: isMobile,
            ),
            const SizedBox(height: 16),
            _buildMultiSelectPoliField(
              label: 'Poli',
              hint: 'Pilih poli yang ditangani',
              icon: FontAwesomeIcons.houseMedical, // ✅ Changed to FontAwesome
              selectedPoliIds: _selectedPoliIds,
              poliList: _poliList,
              onSelectionChanged: (selectedIds) {
                setState(() {
                  _selectedPoliIds = selectedIds;
                });
              },
              isMobile: isMobile,
            ),
            const SizedBox(height: 16),
            _buildTextFormField(
              controller: _noHpController,
              label: 'Nomor HP',
              hint: 'Masukkan nomor HP aktif',
              icon: FontAwesomeIcons.phone, // ✅ Changed to FontAwesome
              keyboardType: TextInputType.phone,
              validator: (value) =>
                  value?.trim().isEmpty ?? true ? 'Nomor HP tidak boleh kosong' : null,
              isMobile: isMobile,
            ),
          ],
          isMobile,
        ),
        const SizedBox(height: 20),

        // Pengalaman Section
        _buildSectionCard(
          'Pengalaman',
          FontAwesomeIcons.briefcase, // ✅ Changed to FontAwesome
          const Color(0xFF059669),
          [
            _buildTextFormField(
              controller: _pengalamanController,
              label: 'Pengalaman Kerja',
              hint: 'Masukkan pengalaman kerja',
              icon: FontAwesomeIcons.clockRotateLeft, // ✅ Changed to FontAwesome
              maxLines: 3,
              isMobile: isMobile,
            ),
          ],
          isMobile,
        ),
        const SizedBox(height: 20),

        // Deskripsi Section
        _buildSectionCard(
          'Deskripsi',
          FontAwesomeIcons.fileLines, // ✅ Changed to FontAwesome
          const Color(0xFF7C3AED),
          [
            _buildTextFormField(
              controller: _deskripsiController,
              label: 'Deskripsi Dokter',
              hint: 'Tulis deskripsi atau bio singkat',
              icon: FontAwesomeIcons.fileLines, // ✅ Changed to FontAwesome
              maxLines: 4,
              isMobile: isMobile,
            ),
          ],
          isMobile,
        ),
      ],
    );
  }

  Widget _buildSectionCard(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
    bool isMobile,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: FaIcon(icon, color: color, size: 20), // ✅ Changed to FaIcon
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          // Section Content
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    required bool isMobile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FaIcon(icon, size: 16, color: Colors.grey.shade600), // ✅ Changed to FaIcon
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: TextStyle(fontSize: isMobile ? 14 : 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade500),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0891B2), width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: maxLines > 1 ? 16 : 12,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String hint,
    required IconData icon,
    required int? value,
    required List<Map<String, dynamic>> items,
    required String displayField,
    required void Function(int?) onChanged,
    required bool isMobile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FaIcon(icon, size: 16, color: Colors.grey.shade600), // ✅ Changed to FaIcon
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: value,
          hint: Text(
            hint,
            style: TextStyle(color: Colors.grey.shade500),
          ),
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF0891B2), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
          ),
          items: items.map((item) {
            return DropdownMenuItem<int>(
              value: item['id'],
              child: Text(
                item[displayField]?.toString() ?? '',
                style: TextStyle(fontSize: isMobile ? 14 : 16),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildMultiSelectPoliField({
    required String label,
    required String hint,
    required IconData icon,
    required List<int> selectedPoliIds,
    required List<Map<String, dynamic>> poliList,
    required Function(List<int>) onSelectionChanged,
    required bool isMobile,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FaIcon(icon, size: 16, color: Colors.grey.shade600), // ✅ Changed to FaIcon
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        InkWell(
          onTap: () => _showPoliSelectionDialog(selectedPoliIds, poliList, onSelectionChanged),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: const Color(0xFFF8FAFC),
            ),
            child: Row(
              children: [
                Expanded(
                  child: selectedPoliIds.isEmpty
                      ? Text(
                          hint,
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: isMobile ? 14 : 16,
                          ),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: selectedPoliIds.map((poliId) {
                            final poli = poliList.firstWhere(
                              (p) => int.tryParse(p['id'].toString()) == poliId,
                              orElse: () => {'nama_poli': 'Unknown'},
                            );
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0891B2).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF0891B2).withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    poli['nama_poli']?.toString() ?? 'Unknown',
                                    style: TextStyle(
                                      color: const Color(0xFF0891B2),
                                      fontSize: isMobile ? 12 : 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  InkWell(
                                    onTap: () {
                                      final newSelection = List<int>.from(selectedPoliIds);
                                      newSelection.remove(poliId);
                                      onSelectionChanged(newSelection);
                                    },
                                    child: FaIcon( // ✅ Changed to FaIcon
                                      FontAwesomeIcons.xmark,
                                      size: isMobile ? 14 : 16,
                                      color: const Color(0xFF0891B2),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                ),
                FaIcon( // ✅ Changed to FaIcon
                  FontAwesomeIcons.chevronDown,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
        
        if (selectedPoliIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${selectedPoliIds.length} poli dipilih',
              style: TextStyle(
                fontSize: isMobile ? 12 : 13,
                color: const Color(0xFF0891B2),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  void _showPoliSelectionDialog(
    List<int> currentSelection,
    List<Map<String, dynamic>> poliList,
    Function(List<int>) onSelectionChanged,
  ) {
    List<int> tempSelection = List.from(currentSelection);
    String searchQuery = '';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredPoli = poliList.where((poli) {
              final namaPoliLower = poli['nama_poli']?.toString().toLowerCase() ?? '';
              return namaPoliLower.contains(searchQuery.toLowerCase());
            }).toList();

            return AlertDialog(
              title: Column(
                children: [
                  Text('Pilih Poli (${poliList.length} tersedia)'),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari poli...',
                      prefixIcon: const FaIcon(FontAwesomeIcons.magnifyingGlass), // ✅ Changed to FaIcon
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, 
                        vertical: 8,
                      ),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        searchQuery = value;
                      });
                    },
                  ),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                constraints: const BoxConstraints(maxHeight: 400),
                child: filteredPoli.isEmpty
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FaIcon( // ✅ Changed to FaIcon
                            searchQuery.isEmpty ? FontAwesomeIcons.circleInfo : FontAwesomeIcons.magnifyingGlass, 
                            size: 48, 
                            color: Colors.grey
                          ),
                          const SizedBox(height: 16),
                          Text(searchQuery.isEmpty 
                            ? 'Tidak ada data poli tersedia'
                            : 'Tidak ditemukan poli yang sesuai'
                          ),
                        ],
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredPoli.length,
                        itemBuilder: (context, index) {
                          final poli = filteredPoli[index];
                          final poliId = int.tryParse(poli['id'].toString());
                          final poliNama = poli['nama_poli']?.toString() ?? 'Nama tidak tersedia';
                          
                          if (poliId == null) {
                            return const SizedBox.shrink();
                          }
                          
                          final isSelected = tempSelection.contains(poliId);
                          
                          return CheckboxListTile(
                            title: Text(poliNama),
                            subtitle: Text('ID: $poliId'),
                            value: isSelected,
                            activeColor: const Color(0xFF0891B2),
                            onChanged: (bool? selected) {
                              setDialogState(() {
                                if (selected == true) {
                                  if (!tempSelection.contains(poliId)) {
                                    tempSelection.add(poliId);
                                  }
                                } else {
                                  tempSelection.remove(poliId);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    onSelectionChanged(tempSelection);
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0891B2),
                  ),
                  child: Text(
                    'Simpan (${tempSelection.length})',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildActionButtons(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16),
              side: const BorderSide(color: Color(0xFF64748B)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Batal',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _updateProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0891B2),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: _isLoading
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Simpan Perubahan',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}