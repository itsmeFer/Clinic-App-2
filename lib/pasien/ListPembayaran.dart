import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'pembayaran.dart';

class ListPembayaran extends StatefulWidget {
  const ListPembayaran({super.key});

  @override
  State<ListPembayaran> createState() => _ListPembayaranState();
}

class _ListPembayaranState extends State<ListPembayaran> {
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? pembayaranData;
  List<dynamic> paymentsList = [];
  List<int> selectedPayments = []; // Untuk multiple selection
  bool selectAll = false;

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

      if (token == null || pasienId == null) {
        setState(() {
          errorMessage = 'Token atau ID pasien tidak ditemukan';
          isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('https://admin.royal-klinik.cloud/api/pembayaran/pasien/$pasienId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('📡 fetchListPembayaran - Status: ${response.statusCode}');
      print('📄 fetchListPembayaran - Body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            pembayaranData = data['data'];
            paymentsList = data['data']['payments'] ?? [];
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = data['message'] ?? 'Gagal memuat data pembayaran';
            isLoading = false;
          });
        }
      } else if (response.statusCode == 404) {
        final data = jsonDecode(response.body);
        setState(() {
          errorMessage = data['message'] ?? 'Tidak ada pembayaran yang menunggu';
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = 'Gagal memuat data pembayaran';
          isLoading = false;
        });
      }
    } catch (e) {
      print('❌ fetchListPembayaran Error: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Kesalahan koneksi: $e';
          isLoading = false;
        });
      }
    }
  }

  void togglePaymentSelection(int kunjunganId) {
    setState(() {
      if (selectedPayments.contains(kunjunganId)) {
        selectedPayments.remove(kunjunganId);
      } else {
        selectedPayments.add(kunjunganId);
      }
      
      // Update select all status
      selectAll = selectedPayments.length == paymentsList.length;
    });
  }

  void toggleSelectAll() {
    setState(() {
      if (selectAll) {
        selectedPayments.clear();
        selectAll = false;
      } else {
        selectedPayments = paymentsList.map((payment) => payment['kunjungan_id'] as int).toList();
        selectAll = true;
      }
    });
  }

  double getSelectedTotal() {
    double total = 0;
    for (var payment in paymentsList) {
      if (selectedPayments.contains(payment['kunjungan_id'])) {
        total += toDoubleValue(payment['total_tagihan']);
      }
    }
    return total;
  }

  void bayarTerpilih() async {
    if (selectedPayments.isEmpty) {
      _showErrorSnackBar('Pilih pembayaran yang ingin dibayar');
      return;
    }

    if (selectedPayments.length == 1) {
      // Simpan kunjungan_id yang dipilih ke SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selected_kunjungan_id', selectedPayments.first);
      await prefs.setBool('from_list_payment', true);
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Pembayaran(), // Tanpa parameter
        ),
      ).then((_) async {
        // Clear selected kunjungan_id setelah selesai
        await prefs.remove('selected_kunjungan_id');
        await prefs.remove('from_list_payment');
        // Refresh list setelah kembali dari pembayaran
        fetchListPembayaran();
      });
    } else {
      // Multiple payment - bisa implementasi pembayaran gabungan di sini
      _showInfoDialog('Multi Payment', 
        'Fitur pembayaran multiple sedang dalam pengembangan.\nSilakan bayar satu per satu terlebih dahulu.');
    }
  }

  void lihatDetail(int kunjunganId) async {
    // Simpan kunjungan_id yang dipilih ke SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_kunjungan_id', kunjunganId);
    await prefs.setBool('from_list_payment', true);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Pembayaran(), // Tanpa parameter
      ),
    ).then((_) async {
      // Clear selected kunjungan_id setelah selesai
      await prefs.remove('selected_kunjungan_id');
      await prefs.remove('from_list_payment');
      // Refresh list setelah kembali dari pembayaran
      fetchListPembayaran();
    });
  }

  String formatCurrency(dynamic amount) {
    double value = toDoubleValue(amount);
    return 'Rp ${value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), 
      (Match m) => '${m[1]}.'
    )}';
  }
  
  double toDoubleValue(dynamic value) {
    if (value == null) return 0.0;
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    } else if (value is int) {
      return value.toDouble();
    } else if (value is double) {
      return value;
    }
    return 0.0;
  }

  String formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des',
      ];
      return '${date.day} ${months[date.month]} ${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Daftar Pembayaran',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchListPembayaran,
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00897B),
              ),
            )
          : errorMessage != null
              ? _buildErrorState()
              : paymentsList.isEmpty
                  ? _buildNoDataState()
                  : _buildContent(),
      bottomNavigationBar: paymentsList.isNotEmpty && selectedPayments.isNotEmpty
          ? _buildBottomCheckoutBar()
          : null,
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.info_outline,
                size: 48,
                color: Colors.orange.shade400,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              errorMessage!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: fetchListPembayaran,
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
              ),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.payment,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'Tidak ada pembayaran yang menunggu',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Semua pembayaran sudah selesai',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Header Info
        Container(
          margin: const EdgeInsets.all(16),
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
                  Icon(
                    Icons.person,
                    color: const Color(0xFF00897B),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    pembayaranData!['pasien']['nama_pasien'] ?? 'Pasien',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${paymentsList.length} kunjungan menunggu pembayaran',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                'Total: ${formatCurrency(pembayaranData!['total_keseluruhan'])}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF00897B),
                ),
              ),
            ],
          ),
        ),

        // Select All Checkbox
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Checkbox(
                value: selectAll,
                onChanged: (_) => toggleSelectAll(),
                activeColor: const Color(0xFF00897B),
              ),
              const SizedBox(width: 8),
              const Text(
                'Pilih Semua',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (selectedPayments.isNotEmpty)
                Text(
                  '${selectedPayments.length} dipilih',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // List Pembayaran
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: paymentsList.length,
            itemBuilder: (context, index) {
              final payment = paymentsList[index];
              final isSelected = selectedPayments.contains(payment['kunjungan_id']);
              
              return _buildPaymentCard(payment, isSelected);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFF00897B) : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header dengan checkbox
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF00897B).withOpacity(0.1) : null,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => togglePaymentSelection(payment['kunjungan_id']),
                  activeColor: const Color(0xFF00897B),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.local_hospital,
                            size: 16,
                            color: const Color(0xFF00897B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            payment['poli']['nama_poli'] ?? 'Umum',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF00897B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kunjungan ${formatDate(payment['tanggal_kunjungan'])}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'No. Antrian: ${payment['no_antrian'] ?? '-'}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatCurrency(payment['total_tagihan']),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00897B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        payment['status_pembayaran'] ?? 'Belum Bayar',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Diagnosis: ${payment['diagnosis'] ?? 'Tidak ada'}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                
                // Ringkasan layanan dan obat
                Row(
                  children: [
                    if (payment['layanan'] != null && (payment['layanan'] as List).isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${(payment['layanan'] as List).length} Layanan',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    
                    if (payment['layanan'] != null && (payment['layanan'] as List).isNotEmpty &&
                        payment['resep_obat'] != null && (payment['resep_obat'] as List).isNotEmpty)
                      const SizedBox(width: 8),
                    
                    if (payment['resep_obat'] != null && (payment['resep_obat'] as List).isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${(payment['resep_obat'] as List).length} Obat',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    
                    const Spacer(),
                    
                    TextButton(
                      onPressed: () => lihatDetail(payment['kunjungan_id']),
                      child: const Text(
                        'Lihat Detail',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF00897B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCheckoutBar() {
    final selectedTotal = getSelectedTotal();
    
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${selectedPayments.length} item dipilih',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        formatCurrency(selectedTotal),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00897B),
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton(
                    onPressed: bayarTerpilih,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00897B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.payment, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          selectedPayments.length == 1 ? 'Bayar Sekarang' : 'Bayar Semua',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
}