import 'dart:convert';
import 'package:RoyalClinic/dokter/Pemeriksaan.dart' as Medical;
import 'package:RoyalClinic/dokter/EditProfilDokter.dart' as EditProfile;
import 'package:RoyalClinic/dokter/RiwayatPasien.dart'; // ⭐ TAMBAHAN: Import halaman RiwayatPasien
import 'package:RoyalClinic/screen/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DokterDashboard extends StatefulWidget {
  const DokterDashboard({Key? key}) : super(key: key);

  @override
  State<DokterDashboard> createState() => _DokterDashboardState();
}

class _DokterDashboardState extends State<DokterDashboard> {
  bool isLoading = true;
  Map<String, dynamic>? dokterData;
  List<dynamic> kunjunganEngaged = [];
  Map<String, int> statistik = {
    'total_pasien_engaged': 0,
    'pasien_aktif': 0,
    'hari_ini': 0,
    'dokter_online': 1,
  };
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadDashboardData();
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<int?> getDoctorId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('dokter_id');
  }

  Future<void> loadDashboardData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final token = await getToken();
      if (token == null) {
        setState(() {
          errorMessage = 'Token tidak ditemukan. Silakan login kembali.';
          isLoading = false;
        });
        return;
      }

      await loadDokterProfile();
      if (dokterData != null) {
        await loadKunjunganEngaged();
      }

      debugPrintData();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = 'Terjadi kesalahan: $e';
        isLoading = false;
      });
    }
  }

  Future<void> loadDokterProfile() async {
    try {
      final token = await getToken();

      final response = await http.get(
        Uri.parse('https://admin.royal-klinik.cloud/api/dokter/get-data-dokter'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['Data Dokter'] != null) {
          final dataDokterList = data['Data Dokter'] as List;
          if (dataDokterList.isNotEmpty) {
            setState(() {
              dokterData = dataDokterList[0];
            });

            final prefs = await SharedPreferences.getInstance();
            await prefs.setInt('dokter_id', dokterData!['id']);
          }
        }
      } else if (response.statusCode == 401) {
        await _handleTokenExpired();
      }
    } catch (e) {
      print('Error loading dokter profile: $e');
    }
  }

  Future<void> loadKunjunganEngaged() async {
    try {
      final token = await getToken();

      if (token == null) {
        print('Token is null');
        return;
      }

      print('Loading kunjungan engaged...');

      final response = await http.get(
        Uri.parse('https://admin.royal-klinik.cloud/api/dokter/get-data-kunjungan-by-id-dokter'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            kunjunganEngaged = data['data'] ?? [];
            _calculateStatistik();
          });

          print('Successfully loaded ${kunjunganEngaged.length} engaged patients');

          if (data['dokter_info'] != null) {
            print('Dokter ID: ${data['dokter_info']['id']}');
            print('Dokter Name: ${data['dokter_info']['nama_dokter']}');
          }
        } else {
          print('API returned success: false');
          print('Message: ${data['message']}');
        }
      } else if (response.statusCode == 401) {
        print('Token expired, handling logout...');
        await _handleTokenExpired();
      } else {
        print('API Error: ${response.statusCode}');
        try {
          final errorData = jsonDecode(response.body);
          print('Error message: ${errorData['message']}');
        } catch (e) {
          print('Could not parse error response: $e');
        }
      }
    } catch (e) {
      print('Exception in loadKunjunganEngaged: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _calculateStatistik() {
    final total = kunjunganEngaged.length;

    setState(() {
      statistik = {
        'total_pasien_engaged': total,
        'pasien_aktif': total,
        'hari_ini': DateTime.now().day,
        'dokter_online': 1,
      };
    });

    print('Statistik updated - Total Engaged: $total');
  }

  void debugPrintData() {
    print('=== DEBUG INFO ===');
    print('dokterData: $dokterData');
    print('kunjunganEngaged length: ${kunjunganEngaged.length}');
    print('statistik: $statistik');
    
    if (kunjunganEngaged.isNotEmpty) {
      print('Sample kunjungan:');
      print(kunjunganEngaged.first);
    }
    print('==================');
  }

  Future<void> _handleTokenExpired() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesi telah berakhir. Silakan login kembali.'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  Future<void> _logout() async {
    try {
      final token = await getToken();

      await http.post(
        Uri.parse('https://admin.royal-klinik.cloud/api/logout'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
    } catch (e) {
      print('Error during logout: $e');
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  Widget _buildStatistikCard(String title, int value, Color color, IconData icon) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: isSmallScreen ? 20 : 24),
                const Spacer(),
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Text(
              title,
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKunjunganCard(Map<String, dynamic> kunjungan) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    
    return Card(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 6 : 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 6 : 8, 
                    vertical: 4
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    'No. ${kunjungan['no_antrian'] ?? '-'}',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 10 : 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 6 : 8, 
                    vertical: 4
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Text(
                    'Sedang Ditangani',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 10 : 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Text(
              kunjungan['pasien']?['nama_pasien'] ?? 'Nama tidak tersedia',
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16, 
                fontWeight: FontWeight.bold
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Keluhan: ${kunjungan['keluhan_awal'] ?? '-'}',
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 14, 
                color: Colors.grey
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            
            // Informasi tambahan pasien
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Info Pasien:',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 10 : 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tanggal Kunjungan: ${kunjungan['tanggal_kunjungan'] ?? '-'}',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 10 : 12, 
                      color: Colors.grey
                    ),
                  ),
                  if (kunjungan['created_at'] != null)
                    Text(
                      'Waktu Daftar: ${kunjungan['created_at'].toString().split('T')[1].substring(0, 5)}',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 10 : 12, 
                        color: Colors.grey
                      ),
                    ),
                ],
              ),
            ),
            
            SizedBox(height: isSmallScreen ? 6 : 8),
            
            // Button untuk melanjutkan pemeriksaan
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
  builder: (context) => Medical.Pemeriksaan(kunjunganData: kunjungan)
),
                  );
                },
                icon: Icon(Icons.medical_information, size: isSmallScreen ? 14 : 16),
                label: Text(
                  'Lanjutkan Pemeriksaan',
                  style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 10 : 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showLogoutConfirmation() async {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Konfirmasi',
          style: TextStyle(fontSize: screenWidth < 400 ? 16 : 18),
        ),
        content: Text(
          'Apakah Anda yakin ingin keluar?',
          style: TextStyle(fontSize: screenWidth < 400 ? 14 : 16),
        ),
        contentPadding: EdgeInsets.fromLTRB(
          screenWidth * 0.06, 
          20.0, 
          screenWidth * 0.06, 
          0
        ),
        actionsPadding: EdgeInsets.fromLTRB(
          screenWidth * 0.06, 
          0, 
          screenWidth * 0.06, 
          16.0
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Batal',
              style: TextStyle(fontSize: screenWidth < 400 ? 12 : 14),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Ya',
              style: TextStyle(fontSize: screenWidth < 400 ? 12 : 14),
            ),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final isMediumScreen = screenWidth >= 400 && screenWidth < 600;
    
    // Responsive grid settings
    int crossAxisCount = 2;
    double childAspectRatio = 1.5;
    
    if (isSmallScreen) {
      crossAxisCount = 1;
      childAspectRatio = 3.0;
    } else if (isMediumScreen) {
      crossAxisCount = 2;
      childAspectRatio = 1.4;
    } else {
      crossAxisCount = 2;
      childAspectRatio = 1.5;
    }
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Dashboard Dokter',
          style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
        ),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          // ⭐ TAMBAHAN: Button untuk ke halaman riwayat pasien
          IconButton(
            icon: Icon(Icons.history, size: isSmallScreen ? 20 : 24),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RiwayatPasienPage(),
                ),
              );
            },
            tooltip: 'Riwayat Pasien',
          ),
          IconButton(
            icon: Icon(Icons.refresh, size: isSmallScreen ? 20 : 24),
            onPressed: loadDashboardData,
          ),
          IconButton(
            icon: Icon(Icons.logout, size: isSmallScreen ? 20 : 24),
            onPressed: () async {
              final shouldLogout = await _showLogoutConfirmation();
              if (shouldLogout) {
                await _logout();
              }
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: isSmallScreen ? 48 : 64,
                        color: Colors.red.shade300,
                      ),
                      SizedBox(height: isSmallScreen ? 12 : 16),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 24 : 32),
                        child: Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 12 : 16),
                      ElevatedButton(
                        onPressed: loadDashboardData,
                        child: Text(
                          'Coba Lagi',
                          style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadDashboardData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Card
                        if (dokterData != null)
                          Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.teal.shade600,
                                    Colors.teal.shade400,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: isSmallScreen ? 25 : 30,
                                    backgroundColor: Colors.white,
                                    backgroundImage: dokterData!['foto_dokter'] != null
                                        ? NetworkImage(
                                            'https://admin.royal-klinik.cloud/storage/${dokterData!['foto_dokter']}',
                                          )
                                        : null,
                                    child: dokterData!['foto_dokter'] == null
                                        ? Icon(
                                            Icons.person,
                                            size: isSmallScreen ? 25 : 30,
                                            color: Colors.teal,
                                          )
                                        : null,
                                  ),
                                  SizedBox(width: isSmallScreen ? 12 : 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Selamat Datang,',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: isSmallScreen ? 12 : 14,
                                          ),
                                        ),
                                        Text(
                                          'Dr. ${dokterData!['nama_dokter'] ?? 'Dokter'}',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: isSmallScreen ? 16 : 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          dokterData!['jenis_spesialis']?['nama_spesialis'] ?? 'Umum',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: isSmallScreen ? 12 : 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => EditProfile.EditProfileDokter(
                                            dokterData: dokterData!,
                                          ),
                                        ),
                                      );

                                      if (result == true) {
                                        await loadDashboardData();
                                      }
                                    },
                                    icon: Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                      size: isSmallScreen ? 20 : 24,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        SizedBox(height: isSmallScreen ? 16 : 20),

                        // Statistik Cards
                        Text(
                          'Status Pemeriksaan',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 16 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 10 : 12),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: childAspectRatio,
                          crossAxisSpacing: isSmallScreen ? 8 : 12,
                          mainAxisSpacing: isSmallScreen ? 8 : 12,
                          children: [
                            _buildStatistikCard(
                              'Pasien Sedang Ditangani',
                              statistik['total_pasien_engaged']!,
                              Colors.green,
                              Icons.medical_services,
                            ),
                            _buildStatistikCard(
                              'Pasien Aktif',
                              statistik['pasien_aktif']!,
                              Colors.teal,
                              Icons.people_alt,
                            ),
                            _buildStatistikCard(
                              'Hari Ini',
                              statistik['hari_ini']!,
                              Colors.blue,
                              Icons.calendar_today,
                            ),
                            _buildStatistikCard(
                              'Status Dokter',
                              statistik['dokter_online']!,
                              Colors.orange,
                              Icons.online_prediction,
                            ),
                          ],
                        ),

                        SizedBox(height: isSmallScreen ? 20 : 24),

                        // Daftar Kunjungan
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Pasien Sedang Ditangani',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 16 : 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 6 : 8, 
                                vertical: 4
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.green.shade200),
                              ),
                              child: Text(
                                '${kunjunganEngaged.length} pasien',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12 : 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 10 : 12),

                        if (kunjunganEngaged.isEmpty)
                          Card(
                            child: Padding(
                              padding: EdgeInsets.all(isSmallScreen ? 24 : 32),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.medical_services_outlined,
                                    size: isSmallScreen ? 40 : 48,
                                    color: Colors.grey.shade400,
                                  ),
                                  SizedBox(height: isSmallScreen ? 12 : 16),
                                  Text(
                                    'Tidak ada pasien yang sedang ditangani',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 14 : 16,
                                      color: Colors.grey.shade600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: isSmallScreen ? 6 : 8),
                                  Text(
                                    'Pasien akan muncul di sini setelah status berubah menjadi "Engaged"',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 12 : 14,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: kunjunganEngaged.length,
                            itemBuilder: (context, index) {
                              return _buildKunjunganCard(kunjunganEngaged[index]);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }
}