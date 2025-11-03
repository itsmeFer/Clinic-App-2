import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class RMPasien extends StatefulWidget {
  final int pasienId;
  final String namaPasien;

  const RMPasien({
    super.key,
    required this.pasienId,
    required this.namaPasien,
  });

  @override
  State<RMPasien> createState() => _RMPasienState();
}

class _RMPasienState extends State<RMPasien> {
  // Ganti sesuai BASE API Anda
  static const String baseUrl = 'http://192.168.1.6:8000/api';

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
    return prefs.getString('token');
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
            _pasienData = Map<String, dynamic>.from(data['data']['pasien'] ?? {});
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

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    try {
      double numPrice = price is String ? double.parse(price) : (price as num).toDouble();
      final formatter = NumberFormat('#,###', 'id_ID');
      return formatter.format(numPrice);
    } catch (_) {
      return price.toString();
    }
  }

  // ---------- UI ----------
  Widget _buildPatientHeader() {
    if (_pasienData == null) return const SizedBox.shrink();
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.teal.shade400, Colors.teal.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: isSmallScreen ? 60 : 80,
            height: isSmallScreen ? 60 : 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 5,
                ),
              ],
            ),
            child: ClipOval(
              child: (_pasienData!['foto_pasien'] != null && (_pasienData!['foto_pasien'] as String).isNotEmpty)
                  ? Image.network(
                      'http://192.168.1.6:8000/storage/${_pasienData!['foto_pasien']}',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultAvatar(isSmallScreen);
                      },
                    )
                  : _buildDefaultAvatar(isSmallScreen),
            ),
          ),
          SizedBox(width: isSmallScreen ? 12 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _pasienData!['nama_pasien']?.toString() ?? 'Tidak tersedia',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 18 : 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      _pasienData!['jenis_kelamin'] == 'Laki-laki' ? Icons.male : Icons.female,
                      color: Colors.white70,
                      size: isSmallScreen ? 16 : 18,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_pasienData!['jenis_kelamin'] ?? '-'} • ${_calculateAge(_pasienData!['tanggal_lahir']?.toString())} tahun',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13 : 15,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                if ((_pasienData!['alamat']?.toString().isNotEmpty ?? false)) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.white70,
                        size: isSmallScreen ? 14 : 16,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _pasienData!['alamat'].toString(),
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 14,
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

  Widget _buildDefaultAvatar(bool isSmallScreen) {
    return Container(
      color: Colors.teal.shade200,
      child: Icon(
        Icons.person,
        size: isSmallScreen ? 40 : 50,
        color: Colors.teal.shade700,
      ),
    );
  }

  Widget _buildStatisticsCard() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            Icons.medical_services,
            'Total Kunjungan',
            _riwayatEMR.length.toString(),
            Colors.blue,
            isSmallScreen,
          ),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          _buildStatItem(
            Icons.history,
            'Rekam Medis',
            _riwayatEMR.length.toString(),
            Colors.teal,
            isSmallScreen,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String label,
    String value,
    Color color,
    bool isSmallScreen,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: isSmallScreen ? 24 : 28),
        SizedBox(height: isSmallScreen ? 4 : 6),
        Text(
          value,
          style: TextStyle(
            fontSize: isSmallScreen ? 18 : 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 11 : 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildEMRCard(Map<String, dynamic> emrData) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 14 : 16,
            vertical: isSmallScreen ? 6 : 8,
          ),
          childrenPadding: EdgeInsets.all(isSmallScreen ? 14 : 16),
          leading: Container(
            padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
            decoration: BoxDecoration(
              color: Colors.teal.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.folder_shared,
              color: Colors.teal.shade700,
              size: isSmallScreen ? 20 : 24,
            ),
          ),
          title: Text(
            _formatTanggalSingkat(emrData['tanggal_kunjungan']?.toString()),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isSmallScreen ? 14 : 16,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                'Poli: ${_toMap(emrData['poli'])['nama_poli'] ?? 'Tidak diketahui'}',
                style: TextStyle(
                  fontSize: isSmallScreen ? 11 : 12,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _getStatusColor(emrData['status_kunjungan']?.toString()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  emrData['status_kunjungan']?.toString() ?? 'Unknown',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10 : 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          children: [
            _buildEMRDetails(emrData, isSmallScreen),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'succeed':
      case 'completed':
        return Colors.green;
      case 'payment':
        return Colors.orange;
      default:
        return Colors.grey;
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
          Icons.description,
          Colors.blue,
          [
            _buildDetailRow('Keluhan Awal', emrData['keluhan_awal']?.toString(), isSmallScreen),
            _buildDetailRow('Keluhan Utama', emr['keluhan_utama']?.toString(), isSmallScreen),
            if ((emr['riwayat_penyakit_dahulu']?.toString().isNotEmpty ?? false))
              _buildDetailRow('Riwayat Penyakit Dahulu', emr['riwayat_penyakit_dahulu']?.toString(), isSmallScreen),
            if ((emr['riwayat_penyakit_keluarga']?.toString().isNotEmpty ?? false))
              _buildDetailRow('Riwayat Penyakit Keluarga', emr['riwayat_penyakit_keluarga']?.toString(), isSmallScreen),
          ],
          isSmallScreen,
        ),

        SizedBox(height: isSmallScreen ? 12 : 16),

        _buildDetailSection(
          'Tanda Vital',
          Icons.monitor_heart,
          Colors.redAccent,
          [
            _buildDetailRow('Tekanan Darah', tandaVital['tekanan_darah']?.toString(), isSmallScreen),
            _buildDetailRow('Suhu Tubuh', tandaVital['suhu_tubuh']?.toString(), isSmallScreen),
            _buildDetailRow('Nadi', tandaVital['nadi']?.toString(), isSmallScreen),
            _buildDetailRow('Pernapasan', tandaVital['pernapasan']?.toString(), isSmallScreen),
            _buildDetailRow('Saturasi Oksigen', tandaVital['saturasi_oksigen']?.toString(), isSmallScreen),
          ],
          isSmallScreen,
        ),

        SizedBox(height: isSmallScreen ? 12 : 16),

        _buildDetailSection(
          'Diagnosis',
          Icons.assignment,
          Colors.orange,
          [
            _buildDetailRow('Diagnosis', emr['diagnosis']?.toString(), isSmallScreen),
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

    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.badge, color: Colors.green, size: isSmall ? 18 : 20),
              SizedBox(width: isSmall ? 6 : 8),
              Text(
                'Pemeriksa',
                style: TextStyle(
                  fontSize: isSmall ? 14 : 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmall ? 10 : 12),
          _buildDetailRow('Dokter', dokter['nama_dokter']?.toString() ?? 'Tidak diketahui', isSmall),
          _buildDetailRow('Poli', poli['nama_poli']?.toString() ?? 'Tidak diketahui', isSmall),
          _buildDetailRow('Spesialis', spesialis['nama_spesialis']?.toString() ?? 'Tidak diketahui', isSmall),
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
              Icon(icon, color: color, size: isSmallScreen ? 18 : 20),
              SizedBox(width: isSmallScreen ? 6 : 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.bold,
                  color: color,
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

  Widget _buildDetailRow(String label, String? value, bool isSmallScreen) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: isSmallScreen ? 6 : 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 14,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // -------- Resep (LIST<dynamic> -> cast aman) --------
  Widget _buildResepSection(List<dynamic> resepList, bool isSmallScreen) {
    final items = _toListMap(resepList);

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.medication, color: Colors.purple.shade700, size: isSmallScreen ? 18 : 20),
              SizedBox(width: isSmallScreen ? 6 : 8),
              Text(
                'Resep Obat',
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade700,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 10 : 12),
          ...items.map((resep) => _buildResepItem(resep, isSmallScreen)),
        ],
      ),
    );
  }

  Widget _buildResepItem(Map<String, dynamic> resep, bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 10),
      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (resep['nama_obat'] ?? 'Obat').toString(),
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: isSmallScreen ? 13 : 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Jumlah: ${resep['jumlah'] ?? '-'} • Dosis: ${resep['dosis'] ?? '-'}',
                      style: TextStyle(fontSize: isSmallScreen ? 11 : 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (resep['status'] == 'Sudah Diambil') ? Colors.green.shade100 : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  (resep['status'] ?? 'Belum Diambil').toString(),
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10 : 11,
                    color: (resep['status'] == 'Sudah Diambil') ? Colors.green.shade700 : Colors.orange.shade700,
                    fontWeight: FontWeight.w600,
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
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: isSmallScreen ? 14 : 16, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      resep['keterangan'].toString(),
                      style: TextStyle(fontSize: isSmallScreen ? 11 : 12, color: Colors.grey.shade700),
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

  // -------- Layanan (LIST<dynamic> -> cast aman) --------
  Widget _buildLayananSection(List<dynamic> layananList, bool isSmallScreen) {
    final items = _toListMap(layananList);

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.medical_services_outlined, color: Colors.blue.shade700, size: isSmallScreen ? 18 : 20),
              SizedBox(width: isSmallScreen ? 6 : 8),
              Text(
                'Layanan Medis',
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 10 : 12),
          ...items.map((layanan) => _buildLayananItem(layanan, isSmallScreen)),
        ],
      ),
    );
  }

  Widget _buildLayananItem(Map<String, dynamic> layanan, bool isSmallScreen) {
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 10),
      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (layanan['nama_layanan'] ?? 'Layanan').toString(),
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: isSmallScreen ? 13 : 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Jumlah: ${layanan['jumlah'] ?? '-'} kali',
                  style: TextStyle(fontSize: isSmallScreen ? 11 : 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Text(
            'Rp ${_formatPrice(layanan['harga_layanan'])}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isSmallScreen ? 13 : 14,
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // --- Pembayaran (DISIMPAN tapi TIDAK dipanggil) ---
  Widget _buildPembayaranSection(Map<String, dynamic> pembayaran, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment, color: Colors.green.shade700, size: isSmallScreen ? 18 : 20),
              SizedBox(width: isSmallScreen ? 6 : 8),
              Text(
                'Informasi Pembayaran',
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 10 : 12),
          _buildPembayaranRow('Total Tagihan', 'Rp ${_formatPrice(pembayaran['total_tagihan'])}', isSmallScreen),
          _buildPembayaranRow('Metode Pembayaran', pembayaran['metode_pembayaran']?.toString() ?? 'Tidak diketahui', isSmallScreen),
          _buildPembayaranRow('Status', pembayaran['status']?.toString() ?? 'Belum Bayar', isSmallScreen, isStatus: true, status: pembayaran['status']?.toString()),
          if (pembayaran['tanggal_pembayaran'] != null)
            _buildPembayaranRow('Tanggal Pembayaran', _formatTanggal(pembayaran['tanggal_pembayaran']?.toString()), isSmallScreen),
        ],
      ),
    );
  }

  Widget _buildPembayaranRow(
    String label,
    String value,
    bool isSmallScreen, {
    bool isStatus = false,
    String? status,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isSmallScreen ? 6 : 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: isSmallScreen ? 11 : 12, color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(width: 8),
          if (isStatus)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: (status == 'Sudah Bayar') ? Colors.green.shade100 : Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: isSmallScreen ? 11 : 12,
                  color: (status == 'Sudah Bayar') ? Colors.green.shade700 : Colors.orange.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            Text(
              value,
              style: TextStyle(
                fontSize: isSmallScreen ? 11 : 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Riwayat Rekam Medis',
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.white, size: isSmallScreen ? 20 : 24),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 16),
                  Text('Memuat riwayat rekam medis...'),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'Gagal memuat data',
                          style: TextStyle(fontSize: isSmallScreen ? 16 : 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: isSmallScreen ? 12 : 14, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadRiwayatEMR,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Coba Lagi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadRiwayatEMR,
                  color: Colors.teal,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPatientHeader(),
                        SizedBox(height: isSmallScreen ? 16 : 20),
                        _buildStatisticsCard(),
                        SizedBox(height: isSmallScreen ? 16 : 20),
                        Row(
                          children: [
                            Icon(Icons.history, color: Colors.teal.shade700, size: isSmallScreen ? 20 : 24),
                            SizedBox(width: isSmallScreen ? 6 : 8),
                            Text(
                              'Riwayat Pemeriksaan',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 16 : 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.teal.shade700,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        if (_riwayatEMR.isEmpty)
                          Container(
                            padding: EdgeInsets.all(isSmallScreen ? 24 : 32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.inbox, size: isSmallScreen ? 48 : 64, color: Colors.grey.shade400),
                                SizedBox(height: isSmallScreen ? 12 : 16),
                                Text(
                                  'Belum ada riwayat rekam medis',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Riwayat pemeriksaan pasien akan muncul di sini',
                                  style: TextStyle(fontSize: isSmallScreen ? 12 : 14, color: Colors.grey.shade500),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        else
                          ..._riwayatEMR
                              .map((emr) => _buildEMRCard(Map<String, dynamic>.from(emr)))
                              .toList(),
                        SizedBox(height: isSmallScreen ? 16 : 20),
                      ],
                    ),
                  ),
                ),
    );
  }
}
