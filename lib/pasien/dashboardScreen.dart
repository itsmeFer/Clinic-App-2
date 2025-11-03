import 'dart:async';
import 'dart:convert';

import 'package:RoyalClinic/pasien/Artikel.dart';
import 'package:RoyalClinic/pasien/Katalog.dart';
import 'package:RoyalClinic/pasien/ListPembayaran.dart';
import 'package:RoyalClinic/pasien/PembelianObat.dart';
import 'package:RoyalClinic/pasien/PesanJadwal.dart';
import 'package:RoyalClinic/pasien/Testimoni.dart';
import 'package:RoyalClinic/pasien/edit_profile.dart';
import 'package:RoyalClinic/pasien/RiwayatKunjungan.dart';
import 'package:RoyalClinic/screen/login.dart';

import 'package:RoyalClinic/widgets/royal_scaffold.dart'; // ⬅️ pakai RoyalScaffold
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// ============== THEME HELPERS (teal premium) ==============
class TealX {
  // Base teals
  static const Color primary = Color(0xFF00897B); // teal 600-ish
  static const Color primaryDark = Color(0xFF00695C);
  static const Color primaryLight = Color(0xFF4DB6AC);

  // Neutrals
  static const Color bg = Color(0xFFF6FBFA);
  static const Color card = Colors.white;
  static const Color text = Color(0xFF0F1C1A);
  static const Color textMuted = Color(0xFF6A7A77);

  // Glass
  static Color glassBg = Colors.white.withOpacity(0.75);
  static Color glassBorder = Colors.white.withOpacity(0.45);

  // Shadows
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: const Color(0xFF00695C).withOpacity(0.08),
      blurRadius: 18,
      spreadRadius: 1,
      offset: const Offset(0, 8),
    ),
  ];

  static LinearGradient bgGradient = const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFE7F4F2), // very light teal mist
      Color(0xFFF8FFFE), // almost white
    ],
  );

  static LinearGradient capsuleGradient = const LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF00897B), Color(0xFF4DB6AC)],
  );

  static LinearGradient stat1 = const LinearGradient(
    colors: [Color(0xFF42E695), Color(0xFF3BB2B8)],
  );
  static LinearGradient stat2 = const LinearGradient(
    colors: [Color(0xFF16A085), Color(0xFF2ECC71)],
  );
}

/// Kartu "glass"
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.padding, this.margin});
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TealX.glassBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: TealX.glassBorder, width: 1),
        boxShadow: TealX.softShadow,
      ),
      child: child,
    );
  }
}

/// Capsule button teal
class CapsuleButton extends StatelessWidget {
  const CapsuleButton({super.key, required this.text, this.onTap});
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: TealX.capsuleGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: TealX.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ========================= MAIN WRAPPER =========================
class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;
  List<dynamic> jadwalDokter = [];
  final PageController _pageController = PageController();

  // 🔹 Judul per tab untuk AppBar global
  final _titles = const [
    'Beranda',
    'Jadwal Dokter',
    'Riwayat Kunjungan',
    'Profil Saya',
  ];

  @override
  void initState() {
    super.initState();
    fetchJadwalDokter();
  }

  Future<void> fetchJadwalDokter() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final token = prefs.getString('token');
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('http://192.168.1.6:8000/api/getAllDokter'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (!mounted) return;

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        if (!mounted) return;
        setState(() {
          jadwalDokter = data['data'];
        });
      }
    } catch (_) {}
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
    setState(() => _selectedIndex = index);
    _pageController.jumpToPage(index);
  }

  void _refreshData() {
    fetchJadwalDokter();
  }

  @override
  Widget build(BuildContext context) {
    return RoyalScaffold(
      title: _titles[_selectedIndex],          // ⬅️ judul dinamis per tab
      trailingActions: [                       // ⬅️ action kanan AppBar (logout)
        IconButton(
          icon: const Icon(Icons.logout, color: TealX.text),
          onPressed: logout,
          tooltip: 'Keluar',
        ),
      ],
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _selectedIndex = index),
        children: [
          // ⬇️ Halaman tanpa AppBar internal
          DashboardPage(
            jadwalDokter: jadwalDokter,
            onRefresh: _refreshData,
            onLogout: logout,
          ),
          PesanJadwal(allJadwal: jadwalDokter),
          const RiwayatKunjunganBody(),
          const EditProfilePage(),
        ],
      ),

      // ⬇️ BottomNav tetap seperti sebelumnya
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              border: Border.all(color: Colors.white.withOpacity(0.6)),
              boxShadow: TealX.softShadow,
            ),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              backgroundColor: Colors.transparent,
              selectedItemColor: TealX.primary,
              unselectedItemColor: Colors.teal.shade200,
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

