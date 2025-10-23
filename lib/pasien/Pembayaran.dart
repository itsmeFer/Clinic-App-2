import 'dart:async';
import 'dart:convert';
import 'package:RoyalClinic/pasien/dashboardScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Tambahkan dependency ini

class Pembayaran extends StatefulWidget {
  final int? kunjunganId;
  final bool fromList;
  
  const Pembayaran({
    super.key,
    this.kunjunganId,
    this.fromList = false,
  });

  @override
  State<Pembayaran> createState() => _PembayaranState();
}

class _PembayaranState extends State<Pembayaran> {
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? pembayaranData;
  
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
        Uri.parse('http://10.227.74.71:8000/api/pembayaran/get-data-metode-pembayaran'),
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
          print('✅ Loaded ${metodePembayaran.length} metode pembayaran from database');
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
      
      if (token == null) {
        setState(() {
          errorMessage = 'Token tidak ditemukan';
          isLoading = false;
        });
        return;
      }

      // Check SharedPreferences untuk detect dari list
      final prefs = await SharedPreferences.getInstance();
      final selectedKunjunganId = prefs.getInt('selected_kunjungan_id');
      final fromListPayment = prefs.getBool('from_list_payment') ?? false;

      String url;
      
      if (selectedKunjunganId != null && fromListPayment) {
        // Dari ListPembayaran - ambil detail specific kunjungan
        url = 'http://10.227.74.71:8000/api/pembayaran/detail/$selectedKunjunganId';
        print('🔍 Using specific kunjungan_id from SharedPreferences: $selectedKunjunganId');
      } else if (widget.kunjunganId != null) {
        // Dari parameter constructor (fallback)
        url = 'http://10.227.74.71:8000/api/pembayaran/detail/${widget.kunjunganId}';
        print('🔍 Using kunjunganId from constructor: ${widget.kunjunganId}');
      } else {
        // Original behavior - ambil dari pasien_id
        final pasienId = await getPasienId();
        if (pasienId == null) {
          setState(() {
            errorMessage = 'ID pasien tidak ditemukan';
            isLoading = false;
          });
          return;
        }
        url = 'http://10.227.74.71:8000/api/pembayaran/pasien/$pasienId';
        print('🔍 Using original behavior with pasien_id: $pasienId');
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('📡 fetchPembayaranData - URL: $url');
      print('📡 fetchPembayaranData - Status: ${response.statusCode}');
      print('📄 fetchPembayaranData - Body: ${response.body}');

      if (!mounted) return;

      if (response.body.startsWith('<') || response.body.contains('<script>')) {
        setState(() {
          errorMessage = 'Server mengembalikan HTML alih-alih JSON. Cek Laravel log untuk error details.';
          isLoading = false;
        });
        return;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            // Handle response yang berbeda
            if (selectedKunjunganId != null && fromListPayment) {
              // Dari endpoint detail - data langsung
              pembayaranData = data['data'];
            } else if (widget.kunjunganId != null) {
              // Dari parameter constructor - data langsung
              pembayaranData = data['data'];
            } else {
              // Dari endpoint pasien - ambil payment pertama jika multiple
              if (data['data']['payments'] != null) {
                pembayaranData = data['data']['payments'][0];
              } else {
                pembayaranData = data['data'];
              }
            }
            isLoading = false;
          });
          
