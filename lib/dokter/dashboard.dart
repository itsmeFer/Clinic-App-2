import 'dart:convert';
import 'package:RoyalClinic/dokter/EditProfilDokter.dart';
import 'package:RoyalClinic/dokter/Pemeriksaan.dart';
import 'package:RoyalClinic/dokter/RiwayatPasien.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // ✅ Import Font Awesome
// Import shared sidebar with prefix to avoid conflicts
import 'package:RoyalClinic/dokter/Sidebar.dart' as Sidebar;

class DokterDashboard extends StatefulWidget {
  const DokterDashboard({Key? key}) : super(key: key);

  @override
  State<DokterDashboard> createState() => _DokterDashboardState();
}

class _DokterDashboardState extends State<DokterDashboard> {
  bool isLoading = true;
  String? errorMessage;

  // Sidebar state
  bool isSidebarCollapsed = false;

  Map<String, dynamic>? dokterData;
  List<dynamic> kunjunganEngaged = [];
  List<dynamic> allKunjungan = [];

  // KPI yang dipakai
  Map<String, int> statistik = {'janji_hari_ini': 0, 'antrian_aktif': 0};

  // Filter states
  String selectedNameFilter = 'Semua';
  String selectedPoliFilter = 'Semua Poli';
  String searchQuery = '';
  List<String> availablePoliFilters = ['Semua Poli'];
  List<String> availableNameFilters = [
    'Semua',
    'Terbaru',
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
  ];

  final TextEditingController _searchController = TextEditingController();

