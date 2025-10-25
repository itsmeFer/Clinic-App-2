import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:RoyalClinic/pasien/pembayaran.dart';

class ListPembayaran extends StatefulWidget {
  const ListPembayaran({super.key});

  @override
  State<ListPembayaran> createState() => _ListPembayaranState();
}

class _ListPembayaranState extends State<ListPembayaran> {
  bool isLoading = true;
  String? errorMessage;
  List<Map<String, dynamic>> pembayaranList = [];

  @override
  void initState() {
    super.initState();
    fetchListPembayaran();
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<int?> getPasienId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('pasien_id');
  }

  Future<void> fetchListPembayaran() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final token = await getToken();
      final pasienId = await getPasienId();

      print('🔍 === DEBUG LIST PEMBAYARAN ===');
      print('🔍 Token: ${token != null ? 'Available' : 'NULL'}');
      print('🔍 PasienId: $pasienId');

      if (token == null) {
        setState(() {
          errorMessage = 'Token tidak ditemukan. Silakan login ulang.';
          isLoading = false;
        });
        return;
      }

      if (pasienId == null) {
        setState(() {
          errorMessage = 'ID pasien tidak ditemukan. Silakan login ulang.';
          isLoading = false;
        });
        return;
      }

      // Try to fetch from the list endpoint first
      final listUrl = 'http://10.227.74.71:8000/api/pembayaran/list/$pasienId';
      print('🔍 Trying list URL: $listUrl');

      final listResponse = await http.get(
        Uri.parse(listUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('📡 fetchListPembayaran - Status: ${listResponse.statusCode}');
      print('📄 fetchListPembayaran - Body: ${listResponse.body}');

      if (!mounted) return;

      // Handle different response scenarios
      if (listResponse.statusCode == 200) {
        final data = jsonDecode(listResponse.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            pembayaranList = _processPembayaranData(data['data']);
            isLoading = false;
          });
          print('✅ Loaded ${pembayaranList.length} payments from list endpoint');
          return;
        }
      }

      // If list endpoint fails, try single patient endpoint
      print('🔄 List endpoint failed, trying patient endpoint...');
      final patientUrl = 'http://10.227.74.71:8000/api/pembayaran/pasien/$pasienId';

      final patientResponse = await http.get(
        Uri.parse(patientUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('📡 Patient endpoint - Status: ${patientResponse.statusCode}');
      print('📄 Patient endpoint - Body: ${patientResponse.body}');

      if (patientResponse.statusCode == 200) {
        final data = jsonDecode(patientResponse.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            if (data['data']['payments'] != null) {
              pembayaranList = _processPembayaranData(data['data']['payments']);
            } else {
              pembayaranList = [_processSinglePembayaran(data['data'])];
            }
            isLoading = false;
          });
          print('✅ Loaded ${pembayaranList.length} payments from patient endpoint');
          return;
        }
      }

