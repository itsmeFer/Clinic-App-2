// lib/dokter/LayananDokter.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// halaman pemeriksaan layanan
import 'PemeriksaanLayanan.dart';

// pakai komponen shared yang sudah kamu buat
import 'package:RoyalClinic/dokter/Sidebar.dart'
    show
        SharedSidebar,
        SharedMobileDrawer,
        SharedTopHeader,
        SharedRightSidebar,
        SidebarPage,
        NavigationHelper;

class LayananDokterPage extends StatefulWidget {
  const LayananDokterPage({Key? key}) : super(key: key);

  @override
  State<LayananDokterPage> createState() => _LayananDokterPageState();
}

class _LayananDokterPageState extends State<LayananDokterPage> {
  // mapping status dari backend -> status untuk UI & filter chip
 // mapping status dari backend (Pending / Waiting / Engaged / Payment / Success)
// -> status UI yg dipakai filter: menunggu / proses / selesai / batal
String _mapStatusUI(dynamic raw) {
  final s = (raw ?? '').toString().toLowerCase();

  if (s == 'pending' || s == 'waiting') return 'menunggu';
  if (s == 'engaged' || s == 'payment') return 'proses';
  if (s == 'success' || s == 'completed' || s == 'done') return 'selesai';
  if (s == 'cancelled' || s == 'canceled' || s == 'batal') return 'batal';

  // default
  return 'menunggu';
}


  bool _isLoading = true;
  bool _isError = false;
  String? _errorMessage;
  List<dynamic> _orders = [];

  // filter status: 'semua', 'menunggu', 'proses', 'selesai', 'batal'
  String _filterStatus = 'semua';

  // SESUAIKAN dengan IP backend kamu
  final String _baseUrl = 'http://10.19.0.247:8000/api';

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
  setState(() {
    _isLoading = true;
    _isError = false;
    _errorMessage = null;
  });

  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final uri = Uri.parse('$_baseUrl/dokter/layanan-order');

    final response = await http.get(
      uri,
      headers: {
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      _isError = true;
      _errorMessage = 'Gagal memuat data (kode: ${response.statusCode}).';
    } else {
      final data = jsonDecode(response.body);

      // fleksibel: kalau response { data: [...] } atau langsung [...]
      final list = (data is List)
          ? data
          : (data['data'] ?? data['orders'] ?? []);

      // ✅ backend sudah filter "Engaged", jadi tinggal assign
      _orders = List<dynamic>.from(list);
    }
  } catch (e) {
    _isError = true;
    _errorMessage = 'Terjadi kesalahan: $e';
  }

  if (!mounted) return;
  setState(() {
    _isLoading = false;
  });
}


List<dynamic> get _filteredOrders {
  if (_filterStatus == 'semua') return _orders;

  return _orders.where((o) {
    final backendStatus = o['status'] ?? o['status_kunjungan'];
    final statusUI = _mapStatusUI(backendStatus);
    return statusUI == _filterStatus;
  }).toList();
}


  String _formatRupiah(dynamic value) {
    if (value == null) return 'Rp 0';
    final numVal = (value is String)
        ? double.tryParse(value) ?? 0
        : (value is int)
        ? value.toDouble()
        : (value as num).toDouble();

    final format = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return format.format(numVal);
  }

