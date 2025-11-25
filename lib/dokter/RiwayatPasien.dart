import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // ✅ Import Font Awesome

// Import shared sidebar dengan prefix
import 'Sidebar.dart' as Sidebar;
// HANYA RMPasien
import 'RMPasien.dart';

class RiwayatPasienPage extends StatefulWidget {
  @override
  _RiwayatPasienPageState createState() => _RiwayatPasienPageState();
}

class _RiwayatPasienPageState extends State<RiwayatPasienPage>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Data variables
  List<dynamic> riwayatPasien = [];
  List<dynamic> filteredRiwayatPasien = [];
  bool isLoading = true;
  String? errorMessage;
  String baseUrl = 'http://10.19.0.247:8000/api';

  // UI State
  bool isSidebarCollapsed = false;
  Map<String, dynamic>? dokterData;

  // Search & filter
  TextEditingController searchController = TextEditingController();
  String selectedStatusFilter = 'Semua Status';
  String selectedDateFilter = 'Semua Tanggal';
  List<String> availableStatusFilters = [
    'Semua Status',
    'Succeed',
    'Canceled',
    'Payment',
  ];
  List<String> availableDateFilters = [
    'Semua Tanggal',
    'Hari Ini',
    'Minggu Ini',
    'Bulan Ini',
  ];

  // Anim
  late AnimationController _fadeAnimationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeInOut,
    );
    _loadDokterProfile();
    _loadRiwayatPasien();
    searchController.addListener(_filterPasien);
  }

  @override
  void dispose() {
    searchController.removeListener(_filterPasien);
    searchController.dispose();
    _fadeAnimationController.dispose();
    super.dispose();
  }

  void setStateSafe(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  // ===== NAV =====
  void _handleSidebarNavigation(Sidebar.SidebarPage page) {
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
    if (confirm) await Sidebar.NavigationHelper.logout(context);
  }

  // ===== DATA =====
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _loadDokterProfile() async {
    try {
      final token = await _getToken();
      if (token == null) return;
      final res = await http.get(
        Uri.parse('$baseUrl/dokter/get-data-dokter'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true &&
            data['Data Dokter'] is List &&
            data['Data Dokter'].isNotEmpty) {
          setStateSafe(() => dokterData = data['Data Dokter'].first);
        }
      }
    } catch (_) {}
  }

  /// ✅ UPDATED: Endpoint sama, tapi sekarang backend filter berdasarkan EMR dokter_id
  /// Tidak perlu perubahan di Flutter karena API contract tetap sama
  Future<void> _loadRiwayatPasien() async {
    try {
      setStateSafe(() {
        isLoading = true;
        errorMessage = null;
      });
      final token = await _getToken();
      if (token == null)
        throw Exception('Token tidak ditemukan. Silakan login kembali.');

      // ✅ Backend sekarang filter berdasarkan EMR.dokter_id bukan poli
      // Endpoint tetap sama: /dokter/riwayat-pasien-diperiksa
      final resp = await http.get(
        Uri.parse('$baseUrl/dokter/riwayat-pasien-diperiksa'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (resp.statusCode == 401) {
        await _handleTokenExpired();
        return;
      }
      if (resp.statusCode != 200)
        throw Exception('Gagal memuat data (${resp.statusCode})');

      final data = json.decode(resp.body);
      if (data['success'] == true) {
        setStateSafe(() {
          riwayatPasien = (data['data'] as List?) ?? [];
          filteredRiwayatPasien = riwayatPasien;
          isLoading = false;
        });
        _fadeAnimationController.forward();
        
        // ✅ DEBUG: Log filtering method dari backend
        if (data['dokter_info'] != null && data['dokter_info']['filtering_method'] != null) {
          print('🔍 Backend filtering method: ${data['dokter_info']['filtering_method']}');
        }
      } else {
        throw Exception(data['message'] ?? 'Gagal memuat data');
      }
    } catch (e) {
      setStateSafe(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _handleTokenExpired() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sesi berakhir. Silakan login kembali.'),
        backgroundColor: Colors.red,
      ),
    );
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  // ===== FILTER =====
  void _filterPasien() {
    final q = searchController.text.toLowerCase().trim();
    setStateSafe(() {
      List<dynamic> f = List.from(riwayatPasien);
      if (q.isNotEmpty) {
        f = f.where((p) {
          final nama = (p['pasien']?['nama_pasien'] ?? '')
              .toString()
              .toLowerCase();
          final antri = (p['no_antrian'] ?? '').toString().toLowerCase();
          final diag = (p['emr']?['diagnosis'] ?? '').toString().toLowerCase();
          // ✅ TAMBAHAN: Search berdasarkan no_emr
          final noEmr = (p['pasien']?['no_emr'] ?? '').toString().toLowerCase();
          return nama.contains(q) || antri.contains(q) || diag.contains(q) || noEmr.contains(q);
        }).toList();
      }
      if (selectedStatusFilter != 'Semua Status') {
        f = f
            .where(
              (p) => (p['status'] ?? '').toString().toLowerCase().contains(
                selectedStatusFilter.toLowerCase(),
              ),
            )
            .toList();
      }
      if (selectedDateFilter != 'Semua Tanggal') {
        final now = DateTime.now();
        f = f.where((p) {
          try {
            final d = DateTime.parse(p['tanggal_kunjungan']);
            switch (selectedDateFilter) {
              case 'Hari Ini':
                return d.year == now.year &&
                    d.month == now.month &&
                    d.day == now.day;
              case 'Minggu Ini':
                final start = now.subtract(Duration(days: now.weekday - 1));
                return d.isAfter(start) &&
                    d.isBefore(now.add(const Duration(days: 1)));
              case 'Bulan Ini':
                return d.year == now.year && d.month == now.month;
            }
          } catch (_) {}
          return true;
        }).toList();
      }
      filteredRiwayatPasien = f;
    });
  }

  void _resetFilters() {
    setStateSafe(() {
      selectedStatusFilter = 'Semua Status';
      selectedDateFilter = 'Semua Tanggal';
      searchController.clear();
    });
    _filterPasien();
  }

  // ===== UTIL =====
  String _formatDate(String? s) {
    if (s == null || s.isEmpty) return 'N/A';
    try {
      return DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(s));
    } catch (_) {
      return s;
    }
  }

  Widget _statusChip(String status, bool small) {
    Color bg, fg;
    switch (status.toLowerCase()) {
      case 'succeed':
      case 'completed':
      case 'selesai':
      case 'done':
        bg = Colors.green.shade100;
        fg = Colors.green.shade700;
        break;
      case 'canceled':
      case 'dibatalkan':
        bg = Colors.red.shade100;
        fg = Colors.red.shade700;
        break;
      case 'payment':
      case 'paid':
      case 'lunas':
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade700;
        break;
      default:
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade700;
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: small ? 9 : 10,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final w = MediaQuery.of(context).size.width;
    final isDesktop = w >= 1024;
    final isTablet = w >= 768 && w < 1024;
    final isMobile = w < 768;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (isDesktop || isTablet)
              Sidebar.SharedSidebar(
                currentPage: Sidebar.SidebarPage.riwayatPasien,
                dokterData: dokterData,
                isCollapsed: isSidebarCollapsed,
                onToggleCollapse: () =>
                    setState(() => isSidebarCollapsed = !isSidebarCollapsed),
                onNavigate: _handleSidebarNavigation,
                onLogout: _handleLogout,
              ),
            Expanded(
              child: Column(
                children: [
                  Sidebar.SharedTopHeader(
                    currentPage: Sidebar.SidebarPage.riwayatPasien,
                    dokterData: dokterData,
                    isMobile: isMobile,
                    onRefresh: _loadRiwayatPasien,
                  ),
                  Expanded(child: _buildMainContent()),
                ],
              ),
            ),
          ],
        ),
      ),
      drawer: isMobile
          ? Sidebar.SharedMobileDrawer(
              currentPage: Sidebar.SidebarPage.riwayatPasien,
              dokterData: dokterData,
              onNavigate: _handleSidebarNavigation,
              onLogout: _handleLogout,
            )
          : null,
    );
  }

  Widget _buildMainContent() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF06B6D4)),
            SizedBox(height: 16),
            Text(
              'Memuat riwayat pasien yang Anda periksa...', // ✅ UPDATED TEXT
              style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
            ),
          ],
        ),
      );
    }
    if (errorMessage != null) {
      return _ErrorState(message: errorMessage!, onRetry: _loadRiwayatPasien);
    }

    return Container(
      color: const Color(0xFFF8FAFC),
      child: LayoutBuilder(
        builder: (context, c) {
          final small = c.maxWidth < 768;
          return RefreshIndicator(
            onRefresh: _loadRiwayatPasien,
            color: const Color(0xFF06B6D4),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(small ? 12 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatisticsSection(small),
                  SizedBox(height: small ? 16 : 20),
                  _buildFilterSection(small),
                  SizedBox(height: small ? 16 : 20),
                  _buildPatientListSection(small),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatisticsSection(bool small) {
    final succeeded = riwayatPasien
        .where(
          (p) =>
              (p['status'] ?? '').toString().toLowerCase().contains('succeed'),
        )
        .length;
    final canceled = riwayatPasien
        .where(
          (p) =>
              (p['status'] ?? '').toString().toLowerCase().contains('cancel'),
        )
        .length;
    final payment = riwayatPasien
        .where(
          (p) =>
              (p['status'] ?? '').toString().toLowerCase().contains('payment'),
        )
        .length;

    Widget card(String title, int val, IconData ic, Color color) => Container(
      padding: EdgeInsets.all(small ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 8,
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
                padding: EdgeInsets.all(small ? 6 : 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: FaIcon(ic, color: color, size: small ? 16 : 18),
              ),
              FaIcon(
                FontAwesomeIcons.arrowUp,
                color: Colors.grey.shade400,
                size: small ? 12 : 14,
              ),
            ],
          ),
          SizedBox(height: small ? 8 : 12),
          Text(
            '$val',
            style: TextStyle(
              fontSize: small ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: small ? 11 : 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ringkasan Riwayat Pemeriksaan Anda', // ✅ UPDATED TITLE
          style: TextStyle(
            fontSize: small ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
        SizedBox(height: small ? 12 : 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: small ? 2 : 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: small ? 1.0 : 1.1,
          children: [
            card(
              'Total Pasien Anda', // ✅ UPDATED TEXT
              riwayatPasien.length,
              FontAwesomeIcons.users,
              const Color(0xFF059669),
            ),
            card(
              'Berhasil',
              succeeded,
              FontAwesomeIcons.circleCheck,
              const Color(0xFF10B981),
            ),
            card(
              'Pembayaran',
              payment,
              FontAwesomeIcons.creditCard,
              const Color(0xFF0891B2),
            ),
            card(
              'Dibatalkan',
              canceled,
              FontAwesomeIcons.circleXmark,
              const Color(0xFFDC2626),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterSection(bool small) {
    return Container(
      padding: EdgeInsets.all(small ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 8,
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0891B2).withOpacity(.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const FaIcon(
                  FontAwesomeIcons.filter,
                  color: Color(0xFF0891B2),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Filter & Pencarian',
                  style: TextStyle(
                    fontSize: small ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: small ? 12 : 16),
          // Search - UPDATED PLACEHOLDER TEXT
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Cari nama pasien, no EMR, nomor antrian, atau diagnosis...', // ✅ UPDATE PLACEHOLDER
                hintStyle: TextStyle(
                  fontSize: small ? 12 : 13,
                  color: Colors.grey.shade500,
                ),
                prefixIcon: Container(
                  padding: EdgeInsets.all(small ? 12 : 14),
                  child: FaIcon(
                    FontAwesomeIcons.magnifyingGlass,
                    size: small ? 16 : 18,
                    color: Colors.grey.shade500,
                  ),
                ),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: FaIcon(
                          FontAwesomeIcons.xmark,
                          size: small ? 14 : 16,
                          color: Colors.grey.shade500,
                        ),
                        onPressed: () {
                          searchController.clear();
                          _filterPasien();
                        },
                        constraints: BoxConstraints(
                          minWidth: small ? 36 : 40,
                          minHeight: small ? 36 : 40,
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: small ? 12 : 14,
                ),
                isDense: false,
              ),
              style: TextStyle(fontSize: small ? 12 : 13),
            ),
          ),
          SizedBox(height: small ? 12 : 16),
          _filterDropdown(
            'Filter Status',
            selectedStatusFilter,
            availableStatusFilters,
            (v) {
              setStateSafe(() => selectedStatusFilter = v!);
              _filterPasien();
            },
            FontAwesomeIcons.circleCheck,
            small,
          ),
          SizedBox(height: small ? 10 : 12),
          _filterDropdown(
            'Filter Tanggal',
            selectedDateFilter,
            availableDateFilters,
            (v) {
              setStateSafe(() => selectedDateFilter = v!);
              _filterPasien();
            },
            FontAwesomeIcons.calendarDays,
            small,
          ),
          if (selectedStatusFilter != 'Semua Status' ||
              selectedDateFilter != 'Semua Tanggal' ||
              searchController.text.isNotEmpty) ...[
            SizedBox(height: small ? 12 : 16),
            Container(
              padding: EdgeInsets.all(small ? 8 : 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0891B2).withOpacity(.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFF0891B2).withOpacity(.2),
                ),
              ),
              child: Row(
                children: [
                  const FaIcon(
                    FontAwesomeIcons.circleInfo,
                    color: Color(0xFF0891B2),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Filter aktif: ${_activeFiltersText()}',
                      style: TextStyle(
                        fontSize: small ? 10 : 11,
                        color: const Color(0xFF0891B2),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: _resetFilters,
                    child: Text(
                      'Reset',
                      style: TextStyle(
                        fontSize: small ? 10 : 11,
                        color: const Color(0xFFDC2626),
                        fontWeight: FontWeight.w500,
                      ),
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

  String _activeFiltersText() {
    final parts = <String>[];
    if (selectedStatusFilter != 'Semua Status')
      parts.add('Status: $selectedStatusFilter');
    if (selectedDateFilter != 'Semua Tanggal')
      parts.add('Tanggal: $selectedDateFilter');
    if (searchController.text.isNotEmpty)
      parts.add('Pencarian: "${searchController.text}"');
    return parts.join(', ');
  }

  Widget _filterDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
    IconData icon,
    bool small,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            FaIcon(icon, size: 14, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: small ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: small ? 8 : 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              items: items
                  .map(
                    (e) => DropdownMenuItem<String>(
                      value: e,
                      child: Text(
                        e,
                        style: TextStyle(
                          fontSize: small ? 11 : 12,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
              icon: FaIcon(
                FontAwesomeIcons.chevronDown,
                color: Colors.grey.shade500,
                size: 16,
              ),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
  // Ambil list pasien unik berdasarkan pasien.id
  List<Map<String, dynamic>> _uniquePatients(List<dynamic> source) {
    final Map<int, Map<String, dynamic>> byId = {};

    for (final raw in source) {
      if (raw is Map<String, dynamic>) {
        final pasienId = (raw['pasien']?['id'] as num?)?.toInt();
        if (pasienId != null && !byId.containsKey(pasienId)) {
          byId[pasienId] = raw; // <-- TIDAK ADA karakter aneh di sini
        }
      }
    }

    return byId.values.toList();
  }

    Widget _buildPatientListSection(bool small) {
    // pasien unik dari semua riwayat & hasil filter
    final uniqueAllPatients = _uniquePatients(riwayatPasien);
    final uniqueFilteredPatients = _uniquePatients(filteredRiwayatPasien);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withOpacity(.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const FaIcon(
                FontAwesomeIcons.userDoctor,
                color: Color(0xFF059669),
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pasien yang Anda Periksa',
                  style: TextStyle(
                    fontSize: small ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                Text(
                  '${uniqueFilteredPatients.length} pasien dari ${uniqueAllPatients.length} pasien',
                  style: TextStyle(
                    fontSize: small ? 10 : 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: small ? 12 : 16),
        if (uniqueFilteredPatients.isEmpty)
          _emptyState(small)
        else
          _patientList(small, uniqueFilteredPatients),
      ],
    );
  }



  Widget _emptyState(bool small) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(small ? 24 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(small ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: FaIcon(
              riwayatPasien.isEmpty
                  ? FontAwesomeIcons.userDoctor // ✅ UPDATED ICON
                  : FontAwesomeIcons.filterCircleXmark,
              size: small ? 32 : 40,
              color: Colors.grey.shade400,
            ),
          ),
          SizedBox(height: small ? 12 : 16),
          Text(
            riwayatPasien.isEmpty
                ? 'Belum ada riwayat pemeriksaan' // ✅ UPDATED TEXT
                : 'Tidak ada pemeriksaan yang sesuai filter', // ✅ UPDATED TEXT
            style: TextStyle(
              fontSize: small ? 14 : 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: small ? 6 : 8),
          Text(
            riwayatPasien.isEmpty
                ? 'Riwayat pasien yang Anda periksa akan muncul di sini.' // ✅ UPDATED TEXT
                : 'Coba ubah filter atau reset untuk melihat semua data.',
            style: TextStyle(
              fontSize: small ? 12 : 13,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          if (riwayatPasien.isNotEmpty) ...[
            SizedBox(height: small ? 12 : 16),
            ElevatedButton.icon(
              onPressed: _resetFilters,
              icon: const FaIcon(
                FontAwesomeIcons.arrowsRotate,
                size: 14,
              ),
              label: const Text('Reset Filter'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0891B2),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: small ? 16 : 20,
                  vertical: small ? 8 : 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                textStyle: TextStyle(fontSize: small ? 12 : 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _patientList(bool small, List<Map<String, dynamic>> patients) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: patients.length,
        separatorBuilder: (_, __) => SizedBox(height: small ? 8 : 12),
        itemBuilder: (context, i) =>
            _patientCard(patients[i], small),
      ),
    );
  }





Widget _patientCard(Map<String, dynamic> p, bool small) {
  final nama = p['pasien']?['nama_pasien'] ?? 'Nama tidak tersedia';
  final noAntrian = p['no_antrian'] ?? '-';
  final status = p['status'] ?? 'Unknown';
  final tanggal = _formatDate(p['tanggal_kunjungan']?.toString());
  final diagnosis = (p['emr']?['diagnosis'] ?? '-').toString();
  final noEmr = p['pasien']?['no_emr']?.toString() ?? '-';

  void _goRMLengkap() {
    final pasienId = (p['pasien']?['id'] as num?)?.toInt();
    final namaPasien = p['pasien']?['nama_pasien']?.toString() ?? 'Pasien';
    if (pasienId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RMPasien(pasienId: pasienId, namaPasien: namaPasien),
      ),
    );
  }

  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _goRMLengkap,
        child: Padding(
          padding: EdgeInsets.all(small ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // EMR + status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: small ? 8 : 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      noEmr != '-' ? 'EMR: $noEmr' : 'No EMR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: small ? 10 : 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _statusChip(status, small),
                ],
              ),
              SizedBox(height: small ? 10 : 12),

              // Nama pasien + no antrian
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nama,
                    style: TextStyle(
                      fontSize: small ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (noAntrian != '-') ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        FaIcon(
                          FontAwesomeIcons.hashtag,
                          size: 10,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Antrian: $noAntrian',
                          style: TextStyle(
                            fontSize: small ? 10 : 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),

              SizedBox(height: small ? 8 : 10),

              // Diagnosis (kalau ada)
              if (diagnosis != '-' && diagnosis.isNotEmpty) ...[
                Container(
                  padding: EdgeInsets.all(small ? 8 : 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          FaIcon(
                            FontAwesomeIcons.stethoscope,
                            size: 12,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Diagnosis Anda:',
                            style: TextStyle(
                              fontSize: small ? 10 : 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        diagnosis,
                        style: TextStyle(
                          fontSize: small ? 11 : 12,
                          color: const Color(0xFF374151),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: small ? 8 : 10),
              ],

              // Tanggal pemeriksaan
              _infoItem(
                FontAwesomeIcons.calendarDays,
                'Tanggal Pemeriksaan',
                tanggal,
                const Color(0xFF0891B2),
                small,
              ),
              SizedBox(height: small ? 10 : 12),

              // Tombol RM lengkap
              SizedBox(
                width: double.infinity,
                height: small ? 32 : 36,
                child: OutlinedButton.icon(
                  onPressed: _goRMLengkap,
                  icon: FaIcon(
                    FontAwesomeIcons.bookMedical,
                    size: small ? 14 : 16,
                  ),
                  label: Text(
                    'RM Lengkap',
                    style: TextStyle(
                      fontSize: small ? 12 : 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF7C3AED),
                    side: const BorderSide(color: Color(0xFF7C3AED)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _infoItem(
    IconData icon,
    String label,
    String value,
    Color color,
    bool small,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: color.withOpacity(.1),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FaIcon(icon, size: 12, color: color),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: small ? 9 : 10,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: small ? 10 : 11,
                  color: const Color(0xFF374151),
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
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
    final small = MediaQuery.of(context).size.width < 400;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(small ? 20 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(small ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: FaIcon(
                FontAwesomeIcons.triangleExclamation,
                size: small ? 32 : 40,
                color: Colors.red.shade400,
              ),
            ),
            SizedBox(height: small ? 12 : 16),
            Text(
              'Oops! Terjadi Kesalahan',
              style: TextStyle(
                fontSize: small ? 16 : 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: small ? 6 : 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: small ? 12 : 13,
                color: Colors.grey.shade600,
              ),
            ),
            SizedBox(height: small ? 16 : 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const FaIcon(
                FontAwesomeIcons.arrowsRotate,
                size: 16,
              ),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0891B2),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: small ? 20 : 24,
                  vertical: small ? 10 : 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                textStyle: TextStyle(fontSize: small ? 12 : 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}