      // If both endpoints fail with specific errors
      if (listResponse.statusCode == 404 || patientResponse.statusCode == 404) {
        setState(() {
          pembayaranList = [];
          isLoading = false;
        });
        print('ℹ️ No payment data found for patient');
      } else {
        setState(() {
          errorMessage = 'Gagal memuat data pembayaran. Silakan coba lagi.';
          isLoading = false;
        });
      }

    } catch (e) {
      print('❌ fetchListPembayaran Exception: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Terjadi kesalahan koneksi. Silakan coba lagi.';
          isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _processPembayaranData(dynamic data) {
    if (data == null) return [];

    if (data is List) {
      return data.map((item) => _processSinglePembayaran(item)).toList();
    } else {
      return [_processSinglePembayaran(data)];
    }
  }

  Map<String, dynamic> _processSinglePembayaran(dynamic item) {
    if (item == null) return _createEmptyPembayaran();

    final Map<String, dynamic> processed = {};

    // Safely extract all fields with null checks
    processed['id'] = item['id'];
    processed['total_tagihan'] = item['total_tagihan'] ?? 0;
    processed['status_pembayaran'] = item['status_pembayaran'] ?? 'Belum Bayar';
    processed['kode_transaksi'] = item['kode_transaksi'];
    processed['tanggal_pembayaran'] = item['tanggal_pembayaran'];
    processed['tanggal_kunjungan'] = item['tanggal_kunjungan'];
    processed['no_antrian'] = item['no_antrian'];
    processed['diagnosis'] = item['diagnosis'];
    processed['metode_pembayaran_nama'] = item['metode_pembayaran_nama'];

    // Handle nested pasien data safely
    if (item['pasien'] != null && item['pasien'] is Map) {
      processed['pasien'] = {
        'nama_pasien': item['pasien']['nama_pasien'] ?? 'Pasien',
      };
    } else {
      processed['pasien'] = {'nama_pasien': 'Pasien'};
    }

    // Handle nested poli data safely
    if (item['poli'] != null && item['poli'] is Map) {
      processed['poli'] = {
        'nama_poli': item['poli']['nama_poli'] ?? 'Umum',
      };
    } else {
      processed['poli'] = {'nama_poli': 'Umum'};
    }

    // Handle resep data safely
    if (item['resep'] != null && item['resep'] is List) {
      processed['resep'] = List<Map<String, dynamic>>.from(item['resep']);
    } else {
      processed['resep'] = [];
    }

    // Handle layanan data safely
    if (item['layanan'] != null && item['layanan'] is List) {
      processed['layanan'] = List<Map<String, dynamic>>.from(item['layanan']);
    } else {
      processed['layanan'] = [];
    }

    // Handle flags
    processed['is_emr_missing'] = item['is_emr_missing'] ?? false;
    processed['is_payment_missing'] = item['is_payment_missing'] ?? false;

    return processed;
  }

  Map<String, dynamic> _createEmptyPembayaran() {
    return {
      'id': null,
      'total_tagihan': 0,
      'status_pembayaran': 'Belum Bayar',
      'kode_transaksi': null,
      'tanggal_pembayaran': null,
      'tanggal_kunjungan': DateTime.now().toString(),
      'no_antrian': '-',
      'diagnosis': 'Data tidak tersedia',
      'metode_pembayaran_nama': null,
      'pasien': {'nama_pasien': 'Pasien'},
      'poli': {'nama_poli': 'Umum'},
      'resep': [],
      'layanan': [],
      'is_emr_missing': false,
      'is_payment_missing': false,
    };
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
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
    )}';
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'sudah bayar':
      case 'completed':
        return Colors.green;
      case 'belum bayar':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'sudah bayar':
      case 'completed':
        return Icons.check_circle;
      case 'belum bayar':
        return Icons.schedule;
      default:
        return Icons.help_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Riwayat Pembayaran'),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF00897B)),
            SizedBox(height: 16),
            Text('Memuat riwayat pembayaran...'),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red.shade400,
              ),
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
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: fetchListPembayaran,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (pembayaranList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Belum Ada Riwayat Pembayaran',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Riwayat pembayaran akan muncul setelah Anda melakukan kunjungan.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: fetchListPembayaran,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: fetchListPembayaran,
      color: const Color(0xFF00897B),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: pembayaranList.length,
        itemBuilder: (context, index) {
          final payment = pembayaranList[index];
          return _buildPaymentCard(payment, index);
        },
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment, int index) {
    // Safe null checks for all accessed fields
    final namaPasien = payment['pasien']?['nama_pasien'] ?? 'Pasien';
    final namaPoli = payment['poli']?['nama_poli'] ?? 'Umum';
    final status = payment['status_pembayaran'] ?? 'Belum Bayar';
    final totalTagihan = toDoubleValue(payment['total_tagihan']);
    final kodeTransaksi = payment['kode_transaksi'];
    final tanggalKunjungan = payment['tanggal_kunjungan'];
    final noAntrian = payment['no_antrian'];
    final isEmrMissing = payment['is_emr_missing'] == true;
    final isPaymentMissing = payment['is_payment_missing'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          // Save context for navigation
          final prefs = await SharedPreferences.getInstance();
          if (payment['id'] != null) {
            await prefs.setInt('selected_kunjungan_id', payment['id']);
            await prefs.setBool('from_list_payment', true);
          }

          if (!mounted) return;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => Pembayaran(
                kunjunganId: payment['id'],
                fromList: true,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with patient name and status
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          namaPasien,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          namaPoli,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(status).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getStatusIcon(status),
                          size: 16,
                          color: _getStatusColor(status),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(status),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Payment details
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(tanggalKunjungan),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.confirmation_number,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'No. ${noAntrian ?? '-'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Total amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Pembayaran:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    formatCurrency(totalTagihan),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00897B),
                    ),
                  ),
                ],
              ),

              // Transaction code if available
              if (kodeTransaksi != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.qr_code,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Kode: $kodeTransaksi',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ],

              // Special status indicators
              if (isEmrMissing || isPaymentMissing) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isEmrMissing
                        ? Colors.blue.shade50
                        : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isEmrMissing
                          ? Colors.blue.shade200
                          : Colors.amber.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isEmrMissing
                            ? Icons.medical_services
                            : Icons.hourglass_empty,
                        size: 16,
                        color: isEmrMissing
                            ? Colors.blue.shade600
                            : Colors.amber.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isEmrMissing
                              ? 'Menunggu pemeriksaan dokter'
                              : 'Sedang diproses',
                          style: TextStyle(
                            fontSize: 12,
                            color: isEmrMissing
                                ? Colors.blue.shade700
                                : Colors.amber.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}