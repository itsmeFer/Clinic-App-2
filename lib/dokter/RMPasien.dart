import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ✅ PDF / PRINT / SAVE DEPENDENCIES
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:file_saver/file_saver.dart';

import 'package:RoyalClinic/dokter/DetailRiwayatPasien.dart';
// pakai komponen shared yang sudah kamu buat
import 'package:RoyalClinic/dokter/Sidebar.dart'
    show
        SharedSidebar,
        SharedMobileDrawer,
        SharedTopHeader,
        SidebarPage,
        NavigationHelper;
// FONT AWESOME
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class RMPasien extends StatefulWidget {
  final int pasienId;
  final String namaPasien;

  const RMPasien({super.key, required this.pasienId, required this.namaPasien});

  @override
  State<RMPasien> createState() => _RMPasienState();
}

class _RMPasienState extends State<RMPasien> {
  Widget _kvRow(String k, String v, bool isSmall) {
    return Padding(
      padding: EdgeInsets.only(bottom: isSmall ? 6 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isSmall ? 110 : 140,
            child: Text(
              k,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              v,
              style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kvInline(String k, String v, bool isSmall) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            k,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            v,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  int _kunjunganIdFrom(Map<String, dynamic> emrData) {
    // beberapa API mengirim "kunjungan_id", sebagian lagi "id"
    final raw = emrData['kunjungan_id'] ?? emrData['id'];
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw) ?? 0;
    if (raw is num) return raw.toInt();
    return 0;
  }

  // Ganti sesuai BASE API Anda
  static const String baseUrl = 'http://10.19.0.247:8000/api';

  bool _isLoading = true;
  Map<String, dynamic>? _pasienData;
  List<dynamic> _riwayatEMR = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadRiwayatEMR();
  }

  // ---------- Helpers ----------
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('dokter_token') ?? prefs.getString('token');
  }

  List<Map<String, dynamic>> _toListMap(dynamic v) {
    if (v is List) {
      return v
          .where((e) => e is Map)
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return const [];
  }

  Map<String, dynamic> _toMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return <String, dynamic>{};
  }

  Future<void> _loadRiwayatEMR() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _getToken();
      if (token == null) {
        throw Exception('Token tidak ditemukan');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/dokter/pasien/riwayat-emr/${widget.pasienId}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _pasienData = Map<String, dynamic>.from(
              data['data']['pasien'] ?? {},
            );
            _riwayatEMR = List<dynamic>.from(data['data']['riwayat_emr'] ?? []);
            _isLoading = false;
          });
        } else {
          throw Exception(data['message'] ?? 'Gagal mengambil data');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatTanggal(String? tanggal) {
    if (tanggal == null || tanggal.isEmpty) return 'Tidak tersedia';
    try {
      final dateTime = DateTime.parse(tanggal);
      return DateFormat('dd MMM yyyy, HH:mm').format(dateTime);
    } catch (_) {
      return tanggal;
    }
  }

  String _formatTanggalSingkat(String? tanggal) {
    if (tanggal == null || tanggal.isEmpty) return 'Tidak tersedia';
    try {
      final dateTime = DateTime.parse(tanggal);
      return DateFormat('dd MMM yyyy').format(dateTime);
    } catch (_) {
      return tanggal;
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null || iso.isEmpty) return 'N/A';
    try {
      final d = DateTime.parse(iso);
      return DateFormat('dd/MM/yyyy').format(d);
    } catch (_) {
      return iso;
    }
  }

  int _calculateAge(String? tanggalLahir) {
    if (tanggalLahir == null || tanggalLahir.isEmpty) return 0;
    try {
      final birthDate = DateTime.parse(tanggalLahir);
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return 0;
    }
  }

  String _money(dynamic price) {
    if (price == null) return '0';
    try {
      final v = price is String
          ? double.parse(price)
          : (price as num).toDouble();
      return NumberFormat('#,###', 'id_ID').format(v);
    } catch (_) {
      return price.toString();
    }
  }

    String _extractNoEmr() {
    // 1. Coba dari data pasien
    if (_pasienData != null &&
        (_pasienData!['no_emr']?.toString().isNotEmpty ?? false)) {
      return _pasienData!['no_emr'].toString();
    }

    // 2. Kalau tidak ada, coba dari riwayat EMR pertama
    if (_riwayatEMR.isNotEmpty) {
      final first = _toMap(_riwayatEMR.first);

      // bisa saja ada di root
      if ((first['no_emr']?.toString().isNotEmpty ?? false)) {
        return first['no_emr'].toString();
      }

      // atau di dalam objek emr
      final emr = _toMap(first['emr']);
      if ((emr['no_emr']?.toString().isNotEmpty ?? false)) {
        return emr['no_emr'].toString();
      }
    }

    // kalau benar-benar tidak ada
    return '';
  }

  // ========== 🆕 PDF EXPORT FUNCTIONALITY ========== //
  Future<Uint8List> _buildRiwayatEmrPdf() async {
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

    final noEmr = _extractNoEmr();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(margin: const pw.EdgeInsets.all(24)),
        build: (context) => [
          // HEADER
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'RIWAYAT REKAM MEDIS LENGKAP',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue800,
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
                    'No. EMR: ${noEmr.isNotEmpty ? noEmr : '-'}',
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
          _row('Nama Pasien', _pasienData?['nama_pasien']?.toString() ?? '-'),
          _row(
            'Tanggal Lahir',
            _fmtDate(_pasienData?['tanggal_lahir']?.toString() ?? ''),
          ),
          _row('Jenis Kelamin', _pasienData?['jenis_kelamin']?.toString() ?? '-'),
          _row('Alamat', _pasienData?['alamat']?.toString() ?? '-'),
          pw.SizedBox(height: 16),

          // ✅ RIWAYAT EMR LENGKAP
          if (_riwayatEMR.isNotEmpty) ...[
            pw.Text(
              'RIWAYAT REKAM MEDIS (${_riwayatEMR.length} Kunjungan)',
              style: pw.TextStyle(
                fontSize: 14, 
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
            pw.Divider(color: PdfColors.blue800),
            pw.SizedBox(height: 8),
            
            // Loop semua riwayat EMR
            ..._riwayatEMR.asMap().entries.map((entry) {
              int index = entry.key;
              Map<String, dynamic> kunjungan = _toMap(entry.value);
              
              final emrData = _toMap(kunjungan['emr']);
              final poliData = _toMap(kunjungan['poli']);
              final dokterData = _toMap(kunjungan['dokter']);
              final perawatData = _toMap(kunjungan['perawat']);
              final resepObat = _toListMap(kunjungan['resep_obat']);
              final layanan = _toListMap(kunjungan['layanan']);
              final tandaVital = _toMap(emrData['tanda_vital']);

              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 20),
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 1),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Header kunjungan
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue50,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        'KUNJUNGAN #${index + 1} - ${_fmtDate(kunjungan['tanggal_kunjungan']?.toString() ?? '')}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 8),

                    // Info kunjungan
                    _row('Tanggal Kunjungan', _fmtDate(kunjungan['tanggal_kunjungan']?.toString() ?? '')),
                    _row('No. Antrian', kunjungan['no_antrian']?.toString() ?? '-'),
                    _row('Poli', poliData['nama_poli']?.toString() ?? '-'),
                    _row('Dokter', dokterData['nama_dokter']?.toString() ?? '-'),
                    if (perawatData['nama_perawat'] != null && 
                        (perawatData['nama_perawat']?.toString().isNotEmpty ?? false) &&
                        !(perawatData['nama_perawat']?.toString().toLowerCase().contains('belum ada') ?? false))
                      _row('Perawat Pemeriksa', perawatData['nama_perawat']?.toString() ?? '-'),
                    _row('Status Kunjungan', kunjungan['status_kunjungan']?.toString() ?? '-'),
                    pw.SizedBox(height: 6),

                    // EMR Detail
                    pw.Text(
                      'Detail Pemeriksaan',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Divider(height: 4),
                    _row('Keluhan Awal', kunjungan['keluhan_awal']?.toString() ?? '-'),
                    _row('Keluhan Utama', emrData['keluhan_utama']?.toString() ?? '-'),
                    _row('Riwayat Penyakit Dahulu', emrData['riwayat_penyakit_dahulu']?.toString() ?? '-'),
                    _row('Riwayat Penyakit Keluarga', emrData['riwayat_penyakit_keluarga']?.toString() ?? '-'),
                    _row('Diagnosis', emrData['diagnosis']?.toString() ?? '-'),
                    pw.SizedBox(height: 4),

                    // Tanda vital
                    pw.Text(
                      'Tanda Vital',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Divider(height: 4),
                    _row('Tekanan Darah', tandaVital['tekanan_darah']?.toString() ?? '-'),
                    _row('Suhu Tubuh (°C)', tandaVital['suhu_tubuh']?.toString() ?? '-'),
                    _row('Nadi (bpm)', tandaVital['nadi']?.toString() ?? '-'),
                    _row('Pernapasan/menit', tandaVital['pernapasan']?.toString() ?? '-'),
                    _row('Saturasi Oksigen (%)', tandaVital['saturasi_oksigen']?.toString() ?? '-'),
                    
                    // Layanan (jika ada)
                    if (layanan.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Layanan Medis',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Divider(height: 4),
                      ...layanan.map((l) {
                        final nama = l['nama_layanan']?.toString() ?? 'Layanan';
                        final jumlah = l['jumlah']?.toString() ?? '1';
                        final harga = l['harga_layanan']?.toString() ?? '0';
                        return _row('$nama (${jumlah}x)', 'Rp ${_money(harga)}');
                      }).toList(),
                    ],

                    // Resep obat (jika ada)
                    if (resepObat.isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Resep Obat',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Divider(height: 4),
                      ...resepObat.map((obat) {
                        final nama = obat['nama_obat']?.toString() ?? 'Obat';
                        final jumlah = obat['jumlah']?.toString() ?? '1';
                        final dosis = obat['dosis']?.toString() ?? '';
                        final keterangan = obat['keterangan']?.toString() ?? '';
                        final status = obat['status']?.toString() ?? '';
                        
                        String obatInfo = '$nama (${jumlah}x)';
                        if (dosis.isNotEmpty) obatInfo += ' - $dosis';
                        if (status.isNotEmpty) obatInfo += ' [$status]';
                        
                        return pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(obatInfo, style: const pw.TextStyle(fontSize: 10)),
                              if (keterangan.isNotEmpty)
                                pw.Text(
                                  'Keterangan: $keterangan',
                                  style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ],
                ),
              );
            }).toList(),
          ] else ...[
            pw.Text(
              'Belum ada riwayat rekam medis untuk pasien ini.',
              style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
            ),
          ],

          // Footer
          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              'Dokumen ini dicetak secara otomatis dari Sistem Royal Klinik.\n'
              'Untuk informasi lebih lanjut, hubungi Royal Klinik.',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> _onPrintRiwayatEmr() async {
    if (_pasienData == null || _riwayatEMR.isEmpty) {
      _showSnackbar('Tidak ada data riwayat EMR untuk dicetak', isError: true);
      return;
    }
    
    try {
      _showSnackbar('Sedang menyiapkan dokumen untuk cetak...', isError: false);
      final bytes = await _buildRiwayatEmrPdf();
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => bytes);
    } catch (e) {
      debugPrint('Error print riwayat EMR: $e');
      _showSnackbar('Gagal mencetak PDF: $e', isError: true);
    }
  }

  Future<void> _onDownloadRiwayatEmr() async {
    if (_pasienData == null || _riwayatEMR.isEmpty) {
      _showSnackbar('Tidak ada data riwayat EMR untuk diunduh', isError: true);
      return;
    }

    try {
      _showSnackbar('Sedang menyiapkan PDF riwayat lengkap...', isError: false);
      
      final bytes = await _buildRiwayatEmrPdf();
      final noEmr = _extractNoEmr();

      final fileName = (noEmr.isNotEmpty)
          ? 'Riwayat_Rekam_Medis_$noEmr'
          : 'Riwayat_Rekam_Medis_${widget.namaPasien.replaceAll(' ', '_')}';

      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        ext: 'pdf',
        mimeType: MimeType.pdf,
      );
      
      _showSnackbar('PDF riwayat rekam medis berhasil disimpan!', isError: false);
    } catch (e) {
      debugPrint('Error download riwayat EMR: $e');
      _showSnackbar('Gagal menyimpan PDF: $e', isError: true);
    }
  }

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

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3)).then((_) {
      if (entry.mounted) entry.remove();
    });
  }

  // ================== LAYOUT UTAMA (dengan Sidebar & WillPopScope) ==================
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;
    final isMobile = screenWidth < 768;

    return WillPopScope(
      onWillPop: () async {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(); // balik ke list riwayat pasien
          return false;
        }
        return true;
      },
      child: Scaffold(
        drawer: isMobile
            ? SharedMobileDrawer(
                currentPage: SidebarPage.riwayatPasien,
                dokterData: null,
                onNavigate: (page) =>
                    NavigationHelper.navigateToPage(context, page),
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
                onNavigate: (page) =>
                    NavigationHelper.navigateToPage(context, page),
                onLogout: () => NavigationHelper.logout(context),
              ),
            Expanded(
              child: Column(
                children: [
                  SharedTopHeader(
                    currentPage: SidebarPage.riwayatPasien,
                    dokterData: null,
                    isMobile: isMobile,
                    onRefresh: _loadRiwayatEMR,
                  ),
                  Expanded(
                    child: Container(
                      color: const Color(0xFFF8FAFC),
                      child: _buildBody(isMobile),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================== BODY (dengan tombol Kembali) ==================
  Widget _buildBody(bool isMobile) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.teal),
            SizedBox(height: 16),
            Text('Memuat riwayat rekam medis...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(
                FontAwesomeIcons.circleExclamation,
                size: 64,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              const Text(
                'Gagal memuat data',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadRiwayatEMR,
                icon: const FaIcon(FontAwesomeIcons.rotateRight, size: 16),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final pad = EdgeInsets.all(isMobile ? 16 : 24);
    return RefreshIndicator(
      onRefresh: _loadRiwayatEMR,
      color: Colors.teal,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: pad,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _BackButton(
              label: 'Kembali ke Riwayat Pasien',
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 12),

            // Header judul + aksi cepat
            Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.clockRotateLeft,
                  color: Colors.teal.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Riwayat Rekam Medis • ${widget.namaPasien}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _QuickActions(
                  onRefresh: _loadRiwayatEMR,
                  onDownloadPdf: _onDownloadRiwayatEmr,
                  onPrintPdf: _onPrintRiwayatEmr,
                  hasData: _riwayatEMR.isNotEmpty,
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildPatientHeader(),
            const SizedBox(height: 16),
            _buildStatisticsCard(),
            const SizedBox(height: 20),

            Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.listCheck,
                  color: Colors.teal.shade700,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Riwayat Pemeriksaan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_riwayatEMR.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    const FaIcon(
                      FontAwesomeIcons.inbox,
                      size: 64,
                      color: Color(0xFFCBD5F5),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Belum ada riwayat rekam medis',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Riwayat pemeriksaan pasien akan muncul di sini',
                      style: TextStyle(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ..._riwayatEMR
                  .map((emr) => _buildEMRCard(Map<String, dynamic>.from(emr)))
                  .toList(),
          ],
        ),
      ),
    );
  }

  // ---------- UI potongan ----------
  Widget _buildPatientHeader() {
    if (_pasienData == null) return const SizedBox.shrink();
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    
    // ✅ Ambil No EMR dari pasien / riwayat EMR
    final noEmr = _extractNoEmr();


    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: isSmallScreen ? 56 : 64,
                height: isSmallScreen ? 56 : 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF1F5F9),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ClipOval(
                  child: (_pasienData!['foto_pasien'] != null &&
                          (_pasienData!['foto_pasien'] as String).isNotEmpty)
                      ? Image.network(
                          'http://10.19.0.247:8000/storage/${_pasienData!['foto_pasien']}',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _defaultAvatarIcon(),
                        )
                      : _defaultAvatarIcon(),
                ),
              ),
              SizedBox(width: isSmallScreen ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _pasienData!['nama_pasien']?.toString() ?? 'Tidak tersedia',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        FaIcon(
                          _pasienData!['jenis_kelamin'] == 'Laki-laki'
                              ? FontAwesomeIcons.mars
                              : FontAwesomeIcons.venus,
                          size: 16,
                          color: const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_pasienData!['jenis_kelamin'] ?? '-'} • ${_calculateAge(_pasienData!['tanggal_lahir']?.toString())} tahun',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                    if ((_pasienData!['alamat']?.toString().isNotEmpty ?? false))
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Row(
                          children: [
                            const FaIcon(
                              FontAwesomeIcons.locationDot,
                              size: 16,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _pasienData!['alamat'].toString(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (_riwayatEMR.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      const FaIcon(
                        FontAwesomeIcons.calendarDays,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatTanggalSingkat(
                          _toMap(
                            _riwayatEMR.first,
                          )['tanggal_kunjungan']?.toString(),
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          
          // ✅ TAMBAHKAN NO EMR Section
          if (noEmr.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF7C3AED).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.idCard,
                      size: 16,
                      color: Color(0xFF7C3AED),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nomor EMR',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF7C3AED),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          noEmr,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF5B21B6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Copy button untuk No EMR
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: IconButton(
                      onPressed: () {
                        // Copy No EMR ke clipboard
                        // Clipboard.setData(ClipboardData(text: noEmr));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('No EMR $noEmr berhasil disalin'),
                            backgroundColor: const Color(0xFF7C3AED),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const FaIcon(
                        FontAwesomeIcons.copy,
                        size: 16,
                        color: Color(0xFF7C3AED),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
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

  Widget _defaultAvatarIcon() =>
      const Icon(FontAwesomeIcons.user, color: Color(0xFF94A3B8), size: 32);

  Widget _buildStatisticsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: _statItem(
              icon: FontAwesomeIcons.calendarCheck,
              label: 'Total Kunjungan',
              value: _riwayatEMR.length.toString(),
            ),
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade200),
          Expanded(
            child: _statItem(
              icon: FontAwesomeIcons.folderOpen,
              label: 'Rekam Medis',
              value: _riwayatEMR.length.toString(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FaIcon(icon, size: 22, color: const Color(0xFF0EA5E9)),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEMRCard(Map<String, dynamic> emrData) {
  final isSmall = MediaQuery.of(context).size.width < 400;
  final kunjunganId = _kunjunganIdFrom(emrData);

  void _goToDetail() {
    if (kunjunganId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID kunjungan tidak valid')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailRiwayatPasienPage(kunjunganId: kunjunganId),
      ),
    );
  }

  final poli = _toMap(emrData['poli'])['nama_poli']?.toString() ?? 'Tidak diketahui';
  final status = emrData['status_kunjungan']?.toString();
  final emr = _toMap(emrData['emr']);
  final tandaVital = _toMap(emr['tanda_vital']);
  
  // ✅ Data perawat (sudah ada di kode Anda)
  final perawat = _toMap(emrData['perawat']);
  final namaPerawat = perawat['nama_perawat']?.toString();
  final fotoPerawat = perawat['foto_perawat']?.toString(); // ✅ TAMBAH ini

  final keluhanUtama = emr['keluhan_utama']?.toString();
  final diagnosis = emr['diagnosis']?.toString();
  final tekananDarah = tandaVital['tekanan_darah']?.toString();
  final suhu = tandaVital['suhu_tubuh']?.toString();

  return Card(
    elevation: 0,
    margin: EdgeInsets.only(bottom: isSmall ? 12 : 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Colors.grey.shade200),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _goToDetail,
      child: Padding(
        padding: EdgeInsets.all(isSmall ? 14 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header baris 1: tanggal + status
            Row(
              children: [
                const FaIcon(
                  FontAwesomeIcons.calendarDays,
                  size: 18,
                  color: Color(0xFF0EA5E9),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatTanggalSingkat(
                      emrData['tanggal_kunjungan']?.toString(),
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusPill(status: status),
              ],
            ),

            const SizedBox(height: 8),

            // header baris 2: poli + no antrian
            Row(
              children: [
                const FaIcon(
                  FontAwesomeIcons.hospital,
                  size: 16,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Poli: $poli',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if ((emrData['no_antrian']?.toString().isNotEmpty ?? false)) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      'Antrian ${emrData['no_antrian']}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // ✅ Info perawat - DITINGKATKAN dengan avatar
            if (namaPerawat != null && namaPerawat.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(isSmall ? 8 : 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F9FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Row(
                  children: [
                    // ✅ Avatar perawat kecil
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0284C7),
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
                                    size: 10,
                                  ),
                                ),
                            ),
                          )
                        : const Center(
                            child: FaIcon(
                              FontAwesomeIcons.userNurse,
                              color: Colors.white,
                              size: 10,
                            ),
                          ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Diperiksa oleh: $namaPerawat',
                        style: TextStyle(
                          fontSize: isSmall ? 10 : 11,
                          color: const Color(0xFF0369A1),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // garis tipis pemisah
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(vertical: 12),
              color: Colors.grey.shade200,
            ),

            // ringkasan isi (tanpa expand)
            if (emrData['keluhan_awal'] != null &&
                emrData['keluhan_awal'].toString().isNotEmpty)
              _kvRow(
                'Keluhan Awal',
                emrData['keluhan_awal'].toString(),
                isSmall,
              ),
            if (keluhanUtama != null && keluhanUtama.isNotEmpty)
              _kvRow('Keluhan Utama', keluhanUtama, isSmall),
            if (diagnosis != null && diagnosis.isNotEmpty)
              _kvRow('Diagnosis', diagnosis, isSmall),
            if (tekananDarah != null && tekananDarah.isNotEmpty ||
                (suhu != null && suhu.isNotEmpty))
              Row(
                children: [
                  Expanded(
                    child: _kvInline(
                      'Tekanan Darah',
                      tekananDarah ?? '-',
                      isSmall,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _kvInline('Suhu (°C)', suhu ?? '-', isSmall),
                  ),
                ],
              ),

            const SizedBox(height: 12),

            // aksi kanan: lihat detail
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _goToDetail,
                icon: const FaIcon(FontAwesomeIcons.eye, size: 18),
                label: const Text(
                  'Lihat Detail',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF14B8A6),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: const Color(0xFF14B8A6).withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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

  Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'succeed':
      case 'completed':
        return const Color(0xFF10B981);
      case 'payment':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  Widget _buildEMRDetails(Map<String, dynamic> emrData, bool isSmallScreen) {
    final emr = _toMap(emrData['emr']);
    final tandaVital = _toMap(emr['tanda_vital']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPemeriksaSection(emrData, isSmallScreen),
        SizedBox(height: isSmallScreen ? 12 : 16),

        _buildDetailSection(
          'Anamnesis',
          FontAwesomeIcons.fileLines,
          const Color(0xFF0284C7),
          [
            _rowDetail(
              'Keluhan Awal',
              emrData['keluhan_awal']?.toString(),
              isSmallScreen,
            ),
            _rowDetail(
              'Keluhan Utama',
              emr['keluhan_utama']?.toString(),
              isSmallScreen,
            ),
            if ((emr['riwayat_penyakit_dahulu']?.toString().isNotEmpty ??
                false))
              _rowDetail(
                'Riwayat Penyakit Dahulu',
                emr['riwayat_penyakit_dahulu']?.toString(),
                isSmallScreen,
              ),
            if ((emr['riwayat_penyakit_keluarga']?.toString().isNotEmpty ??
                false))
              _rowDetail(
                'Riwayat Penyakit Keluarga',
                emr['riwayat_penyakit_keluarga']?.toString(),
                isSmallScreen,
              ),
          ],
          isSmallScreen,
        ),

        SizedBox(height: isSmallScreen ? 12 : 16),

        _buildDetailSection(
          'Tanda Vital',
          FontAwesomeIcons.heartPulse,
          const Color(0xFFEF4444),
          [
            _rowDetail(
              'Tekanan Darah',
              tandaVital['tekanan_darah']?.toString(),
              isSmallScreen,
            ),
            _rowDetail(
              'Suhu Tubuh',
              tandaVital['suhu_tubuh']?.toString(),
              isSmallScreen,
            ),
            _rowDetail('Nadi', tandaVital['nadi']?.toString(), isSmallScreen),
            _rowDetail(
              'Pernapasan',
              tandaVital['pernapasan']?.toString(),
              isSmallScreen,
            ),
            _rowDetail(
              'Saturasi Oksigen',
              tandaVital['saturasi_oksigen']?.toString(),
              isSmallScreen,
            ),
          ],
          isSmallScreen,
        ),

        SizedBox(height: isSmallScreen ? 12 : 16),

        _buildDetailSection(
          'Diagnosis',
          FontAwesomeIcons.clipboardList,
          const Color(0xFFF59E0B),
          [
            _rowDetail(
              'Diagnosis',
              emr['diagnosis']?.toString(),
              isSmallScreen,
            ),
          ],
          isSmallScreen,
        ),

        SizedBox(height: isSmallScreen ? 12 : 16),

        if ((emrData['resep_obat'] as List?)?.isNotEmpty ?? false)
          _buildResepSection(emrData['resep_obat'] as List, isSmallScreen),

        if ((emrData['layanan'] as List?)?.isNotEmpty ?? false)
          _buildLayananSection(emrData['layanan'] as List, isSmallScreen),
      ],
    );
  }

 Widget _buildPemeriksaSection(Map<String, dynamic> emrData, bool isSmall) {
  final dokter = _toMap(emrData['dokter']);
  final poli = _toMap(emrData['poli']);
  final spesialis = _toMap(emrData['spesialis']);
  final perawat = _toMap(emrData['perawat']);
  final namaPerawat = perawat['nama_perawat']?.toString();
  final fotoPerawat = perawat['foto_perawat']?.toString();

  return Container(
    padding: EdgeInsets.all(isSmall ? 12 : 14),
    decoration: BoxDecoration(
      color: const Color(0xFFF0FDF4),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFDCFCE7)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            FaIcon(
              FontAwesomeIcons.idBadge,
              color: Color(0xFF10B981),
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              'Tim Pemeriksa',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF065F46),
              ),
            ),
          ],
        ),
        SizedBox(height: isSmall ? 10 : 12),
        
        // ✅ Section Perawat dengan status badge
        if (namaPerawat != null && namaPerawat.isNotEmpty) ...[
          Container(
            padding: EdgeInsets.all(isSmall ? 10 : 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F9FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBAE6FD)),
            ),
            child: Row(
              children: [
                // Avatar perawat
                Container(
                  width: isSmall ? 28 : 32,
                  height: isSmall ? 28 : 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0284C7),
                  ),
                  child: fotoPerawat != null && fotoPerawat.isNotEmpty 
                    ? ClipOval(
                        child: Image.network(
                          'http://10.19.0.247:8000/storage/$fotoPerawat',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => 
                            Center(
                              child: FaIcon(
                                FontAwesomeIcons.userNurse,
                                color: Colors.white,
                                size: isSmall ? 12 : 14,
                              ),
                            ),
                        ),
                      )
                    : Center(
                        child: FaIcon(
                          FontAwesomeIcons.userNurse,
                          color: Colors.white,
                          size: isSmall ? 12 : 14,
                        ),
                      ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Perawat Pemeriksa',
                        style: TextStyle(
                          fontSize: isSmall ? 10 : 11,
                          color: const Color(0xFF0369A1),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        namaPerawat,
                        style: TextStyle(
                          fontSize: isSmall ? 12 : 13,
                          color: const Color(0xFF0F172A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmall ? 6 : 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Perawat',
                    style: TextStyle(
                      fontSize: isSmall ? 9 : 10,
                      color: const Color(0xFF0284C7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        
        // Data dokter, poli, spesialis
        _rowDetail(
          'Dokter',
          dokter['nama_dokter']?.toString() ?? 'Tidak diketahui',
          isSmall,
        ),
        _rowDetail(
          'Poli',
          poli['nama_poli']?.toString() ?? 'Tidak diketahui',
          isSmall,
        ),
        _rowDetail(
          'Spesialis',
          spesialis['nama_spesialis']?.toString() ?? 'Tidak diketahui',
          isSmall,
        ),
      ],
    ),
  );
}

  Widget _buildDetailSection(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
    bool isSmallScreen,
  ) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color.darken(),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 10 : 12),
          ...children,
        ],
      ),
    );
  }

  Widget _rowDetail(String label, String? value, bool isSmall) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: isSmall ? 6 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
          ),
        ],
      ),
    );
  }

  Widget _buildResepSection(List<dynamic> resepList, bool isSmall) {
    final items = _toListMap(resepList);

    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF5FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              FaIcon(FontAwesomeIcons.pills, color: Color(0xFF7E22CE)),
              SizedBox(width: 8),
              Text(
                'Resep Obat',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B21A8),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmall ? 10 : 12),
          ...items.map((resep) => _resepItem(resep, isSmall)),
        ],
      ),
    );
  }

  Widget _resepItem(Map<String, dynamic> resep, bool isSmall) {
    final taken = (resep['status'] == 'Sudah Diambil');
    return Container(
      margin: EdgeInsets.only(bottom: isSmall ? 8 : 10),
      padding: EdgeInsets.all(isSmall ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE9D5FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (resep['nama_obat'] ?? 'Obat').toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Jumlah: ${resep['jumlah'] ?? '-'} • Dosis: ${resep['dosis'] ?? '-'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: taken
                      ? const Color(0xFFD1FAE5)
                      : const Color(0xFFFFEDD5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  (resep['status'] ?? 'Belum Diambil').toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: taken
                        ? const Color(0xFF065F46)
                        : const Color(0xFF9A3412),
                  ),
                ),
              ),
            ],
          ),
          if ((resep['keterangan']?.toString().isNotEmpty ?? false)) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  FaIcon(
                    FontAwesomeIcons.circleInfo,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Keterangan tercantum pada resep.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
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

  Widget _buildLayananSection(List<dynamic> layananList, bool isSmall) {
    final items = _toListMap(layananList);

    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              FaIcon(
                FontAwesomeIcons.stethoscope,
                color: Color(0xFF1D4ED8),
              ),
              SizedBox(width: 8),
              Text(
                'Layanan Medis',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
          SizedBox(height: isSmall ? 10 : 12),
          ...items.map((layanan) => _layananItem(layanan, isSmall)),
        ],
      ),
    );
  }

  Widget _layananItem(Map<String, dynamic> layanan, bool isSmall) {
    return Container(
      margin: EdgeInsets.only(bottom: isSmall ? 8 : 10),
      padding: EdgeInsets.all(isSmall ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (layanan['nama_layanan'] ?? 'Layanan').toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Jumlah: ${layanan['jumlah'] ?? '-'} kali',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Rp ${_money(layanan['harga_layanan'])}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF1D4ED8),
            ),
          ),
        ],
      ),
    );
  }
}

// ================== SMALL WIDGETS ==================
class _BackButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _BackButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const FaIcon(FontAwesomeIcons.arrowLeft, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF0F172A),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onRefresh;
  final VoidCallback onDownloadPdf;
  final VoidCallback onPrintPdf;
  final bool hasData;
  
  const _QuickActions({
    required this.onRefresh,
    required this.onDownloadPdf,
    required this.onPrintPdf,
    required this.hasData,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: onRefresh,
          icon: const FaIcon(FontAwesomeIcons.rotateRight, size: 16),
          label: const Text('Refresh'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            side: BorderSide(color: Colors.grey.shade300),
            foregroundColor: const Color(0xFF0F172A),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        // ✅ TOMBOL DOWNLOAD PDF - hanya aktif jika ada data
        OutlinedButton.icon(
          onPressed: hasData ? onDownloadPdf : null,
          icon: const FaIcon(FontAwesomeIcons.download, size: 16),
          label: const Text('Download PDF'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            side: BorderSide(
              color: hasData 
                ? Colors.teal.shade600 
                : Colors.grey.shade300,
            ),
            foregroundColor: hasData 
              ? Colors.teal.shade600 
              : Colors.grey.shade400,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 8),
        // ✅ TOMBOL PRINT PDF - hanya aktif jika ada data
        ElevatedButton.icon(
          onPressed: hasData ? onPrintPdf : null,
          icon: const FaIcon(FontAwesomeIcons.print, size: 16),
          label: const Text('Print PDF'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            backgroundColor: hasData 
              ? Colors.teal.shade600 
              : Colors.grey.shade300,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String? status;
  const _StatusPill({this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch ((status ?? '').toLowerCase()) {
      case 'succeed':
      case 'completed':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF065F46);
        break;
      case 'payment':
        bg = const Color(0xFFFFEDD5);
        fg = const Color(0xFF9A3412);
        break;
      default:
        bg = const Color(0xFFE2E8F0);
        fg = const Color(0xFF475569);
    }
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status ?? 'Unknown',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

// ================== EXTENSION KECIL ==================
extension _ColorX on Color {
  Color darken([double amount = .2]) {
    final hsl = HSLColor.fromColor(this);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }
}