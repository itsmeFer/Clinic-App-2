import 'package:RoyalClinic/dokter/EditProfilDokter.dart';
import 'package:RoyalClinic/dokter/LayananDokter.dart';
import 'package:RoyalClinic/dokter/ListPerawat.dart';
import 'package:RoyalClinic/dokter/RiwayatPasien.dart';
import 'package:RoyalClinic/dokter/dashboard.dart';
import 'package:RoyalClinic/screen/login.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:ui';

const String kLogoPath = 'assets/gambar/logo.png';

// Enum untuk mendefinisikan halaman
enum SidebarPage {
  dashboard,
  riwayatPasien,
  layananDokter, // 🔥 BARU: menu order layanan ke dokter
  perawat,
  profilDokter,
  statistik,
  pengaturan,
}

// Model untuk sidebar menu item
class SidebarMenuItem {
  final IconData icon;
  final String title;
  final SidebarPage page;

  SidebarMenuItem({
    required this.icon,
    required this.title,
    required this.page,
  });
}

// ================== SIDEBAR KIRI (DESAIN BARU) ==================
class SharedSidebar extends StatelessWidget {
  final SidebarPage currentPage;
  final Map<String, dynamic>? dokterData;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;
  final Function(SidebarPage) onNavigate;
  final VoidCallback onLogout;

  const SharedSidebar({
    Key? key,
    required this.currentPage,
    this.dokterData,
    required this.isCollapsed,
    required this.onToggleCollapse,
    required this.onNavigate,
    required this.onLogout,
  }) : super(key: key);