// ========================= DASHBOARD PAGE =========================
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

  // data publik
  List<dynamic> heroSections = [];
  List<dynamic> eventPromos = [];

  // existing sections
  List<dynamic> catalogList = [];
  List<dynamic> articleList = [];
  List<dynamic> testimoniList = [];

  // UI controllers
  int _currentBanner = 0;
  final PageController _bannerController = PageController();
  final ScrollController _scrollController = ScrollController();
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    fetchProfile();
    fetchCatalog();
    fetchArticles();
    fetchTestimoni();
    fetchHeroSections();
    fetchEventPromos();

    _startBannerAutoPlay();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ====================== FETCHERS ======================
  Future<void> fetchProfile() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final token = prefs.getString('token');

    try {
      if (token == null) {
        setState(() => isLoading = false);
        return;
      }
      final res = await http.get(
        Uri.parse('http://192.168.1.6:8000/api/pasien/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (!mounted) return;
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        setState(() {
          profileData = data['data'];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchCatalog() async {
    try {
      final res = await http.get(
        Uri.parse('https://backend.royal-klinik.cloud/api/upload/catalogs'),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          setState(() => catalogList = data['data']['catalogs'] ?? []);
        }
      }
    } catch (_) {}
  }

  Future<void> fetchArticles() async {
    try {
      final res = await http.get(
        Uri.parse('https://backend.royal-klinik.cloud/api/upload/articles'),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          setState(() => articleList = data['data']['articles'] ?? []);
        }
      }
    } catch (_) {}
  }

  Future<void> fetchTestimoni() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final token = prefs.getString('token');
      final res = await http.get(
        Uri.parse('http://192.168.1.6:8000/api/getDataTestimoni'),
        headers: {if (token != null) 'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() => testimoniList = data['Data Testimoni'] ?? []);
      }
    } catch (_) {}
  }

  Future<void> fetchHeroSections() async {
    try {
      final res = await http.get(
        Uri.parse(
          'https://backend.royal-klinik.cloud/api/upload/hero-sections',
        ),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final sections = (data['data']?['sections'] as List?) ?? [];
          setState(
            () => heroSections =
                sections.where((e) => e['is_active'] == true).toList(),
          );
          _startBannerAutoPlay();
        }
      }
    } catch (_) {}
  }

  Future<void> fetchEventPromos() async {
    try {
      final res = await http.get(
        Uri.parse('https://backend.royal-klinik.cloud/api/upload/event-promos'),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          setState(
            () => eventPromos = (data['data']?['eventPromos'] as List?) ?? [],
          );
        }
      }
    } catch (_) {}
  }

  // ====================== HELPERS ======================
  void _startBannerAutoPlay() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_bannerController.hasClients) return;
      final count = heroSections.isNotEmpty ? heroSections.length : 0;
      if (count <= 1) return;
      final next = (_currentBanner + 1) % count;
      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
      );
    });
  }

  Map<int, Map<String, dynamic>> getUniqueDokter() {
    final Map<int, Map<String, dynamic>> unique = {};
    for (final item in widget.jadwalDokter) {
      if (item is! Map) continue;
      final dokterId = item['id_dokter'] ?? item['id'];
      if (dokterId == null) continue;
      final List jadwalList = (item['jadwal'] as List?) ?? [];
      unique[dokterId] = {
        'dokter': item,
        'total_jadwal': jadwalList.length,
        'sample_jadwal': jadwalList.isNotEmpty ? jadwalList.first : null,
      };
    }
    return unique;
  }

  // ====================== UI ======================
  @override
  Widget build(BuildContext context) {
    final pasien = profileData;

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: TealX.primary),
      );
    }
    if (pasien == null) {
      return const Center(child: Text('Tidak ada data profil'));
    }

    // ⬇️ Tidak pakai AppBar lokal; RoyalScaffold sudah handle AppBar global
    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      children: [
        // PROFILE (glass)
        GlassCard(
          padding: const EdgeInsets.all(18),
          child: _ProfileCard(pasien: pasien),
        ),
        const SizedBox(height: 14),

        // BANNER dari API
        _BannerFromApi(
          controller: _bannerController,
          items: heroSections,
          onChanged: (i) => setState(() => _currentBanner = i),
          currentIndex: _currentBanner,
        ),
        if (heroSections.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(heroSections.length, (i) {
                final active = _currentBanner == i;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? TealX.primary
                        : TealX.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),

        // Event/Promo
        if (eventPromos.isNotEmpty) ...[
          const SizedBox(height: 8),
          const _SectionTitle(title: 'Event & Promo'),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: eventPromos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) =>
                  _PromoCardHorizontal(item: eventPromos[i]),
            ),
          ),
        ],
        const SizedBox(height: 12),

        // MENU GRID
        const SizedBox(height: 6),
        Transform.translate(
          offset: const Offset(0, -4),
          child: GlassCard(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
            child: _MenuGrid(),
          ),
        ),

        const SizedBox(height: 14),

        // Quick stats
        _QuickStats(
          catalogCount: catalogList.length,
          jadwalCount: widget.jadwalDokter.length,
        ),
        const SizedBox(height: 18),

        // Tips
        GlassCard(child: _InfoTips()),
        const SizedBox(height: 18),

        // Dokter Tersedia
        GlassCard(
          child: _DokterTersediaSection(jadwalDokter: widget.jadwalDokter),
        ),
        const SizedBox(height: 18),

        // Katalog
        GlassCard(child: _KatalogSection(catalogList: catalogList)),
        const SizedBox(height: 18),

        // Artikel
        GlassCard(child: _ArtikelSection(articleList: articleList)),
        const SizedBox(height: 18),

        // Testimoni
        GlassCard(child: _TestimoniSection(testimoniList: testimoniList)),

        const SizedBox(height: 72),
      ],
    );
  }
}

