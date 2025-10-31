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
  static const String baseUrl = 'http://10.61.209.71:8000/api';

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

      // cegah jsonDecode HTML error
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

  // ---------- UI HELPERS ----------
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

  Widget _section({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.25)),
        boxShadow: [BoxShadow(color: color.withOpacity(.08), blurRadius: 8, offset: const Offset(0,2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16))),
          ]),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _bullet(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(margin: const EdgeInsets.only(top: 8), width: 4, height: 4, decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: RichText(text: TextSpan(
          style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.4),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: value),
          ],
        ))),
      ]),
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
            gradient: LinearGradient(colors: [Colors.teal.shade600, Colors.teal.shade500]),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchDetail, tooltip: 'Refresh'),
        ],
      ),
      body: isLoading
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Colors.teal.shade600), strokeWidth: 3),
              const SizedBox(height: 12),
              Text('Memuat detail...', style: TextStyle(color: Colors.grey.shade600)),
            ]))
          : (errorMessage != null)
              ? _errorWidget()
              : (detail == null)
                  ? _emptyWidget()
                  : RefreshIndicator(
                      color: Colors.teal.shade600,
                      onRefresh: _fetchDetail,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Kartu header ringkas
                            _headerCard(detail!, isSmall),
                            const SizedBox(height: 12),

                            // Section: Informasi Pasien
                            _section(
                              icon: Icons.person_rounded,
                              title: 'Informasi Pasien',
                              color: Colors.teal.shade600,
                              children: [
                                _bullet('Nama', _s(detail?['pasien'], 'nama_pasien')),
                                _bullet('Alamat', _s(detail?['pasien'], 'alamat')),
                                _bullet('Tanggal Lahir', _fmtDate(_s(detail?['pasien'], 'tanggal_lahir'))),
                                _bullet('Jenis Kelamin', _s(detail?['pasien'], 'jenis_kelamin')),
                              ],
                            ),

                            // Section: Informasi Kunjungan
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

                            // Section: EMR (jika ada)
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

                            // Section: Resep Obat (jika ada)
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
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.green.shade200),
                                        boxShadow: [
                                          BoxShadow(color: Colors.green.withOpacity(.05), blurRadius: 4, offset: const Offset(0,1)),
                                        ],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)),
                                            child: Text(nama, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                                          ),
                                          const SizedBox(height: 8),
                                          _kv(Icons.inventory_rounded, 'Jumlah', '$jumlah tablet'),
                                          _kv(Icons.medication_rounded, 'Dosis', '$dosis mg'),
                                          _kv(Icons.notes_rounded, 'Keterangan', ket),
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
    );
  }

  Widget _headerCard(Map<String, dynamic> d, bool isSmall) {
    final pasien = (d['pasien'] ?? {}) as Map<String, dynamic>;
    final foto = pasien['foto_pasien'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.teal.shade600, Colors.teal.shade500]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.teal.shade200.withOpacity(.4), blurRadius: 12, offset: const Offset(0,6))],
      ),
      child: Row(
        children: [
          Container(
            width: isSmall ? 56 : 64,
            height: isSmall ? 56 : 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(.7), width: 2),
              image: (foto != null)
                  ? DecorationImage(
                      image: NetworkImage('http://10.61.209.71:8000/storage/$foto'),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: (foto == null)
                ? Icon(Icons.person_rounded, color: Colors.white, size: isSmall ? 28 : 32)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pasien['nama_pasien']?.toString() ?? 'Nama tidak tersedia',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.confirmation_number_rounded, size: 14, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text('Antrian: ${d['no_antrian'] ?? 'N/A'}', style: const TextStyle(color: Colors.white70)),
                ]),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white70),
                  const SizedBox(width: 6),
                  Text('Tgl: ${_fmtDate(d['tanggal_kunjungan']?.toString())}', style: const TextStyle(color: Colors.white70)),
                ]),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _chipStatus(d['status']?.toString()),
        ],
      ),
    );
  }

  Widget _kv(IconData icon, String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.green.shade600),
          const SizedBox(width: 6),
          Text('$k: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }

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
}
