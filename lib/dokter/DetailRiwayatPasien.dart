import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DetailRiwayatPasienPage extends StatefulWidget {
  final int kunjunganId;
  const DetailRiwayatPasienPage({Key? key, required this.kunjunganId}) : super(key: key);

  @override
  State<DetailRiwayatPasienPage> createState() => _DetailRiwayatPasienPageState();
}

class _DetailRiwayatPasienPageState extends State<DetailRiwayatPasienPage> {
  static const String baseUrl = 'https://admin.royal-klinik.cloud/api';

  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? detail; // payload dari API

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('dokter_token') ?? prefs.getString('token');
      if (token == null) {
        throw Exception('Token tidak ditemukan. Silakan login sebagai Dokter.');
      }

      final uri = Uri.parse('$baseUrl/dokter/detail-riwayat-pasien/${widget.kunjunganId}');
      final res = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      final contentType = res.headers['content-type'] ?? '';
      if (!contentType.toLowerCase().contains('application/json')) {
        throw Exception('Server mengembalikan non-JSON (${res.statusCode}). Cek token/role.');
      }

      final body = jsonDecode(res.body);
      if (res.statusCode == 200 && body is Map && (body['success'] == true)) {
        setState(() {
          detail = Map<String, dynamic>.from(body['data'] ?? {});
          isLoading = false;
        });
      } else {
        throw Exception((body['message'] ?? 'Gagal memuat detail').toString());
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  // ---------- THEME HELPERS ----------
  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return 'N/A';
    try {
      final d = DateTime.parse(iso);
      return DateFormat('dd/MM/yyyy').format(d);
    } catch (_) {
      return iso;
    }
  }

  String _s(dynamic m, String k) {
    try {
      if (m is Map && m[k] != null) return m[k].toString();
    } catch (_) {}
    return 'N/A';
  }

  Widget _chipStatus(String? status) {
    final s = (status ?? '').toLowerCase();
    Color bg, fg;
    if (['succeed','completed','selesai','done'].contains(s)) {
      bg = Colors.green.shade100; fg = Colors.green.shade700;
    } else if (['canceled','dibatalkan'].contains(s)) {
      bg = Colors.red.shade100; fg = Colors.red.shade700;
    } else if (['payment','paid','lunas'].contains(s)) {
      bg = Colors.blue.shade100; fg = Colors.blue.shade700;
    } else {
      bg = Colors.orange.shade100; fg = Colors.orange.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status ?? 'Unknown', style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
    );
  }

