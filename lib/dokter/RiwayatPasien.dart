import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class RiwayatPasienPage extends StatefulWidget {
  @override
  _RiwayatPasienPageState createState() => _RiwayatPasienPageState();
}

class _RiwayatPasienPageState extends State<RiwayatPasienPage> with TickerProviderStateMixin {
  List<dynamic> riwayatPasien = [];
  List<dynamic> filteredRiwayatPasien = [];
  bool isLoading = true;
  String? errorMessage;
  String baseUrl = 'http://10.227.74.71:8000/api';
  TextEditingController searchController = TextEditingController();
  
  // Animation controllers
  late AnimationController _searchAnimationController;
  late Animation<double> _searchAnimation;
  late AnimationController _typingAnimationController;
  late Animation<double> _typingAnimation;
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    _loadRiwayatPasien();
    searchController.addListener(_filterPasien);
    
    // Initialize animation controllers
    _searchAnimationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _searchAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _typingAnimationController = AnimationController(
      duration: Duration(milliseconds: 150),
      vsync: this,
    );
    _typingAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _typingAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    searchController.removeListener(_filterPasien);
    searchController.dispose();
    _searchAnimationController.dispose();
    _typingAnimationController.dispose();
    super.dispose();
  }

  void _filterPasien() {
    String query = searchController.text.toLowerCase();
    
    // Trigger typing animation
    if (query.isNotEmpty) {
      _typingAnimationController.forward().then((_) {
        _typingAnimationController.reverse();
      });
    }
    
    setState(() {
      if (query.isEmpty) {
        filteredRiwayatPasien = riwayatPasien;
      } else {
        filteredRiwayatPasien = riwayatPasien.where((pasien) {
          String namaPasien = (pasien['pasien']['nama_pasien'] ?? '').toString().toLowerCase();
          return namaPasien.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _loadRiwayatPasien() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      if (token == null) {
        throw Exception('Token tidak ditemukan. Silakan login kembali.');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/dokter/riwayat-pasien-diperiksa'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          setState(() {
            riwayatPasien = data['data'];
            filteredRiwayatPasien = riwayatPasien;
            isLoading = false;
          });
        } else {
          throw Exception(data['message']);
        }
      } else {
        throw Exception('Gagal memuat data: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _showDetailRiwayat(dynamic kunjunganId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('$baseUrl/dokter/detail-riwayat-pasien/$kunjunganId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success']) {
          _showDetailDialog(data['data']);
        } else {
          _showErrorSnackBar(data['message']);
        }
      } else {
        _showErrorSnackBar('Gagal memuat detail: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    }
  }

  void _showDetailDialog(dynamic detailData) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(
              children: [
                // Header
                Container(
                  padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal.shade600, Colors.teal.shade400],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Detail Riwayat Pasien',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: Colors.white),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailSection('Informasi Pasien', [
                          'Nama: ${detailData['pasien']['nama_pasien'] ?? 'N/A'}',
                          'Alamat: ${detailData['pasien']['alamat'] ?? 'N/A'}',
                          'Tanggal Lahir: ${_formatDate(detailData['pasien']['tanggal_lahir'])}',
                          'Jenis Kelamin: ${detailData['pasien']['jenis_kelamin'] ?? 'N/A'}',
                        ], Colors.teal.shade50, Colors.teal.shade600),
                        SizedBox(height: 16),
                        _buildDetailSection('Informasi Kunjungan', [
                          'Tanggal Kunjungan: ${_formatDate(detailData['tanggal_kunjungan'])}',
                          'No. Antrian: ${detailData['no_antrian'] ?? 'N/A'}',
                          'Keluhan Awal: ${detailData['keluhan_awal'] ?? 'N/A'}',
                          'Status: ${detailData['status'] ?? 'N/A'}',
                        ], Colors.blue.shade50, Colors.blue.shade600),
                        if (detailData['emr'] != null) ...[
                          SizedBox(height: 16),
                          _buildDetailSection('Electronic Medical Record', [
                            'Keluhan Utama: ${detailData['emr']['keluhan_utama'] ?? 'N/A'}',
                            'Riwayat Penyakit Sekarang: ${detailData['emr']['riwayat_penyakit_sekarang'] ?? 'N/A'}',
                            'Riwayat Penyakit Dahulu: ${detailData['emr']['riwayat_penyakit_dahulu'] ?? 'N/A'}',
                            'Riwayat Keluarga: ${detailData['emr']['riwayat_penyakit_keluarga'] ?? 'N/A'}',
                            'Diagnosis: ${detailData['emr']['diagnosis'] ?? 'N/A'}',
                          ], Colors.purple.shade50, Colors.purple.shade600),
                          SizedBox(height: 16),
                          _buildDetailSection('Tanda Vital', [
                            'Tekanan Darah: ${detailData['emr']['tekanan_darah'] ?? 'N/A'}',
                            'Suhu Tubuh: ${detailData['emr']['suhu_tubuh'] ?? 'N/A'}°C',
                            'Nadi: ${detailData['emr']['nadi'] ?? 'N/A'} bpm',
                            'Pernapasan: ${detailData['emr']['pernapasan'] ?? 'N/A'} per menit',
                            'Saturasi Oksigen: ${detailData['emr']['saturasi_oksigen'] ?? 'N/A'}%',
                          ], Colors.orange.shade50, Colors.orange.shade600),
                        ],
                        if (_hasValidResep(detailData)) ...[
                          SizedBox(height: 16),
                          _buildResepSection(_getResepData(detailData)),
                        ],
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                
                // Actions
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Text(
                          'Tutup',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
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
      },
    );
  }

  Widget _buildDetailSection(String title, List<String> items, Color backgroundColor, Color titleColor) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: titleColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: titleColor.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: titleColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getIconForSection(title),
                  color: titleColor,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: EdgeInsets.only(top: 6),
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: titleColor.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  IconData _getIconForSection(String title) {
    switch (title) {
      case 'Informasi Pasien':
        return Icons.person;
      case 'Informasi Kunjungan':
        return Icons.event_note;
      case 'Electronic Medical Record':
        return Icons.medical_information;
      case 'Tanda Vital':
        return Icons.monitor_heart;
      default:
        return Icons.info;
    }
  }

  Widget _buildResepSection(List<dynamic> obatList) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade50, Colors.green.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.medical_services,
                  color: Colors.green.shade700,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Resep Obat',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...obatList.map((obat) {
            String namaObat = 'N/A';
            String dosis = 'N/A';
            String keterangan = 'N/A';
            String jumlah = 'N/A';

            try {
              if (obat != null && obat is Map<String, dynamic>) {
                namaObat = _safeGetString(obat, 'nama_obat');
                dosis = _safeGetString(obat, 'dosis');
                
                if (obat.containsKey('pivot') && obat['pivot'] != null && obat['pivot'] is Map<String, dynamic>) {
                  var pivotData = obat['pivot'] as Map<String, dynamic>;
                  
                  jumlah = _safeGetString(pivotData, 'jumlah');
                  keterangan = _safeGetString(pivotData, 'keterangan');
                  
                  String pivotDosis = _safeGetString(pivotData, 'dosis');
                  if (pivotDosis != 'N/A' && pivotDosis.isNotEmpty) {
                    dosis = pivotDosis;
                  }
                }
              }
            } catch (e) {
              print('Error parsing obat: $e');
            }

            return Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.05),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          namaObat,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  _buildObatInfo('Jumlah', jumlah, Icons.inventory),
                  _buildObatInfo('Dosis', dosis, Icons.medication),
                  _buildObatInfo('Keterangan', keterangan, Icons.notes),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildObatInfo(String label, String value, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.green.shade600),
          SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _safeGetString(Map<String, dynamic> map, String key) {
    try {
      if (map.containsKey(key) && map[key] != null) {
        return map[key].toString();
      }
      return 'N/A';
    } catch (e) {
      return 'N/A';
    }
  }

  bool _hasValidResep(dynamic detailData) {
    try {
      if (detailData == null) return false;
      
      if (detailData['resep'] != null) {
        var resep = detailData['resep'];
        
        if (resep is List && resep.isNotEmpty) {
          var firstResep = resep[0];
          if (firstResep is Map && firstResep['obat'] != null && firstResep['obat'] is List && (firstResep['obat'] as List).isNotEmpty) {
            return true;
          }
        }
        
        if (resep is Map && resep['obat'] != null && resep['obat'] is List && (resep['obat'] as List).isNotEmpty) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  List<dynamic> _getResepData(dynamic detailData) {
    try {
      if (detailData == null || detailData['resep'] == null) return [];
      
      var resep = detailData['resep'];
      
      if (resep is List && resep.isNotEmpty) {
        var firstResep = resep[0];
        if (firstResep is Map && firstResep['obat'] != null && firstResep['obat'] is List) {
          return List<dynamic>.from(firstResep['obat']);
        }
      }
      
      if (resep is Map && resep['obat'] != null && resep['obat'] is List) {
        return List<dynamic>.from(resep['obat']);
      }
      
      return [];
    } catch (e) {
      return [];
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'N/A';
    try {
      DateTime date = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Riwayat Pasien',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.teal.shade600,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade600, Colors.teal.shade400],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded),
            onPressed: _loadRiwayatPasien,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header dengan statistik dan search
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade600, Colors.teal.shade400],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _buildStatCard(
                    'Total Pasien Diperiksa',
                    '${riwayatPasien.length}',
                    Icons.people_rounded,
                    Colors.white,
                  ),
                ),
                // Search Bar
                AnimatedBuilder(
                  animation: _searchAnimation,
                  builder: (context, child) {
                    return Container(
                      margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1 + (_searchAnimation.value * 0.05)),
                            blurRadius: 10 + (_searchAnimation.value * 5),
                            offset: Offset(0, 4 + (_searchAnimation.value * 2)),
                          ),
                        ],
                      ),
                      child: AnimatedBuilder(
                        animation: _typingAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _typingAnimation.value,
                            child: Focus(
                              onFocusChange: (hasFocus) {
                                setState(() {
                                  _isSearchFocused = hasFocus;
                                });
                                if (hasFocus) {
                                  _searchAnimationController.forward();
                                } else {
                                  _searchAnimationController.reverse();
                                }
                              },
                              child: TextField(
                                controller: searchController,
                                decoration: InputDecoration(
                                  hintText: 'Cari berdasarkan nama pasien...',
                                  hintStyle: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 14,
                                  ),
                                  prefixIcon: AnimatedContainer(
                                    duration: Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    child: Icon(
                                      Icons.search,
                                      color: _isSearchFocused 
                                          ? Colors.teal.shade600 
                                          : Colors.grey.shade500,
                                      size: 20 + (_searchAnimation.value * 2),
                                    ),
                                  ),
                                  suffixIcon: AnimatedSwitcher(
                                    duration: Duration(milliseconds: 200),
                                    child: searchController.text.isNotEmpty
                                        ? IconButton(
                                            key: ValueKey('clear'),
                                            icon: Icon(
                                              Icons.clear,
                                              color: Colors.grey.shade500,
                                              size: 18,
                                            ),
                                            onPressed: () {
                                              searchController.clear();
                                              _typingAnimationController.reset();
                                            },
                                          )
                                        : SizedBox(
                                            key: ValueKey('empty'),
                                            width: 48,
                                          ),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(25),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(25),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(25),
                                    borderSide: BorderSide(
                                      color: Colors.teal.shade300,
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                ),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade800,
                                ),
                                onChanged: (value) {
                                  // Trigger filter on change
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          
          // Content area
          Expanded(
            child: isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.teal.shade600),
                          strokeWidth: 3,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Memuat riwayat pasien...',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.error_outline_rounded,
                                  size: 64,
                                  color: Colors.red.shade400,
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Terjadi Kesalahan',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red.shade500),
                              ),
                              SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _loadRiwayatPasien,
                                icon: Icon(Icons.refresh_rounded),
                                label: Text('Coba Lagi'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade400,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : filteredRiwayatPasien.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    searchController.text.isNotEmpty ? Icons.search_off_rounded : Icons.folder_open_rounded,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Text(
                                  searchController.text.isNotEmpty 
                                      ? 'Tidak ada pasien ditemukan'
                                      : 'Belum Ada Riwayat Pasien',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  searchController.text.isNotEmpty
                                      ? 'Coba gunakan kata kunci lain'
                                      : 'Pasien yang sudah diperiksa akan muncul di sini',
                                  style: TextStyle(color: Colors.grey.shade500),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadRiwayatPasien,
                            color: Colors.teal.shade600,
                            child: ListView.builder(
                              padding: EdgeInsets.all(16),
                              itemCount: filteredRiwayatPasien.length,
                              itemBuilder: (context, index) {
                                final pasien = filteredRiwayatPasien[index];
                                return Container(
                                  margin: EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () => _showDetailRiwayat(pasien['id']),
                                      child: Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            // Foto pasien dengan border teal
                                            Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.teal.shade300,
                                                  width: 2,
                                                ),
                                                image: pasien['pasien']['foto_pasien'] != null
                                                    ? DecorationImage(
                                                        image: NetworkImage(
                                                          'http://10.227.74.71:8000/storage/${pasien['pasien']['foto_pasien']}',
                                                        ),
                                                        fit: BoxFit.cover,
                                                      )
                                                    : null,
                                              ),
                                              child: pasien['pasien']['foto_pasien'] == null
                                                  ? Icon(
                                                      Icons.person_rounded,
                                                      size: 30,
                                                      color: Colors.teal.shade600,
                                                    )
                                                  : null,
                                            ),
                                            SizedBox(width: 16),
                                            
                                            // Informasi pasien
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    pasien['pasien']['nama_pasien'] ?? 'Nama tidak tersedia',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 16,
                                                      color: Colors.grey.shade800,
                                                    ),
                                                  ),
                                                  SizedBox(height: 6),
                                                  _buildInfoRow(
                                                    Icons.calendar_today_rounded,
                                                    'Tanggal: ${_formatDate(pasien['tanggal_kunjungan'])}',
                                                    Colors.teal.shade600,
                                                  ),
                                                  SizedBox(height: 2),
                                                  _buildInfoRow(
                                                    Icons.confirmation_number_rounded,
                                                    'Antrian: ${pasien['no_antrian'] ?? 'N/A'}',
                                                    Colors.blue.shade600,
                                                  ),
                                                  if (pasien['emr'] != null) ...[
                                                    SizedBox(height: 2),
                                                    _buildInfoRow(
                                                      Icons.medical_services_rounded,
                                                      'Diagnosis: ${pasien['emr']['diagnosis'] ?? 'N/A'}',
                                                      Colors.green.shade600,
                                                    ),
                                                  ],
                                                  SizedBox(height: 6),
                                                  Container(
                                                    padding: EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: pasien['status'] == 'Succeed' || pasien['status'] == 'Completed'
                                                          ? Colors.green.shade100
                                                          : pasien['status'] == 'Canceled'
                                                          ? Colors.red.shade100
                                                          : Colors.orange.shade100,
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                    child: Text(
                                                      pasien['status'],
                                                      style: TextStyle(
                                                        color: pasien['status'] == 'Succeed' || pasien['status'] == 'Completed'
                                                            ? Colors.green.shade700
                                                            : pasien['status'] == 'Canceled'
                                                            ? Colors.red.shade700
                                                            : Colors.orange.shade700,
                                                        fontWeight: FontWeight.w600,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            
                                            // Arrow icon
                                            Container(
                                              padding: EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Colors.teal.shade50,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.arrow_forward_ios_rounded,
                                                color: Colors.teal.shade600,
                                                size: 16,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: color,
        ),
        SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}