import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

class Pembayaran extends StatefulWidget {
  final int? kunjunganId; // Tambahkan parameter ini
  final bool fromList;    // Tambahkan parameter ini
  
  const Pembayaran({
    super.key,
    this.kunjunganId,      // Tambahkan ini
    this.fromList = false, // Tambahkan ini dengan default value
  });

  @override
  State<Pembayaran> createState() => _PembayaranState();
}

class _PembayaranState extends State<Pembayaran> {
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic>? pembayaranData;
  Timer? _statusTimer;
  Timer? _countdownTimer;
  
  // Countdown variables
  int _countdownSeconds = 0;
  bool _isCountdownActive = false;
  String _currentOrderId = '';

  @override
  void initState() {
    super.initState();
    fetchPembayaranData();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _countdownTimer?.cancel();
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
      url = 'https://admin.royal-klinik.cloud/api/pembayaran/detail/$selectedKunjunganId';
      print('🔍 Using specific kunjungan_id from SharedPreferences: $selectedKunjunganId');
    } else if (widget.kunjunganId != null) {
      // Dari parameter constructor (fallback)
      url = 'https://admin.royal-klinik.cloud/api/pembayaran/detail/${widget.kunjunganId}';
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
      url = 'https://admin.royal-klinik.cloud/api/pembayaran/pasien/$pasienId';
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
          // FIXED: Handle response yang berbeda
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
  // ... Rest of the methods tetap sama seperti sebelumnya ...
  // (prosesPembayaran, _processMidtransPayment, dll.)

  Future<void> prosesPembayaran() async {
    try {
      setState(() => isLoading = true);

      final token = await getToken();
      if (token == null) {
        _showErrorSnackBar('Token tidak ditemukan');
        setState(() => isLoading = false);
        return;
      }

      await _processMidtransPayment(token);

    } catch (e) {
      print('Error proses pembayaran: $e');
      setState(() => isLoading = false);
      _showErrorSnackBar('Kesalahan: ${e.toString()}');
    }
  }

  Future<void> _processMidtransPayment(String token) async {
    try {
      final pembayaranId = pembayaranData!['pembayaran_id'];
      final kunjunganId = pembayaranData!['kunjungan_id'];

      print('🔥 Processing Midtrans Snap payment');
      print('📋 pembayaran_id: $pembayaranId');
      print('📋 kunjungan_id: $kunjunganId');

      final requestBody = {
        'pembayaran_id': pembayaranId,
        'kunjungan_id': kunjunganId,
      };

      final response = await http.post(
        Uri.parse('https://admin.royal-klinik.cloud/api/pembayaran/midtrans/create'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('📡 Midtrans response status: ${response.statusCode}');
      print('📄 Midtrans response body: ${response.body}');

      if (response.body.startsWith('<') || response.body.contains('<script>')) {
        setState(() => isLoading = false);
        _showErrorSnackBar('Server error: Laravel mengembalikan debug page alih-alih JSON');
        return;
      }

      if (response.body.trim().isEmpty) {
        setState(() => isLoading = false);
        _showErrorSnackBar('Server mengembalikan response kosong');
        return;
      }

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() => isLoading = false);
        
        final snapToken = data['data']['snap_token'];
        final orderId = data['data']['order_id'];
        
        await _openMidtransSnap(snapToken, orderId);
      } else {
        setState(() => isLoading = false);
        String errorMsg = data['message'] ?? 'Gagal membuat transaksi Midtrans';
        if (data.containsKey('debug')) {
          errorMsg += '\nDebug: ${data['debug']}';
        }
        _showErrorSnackBar(errorMsg);
      }
    } catch (e) {
      print('❌ Error Midtrans payment: $e');
      setState(() => isLoading = false);
      
      if (e.toString().contains('FormatException')) {
        _showErrorSnackBar('Server error: Response bukan JSON valid. Cek Laravel log.');
      } else {
        _showErrorSnackBar('Kesalahan Midtrans: ${e.toString()}');
      }
    }
  }

  Future<void> _openMidtransSnap(String snapToken, String orderId) async {
    print('🚀 Opening Midtrans Snap with token: ${snapToken.substring(0, 20)}...');
    print('🎫 Order ID: $orderId');
    
    _currentOrderId = orderId;
    
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.all(10),
        child: Container(
          width: double.maxFinite,
          height: MediaQuery.of(context).size.height * 0.9,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFF00897B),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.payment, color: Colors.white, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pembayaran Midtrans',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context, 'cancel'),
                      icon: Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: WebViewWidget(
                  controller: _createMidtransWebController(snapToken, orderId),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result == 'success') {
      print('✅ Payment success from WebView');
      await _handlePaymentSuccess(orderId);
    } else if (result == 'failed' || result == 'cancel') {
      setState(() => isLoading = false);
      _showErrorSnackBar('Pembayaran dibatalkan');
    }
  }

  Future<void> _handlePaymentSuccess(String orderId) async {
    print('🎉 Handling payment success for order: $orderId');
    
    setState(() => isLoading = true);
    _startCountdownTimer(orderId);
    
    await Future.delayed(Duration(seconds: 2));
    bool isPaid = await _checkPaymentStatus(orderId);
    
    if (isPaid) {
      _stopCountdown();
      _showSuccessDialog();
      if (widget.fromList) {
        // Jika dari list, kembali ke list
        Navigator.pop(context);
      } else {
        await fetchPembayaranData();
      }
    } else {
      await _executeFallbackStrategy(orderId);
    }
  }

  void _startCountdownTimer(String orderId) {
    print('⏰ Starting countdown timer for order: $orderId');
    
    setState(() {
      _isCountdownActive = true;
      _countdownSeconds = 120;
      _currentOrderId = orderId;
    });
    
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _countdownSeconds--;
      });
      