// ========================= SUBWIDGETS =========================
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.pasien});
  final Map<String, dynamic> pasien;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _safeImageSquare(
              url: pasien['foto_pasien'] != null
                  ? 'http://192.168.1.6:8000/storage/${pasien['foto_pasien']}'
                  : null,
              size: 58,
              fallbackIcon: Icons.person,
            ),
            const SizedBox(width: 14),
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
                      fontWeight: FontWeight.w800,
                      color: TealX.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pasien['email']?.toString() ?? '-',
                    style: const TextStyle(fontSize: 13, color: TealX.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        
        // ✅ TAMBAHAN: Tampilkan NO EMR di bawah
        if (pasien['no_emr'] != null && pasien['no_emr'].toString().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: TealX.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: TealX.primary.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: TealX.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.badge_outlined,
                      size: 18,
                      color: TealX.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nomor Rekam Medis',
                          style: TextStyle(
                            fontSize: 11,
                            color: TealX.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pasien['no_emr'].toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: TealX.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ✅ BADGE MOBILE/WEB
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: pasien['no_emr'].toString().startsWith('RMB')
                          ? const Color(0xFF2196F3) // Blue for Mobile
                          : const Color(0xFF4CAF50), // Green for Web
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      pasien['no_emr'].toString().startsWith('RMB')
                          ? 'MOBILE'
                          : 'WEB',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ========================= IMPROVED BANNER FROM API =========================
class _BannerFromApi extends StatelessWidget {
  const _BannerFromApi({
    required this.controller,
    required this.items,
    required this.onChanged,
    required this.currentIndex,
  });

  final PageController controller;
  final List<dynamic> items;
  final void Function(int) onChanged;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final hasData = items.isNotEmpty;
    return Container(
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: TealX.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: hasData
            ? PageView.builder(
                controller: controller,
                onPageChanged: onChanged,
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final it = items[i] as Map<String, dynamic>;
                  final imageUrl = (it['imageUrl'] ?? '').toString();
                  final pos = (it['position'] ?? 'center')
                      .toString()
                      .toLowerCase();
                  final texts = _extractLocalizedTexts(context, it);

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Background image with better loading
                      _BackgroundImage(imageUrl: imageUrl),

                      // Enhanced gradient overlay for better text visibility
                      _GradientOverlay(),

                      // Improved text overlay
                      _EnhancedTextOverlay(
                        position: pos,
                        title: texts['title']!,
                        subtitle: texts['subtitle']!,
                      ),
                    ],
                  );
                },
              )
            : _bannerFallback(),
      ),
    );
  }

  Widget _bannerFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            TealX.primary.withOpacity(0.1),
            TealX.primaryLight.withOpacity(0.1),
          ],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image, color: TealX.primary, size: 48),
            SizedBox(height: 8),
            Text(
              'Banner akan muncul di sini',
              style: TextStyle(color: TealX.textMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, String> _extractLocalizedTexts(
    BuildContext context,
    Map<String, dynamic> item,
  ) {
    final String lang =
        Localizations.localeOf(context).languageCode; // 'id' atau 'en'
    final List i18n = (item['i18n'] as List?) ?? [];

    Map? chosen = i18n.cast<Map?>().firstWhere(
      (m) => (m?['locale'] ?? '').toString().toLowerCase() == lang,
      orElse: () => null,
    );

    chosen ??= i18n.cast<Map?>().firstWhere(
      (m) => (m?['locale'] ?? '').toString().toLowerCase() == 'en',
      orElse: () => null,
    );

    String title = (chosen?['title'] ?? '').toString().trim();
    String subtitle = (chosen?['subtitle'] ?? '').toString().trim();

    final pageKey = (item['page_key'] ?? '').toString().toLowerCase();
    if (title.isEmpty || subtitle.isEmpty) {
      final defaults = _defaultCopy(pageKey, lang);
      if (title.isEmpty) title = defaults['title']!;
      if (subtitle.isEmpty) subtitle = defaults['subtitle']!;
    }

    return {'title': title, 'subtitle': subtitle};
  }

  Map<String, String> _defaultCopy(String pageKey, String lang) {
    final bool isId = lang == 'id';

    switch (pageKey) {
      case 'home':
        return {
          'title':
              isId ? 'Kesehatan Anda, Prioritas Kami' : 'Your Health, Our Priority',
          'subtitle': isId
              ? 'Layanan klinik tepercaya dengan dokter profesional dan fasilitas modern.'
              : 'Trusted clinic services with professional doctors and modern facilities.',
        };
      case 'about':
        return {
          'title': isId ? 'Tentang Royal Clinic' : 'About Royal Clinic',
          'subtitle': isId
              ? 'Memberikan perawatan terbaik dengan sentuhan manusiawi sejak hari pertama.'
              : 'Delivering the best care with a human touch from day one.',
        };
      default:
        return {
          'title': 'Royal Clinic',
          'subtitle': isId
              ? 'Solusi kesehatan terpadu untuk Anda dan keluarga.'
              : 'Integrated healthcare for you and your family.',
        };
    }
  }
}

// ========================= BACKGROUND IMAGE COMPONENT =========================
class _BackgroundImage extends StatelessWidget {
  const _BackgroundImage({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return imageUrl.isEmpty
        ? Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  TealX.primary.withOpacity(0.1),
                  TealX.primaryLight.withOpacity(0.1),
                ],
              ),
            ),
          )
        : Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    TealX.primary.withOpacity(0.1),
                    TealX.primaryLight.withOpacity(0.1),
                  ],
                ),
              ),
              child: const Center(
                child: Icon(Icons.image_not_supported,
                    color: TealX.primary, size: 48),
              ),
            ),
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      TealX.primary.withOpacity(0.05),
                      TealX.primaryLight.withOpacity(0.05),
                    ],
                  ),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: TealX.primary,
                  ),
                ),
              );
            },
          );
  }
}