  // ===== NAVIGATION HANDLERS (SIMPLIFIED) =====
  void _handleSidebarNavigation(Sidebar.SidebarPage page) {
    // ✅ FIXED: Handle profil dokter navigation dengan refresh
    if (page == Sidebar.SidebarPage.profilDokter) {
      _goEditProfile();
      return;
    }

    // Gunakan NavigationHelper yang sudah ada di Sidebar.dart untuk page lain
    Sidebar.NavigationHelper.navigateToPage(
      context,
      page,
      dokterData: dokterData,
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await Sidebar.NavigationHelper.showLogoutConfirmation(
      context,
    );
    if (confirm) {
      await Sidebar.NavigationHelper.logout(context);
    }
  }

  // ===== HELPER METHODS =====
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

  Map<String, dynamic> _deepCopyMap(Map<String, dynamic> original) {
    Map<String, dynamic> copy = {};
    original.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        copy[key] = _deepCopyMap(value);
      } else if (value is List) {
        copy[key] = value.map((item) {
          if (item is Map<String, dynamic>) {
            return _deepCopyMap(item);
          }
          return item;
        }).toList();
      } else {
        copy[key] = value;
      }
    });
    return copy;
  }

  // ===== DATA LOADING METHODS =====
  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
        _updateAvailableFilters();
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
        Uri.parse('http://10.19.0.247:8000/api/dokter/get-data-dokter'),
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
          final mutableDokterData = _deepCopyMap(first);

          setStateSafe(() => dokterData = mutableDokterData);
          await _saveDoctorIdIfAny(mutableDokterData);
        }
      } else if (response.statusCode == 401) {
        await _handleTokenExpired();
      }
    } catch (e) {
      print('❌ Error loading dokter profile: $e');
    }
  }

  Future<void> _loadKunjunganEngaged() async {
    try {
      final token = await _getToken();
      if (!mounted) return;
      if (token == null) return;

      final response = await http.get(
        Uri.parse(
          'http://10.19.0.247:8000/api/dokter/get-data-kunjungan-by-id-dokter',
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
            allKunjungan = kunjunganList;
            _updateAvailableFilters();
            _applyFilters();
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
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  // ===== FILTER & CALCULATION METHODS =====
  void _updateAvailableFilters() {
    final Set<String> poliNames = {'Semua Poli'};

    if (dokterData != null && dokterData!['all_poli'] != null) {
      final allPoliList = dokterData!['all_poli'] as List;
      for (final poli in allPoliList) {
        if (poli is Map && poli['nama_poli'] != null) {
          poliNames.add(poli['nama_poli'].toString());
        }
      }
    }

    setStateSafe(() {
      availablePoliFilters = poliNames.toList();
    });
  }

  void _applyFilters() {
    List<dynamic> filtered = List.from(allKunjungan);

    if (selectedNameFilter != 'Semua') {
      if (selectedNameFilter == 'Terbaru') {
        filtered.sort((a, b) {
          try {
            final dateA = DateTime.parse(
              a['created_at']?.toString() ?? '2000-01-01',
            ).toLocal();
            final dateB = DateTime.parse(
              b['created_at']?.toString() ?? '2000-01-01',
            ).toLocal();
            return dateB.compareTo(dateA);
          } catch (e) {
            return 0;
          }
        });
      } else {
        filtered = filtered.where((k) {
          final nama = k['pasien']?['nama_pasien']?.toString() ?? '';
          if (nama.isEmpty) return false;
          return nama.toUpperCase().startsWith(selectedNameFilter);
        }).toList();
      }
    }

    if (selectedPoliFilter != 'Semua Poli') {
      filtered = filtered.where((k) {
        final poliName = k['poli']?['nama_poli']?.toString();
        return poliName == selectedPoliFilter;
      }).toList();
    }

    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      filtered = filtered.where((k) {
        final nama =
            k['pasien']?['nama_pasien']?.toString().toLowerCase() ?? '';
        final keluhan = k['keluhan_awal']?.toString().toLowerCase() ?? '';
        final noAntrian = k['no_antrian']?.toString().toLowerCase() ?? '';

        return nama.contains(query) ||
            keluhan.contains(query) ||
            noAntrian.contains(query);
      }).toList();
    }

    setStateSafe(() {
      kunjunganEngaged = filtered;
    });

    _calculateStatistik();
  }

  void _resetFilters() {
    setStateSafe(() {
      selectedNameFilter = 'Semua';
      selectedPoliFilter = 'Semua Poli';
      searchQuery = '';
      _searchController.clear();
    });
    _applyFilters();
  }

  String _getActiveFiltersText() {
    List<String> activeFilters = [];

    if (selectedNameFilter != 'Semua') {
      if (selectedNameFilter == 'Terbaru') {
        activeFilters.add('Urutkan: Terbaru');
      } else {
        activeFilters.add('Huruf: $selectedNameFilter');
      }
    }
    if (selectedPoliFilter != 'Semua Poli') {
      activeFilters.add(selectedPoliFilter);
    }
    if (searchQuery.isNotEmpty) {
      activeFilters.add('Pencarian: "$searchQuery"');
    }

    return activeFilters.join(', ');
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

  int _countAppointmentsToday() {
    final now = DateTime.now().toLocal();
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

        if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
          count++;
        }
      } catch (e) {
        // Ignore parsing errors
      }
    }

    return count;
  }

  // ===== NAVIGATION METHODS =====
  Future<void> _goEditProfile() async {
    if (dokterData == null) return;

    // ✅ FIXED: Navigate dengan nama class yang benar
    final updatedData = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilDokter(dokterData: dokterData!),
      ),
    );

    // ✅ Refresh data dokter setelah edit
    if (updatedData != null) {
      await _loadDokterProfile();
    }
  }

  Future<void> _navigateToPemeriksaan(
    Map<String, dynamic> kunjunganData,
  ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Pemeriksaan(kunjunganData: kunjunganData),
      ),
    );

    // Handle result jika diperlukan
    if (result != null && result['success'] == true) {
      _onPemeriksaanCompleted(kunjunganData['id']);
    }
  }

  void _onPemeriksaanCompleted(int kunjunganId) {
    setStateSafe(() {
      allKunjungan.removeWhere((k) => k['id'] == kunjunganId);
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

  // ===== UI BUILD METHODS =====
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;
    final isMobile = screenWidth < 768;

    return Scaffold(
      body: Row(
        children: [
          // ✅ INI YANG BENAR: Sidebar di kiri (BUKAN SharedTopHeader)
          if (isDesktop || isTablet)
            Sidebar.SharedSidebar(
              currentPage: Sidebar.SidebarPage.dashboard,
              dokterData: dokterData,
              isCollapsed: isSidebarCollapsed,
              onToggleCollapse: () =>
                  setState(() => isSidebarCollapsed = !isSidebarCollapsed),
              onNavigate: _handleSidebarNavigation,
              onLogout: _handleLogout,
            ),

          // ✅ Area konten dibatasi oleh Expanded
          Expanded(
            child: Column(
              children: [
                // ✅ Header ada di area konten (aman, lebar sudah dibatasi)
                Sidebar.SharedTopHeader(
                  currentPage: Sidebar.SidebarPage.dashboard,
                  dokterData: dokterData,
                  isMobile: isMobile,
                  onRefresh: _loadDashboardData,
                ),
                Expanded(child: _buildMainContent()),
              ],
            ),
          ),
        ],
      ),
      // ✅ Drawer hanya untuk mobile
      drawer: isMobile
          ? Sidebar.SharedMobileDrawer(
              currentPage: Sidebar.SidebarPage.dashboard,
              dokterData: dokterData,
              onNavigate: _handleSidebarNavigation,
              onLogout: _handleLogout,
            )
          : null,
    );
  }

  // ================== MAIN CONTENT + RIGHT SIDEBAR ==================
Widget _buildMainContent() {
  final screenWidth = MediaQuery.of(context).size.width;
  // threshold kapan right sidebar muncul, bebas kamu mau 1024/1200
  final showRightSidebar = screenWidth >= 1200;

  return Container(
    color: const Color(0xFFF8FAFC),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // konten utama di kiri
        Expanded(
          child: _buildMainCenterContent(),
        ),

        // right sidebar (hanya desktop lebar)
        if (showRightSidebar) ...[
          const SizedBox(width: 24),
          const SizedBox(
            width: 280,
            child: Sidebar.SharedRightSidebar(),
          ),
          const SizedBox(width: 24),
        ],
      ],
    ),
  );
}

