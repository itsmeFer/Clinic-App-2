import 'dart:async';
import 'dart:convert';
import 'package:RoyalClinic/pasien/dashboardScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class Pembayaran extends StatefulWidget {
  final int? kunjunganId;
  final bool fromList;

  const Pembayaran({super.key, this.kunjunganId, this.fromList = false});

  @override
  State<Pembayaran> createState() => _PembayaranState();
}

class _PembayaranState extends State<Pembayaran> {
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? pembayaranData;

  // TAMBAHKAN untuk screenshot
  final GlobalKey _screenshotKey = GlobalKey();

  // TAMBAHKAN untuk metode pembayaran dari database
  List<Map<String, dynamic>> metodePembayaran = [];
  bool isLoadingMetode = false;

  @override
  void initState() {
    super.initState();
    fetchPembayaranData();
    fetchMetodePembayaran();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _showPaymentProofDialog(String buktiPembayaran) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.black,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  child: Image.network(
                    'https://admin.royal-klinik.cloud/storage/$buktiPembayaran',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.broken_image,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Gagal memuat gambar',
                              style: TextStyle(
                                color: Colors.grey.shade300,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<int?> getPasienId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('pasien_id');
  }

  Future<bool> _isFromList() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('from_list_payment') ?? widget.fromList;
  }

  // Clear debug preferences jika diperlukan
  Future<void> _clearDebugPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selected_kunjungan_id');
    await prefs.remove('from_list_payment');
    print('🧹 Cleared debug SharedPreferences');
  }