// ========================= ENHANCED GRADIENT OVERLAY =========================
class _GradientOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          stops: const [0.0, 0.4, 0.8, 1.0],
          colors: [
            Colors.black.withOpacity(0.75), // Strong at bottom
            Colors.black.withOpacity(0.45),
            Colors.black.withOpacity(0.15),
            Colors.transparent, // Transparent at top
          ],
        ),
      ),
    );
  }
}

// ========================= ENHANCED TEXT OVERLAY =========================
class _EnhancedTextOverlay extends StatelessWidget {
  const _EnhancedTextOverlay({
    required this.position,
    required this.title,
    required this.subtitle,
  });

  final String position;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Always position text at bottom regardless of position parameter
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          screenWidth * 0.05, // 5% dari lebar layar
          60,
          screenWidth * 0.05, // 5% dari lebar layar
          20,
        ),
        child: _ElegantTextCard(
          title: title,
          subtitle: subtitle,
          crossAlignment: CrossAxisAlignment.start,
          textAlign: TextAlign.left,
          screenWidth: screenWidth,
        ),
      ),
    );
  }
}

// ========================= ELEGANT TEXT CARD =========================
class _ElegantTextCard extends StatelessWidget {
  const _ElegantTextCard({
    required this.title,
    required this.subtitle,
    required this.crossAlignment,
    required this.textAlign,
    required this.screenWidth,
  });