// ================== KONTEN TENGAH (ISI LAMA) ==================
Widget _buildMainCenterContent() {
  if (isLoading) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF06B6D4)),
          SizedBox(height: 16),
          Text(
            'Memuat data...',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
          ),
        ],
      ),
    );
  }

  if (errorMessage != null) {
    return _ErrorState(message: errorMessage!, onRetry: _loadDashboardData);
  }

  return LayoutBuilder(
    builder: (context, constraints) {
      final isSmallScreen = constraints.maxWidth < 768;

      return RefreshIndicator(
        onRefresh: _loadDashboardData,
        color: const Color(0xFF06B6D4),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              if (dokterData != null) ...[
                _buildWelcomeSection(isSmallScreen),
                const SizedBox(height: 24),
              ],

              // Statistics Cards
              _buildStatisticsSection(isSmallScreen),
              const SizedBox(height: 24),

              // Filter Section
              _buildFilterSection(isSmallScreen),
              const SizedBox(height: 24),

              // Patient List
              _buildPatientListSection(isSmallScreen),
            ],
          ),
        ),
      );
    },
  );
}


  Widget _buildWelcomeSection(bool isSmall) {
    if (dokterData == null) return const SizedBox.shrink();

    final nama = dokterData!['nama_dokter'] ?? 'Dokter';
    final foto = dokterData!['foto_dokter'];

    return Container(
      padding: EdgeInsets.all(isSmall ? 20 : 28),
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
          Container(
            width: isSmall ? 60 : 70,
            height: isSmall ? 60 : 70,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: ClipOval(
              child: Sidebar.SafeNetworkImage(
                url: foto != null
                    ? 'http://10.19.0.247:8000/storage/$foto'
                    : null,
                size: isSmall ? 60 : 70,
                fallback: FaIcon(
                  FontAwesomeIcons.userDoctor, // ✅ user-doctor icon
                  color: Colors.white,
                  size: isSmall ? 30 : 35,
                ),
              ),
            ),
          ),
          SizedBox(width: isSmall ? 16 : 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selamat Datang Kembali!',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: isSmall ? 14 : 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dr. $nama',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmall ? 22 : 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _goEditProfile,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: FaIcon(
                FontAwesomeIcons.penToSquare, // ✅ edit icon
                color: Colors.white,
                size: isSmall ? 18 : 20,
              ),
            ),
            tooltip: 'Edit Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection(bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ringkasan Hari Ini',
          style: TextStyle(
            fontSize: isSmall ? 18 : 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 16),

        GridView.builder(
          shrinkWrap: true,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 4,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isSmall ? 2 : 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: isSmall ? 170 : 180,
          ),
          itemBuilder: (context, index) {
            switch (index) {
              case 0:
                return _buildStatCard(
                  'Janji Hari Ini',
                  statistik['janji_hari_ini'] ?? 0,
                  FontAwesomeIcons.calendarCheck, // ✅ calendar-check
                  const Color(0xFF059669),
                );
              case 1:
                return _buildStatCard(
                  'Antrian Aktif',
                  statistik['antrian_aktif'] ?? 0,
                  FontAwesomeIcons
                      .clockRotateLeft, // ✅ clock-rotate-left (queue)
                  const Color(0xFF0891B2),
                );
              case 2:
                final total =
                    (statistik['janji_hari_ini'] ?? 0) +
                    (statistik['antrian_aktif'] ?? 0);
                return _buildStatCard(
                  'Total Pasien',
                  total,
                  FontAwesomeIcons.userGroup, // ✅ user-group (people)
                  const Color(0xFF7C3AED),
                );
              default:
                return _buildStatCard(
                  'Selesai Hari Ini',
                  0,
                  FontAwesomeIcons.circleCheck, // ✅ circle-check
                  const Color(0xFFDC2626),
                );
            }
          },
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: FaIcon(icon, color: color, size: 20), // ✅ Font Awesome
              ),
              FaIcon(
                FontAwesomeIcons.arrowTrendUp, // ✅ trending-up
                color: Colors.grey.shade400,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(bool isSmall) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 16 : 20),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0891B2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const FaIcon(
                  FontAwesomeIcons.filter, // ✅ filter icon
                  color: Color(0xFF0891B2),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Filter & Pencarian Pasien',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            ),
            child: TextField(
              controller: _searchController,
              textAlignVertical:
                  TextAlignVertical.center, // ⬅️ biar isi + icon center
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Cari nama pasien, keluhan, atau nomor antrian...',
                hintStyle: TextStyle(
                  fontSize: isSmall ? 13 : 14,
                  color: Colors.grey.shade500,
                ),

                // ✅ prefix icon dirapikan, tidak “ngambang”
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: FaIcon(
                    FontAwesomeIcons.magnifyingGlass,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),

                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: FaIcon(
                          FontAwesomeIcons.xmark,
                          size: 16,
                          color: Colors.grey.shade500,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => searchQuery = '');
                          _applyFilters();
                        },
                      )
                    : null,

                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: 12, // ⬅️ kecilin padding vertikal
                ),
              ),
              style: TextStyle(fontSize: isSmall ? 13 : 14),
              onChanged: (value) {
                setState(() => searchQuery = value);
                _applyFilters();
              },
            ),
          ),

          // Active Filters Info
          if (selectedNameFilter != 'Semua' ||
              selectedPoliFilter != 'Semua Poli' ||
              searchQuery.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0891B2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF0891B2).withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  const FaIcon(
                    FontAwesomeIcons.circleInfo, // ✅ info icon
                    color: Color(0xFF0891B2),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Filter aktif: ${_getActiveFiltersText()}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF0891B2),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _resetFilters,
                    icon: const FaIcon(
                      FontAwesomeIcons.xmark, // ✅ clear icon
                      size: 14,
                      color: Color(0xFFDC2626),
                    ),
                    label: const Text(
                      'Reset',
                      style: TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                    ),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(60, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPatientListSection(bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const FaIcon(
                FontAwesomeIcons.userGroup, // ✅ people icon
                color: Color(0xFF059669),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pasien Sedang Ditangani',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Text(
                  '${kunjunganEngaged.length} pasien aktif',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (kunjunganEngaged.isEmpty)
          _buildEmptyState()
        else
          _buildPatientList(isSmall),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: FaIcon(
              allKunjungan.isEmpty
                  ? FontAwesomeIcons
                        .briefcaseMedical // ✅ medical services
                  : FontAwesomeIcons.filterCircleXmark, // ✅ filter off
              size: 48,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            allKunjungan.isEmpty
                ? 'Tidak ada pasien yang sedang ditangani'
                : 'Tidak ada pasien yang sesuai filter',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            allKunjungan.isEmpty
                ? 'Pasien akan muncul di sini setelah status menjadi "Engaged".'
                : 'Coba ubah filter atau reset untuk melihat semua data.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPatientList(bool isSmall) {
    return Column(
      children: List.generate(kunjunganEngaged.length, (index) {
        final card = _buildModernPatientCard(kunjunganEngaged[index], isSmall);
        return Padding(padding: const EdgeInsets.only(bottom: 12), child: card);
      }),
    );
  }

  Widget _buildModernPatientCard(Map<String, dynamic> data, bool isSmall) {
    final no = data['no_antrian'] ?? '-';
    final nama = data['pasien']?['nama_pasien'] ?? 'Nama tidak tersedia';
    final keluhan = data['keluhan_awal'] ?? '-';

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
      child: Padding(
        padding: EdgeInsets.all(isSmall ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0891B2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'No. $no',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF059669)),
                  ),
                  child: const Text(
                    'Sedang Ditangani',
                    style: TextStyle(
                      color: Color(0xFF059669),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              nama,
              style: TextStyle(
                fontSize: isSmall ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1E293B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FaIcon(
                        FontAwesomeIcons.notesMedical, // ✅ medical information
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Keluhan:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    keluhan,
                    style: TextStyle(
                      fontSize: isSmall ? 13 : 14,
                      color: const Color(0xFF374151),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _navigateToPemeriksaan(data),
                icon: const FaIcon(
                  FontAwesomeIcons.stethoscope,
                  size: 18,
                ), // ✅ stethoscope
                label: const Text(
                  'Lanjutkan Pemeriksaan',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
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

// Error State Widget
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: FaIcon(
                FontAwesomeIcons.triangleExclamation, // ✅ error icon
                size: 48,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Oops! Terjadi Kesalahan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const FaIcon(
                FontAwesomeIcons.arrowsRotate,
                size: 16,
              ), // ✅ refresh icon
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0891B2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
