import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class PembelianObat extends StatefulWidget {
  const PembelianObat({super.key});

  @override
  State<PembelianObat> createState() => _PembelianObatState();
}

class _PembelianObatState extends State<PembelianObat> {
  bool isLoading = true;
  bool isProcessing = false;
  String? errorMessage;
  List<Map<String, dynamic>> daftarObat = [];
  List<Map<String, dynamic>> keranjangObat = [];
  List<Map<String, dynamic>> metodePembayaran = [];
  bool isLoadingMetode = false;
  
  // Controllers
  final TextEditingController _uangDiterimaController = TextEditingController();
  
  // Selected payment method
  Map<String, dynamic>? selectedMetodePembayaran;
  
  // Total calculation
  double totalTagihan = 0.0;
  double uangDiterima = 0.0;
  double kembalian = 0.0;

  @override
  void initState() {
    super.initState();
    fetchDaftarObat();
    fetchMetodePembayaran();
  }

  @override
  void dispose() {
    _uangDiterimaController.dispose();
    super.dispose();
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<int?> getPasienId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('pasien_id');
  }

  // Fetch daftar obat dari API
  Future<void> fetchDaftarObat() async {
    try {
      final token = await getToken();
      if (token == null) {
        setState(() {
          errorMessage = 'Token tidak ditemukan. Silakan login ulang.';
          isLoading = false;
        });
        return;
      }

      final response = await http.get(
        Uri.parse('https://admin.royal-klinik.cloud/api/obat/list'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('📡 fetchDaftarObat - Status: ${response.statusCode}');
      print('📄 fetchDaftarObat - Body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() {
            daftarObat = List<Map<String, dynamic>>.from(data['data']);
            isLoading = false;
          });
          print('✅ Loaded ${daftarObat.length} obat from database');
        } else {
          setState(() {
            errorMessage = data['message'] ?? 'Gagal memuat data obat';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Gagal memuat data obat. Status: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      print('❌ fetchDaftarObat Error: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Terjadi kesalahan: $e';
          isLoading = false;
        });
      }
    }
  }

  // Fetch metode pembayaran dari database
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

  // Tambah obat ke keranjang
  void _tambahKeKeranjang(Map<String, dynamic> obat) {
    final existingIndex = keranjangObat.indexWhere(
      (item) => item['id'] == obat['id']
    );

    if (existingIndex >= 0) {
      setState(() {
        if (keranjangObat[existingIndex]['jumlah_beli'] < obat['jumlah']) {
          keranjangObat[existingIndex]['jumlah_beli'] += 1;
        } else {
          _showSnackBar('Stok obat tidak mencukupi!', isError: true);
        }
      });
    } else {
      if (obat['jumlah'] > 0) {
        setState(() {
          keranjangObat.add({
            ...obat,
            'jumlah_beli': 1,
          });
        });
      } else {
        _showSnackBar('Obat ini sedang kosong!', isError: true);
      }
    }
    _hitungTotal();
  }

  // Kurangi obat dari keranjang
  void _kurangiDariKeranjang(Map<String, dynamic> obat) {
    final existingIndex = keranjangObat.indexWhere(
      (item) => item['id'] == obat['id']
    );

    if (existingIndex >= 0) {
      setState(() {
        if (keranjangObat[existingIndex]['jumlah_beli'] > 1) {
          keranjangObat[existingIndex]['jumlah_beli'] -= 1;
        } else {
          keranjangObat.removeAt(existingIndex);
        }
      });
    }
    _hitungTotal();
  }

  // Hitung total belanja
  void _hitungTotal() {
    double total = 0.0;
    for (var item in keranjangObat) {
      total += (item['total_harga'] ?? 0.0) * item['jumlah_beli'];
    }
    setState(() {
      totalTagihan = total;
    });
  }

  // Hitung kembalian
  void _hitungKembalian(String value) {
    double uang = double.tryParse(value) ?? 0.0;
    setState(() {
      uangDiterima = uang;
      kembalian = uangDiterima - totalTagihan;
    });
  }

  // Proses pembelian obat
  Future<void> _prosesPembelian() async {
    if (keranjangObat.isEmpty) {
      _showSnackBar('Keranjang belanja kosong!', isError: true);
      return;
    }

    if (selectedMetodePembayaran == null) {
      _showSnackBar('Pilih metode pembayaran!', isError: true);
      return;
    }

    if (selectedMetodePembayaran!['nama_metode'] == 'Tunai / Cash' && 
        uangDiterima < totalTagihan) {
      _showSnackBar('Uang yang diterima kurang!', isError: true);
      return;
    }

    setState(() => isProcessing = true);

    try {
      final token = await getToken();
      final pasienId = await getPasienId();

      if (token == null || pasienId == null) {
        _showSnackBar('Session expired. Silakan login ulang.', isError: true);
        return;
      }

      final kodeTransaksi = 'TXN-${DateTime.now().millisecondsSinceEpoch}';
      final List<Map<String, dynamic>> transaksiData = [];

      for (var item in keranjangObat) {
        transaksiData.add({
          'pasien_id': pasienId,
          'obat_id': item['id'],
          'metode_pembayaran_id': selectedMetodePembayaran!['id'],
          'kode_transaksi': kodeTransaksi,
          'jumlah': item['jumlah_beli'],
          'total_tagihan': totalTagihan,
          'uang_yang_diterima': selectedMetodePembayaran!['nama_metode'] == 'Tunai / Cash' 
              ? uangDiterima : totalTagihan,
          'kembalian': selectedMetodePembayaran!['nama_metode'] == 'Tunai / Cash' 
              ? kembalian : 0,
          'sub_total': (item['total_harga'] ?? 0.0) * item['jumlah_beli'],
          'tanggal_transaksi': DateTime.now().toIso8601String(),
          'status': 'Sudah Bayar',
        });
      }

      final response = await http.post(
        Uri.parse('https://admin.royal-klinik.cloud/api/penjualan-obat/store'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'transaksi_data': transaksiData,
        }),
      );

      print('📡 prosesPembelian - Status: ${response.statusCode}');
      print('📄 prosesPembelian - Body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _showSuccessDialog(kodeTransaksi);
        } else {
          _showSnackBar(data['message'] ?? 'Gagal memproses pembelian', isError: true);
        }
      } else {
        _showSnackBar('Gagal memproses pembelian. Status: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      print('❌ prosesPembelian Error: $e');
      _showSnackBar('Terjadi kesalahan: $e', isError: true);
    } finally {
      setState(() => isProcessing = false);
    }
  }

  void _showSuccessDialog(String kodeTransaksi) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: Icon(
            Icons.check_circle,
            color: Colors.green.shade600,
            size: 64,
          ),
          title: const Text(
            'Pembelian Berhasil!',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Kode Transaksi:',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 4),
              Text(
                kodeTransaksi,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              if (selectedMetodePembayaran!['nama_metode'] == 'Tunai / Cash' && kembalian > 0)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Kembalian:',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      Text(
                        formatCurrency(kembalian),
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _resetForm();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Selesai',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _resetForm() {
    setState(() {
      keranjangObat.clear();
      selectedMetodePembayaran = null;
      totalTagihan = 0.0;
      uangDiterima = 0.0;
      kembalian = 0.0;
    });
    _uangDiterimaController.clear();
    fetchDaftarObat(); // Refresh stok obat
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  String formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    )}';
  }