  // Method untuk fetch metode pembayaran dari database
  Future<void> fetchMetodePembayaran() async {
    try {
      setState(() => isLoadingMetode = true);

      final token = await getToken();
      if (token == null) {
        _setDefaultMetodePembayaran();
        return;
      }

      final response = await http.get(
        Uri.parse(
          'https://admin.royal-klinik.cloud/api/pembayaran/get-data-metode-pembayaran',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('📡 fetchMetodePembayaran - Status: ${response.statusCode}');
      print('📄 fetchMetodePembayaran - Body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            metodePembayaran = List<Map<String, dynamic>>.from(data['data']);
            isLoadingMetode = false;
          });
          print(
            '✅ Loaded ${metodePembayaran.length} metode pembayaran from database',
          );
        } else {
          _setDefaultMetodePembayaran();
        }
      } else {
        _setDefaultMetodePembayaran();
      }
    } catch (e) {
      print('❌ fetchMetodePembayaran Error: $e');
      _setDefaultMetodePembayaran();
    }
  }

  void _setDefaultMetodePembayaran() {
    setState(() {
      metodePembayaran = [
        {'id': null, 'nama_metode': 'Tunai / Cash', 'icon': '💰'},
        {'id': null, 'nama_metode': 'Kartu Debit/Kredit', 'icon': '💳'},
        {'id': null, 'nama_metode': 'QRIS (Scan QR)', 'icon': '📱'},
        {'id': null, 'nama_metode': 'Transfer Bank', 'icon': '🏦'},
      ];
      isLoadingMetode = false;
    });
    print('⚠️ Using default metode pembayaran');
  }

  Future<void> fetchPembayaranData() async {
    try {
      final token = await getToken();
      final prefs = await SharedPreferences.getInstance();
      final selectedKunjunganId = prefs.getInt('selected_kunjungan_id');
      final fromListPayment = prefs.getBool('from_list_payment') ?? false;
      final pasienId = await getPasienId();

      // TAMBAHKAN DEBUGGING YANG LEBIH DETAIL
      print('🔍 === DEBUG PEMBAYARAN DATA ===');
      print('🔍 Token: ${token != null ? 'Available' : 'NULL'}');
      print('🔍 selectedKunjunganId: $selectedKunjunganId');
      print('🔍 fromListPayment: $fromListPayment');
      print('🔍 widget.kunjunganId: ${widget.kunjunganId}');
      print('🔍 pasienId: $pasienId');

      if (token == null) {
        print('❌ Token tidak ditemukan');
        setState(() {
          errorMessage = 'Token tidak ditemukan. Silakan login ulang.';
          isLoading = false;
        });
        return;
      }

      String url;
      String debugInfo;

      if (selectedKunjunganId != null && fromListPayment) {
        url =
            'https://admin.royal-klinik.cloud/api/pembayaran/detail/$selectedKunjunganId';
        debugInfo = 'Using selectedKunjunganId from SharedPreferences';
      } else if (widget.kunjunganId != null) {
        url =
            'https://admin.royal-klinik.cloud/api/pembayaran/detail/${widget.kunjunganId}';
        debugInfo = 'Using kunjunganId from constructor';
      } else {
        if (pasienId == null) {
          print('❌ PasienId tidak ditemukan');
          setState(() {
            errorMessage = 'ID pasien tidak ditemukan. Silakan login ulang.';
            isLoading = false;
          });
          return;
        }
        url = 'https://admin.royal-klinik.cloud/api/pembayaran/pasien/$pasienId';
        debugInfo = 'Using pasienId fallback';
      }

      print('🔍 $debugInfo');
      print('🔍 Final URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      if (!mounted) return;

      // Handle HTML response (server error)
      if (response.body.startsWith('<') || response.body.contains('<script>')) {
        print('❌ Server returned HTML instead of JSON');
        setState(() {
          errorMessage = 'Server error. Silakan coba lagi atau hubungi admin.';
          isLoading = false;
        });
        return;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            if (selectedKunjunganId != null && fromListPayment) {
              pembayaranData = Map<String, dynamic>.from(data['data']);
            } else if (widget.kunjunganId != null) {
              pembayaranData = Map<String, dynamic>.from(data['data']);
            } else {
              if (data['data']['payments'] != null &&
                  data['data']['payments'].isNotEmpty) {
                pembayaranData = Map<String, dynamic>.from(
                  data['data']['payments'][0],
                );
              } else {
                pembayaranData = Map<String, dynamic>.from(data['data']);
              }
            }
            isLoading = false;
          });

          print('✅ Data pembayaran berhasil dimuat');
          print('🔍 Total tagihan: ${pembayaranData?['total_tagihan']}');
          print('🔍 Status: ${pembayaranData?['status_pembayaran']}');
          print('🔍 EMR Missing: ${pembayaranData?['is_emr_missing']}');
          print('🔍 Payment Missing: ${pembayaranData?['is_payment_missing']}');
          print('🔍 Kode Transaksi: ${pembayaranData?['kode_transaksi']}');
          print(
            '🔍 Metode Pembayaran Nama: ${pembayaranData?['metode_pembayaran_nama']}',
          );
        } else {
          print('❌ Response success = false or data is null');
          setState(() {
            errorMessage = data['message'] ?? 'Data pembayaran tidak ditemukan';
            isLoading = false;
          });
        }
      } else if (response.statusCode == 404) {
        print('❌ Data tidak ditemukan (404)');
        setState(() {
          errorMessage = 'Data pembayaran tidak ditemukan untuk pasien ini.';
          isLoading = false;
        });
      } else if (response.statusCode == 401) {
        print('❌ Unauthorized (401)');
        setState(() {
          errorMessage = 'Sesi telah berakhir. Silakan login ulang.';
          isLoading = false;
        });
      } else if (response.statusCode == 400) {
        try {
          final data = jsonDecode(response.body);
          if (data['message']?.toString().toLowerCase().contains(
                'sudah selesai',
              ) ==
              true) {
            setState(() {
              pembayaranData = {
                'status_pembayaran': 'Sudah Bayar',
                'kode_transaksi': 'COMPLETED',
                'total_tagihan': 0,
                'pasien': {'nama_pasien': 'Pasien'},
                'poli': {'nama_poli': 'Umum'},
                'tanggal_kunjungan': DateTime.now().toString(),
                'no_antrian': '-',
                'diagnosis': 'Pembayaran sudah selesai',
                'resep': [],
                'layanan': [],
              };
              isLoading = false;
            });
          } else {
            setState(() {
              errorMessage =
                  data['message'] ?? 'Pembayaran tidak dapat diproses';
              isLoading = false;
            });
          }
        } catch (e) {
          setState(() {
            errorMessage = 'Terjadi kesalahan: ${response.statusCode}';
            isLoading = false;
          });
        }
      } else {
        print('❌ Unexpected status code: ${response.statusCode}');
        try {
          final data = jsonDecode(response.body);
          setState(() {
            errorMessage =
                data['message'] ?? 'Terjadi kesalahan: ${response.statusCode}';
            isLoading = false;
          });
        } catch (e) {
          setState(() {
            errorMessage = 'Terjadi kesalahan: ${response.statusCode}';
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('❌ fetchPembayaranData Exception: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Terjadi kesalahan koneksi. Silakan coba lagi.';
          isLoading = false;
        });
      }
    }
  }

  // Method untuk share sebagai gambar
  Future<void> shareAsImage() async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF00897B)),
        ),
      );

      // Capture screenshot
      RenderRepaintBoundary boundary =
          _screenshotKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/pembayaran_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngBytes);

      // Close loading
      Navigator.of(context).pop();

      // Share the image
      await Share.shareXFiles(
        [XFile(file.path)],
        text: _generateShareText(),
        subject: 'Detail Pembayaran - Royal Clinic',
      );
    } catch (e) {
      // Close loading if still open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membagikan gambar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Method untuk share sebagai PDF
  Future<void> shareAsPDF() async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF00897B)),
        ),
      );

      final pdf = pw.Document();

      // Add page to PDF
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return _buildPDFContent();
          },
        ),
      );

      // Save PDF to temporary file
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/pembayaran_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(await pdf.save());

      // Close loading
      Navigator.of(context).pop();

      // Share the PDF
      await Share.shareXFiles(
        [XFile(file.path)],
        text: _generateShareText(),
        subject: 'Detail Pembayaran - Royal Clinic',
      );
    } catch (e) {
      // Close loading if still open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membagikan PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Method untuk share sebagai teks
  Future<void> shareAsText() async {
    try {
      await Share.share(
        _generateShareText(),
        subject: 'Detail Pembayaran - Royal Clinic',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membagikan teks: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Method untuk generate text yang akan di-share
  String _generateShareText() {
    if (pembayaranData == null) return 'Detail Pembayaran - Royal Clinic';

    final namaPasien = pembayaranData!['pasien']?['nama_pasien'] ?? '-';
    final namaPoli = pembayaranData!['poli']?['nama_poli'] ?? '-';
    final tanggalKunjungan = _formatDate(pembayaranData!['tanggal_kunjungan']);
    final noAntrian = pembayaranData!['no_antrian']?.toString() ?? '-';
    final totalTagihan = formatCurrency(
      toDoubleValue(pembayaranData!['total_tagihan']),
    );
    final status = pembayaranData!['status_pembayaran'] ?? 'Belum Bayar';
    final kodeTransaksi = pembayaranData!['kode_transaksi'] ?? '-';
    final metodePembayaran =
        pembayaranData!['metode_pembayaran_nama'] ?? 'Belum dipilih';

    return '''
🏥 ROYAL CLINIC - DETAIL PEMBAYARAN

👤 Pasien: $namaPasien
🏢 Poli: $namaPoli
📅 Tanggal: $tanggalKunjungan
🎫 No. Antrian: $noAntrian

💰 Total Pembayaran: $totalTagihan
📊 Status: $status
🔐 Kode Transaksi: $kodeTransaksi
💳 Metode Pembayaran: $metodePembayaran

Terima kasih telah menggunakan layanan Royal Clinic!
  ''';
  }

  // Method untuk build PDF content
  pw.Widget _buildPDFContent() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(20),
          color: PdfColors.teal,
          child: pw.Column(
            children: [
              pw.Text(
                'ROYAL CLINIC',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                'Detail Pembayaran',
                style: pw.TextStyle(fontSize: 16, color: PdfColors.white),
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 20),

        // Patient Info
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(15),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Informasi Kunjungan',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              _buildPDFInfoRow(
                'Nama Pasien',
                pembayaranData!['pasien']?['nama_pasien'] ?? '-',
              ),
              _buildPDFInfoRow(
                'Poli',
                pembayaranData!['poli']?['nama_poli'] ?? '-',
              ),
              _buildPDFInfoRow(
                'Tanggal',
                _formatDate(pembayaranData!['tanggal_kunjungan']),
              ),
              _buildPDFInfoRow(
                'No. Antrian',
                pembayaranData!['no_antrian']?.toString() ?? '-',
              ),
              if (pembayaranData!['diagnosis'] != null)
                _buildPDFInfoRow('Diagnosis', pembayaranData!['diagnosis']),
            ],
          ),
        ),

        pw.SizedBox(height: 15),

        // Payment Summary
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(15),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Rincian Pembayaran',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),

              // Resep
              if (_hasResep()) ...[
                pw.Text(
                  'Resep Obat:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 5),
                ...((pembayaranData!['resep'] as List?) ?? []).map(
                  (resep) => _buildPDFInfoRow(
                    '  ${resep['obat']?['nama_obat'] ?? 'Obat'}',
                    '${resep['jumlah'] ?? 0}x - ${formatCurrency(toDoubleValue(resep['obat']?['harga_obat']))}',
                  ),
                ),
                pw.SizedBox(height: 10),
              ],

              // Layanan
              if (_hasLayanan()) ...[
                pw.Text(
                  'Layanan Medis:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 5),
                ...((pembayaranData!['layanan'] as List?) ?? []).map(
                  (layanan) => _buildPDFInfoRow(
                    '  ${layanan['nama_layanan'] ?? 'Layanan'}',
                    formatCurrency(toDoubleValue(layanan['harga_layanan'])),
                  ),
                ),
                pw.SizedBox(height: 10),
              ],

              pw.Divider(),
              pw.SizedBox(height: 5),

              // Total
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Total Pembayaran:',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    formatCurrency(
                      toDoubleValue(pembayaranData!['total_tagihan']),
                    ),
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 10),

              // Payment Info
              if (pembayaranData!['metode_pembayaran_nama'] != null) ...[
                pw.Divider(),
                _buildPDFInfoRow(
                  'Metode Pembayaran',
                  pembayaranData!['metode_pembayaran_nama'],
                ),
                if (pembayaranData!['tanggal_pembayaran'] != null)
                  _buildPDFInfoRow(
                    'Tanggal Pembayaran',
                    _formatDateTime(pembayaranData!['tanggal_pembayaran']),
                  ),
                _buildPDFInfoRow(
                  'Status',
                  pembayaranData!['status_pembayaran'] ?? 'Belum Bayar',
                ),
              ],

              if (pembayaranData!['kode_transaksi'] != null)
                _buildPDFInfoRow(
                  'Kode Transaksi',
                  pembayaranData!['kode_transaksi'],
                ),
            ],
          ),
        ),

        pw.Spacer(),

        // Footer
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          child: pw.Text(
            'Terima kasih telah menggunakan layanan Royal Clinic!\nDokumen ini digenerate pada ${DateTime.now().toString()}',
            style: const pw.TextStyle(fontSize: 10),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPDFInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
          ),
          pw.Text(': ', style: const pw.TextStyle(fontSize: 12)),
          pw.Expanded(
            child: pw.Text(value, style: const pw.TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // Method untuk show share options dialog
  void _showShareOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bagikan Detail Pembayaran',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOption(
                  icon: Icons.image,
                  label: 'Gambar',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    shareAsImage();
                  },
                ),
                _buildShareOption(
                  icon: Icons.picture_as_pdf,
                  label: 'PDF',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    shareAsPDF();
                  },
                ),
                _buildShareOption(
                  icon: Icons.text_fields,
                  label: 'Teks',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    shareAsText();
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method untuk konversi nilai ke double
  double toDoubleValue(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.')) ?? 0.0;
    }
    return 0.0;
  }

  String formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  bool get canMakePayment {
    if (pembayaranData == null) return false;
    final isEmrMissing = pembayaranData!['is_emr_missing'] == true;
    final isPaymentMissing = pembayaranData!['is_payment_missing'] == true;

    if (isEmrMissing || isPaymentMissing) return false;

    final status = pembayaranData!['status_pembayaran']
        ?.toString()
        .toLowerCase();
    return status != 'sudah bayar' && status != 'completed';
  }

  bool get isPaid {
    if (pembayaranData == null) return false;
    final status = pembayaranData!['status_pembayaran']
        ?.toString()
        .toLowerCase();
    return status == 'sudah bayar' || status == 'completed';
  }

  bool get isDataIncomplete {
    if (pembayaranData == null) return true;
    final isEmrMissing = pembayaranData!['is_emr_missing'] == true;
    final isPaymentMissing = pembayaranData!['is_payment_missing'] == true;
    return isEmrMissing || isPaymentMissing;
  }

  Future<void> cekStatusPembayaran() async {
    // Refresh data pembayaran
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    await fetchPembayaranData();
  }

  Widget _buildPaymentProofSection() {
    final kodeTransaksi = pembayaranData!['kode_transaksi'];
    final buktiPembayaran = pembayaranData!['bukti_pembayaran'];
    final isPaid =
        pembayaranData!['status_pembayaran']?.toString().toLowerCase() ==
        'sudah bayar';

    if (!isPaid) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
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
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.verified,
                  color: Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Bukti Pembayaran',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // QR Code Section (untuk verifikasi kode transaksi)
          if (kodeTransaksi != null) ...[
            const Text(
              'QR Code Transaksi:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: QrImageView(
                      data: kodeTransaksi,
                      version: QrVersions.auto,
                      size: 120,
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    kodeTransaksi,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontFamily: 'monospace',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Foto Bukti Pembayaran Section (foto yang diupload admin kasir)
          const Text(
            'Foto Bukti Pembayaran:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),

          if (buktiPembayaran != null) ...[
            GestureDetector(
              onTap: () {
                // Tampilkan foto dalam dialog fullscreen
                _showPaymentProofDialog(buktiPembayaran);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  'https://admin.royal-klinik.cloud/storage/$buktiPembayaran',
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Gagal memuat gambar bukti pembayaran',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: double.infinity,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00897B),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap untuk melihat gambar ukuran penuh',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade600,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ] else ...[
            Container(
              width: double.infinity,
              height: 120,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.upload_file,
                    color: Colors.blue.shade600,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bukti pembayaran akan diunggah\noleh admin kasir',
                    style: TextStyle(fontSize: 14, color: Colors.blue.shade700),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard() {
    final metodePembayaranNama = pembayaranData!['metode_pembayaran_nama'];
    final tanggalPembayaran = pembayaranData!['tanggal_pembayaran'];
    final isPaid =
        pembayaranData!['status_pembayaran']?.toString().toLowerCase() ==
        'sudah bayar';

    // Hanya tampilkan jika sudah bayar atau ada metode pembayaran
    if (!isPaid && metodePembayaranNama == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
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
                  color: const Color(0xFF00897B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getPaymentMethodIcon(metodePembayaranNama),
                  color: const Color(0xFF00897B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Metode Pembayaran',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (metodePembayaranNama != null) ...[
            _buildInfoRow('Metode', metodePembayaranNama),
          ] else ...[
            _buildInfoRow('Metode', 'Belum dipilih'),
          ],

          if (tanggalPembayaran != null) ...[
            _buildInfoRow(
              'Tanggal Pembayaran',
              _formatDateTime(tanggalPembayaran),
            ),
          ],

          if (!isPaid && metodePembayaranNama == null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade600, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Metode pembayaran akan dipilih oleh kasir',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
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

  // Helper method untuk mendapatkan icon berdasarkan metode pembayaran
  IconData _getPaymentMethodIcon(String? metodeName) {
    if (metodeName == null) return Icons.payment;

    final lowerMethod = metodeName.toLowerCase();

    if (lowerMethod.contains('cash') || lowerMethod.contains('tunai')) {
      return Icons.money;
    } else if (lowerMethod.contains('kartu') ||
        lowerMethod.contains('debit') ||
        lowerMethod.contains('kredit')) {
      return Icons.credit_card;
    } else if (lowerMethod.contains('qris') || lowerMethod.contains('qr')) {
      return Icons.qr_code;
    } else if (lowerMethod.contains('transfer') ||
        lowerMethod.contains('bank')) {
      return Icons.account_balance;
    } else if (lowerMethod.contains('wallet') ||
        lowerMethod.contains('digital')) {
      return Icons.account_balance_wallet;
    } else if (lowerMethod.contains('ovo') ||
        lowerMethod.contains('dana') ||
        lowerMethod.contains('gopay')) {
      return Icons.phone_android;
    }

    return Icons.payment;
  }

  // Helper method untuk format tanggal dan waktu
  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return '-';
    try {
      final DateTime parsedDate = DateTime.parse(dateTime.toString());
      return '${parsedDate.day}/${parsedDate.month}/${parsedDate.year} ${parsedDate.hour.toString().padLeft(2, '0')}:${parsedDate.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTime.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pembayaran'),
          backgroundColor: const Color(0xFF00897B),
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF00897B)),
              SizedBox(height: 16),
              Text('Memuat data pembayaran...'),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pembayaran'),
          backgroundColor: const Color(0xFF00897B),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  'Terjadi Kesalahan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          isLoading = true;
                          errorMessage = null;
                        });
                        fetchPembayaranData();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Lagi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00897B),
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Kembali'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (pembayaranData == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pembayaran'),
          backgroundColor: const Color(0xFF00897B),
          foregroundColor: Colors.white,
        ),
        body: const Center(child: Text('Data pembayaran tidak tersedia')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Detail Pembayaran'),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // TAMBAHKAN tombol share
          if (pembayaranData != null && !isDataIncomplete)
            IconButton(
              onPressed: _showShareOptions,
              icon: const Icon(Icons.share),
              tooltip: 'Bagikan',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Pembayaran
                  _buildStatusCard(),
                  const SizedBox(height: 16),

                  // Informasi Pasien & Kunjungan
                  _buildPatientInfoCard(),
                  const SizedBox(height: 16),

                  // TAMBAHKAN: Bukti Pembayaran Section (hanya tampil jika sudah bayar)
                  _buildPaymentProofSection(),
                  if (isPaid) const SizedBox(height: 16),

                  // Resep (jika ada dan data lengkap)
                  if (_hasResep() && !isDataIncomplete) _buildResepCard(),

                  // Layanan (jika ada dan data lengkap)
                  if (_hasLayanan() && !isDataIncomplete) _buildLayananCard(),

                  if (!isDataIncomplete) const SizedBox(height: 16),

                  // Rincian Pembayaran (hanya jika data lengkap)
                  if (!isDataIncomplete) _buildPaymentSummaryCard(),

                  const SizedBox(height: 100), // Space for bottom button
                ],
              ),
            ),
          ),

          // Bottom Payment Actions
          if (!isPaid) _buildBottomPaymentButton() else _buildAlreadyPaidInfo(),
        ],
      ),
    );
  }

  bool _hasResep() {
    final resep = pembayaranData?['resep'];
    return resep != null && resep is List && resep.isNotEmpty;
  }

  bool _hasLayanan() {
    final layanan = pembayaranData?['layanan'];
    return layanan != null && layanan is List && layanan.isNotEmpty;
  }

  Widget _buildStatusCard() {
    final status = pembayaranData!['status_pembayaran'] ?? 'Belum Bayar';
    final isEmrMissing = pembayaranData!['is_emr_missing'] == true;
    final isPaymentMissing = pembayaranData!['is_payment_missing'] == true;

    final isPaidStatus =
        status.toString().toLowerCase() == 'sudah bayar' ||
        status.toString().toLowerCase() == 'completed';

    Color cardColor;
    Color iconColor;
    Color textColor;
    IconData icon;
    String statusText;
    String? subtitleText;

    if (isEmrMissing) {
      cardColor = Colors.blue.shade50;
      iconColor = Colors.blue.shade600;
      textColor = Colors.blue.shade700;
      icon = Icons.medical_services;
      statusText = 'Menunggu Pemeriksaan Dokter';
      subtitleText = 'Silakan tunggu hingga pemeriksaan selesai';
    } else if (isPaymentMissing) {
      cardColor = Colors.amber.shade50;
      iconColor = Colors.amber.shade600;
      textColor = Colors.amber.shade700;
      icon = Icons.hourglass_empty;
      statusText = 'Sedang Diproses';
      subtitleText = 'Perhitungan biaya sedang diproses';
    } else if (isPaidStatus) {
      cardColor = Colors.green.shade50;
      iconColor = Colors.green.shade600;
      textColor = Colors.green.shade700;
      icon = Icons.check_circle;
      statusText = 'Pembayaran Selesai';
    } else {
      cardColor = Colors.orange.shade50;
      iconColor = Colors.orange.shade600;
      textColor = Colors.orange.shade700;
      icon = Icons.schedule;
      statusText = 'Menunggu Pembayaran';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(height: 8),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),

          // HAPUS BAGIAN QR CODE KECIL DI STATUS CARD
          // QR code hanya akan muncul di section bukti pembayaran saja
          if (pembayaranData!['kode_transaksi'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Kode: ${pembayaranData!['kode_transaksi']}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          if (subtitleText != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitleText,
              style: TextStyle(
                fontSize: 12,
                color: textColor.withOpacity(0.8),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPatientInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
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
                  color: const Color(0xFF00897B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person,
                  color: Color(0xFF00897B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Informasi Kunjungan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildInfoRow(
            'Nama Pasien',
            pembayaranData!['pasien']?['nama_pasien'] ?? '-',
          ),
          _buildInfoRow('Poli', pembayaranData!['poli']?['nama_poli'] ?? '-'),
          _buildInfoRow(
            'Tanggal',
            _formatDate(pembayaranData!['tanggal_kunjungan']),
          ),
          _buildInfoRow(
            'No. Antrian',
            pembayaranData!['no_antrian']?.toString() ?? '-',
          ),

          if (pembayaranData!['diagnosis'] != null)
            _buildInfoRow('Diagnosis', pembayaranData!['diagnosis']),
        ],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return '-';
    try {
      final DateTime parsedDate = DateTime.parse(date.toString());
      return '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}';
    } catch (e) {
      return date.toString();
    }
  }

  Widget _buildResepCard() {
    final resepList = pembayaranData!['resep'] as List? ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
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
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.medication,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Resep Obat',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ...resepList
              .map(
                (resep) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          resep['obat']?['nama_obat'] ?? 'Obat',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Text(
                        '${resep['jumlah'] ?? 0}x',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatCurrency(
                          toDoubleValue(resep['obat']?['harga_obat']),
                        ),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }

  Widget _buildLayananCard() {
    final layananList = pembayaranData!['layanan'] as List? ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
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
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.medical_services,
                  color: Colors.purple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Layanan Medis',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ...layananList
              .map(
                (layanan) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          layanan['nama_layanan'] ?? 'Layanan',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Text(
                        formatCurrency(toDoubleValue(layanan['harga_layanan'])),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ],
      ),
    );
  }

  Widget _buildPaymentSummaryCard() {
    final totalTagihan = toDoubleValue(pembayaranData!['total_tagihan']);
    final resepList = pembayaranData!['resep'] as List? ?? [];
    final layananList = pembayaranData!['layanan'] as List? ?? [];
    final metodePembayaran = pembayaranData!['metode_pembayaran_nama'];
    final tanggalPembayaran = pembayaranData!['tanggal_pembayaran'];
    final isPaid =
        pembayaranData!['status_pembayaran']?.toString().toLowerCase() ==
        'sudah bayar';

    double totalObat = 0;
    double totalLayanan = 0;

    // Calculate total obat
    for (var resep in resepList) {
      final harga = toDoubleValue(resep['obat']?['harga_obat']);
      final jumlah = toDoubleValue(resep['jumlah']);
      totalObat += (harga * jumlah);
    }

    // Calculate total layanan
    for (var layanan in layananList) {
      totalLayanan += toDoubleValue(layanan['harga_layanan']);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
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
                  color: const Color(0xFF00897B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt,
                  color: Color(0xFF00897B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Rincian Pembayaran',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Rincian biaya
          if (totalLayanan > 0)
            _buildSummaryRow('Total Layanan', formatCurrency(totalLayanan)),

          if (totalObat > 0)
            _buildSummaryRow('Total Obat', formatCurrency(totalObat)),

          if (totalLayanan > 0 || totalObat > 0) const Divider(height: 24),

          _buildSummaryRow(
            'Total Pembayaran',
            formatCurrency(totalTagihan),
            isTotal: true,
          ),

          // TAMBAHKAN: Informasi metode pembayaran
          if (metodePembayaran != null || isPaid) ...[
            const Divider(height: 20),
            const SizedBox(height: 8),

            // Header metode pembayaran
            Text(
              'Informasi Pembayaran:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),

            // Metode pembayaran
            Row(
              children: [
                Icon(
                  _getPaymentMethodIcon(metodePembayaran),
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  'Metode:',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    metodePembayaran ?? 'Belum dipilih',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: metodePembayaran != null
                          ? Colors.black87
                          : Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),

            // Tanggal pembayaran (jika sudah bayar)
            if (tanggalPembayaran != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.schedule, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    'Dibayar:',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatDateTime(tanggalPembayaran),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ],

            // Status pembayaran
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  isPaid ? Icons.check_circle : Icons.schedule,
                  size: 16,
                  color: isPaid
                      ? Colors.green.shade600
                      : Colors.orange.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  'Status:',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isPaid ? 'Lunas' : 'Belum Bayar',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isPaid
                          ? Colors.green.shade600
                          : Colors.orange.shade600,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],

          // Pesan untuk yang belum bayar dan belum ada metode
          if (!isPaid && metodePembayaran == null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade600, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Metode pembayaran akan dipilih oleh kasir saat pembayaran',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
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

  Widget _buildBottomPaymentButton() {
    if (pembayaranData == null) return const SizedBox.shrink();

    final isEmrMissing = pembayaranData!['is_emr_missing'] == true;
    final isPaymentMissing = pembayaranData!['is_payment_missing'] == true;

    // ✅ Jika EMR atau payment missing, tampilkan info saja
    if (isEmrMissing || isPaymentMissing) {
      Color bgColor = isEmrMissing ? Colors.blue.shade50 : Colors.amber.shade50;
      Color borderColor = isEmrMissing
          ? Colors.blue.shade200
          : Colors.amber.shade200;
      Color iconColor = isEmrMissing
          ? Colors.blue.shade600
          : Colors.amber.shade600;
      Color textColor = isEmrMissing
          ? Colors.blue.shade700
          : Colors.amber.shade700;
      String message = isEmrMissing
          ? 'Pembayaran akan tersedia setelah pemeriksaan selesai.'
          : 'Perhitungan biaya sedang diproses oleh admin.';

      return Container(
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.info, color: iconColor, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final totalTagihan = toDoubleValue(pembayaranData!['total_tagihan']);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Pembayaran:',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  Text(
                    formatCurrency(totalTagihan),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00897B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.schedule, size: 20),
                        label: const Text(
                          'Bayar Nanti',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Cek Status Pembayaran button
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: canMakePayment ? cekStatusPembayaran : null,
                        icon: const Icon(Icons.refresh, size: 20),
                        label: const Text(
                          'Cek Status Pembayaran',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00897B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: Colors.grey.shade300,
                          elevation: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlreadyPaidInfo() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border(top: BorderSide(color: Colors.green.shade200)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pembayaran selesai. Silakan ambil obat di apoteker.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
          const Text(': ', style: TextStyle(fontSize: 12)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w600 : FontWeight.normal,
              color: isTotal ? Colors.black87 : Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: FontWeight.w600,
              color: isTotal ? const Color(0xFF00897B) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