          // Debug print kode transaksi dan metode pembayaran
          print('🔍 Kode Transaksi: ${pembayaranData?['kode_transaksi']}');
          print('🔍 Metode Pembayaran: ${pembayaranData?['metode_pembayaran']}');
          print('🔍 Metode Pembayaran Nama: ${pembayaranData?['metode_pembayaran_nama']}');
        } else {
          setState(() {
            errorMessage = data['message'] ?? 'Gagal memuat data pembayaran';
            isLoading = false;
          });
        }
      } else if (response.statusCode == 400) {
        // HANDLE: Status 400 could mean payment is already completed
        final data = jsonDecode(response.body);
        if (data['message']?.toString().toLowerCase().contains('sudah selesai') == true) {
          // Payment is completed, create mock data for display
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
              'layanan': [],
              'resep_obat': [],
              'total_layanan': 0,
              'total_obat': 0,
            };
            isLoading = false;
          });
          
          // Auto show success dialog since payment is completed
          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted) {
              _showPaymentSuccessDialog();
            }
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
          errorMessage = 'Gagal memuat data pembayaran (Status: ${response.statusCode})';
          isLoading = false;
        });
      }
    } catch (e) {
      print('❌ fetchPembayaranData Error: $e');
      if (mounted) {
        setState(() {
          if (e.toString().contains('FormatException')) {
            errorMessage = 'Server mengembalikan format tidak valid. Silakan hubungi admin.';
          } else {
            errorMessage = 'Kesalahan koneksi: $e';
          }
          isLoading = false;
        });
      }
    }
  }

  // CHANGED: Check payment status without showing cashier dialog
  Future<void> cekStatusPembayaran() async {
    try {
      setState(() => isLoading = true);
      
      // Refresh payment data to get latest status
      await fetchPembayaranData();
      
      if (!mounted) return;
      
      setState(() => isLoading = false);
      
      // Check if payment is now completed
      if (pembayaranData != null && pembayaranData!['status_pembayaran'] == 'Sudah Bayar') {
        _showPaymentSuccessDialog();
      } else {
        // Still not paid, show info message
        _showErrorSnackBar('Pembayaran belum selesai. Silakan cek kembali setelah melakukan pembayaran di kasir.');
      }
    } catch (e) {
      print('Error cek status pembayaran: $e');
      setState(() => isLoading = false);
      _showErrorSnackBar('Kesalahan: ${e.toString()}');
    }
  }

  // NEW: Show payment success dialog with navigation to dashboard
  void _showPaymentSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success animation container
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green.shade600,
                  size: 50,
                ),
              ),
              SizedBox(height: 24),
              
              // Success title
              Text(
                'Pembayaran Berhasil!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 12),
              
              // Success message
              Text(
                'Terima kasih! Pembayaran Anda telah berhasil diproses.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 8),
              
              // Additional info
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Anda dapat mengambil obat di apoteker klinik',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 24),
              
              // OK button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    
                    // Navigate to MainWrapper (dashboard) - replace all routes
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const MainWrapper()),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF00897B),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'Kembali ke Dashboard',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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

  // NEW: Show QR Code dialog
  void _showQRCodeDialog() {
    final kodeTransaksi = pembayaranData?['kode_transaksi'];
    
    if (kodeTransaksi == null) {
      _showErrorSnackBar('Kode transaksi tidak tersedia');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.qr_code, color: Color(0xFF00897B), size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'QR Code Pembayaran',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: Colors.grey.shade600),
                  ),
                ],
              ),
              SizedBox(height: 20),
              
              // QR Code
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: QrImageView(
                  data: kodeTransaksi,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                ),
              ),
              
              SizedBox(height: 16),
              
              // Kode Transaksi Text
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    Text(
                      'Kode Transaksi:',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    SelectableText(
                      kodeTransaksi,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              
              SizedBox(height: 16),
              
              // Copy button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: kodeTransaksi));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Kode transaksi disalin ke clipboard'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: Icon(Icons.copy, size: 18),
                  label: Text('Salin Kode'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF00897B),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              
              SizedBox(height: 12),
              
              Text(
                'Tunjukkan QR code ini kepada petugas kasir atau salin kode transaksi untuk pembayaran',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // UPDATED: Show payment at cashier dialog dengan kode transaksi dan metode pembayaran dari database
  void _showPaymentAtCashierDialog() {
    setState(() => isLoading = false);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.store, color: Color(0xFF00897B), size: 24),
            SizedBox(width: 12),
            Text('Pembayaran di Kasir'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Silakan lakukan pembayaran di kasir klinik',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 16),
            
            // TAMPILKAN KODE TRANSAKSI JIKA ADA
            if (pembayaranData?['kode_transaksi'] != null) ...[
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long, color: Colors.orange.shade700, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Kode Transaksi:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        Spacer(),
                        // NEW: QR Code button
                        IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _showQRCodeDialog();
                          },
                          icon: Icon(Icons.qr_code, 
                            color: Colors.orange.shade700, 
                            size: 20
                          ),
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(minWidth: 24, minHeight: 24),
                          tooltip: 'Tampilkan QR Code',
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    SelectableText(
                      pembayaranData!['kode_transaksi'],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                        fontFamily: 'monospace',
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Tunjukkan kode ini kepada kasir',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
            ],
            
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Pembayaran:',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    formatCurrency(pembayaranData!['total_tagihan']),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00897B),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            
            // TAMPILKAN METODE PEMBAYARAN DARI DATABASE
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.payment, color: Colors.green.shade700, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Metode Pembayaran Tersedia:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  
                  // DYNAMIC PAYMENT METHODS dari database
                  if (isLoadingMetode)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.green.shade600,
                          ),
                        ),
                      ),
                    )
                  else if (metodePembayaran.isEmpty)
                    Text(
                      '• Metode pembayaran akan ditentukan di kasir',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade600,
                      ),
                    )
                  else
                    ...metodePembayaran.map((metode) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Text(
                              metode['icon'] ?? '💳',
                              style: TextStyle(fontSize: 12),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '• ${metode['nama_metode'] ?? 'Unknown'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              pembayaranData?['kode_transaksi'] != null 
                  ? 'Tunjukkan kode transaksi ini kepada petugas kasir. Anda dapat memilih metode pembayaran yang diinginkan di kasir.'
                  : 'Silakan menuju kasir untuk menyelesaikan pembayaran. Anda dapat memilih metode pembayaran yang diinginkan di kasir.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Batal'),
          ),
          if (pembayaranData?['kode_transaksi'] != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showQRCodeDialog();
              },
              child: Text('QR Code'),
              style: TextButton.styleFrom(
                foregroundColor: Color(0xFF00897B),
              ),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccessDialog();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF00897B),
              foregroundColor: Colors.white,
            ),
            child: Text('Menuju Kasir'),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green.shade600,
                size: 60,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Siap untuk Pembayaran!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              pembayaranData?['kode_transaksi'] != null
                  ? 'Silakan menuju kasir untuk menyelesaikan pembayaran dengan kode transaksi yang telah diberikan.\nSetelah pembayaran selesai, Anda dapat mengambil obat di apoteker.'
                  : 'Silakan menuju kasir untuk menyelesaikan pembayaran.\nSetelah pembayaran selesai, Anda dapat mengambil obat di apoteker.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (widget.fromList) {
                    // Jika dari list, kembali ke list
                    Navigator.of(context).pop();
                  } else {
                    // Jika bukan dari list, tetap di halaman ini
                    Navigator.of(context).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Selesai',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
        duration: Duration(seconds: 5),
      ),
    );
  }

  String formatCurrency(dynamic amount) {
    double value;
    if (amount is String) {
      value = double.tryParse(amount) ?? 0.0;
    } else if (amount is int) {
      value = amount.toDouble();
    } else if (amount is double) {
      value = amount;
    } else {
      value = 0.0;
    }
    
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

  bool get canMakePayment {
    if (pembayaranData == null) return false;
    return pembayaranData!['status_pembayaran'] != 'Sudah Bayar';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          widget.fromList ? 'Detail Pembayaran' : 'Pembayaran',
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
        automaticallyImplyLeading: false, // REMOVE back button
        actions: [
          // NEW: QR Code action button (keep only this one)
          if (pembayaranData?['kode_transaksi'] != null)
            IconButton(
              icon: const Icon(Icons.qr_code),
              onPressed: _showQRCodeDialog,
              tooltip: 'Tampilkan QR Code',
            ),
          // REMOVED: Refresh button
        ],
      ),
      body: Stack(
        children: [
          // Main content
          isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF00897B),
                  ),
                )
              : errorMessage != null
                  ? _buildErrorState()
                  : pembayaranData == null
                      ? _buildNoDataState()
                      : _buildContent(),
        ],
      ),
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
            if (widget.fromList)
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
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
                child: const Text('Kembali'),
              )
            else
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    isLoading = true;
                    errorMessage = null;
                  });
                  fetchPembayaranData();
                  fetchMetodePembayaran();
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
            Icons.receipt_long,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'Tidak ada pembayaran',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusCard(),
                const SizedBox(height: 16),
                _buildPatientInfo(),
                const SizedBox(height: 16),
                _buildMedicalServices(),
                const SizedBox(height: 16),
                _buildMedicationsList(),
                const SizedBox(height: 16),
                _buildPaymentSummary(),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
        
        if (pembayaranData!['status_pembayaran'] == 'Sudah Bayar')
          _buildAlreadyPaidInfo()
        else
          _buildBottomPaymentButton(),
      ],
    );
  }

  Widget _buildStatusCard() {
    final status = pembayaranData!['status_pembayaran'] ?? 'Belum Bayar';
    final isPaymentComplete = status == 'Sudah Bayar';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPaymentComplete ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPaymentComplete ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPaymentComplete ? Icons.check_circle : Icons.schedule,
            color: isPaymentComplete ? Colors.green.shade600 : Colors.orange.shade600,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPaymentComplete ? 'Pembayaran Selesai' : 'Menunggu Pembayaran',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isPaymentComplete ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPaymentComplete 
                      ? 'Silakan ambil obat di apoteker klinik'
                      : 'Silakan lakukan pembayaran di kasir terlebih dahulu',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // UPDATED: Tambahkan kode transaksi ke patient info dengan QR code button
  Widget _buildPatientInfo() {
    final pasien = pembayaranData!['pasien'];
    final poli = pembayaranData!['poli'];
    final tanggalKunjungan = pembayaranData!['tanggal_kunjungan'];
    
    return Container(
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Pasien', pasien?['nama_pasien'] ?? 'Tidak ada'),
          _buildInfoRow('Poli', poli?['nama_poli'] ?? 'Tidak ada'),
          _buildInfoRow('Tanggal', formatDate(tanggalKunjungan ?? '')),
          _buildInfoRow('No. Antrian', pembayaranData!['no_antrian'] ?? '-'),
          _buildInfoRow('Diagnosis', pembayaranData!['diagnosis'] ?? '-'),
          
          // TAMBAHKAN KODE TRANSAKSI DI SINI dengan QR button
          if (pembayaranData!['kode_transaksi'] != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.shade200, width: 1),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.qr_code,
                    color: Colors.orange.shade700,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kode Transaksi:',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SelectableText(
                          pembayaranData!['kode_transaksi'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade800,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  // NEW: QR Code mini button
                  IconButton(
                    onPressed: _showQRCodeDialog,
                    icon: Icon(Icons.fullscreen, 
                      color: Colors.orange.shade700, 
                      size: 16
                    ),
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Lihat QR Code',
                  ),
                ],
              ),
            ),
          ],
          
          // TAMPILKAN METODE PEMBAYARAN JIKA ADA
          if (pembayaranData!['metode_pembayaran_nama'] != null || pembayaranData!['metode_pembayaran'] != null)
            _buildInfoRow(
              'Metode Pembayaran',
              pembayaranData!['metode_pembayaran_nama'] ?? pembayaranData!['metode_pembayaran'] ?? 'Cash'
            ),
        ],
      ),
    );
  }

  Widget _buildMedicalServices() {
    final layananList = pembayaranData!['layanan'] as List<dynamic>? ?? [];
    
    return Container(
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
                  Icons.medical_services,
                  color: Color(0xFF00897B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Layanan Medis',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (layananList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Tidak ada layanan',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            )
          else
            ...layananList.map((layanan) {
              final namaLayanan = layanan['nama_layanan']?.toString() ?? 'Layanan';
              final hargaLayanan = toDoubleValue(layanan['harga_layanan']);
              final jumlah = layanan['jumlah'] ?? 1;
              final subtotal = toDoubleValue(layanan['subtotal']);
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            namaLayanan,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${jumlah}x @ ${formatCurrency(hargaLayanan)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatCurrency(subtotal),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00897B),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildMedicationsList() {
    final resepObat = pembayaranData!['resep_obat'] as List<dynamic>? ?? [];
    
    return Container(
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
                  Icons.medication,
                  color: Color(0xFF00897B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Obat-obatan',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (resepObat.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Tidak ada resep obat',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            )
          else
            ...resepObat.asMap().entries.map((entry) {
              return _buildMedicationItem(entry.value);
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildMedicationItem(Map<String, dynamic> obat) {
    final isReady = obat['status'] == 'Sudah Diambil';
    final obatData = obat['obat'] ?? {};
    
    final hargaObat = toDoubleValue(obatData['harga_obat']);
    final jumlah = toDoubleValue(obat['jumlah']);
    final hargaTotal = hargaObat * jumlah;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isReady ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isReady ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isReady ? Colors.green.shade100 : Colors.orange.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              isReady ? Icons.check_circle : Icons.schedule,
              color: isReady ? Colors.green.shade600 : Colors.orange.shade600,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  obatData['nama_obat']?.toString() ?? 'Obat',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${jumlah.toInt()}x - ${obat['keterangan']?.toString() ?? 'Sesuai anjuran dokter'}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  isReady ? 'Sudah diambil' : 'Belum diambil',
                  style: TextStyle(
                    fontSize: 10,
                    color: isReady ? Colors.green.shade600 : Colors.orange.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatCurrency(hargaTotal),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF00897B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummary() {
    final totalTagihan = toDoubleValue(pembayaranData!['total_tagihan']);
    final totalLayanan = toDoubleValue(pembayaranData!['total_layanan'] ?? 0);
    final totalObat = toDoubleValue(pembayaranData!['total_obat'] ?? 0);
    
    return Container(
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          if (totalLayanan > 0)
            _buildSummaryRow('Total Layanan', formatCurrency(totalLayanan)),
          
          if (totalObat > 0)
            _buildSummaryRow('Total Obat', formatCurrency(totalObat)),
          
          const Divider(height: 24),
          
          _buildSummaryRow(
            'Total Pembayaran', 
            formatCurrency(totalTagihan), 
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPaymentButton() {
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
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
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
              
              // NEW: Two buttons side by side
              Row(
                children: [
                  // Bayar Nanti button
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Navigate back to ListPembayaran
                          Navigator.of(context).pop();
                        },
                        icon: Icon(Icons.schedule, size: 20),
                        label: Text(
                          'Bayar Nanti',
                          style: const TextStyle(
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
                        icon: Icon(Icons.refresh, size: 20),
                        label: Text(
                          'Cek Status Pembayaran',
                          style: const TextStyle(
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
              Icon(
                Icons.check_circle,
                color: Colors.green.shade600,
                size: 20,
              ),
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
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(fontSize: 12),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
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