  int _getJumlahDiKeranjang(int obatId) {
    final item = keranjangObat.firstWhere(
      (item) => item['id'] == obatId,
      orElse: () => {},
    );
    return item['jumlah_beli'] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Pembelian Obat',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (keranjangObat.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16),
              child: Stack(
                children: [
                  IconButton(
                    onPressed: () => _showKeranjangDialog(),
                    icon: const Icon(Icons.shopping_cart),
                  ),
                  if (keranjangObat.isNotEmpty)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          keranjangObat.length.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? _buildErrorState()
              : _buildContent(),
      bottomNavigationBar: keranjangObat.isNotEmpty 
          ? _buildBottomCheckoutButton() 
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
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Oops!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  isLoading = true;
                  errorMessage = null;
                });
                fetchDaftarObat();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (daftarObat.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medical_services_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada obat tersedia',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: daftarObat.length,
      itemBuilder: (context, index) {
        final obat = daftarObat[index];
        final jumlahDiKeranjang = _getJumlahDiKeranjang(obat['id']);
        final stokTersedia = (obat['jumlah'] ?? 0) - jumlahDiKeranjang;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
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
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00897B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.medication,
                        color: Color(0xFF00897B),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            obat['nama_obat'] ?? 'Nama obat tidak tersedia',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Dosis: ${obat['dosis']?.toString() ?? '-'} mg',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Stok: $stokTersedia',
                            style: TextStyle(
                              fontSize: 14,
                              color: stokTersedia > 0 
                                  ? Colors.green.shade600 
                                  : Colors.red.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatCurrency(obat['total_harga']?.toDouble() ?? 0.0),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00897B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (jumlahDiKeranjang > 0)
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => _kurangiDariKeranjang(obat),
                            icon: const Icon(Icons.remove_circle_outline),
                            color: Colors.red.shade600,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.red.shade50,
                              minimumSize: const Size(36, 36),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              jumlahDiKeranjang.toString(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: stokTersedia > 0 
                                ? () => _tambahKeKeranjang(obat)
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                            color: stokTersedia > 0 
                                ? const Color(0xFF00897B)
                                : Colors.grey.shade400,
                            style: IconButton.styleFrom(
                              backgroundColor: stokTersedia > 0 
                                  ? const Color(0xFF00897B).withOpacity(0.1)
                                  : Colors.grey.shade100,
                              minimumSize: const Size(36, 36),
                            ),
                          ),
                        ],
                      )
                    else
                      const SizedBox.shrink(),
                    
                    if (jumlahDiKeranjang == 0)
                      ElevatedButton.icon(
                        onPressed: stokTersedia > 0 
                            ? () => _tambahKeKeranjang(obat)
                            : null,
                        icon: const Icon(Icons.add_shopping_cart, size: 18),
                        label: const Text('Tambah'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: stokTersedia > 0 
                              ? const Color(0xFF00897B)
                              : Colors.grey.shade400,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomCheckoutButton() {
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
                    'Total Belanja:',
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
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => _showCheckoutDialog(),
                  icon: const Icon(Icons.payment, size: 20),
                  label: Text(
                    'Checkout (${keranjangObat.length} item)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showKeranjangDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Keranjang Belanja',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: keranjangObat.length,
              itemBuilder: (context, index) {
                final item = keranjangObat[index];
                final subtotal = (item['total_harga'] ?? 0.0) * item['jumlah_beli'];
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['nama_obat'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${item['jumlah_beli']}x ${formatCurrency(item['total_harga'] ?? 0.0)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            formatCurrency(subtotal),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00897B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  void _showCheckoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Checkout Pembayaran',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ringkasan belanja
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ringkasan Belanja:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          ...keranjangObat.map((item) {
                            final subtotal = (item['total_harga'] ?? 0.0) * item['jumlah_beli'];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${item['nama_obat']} (${item['jumlah_beli']}x)',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                  Text(
                                    formatCurrency(subtotal),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                formatCurrency(totalTagihan),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF00897B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Metode pembayaran
                    const Text(
                      'Pilih Metode Pembayaran:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    
                    if (isLoadingMetode)
                      const Center(child: CircularProgressIndicator())
                    else
                      ...metodePembayaran.map((metode) {
                        final isSelected = selectedMetodePembayaran?['id'] == metode['id'];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () {
                              setDialogState(() {
                                selectedMetodePembayaran = metode;
                              });
                              setState(() {
                                selectedMetodePembayaran = metode;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isSelected 
                                      ? const Color(0xFF00897B) 
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                color: isSelected 
                                    ? const Color(0xFF00897B).withOpacity(0.1)
                                    : Colors.white,
                              ),
                              child: Row(
                                children: [
                                  Text(
                                    metode['icon'] ?? '💳',
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      metode['nama_metode'] ?? '',
                                      style: TextStyle(
                                        fontWeight: isSelected 
                                            ? FontWeight.w600 
                                            : FontWeight.normal,
                                        color: isSelected 
                                            ? const Color(0xFF00897B)
                                            : Colors.black87,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF00897B),
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    
                    // Input uang diterima untuk tunai
                    if (selectedMetodePembayaran?['nama_metode'] == 'Tunai / Cash') ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Uang Diterima:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _uangDiterimaController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          hintText: 'Masukkan jumlah uang diterima',
                          prefixText: 'Rp ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF00897B)),
                          ),
                        ),
                        onChanged: (value) {
                          _hitungKembalian(value);
                          setDialogState(() {});
                        },
                      ),
                      if (uangDiterima > 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: kembalian >= 0 
                                ? Colors.green.shade50 
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: kembalian >= 0 
                                  ? Colors.green.shade200 
                                  : Colors.red.shade200,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                kembalian >= 0 ? 'Kembalian:' : 'Kurang:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: kembalian >= 0 
                                      ? Colors.green.shade700 
                                      : Colors.red.shade700,
                                ),
                              ),
                              Text(
                                formatCurrency(kembalian.abs()),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: kembalian >= 0 
                                      ? Colors.green.shade700 
                                      : Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: isProcessing ? null : () {
                    Navigator.of(context).pop();
                    _prosesPembelian();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00897B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Bayar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}