  final String title;
  final String subtitle;
  final CrossAxisAlignment crossAlignment;
  final TextAlign textAlign;
  final double screenWidth;

  @override
  Widget build(BuildContext context) {
    // Font sizes yang lebih kecil
    final titleSize = screenWidth < 360
        ? 14.0
        : screenWidth < 400
            ? 15.0
            : screenWidth < 500
                ? 16.0
                : 17.0;

    final subtitleSize = screenWidth < 360
        ? 11.0
        : screenWidth < 400
            ? 11.5
            : screenWidth < 500
                ? 12.0
                : 12.5;

    // Max width responsif
    final maxWidth = screenWidth * 0.85; // Dikurangi dari 90% ke 85%

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAlignment,
        children: [
          // Title
          Text(
            title,
            textAlign: textAlign,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: titleSize,
              fontWeight: FontWeight.w800,
              height: 1.15,
              letterSpacing: 0.1,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.8),
                  blurRadius: 6,
                  offset: const Offset(0, 1.5),
                ),
                Shadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 3,
                  offset: const Offset(0, 0.5),
                ),
              ],
            ),
          ),

          SizedBox(height: screenWidth < 360 ? 4 : 5),

          // Subtitle
          Text(
            subtitle,
            textAlign: textAlign,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              fontSize: subtitleSize,
              fontWeight: FontWeight.w400,
              height: 1.25,
              letterSpacing: 0.05,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.7),
                  blurRadius: 4,
                  offset: const Offset(0, 0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Promo horizontal card (glass + teal accents)
class _PromoCardHorizontal extends StatelessWidget {
  const _PromoCardHorizontal({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = (item['imageUrl'] ?? '').toString();
    final title = (item['title'] ?? 'Promo').toString();
    final date = (item['date'] ?? '').toString();

    return Container(
      width: 252,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
        boxShadow: TealX.softShadow,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(16)),
            child: Image.network(
              imageUrl,
              width: 104,
              height: 124,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 104,
                height: 124,
                color: const Color(0x1100897B),
                child: const Icon(
                  Icons.image_not_supported,
                  color: TealX.primary,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _chip('Promo'),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: TealX.text,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.event, size: 14, color: TealX.primary),
                      const SizedBox(width: 6),
                      Text(
                        date,
                        style: const TextStyle(
                          color: TealX.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: TealX.capsuleGradient,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: TealX.text,
        letterSpacing: 0.2,
      ),
    );
  }
}

// Image square helper
Widget _safeImageSquare({
  required String? url,
  required double size,
  required IconData fallbackIcon,
}) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: SizedBox(
      width: size,
      height: size,
      child: url == null || url.isEmpty
          ? Container(
              color: const Color(0x1400897B),
              child: Icon(fallbackIcon, color: TealX.primary),
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0x1400897B),
                child: Icon(fallbackIcon, color: TealX.primary),
              ),
            ),
    ),
  );
}

class _MenuGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3, // Ubah dari 4 ke 3 untuk menampung 5 item dalam 2 baris
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.9,
      padding: EdgeInsets.zero,
      children: [
        _menuItem(
          context,
          'assets/icons/testimoni.png',
          'Testimoni',
          const Color(0xFF7B1FA2),
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TestimoniPage()),
          ),
        ),
        _menuItem(
          context,
          'assets/icons/artikel.png',
          'Artikel',
          const Color(0xFF1976D2),
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const Artikel()),
          ),
        ),
        _menuItem(
          context,
          'assets/icons/layanan.png',
          'Layanan',
          const Color(0xFFE64A19),
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const Katalog()),
          ),
        ),
        _menuItem(
          context,
          'assets/icons/bayar.png',
          'Bayar',
          const Color(0xFF388E3C),
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ListPembayaran()),
          ),
        ),
        // TAMBAHAN BARU: Tombol PembelianObat
        _menuItem(
          context,
          'assets/icons/obat.png', // Anda perlu menambahkan icon ini atau gunakan yang sudah ada
          'Beli Obat',
          const Color(0xFFFF5722), // Warna orange untuk membedakan
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PembelianObat()),
          ),
        ),
      ],
    );
  }
}

