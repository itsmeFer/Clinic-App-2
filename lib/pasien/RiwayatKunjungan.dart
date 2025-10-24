import 'dart:convert';
import 'package:RoyalClinic/pasien/PesanJadwal.dart';
import 'package:RoyalClinic/pasien/dashboardScreen.dart';
import 'package:RoyalClinic/pasien/edit_profile.dart';
import 'package:RoyalClinic/pasien/DetailEmr.dart'; // Import halaman DetailEmr baru
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// UPDATED: Create a version without bottom navigation for use in MainWrapper
class RiwayatKunjunganPage extends StatefulWidget {
  const RiwayatKunjunganPage({Key? key}) : super(key: key);

  @override
  State<RiwayatKunjunganPage> createState() => _RiwayatKunjunganPageState();
}

class _RiwayatKunjunganPageState extends State<RiwayatKunjunganPage> {
  bool isLoading = true;
  List<dynamic> riwayatList = [];
  Map<String, dynamic>? pasienInfo;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchRiwayatKunjungan();
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print('=== GET TOKEN DEBUG ===');
    print('Token from SharedPrefs: $token');
    return token;
  }

  Future<int?> getPasienId() async {
    final prefs = await SharedPreferences.getInstance();
    final pasienId = prefs.getInt('pasien_id');
    print('=== GET PASIEN ID DEBUG ===');
    print('Pasien ID from SharedPrefs: $pasienId');
    return pasienId;
  }

  Future<void> fetchRiwayatKunjungan() async {
    try {
      final token = await getToken();
      final pasienId = await getPasienId();

      if (token == null || pasienId == null) {
        if (mounted) {
          setState(() {
            errorMessage = 'Token atau ID pasien tidak ditemukan';
            isLoading = false;
          });
        }
        return;
      }

      final response = await http.get(
        Uri.parse('http://10.227.74.71:8000/api/kunjungan/riwayat/$pasienId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (!mounted) return;

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          riwayatList = data['data'] ?? [];
          pasienInfo = data['pasien_info'];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = data['message'] ?? 'Gagal memuat riwayat kunjungan';
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Kesalahan koneksi: $e';
          isLoading = false;
        });
      }
    }
  }

  Future<void> batalkanKunjungan(int kunjunganId) async {
    try {
      final token = await getToken();
      if (token == null) {
        print('=== BATALKAN ERROR: Token null ===');
        if (mounted) {
          _showErrorSnackBar('Token tidak ditemukan');
        }
        return;
      }

      print('=== BATALKAN KUNJUNGAN START ===');
      print('Kunjungan ID: $kunjunganId');
      print('Token: ${token.substring(0, 10)}...');

      if (mounted) {
        setState(() => isLoading = true);
      }

      final requestBody = jsonEncode({'id': kunjunganId});
      print('Request Body: $requestBody');

      final response = await http.post(
        Uri.parse('http://10.227.74.71:8000/api/kunjungan/batalkan'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: requestBody,
      );

      print('=== BATALKAN RESPONSE ===');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (!mounted) return;

      if (response.body.startsWith('<!DOCTYPE html>') ||
          response.body.startsWith('<html>')) {
        print('ERROR: Received HTML response instead of JSON');
        _showErrorSnackBar('Endpoint tidak ditemukan. Periksa URL API.');
        setState(() => isLoading = false);
        return;
      }

      if (response.body.isEmpty) {
        print('WARNING: Response body is empty');
        if (response.statusCode == 200 || response.statusCode == 204) {
          _showSuccessSnackBar('Kunjungan berhasil dibatalkan');
          await fetchRiwayatKunjungan();
          return;
        }
      }

      final data = jsonDecode(response.body);
      print('Parsed Data: $data');

      bool isSuccess = false;

      if (response.statusCode == 200) {
        if (data['success'] == true ||
            data['success'] == 'true' ||
            data['success'] == 1 ||
            data['success'] == '1' ||
            data['status'] == 'success' ||
            data['status'] == 200 ||
            (data['message'] != null &&
                data['message'].toString().toLowerCase().contains(
                  'berhasil',
                ))) {
          isSuccess = true;
        }
      }

      if (isSuccess) {
        await fetchRiwayatKunjungan();
        if (mounted) {
          _showSuccessSnackBar(
            data['message'] ?? 'Kunjungan berhasil dibatalkan',
          );
        }
      } else {
        if (mounted) {
          _showErrorSnackBar(data['message'] ?? 'Gagal membatalkan kunjungan');
        }
      }
    } catch (e) {
      print('=== BATALKAN EXCEPTION ===');
      print('Error: $e');
      if (mounted) {
        _showErrorSnackBar('Kesalahan: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
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

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFFF9800);
      case 'waiting':
        return const Color(0xFF9C27B0);
      case 'engaged':
        return const Color(0xFF2196F3);
      case 'payment':
        return const Color(0xFFFF5722);
      case 'succeed':
        return const Color(0xFF4CAF50);
      case 'canceled':
        return const Color(0xFFE53935);
      default:
        return Colors.grey;
    }
  }

  String getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Menunggu Konfirmasi';
      case 'waiting':
        return 'Menunggu Antrian';
      case 'engaged':
        return 'Sedang Ditangani';
      case 'payment':
        return 'Menunggu Pembayaran';
      case 'succeed':
        return 'Selesai';
      case 'canceled':
        return 'Dibatalkan';
      default:
        return status;
    }
  }

  IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.schedule;
      case 'waiting':
        return Icons.hourglass_empty;
      case 'engaged':
        return Icons.medical_services;
      case 'payment':
        return Icons.payment;
      case 'succeed':
        return Icons.check_circle;
      case 'canceled':
        return Icons.cancel;
      default:
        return Icons.help_outline;
    }
  }

  String _norm(String? s) =>
      (s ?? '').replaceAll(RegExp(r'\s+'), '').toLowerCase();

  // Tentukan status efektif untuk UI berdasarkan status kunjungan + pembayaran
  String effectiveStatus(Map<String, dynamic> kunjungan) {
    final raw = (kunjungan['status'] ?? '').toString();
    final paymentStatus = kunjungan['pembayaran']?['status']?.toString();

    // Jika pembayaran sudah "Sudah Bayar", tampilkan sebagai "Selesai"
    if (_norm(paymentStatus) == 'sudahbayar') {
      return 'succeed';
    }
    return raw;
  }

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
          : amount.toDouble();
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

  Widget _buildPasienInfoCard() {
    if (pasienInfo == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: pasienInfo!['foto_pasien'] != null
                  ? Image.network(
                      'http://10.227.74.71:8000/storage/${pasienInfo!['foto_pasien']}',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.person,
                          size: 40,
                          color: Color(0xFF00897B),
                        );
                      },
                    )
                  : const Icon(
                      Icons.person,
                      size: 40,
                      color: Color(0xFF00897B),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pasienInfo!['nama_pasien'] ?? 'Nama tidak tersedia',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.cake, size: 14, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      calculateAge(pasienInfo!['tanggal_lahir']),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      pasienInfo!['jenis_kelamin'] == 'Laki-laki'
                          ? Icons.male
                          : Icons.female,
                      size: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      pasienInfo!['jenis_kelamin'] ?? '-',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                if (pasienInfo!['alamat'] != null &&
                    pasienInfo!['alamat'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          pasienInfo!['alamat'],
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
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
        ],
      ),
    );
  }

  // UPDATED: Simplified dialog for basic information only
  void showKunjunganDetail(Map<String, dynamic> kunjungan) {
    final String statusEff = effectiveStatus(kunjungan);
    final dokter = kunjungan['dokter'] ?? {};

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF00897B),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Ringkasan Kunjungan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Content - Simplified for basic info only
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Badge
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: getStatusColor(statusEff).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: getStatusColor(statusEff),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              getStatusIcon(statusEff),
                              size: 18,
                              color: getStatusColor(statusEff),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              getStatusText(statusEff),
                              style: TextStyle(
                                color: getStatusColor(statusEff),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Basic Information
                      _buildSimpleInfoCard('Informasi Kunjungan', [
                        _buildSimpleRow(
                          Icons.confirmation_number,
                          'No. Antrian',
                          kunjungan['no_antrian'] ?? '-',
                        ),
                        _buildSimpleRow(
                          Icons.calendar_today,
                          'Tanggal',
                          formatDate(kunjungan['tanggal_kunjungan'] ?? ''),
                        ),
                        _buildSimpleRow(
                          Icons.medical_services,
                          'Keluhan Awal',
                          kunjungan['keluhan_awal'] ?? '-',
                        ),
                      ]),

                      const SizedBox(height: 12),

                      // Doctor Information
                      _buildSimpleInfoCard('Informasi Dokter', [
                        _buildSimpleRow(
                          Icons.person,
                          'Nama Dokter',
                          dokter['nama_dokter'] ?? '-',
                        ),
                        _buildSimpleRow(
                          Icons.local_hospital,
                          'Spesialisasi',
                          dokter['spesialisasi'] ?? 'Umum',
                        ),
                        if (dokter['no_hp'] != null)
                          _buildSimpleRow(
                            Icons.phone,
                            'No. HP',
                            dokter['no_hp'],
                          ),
                      ]),

                      // EMR Summary and Action Button
                      if (kunjungan['emr'] != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF00897B).withOpacity(0.1),
                                const Color(0xFF00897B).withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF00897B).withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.medical_information,
                                    color: Color(0xFF00897B),
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'EMR Tersedia',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF00897B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Data rekam medis elektronik lengkap tersedia untuk kunjungan ini',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black54,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(
                                      context,
                                    ); // Close current dialog
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DetailEmr(
                                          kunjungan: kunjungan,
                                          pasienInfo: pasienInfo,
                                        ),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.visibility, size: 18),
                                  label: const Text('Lihat Detail EMR'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00897B),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Additional Info Badges
                      if (kunjungan['resep_obat'] != null ||
                          kunjungan['pembayaran'] != null) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (kunjungan['resep_obat'] != null &&
                                (kunjungan['resep_obat'] as List).isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.medication,
                                      size: 14,
                                      color: Colors.purple.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${(kunjungan['resep_obat'] as List).length} Resep Obat',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.purple.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (kunjungan['pembayaran'] != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.payment,
                                      size: 14,
                                      color: Colors.green.shade700,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      formatCurrency(
                                        kunjungan['pembayaran']['total_tagihan'],
                                      ),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleInfoCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00897B).withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF00897B),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF00897B)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF00897B)),
          )
        : errorMessage != null
        ? Container(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red.shade300,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Oops! Terjadi Kesalahan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage!,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      if (mounted) {
                        setState(() {
                          isLoading = true;
                          errorMessage = null;
                        });
                      }
                      fetchRiwayatKunjungan();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00897B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Coba Lagi',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        : riwayatList.isEmpty
        ? Column(
            children: [
              _buildPasienInfoCard(),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Icon(
                          Icons.history,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Belum Ada Riwayat',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Anda belum memiliki riwayat kunjungan',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
        : RefreshIndicator(
            onRefresh: fetchRiwayatKunjungan,
            color: const Color(0xFF00897B),
            child: ListView(
              children: [
                _buildPasienInfoCard(),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: riwayatList.length,
                  itemBuilder: (context, index) {
                    final kunjungan = riwayatList[index];
                    final dokter = kunjungan['dokter'];
                    final status = effectiveStatus(kunjungan);
                    final hasEMR = kunjungan['emr'] != null;
                    final hasPrescription =
                        kunjungan['resep_obat'] != null &&
                        kunjungan['resep_obat'].isNotEmpty;
                    final payment = kunjungan['pembayaran'];
                    final canCancel = [
                      'pending',
                      'waiting',
                    ].contains(status.toLowerCase());

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
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
                      child: InkWell(
                        onTap: () => showKunjunganDetail(kunjungan),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF00897B,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: dokter?['foto_dokter'] != null
                                          ? Image.network(
                                              'http://10.227.74.71:8000/storage/${dokter['foto_dokter']}',
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    return const Icon(
                                                      Icons.person,
                                                      size: 32,
                                                      color: Color(0xFF00897B),
                                                    );
                                                  },
                                            )
                                          : const Icon(
                                              Icons.person,
                                              size: 32,
                                              color: Color(0xFF00897B),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          dokter?['nama_dokter'] ??
                                              'Nama tidak tersedia',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          formatDate(
                                            kunjungan['tanggal_kunjungan'] ??
                                                '',
                                          ),
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        if (dokter?['spesialisasi'] !=
                                            null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Poli ${dokter['spesialisasi']}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF00897B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: getStatusColor(
                                        status,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: getStatusColor(status),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          getStatusIcon(status),
                                          size: 14,
                                          color: getStatusColor(status),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          getStatusText(status),
                                          style: TextStyle(
                                            color: getStatusColor(status),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.confirmation_number,
                                          size: 16,
                                          color: Color(0xFF00897B),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'No. Antrian: ${kunjungan['no_antrian'] ?? '-'}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.medical_services,
                                          size: 16,
                                          color: Color(0xFF00897B),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Keluhan: ${kunjungan['keluhan_awal'] ?? '-'}',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Badges tambahan (EMR/Resep/Pembayaran)
                              if (hasEMR ||
                                  hasPrescription ||
                                  payment != null) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    if (hasEMR)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.medical_information,
                                              size: 12,
                                              color: Colors.blue.shade700,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'EMR',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.blue.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (hasPrescription)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.purple.shade100,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.medication,
                                              size: 12,
                                              color: Colors.purple.shade700,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${kunjungan['resep_obat'].length} Obat',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.purple.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (payment != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              payment['status'] == 'Sudah Bayar'
                                              ? Colors.green.shade100
                                              : Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              payment['status'] == 'Sudah Bayar'
                                                  ? Icons.check_circle
                                                  : Icons.payment,
                                              size: 12,
                                              color:
                                                  payment['status'] ==
                                                      'Sudah Bayar'
                                                  ? Colors.green.shade700
                                                  : Colors.orange.shade700,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              formatCurrency(
                                                payment['total_tagihan'],
                                              ),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color:
                                                    payment['status'] ==
                                                        'Sudah Bayar'
                                                    ? Colors.green.shade700
                                                    : Colors.orange.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],

                              if (canCancel) ...[
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red.shade500,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          title: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  Icons.cancel,
                                                  color: Colors.red.shade500,
                                                  size: 24,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              const Expanded(
                                                child: Text(
                                                  'Batalkan Kunjungan',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          content: Text(
                                            'Apakah Anda yakin ingin membatalkan kunjungan dengan Dr. ${dokter?['nama_dokter'] ?? 'Dokter'} pada ${formatDate(kunjungan['tanggal_kunjungan'] ?? '')}?',
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                          actions: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    style: TextButton.styleFrom(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 12,
                                                          ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        side: BorderSide(
                                                          color: Colors
                                                              .grey
                                                              .shade300,
                                                        ),
                                                      ),
                                                    ),
                                                    child: const Text(
                                                      'Tidak',
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: ElevatedButton(
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                      batalkanKunjungan(
                                                        kunjungan['id'],
                                                      );
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          Colors.red.shade500,
                                                      foregroundColor:
                                                          Colors.white,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            vertical: 12,
                                                          ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      elevation: 0,
                                                    ),
                                                    child: const Text(
                                                      'Ya, Batalkan',
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    child: const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.cancel, size: 18),
                                        SizedBox(width: 8),
                                        Text(
                                          'Batalkan Kunjungan',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
  }
}

// UPDATED: Original RiwayatKunjungan for standalone use (with bottom navigation)
class RiwayatKunjungan extends StatelessWidget {
  const RiwayatKunjungan({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Riwayat Kunjungan'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: const RiwayatKunjunganPage(),
    );
  }
}

// UPDATED: MainWrapperWithIndex now uses RiwayatKunjunganPage (without bottom nav)
class MainWrapperWithIndex extends StatefulWidget {
  final int initialIndex;
  const MainWrapperWithIndex({super.key, required this.initialIndex});

  @override
  State<MainWrapperWithIndex> createState() => _MainWrapperWithIndexState();
}

class _MainWrapperWithIndexState extends State<MainWrapperWithIndex> {
  late int _selectedIndex;
  late PageController _pageController;
  List<dynamic> jadwalDokter = [];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    fetchJadwalDokter();
  }

  Future<void> fetchJadwalDokter() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final token = prefs.getString('token');
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('http://10.227.74.71:8000/api/getAllDokter'),
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

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _selectedIndex = index),
        children: [
          DashboardPage(
            jadwalDokter: jadwalDokter,
            onRefresh: fetchJadwalDokter,
            onLogout: () {},
          ),
          PesanJadwal(allJadwal: jadwalDokter),
          const RiwayatKunjunganPage(),
          const EditProfilePage(),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              border: Border.all(color: Colors.white.withOpacity(0.6)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00695C).withOpacity(0.08),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              backgroundColor: Colors.transparent,
              selectedItemColor: const Color(0xFF00897B),
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
