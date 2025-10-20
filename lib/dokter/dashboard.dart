import 'dart:convert';
import 'package:RoyalClinic/dokter/Pemeriksaan.dart' as Medical;
import 'package:RoyalClinic/dokter/EditProfilDokter.dart' as EditProfile;
import 'package:RoyalClinic/dokter/RiwayatPasien.dart';
import 'package:RoyalClinic/screen/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class DokterDashboard extends StatefulWidget {
  const DokterDashboard({Key? key}) : super(key: key);

  @override
  State<DokterDashboard> createState() => _DokterDashboardState();
}

class _DokterDashboardState extends State<DokterDashboard> {
  bool isLoading = true;
  String? errorMessage;

  Map<String, dynamic>? dokterData;
  List<dynamic> kunjunganEngaged = [];

  // KPI yang dipakai
  Map<String, int> statistik = {'janji_hari_ini': 0, 'antrian_aktif': 0};

  // ---------- Helpers ----------
  void setStateSafe(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _saveDoctorIdIfAny(dynamic dokter) async {
    if (dokter is Map && dokter['id'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('dokter_id', dokter['id']);
    }
  }

  DateTime _getNowInTimezone() {
    return DateTime.now().toLocal();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    final aLocal = a.toLocal();
    final bLocal = b.toLocal();

    return aLocal.year == bLocal.year &&
        aLocal.month == bLocal.month &&
        aLocal.day == bLocal.day;
  }

  int _countAppointmentsToday() {
    final now = _getNowInTimezone();
    int count = 0;

    for (final k in kunjunganEngaged) {
      final raw = k['tanggal_kunjungan']?.toString();
      if (raw == null) continue;

      try {
        DateTime dt;

        if (raw.contains('T')) {
          dt = DateTime.parse(raw).toLocal();
        } else {
          dt = DateTime.parse(raw + 'T00:00:00').toLocal();
        }

        if (_isSameDay(dt, now)) {
          count++;
        }
      } catch (e) {
        // Ignore parsing errors
      }
    }

    return count;
  }

  // ---------- Lifecycle ----------
  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // ---------- Data fetching ----------
  Future<void> _loadDashboardData() async {
    try {
      setStateSafe(() {
        isLoading = true;
        errorMessage = null;
      });

      final token = await _getToken();
      if (!mounted) return;

      if (token == null) {
        setStateSafe(() {
          errorMessage = 'Token tidak ditemukan. Silakan login kembali.';
          isLoading = false;
        });
        return;
      }

      await _loadDokterProfile();
      if (!mounted) return;

      if (dokterData != null) {
        await _loadKunjunganEngaged();
        if (!mounted) return;
      }

      _calculateStatistik();
      setStateSafe(() => isLoading = false);
    } catch (e) {
      setStateSafe(() {
        errorMessage = 'Terjadi kesalahan: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _loadDokterProfile() async {
    try {
      final token = await _getToken();
      if (!mounted) return;

      final response = await http.get(
        Uri.parse('http://10.227.74.71:8000/api/dokter/get-data-dokter'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true &&
            data['Data Dokter'] is List &&
            data['Data Dokter'].isNotEmpty) {
          final first = (data['Data Dokter'] as List).first;
          setStateSafe(() => dokterData = first);
          await _saveDoctorIdIfAny(first);
        }
      } else if (response.statusCode == 401) {
        await _handleTokenExpired();
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> _loadKunjunganEngaged() async {
    try {
      final token = await _getToken();
      if (!mounted) return;
      if (token == null) return;

      final response = await http.get(
        Uri.parse(
          'http://10.227.74.71:8000/api/dokter/get-data-kunjungan-by-id-dokter',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> kunjunganList = (data['data'] as List?) ?? [];

          setStateSafe(() {
            kunjunganEngaged = kunjunganList;
          });
        }
      } else if (response.statusCode == 401) {
        await _handleTokenExpired();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _calculateStatistik() {
    final appointmentsToday = _countAppointmentsToday();
    final activeQueue = kunjunganEngaged.length;

    setStateSafe(() {
      statistik = {
        'janji_hari_ini': appointmentsToday,
        'antrian_aktif': activeQueue,
      };
    });
  }

  Future<void> _handleTokenExpired() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sesi telah berakhir. Silakan login kembali.'),
        backgroundColor: Colors.red,
      ),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Future<void> _logout() async {
    try {
      final token = await _getToken();
      if (!mounted) return;

      await http.post(
        Uri.parse('http://10.227.74.71:8000/api/logout'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
    } catch (e) {
      // Handle error silently
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  Future<bool> _showLogoutConfirmation() async {
    final isSmall = MediaQuery.of(context).size.width < 400;
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(
              'Konfirmasi',
              style: TextStyle(fontSize: isSmall ? 16 : 18),
            ),
            content: Text(
              'Apakah Anda yakin ingin keluar?',
              style: TextStyle(fontSize: isSmall ? 14 : 16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Ya'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _onPemeriksaanCompleted(int kunjunganId) {
    setStateSafe(() {
      kunjunganEngaged.removeWhere((k) => k['id'] == kunjunganId);
    });

    _calculateStatistik();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _loadKunjunganEngaged();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pemeriksaan telah diselesaikan'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final colorPrimary = const Color(0xFF00897B);
    final colorBg = Colors.grey.shade50;

    return Scaffold(
      backgroundColor: colorBg,
      appBar: _buildAppBar(colorPrimary),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? _ErrorState(message: errorMessage!, onRetry: _loadDashboardData)
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;

                  // Breakpoints
                  final isPhoneSmall = w < 360;
                  final isPhone = w < 600;
                  final isTablet = w >= 600 && w < 900;
                  final isWide = w >= 900;

                  // Grid statistik adaptif (2 kartu)
                  int statCols = 2;
                  double statHeight;
                  if (isPhoneSmall) {
                    statHeight = 132;
                  } else if (isPhone) {
                    statHeight = 120;
                  } else if (isTablet) {
                    statHeight = 110;
                  } else {
                    statHeight = 108;
                  }

                  final padding = EdgeInsets.symmetric(
                    horizontal: isPhoneSmall ? 12 : 16,
                    vertical: isPhoneSmall ? 10 : 12,
                  );

                  final List<Widget> items = [];

                  if (dokterData != null) {
                    items.add(
                      _WelcomeCard(dokter: dokterData!, onEdit: _goEditProfile),
                    );
                    items.add(SizedBox(height: isPhone ? 16 : 20));
                  }

                  items.add(
                    Text(
                      'Ringkasan',
                      style: TextStyle(
                        fontSize: isPhone ? 16 : 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                  items.add(const SizedBox(height: 10));

                  items.add(_StatisticsChart(statistik: statistik));

                  items.add(SizedBox(height: isPhone ? 18 : 22));

                  items.add(
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: w * 0.7),
                          child: Text(
                            'Pasien Sedang Ditangani',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isPhone ? 16 : 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        _ChipInfo(
                          text: '${kunjunganEngaged.length} pasien',
                          color: Colors.green,
                        ),
                      ],
                    ),
                  );
                  items.add(const SizedBox(height: 10));

                  if (kunjunganEngaged.isEmpty) {
                    items.add(
                      const _EmptyCard(
                        icon: Icons.medical_services_outlined,
                        title: 'Tidak ada pasien yang sedang ditangani',
                        subtitle:
                            'Pasien akan muncul di sini setelah status menjadi "Engaged".',
                      ),
                    );
                  } else {
                    for (var i = 0; i < kunjunganEngaged.length; i++) {
                      items.add(
                        _PatientCard(
                          data: kunjunganEngaged[i],
                          onOpen: () =>
                              _navigateToPemeriksaan(kunjunganEngaged[i]),
                        ),
                      );
                      if (i != kunjunganEngaged.length - 1) {
                        items.add(const SizedBox(height: 10));
                      }
                    }
                  }

                  items.add(const SizedBox(height: 80));

                  return ListView(
                    padding: padding,
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: items,
                  );
                },
              ),
            ),
    );
  }

  Future<void> _navigateToPemeriksaan(
    Map<String, dynamic> kunjunganData,
  ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Medical.Pemeriksaan(kunjunganData: kunjunganData),
      ),
    );

    if (result != null && result is Map) {
      if (result['completed'] == true) {
        final kunjunganId = kunjunganData['id'];
        if (kunjunganId != null) {
          _onPemeriksaanCompleted(kunjunganId);
        }
      }
    } else if (result == true) {
      final kunjunganId = kunjunganData['id'];
      if (kunjunganId != null) {
        _onPemeriksaanCompleted(kunjunganId);
      }
    }
  }

  PreferredSizeWidget _buildAppBar(Color colorPrimary) {
    final isSmall = MediaQuery.of(context).size.width < 400;
    return AppBar(
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorPrimary, colorPrimary.withOpacity(0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: Row(
        children: [
          const SizedBox(width: 16),
          CircleAvatar(
            radius: isSmall ? 16 : 18,
            backgroundColor: Colors.white,
            backgroundImage: AssetImage("assets/gambar/logo.png"),
          ),

          const SizedBox(width: 10),
          Text(
            'Dashboard Dokter',
            style: TextStyle(
              fontSize: isSmall ? 16 : 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          tooltip: 'Riwayat Pasien',
          icon: Icon(Icons.history, size: isSmall ? 20 : 24),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RiwayatPasienPage()),
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          icon: Icon(Icons.refresh, size: isSmall ? 20 : 24),
          onPressed: _loadDashboardData,
        ),
        IconButton(
          tooltip: 'Logout',
          icon: Icon(Icons.logout, size: isSmall ? 20 : 24),
          onPressed: () async {
            final ok = await _showLogoutConfirmation();
            if (ok) await _logout();
          },
        ),
      ],
    );
  }

  Future<void> _goEditProfile() async {
    if (dokterData == null) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfile.EditProfileDokter(dokterData: dokterData!),
      ),
    );
    if (result == true) {
      await _loadDashboardData();
    }
  }
}

// =========================================================
// ===================== UI SUBWIDGETS =====================
// =========================================================

class _WelcomeCard extends StatelessWidget {
  final Map<String, dynamic> dokter;
  final VoidCallback onEdit;

  const _WelcomeCard({required this.dokter, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 400;
    final foto = dokter['foto_dokter'];
    final nama = dokter['nama_dokter'] ?? 'Dokter';
    final spesialis = dokter['poli']?['nama_poli'] ?? 'Umum';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: EdgeInsets.all(isSmall ? 16 : 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade600, Colors.teal.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: isSmall ? 26 : 30,
              backgroundColor: Colors.white,
              child: ClipOval(
                child: SafeNetworkImage(
                  url: (foto != null)
                      ? 'http://10.227.74.71:8000/storage/$foto'
                      : null,
                  size: (isSmall ? 52 : 60),
                  fallback: Icon(
                    Icons.person,
                    color: Colors.teal,
                    size: isSmall ? 26 : 30,
                  ),
                ),
              ),
            ),
            SizedBox(width: isSmall ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selamat Datang,',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isSmall ? 12 : 13,
                    ),
                  ),
                  Text(
                    'Dr. $nama',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isSmall ? 16 : 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    spesialis,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isSmall ? 12 : 13,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onEdit,
              icon: Icon(
                Icons.edit,
                color: Colors.white,
                size: isSmall ? 20 : 24,
              ),
              tooltip: 'Edit Profil',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatisticsChart extends StatelessWidget {
  final Map<String, int> statistik;

  const _StatisticsChart({required this.statistik});

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 400;
    final janjiHariIni = statistik['janji_hari_ini'] ?? 0;
    final antrianAktif = statistik['antrian_aktif'] ?? 0;
    final total = janjiHariIni + antrianAktif;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: EdgeInsets.all(isSmall ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statistik Hari Ini',
              style: TextStyle(
                fontSize: isSmall ? 16 : 18,
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: isSmall ? 16 : 20),

            // Bar Chart Simple
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      _buildBarChart(
                        'Janji Hari Ini',
                        janjiHariIni,
                        total > 0 ? janjiHariIni / total : 0,
                        Colors.teal,
                        isSmall,
                      ),
                      SizedBox(height: isSmall ? 12 : 16),
                      _buildBarChart(
                        'Antrian Aktif',
                        antrianAktif,
                        total > 0 ? antrianAktif / total : 0,
                        Colors.green,
                        isSmall,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: isSmall ? 16 : 20),

                // Circular Progress
                Expanded(
                  child: Column(
                    children: [
                      SizedBox(
                        width: isSmall ? 80 : 100,
                        height: isSmall ? 80 : 100,
                        child: Stack(
                          children: [
                            // Background circle
                            Container(
                              width: double.infinity,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.grey[200]!,
                                  width: 8,
                                ),
                              ),
                            ),

                            // Progress circles
                            if (total > 0) ...[
                              // Teal progress
                              CircularProgressIndicator(
                                value: janjiHariIni / total,
                                backgroundColor: Colors.transparent,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.teal,
                                ),
                                strokeWidth: 8,
                              ),

                              // Green progress (offset)
                              Transform.rotate(
                                angle: (janjiHariIni / total) * 2 * 3.14159,
                                child: CircularProgressIndicator(
                                  value: antrianAktif / total,
                                  backgroundColor: Colors.transparent,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.green,
                                  ),
                                  strokeWidth: 8,
                                ),
                              ),
                            ],

                            // Center text
                            Center(
                              child: Text(
                                '$total',
                                style: TextStyle(
                                  fontSize: isSmall ? 18 : 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isSmall ? 8 : 12),
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: isSmall ? 12 : 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: isSmall ? 16 : 20),

            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLegend(
                  'Janji Hari Ini',
                  Colors.teal,
                  janjiHariIni,
                  isSmall,
                ),
                _buildLegend(
                  'Antrian Aktif',
                  Colors.green,
                  antrianAktif,
                  isSmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(
    String label,
    int value,
    double percentage,
    Color color,
    bool isSmall,
  ) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: isSmall ? 12 : 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ),
        SizedBox(width: isSmall ? 8 : 12),
        Expanded(
          flex: 3,
          child: Container(
            height: isSmall ? 20 : 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[200],
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: percentage.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [color, color.withOpacity(0.7)],
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: isSmall ? 8 : 12),
        SizedBox(
          width: isSmall ? 20 : 24,
          child: Text(
            '$value',
            style: TextStyle(
              fontSize: isSmall ? 12 : 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(String label, Color color, int value, bool isSmall) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isSmall ? 12 : 16,
          height: isSmall ? 12 : 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        SizedBox(width: isSmall ? 6 : 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: isSmall ? 10 : 12,
                color: Colors.grey[600],
              ),
            ),
            Text(
              '$value',
              style: TextStyle(
                fontSize: isSmall ? 12 : 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ChipInfo extends StatelessWidget {
  final String text;
  final Color color;

  const _ChipInfo({required this.text, required this.color});

  Color _derive700(Color base) {
    if (base is MaterialColor) return (base as MaterialColor).shade700;
    final hsl = HSLColor.fromColor(base);
    final darker = hsl.withLightness((hsl.lightness * 0.75).clamp(0.0, 1.0));
    return darker.toColor();
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 400;
    final textColor = _derive700(color);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 8 : 10,
          vertical: isSmall ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: isSmall ? 11.5 : 13,
          ),
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 400;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isSmall ? 24 : 28),
        child: Column(
          children: [
            Icon(icon, size: isSmall ? 42 : 48, color: Colors.grey.shade400),
            SizedBox(height: isSmall ? 10 : 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: isSmall ? 14 : 16),
            ),
            SizedBox(height: isSmall ? 6 : 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isSmall ? 12 : 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onOpen;

  const _PatientCard({required this.data, required this.onOpen});

  String formatDate(String? raw) {
    if (raw == null) return '-';
    try {
      DateTime dt;

      if (raw.contains('T')) {
        dt = DateTime.parse(raw).toLocal();
      } else {
        dt = DateTime.parse(raw + 'T00:00:00').toLocal();
      }

      return DateFormat('dd MMMM yyyy', 'id_ID').format(dt);
    } catch (e) {
      return raw;
    }
  }

  String? formatTime(String? raw) {
    if (raw == null) return null;
    try {
      DateTime dt;
      if (raw.contains('T')) {
        dt = DateTime.parse(raw).toLocal();
      } else {
        dt = DateTime.parse(raw + 'T00:00:00').toLocal();
      }

      return DateFormat.Hm().format(dt);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 400;

    final no = data['no_antrian'] ?? '-';
    final nama = data['pasien']?['nama_pasien'] ?? 'Nama tidak tersedia';
    final keluhan = data['keluhan_awal'] ?? '-';

    final tgl = formatDate(data['tanggal_kunjungan']?.toString());
    final jam = formatTime(data['created_at']?.toString());

    Widget _badge(
      String text, {
      Color? color,
      Color? border,
      Color? textColor,
    }) {
      final c = color ?? Colors.blue.shade50;
      final b = border ?? Colors.blue.shade200;
      final t = textColor ?? Colors.blue.shade700;
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmall ? 8 : 10,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: b),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: isSmall ? 11 : 12,
            fontWeight: FontWeight.w700,
            color: t,
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: EdgeInsets.all(isSmall ? 12 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _badge('No. $no'),
                _badge(
                  'Sedang Ditangani',
                  color: Colors.green.withOpacity(0.1),
                  border: Colors.green,
                  textColor: Colors.green.shade700,
                ),
              ],
            ),

            SizedBox(height: isSmall ? 8 : 10),

            Text(
              nama,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isSmall ? 15 : 16.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Keluhan: $keluhan',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade700),
            ),

            SizedBox(height: isSmall ? 8 : 10),

            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isSmall ? 8 : 10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: DefaultTextStyle(
                style: TextStyle(
                  fontSize: isSmall ? 11.5 : 12.5,
                  color: Colors.grey.shade700,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Info Pasien:',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text('Tanggal Kunjungan: $tgl'),
                    if (jam != null) Text('Waktu Daftar: $jam'),
                  ],
                ),
              ),
            ),

            SizedBox(height: isSmall ? 8 : 10),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onOpen,
                icon: Icon(Icons.medical_information, size: isSmall ? 16 : 18),
                label: Text(
                  'Lanjutkan Pemeriksaan',
                  style: TextStyle(fontSize: isSmall ? 13 : 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: isSmall ? 10 : 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SafeNetworkImage extends StatelessWidget {
  final String? url;
  final double size;
  final Widget? fallback;

  const SafeNetworkImage({
    super.key,
    required this.url,
    required this.size,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.trim().isEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(child: fallback ?? const Icon(Icons.image)),
      );
    }
    return Image.network(
      url!,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => SizedBox(
        width: size,
        height: size,
        child: Center(child: fallback ?? const Icon(Icons.broken_image)),
      ),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          width: size,
          height: size,
          child: Center(
            child: SizedBox(
              width: size * .5,
              height: size * .5,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 400;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: isSmall ? 24 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: isSmall ? 48 : 64,
              color: Colors.red.shade300,
            ),
            SizedBox(height: isSmall ? 12 : 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: isSmall ? 14 : 16),
            ),
            SizedBox(height: isSmall ? 12 : 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }
}