Widget _menuItem(
  BuildContext context,
  String img,
  String label,
  Color color,
  VoidCallback onTap,
) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.6)),
        boxShadow: TealX.softShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            flex: 3,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.18), color.withOpacity(0.12)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: Image.asset(
                      img,
                      width: 52,
                      height: 52,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                color: TealX.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _QuickStats extends StatelessWidget {
  const _QuickStats({required this.catalogCount, required this.jadwalCount});
  final int catalogCount;
  final int jadwalCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _modernStatCard(
            'Total Layanan',
            catalogCount,
            Icons.medical_services_rounded,
            TealX.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _modernStatCard(
            'Jadwal Tersedia',
            jadwalCount,
            Icons.calendar_today_rounded,
            TealX.primaryDark,
          ),
        ),
      ],
    );
  }

  Widget _modernStatCard(
      String label, int value, IconData icon, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.08),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: primaryColor.withOpacity(0.04),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon dengan background circle
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryColor, size: 24),
          ),
          const SizedBox(height: 14),

          // Value
          Text(
            '$value',
            style: TextStyle(
              color: primaryColor,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),

          // Label
          const Text(
            'Total Layanan',
            style: TextStyle(
              color: TealX.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTips extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: TealX.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.info_outline, color: TealX.primary, size: 28),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tips Kesehatan',
                style: TextStyle(
                  color: TealX.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Jangan lupa minum air putih 8 gelas sehari dan istirahat cukup!',
                style: TextStyle(
                  color: TealX.textMuted,
                  fontSize: 13.5,
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

class _DokterTersediaSection extends StatelessWidget {
  const _DokterTersediaSection({required this.jadwalDokter});
  final List<dynamic> jadwalDokter;

  Map<int, Map<String, dynamic>> _unique(List<dynamic> data) {
    final Map<int, Map<String, dynamic>> unique = {};
    for (final item in data) {
      if (item is! Map) continue;
      final dokterId = item['id_dokter'] ?? item['id'];
      if (dokterId == null) continue;
      final List jadwalList = (item['jadwal'] as List?) ?? [];
      unique[dokterId] = {
        'dokter': item,
        'total_jadwal': jadwalList.length,
        'sample_jadwal': jadwalList.isNotEmpty ? jadwalList.first : null,
      };
    }
    return unique;
  }

  @override
  Widget build(BuildContext context) {
    final uniqueDokter = _unique(jadwalDokter).values.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Dokter Tersedia',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: TealX.text,
              ),
            ),
            if (jadwalDokter.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PesanJadwal(allJadwal: jadwalDokter),
                  ),
                ),
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(
                    fontSize: 13,
                    color: TealX.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (jadwalDokter.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: TealX.softShadow,
            ),
            child: Column(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 48,
                  color: Colors.teal.shade100,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Belum ada dokter tersedia',
                  style: TextStyle(color: TealX.textMuted, fontSize: 14),
                ),
              ],
            ),
          )
        else
          Column(
            children: uniqueDokter.take(3).map((dokterData) {
              final dokter = dokterData['dokter'];
              final totalJadwal = dokterData['total_jadwal'];
              final foto = dokter['foto_dokter']?.toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: TealX.softShadow,
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: (foto == null || foto.isEmpty)
                          ? Container(
                              width: 70,
                              height: 70,
                              color: TealX.primary.withOpacity(0.08),
                              child: const Icon(
                                Icons.person,
                                color: TealX.primary,
                                size: 36,
                              ),
                            )
                          : Image.network(
                              'http://192.168.1.6:8000/storage/$foto',
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 70,
                                height: 70,
                                color: TealX.primary.withOpacity(0.08),
                                child: const Icon(
                                  Icons.person,
                                  color: TealX.primary,
                                  size: 36,
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
                            dokter['nama_dokter']?.toString() ??
                                'Nama tidak tersedia',
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: TealX.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            dokter['jenis_spesialis']?['nama_spesialis']
                                    ?.toString() ??
                                'Spesialis Umum',
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: TealX.textMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: TealX.primary.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$totalJadwal jadwal tersedia',
                              style: const TextStyle(
                                fontSize: 12,
                                color: TealX.primary,
                                fontWeight: FontWeight.w700,
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
          ),
      ],
    );
  }
}

class _KatalogSection extends StatelessWidget {
  const _KatalogSection({required this.catalogList});
  final List<dynamic> catalogList;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Katalog Layanan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: TealX.text,
              ),
            ),
            if (catalogList.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const Katalog()),
                ),
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(
                    fontSize: 13,
                    color: TealX.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (catalogList.isEmpty)
          _emptyCard(
            icon: Icons.medical_services_outlined,
            text: 'Belum ada katalog layanan',
          )
        else
          Column(
            children: catalogList.take(3).map((c) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: TealX.softShadow,
                ),
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const Katalog()),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          (c['imageUrl'] ?? '').toString(),
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 88,
                            height: 88,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.image_not_supported),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c['title']?.toString() ?? 'Tidak ada judul',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: TealX.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              c['category']?['name']?.toString() ??
                                  'Kategori tidak ada',
                              style: const TextStyle(
                                fontSize: 13,
                                color: TealX.textMuted,
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
      ],
    );
  }
}