Color _statusColor(String statusUI) {
  if (statusUI == 'menunggu') {
    return const Color(0xFFF97316); // orange
  } else if (statusUI == 'proses') {
    return const Color(0xFF2563EB); // biru
  } else if (statusUI == 'selesai') {
    return const Color(0xFF16A34A); // hijau
  } else if (statusUI == 'batal') {
    return const Color(0xFFDC2626); // merah
  }
  return const Color(0xFF6B7280);
}



  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1200;
    final isTablet = screenWidth >= 768 && screenWidth < 1200;
    final isMobile = screenWidth < 768;

    return Scaffold(
      body: Row(
        children: [
          if (isDesktop || isTablet)
            SharedSidebar(
              currentPage: SidebarPage.layananDokter,
              dokterData: null, // kalau nanti mau kirim dokterData bisa dimodif
              isCollapsed: false,
              onToggleCollapse: () {},
              onNavigate: (page) =>
                  NavigationHelper.navigateToPage(context, page),
              onLogout: () => NavigationHelper.logout(context),
            ),

          // MAIN + RIGHT SIDEBAR
          Expanded(
            child: Row(
              children: [
                // MAIN CONTENT
                Expanded(
                  child: Column(
                    children: [
                      SharedTopHeader(
                        currentPage: SidebarPage.layananDokter,
                        dokterData: null,
                        isMobile: isMobile,
                        onRefresh: _fetchOrders,
                      ),
                      Expanded(
                        child: Container(
                          color: const Color(0xFFF8FAFC),
                          padding: EdgeInsets.all(isMobile ? 16 : 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFilterBar(isMobile),
                              const SizedBox(height: 16),
                              Expanded(child: _buildBodyContent()),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // RIGHT SIDEBAR (desktop only)
                if (isDesktop)
                  SizedBox(
                    width: 320,
                    child: Container(
                      color: const Color(0xFFF8FAFC),
                      padding: const EdgeInsets.fromLTRB(0, 16, 16, 0),
                      child: const SharedRightSidebar(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      drawer: isMobile
          ? SharedMobileDrawer(
              currentPage: SidebarPage.layananDokter,
              dokterData: null,
              onNavigate: (page) =>
                  NavigationHelper.navigateToPage(context, page),
              onLogout: () => NavigationHelper.logout(context),
            )
          : null,
    );
  }

  // ================== FILTER BAR ==================
  Widget _buildFilterBar(bool isMobile) {
    final filters = <String, String>{
      'semua': 'Semua',
      'menunggu': 'Menunggu',
      'proses': 'Proses',
      'selesai': 'Selesai',
      'batal': 'Batal',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.entries.map((entry) {
          final selected = _filterStatus == entry.key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                entry.value,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : const Color(0xFF475569),
                ),
              ),
              selected: selected,
              selectedColor: const Color(0xFF4F46E5),
              backgroundColor: const Color(0xFFE2E8F0),
              onSelected: (_) {
                setState(() {
                  _filterStatus = entry.key;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  // ================== BODY CONTENT ==================
  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const FaIcon(
              FontAwesomeIcons.triangleExclamation,
              color: Color(0xFFDC2626),
              size: 32,
            ),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Gagal memuat data',
              style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _fetchOrders,
              icon: const FaIcon(FontAwesomeIcons.rotateRight, size: 14),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }

    if (_filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFE0EAFF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: FaIcon(
                  FontAwesomeIcons.notesMedical,
                  color: Color(0xFF4F46E5),
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum ada order layanan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Order layanan pasien yang masuk ke dokter\nakan tampil di halaman ini.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _filteredOrders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = _filteredOrders[index] as Map<String, dynamic>;
        return _buildOrderCard(order);
      },
    );
  }

  // ================== ORDER CARD ==================
  Widget _buildOrderCard(Map<String, dynamic> order) {
    // fleksibel ngambil field sesuai struktur API
final kodeTrx =
    order['kode_trx'] ??
    order['kode_transaksi'] ??
    order['kode'] ??
    'TRX-${order['id'] ?? '-'}';


final backendStatus = order['status'] ?? order['status_kunjungan'];
final statusUI = _mapStatusUI(backendStatus);


    final createdAt = order['tanggal_transaksi'] ??
                  order['created_at_transaksi'] ??
                  order['created_at'] ??
                  '';


    // ====== MAPPING PASIEN / RM / POLI ======
    final kunjungan = order['kunjungan'] ?? {};
    final pasien = kunjungan['pasien'] ?? order['pasien'] ?? {};

    final namaPasien =
        order['nama_pasien'] ??
        pasien['nama_pasien'] ??
        pasien['nama_lengkap'] ??
        pasien['nama'] ??
        'Pasien';

    final noRM =
        order['no_rekam_medis'] ??
        pasien['no_rekam_medis'] ??
        pasien['no_emr'] ??
        '-';

    final poliNama =
        order['nama_poli'] ??
        (kunjungan['poli'] ?? {})['nama_poli'] ??
        order['poli_nama'] ??
        '-';
    // =======================================

    final totalTagihan = order['total_tagihan'];
    final diskonTipe = order['diskon_tipe']; // 'persen' / 'rupiah' / null
    final diskonNilai = order['diskon_nilai'];
    final totalSetelahDiskon = order['total_setelah_diskon'] ?? totalTagihan;

    // kalau nanti kamu kirim array detail dari API, masih kita baca di sini
    final detail =
        (order['detail_layanan'] ??
                order['layanan_items'] ??
                order['kunjungan_layanan'] ??
                [])
            as List<dynamic>;

    // ====== 👇 RINGKASAN NAMA LAYANAN YANG AKAN DITAMPILKAN ======
    String layananText =
        (order['ringkasan_layanan'] ?? // kalau API kirim field ini
                order['nama_layanan'] ?? // atau nama_layanan
                order['layanan'] ?? // atau layanan
                '')
            .toString();

    // kalau belum ada tapi detail_layanan tidak kosong → gabung nama_nya
    if (layananText.trim().isEmpty && detail.isNotEmpty) {
      final names = detail
          .map((d) {
            final layanan = d['layanan'] ?? {};
            return (layanan['nama_layanan'] ?? d['nama_layanan'] ?? '')
                .toString();
          })
          .where((x) => x.trim().isNotEmpty)
          .toList();

      if (names.isNotEmpty) {
        layananText = names.join(', ');
      }
    }
    // =============================================================

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // BARIS ATAS: kode + status + tanggal
          Row(
            children: [
              Expanded(
                child: Text(
                  kodeTrx.toString(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(statusUI).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _statusColor(statusUI),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusUI[0].toUpperCase() + statusUI.substring(1),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(statusUI),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const FaIcon(
                FontAwesomeIcons.clock,
                size: 11,
                color: Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 4),
              Text(
                createdAt.toString(),
                style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // PASIEN + POLI
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Center(
                  child: FaIcon(
                    FontAwesomeIcons.user,
                    size: 14,
                    color: Color(0xFF0EA5E9),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      namaPasien.toString(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          'RM: $noRM',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          '•',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Poli $poliNama',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // ====== BAGIAN LAYANAN (CUMA SATU TEKS) ======
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Layanan',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              layananText.trim().isNotEmpty
                  ? layananText
                  : '- Belum ada detail layanan',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
          ),

          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // TOTAL & DISKON
          Column(
            children: [
              _rowTotalLabel(
                label: 'Total Tagihan',
                value: _formatRupiah(totalTagihan),
              ),
              if (diskonTipe != null && diskonTipe.toString().isNotEmpty)
                _rowTotalLabel(
                  label:
                      'Diskon (${diskonTipe.toString() == 'persen' ? '${diskonNilai ?? 0}%' : 'rupiah'})',
                  value:
                      '- ${_formatRupiah(diskonTipe.toString() == 'persen' ? _hitungDiskonPersen(totalTagihan, diskonNilai) : diskonNilai)}',
                  valueColor: const Color(0xFFDC2626),
                ),
              const SizedBox(height: 4),
              _rowTotalLabel(
                label: 'Grand Total',
                value: _formatRupiah(totalSetelahDiskon),
                isBold: true,
                valueColor: const Color(0xFF16A34A),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ================= BUTTON KE PEMERIKSAAN LAYANAN =================
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              label: const Text(
                "Buka Pemeriksaan Layanan",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              onPressed: () {
                final kunjungan = order['kunjungan'] ?? {};

                // --- Ambil ringkasan layanan dari order ---
                final layananText =
                    (order['ringkasan_layanan'] ??
                            order['nama_layanan'] ??
                            order['layanan'] ??
                            '')
                        .toString();

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PemeriksaanLayanan(
                      kunjunganData: {
                        "id": kunjungan["id"],
                        "pasien": kunjungan["pasien"],

                        // identitas pasien
                        "nama_pasien": order["nama_pasien"],
                        "no_rekam_medis": order["no_rekam_medis"],
                        "nama_poli": order["nama_poli"],

                        // --- INI YANG PALING PENTING ---
                        "ringkasan_layanan": layananText,

                        // lainnya
                        "tanggal_kunjungan": order["created_at"],
                        "keluhan_awal": kunjungan["keluhan_awal"] ?? "",
                        "no_antrian": kunjungan["no_antrian"] ?? "",
                        "order": order,
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  dynamic _hitungDiskonPersen(dynamic total, dynamic persen) {
    final t = (total is String)
        ? double.tryParse(total) ?? 0
        : (total is int)
        ? total.toDouble()
        : (total ?? 0) as num;
    final p = (persen is String)
        ? double.tryParse(persen) ?? 0
        : (persen is int)
        ? persen.toDouble()
        : (persen ?? 0) as num;

    return (t * p) / 100;
  }

  Widget _rowTotalLabel({
    required String label,
    required String value,
    bool isBold = false,
    Color valueColor = const Color(0xFF111827),
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: const Color(0xFF6B7280),
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
