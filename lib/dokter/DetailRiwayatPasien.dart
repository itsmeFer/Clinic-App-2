import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// PDF / PRINT / SAVE
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_saver/file_saver.dart';

// gunakan komponen shared (sidebar/header) biar konsisten tampilan web
import 'package:RoyalClinic/dokter/Sidebar.dart'
    show
        SharedSidebar,
        SharedMobileDrawer,
        SharedTopHeader,
        SidebarPage,
        NavigationHelper;

// FONT AWESOME
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class DetailRiwayatPasienPage extends StatefulWidget {
  final int kunjunganId;
  const DetailRiwayatPasienPage({Key? key, required this.kunjunganId})
    : super(key: key);

  @override
  State<DetailRiwayatPasienPage> createState() =>
      _DetailRiwayatPasienPageState();
}

class _DetailRiwayatPasienPageState extends State<DetailRiwayatPasienPage> {
  static const String baseUrl = 'http://10.19.0.247:8000/api';

  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? detail;

  // ✅ EDIT MODE VARIABLES
  bool isEditMode = false;
  bool isSaving = false;
  final _formKey = GlobalKey<FormState>();
  
  // Controllers untuk edit inline
  final TextEditingController _keluhanUtamaController = TextEditingController();
  final TextEditingController _diagnosisController = TextEditingController();
  final TextEditingController _riwayatPenyakitDahuluController = TextEditingController();
  final TextEditingController _riwayatPenyakitKeluargaController = TextEditingController();
  final TextEditingController _tekananDarahController = TextEditingController();
  final TextEditingController _suhuTubuhController = TextEditingController();
  final TextEditingController _nadiController = TextEditingController();
  final TextEditingController _pernapasanController = TextEditingController();
  final TextEditingController _saturasiOksigenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchDetail();
  }

  @override
  void dispose() {
    _keluhanUtamaController.dispose();
    _diagnosisController.dispose();
    _riwayatPenyakitDahuluController.dispose();
    _riwayatPenyakitKeluargaController.dispose();
    _tekananDarahController.dispose();
    _suhuTubuhController.dispose();
    _nadiController.dispose();
    _pernapasanController.dispose();
    _saturasiOksigenController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetail() async {
  setState(() {
    isLoading = true;
    errorMessage = null;
  });

  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('dokter_token') ?? prefs.getString('token');
    
    print('🔑 Token: ${token?.substring(0, 20)}...'); // ✅ LOG TOKEN
    
    if (token == null) {
      throw Exception('Token tidak ditemukan. Silakan login sebagai Dokter.');
    }

    final uri = Uri.parse(
      '$baseUrl/dokter/detail-riwayat-pasien/${widget.kunjunganId}',
    );
    
    print('🌐 Request URL: $uri'); // ✅ LOG URL
    
    final res = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    print('📱 Response Status: ${res.statusCode}'); // ✅ LOG STATUS
    print('📱 Response Headers: ${res.headers}'); // ✅ LOG HEADERS
    print('📱 Response Body: ${res.body}'); // ✅ LOG BODY

    final contentType = res.headers['content-type'] ?? '';
    if (!contentType.toLowerCase().contains('application/json')) {
      throw Exception(
        'Server mengembalikan non-JSON (${res.statusCode}). Response: ${res.body}',
      );
    }

    final body = jsonDecode(res.body);
    if (res.statusCode == 200 && body is Map && (body['success'] == true)) {
      setState(() {
        detail = Map<String, dynamic>.from(body['data'] ?? {});
        isLoading = false;
      });
      _populateControllers();
    } else {
      throw Exception((body['message'] ?? 'Gagal memuat detail: ${res.body}').toString());
    }
  } catch (e) {
    print('❌ Fetch Detail Error: $e'); // ✅ LOG ERROR
    setState(() {
      isLoading = false;
      errorMessage = e.toString();
    });
  }
}
  // ✅ POPULATE CONTROLLERS dengan data EMR
  void _populateControllers() {
    if (detail != null && detail!['emr'] != null) {
      final emr = detail!['emr'] as Map<String, dynamic>;
      
      _keluhanUtamaController.text = emr['keluhan_utama']?.toString() ?? '';
      _diagnosisController.text = emr['diagnosis']?.toString() ?? '';
      _riwayatPenyakitDahuluController.text = emr['riwayat_penyakit_dahulu']?.toString() ?? '';
      _riwayatPenyakitKeluargaController.text = emr['riwayat_penyakit_keluarga']?.toString() ?? '';
      _tekananDarahController.text = emr['tekanan_darah']?.toString() ?? '';
      _suhuTubuhController.text = emr['suhu_tubuh']?.toString() ?? '';
      _nadiController.text = emr['nadi']?.toString() ?? '';
      _pernapasanController.text = emr['pernapasan']?.toString() ?? '';
      _saturasiOksigenController.text = emr['saturasi_oksigen']?.toString() ?? '';
    }
  }

  // ✅ TOGGLE EDIT MODE
  void _toggleEditMode() {
    setState(() {
      isEditMode = !isEditMode;
    });
    
    if (isEditMode) {
      _populateControllers(); // Refresh controller values saat masuk edit mode
    }
  }

  // ✅ SAVE CHANGES
  // ✅ SAVE CHANGES (VERSI FIX – HABIS SAVE LANGSUNG REFRESH DETAIL)