class _ArtikelSection extends StatelessWidget {
  const _ArtikelSection({required this.articleList});
  final List<dynamic> articleList;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Artikel Kesehatan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: TealX.text,
              ),
            ),
            if (articleList.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const Artikel()),
                ),
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(
                    fontSize: 13,
                    color: TealX.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (articleList.isEmpty)
          _emptyCard(
            icon: Icons.article_outlined,
            text: 'Belum ada artikel tersedia',
          )
        else
          Column(
            children: articleList.take(3).map((a) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: TealX.softShadow,
                ),
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const Artikel()),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          (a['imageUrl'] ?? '').toString(),
                          width: 58,
                          height: 58,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 58,
                            height: 58,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.article),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a['title']?.toString() ?? 'Tidak ada judul',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: TealX.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              a['category']?['name']?.toString() ??
                                  'Kategori tidak ada',
                              style: const TextStyle(
                                fontSize: 13,
                                color: TealX.textMuted,
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
      ],
    );
  }
}

class _TestimoniSection extends StatelessWidget {
  const _TestimoniSection({required this.testimoniList});
  final List<dynamic> testimoniList;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Testimoni Pasien',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: TealX.text,
              ),
            ),
            if (testimoniList.isNotEmpty)
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TestimoniPage()),
                ),
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(
                    fontSize: 13,
                    color: TealX.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (testimoniList.isEmpty)
          _emptyCard(
            icon: Icons.rate_review_outlined,
            text: 'Belum ada testimoni',
          )
        else
          Column(
            children: testimoniList.take(3).map((t) {
              final nama = (t['nama_testimoni'] ?? 'Tamu').toString();
              final initial = nama.isNotEmpty ? nama[0].toUpperCase() : 'T';
              final isi = (t['isi_testimoni'] ?? '').toString();
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: TealX.softShadow,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: TealX.primary.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: TealX.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nama,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: TealX.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isi,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: TealX.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

Widget _emptyCard({required IconData icon, required String text}) {
  return Container(
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: TealX.softShadow,
    ),
    child: Column(
      children: [
        Icon(icon, size: 44, color: Colors.teal.shade100),
        const SizedBox(height: 10),
        Text(
          text,
          style: const TextStyle(color: TealX.textMuted, fontSize: 14),
        ),
      ],
    ),
  );
}

// ========================= WRAPPERS (tanpa Scaffold lokal) =========================

/// Body Jadwal: cukup return konten — AppBar global dihandle RoyalScaffold
class PesanJadwalBody extends StatelessWidget {
  final List<dynamic> jadwalDokter;
  const PesanJadwalBody({super.key, required this.jadwalDokter});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: TealX.bgGradient),
      child: const SafeArea(
        top: false,
        child: SizedBox.shrink(), // ganti dengan body asli jika perlu wrapper
      ),
    );
  }
}

/// Body Riwayat: cukup return konten — AppBar global dihandle RoyalScaffold
class RiwayatKunjunganBody extends StatelessWidget {
  const RiwayatKunjunganBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const RiwayatKunjungan();
  }
}