  static final List<SidebarMenuItem> menuItems = [
    SidebarMenuItem(
      icon: FontAwesomeIcons.gaugeHigh,
      title: 'Dashboard',
      page: SidebarPage.dashboard,
    ),
    SidebarMenuItem(
      icon: FontAwesomeIcons.clockRotateLeft,
      title: 'Riwayat Pasien',
      page: SidebarPage.riwayatPasien,
    ),
    SidebarMenuItem(
      icon: FontAwesomeIcons.notesMedical,
      title: 'Layanan Dokter', // 🔥 BARU
      page: SidebarPage.layananDokter,
    ),
    SidebarMenuItem(
      icon: FontAwesomeIcons.userNurse,
      title: 'Perawat',
      page: SidebarPage.perawat,
    ),
    SidebarMenuItem(
      icon: FontAwesomeIcons.userDoctor,
      title: 'Profil Dokter',
      page: SidebarPage.profilDokter,
    ),
    SidebarMenuItem(
      icon: FontAwesomeIcons.chartLine,
      title: 'Statistik',
      page: SidebarPage.statistik,
    ),
    SidebarMenuItem(
      icon: FontAwesomeIcons.gear,
      title: 'Pengaturan',
      page: SidebarPage.pengaturan,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final sidebarWidth = isCollapsed ? 90.0 : 280.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: sidebarWidth,
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF191F3A),
                Color(0xFF202545),
              ],
            ),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: const Color(0xFF4F46E5).withOpacity(0.5),
              width: 1.5,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isActuallyCollapsed = constraints.maxWidth < 150;

              return Padding(
                padding: EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: isActuallyCollapsed ? 10 : 16,
                ),
                child: Column(
                  children: [
                    _buildSidebarHeader(isActuallyCollapsed),
                    const SizedBox(height: 24),
                    if (!isActuallyCollapsed && dokterData != null)
                      _buildSidebarUserProfile(),
                    if (!isActuallyCollapsed && dokterData != null)
                      const SizedBox(height: 10),
                    Expanded(
                      child: _buildSidebarMenu(isActuallyCollapsed),
                    ),
                    const SizedBox(height: 16),
                    _buildSidebarFooter(isActuallyCollapsed),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ================== HEADER ==================
  Widget _buildSidebarHeader(bool isActuallyCollapsed) {
    // MODE COLLAPSED
    if (isActuallyCollapsed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // logo bulat
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFFFFFFFF),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Image.asset(kLogoPath),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          // tombol toggle (panah kanan)
          InkWell(
            onTap: onToggleCollapse,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Center(
                child: FaIcon(
                  FontAwesomeIcons.angleRight,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // MODE EXPANDED (seperti Teams.co)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF252B4D),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFFFFFFF),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Image.asset(kLogoPath),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'RoyalClinic',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onToggleCollapse,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Center(
                child: FaIcon(
                  FontAwesomeIcons.angleLeft,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================== USER PROFILE ==================
  Widget _buildSidebarUserProfile() {
    if (dokterData == null) return const SizedBox.shrink();

    final nama = dokterData!['nama_dokter'] ?? 'Dokter';
    final foto = dokterData!['foto_dokter'];

    String spesialisInfo = '';
    if (dokterData!['jenis_spesialis'] != null &&
        dokterData!['jenis_spesialis'] is Map) {
      spesialisInfo =
          dokterData!['jenis_spesialis']['nama_spesialis']?.toString() ?? '';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF24294A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF1E293B),
            child: ClipOval(
              child: SafeNetworkImage(
                url: foto != null
                    ? 'http://10.19.0.247:8000/storage/$foto'
                    : null,
                size: 44,
                fallback: const FaIcon(
                  FontAwesomeIcons.userDoctor,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dr. $nama',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (spesialisInfo.isNotEmpty)
                  Text(
                    'Sp. $spesialisInfo',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================== MENU ==================
  Widget _buildSidebarMenu(bool isActuallyCollapsed) {
    return ListView.builder(
      primary: false,
      padding: EdgeInsets.zero,
      itemCount: menuItems.length,
      itemBuilder: (context, index) {
        final item = menuItems[index];
        final isSelected = currentPage == item.page;

        final Color baseTextColor =
            isSelected ? Colors.white : Colors.white.withOpacity(0.75);
        final Color baseIconColor =
            isSelected ? Colors.white : Colors.white.withOpacity(0.8);

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: () => onNavigate(item.page),
              child: Container(
                padding: EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: isActuallyCollapsed ? 0 : 14,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF3B3F73)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                  border: isSelected
                      ? Border.all(
                          color: const Color(0xFF6366F1),
                          width: 1.4,
                        )
                      : null,
                ),
                child: isActuallyCollapsed
                    ? Center(
                        child: FaIcon(
                          item.icon,
                          color: baseIconColor,
                          size: 18,
                        ),
                      )
                    : Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF4F46E5)
                                  : Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Center(
                              child: FaIcon(
                                item.icon,
                                color: isSelected
                                    ? Colors.white
                                    : baseIconColor,
                                size: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                color: baseTextColor,
                                fontSize: 13.5,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ================== FOOTER (LOGOUT) ==================
  Widget _buildSidebarFooter(bool isActuallyCollapsed) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isActuallyCollapsed) const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onLogout,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: isActuallyCollapsed
                    ? const Center(
                        child: FaIcon(
                          FontAwesomeIcons.rightFromBracket,
                          color: Color(0xFF4F46E5),
                          size: 18,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          FaIcon(
                            FontAwesomeIcons.rightFromBracket,
                            color: Color(0xFF4F46E5),
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Logout',
                            style: TextStyle(
                              color: Color(0xFF4F46E5),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ================== MOBILE GLASS INFO PANEL ==================
class _MobileGlassInfoPanel extends StatelessWidget {
  const _MobileGlassInfoPanel({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final tanggal = DateFormat('EEEE, d MMM yyyy', 'id_ID').format(now);
    final jam = DateFormat('HH:mm').format(now);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // baris tanggal & jam
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF06B6D4), Color(0xFF0EA5E9)],
                      ),
                    ),
                    child: const Center(
                      child: FaIcon(
                        FontAwesomeIcons.calendarDays,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tanggal,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Jam $jam',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(color: Colors.white.withOpacity(0.12), height: 1),
              const SizedBox(height: 10),
              const Text(
                'Catatan Hari Ini',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _glassLogItem(
                icon: FontAwesomeIcons.userNurse,
                title: 'Perawat standby',
                subtitle: 'Perawat yang terikat dengan dokter aktif di poli.',
              ),
              const SizedBox(height: 8),
              _glassLogItem(
                icon: FontAwesomeIcons.stethoscope,
                title: 'Pemeriksaan pasien',
                subtitle: 'Data kunjungan baru akan tampil di dashboard.',
              ),
              const SizedBox(height: 8),
              _glassLogItem(
                icon: FontAwesomeIcons.clockRotateLeft,
                title: 'Riwayat EMR',
                subtitle: 'Lihat detail tindakan di menu Riwayat Pasien.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glassLogItem({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: FaIcon(
              icon,
              size: 13,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 10,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ================== MOBILE DRAWER ==================
class SharedMobileDrawer extends StatelessWidget {
  final SidebarPage currentPage;
  final Map<String, dynamic>? dokterData;
  final Function(SidebarPage) onNavigate;
  final VoidCallback onLogout;

  const SharedMobileDrawer({
    Key? key,
    required this.currentPage,
    this.dokterData,
    required this.onNavigate,
    required this.onLogout,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF020617),
              Color(0xFF020617),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ===== HEADER =====
              Container(
                height: 140,
                decoration: const BoxDecoration(color: Color(0xFF020617)),
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF06B6D4), Color(0xFF0EA5E9)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Center(
                            child: FaIcon(
                              FontAwesomeIcons.houseMedical,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Royal Clinic',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Dashboard Dokter',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (dokterData != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: const Color(0xFF1E293B),
                            child: ClipOval(
                              child: SafeNetworkImage(
                                url: dokterData!['foto_dokter'] != null
                                    ? 'http://10.19.0.247:8000/storage/${dokterData!['foto_dokter']}'
                                    : null,
                                size: 28,
                                fallback: const FaIcon(
                                  FontAwesomeIcons.userDoctor,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Dr. ${dokterData!['nama_dokter'] ?? 'Dokter'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // ===== MENU + INFO PANEL (SCROLLABLE) =====
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    // menu items
                    ...SharedSidebar.menuItems.map((item) {
                      final isSelected = currentPage == item.page;
                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              Navigator.of(context).pop();
                              onNavigate(item.page);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF020617)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: isSelected
                                    ? Border.all(
                                        color: const Color(0xFF06B6D4),
                                        width: 1,
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  FaIcon(
                                    item.icon,
                                    color: isSelected
                                        ? const Color(0xFF06B6D4)
                                        : Colors.white.withOpacity(0.8),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: TextStyle(
                                        color: isSelected
                                            ? const Color(0xFF06B6D4)
                                            : Colors.white.withOpacity(0.9),
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 20),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: _MobileGlassInfoPanel(),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // ===== LOGOUT BUTTON =====
              Container(
                padding: const EdgeInsets.all(16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      Navigator.of(context).pop();
                      onLogout();
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFDC2626).withOpacity(0.4),
                        ),
                      ),
                      child: const Row(
                        children: [
                          FaIcon(
                            FontAwesomeIcons.rightFromBracket,
                            color: Color(0xFFDC2626),
                            size: 18,
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Keluar',
                            style: TextStyle(
                              color: Color(0xFFDC2626),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================== TOP HEADER ==================
class SharedTopHeader extends StatelessWidget {
  final SidebarPage currentPage;
  final Map<String, dynamic>? dokterData;
  final bool isMobile;
  final VoidCallback? onRefresh;

  const SharedTopHeader({
    Key? key,
    required this.currentPage,
    this.dokterData,
    required this.isMobile,
    this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: isMobile ? 60 : 70,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (isMobile)
            Builder(
              builder: (context) => IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const FaIcon(FontAwesomeIcons.bars),
                color: const Color(0xFF64748B),
                iconSize: 22,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _getPageTitle(),
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!isMobile)
                  Text(
                    _getPageSubtitle(),
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onRefresh != null)
                IconButton(
                  onPressed: onRefresh,
                  icon: const FaIcon(FontAwesomeIcons.arrowsRotate),
                  color: const Color(0xFF64748B),
                  tooltip: 'Refresh Data',
                  iconSize: isMobile ? 20 : 22,
                ),
              if (!isMobile && dokterData != null)
                PopupMenuButton<String>(
                  offset: const Offset(0, 40),
                  onSelected: (value) {
                    if (value == 'profile' && dokterData != null) {
                      final safeData =
                          Map<String, dynamic>.from(dokterData!);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              EditProfilDokter(dokterData: safeData),
                        ),
                      ).then((updated) {
                        if (updated != null && context.mounted) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const DokterDashboard(),
                            ),
                          );
                        }
                      });
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'profile',
                      child: Row(
                        children: [
                          FaIcon(
                            FontAwesomeIcons.userDoctor,
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Text('Edit Profil'),
                        ],
                      ),
                    ),
                  ],
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: isMobile ? 12 : 16,
                        backgroundColor: const Color(0xFFE2E8F0),
                        child: ClipOval(
                          child: SafeNetworkImage(
                            url: dokterData!['foto_dokter'] != null
                                ? 'http://10.19.0.247:8000/storage/${dokterData!['foto_dokter']}'
                                : null,
                            size: isMobile ? 24 : 32,
                            fallback: FaIcon(
                              FontAwesomeIcons.userDoctor,
                              color: const Color(0xFF64748B),
                              size: isMobile ? 12 : 16,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: isMobile ? 4 : 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 100),
                        child: Text(
                          dokterData!['nama_dokter'] ?? 'Dokter',
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const FaIcon(
                        FontAwesomeIcons.chevronDown,
                        size: 12,
                        color: Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _getPageTitle() {
    switch (currentPage) {
      case SidebarPage.dashboard:
        return 'Dashboard';
      case SidebarPage.riwayatPasien:
        return 'Riwayat Pasien';
      case SidebarPage.layananDokter:
        return 'Layanan Dokter'; // 🔥 BARU
      case SidebarPage.perawat:
        return 'Perawat';
      case SidebarPage.profilDokter:
        return 'Profil Dokter';
      case SidebarPage.statistik:
        return 'Statistik';
      case SidebarPage.pengaturan:
        return 'Pengaturan';
    }
  }

  String _getPageSubtitle() {
    switch (currentPage) {
      case SidebarPage.dashboard:
        return 'Ringkasan aktivitas dan pasien hari ini';
      case SidebarPage.riwayatPasien:
        return 'Riwayat pemeriksaan pasien sebelumnya';
      case SidebarPage.layananDokter:
        return 'Daftar order layanan yang masuk ke dokter'; // 🔥 BARU
      case SidebarPage.perawat:
        return 'Manajemen data perawat dan jadwal tugas';
      case SidebarPage.profilDokter:
        return 'Informasi dan pengaturan profil dokter';
      case SidebarPage.statistik:
        return 'Analisis dan laporan statistik';
      case SidebarPage.pengaturan:
        return 'Pengaturan sistem dan preferensi';
    }
  }
}


// ================== SAFE NETWORK IMAGE ==================
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
        child: Center(
          child: fallback ?? const FaIcon(FontAwesomeIcons.image),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Image.network(
        url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return SizedBox(
            width: size,
            height: size,
            child: Center(
              child: fallback ??
                  const FaIcon(FontAwesomeIcons.triangleExclamation),
            ),
          );
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            width: size,
            height: size,
            child: Center(
              child: SizedBox(
                width: size * 0.4,
                height: size * 0.4,
                child: const CircularProgressIndicator(strokeWidth: 1.5),
              ),
            ),
          );
        },
      ),
    );
  }
}


// ================== NAVIGATION HELPER ==================
class NavigationHelper {
  static void navigateToPage(
    BuildContext context,
    SidebarPage page, {
    Map<String, dynamic>? dokterData,
  }) {
    switch (page) {
      case SidebarPage.dashboard:
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const DokterDashboard()),
          (route) => false,
        );
        break;

      case SidebarPage.riwayatPasien:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => RiwayatPasienPage()),
        );
        break;

      case SidebarPage.layananDokter: // 👉 SEKARANG ARAHNYA KE FILE INI (LayananDokter.dart)
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const LayananDokterPage(),
          ),
        );
        break;

      case SidebarPage.perawat:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PerawatPage(
              dokterData: dokterData,
            ),
          ),
        );
        break;

      case SidebarPage.profilDokter:
        {
          final safeData = Map<String, dynamic>.from(
            dokterData ?? <String, dynamic>{},
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EditProfilDokter(dokterData: safeData),
            ),
          ).then((updated) {
            if (updated != null && context.mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const DokterDashboard()),
              );
            }
          });
          break;
        }

      case SidebarPage.statistik:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const StatistikPage()),
        );
        break;

      case SidebarPage.pengaturan:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PengaturanPage()),
        );
        break;
    }
  }

  static Future<void> logout(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token != null) {
        await http.post(
          Uri.parse('http://10.19.0.247:8000/api/logout'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        );
      }
    } catch (e) {
      // silent
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  static Future<bool> showLogoutConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Konfirmasi'),
            content: const Text('Apakah Anda yakin ingin keluar?'),
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
}



// ================== HALAMAN STATISTIK (SIMPLE) ==================
class StatistikPage extends StatelessWidget {
  const StatistikPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;
    final isMobile = screenWidth < 768;

    return Scaffold(
      body: Row(
        children: [
          if (isDesktop || isTablet)
            SharedSidebar(
              currentPage: SidebarPage.statistik,
              dokterData: null,
              isCollapsed: false,
              onToggleCollapse: () {},
              onNavigate: (page) =>
                  NavigationHelper.navigateToPage(context, page),
              onLogout: () => NavigationHelper.logout(context),
            ),
          Expanded(
            child: Column(
              children: [
                SharedTopHeader(
                  currentPage: SidebarPage.statistik,
                  dokterData: null,
                  isMobile: isMobile,
                ),
                Expanded(
                  child: Container(
                    color: const Color(0xFFF8FAFC),
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const FaIcon(
                                  FontAwesomeIcons.chartLine,
                                  size: 64,
                                  color: Color(0xFF7C3AED),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Statistik',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Halaman statistik sedang dalam pengembangan',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
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
        ],
      ),
      drawer: isMobile
          ? SharedMobileDrawer(
              currentPage: SidebarPage.statistik,
              dokterData: null,
              onNavigate: (page) =>
                  NavigationHelper.navigateToPage(context, page),
              onLogout: () => NavigationHelper.logout(context),
            )
          : null,
    );
  }
}

// ================== HALAMAN PENGATURAN (SIMPLE) ==================
class PengaturanPage extends StatelessWidget {
  const PengaturanPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;
    final isMobile = screenWidth < 768;

    return Scaffold(
      body: Row(
        children: [
          if (isDesktop || isTablet)
            SharedSidebar(
              currentPage: SidebarPage.pengaturan,
              dokterData: null,
              isCollapsed: false,
              onToggleCollapse: () {},
              onNavigate: (page) =>
                  NavigationHelper.navigateToPage(context, page),
              onLogout: () => NavigationHelper.logout(context),
            ),
          Expanded(
            child: Column(
              children: [
                SharedTopHeader(
                  currentPage: SidebarPage.pengaturan,
                  dokterData: null,
                  isMobile: isMobile,
                ),
                Expanded(
                  child: Container(
                    color: const Color(0xFFF8FAFC),
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const FaIcon(
                                  FontAwesomeIcons.gear,
                                  size: 64,
                                  color: Color(0xFF64748B),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Pengaturan',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Halaman pengaturan sedang dalam pengembangan',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
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
        ],
      ),
      drawer: isMobile
          ? SharedMobileDrawer(
              currentPage: SidebarPage.pengaturan,
              dokterData: null,
              onNavigate: (page) =>
                  NavigationHelper.navigateToPage(context, page),
              onLogout: () => NavigationHelper.logout(context),
            )
          : null,
    );
  }
}


// ================== RIGHT SIDEBAR (KOMPONEN BARU) ==================
class SharedRightSidebar extends StatefulWidget {
  const SharedRightSidebar({Key? key}) : super(key: key);

  @override
  State<SharedRightSidebar> createState() => _SharedRightSidebarState();
}

class _SharedRightSidebarState extends State<SharedRightSidebar> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildRealtimeClock(),
          const SizedBox(height: 20),
          _buildMiniCalendar(),
          const SizedBox(height: 20),
          Expanded(
            child: _buildLogsCard(),
          ),
        ],
      ),
    );
  }

  // ========== KARTU JAM REALTIME ==========
  Widget _buildRealtimeClock() {
    final tanggal =
        DateFormat('EEEE, d MMM yyyy', 'id_ID').format(_now);
    final jam = DateFormat('HH:mm:ss').format(_now);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF06B6D4), Color(0xFF0EA5E9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FaIcon(
            FontAwesomeIcons.calendarDays,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(height: 12),
          Text(
            tanggal,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            jam,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ========== MINI KALENDER ==========
  Widget _buildMiniCalendar() {
    final DateTime today = _now;
    final int year = today.year;
    final int month = today.month;

    final firstDay = DateTime(year, month, 1);
    final int startWeekday = firstDay.weekday; // 1 = Senin ... 7 = Minggu
    final int daysInMonth = DateTime(year, month + 1, 0).day;

    final List<Widget> gridItems = [];

    // Slot kosong sebelum tanggal 1
    for (int i = 1; i < startWeekday; i++) {
      gridItems.add(const SizedBox.shrink());
    }

    // Tanggal 1..N
    for (int day = 1; day <= daysInMonth; day++) {
      final bool isToday = (day == today.day);

      gridItems.add(
        Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isToday ? const Color(0xFF4F46E5) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                color: isToday ? Colors.white : const Color(0xFF1E293B),
                fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header bulan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('MMMM yyyy', 'id_ID').format(today),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const FaIcon(
                FontAwesomeIcons.chevronDown,
                size: 14,
                color: Color(0xFF64748B),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Header hari
          Row(
            children: const [
              _MiniCalHeader('Sen'),
              _MiniCalHeader('Sel'),
              _MiniCalHeader('Rab'),
              _MiniCalHeader('Kam'),
              _MiniCalHeader('Jum'),
              _MiniCalHeader('Sab'),
              _MiniCalHeader('Min'),
            ],
          ),
          const SizedBox(height: 8),
          // Grid tanggal
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.2,
            children: gridItems,
          ),
        ],
      ),
    );
  }

  // ========== LOG AKTIVITAS (STATIS) ==========
  Widget _buildLogsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Log Aktivitas',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _logItem(
                  icon: FontAwesomeIcons.userDoctor,
                  title: 'Dokter menyelesaikan pemeriksaan',
                  subtitle: 'EMR pasien telah diperbarui',
                  time: '09:15',
                ),
                const SizedBox(height: 8),
                _logItem(
                  icon: FontAwesomeIcons.userNurse,
                  title: 'Perawat menambahkan catatan vital',
                  subtitle: 'Tekanan darah & suhu dicatat',
                  time: '08:42',
                ),
                const SizedBox(height: 8),
                _logItem(
                  icon: FontAwesomeIcons.clipboardList,
                  title: 'Jadwal kunjungan diperbarui',
                  subtitle: '1 pasien dijadwalkan ulang',
                  time: '08:10',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _logItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String time,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Center(
            child: FaIcon(
              icon,
              size: 14,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          time,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF9CA3AF),
          ),
        ),
      ],
    );
  }
}

// Header singkat untuk nama hari
class _MiniCalHeader extends StatelessWidget {
  final String label;
  const _MiniCalHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}