Future<void> _saveChanges() async {
  // Validasi form
  if (!_formKey.currentState!.validate()) return;

  // Pastikan data EMR ada
  if (detail == null || detail!['emr'] == null) {
    _showSnackbar('Data EMR tidak tersedia', isError: true);
    return;
  }

  setState(() {
    isSaving = true;
  });

  try {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('dokter_token') ?? prefs.getString('token');

    if (token == null) {
      throw Exception('Token tidak ditemukan. Silakan login ulang.');
    }

    final emrId = detail!['emr']['id'];

    final requestBody = {
      'keluhan_utama': _keluhanUtamaController.text.trim(),
      'diagnosis': _diagnosisController.text.trim(),
      'riwayat_penyakit_dahulu':
          _riwayatPenyakitDahuluController.text.trim(),
      'riwayat_penyakit_keluarga':
          _riwayatPenyakitKeluargaController.text.trim(),
      'tekanan_darah': _tekananDarahController.text.trim(),
      'suhu_tubuh': _suhuTubuhController.text.trim(),
      'nadi': _nadiController.text.trim(),
      'pernapasan': _pernapasanController.text.trim(),
      'saturasi_oksigen': _saturasiOksigenController.text.trim(),
    };

    final uri = Uri.parse('$baseUrl/dokter/edit-emr/$emrId');
    final response = await http.put(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode(requestBody),
    );

    final responseBody = jsonDecode(response.body);

    if (response.statusCode == 200 && responseBody['success'] == true) {
      // 🔁 SELALU REFRESH DETAIL DARI SERVER BIAR STATE BERSIH
      await _fetchDetail();

      if (!mounted) return;
      setState(() {
        isEditMode = false; // keluar dari mode edit
      });

      _showSnackbar('Data EMR berhasil diperbarui');
    } else {
      throw Exception(responseBody['message'] ?? 'Gagal menyimpan perubahan');
    }
  } catch (e) {
    _showSnackbar('Error: ${e.toString()}', isError: true);
  } finally {
    if (mounted) {
      setState(() {
        isSaving = false;
      });
    }
  }
}


  // ✅ CANCEL EDIT
  void _cancelEdit() {
    setState(() {
      isEditMode = false;
    });
    _populateControllers(); // Reset ke nilai asli
  }

  // ✅ SHOW SNACKBAR – versi aman, nggak bikin crash
