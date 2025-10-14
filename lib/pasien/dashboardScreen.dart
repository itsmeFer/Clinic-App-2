import 'dart:convert';
import 'dart:async';
import 'package:RoyalClinic/pasien/Artikel.dart';
import 'package:RoyalClinic/pasien/ListPembayaran.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:RoyalClinic/pasien/Katalog.dart';
import 'package:RoyalClinic/pasien/Pembayaran.dart';
import 'package:RoyalClinic/pasien/PesanJadwal.dart';
import 'package:RoyalClinic/pasien/Testimoni.dart';
import 'package:RoyalClinic/pasien/edit_profile.dart';
import 'package:RoyalClinic/pasien/RiwayatKunjungan.dart';
import 'package:RoyalClinic/screen/login.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Main wrapper - Clean & Elegant Design
class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;
  List<dynamic> jadwalDokter = [];
  PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    fetchJadwalDokter();
  }

  Future<void> fetchJadwalDokter() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');

  if (token == null) return;

  try {
    final response = await http.get(
      Uri.parse('https://admin.royal-klinik.cloud/api/getAllDokter'),  // ✅ Use this instead
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 200 && data['success'] == true) {
      setState(() {
        jadwalDokter = data['data'];  // This will now contain your doctor data
      });
    }
  } catch (e) {
      // Handle error silently
    }
  }

  Future<void> logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar dari Akun?'),
        content: const Text('Anda akan keluar dari aplikasi Royal Clinic'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: TextStyle(color: Colors.grey.shade700)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Keluar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  void _refreshData() {
    fetchJadwalDokter();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: [
          DashboardPage(
            jadwalDokter: jadwalDokter,
            onRefresh: _refreshData,
            onLogout: logout,
          ),
          PesanJadwalPage(jadwalDokter: jadwalDokter),
          const RiwayatKunjunganPage(),
          EditProfileWrapper(onRefresh: _refreshData),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.transparent,
          selectedItemColor: const Color(0xFF00897B),
          unselectedItemColor: Colors.grey.shade500,
          selectedFontSize: 12,
          unselectedFontSize: 11,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today_outlined),
              activeIcon: Icon(Icons.calendar_today),
              label: 'Jadwal',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Riwayat',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

// Dashboard Page - Clean Design with Scroll AppBar
class DashboardPage extends StatefulWidget {
  final List<dynamic> jadwalDokter;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  const DashboardPage({
    super.key,
    required this.jadwalDokter,
    required this.onRefresh,
    required this.onLogout,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool isLoading = true;
  Map<String, dynamic>? profileData;
  int _currentBanner = 0;
  final PageController _bannerController = PageController();
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    fetchProfile();
    fetchCatalog();
    fetchArticles();
    fetchTestimoni();
    _startBannerAutoPlay();

    // Listen to scroll changes
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startBannerAutoPlay() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && _bannerController.hasClients) {
        int nextPage = (_currentBanner + 1) % 3;
        _bannerController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> fetchProfile() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://admin.royal-klinik.cloud/api/pasien/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          profileData = data['data'];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  List<dynamic> catalogList = [];
  List<dynamic> articleList = [];
  List<dynamic> testimoniList = [];

  Map<int, Map<String, dynamic>> getUniqueDokter() {
    final Map<int, Map<String, dynamic>> uniqueDokter = {};

    for (var jadwal in widget.jadwalDokter) {
      final dokter = jadwal['dokter'];
      if (dokter != null) {
        final dokterId = dokter['id'];

        if (!uniqueDokter.containsKey(dokterId)) {
          final totalJadwal = widget.jadwalDokter
              .where(
                (j) => j['dokter'] != null && j['dokter']['id'] == dokterId,
              )
              .length;

          uniqueDokter[dokterId] = {
            'dokter': dokter,
            'total_jadwal': totalJadwal,
            'sample_jadwal': jadwal,
          };
        }
      }
    }

    return uniqueDokter;
  }

  Future<void> fetchCatalog() async {
    try {
      final response = await http.get(
        Uri.parse('https://backend.royal-klinik.cloud/api/upload/catalogs'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            catalogList = data['data']['catalogs'] ?? [];
          });
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> fetchArticles() async {
    try {
      final response = await http.get(
        Uri.parse('https://backend.royal-klinik.cloud/api/upload/articles'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            articleList = data['data']['articles'] ?? [];
          });
        }
      }
    } catch (e) {
      // Handle error silently
    }
  }

  Future<void> fetchTestimoni() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('https://admin.royal-klinik.cloud/api/getDataTestimoni'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          testimoniList = data['Data Testimoni'] ?? [];
        });
      }
    } catch (e) {
      // Handle error silently
    }
  }

  // Helper method untuk safe image loading
  Widget buildSafeImage({
    required String? imagePath,
    required double width,
    required double height,
    required IconData fallbackIcon,
    required double iconSize,
    required Color iconColor,
    required BorderRadius borderRadius,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: borderRadius,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: (imagePath != null && imagePath.trim().isNotEmpty)
            ? Image.network(
                'https://admin.royal-klinik.cloud/storage/$imagePath',
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2,
                      color: iconColor,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    fallbackIcon,
                    size: iconSize,
                    color: iconColor,
                  );
                },
              )
            : Icon(
                fallbackIcon,
                size: iconSize,
                color: iconColor,
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pasien = profileData;

    // Calculate AppBar opacity based on scroll - lebih smooth dengan range yang lebih besar
    double appBarOpacity = (_scrollOffset / 200).clamp(0.0, 1.0);

    return isLoading
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF00897B)),
          )
        : pasien == null
        ? const Center(child: Text('Tidak ada data profil'))
        : Scaffold(
            backgroundColor: Colors.grey.shade50,
            extendBodyBehindAppBar: true,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: Container(
                decoration: BoxDecoration(
                  color: Color.lerp(
                    Colors.white.withOpacity(0.0), // Mulai dari transparan
                    const Color(0xFF00897B), // Berubah ke teal
                    appBarOpacity,
                  ),
                  boxShadow: appBarOpacity > 0.3
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(
                              0.15 * appBarOpacity,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  title: Row(
                    children: [
                      Image.asset(
                        'assets/gambar/logo.png',
                        height: 28,
                        width: 28,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Royal Clinic',
                        style: TextStyle(
                          color: Color.lerp(
                            Colors.black87, // Mulai dari hitam
                            Colors.white, // Berubah ke putih
                            appBarOpacity,
                          ),
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(
                        Icons.logout,
                        color: Color.lerp(
                          Colors.grey.shade700, // Mulai dari abu-abu
                          Colors.white, // Berubah ke putih
                          appBarOpacity,
                        ),
                        size: 22,
                      ),
                      onPressed: widget.onLogout,
                    ),
                  ],
                ),
              ),
            ),
            body: ListView(
              controller: _scrollController,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              children: [
                // Banner Carousel
                Container(
                  height: 160,
                  margin: const EdgeInsets.only(bottom: 0),
                  child: Stack(
                    children: [
                      PageView(
                        controller: _bannerController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentBanner = index;
                          });
                        },
                        children: [
                          // Banner 1 - Gradient Purple
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF667EEA,
                                  ).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  right: -20,
                                  bottom: -20,
                                  child: Icon(
                                    Icons.local_hospital,
                                    size: 140,
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: const Text(
                                          'Promo Spesial',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Konsultasi Gratis\nUntuk Pasien Baru!',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Dapatkan sesi konsultasi pertama gratis',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Banner 2 - Gradient Blue
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF00B4DB), Color(0xFF0083B0)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF00B4DB,
                                  ).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  right: -20,
                                  bottom: -20,
                                  child: Icon(
                                    Icons.health_and_safety,
                                    size: 140,
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: const Text(
                                          'Layanan Unggulan',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Medical Check-Up\nLengkap',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Paket pemeriksaan kesehatan menyeluruh',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Banner 3 - Gradient Teal
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF11998E,
                                  ).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  right: -20,
                                  bottom: -20,
                                  child: Icon(
                                    Icons.medical_services,
                                    size: 140,
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: const Text(
                                          'Info Penting',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Layanan 24 Jam\nSetiap Hari!',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Kami siap melayani Anda kapan saja',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 13,
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
                      // Indicator dots
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(3, (index) {
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: _currentBanner == index ? 20 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _currentBanner == index
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.4),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),

                // Menu Grid
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85,
                  children: [
                    _buildMenuItem(
                      imagePath: 'assets/icons/testimoni.png',
                      label: 'Testimoni',
                      color: const Color(0xFF7B1FA2),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TestimoniPage(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      imagePath: 'assets/icons/artikel.png',
                      label: 'Artikel',
                      color: const Color(0xFF1976D2),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Artikel(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      imagePath: 'assets/icons/layanan.png',
                      label: 'Layanan',
                      color: const Color(0xFFE64A19),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Katalog(),
                          ),
                        );
                      },
                    ),
                    _buildMenuItem(
                      imagePath: 'assets/icons/bayar.png',
                      label: 'Bayar',
                      color: const Color(0xFF388E3C),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ListPembayaran(),
                          ),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Profile Section - FIXED
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        const Color(0xFF00897B).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF00897B).withOpacity(0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      buildSafeImage(
                        imagePath: profileData?['foto_pasien']?.toString(),
                        width: 60,
                        height: 60,
                        fallbackIcon: Icons.person,
                        iconSize: 32,
                        iconColor: const Color(0xFF00897B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (pasien['nama_pasien']?.toString().isNotEmpty == true)
                                  ? pasien['nama_pasien']
                                  : pasien['username'] ?? '-',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              pasien['email']?.toString() ?? '-',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Quick Stats Cards
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF667EEA).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.medical_services,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Total Layanan',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${catalogList.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFF093FB), Color(0xFFF5576C)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF093FB).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.calendar_today,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Jadwal Tersedia',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${widget.jadwalDokter.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Info Banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF00D2FF), Color(0xFF3A7BD5)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00D2FF).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.info_outline,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tips Kesehatan',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Jangan lupa minum air putih 8 gelas sehari dan istirahat cukup!',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Dokter Tersedia Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Dokter Tersedia',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (widget.jadwalDokter.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  PesanJadwal(allJadwal: widget.jadwalDokter),
                            ),
                          );
                        },
                        child: const Text(
                          'Lihat Semua',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF00897B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (widget.jadwalDokter.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 48,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Belum ada dokter tersedia',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Builder(
                    builder: (context) {
                      final uniqueDokter = getUniqueDokter();
                      final dokterList = uniqueDokter.values.toList();

                      return Column(
                        children: [
                          ...dokterList.take(3).map((dokterData) {
                            final dokter = dokterData['dokter'];
                            final totalJadwal = dokterData['total_jadwal'];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  buildSafeImage(
                                    imagePath: dokter['foto_dokter']?.toString(),
                                    width: 80,
                                    height: 80,
                                    fallbackIcon: Icons.person,
                                    iconSize: 40,
                                    iconColor: const Color(0xFF00897B),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dokter['nama_dokter']?.toString() ??
                                              'Nama tidak tersedia',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          dokter['jenis_spesialis']
                                                  ?['nama_spesialis']
                                                  ?.toString() ??
                                              'Spesialis Umum',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF00897B,
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            '$totalJadwal jadwal tersedia',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF00897B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      );
                    },
                  ),

                const SizedBox(height: 24),

                // Katalog Layanan Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Katalog Layanan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (catalogList.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const Katalog(),
                            ),
                          );
                        },
                        child: const Text(
                          'Lihat Semua',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF00897B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (catalogList.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.medical_services_outlined,
                            size: 48,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Belum ada katalog layanan',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: catalogList.take(3).map((catalog) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const Katalog(),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  catalog['imageUrl']?.toString() ?? '',
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 60,
                                      height: 60,
                                      color: Colors.grey.shade300,
                                      child: const Icon(
                                        Icons.image_not_supported,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      catalog['title']?.toString() ?? 'Tidak ada judul',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      catalog['category']?['name']?.toString() ?? 'Kategori tidak ada',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 24),
                // Artikel Kesehatan Section

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Artikel Kesehatan',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (articleList.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const Artikel(),
                            ),
                          );
                        },
                        child: const Text(
                          'Lihat Semua',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF00897B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (articleList.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.article_outlined,
                            size: 48,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Belum ada artikel tersedia',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: articleList.take(3).map((article) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const Artikel(),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  article['imageUrl']?.toString() ?? '',
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 60,
                                      height: 60,
                                      color: Colors.grey.shade300,
                                      child: const Icon(Icons.article),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      article['title']?.toString() ?? 'Tidak ada judul',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      article['category']?['name']?.toString() ?? 'Kategori tidak ada',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 24),

                // Testimoni Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Testimoni Pasien',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (testimoniList.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const TestimoniPage(),
                            ),
                          );
                        },
                        child: const Text(
                          'Lihat Semua',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF00897B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                if (testimoniList.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.rate_review_outlined,
                            size: 48,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Belum ada testimoni',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    children: testimoniList.take(3).map((testimoni) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const TestimoniPage(),
                              ),
                            );
                          },
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF00897B,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    testimoni['nama_testimoni']?.toString().isNotEmpty == true
                                        ? testimoni['nama_testimoni'][0].toString().toUpperCase()
                                        : 'T',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF00897B),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      testimoni['nama_testimoni']?.toString() ?? 'Nama tidak tersedia',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      testimoni['isi_testimoni']?.toString() ?? 'Tidak ada testimoni',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 80),
              ],
            ),
          );
  }

  Widget _buildMenuItem({
    required String imagePath,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              flex: 3,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      right: -5,
                      bottom: -5,
                      child: Image.asset(
                        imagePath,
                        width: 40,
                        height: 40,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Flexible(
              flex: 1,
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Wrapper classes
class PesanJadwalPage extends StatelessWidget {
  final List<dynamic> jadwalDokter;

  const PesanJadwalPage({super.key, required this.jadwalDokter});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Jadwal Dokter',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: PesanJadwal(allJadwal: jadwalDokter),
    );
  }
}

class RiwayatKunjunganPage extends StatelessWidget {
  const RiwayatKunjunganPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Riwayat Kunjungan',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: const RiwayatKunjungan(),
    );
  }
}

class EditProfileWrapper extends StatelessWidget {
  final VoidCallback onRefresh;

  const EditProfileWrapper({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Profil Saya',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00897B).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 40,
                      color: Color(0xFF00897B),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Edit Profil Anda',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Perbarui informasi profil Anda',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EditProfilePage(),
                          ),
                        ).then((result) {
                          if (result == true) {
                            onRefresh();
                          }
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00897B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Edit Profil',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
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
  }}