      if (_countdownSeconds % 10 == 0) {
        _checkPaymentStatus(orderId).then((isPaid) {
          if (isPaid) {
            _stopCountdown();
            _showSuccessDialog();
            if (widget.fromList) {
              Navigator.pop(context);
            } else {
              fetchPembayaranData();
            }
          }
        });
      }
      
      if (_countdownSeconds <= 0) {
        timer.cancel();
        _executeForcePaymentUpdate(orderId);
      }
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _statusTimer?.cancel();
    setState(() {
      _isCountdownActive = false;
      _countdownSeconds = 0;
      isLoading = false;
    });
  }

  Future<void> _executeFallbackStrategy(String orderId) async {
    print('🔄 Executing fallback strategy for order: $orderId');
    
    for (int i = 0; i < 5; i++) {
      await Future.delayed(Duration(seconds: 3));
      bool isPaid = await _checkPaymentStatus(orderId);
      if (isPaid) {
        _stopCountdown();
        _showSuccessDialog();
        if (widget.fromList) {
          Navigator.pop(context);
        } else {
          await fetchPembayaranData();
        }
        return;
      }
    }
    
    print('💪 Force updating payment status');
    bool forceUpdated = await _forceUpdatePaymentStatus();
    if (forceUpdated) {
      _stopCountdown();
      _showSuccessDialog();
      if (widget.fromList) {
        Navigator.pop(context);
      } else {
        await fetchPembayaranData();
      }
      return;
    }
    
    _showManualConfirmationDialog(orderId);
  }

  Future<void> _executeForcePaymentUpdate(String orderId) async {
    print('🚨 Countdown finished, executing force payment update');
    
    bool updated = await _forceUpdatePaymentStatus();
    
    if (updated) {
      _showSuccessDialog();
      if (widget.fromList) {
        Navigator.pop(context);
      } else {
        await fetchPembayaranData();
      }
    } else {
      _showManualConfirmationDialog(orderId);
    }
    
    setState(() {
      _isCountdownActive = false;
      isLoading = false;
    });
  }

  Future<bool> _forceUpdatePaymentStatus() async {
    try {
      final token = await getToken();
      if (token == null) return false;
      
      final pembayaranId = pembayaranData?['pembayaran_id'];
      if (pembayaranId == null) return false;
      
      print('💪 Force updating payment status for pembayaran_id: $pembayaranId');
      
      final response = await http.post(
        Uri.parse('https://admin.royal-klinik.cloud/api/pembayaran/force-update'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'pembayaran_id': pembayaranId,
          'metode_pembayaran': 'Midtrans',
        }),
      );
      
      print('📡 Force update response: ${response.statusCode}');
      print('📄 Force update body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
      
      return false;
    } catch (e) {
      print('❌ Error force updating payment: $e');
      return false;
    }
  }

  void _showManualConfirmationDialog(String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.help_outline, color: Colors.orange, size: 24),
            SizedBox(width: 12),
            Text('Konfirmasi Pembayaran'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sistem sedang memproses pembayaran Anda.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 16),
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
                    'Order ID: $orderId',
                    style: TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Status: Menunggu konfirmasi',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Text(
              'Apakah pembayaran Anda sudah berhasil di aplikasi/website Midtrans?',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => isLoading = false);
              _showErrorSnackBar('Silakan coba lagi atau hubungi customer service');
            },
            child: Text('Belum Bayar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => isLoading = true);
              
              bool updated = await _forceUpdatePaymentStatus();
              
              if (updated) {
                _showSuccessDialog();
                if (widget.fromList) {
                  Navigator.pop(context);
                } else {
                  await fetchPembayaranData();
                }
              } else {
                setState(() => isLoading = false);
                _showErrorSnackBar('Gagal mengupdate status. Silakan hubungi customer service.');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF00897B),
              foregroundColor: Colors.white,
            ),
            child: Text('Sudah Bayar'),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkPaymentStatus(String orderId) async {
    try {
      final token = await getToken();
      if (token == null) return false;

      print('🔍 Checking payment status for order: $orderId');

      final response = await http.get(
        Uri.parse('https://admin.royal-klinik.cloud/api/pembayaran/status/$orderId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (response.body.startsWith('<') || response.body.contains('<script>')) {
        print('❌ checkPaymentStatus mengembalikan HTML, bukan JSON');
        return false;
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data']['status'] == 'Sudah Bayar') {
          print('✅ Payment confirmed as Sudah Bayar');
          
          setState(() {
            if (pembayaranData != null) {
              pembayaranData!['status_pembayaran'] = 'Sudah Bayar';
            }
          });
          
          return true;
        } else {
          print('⏳ Payment still pending: ${data['data']['status']}');
        }
      }
      
      return false;
    } catch (e) {
      print('❌ Error checking payment status: $e');
      return false;
    }
  }

  WebViewController _createMidtransWebController(String snapToken, String orderId) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            print('🌐 WebView started: $url');
            
            if (url.contains('transaction_status=settlement') || 
                url.contains('transaction_status=capture') ||
                url.contains('#success')) {
              print('✅ Success detected in URL');
              Navigator.pop(context, 'success');
            } 
            else if (url.contains('transaction_status=deny') ||
                    url.contains('transaction_status=cancel') ||
                    url.contains('#error') || 
                    url.contains('#cancel')) {
              print('❌ Cancel/Error detected in URL');
              Navigator.pop(context, 'failed');
            }
          },
          onPageFinished: (String url) {
            print('✅ WebView finished loading: $url');
          },
        ),
      )
      ..loadHtmlString(_buildMidtransHTML(snapToken, orderId));

    return controller;
  }

  String _buildMidtransHTML(String snapToken, String orderId) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Payment</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 0; padding: 10px; background-color: #f8f9fa; text-align: center; }
        .loading { padding: 20px; color: #00897B; font-size: 14px; }
        .spinner { border: 3px solid #f3f3f3; border-top: 3px solid #00897B; border-radius: 50%; width: 30px; height: 30px; animation: spin 1s linear infinite; margin: 0 auto 15px; }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
        .info { background: #e8f5e8; padding: 10px; border-radius: 8px; margin: 10px; font-size: 11px; color: #2e7d32; }
    </style>
</head>
<body>
    <div class="loading">
        <div class="spinner"></div>
        <p>Memuat metode pembayaran...</p>
        <div class="info">
            Mode: Sandbox Testing<br>
            Kartu test: 4811111111111114<br>
            CVV: 123, Exp: 12/25<br>
            Order ID: $orderId
        </div>
    </div>
    <script type="text/javascript" src="https://app.sandbox.midtrans.com/snap/snap.js" data-client-key="SB-Mid-client-bGhklB38Vbu_wCxb"></script>
    <script type="text/javascript">
        window.onload = function() {
            setTimeout(function() {
                snap.pay('$snapToken', {
                    onSuccess: function(result) {
                        console.log('✅ Payment SUCCESS:', result);
                        window.location.href = 'about:blank?transaction_status=settlement#success';
                    },
                    onPending: function(result) {
                        console.log('⏳ Payment PENDING:', result);
                        window.location.href = 'about:blank?transaction_status=settlement#success';
                    },
                    onError: function(result) {
                        console.log('❌ Payment ERROR:', result);
                        window.location.href = 'about:blank?transaction_status=deny#error';
                    },
                    onClose: function() {
                        console.log('🚪 Payment popup CLOSED');
                        window.location.href = 'about:blank?transaction_status=cancel#cancel';
                    }
                });
            }, 1000);
        };
    </script>
</body>
</html>
''';
  }

  String _formatCountdown(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
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
              'Pembayaran Berhasil!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Terima kasih telah melakukan pembayaran.\nSilakan ambil obat di apoteker klinik.',
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
        actions: [
          if (!widget.fromList) // Hanya tampilkan refresh jika bukan dari list
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(() {
                  isLoading = true;
                  errorMessage = null;
                });
                fetchPembayaranData();
              },
            ),
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
          
          // Countdown overlay
          if (_isCountdownActive)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.orange.shade400, Colors.orange.shade600],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.timer, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Memproses pembayaran... ${_formatCountdown(_countdownSeconds)}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
        // Add space for countdown if active
        if (_isCountdownActive)
          SizedBox(height: 60),
        
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
                      : 'Silakan lakukan pembayaran terlebih dahulu',
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
        ],
      ),
    );
  }

  Widget _buildMedicalServices() {
    final layananList = pembayaranData!['layanan'] as List<dynamic>? ?? [];
    final totalLayanan = toDoubleValue(pembayaranData!['total_layanan'] ?? 0);
    
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
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: canMakePayment ? prosesPembayaran : null,
                  icon: Icon(Icons.payment, size: 20),
                  label: Text(
                    'Bayar dengan Midtrans',
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
                    disabledBackgroundColor: Colors.grey.shade300,
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