// ======= TOAST FLOATING DI KANAN ATAS =======
void _showSnackbar(String message, {bool isError = false}) {
  if (!mounted) return;

  final overlay = Overlay.of(context);
  if (overlay == null) return;

  final entry = OverlayEntry(
    builder: (context) => Positioned(
      top: 30,
      right: 30,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isError
                ? Colors.red.shade600
                : Colors.green.shade600,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          constraints: const BoxConstraints(maxWidth: 350),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(
                isError
                    ? FontAwesomeIcons.exclamationTriangle
                    : FontAwesomeIcons.checkCircle,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  // Masukkan toast ke layar
  overlay.insert(entry);

  // Hilangkan setelah 3 detik
  Future.delayed(const Duration(seconds: 3)).then((_) {
    if (entry.mounted) entry.remove();
  });
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
    if (['succeed', 'completed', 'selesai', 'done'].contains(s)) {
      bg = Colors.green.shade100;
      fg = Colors.green.shade700;
    } else if (['canceled', 'dibatalkan'].contains(s)) {
      bg = Colors.red.shade100;
      fg = Colors.red.shade700;
    } else if (['payment', 'paid', 'lunas'].contains(s)) {
      bg = Colors.blue.shade100;
      fg = Colors.blue.shade700;
    } else {
      bg = Colors.orange.shade100;
      fg = Colors.orange.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(.2)),
      ),
      child: Text(
        status ?? 'Unknown',
        style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  // ---------- SECTION & ITEM HELPERS ----------
  Widget _section({
    required IconData icon,
    required String title,
    required Color color,
    required List<Widget> children,
    VoidCallback? onEdit, // ✅ Callback untuk edit
    bool showEditButton = false, // ✅ Show edit button
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // heading strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              border: Border(bottom: BorderSide(color: color.withOpacity(.18))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: color.withOpacity(.18)),
                  ),
                  child: FaIcon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: color,
                      fontSize: 15,
                      letterSpacing: .2,
                    ),
                  ),
                ),
                // ✅ EDIT BUTTON di header section
                if (showEditButton && onEdit != null)
                  InkWell(
                    onTap: onEdit,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FaIcon(
                            FontAwesomeIcons.edit,
                            size: 12,
                            color: Colors.orange.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Edit',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  // ✅ EDITABLE BULLET ITEM
  Widget _editableBullet({
    required String label,
    required String value,
    TextEditingController? controller,
    bool isRequired = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    if (isEditMode && controller != null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                    fontSize: 13,
                  ),
                ),
                if (isRequired) ...[
                  const SizedBox(width: 4),
                  const Text('*', style: TextStyle(color: Colors.red)),
                ],
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: controller,
              maxLines: maxLines,
              keyboardType: keyboardType,
              validator: isRequired ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return '$label wajib diisi';
                }
                return null;
              } : null,
              decoration: InputDecoration(
                hintText: 'Masukkan $label...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.teal.shade600, width: 2),
                ),
                fillColor: Colors.grey.shade50,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return _bullet(label, value);
    }
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
            flex: 40,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
                letterSpacing: .15,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 60,
            child: Text(
              value.isEmpty || value == 'N/A' ? '-' : value,
              style: TextStyle(
                color: value.isEmpty || value == 'N/A' ? Colors.grey.shade400 : AppColors.sub,
                height: 1.35,
              ),
            ),
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
        if (first is Map && first['obat'] is List) {
          return List<dynamic>.from(first['obat']);
        }
      }
      if (resep is Map && resep['obat'] is List) {
        return List<dynamic>.from(resep['obat']);
      }
    } catch (_) {}
    return [];
  }

  // ✅ TAMBAHAN: Extract layanan dari response
  List<dynamic> _extractLayanan(dynamic detailData) {
    try {
      final layanan = detailData['layanan'];
      if (layanan == null) return [];
      if (layanan is List) {
        return List<dynamic>.from(layanan);
      }
    } catch (_) {}
    return [];
  }

  // ---------- HEADER CARD (SHADCN STYLE) ----------
  Widget _headerCard(Map<String, dynamic> d, bool isSmall) {
    final pasien = (d['pasien'] ?? {}) as Map<String, dynamic>;
    final foto = pasien['foto_pasien'];
    final nama = pasien['nama_pasien']?.toString() ?? 'Nama tidak tersedia';
    final gender = (pasien['jenis_kelamin'] ?? 'N/A').toString();
    final poli = _s(d['poli'] ?? {}, 'nama_poli');
    final tgl = _fmtDate(d['tanggal_kunjungan']?.toString());
    final noAntrian = _s(d, 'no_antrian');
    final emrNo = _s(d['pasien'] ?? {}, 'no_emr');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TOP ROW: Avatar + Nama + Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // avatar
              Container(
                width: isSmall ? 54 : 60,
                height: isSmall ? 54 : 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.tealA.withOpacity(.12),
                  border: Border.all(
                    color: AppColors.tealA.withOpacity(.32),
                    width: 1.4,
                  ),
                  image: (foto != null)
                      ? DecorationImage(
                          image: NetworkImage(
                            'http://10.19.0.247:8000/storage/$foto',
                          ),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: (foto == null)
                    ? Center(
                        child: FaIcon(
                          FontAwesomeIcons.userLarge,
                          color: AppColors.tealA,
                          size: isSmall ? 26 : 30,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nama pasien
                    Text(
                      nama,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w700,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Nomor EMR
                    if (emrNo != 'N/A' && emrNo.isNotEmpty) ...[
                      Row(
                        children: [
                          FaIcon(
                            FontAwesomeIcons.idCard,
                            size: 12,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'No. EMR: $emrNo',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                    ],
                    // Sub info kecil
                    Row(
                      children: [
                        FaIcon(
                          FontAwesomeIcons.calendarDays,
                          size: 12,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tgl,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _chipStatus(_s(d, 'status')),
            ],
          ),
          const SizedBox(height: 14),
          // PILL META (antrian, poli, gender, emr)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(icon: FontAwesomeIcons.ticket, text: 'Antrian $noAntrian'),
              if (poli != 'N/A')
                _pill(icon: FontAwesomeIcons.hospital, text: poli),
              _pill(
                icon: gender.toLowerCase() == 'laki-laki'
                    ? FontAwesomeIcons.mars
                    : FontAwesomeIcons.venus,
                text: gender,
              ),
              if (emrNo != 'N/A')
                _pill(
                  icon: FontAwesomeIcons.fileMedical,
                  text: 'EMR $emrNo',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FaIcon(icon, size: 12, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(IconData icon, String k, String v, {Color? tint}) {
    final c = tint ?? Colors.green.shade700;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          FaIcon(icon, size: 14, color: c),
          const SizedBox(width: 8),
          Text(
            '$k: ',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  // ✅ TAMBAHAN: Build section layanan
  Widget? _buildLayananSection() {
    final layananList = _extractLayanan(detail);
    if (layananList.isEmpty) {
      return null;
    }

    return _section(
      icon: FontAwesomeIcons.stethoscope,
      title: 'Layanan Medis',
      color: Colors.blue.shade600,
      children: [
        ...layananList.map((l) {
          String nama = _s(l, 'nama_layanan');
          String harga = 'N/A';
          String jumlah = 'N/A';
          String subtotal = 'N/A';

          if (l is Map && l['harga_layanan'] != null) {
            try {
              double hargaDouble = double.parse(l['harga_layanan'].toString());
              harga = NumberFormat.currency(
                locale: 'id_ID', 
                symbol: 'Rp ', 
                decimalDigits: 0
              ).format(hargaDouble);
            } catch (_) {
              harga = l['harga_layanan'].toString();
            }
          }

          if (l is Map && l['jumlah'] != null) {
            jumlah = l['jumlah'].toString();
          }

          if (l is Map && l['subtotal'] != null) {
            try {
              double subtotalDouble = double.parse(l['subtotal'].toString());
              subtotal = NumberFormat.currency(
                locale: 'id_ID', 
                symbol: 'Rp ', 
                decimalDigits: 0
              ).format(subtotalDouble);
            } catch (_) {
              subtotal = l['subtotal'].toString();
            }
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blue.shade100,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.stethoscope,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nama,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _kv(
                        FontAwesomeIcons.hashtag,
                        'Jumlah',
                        jumlah,
                        tint: Colors.blue.shade600,
                      ),
                      _kv(
                        FontAwesomeIcons.moneyBill,
                        'Harga',
                        harga,
                        tint: Colors.blue.shade600,
                      ),
                      if (subtotal != 'N/A')
                        _kv(
                          FontAwesomeIcons.calculator,
                          'Subtotal',
                          subtotal,
                          tint: Colors.blue.shade600,
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
  }

  // ---------- PDF HELPERS ----------
  Future<Uint8List> _buildEmrPdf() async {
    final d = detail ?? {};
    final pasien = (d['pasien'] ?? {}) as Map<String, dynamic>;
    final emr = (d['emr'] ?? {}) as Map<String, dynamic>;
    final poli = (d['poli'] ?? {}) as Map<String, dynamic>;

    final doc = pw.Document();

    pw.Widget _row(String label, String value) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 130,
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
            ),
          ],
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(margin: const pw.EdgeInsets.all(24)),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'EMR',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Royal Klinik',
                    style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'No. EMR: ${pasien['no_emr'] ?? '-'}',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Tanggal Cetak: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),

          // DATA PASIEN
          pw.Text(
            'Data Pasien',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(),
          _row('Nama Pasien', pasien['nama_pasien']?.toString() ?? '-'),
          _row(
            'Tanggal Lahir',
            _fmtDate(pasien['tanggal_lahir']?.toString() ?? ''),
          ),
          _row('Jenis Kelamin', pasien['jenis_kelamin']?.toString() ?? '-'),
          _row('Alamat', pasien['alamat']?.toString() ?? '-'),
          pw.SizedBox(height: 12),

          // INFO KUNJUNGAN
          pw.Text(
            'Informasi Kunjungan',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(),
          _row(
            'Tanggal Kunjungan',
            _fmtDate(d['tanggal_kunjungan']?.toString() ?? ''),
          ),
          _row('No. Antrian', d['no_antrian']?.toString() ?? '-'),
          _row('Poli', poli['nama_poli']?.toString() ?? '-'),
          _row('Keluhan Awal', d['keluhan_awal']?.toString() ?? '-'),
          _row('Status', d['status']?.toString() ?? '-'),
          pw.SizedBox(height: 12),

          // LAYANAN (jika ada)
          if (_extractLayanan(detail).isNotEmpty) ...[
            pw.Text(
              'Layanan Medis',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            ..._extractLayanan(detail).map((l) {
              String nama = _s(l, 'nama_layanan');
              String jumlah = _s(l, 'jumlah');
              String harga = _s(l, 'harga_layanan');
              return _row('$nama ($jumlah x)', harga);
            }),
            pw.SizedBox(height: 12),
          ],

          // EMR
          pw.Text(
            'Electronic Medical Record',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(),
          _row('Keluhan Utama', emr['keluhan_utama']?.toString() ?? '-'),
          _row(
            'Riwayat Penyakit Dahulu',
            emr['riwayat_penyakit_dahulu']?.toString() ?? '-',
          ),
          _row(
            'Riwayat Penyakit Keluarga',
            emr['riwayat_penyakit_keluarga']?.toString() ?? '-',
          ),
          _row('Diagnosis', emr['diagnosis']?.toString() ?? '-'),
          pw.SizedBox(height: 12),

          pw.Text(
            'Tanda Vital',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.Divider(),
          _row('Tekanan Darah', emr['tekanan_darah']?.toString() ?? '-'),
          _row('Suhu Tubuh (°C)', emr['suhu_tubuh']?.toString() ?? '-'),
          _row('Nadi (bpm)', emr['nadi']?.toString() ?? '-'),
          _row('Pernapasan / menit', emr['pernapasan']?.toString() ?? '-'),
          _row(
            'Saturasi Oksigen (%)',
            emr['saturasi_oksigen']?.toString() ?? '-',
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> _onPrintEmr() async {
    if (detail == null) return;
    try {
      final bytes = await _buildEmrPdf();
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => bytes);
    } catch (e) {
      debugPrint('Error print EMR: $e');
    }
  }

  Future<void> _onDownloadEmr() async {
    if (detail == null) return;
    try {
      final bytes = await _buildEmrPdf();
      final emrNo = _s(detail?['pasien'] ?? {}, 'no_emr');

      final fileName = (emrNo != 'N/A' && emrNo.isNotEmpty)
          ? 'EMR_$emrNo'
          : 'EMR_${widget.kunjunganId}';

      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );
    } catch (e) {
      debugPrint('Error download EMR: $e');
    }
  }

  // ---------- UI STATES ----------
  Widget _errorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: FaIcon(
                FontAwesomeIcons.circleExclamation,
                color: Colors.red.shade400,
                size: 40,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Terjadi Kesalahan',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? '-',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.red.shade500, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _fetchDetail,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
              ),
              icon: const FaIcon(FontAwesomeIcons.rotateRight, size: 14),
              label: const Text('Coba Lagi', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: FaIcon(
              FontAwesomeIcons.folderOpen,
              color: Colors.grey.shade400,
              size: 40,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Data tidak tersedia',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            'Detail kunjungan tidak ditemukan.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final isDesktop = screenW >= 1024;
    final isTablet = screenW >= 768 && screenW < 1024;
    final isMobile = screenW < 768;

    return Scaffold(
      // drawer untuk mobile
      drawer: isMobile
          ? SharedMobileDrawer(
              currentPage: SidebarPage.riwayatPasien,
              dokterData: null,
              onNavigate: (p) => NavigationHelper.navigateToPage(context, p),
              onLogout: () => NavigationHelper.logout(context),
            )
          : null,
      body: Row(
        children: [
          if (isDesktop || isTablet)
            SharedSidebar(
              currentPage: SidebarPage.riwayatPasien,
              dokterData: null,
              isCollapsed: false,
              onToggleCollapse: () {},
              onNavigate: (p) => NavigationHelper.navigateToPage(context, p),
              onLogout: () => NavigationHelper.logout(context),
            ),
          Expanded(
            child: Column(
              children: [
                // header atas (punya tombol refresh)
                SharedTopHeader(
                  currentPage: SidebarPage.riwayatPasien,
                  dokterData: null,
                  isMobile: isMobile,
                  onRefresh: _fetchDetail,
                ),

                // isi utama
                Expanded(
                  child: Container(
                    color: const Color(0xFFF1F5F9),
                    child: _buildBody(isMobile),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // ✅ FLOATING ACTION BUTTON untuk edit mode
      floatingActionButton: detail != null && detail!['emr'] != null
          ? AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: isEditMode
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Cancel button
                        FloatingActionButton(
                          heroTag: "cancel",
                          onPressed: isSaving ? null : _cancelEdit,
                          backgroundColor: Colors.grey.shade600,
                          child: const FaIcon(
                            FontAwesomeIcons.times,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Save button
                        FloatingActionButton.extended(
                          heroTag: "save",
                          onPressed: isSaving ? null : _saveChanges,
                          backgroundColor: Colors.green.shade600,
                          label: Text(
                            isSaving ? 'Menyimpan...' : 'Simpan',
                            style: const TextStyle(color: Colors.white),
                          ),
                          icon: isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const FaIcon(
                                  FontAwesomeIcons.save,
                                  color: Colors.white,
                                ),
                        ),
                      ],
                    )
                  : FloatingActionButton.extended(
                      heroTag: "edit",
                      onPressed: _toggleEditMode,
                      backgroundColor: Colors.orange.shade600,
                      label: const Text(
                        'Edit EMR',
                        style: TextStyle(color: Colors.white),
                      ),
                      icon: const FaIcon(
                        FontAwesomeIcons.edit,
                        color: Colors.white,
                      ),
                    ),
            )
          : null,
    );
  }

  /// ==== BODY UTAMA (layout web: center with max width) ====
  Widget _buildBody(bool isMobile) {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.teal),
            SizedBox(height: 12),
            Text('Memuat detail...'),
          ],
        ),
      );
    }
    if (errorMessage != null) return _errorWidget();
    if (detail == null) return _emptyWidget();

    final maxWidth = 1100.0;

    return RefreshIndicator(
      color: AppColors.tealA,
      onRefresh: _fetchDetail,
      child: LayoutBuilder(
        builder: (context, c) {
          final pad = EdgeInsets.symmetric(
            horizontal: isMobile ? 16 : 24,
            vertical: isMobile ? 14 : 20,
          );

          return Form(
            key: _formKey, // ✅ Wrap dengan Form untuk validasi
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: pad,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // back button + edit mode indicator
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const FaIcon(FontAwesomeIcons.arrowLeft, size: 16),
                            label: const Text(
                              'Kembali ke Riwayat Pasien',
                              style: TextStyle(fontSize: 13),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF0F172A),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const Spacer(),
                          // ✅ EDIT MODE INDICATOR
                          if (isEditMode)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.orange.shade300),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FaIcon(
                                    FontAwesomeIcons.edit,
                                    size: 12,
                                    color: Colors.orange.shade700,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Mode Edit',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 👉 BUTTON PDF (DOWNLOAD & PRINT) DI SINI
                      if (!isEditMode) // ✅ Hide saat edit mode
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: detail == null
                                  ? null
                                  : () => _onDownloadEmr(),
                              icon: const FaIcon(
                                FontAwesomeIcons.download,
                                size: 13,
                              ),
                              label: const Text(
                                'Download PDF',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                side: BorderSide(color: AppColors.tealA),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: detail == null ? null : _onPrintEmr,
                              icon: const FaIcon(FontAwesomeIcons.print, size: 13),
                              label: const Text(
                                'Cetak EMR',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.tealA,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),

                      // Card utama: header pasien
                      _headerCard(detail!, c.maxWidth < 420),
                      const SizedBox(height: 16),

                      // grid 2 kolom di desktop, 1 kolom di mobile
                      GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: c.maxWidth >= 900 ? 2 : 1,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.25,
                        ),
                        children: [
                          _section(
                            icon: FontAwesomeIcons.user,
                            title: 'Informasi Pasien',
                            color: AppColors.tealA,
                            children: [
                              _bullet(
                                'Nama',
                                _s(detail?['pasien'], 'nama_pasien'),
                              ),
                              _bullet('Alamat', _s(detail?['pasien'], 'alamat')),
                              _bullet(
                                'Tanggal Lahir',
                                _fmtDate(_s(detail?['pasien'], 'tanggal_lahir')),
                              ),
                              _bullet(
                                'Jenis Kelamin',
                                _s(detail?['pasien'], 'jenis_kelamin'),
                              ),
                              _bullet(
                                'No. EMR',
                                _s(detail?['pasien'], 'no_emr'),
                              ),
                            ],
                          ),
                          _section(
                            icon: FontAwesomeIcons.calendarCheck,
                            title: 'Informasi Kunjungan',
                            color: Colors.blue.shade600,
                            children: [
                              _bullet(
                                'Tanggal Kunjungan',
                                _fmtDate(_s(detail, 'tanggal_kunjungan')),
                              ),
                              _bullet('No. Antrian', _s(detail, 'no_antrian')),
                              _bullet('Keluhan Awal', _s(detail, 'keluhan_awal')),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Text(
                                    'Status: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _chipStatus(_s(detail, 'status')),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Section Perawat Pemeriksa (opsional)
                      if (detail?['perawat'] != null) _buildPerawatSection(),

                      const SizedBox(height: 16),

                      // ✅ EMR & Tanda Vital - DENGAN FITUR EDIT
                      if (detail?['emr'] != null) ...[
                        _section(
                          icon: FontAwesomeIcons.fileMedical,
                          title: 'Electronic Medical Record',
                          color: Colors.purple.shade600,
                          showEditButton: !isEditMode, // Hide saat sudah edit mode
                          onEdit: _toggleEditMode,
                          children: [
                            _editableBullet(
                              label: 'Keluhan Utama',
                              value: _s(detail?['emr'], 'keluhan_utama'),
                              controller: _keluhanUtamaController,
                              isRequired: true,
                              maxLines: 3,
                            ),
                            _editableBullet(
                              label: 'Riwayat Penyakit Dahulu',
                              value: _s(detail?['emr'], 'riwayat_penyakit_dahulu'),
                              controller: _riwayatPenyakitDahuluController,
                              maxLines: 3,
                            ),
                            _editableBullet(
                              label: 'Riwayat Penyakit Keluarga',
                              value: _s(detail?['emr'], 'riwayat_penyakit_keluarga'),
                              controller: _riwayatPenyakitKeluargaController,
                              maxLines: 3,
                            ),
                            _editableBullet(
                              label: 'Diagnosis',
                              value: _s(detail?['emr'], 'diagnosis'),
                              controller: _diagnosisController,
                              isRequired: true,
                              maxLines: 3,
                            ),
                          ],
                        ),
                        _section(
                          icon: FontAwesomeIcons.heartPulse,
                          title: 'Tanda Vital',
                          color: Colors.orange.shade600,
                          showEditButton: !isEditMode, // Hide saat sudah edit mode
                          onEdit: _toggleEditMode,
                          children: [
                            _editableBullet(
                              label: 'Tekanan Darah',
                              value: _s(detail?['emr'], 'tekanan_darah'),
                              controller: _tekananDarahController,
                            ),
                            _editableBullet(
                              label: 'Suhu Tubuh (°C)',
                              value: _s(detail?['emr'], 'suhu_tubuh'),
                              controller: _suhuTubuhController,
                              keyboardType: TextInputType.number,
                            ),
                            _editableBullet(
                              label: 'Nadi (bpm)',
                              value: _s(detail?['emr'], 'nadi'),
                              controller: _nadiController,
                              keyboardType: TextInputType.number,
                            ),
                            _editableBullet(
                              label: 'Pernapasan / menit',
                              value: _s(detail?['emr'], 'pernapasan'),
                              controller: _pernapasanController,
                              keyboardType: TextInputType.number,
                            ),
                            _editableBullet(
                              label: 'Saturasi Oksigen (%)',
                              value: _s(detail?['emr'], 'saturasi_oksigen'),
                              controller: _saturasiOksigenController,
                              keyboardType: TextInputType.number,
                            ),
                          ],
                        ),
                      ],

                      // Resep Obat (read-only)
                      Builder(
                        builder: (_) {
                          final obatList = _extractObat(detail);
                          if (obatList.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return _section(
                            icon: FontAwesomeIcons.pills,
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
                                  if (pivotDosis != 'N/A' &&
                                      pivotDosis.isNotEmpty) {
                                    dosis = pivotDosis;
                                  }
                                }

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.green.shade100,
                                    ),
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
                                        child: FaIcon(
                                          FontAwesomeIcons.pills,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              nama,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color: Colors.green.shade800,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            _kv(
                                              FontAwesomeIcons.boxOpen,
                                              'Jumlah',
                                              jumlah,
                                              tint: Colors.green.shade600,
                                            ),
                                            _kv(
                                              FontAwesomeIcons.syringe,
                                              'Dosis',
                                              dosis,
                                              tint: Colors.green.shade600,
                                            ),
                                            _kv(
                                              FontAwesomeIcons.noteSticky,
                                              'Keterangan',
                                              ket,
                                              tint: Colors.green.shade600,
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

                      // SECTION LAYANAN: Dipindahkan ke bawah resep obat
                      if (_buildLayananSection() != null) ...[
                        const SizedBox(height: 16),
                        _buildLayananSection()!,
                      ],

                      // Bottom padding untuk floating button
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPerawatSection() {
    final perawat = detail?['perawat'] as Map<String, dynamic>?;
    if (perawat == null) return const SizedBox.shrink();

    final namaPerawat = _s(perawat, 'nama_perawat');
    final fotoPerawat = perawat['foto_perawat']?.toString();
    final noHp = _s(perawat, 'no_hp_perawat');

    if (namaPerawat == 'N/A' ||
        namaPerawat.toLowerCase().contains('tidak diketahui') ||
        namaPerawat.toLowerCase().contains('belum ada data')) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withOpacity(.06),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              border: Border(
                bottom: BorderSide(
                  color: const Color(0xFF0284C7).withOpacity(.18),
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF0284C7).withOpacity(0.25),
                    ),
                  ),
                  child: const FaIcon(
                    FontAwesomeIcons.userNurse,
                    color: Color(0xFF0284C7),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Perawat Pemeriksa',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0284C7),
                      fontSize: 15,
                      letterSpacing: .2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0284C7),
                    border: Border.all(
                      color: const Color(0xFF0284C7).withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: fotoPerawat != null && fotoPerawat.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            'http://10.19.0.247:8000/storage/$fotoPerawat',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Center(
                                  child: FaIcon(
                                    FontAwesomeIcons.userNurse,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                          ),
                        )
                      : const Center(
                          child: FaIcon(
                            FontAwesomeIcons.userNurse,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFF0284C7).withOpacity(0.25),
                          ),
                        ),
                        child: const Text(
                          'PERAWAT',
                          style: TextStyle(
                            color: Color(0xFF0284C7),
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        namaPerawat,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (noHp != 'N/A' && noHp.isNotEmpty) ...[
                        Row(
                          children: [
                            FaIcon(
                              FontAwesomeIcons.phone,
                              size: 12,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                noHp,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13,
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const FaIcon(
                    FontAwesomeIcons.checkCircle,
                    color: Color(0xFF10B981),
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- PALETTE ----------
class AppColors {
  static final tealA = Colors.teal.shade600;
  static final tealB = Colors.teal.shade500;
  static final ink = const Color(0xFF121418);
  static final sub = Colors.black.withOpacity(.65);
  static final line = const Color(0x11000000);
}