  // ---------- SECTION & ITEM HELPERS ----------
  Widget _section({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 12, offset: const Offset(0, 6))],
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // heading strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: color.withOpacity(.25))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(title,
                      style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 16, letterSpacing: .2)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ],
      ),
    );
  }

  Widget _bullet(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 38,
            child: Text(label,
                style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink, letterSpacing: .15)),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 62,
            child: Text(value, style: TextStyle(color: AppColors.sub, height: 1.35)),
          ),
        ],
      ),
    );
  }

  List<dynamic> _extractObat(dynamic detailData) {
    try {
      final resep = detailData['resep'];
      if (resep == null) return [];
      if (resep is List && resep.isNotEmpty) {
        final first = resep.first;
        if (first is Map && first['obat'] is List) return List<dynamic>.from(first['obat']);
      }
      if (resep is Map && resep['obat'] is List) return List<dynamic>.from(resep['obat']);
    } catch (_) {}
    return [];
  }

  // ---------- HEADER CARD ----------
  Widget _headerCard(Map<String, dynamic> d, bool isSmall) {
    final pasien = (d['pasien'] ?? {}) as Map<String, dynamic>;
    final foto = pasien['foto_pasien'];
    final nama = pasien['nama_pasien']?.toString() ?? 'Nama tidak tersedia';
    final gender = (pasien['jenis_kelamin'] ?? 'N/A').toString();
    final poli = _s(d['poli'] ?? {}, 'nama_poli');
    final tgl = _fmtDate(d['tanggal_kunjungan']?.toString());

    return Stack(
      children: [
        // gradient base
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.tealA, AppColors.tealB]),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(color: AppColors.tealA.withOpacity(.35), blurRadius: 14, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              // avatar
              Container(
                width: isSmall ? 58 : 66,
                height: isSmall ? 58 : 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(.85), width: 2),
                  image: (foto != null)
                      ? DecorationImage(
                          image: NetworkImage('https://admin.royal-klinik.cloud/storage/$foto'),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: (foto == null)
                    ? Icon(Icons.person_rounded, color: Colors.white, size: isSmall ? 30 : 34)
                    : null,
              ),
              const SizedBox(width: 14),
              // info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nama,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _pill(icon: Icons.confirmation_number_rounded, text: 'Antrian ${d['no_antrian'] ?? 'N/A'}'),
                        _pill(icon: Icons.calendar_today_rounded, text: tgl),
                        if (poli != 'N/A') _pill(icon: Icons.local_hospital_rounded, text: poli),
                        _pill(
                          icon: gender.toLowerCase() == 'laki-laki' ? Icons.male : Icons.female,
                          text: gender,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // glossy shimmer stroke
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white.withOpacity(.18), Colors.transparent],
                  stops: const [.0, .45],
                ),
              ),
            ),
          ),
        ),
        // status ribbon
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(.12),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(12),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: _chipStatus(_s(d, 'status')),
          ),
        ),
      ],
    );
  }

  Widget _pill({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.20)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ---------- SMALL KV ITEM ----------
  Widget _kv(IconData icon, String k, String v, {Color? tint}) {
    final c = tint ?? Colors.green.shade700;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 8),
        Text('$k: ', style: const TextStyle(fontWeight: FontWeight.w700)),
        Expanded(child: Text(v)),
      ]),
    );
  }

  // ---------- UI STATES ----------
  Widget _errorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
            child: Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 56),
          ),
          const SizedBox(height: 14),
          const Text('Terjadi Kesalahan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Text(errorMessage ?? '-', textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade500)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _fetchDetail,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Coba Lagi'),
          )
        ]),
      ),
    );
  }

  Widget _emptyWidget() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
          child: Icon(Icons.folder_open_rounded, color: Colors.grey.shade400, size: 56),
        ),
        const SizedBox(height: 14),
        const Text('Data tidak tersedia', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 6),
        Text('Detail kunjungan tidak ditemukan.', style: TextStyle(color: Colors.grey.shade500)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 380;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Detail Riwayat Medis', style: TextStyle(fontWeight: FontWeight.bold)),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.tealA, AppColors.tealB]),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchDetail, tooltip: 'Refresh'),
        ],
      ),
      body: isLoading
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.tealA), strokeWidth: 3),
              const SizedBox(height: 12),
              Text('Memuat detail...', style: TextStyle(color: Colors.grey.shade600)),
            ]))
          : (errorMessage != null)
              ? _errorWidget()
              : (detail == null)
                  ? _emptyWidget()
                  : RefreshIndicator(
                      color: AppColors.tealA,
                      onRefresh: _fetchDetail,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _headerCard(detail!, isSmall),
                            const SizedBox(height: 12),

                            // Informasi Pasien
                            _section(
                              icon: Icons.person_rounded,
                              title: 'Informasi Pasien',
                              color: AppColors.tealA,
                              children: [
                                _bullet('Nama', _s(detail?['pasien'], 'nama_pasien')),
                                _bullet('Alamat', _s(detail?['pasien'], 'alamat')),
                                _bullet('Tanggal Lahir', _fmtDate(_s(detail?['pasien'], 'tanggal_lahir'))),
                                _bullet('Jenis Kelamin', _s(detail?['pasien'], 'jenis_kelamin')),
                              ],
                            ),

                            // Informasi Kunjungan
                            _section(
                              icon: Icons.event_note_rounded,
                              title: 'Informasi Kunjungan',
                              color: Colors.blue.shade600,
                              children: [
                                _bullet('Tanggal Kunjungan', _fmtDate(_s(detail, 'tanggal_kunjungan'))),
                                _bullet('No. Antrian', _s(detail, 'no_antrian')),
                                _bullet('Keluhan Awal', _s(detail, 'keluhan_awal')),
                                Row(children: [
                                  const Text('Status: ', style: TextStyle(fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 8),
                                  _chipStatus(_s(detail, 'status')),
                                ]),
                              ],
                            ),

                            // EMR
                            if (detail?['emr'] != null) ...[
                              _section(
                                icon: Icons.medical_information_rounded,
                                title: 'Electronic Medical Record',
                                color: Colors.purple.shade600,
                                children: [
                                  _bullet('Keluhan Utama', _s(detail?['emr'], 'keluhan_utama')),
                                  _bullet('Riwayat Penyakit Dahulu', _s(detail?['emr'], 'riwayat_penyakit_dahulu')),
                                  _bullet('Riwayat Penyakit Keluarga', _s(detail?['emr'], 'riwayat_penyakit_keluarga')),
                                  _bullet('Diagnosis', _s(detail?['emr'], 'diagnosis')),
                                ],
                              ),
                              _section(
                                icon: Icons.monitor_heart_rounded,
                                title: 'Tanda Vital',
                                color: Colors.orange.shade600,
                                children: [
                                  _bullet('Tekanan Darah', _s(detail?['emr'], 'tekanan_darah')),
                                  _bullet('Suhu Tubuh (°C)', _s(detail?['emr'], 'suhu_tubuh')),
                                  _bullet('Nadi (bpm)', _s(detail?['emr'], 'nadi')),
                                  _bullet('Pernapasan / menit', _s(detail?['emr'], 'pernapasan')),
                                  _bullet('Saturasi Oksigen (%)', _s(detail?['emr'], 'saturasi_oksigen')),
                                ],
                              ),
                            ],

                            // Resep
                            Builder(builder: (_) {
                              final obatList = _extractObat(detail);
                              if (obatList.isEmpty) return const SizedBox.shrink();
                              return _section(
                                icon: Icons.medical_services_rounded,
                                title: 'Resep Obat',
                                color: Colors.green.shade700,
                                children: [
                                  ...obatList.map((o) {
                                    String nama = _s(o, 'nama_obat');
                                    String dosis = _s(o, 'dosis');
                                    String jumlah = 'N/A';
                                    String ket = 'N/A';

                                    if (o is Map && o['pivot'] is Map) {
                                      final p = o['pivot'] as Map;
                                      jumlah = _s(p, 'jumlah');
                                      ket = _s(p, 'keterangan');
                                      final pivotDosis = _s(p, 'dosis');
                                      if (pivotDosis != 'N/A' && pivotDosis.isNotEmpty) dosis = pivotDosis;
                                    }

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.green.shade100),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 8, offset: const Offset(0, 4))],
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Icon(Icons.medication_rounded, color: Colors.green.shade700),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                              Text(nama,
                                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.green.shade800)),
                                              const SizedBox(height: 6),
                                              _kv(Icons.inventory_2_rounded, 'Jumlah', '$jumlah tablet', tint: Colors.green.shade600),
                                              _kv(Icons.medication_liquid_rounded, 'Dosis', '$dosis mg', tint: Colors.green.shade600),
                                              _kv(Icons.notes_rounded, 'Keterangan', ket, tint: Colors.green.shade600),
                                            ]),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
      bottomNavigationBar: (detail != null)
          ? SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.line)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 8, offset: const Offset(0, -4))],
                ),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        // TODO: panggil logic share PDF EMR kamu di sini (share_plus)
                      },
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Bagikan PDF'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: AppColors.tealA),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: panggil logic cetak/preview PDF EMR (printing / open_filex)
                      },
                      icon: const Icon(Icons.print_rounded),
                      label: const Text('Cetak EMR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.tealA,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ]),
              ),
            )
          : null,
    );
  }
}

// ---------- PALETTE ----------
class AppColors {
  static final tealA = Colors.teal.shade600;
  static final tealB = Colors.teal.shade500;
  static final ink  = const Color(0xFF121418);
  static final sub  = Colors.black.withOpacity(.65);
  static final line = const Color(0x11000000);
}
