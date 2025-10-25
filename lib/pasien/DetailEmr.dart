import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:file_saver/file_saver.dart';
import 'package:permission_handler/permission_handler.dart';

class DetailEmr extends StatefulWidget {
  final Map<String, dynamic> kunjungan;
  final Map<String, dynamic>? pasienInfo;

  const DetailEmr({Key? key, required this.kunjungan, this.pasienInfo})
      : super(key: key);

  @override
  State<DetailEmr> createState() => _DetailEmrState();
}

class _DetailEmrState extends State<DetailEmr> {
  bool isLoading = false;

  // =========================
  // ===== PDF GENERATOR =====
  // =========================
  Future<Uint8List> _buildEmrPdf(Map<String, dynamic> kunjungan) async {
    final emr = kunjungan['emr'] ?? {};
    final dokter = kunjungan['dokter'] ?? {};
    final pasien = widget.pasienInfo ?? {};
    final layanan = (kunjungan['layanan'] ?? []) as List;

    final doc = pw.Document();

    String rowText(String label, String? value) =>
        '$label: ${value == null || value.isEmpty ? "-" : value}';

    // hitung biaya layanan & total obat untuk ditampilkan di PDF juga
    final layananTotal = layanan.fold<double>(0, (sum, it) {
      final sub = (it['subtotal'] ?? 0).toString();
      return sum + (double.tryParse(sub) ?? 0);
    });
    final resepList = (kunjungan['resep_obat'] ?? []) as List;
    final totalObat = resepList.fold<double>(0, (sum, it) {
      final sub = (it['subtotal'] ?? 0).toString();
      return sum + (double.tryParse(sub) ?? 0);
    });

    final pembayaran = kunjungan['pembayaran'] ?? {};
    final totalTagihan =
        (pembayaran['total_tagihan'] ??
                (pembayaran['biaya_konsultasi'] ?? layananTotal) + totalObat)
            .toString();

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(24),
          theme: pw.ThemeData.withFont(
            base: await PdfGoogleFonts.nunitoRegular(),
            bold: await PdfGoogleFonts.nunitoBold(),
          ),
        ),
        build: (context) => [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Royal Clinic',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    'Electronic Medical Record',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data:
                    'EMR-${kunjungan['id'] ?? ''}-${kunjungan['tanggal_kunjungan'] ?? ''}',
                width: 60,
                height: 60,
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Divider(),

          // Pasien
          pw.Text(
            'Data Pasien',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(rowText('Nama', pasien['nama_pasien']?.toString())),
          pw.Text(
            rowText('Jenis Kelamin', pasien['jenis_kelamin']?.toString()),
          ),
          pw.Text(
            rowText('Tanggal Lahir', pasien['tanggal_lahir']?.toString()),
          ),
          if ((pasien['alamat'] ?? '').toString().isNotEmpty)
            pw.Text(rowText('Alamat', pasien['alamat'].toString())),
          pw.SizedBox(height: 10),

          // Kunjungan
          pw.Text(
            'Informasi Kunjungan',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            rowText(
              'Tanggal',
              (kunjungan['tanggal_kunjungan'] ?? '').toString(),
            ),
          ),
          pw.Text(
            rowText('No. Antrian', (kunjungan['no_antrian'] ?? '').toString()),
          ),
          pw.Text(
            rowText('Status Kunjungan', (kunjungan['status'] ?? '').toString()),
          ),
          pw.Text(
            rowText(
              'Keluhan Awal',
              (kunjungan['keluhan_awal'] ?? '').toString(),
            ),
          ),
          pw.SizedBox(height: 10),

          // Dokter
          pw.Text(
            'Informasi Dokter',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(rowText('Nama', dokter['nama_dokter']?.toString())),
          pw.Text(rowText('Spesialisasi', dokter['spesialisasi']?.toString())),
          if ((dokter['no_hp'] ?? '').toString().isNotEmpty)
            pw.Text(rowText('No. HP', dokter['no_hp']?.toString())),
          pw.SizedBox(height: 10),

          // EMR
          pw.Text(
            'EMR',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          if ((emr['keluhan_utama'] ?? '').toString().isNotEmpty)
            pw.Text(rowText('Keluhan Utama', emr['keluhan_utama'].toString())),
          if ((emr['diagnosis'] ?? '').toString().isNotEmpty)
            pw.Text(rowText('Diagnosis', emr['diagnosis'].toString())),
          if ((emr['riwayat_penyakit_sekarang'] ?? '').toString().isNotEmpty)
            pw.Text(
              rowText(
                'Riwayat Penyakit Sekarang',
                emr['riwayat_penyakit_sekarang'].toString(),
              ),
            ),
          if ((emr['riwayat_penyakit_dahulu'] ?? '').toString().isNotEmpty)
            pw.Text(
              rowText(
                'Riwayat Penyakit Dahulu',
                emr['riwayat_penyakit_dahulu'].toString(),
              ),
            ),
          if ((emr['riwayat_penyakit_keluarga'] ?? '').toString().isNotEmpty)
            pw.Text(
              rowText(
                'Riwayat Penyakit Keluarga',
                emr['riwayat_penyakit_keluarga'].toString(),
              ),
            ),
          if ((emr['tanggal_pemeriksaan'] ?? '').toString().isNotEmpty)
            pw.Text(
              rowText(
                'Tanggal Pemeriksaan',
                emr['tanggal_pemeriksaan'].toString(),
              ),
            ),

          // Tanda vital
          if (emr['tanda_vital'] != null) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              'Tanda Vital',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            ...[
              'tekanan_darah',
              'suhu_tubuh',
              'nadi',
              'pernapasan',
              'saturasi_oksigen',
            ]
                .where((k) => emr['tanda_vital'][k] != null)
                .map(
                  (k) => pw.Text(
                    rowText(
                      k.replaceAll('_', ' ').toUpperCase(),
                      emr['tanda_vital'][k].toString(),
                    ),
                  ),
                ),
          ],

          // Layanan
          if (layanan.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              'Layanan',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Table.fromTextArray(
              headers: ['Layanan', 'Harga', 'Jumlah', 'Subtotal'],
              data: layanan.map((l) {
                return [
                  (l['nama_layanan'] ?? '-').toString(),
                  (l['harga_layanan'] ?? 0).toString(),
                  (l['jumlah'] ?? 1).toString(),
                  (l['subtotal'] ?? 0).toString(),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(top: 6),
                child: pw.Text('Total Layanan: $layananTotal'),
              ),
            ),
          ],

          // Resep
          if (resepList.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              'Resep Obat',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Table.fromTextArray(
              headers: ['Obat', 'Dosis', 'Jumlah', 'Subtotal'],
              data: resepList
                  .map(
                    (r) => [
                      (r['nama_obat'] ?? '-').toString(),
                      (r['dosis'] ?? '-').toString(),
                      (r['jumlah'] ?? '-').toString(),
                      (r['subtotal'] ?? '-').toString(),
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Padding(
                padding: const pw.EdgeInsets.only(top: 6),
                child: pw.Text('Total Obat: $totalObat'),
              ),
            ),
          ],

          // Pembayaran
          if (pembayaran.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              'Ringkasan Pembayaran',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              rowText(
                'Biaya Konsultasi',
                (pembayaran['biaya_konsultasi'] ?? layananTotal).toString(),
              ),
            ),
            pw.Text(rowText('Total Obat', totalObat.toString())),
            pw.Text(rowText('Total Tagihan', totalTagihan)),
            if ((pembayaran['kode_transaksi'] ?? '').toString().isNotEmpty)
              pw.Text(
                rowText(
                  'Kode Transaksi',
                  pembayaran['kode_transaksi'].toString(),
                ),
              ),
            if ((pembayaran['metode_pembayaran'] ?? '').toString().isNotEmpty)
              pw.Text(
                rowText('Metode', pembayaran['metode_pembayaran'].toString()),
              ),
            if ((pembayaran['tanggal_pembayaran'] ?? '').toString().isNotEmpty)
              pw.Text(
                rowText(
                  'Tanggal Pembayaran',
                  pembayaran['tanggal_pembayaran'].toString(),
                ),
              ),
            if (pembayaran['uang_yang_diterima'] != null)
              pw.Text(
                rowText(
                  'Uang Diterima',
                  pembayaran['uang_yang_diterima'].toString(),
                ),
              ),
            if (pembayaran['kembalian'] != null)
              pw.Text(rowText('Kembalian', pembayaran['kembalian'].toString())),
            if ((pembayaran['status'] ?? '').toString().isNotEmpty)
              pw.Text(rowText('Status', pembayaran['status'].toString())),
          ],

          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Dicetak pada ${DateTime.now()}'),
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<File> _saveTempPdf(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _saveWithPicker({
    required Uint8List bytes,
    required String fileName,
    required MimeType mime,
    required String ext,
  }) async {
    try {
      if (Platform.isAndroid) {
        await Permission.storage.request();
      }

      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
        mimeType: mime,
        ext: ext,
      );

      _showSuccessSnackBar('Tersimpan: $fileName');
    } catch (e) {
      try {
        if (ext == 'pdf') {
          await Printing.sharePdf(bytes: bytes, filename: fileName);
        } else {
          final tmp = await _saveTempPdf(bytes, fileName);
          await Share.shareXFiles([XFile(tmp.path, mimeType: 'image/png')]);
        }
        _showSuccessSnackBar('Gunakan menu "Simpan" pada aplikasi tujuan.');
      } catch (e2) {
        _showErrorSnackBar('Gagal menyimpan: $e2');
      }
    }
  }

  Future<Uint8List> _buildEmrPng(
    Map<String, dynamic> kunjungan, {
    double dpi = 200,
  }) async {
    final pdfBytes = await _buildEmrPdf(kunjungan);
    final raster = await Printing.raster(pdfBytes, pages: [0], dpi: dpi).first;
    return await raster.toPng();
  }

  Future<void> _printEmr() async {
    setState(() => isLoading = true);
    try {
      final bytes = await _buildEmrPdf(widget.kunjungan);
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      _showErrorSnackBar('Gagal mencetak: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _shareEmr() async {
    setState(() => isLoading = true);
    try {
      final bytes = await _buildEmrPdf(widget.kunjungan);
      final fileName =
          'EMR-${widget.kunjungan['id'] ?? DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = await _saveTempPdf(bytes, fileName);
      await Share.shareXFiles([
        XFile(file.path, mimeType: 'application/pdf'),
      ], text: 'EMR kunjungan Anda');
    } catch (e) {
      _showErrorSnackBar('Gagal membagikan: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _showActionMenu() async {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Aksi EMR',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              // Print
              ListTile(
                leading: const Icon(Icons.print, color: Color(0xFF00897B)),
                title: const Text('Cetak EMR'),
                subtitle: const Text('Cetak dokumen EMR'),
                onTap: () {
                  Navigator.pop(ctx);
                  _printEmr();
                },
              ),

              // Share
              ListTile(
                leading: const Icon(Icons.share, color: Color(0xFF00897B)),
                title: const Text('Bagikan EMR'),
                subtitle: const Text('Bagikan file EMR'),
                onTap: () {
                  Navigator.pop(ctx);
                  _shareEmr();
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _downloadEmrChooser() async {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Simpan EMR sebagai',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),

              // PDF
              ListTile(
                leading: const Icon(Icons.picture_as_pdf),
                title: const Text('PDF (direkomendasikan)'),
                subtitle: const Text('Rapi untuk cetak & arsip'),
                onTap: () async {
                  Navigator.pop(ctx);
                  setState(() => isLoading = true);
                  try {
                    final bytes = await _buildEmrPdf(widget.kunjungan);
                    final name =
                        'EMR-${widget.kunjungan['id'] ?? DateTime.now().millisecondsSinceEpoch}.pdf';
                    await _saveWithPicker(
                      bytes: bytes,
                      fileName: name,
                      mime: MimeType.pdf,
                      ext: 'pdf',
                    );
                  } catch (e) {
                    _showErrorSnackBar('Gagal simpan PDF: $e');
                  } finally {
                    setState(() => isLoading = false);
                  }
                },
              ),

              // PNG
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Gambar PNG'),
                subtitle: const Text('Mudah dibagikan ke chat'),
                onTap: () async {
                  Navigator.pop(ctx);
                  setState(() => isLoading = true);
                  try {
                    final png = await _buildEmrPng(widget.kunjungan, dpi: 200);
                    final name =
                        'EMR-${widget.kunjungan['id'] ?? DateTime.now().millisecondsSinceEpoch}.png';
                    await _saveWithPicker(
                      bytes: png,
                      fileName: name,
                      mime: MimeType.png,
                      ext: 'png',
                    );
                  } catch (e) {
                    _showErrorSnackBar('Gagal simpan gambar: $e');
                  } finally {
                    setState(() => isLoading = false);
                  }
                },
              ),

              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // =========================
  // ====== FORMATTERS =======
  // =========================
  String formatDate(String dateString) {
    try {
      if (dateString.isEmpty) return '-';

      // Parse sebagai UTC lalu convert ke local
      final date = DateTime.parse(dateString).toLocal();

      final months = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Ags',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      return '${date.day} ${months[date.month]} ${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String formatCurrency(dynamic amount) {
    if (amount == null) return 'Rp 0';
    try {
      final number = amount is String
          ? double.parse(amount)
          : (amount as num).toDouble();
      return 'Rp ${number.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
    } catch (e) {
      return 'Rp 0';
    }
  }

  String calculateAge(String? tanggalLahir) {
    if (tanggalLahir == null || tanggalLahir.isEmpty) return '-';
    try {
      final birthDate = DateTime.parse(tanggalLahir);
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return '$age tahun';
    } catch (e) {
      return '-';
    }
  }

  // =========================
  // ======== UI BUILD =======
  // =========================
  @override
  Widget build(BuildContext context) {
    final emr = widget.kunjungan['emr'] ?? {};
    final dokter = widget.kunjungan['dokter'] ?? {};
    final pasien = widget.pasienInfo ?? {};
    final vitalSigns = emr['tanda_vital'];
    final prescriptions = (widget.kunjungan['resep_obat'] ?? []) as List;
    final services = (widget.kunjungan['layanan'] ?? []) as List;
    final payment = widget.kunjungan['pembayaran'];

    // Hitung total layanan sebagai fallback jika payment['biaya_konsultasi'] null
    final layananTotal = services.fold<double>(0, (sum, it) {
      final sub = (it['subtotal'] ?? 0).toString();
      return sum + (double.tryParse(sub) ?? 0);
    });
    final totalObat = prescriptions.fold<double>(0, (sum, it) {
      final sub = (it['subtotal'] ?? 0).toString();
      return sum + (double.tryParse(sub) ?? 0);
    });

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Detail EMR',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Pasien
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF00897B),
                        const Color(0xFF00897B).withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00897B).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.medical_information,
                            color: Colors.white,
                            size: 24,
                          ),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Electronic Medical Record',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        pasien['nama_pasien'] ?? 'Nama tidak tersedia',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tanggal Kunjungan: ${formatDate(widget.kunjungan['tanggal_kunjungan'] ?? '')}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Informasi Kunjungan (lengkap)
                _buildSection(
                  'Informasi Kunjungan',
                  Icons.info_outline,
                  Colors.blue,
                  [
                    _buildDetailRow(
                      Icons.confirmation_number,
                      'No. Antrian',
                      widget.kunjungan['no_antrian']?.toString() ?? '-',
                    ),
                    _buildDetailRow(
                      Icons.calendar_today,
                      'Tanggal',
                      formatDate(widget.kunjungan['tanggal_kunjungan'] ?? ''),
                    ),
                    _buildDetailRow(
                      Icons.verified,
                      'Status Kunjungan',
                      widget.kunjungan['status']?.toString() ?? '-',
                    ),
                    _buildDetailRow(
                      Icons.medical_services,
                      'Keluhan Awal',
                      widget.kunjungan['keluhan_awal']?.toString() ?? '-',
                      isMultiline: true,
                    ),
                    if ((emr['tanggal_pemeriksaan'] ?? '')
                        .toString()
                        .isNotEmpty)
                      _buildDetailRow(
                        Icons.event_available,
                        'Tanggal Pemeriksaan EMR',
                        formatDate(emr['tanggal_pemeriksaan'].toString()),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // Informasi Dokter
                _buildSection('Informasi Dokter', Icons.person, Colors.green, [
                  _buildDetailRow(
                    Icons.person,
                    'Nama Dokter',
                    dokter['nama_dokter']?.toString() ?? '-',
                  ),
                  _buildDetailRow(
                    Icons.local_hospital,
                    'Spesialisasi / Poli',
                    dokter['spesialisasi']?.toString() ?? 'Umum',
                  ),
                  if ((dokter['no_hp'] ?? '').toString().isNotEmpty)
                    _buildDetailRow(
                      Icons.phone,
                      'No. HP',
                      dokter['no_hp'].toString(),
                    ),
                  if ((dokter['pengalaman'] ?? '').toString().isNotEmpty)
                    _buildDetailRow(
                      Icons.work_outline,
                      'Pengalaman',
                      dokter['pengalaman'].toString(),
                    ),
                ]),

                const SizedBox(height: 16),

                // EMR
                _buildSection(
                  'Rekam Medis Elektronik',
                  Icons.medical_information,
                  const Color(0xFF00897B),
                  [
                    if ((emr['keluhan_utama'] ?? '').toString().isNotEmpty)
                      _buildDetailRow(
                        Icons.sick,
                        'Keluhan Utama',
                        emr['keluhan_utama'].toString(),
                        isMultiline: true,
                      ),
                    if ((emr['diagnosis'] ?? '').toString().isNotEmpty)
                      _buildDetailRow(
                        Icons.medical_services,
                        'Diagnosis',
                        emr['diagnosis'].toString(),
                        isMultiline: true,
                      ),
                    if ((emr['riwayat_penyakit_sekarang'] ?? '')
                        .toString()
                        .isNotEmpty)
                      _buildDetailRow(
                        Icons.timeline,
                        'Riwayat Penyakit Sekarang',
                        emr['riwayat_penyakit_sekarang'].toString(),
                        isMultiline: true,
                      ),
                    if ((emr['riwayat_penyakit_dahulu'] ?? '')
                        .toString()
                        .isNotEmpty)
                      _buildDetailRow(
                        Icons.history,
                        'Riwayat Penyakit Dahulu',
                        emr['riwayat_penyakit_dahulu'].toString(),
                        isMultiline: true,
                      ),
                    if ((emr['riwayat_penyakit_keluarga'] ?? '')
                        .toString()
                        .isNotEmpty)
                      _buildDetailRow(
                        Icons.family_restroom,
                        'Riwayat Penyakit Keluarga',
                        emr['riwayat_penyakit_keluarga'].toString(),
                        isMultiline: true,
                      ),
                  ],
                ),

                // Tanda Vital
                if (vitalSigns != null) ...[
                  const SizedBox(height: 16),
                  _buildVitalSignsSection(vitalSigns),
                ],

                // Layanan (BARU)
                if (services.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildServicesSection(services, layananTotal),
                ],

                // Resep
                if (prescriptions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildPrescriptionSection(prescriptions),
                ],

                // Ringkasan Biaya (gabungan layanan + obat)
                if (services.isNotEmpty || prescriptions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildCostSummarySection(
                    layananTotal: layananTotal,
                    totalObat: totalObat,
                    totalTagihan:
                        (payment != null && payment['total_tagihan'] != null)
                            ? double.tryParse(
                                    payment['total_tagihan'].toString(),
                                  ) ??
                                (layananTotal + totalObat)
                            : (layananTotal + totalObat),
                  ),
                ],

                // Pembayaran
                if (payment != null) ...[
                  const SizedBox(height: 16),
                  _buildPaymentSection(payment),
                ],

                const SizedBox(height: 120),
              ],
            ),
          ),

          // Loading Overlay
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF00897B)),
                        SizedBox(height: 16),
                        Text('Memproses...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: MediaQuery.of(context).size.width > 600
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.extended(
                  onPressed: _printEmr,
                  heroTag: "print",
                  icon: const Icon(Icons.print),
                  label: const Text('Cetak'),
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF00897B),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.extended(
                  onPressed: _shareEmr,
                  heroTag: "share",
                  icon: const Icon(Icons.share),
                  label: const Text('Bagikan'),
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF00897B),
                ),
              ],
            )
          : FloatingActionButton(
              onPressed: _showActionMenu,
              backgroundColor: const Color(0xFF00897B),
              foregroundColor: Colors.white,
              child: const Icon(Icons.more_vert),
            ),
    );
  }

  // ===== Reusable sections =====

  Widget _buildSection(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value, {
    bool isMultiline = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF00897B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                  maxLines: isMultiline ? null : 3,
                  overflow: isMultiline ? null : TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalSignsSection(Map<String, dynamic> vitalSigns) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.favorite, size: 20, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  'Tanda Vital',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = constraints.maxWidth;
                final crossAxisCount = screenWidth > 500 ? 3 : 2;
                final childAspectRatio = screenWidth > 500 ? 2.0 : 2.2;

                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: childAspectRatio,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    if (vitalSigns['tekanan_darah'] != null)
                      _buildVitalCard(
                        Icons.bloodtype,
                        'Tekanan Darah',
                        '${vitalSigns['tekanan_darah']} mmHg',
                      ),
                    if (vitalSigns['suhu_tubuh'] != null)
                      _buildVitalCard(
                        Icons.thermostat,
                        'Suhu Tubuh',
                        '${vitalSigns['suhu_tubuh']}°C',
                      ),
                    if (vitalSigns['nadi'] != null)
                      _buildVitalCard(
                        Icons.monitor_heart,
                        'Nadi',
                        '${vitalSigns['nadi']} bpm',
                      ),
                    if (vitalSigns['pernapasan'] != null)
                      _buildVitalCard(
                        Icons.air,
                        'Pernapasan',
                        '${vitalSigns['pernapasan']}/min',
                      ),
                    if (vitalSigns['saturasi_oksigen'] != null)
                      _buildVitalCard(
                        Icons.water_drop,
                        'Saturasi O2',
                        '${vitalSigns['saturasi_oksigen']}%',
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.red.shade700),
          const SizedBox(height: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: Colors.red.shade700,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                color: Colors.red.shade800,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ====== LAYANAN (BARU) ======
  Widget _buildServicesSection(List<dynamic> services, double layananTotal) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.teal.shade100,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.medical_services_outlined,
                  size: 20,
                  color: Colors.teal.shade700,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Layanan (${services.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.teal.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...services.asMap().entries.map((entry) {
                  final i = entry.key;
                  final l = entry.value as Map<String, dynamic>;
                  final nama = (l['nama_layanan'] ?? 'Layanan').toString();
                  final harga = l['harga_layanan'];
                  final jumlah = l['jumlah'] ?? 1;
                  final subtotal = l['subtotal'] ?? (0);

                  return Container(
                    margin: EdgeInsets.only(
                      bottom: i < services.length - 1 ? 12 : 0,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nama,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildPrescriptionDetail(
                                'Harga',
                                formatCurrency(harga),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildPrescriptionDetail(
                                'Jumlah',
                                jumlah.toString(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildPrescriptionDetail(
                                'Subtotal',
                                formatCurrency(subtotal),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Total Layanan: ${formatCurrency(layananTotal)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ====== RESEP ======
  Widget _buildPrescriptionSection(List<dynamic> prescriptions) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.shade100,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.medication, size: 20, color: Colors.purple.shade700),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Resep Obat (${prescriptions.length})',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.purple.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: prescriptions.asMap().entries.map<Widget>((entry) {
                final index = entry.key;
                final prescription = entry.value as Map<String, dynamic>;
                return Container(
                  margin: EdgeInsets.only(
                    bottom: index < prescriptions.length - 1 ? 12 : 0,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (prescription['nama_obat'] ??
                                      'Obat tidak dikenal')
                                  .toString(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: prescription['status'] == 'Sudah Diambil'
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              (prescription['status'] ?? 'Belum Diambil')
                                  .toString(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: prescription['status'] == 'Sudah Diambil'
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final screenWidth = constraints.maxWidth;
                          if (screenWidth > 400) {
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildPrescriptionDetail(
                                        'Dosis',
                                        (prescription['dosis'] ?? '-')
                                            .toString(),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildPrescriptionDetail(
                                        'Jumlah',
                                        '${prescription['jumlah'] ?? 0}',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildPrescriptionDetail(
                                        'Harga/item',
                                        formatCurrency(
                                          prescription['harga_per_item'],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildPrescriptionDetail(
                                        'Subtotal',
                                        formatCurrency(
                                          prescription['subtotal'],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          } else {
                            return Column(
                              children: [
                                _buildPrescriptionDetail(
                                  'Dosis',
                                  (prescription['dosis'] ?? '-').toString(),
                                  isFullWidth: true,
                                ),
                                const SizedBox(height: 6),
                                _buildPrescriptionDetail(
                                  'Jumlah',
                                  '${prescription['jumlah'] ?? 0}',
                                  isFullWidth: true,
                                ),
                                const SizedBox(height: 6),
                                _buildPrescriptionDetail(
                                  'Harga/item',
                                  formatCurrency(
                                    prescription['harga_per_item'],
                                  ),
                                  isFullWidth: true,
                                ),
                                const SizedBox(height: 6),
                                _buildPrescriptionDetail(
                                  'Subtotal',
                                  formatCurrency(prescription['subtotal']),
                                  isFullWidth: true,
                                ),
                              ],
                            );
                          }
                        },
                      ),
                      if ((prescription['keterangan'] ?? '')
                          .toString()
                          .isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildPrescriptionDetail(
                          'Keterangan',
                          prescription['keterangan'].toString(),
                          isFullWidth: true,
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionDetail(
    String label,
    String value, {
    bool isFullWidth = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
          maxLines: isFullWidth ? null : 1,
          overflow: isFullWidth ? null : TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ====== RINGKASAN BIAYA (BARU) ======
  Widget _buildCostSummarySection({
    required double layananTotal,
    required double totalObat,
    required double totalTagihan,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade100,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.receipt_long,
                  size: 20,
                  color: Colors.indigo.shade700,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Ringkasan Biaya',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.indigo.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow(
                  Icons.medical_services_outlined,
                  'Total Layanan',
                  formatCurrency(layananTotal),
                ),
                _buildDetailRow(
                  Icons.medication,
                  'Total Obat',
                  formatCurrency(totalObat),
                ),
                const Divider(),
                _buildDetailRow(
                  Icons.attach_money,
                  'Perkiraan Total',
                  formatCurrency(totalTagihan),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ====== PEMBAYARAN (DIPERLUAS) ======
  Widget _buildPaymentSection(Map<String, dynamic> payment) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.payment, size: 20, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Informasi Pembayaran',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow(
                  Icons.medical_services,
                  'Biaya Konsultasi',
                  formatCurrency(payment['biaya_konsultasi']),
                ),
                _buildDetailRow(
                  Icons.medication,
                  'Total Obat',
                  formatCurrency(payment['total_obat']),
                ),
                const Divider(),
                _buildDetailRow(
                  Icons.receipt_long,
                  'Total Tagihan',
                  formatCurrency(payment['total_tagihan']),
                ),
                if ((payment['kode_transaksi'] ?? '').toString().isNotEmpty)
                  _buildDetailRow(
                    Icons.qr_code_2,
                    'Kode Transaksi',
                    payment['kode_transaksi'].toString(),
                  ),
                if ((payment['metode_pembayaran'] ?? '').toString().isNotEmpty)
                  _buildDetailRow(
                    Icons.credit_card,
                    'Metode Pembayaran',
                    payment['metode_pembayaran'].toString(),
                  ),
                if ((payment['tanggal_pembayaran'] ?? '').toString().isNotEmpty)
                  _buildDetailRow(
                    Icons.event,
                    'Tanggal Pembayaran',
                    formatDate(payment['tanggal_pembayaran'].toString()),
                  ),
                if (payment['uang_yang_diterima'] != null)
                  _buildDetailRow(
                    Icons.account_balance_wallet,
                    'Uang Diterima',
                    formatCurrency(payment['uang_yang_diterima']),
                  ),
                if (payment['kembalian'] != null)
                  _buildDetailRow(
                    Icons.monetization_on_outlined,
                    'Kembalian',
                    formatCurrency(payment['kembalian']),
                  ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: payment['status'] == 'Sudah Bayar'
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        payment['status'] == 'Sudah Bayar'
                            ? Icons.check_circle
                            : Icons.schedule,
                        size: 16,
                        color: payment['status'] == 'Sudah Bayar'
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          (payment['status'] ?? 'Status tidak diketahui')
                              .toString(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: payment['status'] == 'Sudah Bayar'
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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
