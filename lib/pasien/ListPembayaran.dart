import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:RoyalClinic/pasien/pembayaran.dart';

class ListPembayaran extends StatefulWidget {
  const ListPembayaran({super.key});

  @override
  State<ListPembayaran> createState() => _ListPembayaranState();
}

class _ListPembayaranState extends State<ListPembayaran> with TickerProviderStateMixin {
  bool isLoading = true;
  String? errorMessage;
  List<Map<String, dynamic>> pembayaranList = [];
  List<Map<String, dynamic>> pembayaranObatList = []; // TAMBAHKAN untuk obat
  List<Map<String, dynamic>> filteredList = [];
  
  // Search and filter controllers
  final TextEditingController _searchController = TextEditingController();
  String _selectedSortBy = 'tanggal_desc';
  String _selectedStatus = 'semua';
  String _selectedType = 'semua'; // TAMBAHKAN filter tipe
  
  // Animated search like artikel page
  bool isSearchActive = false;
  bool isTyping = false;
  
  late AnimationController _searchAnimationController;
  late AnimationController _typingTextController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;
  
  // Typing placeholder animation
  Timer? _typingTimer;
  String _currentText = '';
  final String _fullText = 'Cari nama pasien, poli, kode transaksi, atau diagnosis...';
  
  // Debounce for search
  DateTime? _lastTypeTs;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controllers
    _searchAnimationController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 300),
    );
    _typingTextController = AnimationController(
      vsync: this, 
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _searchAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    _colorAnimation = ColorTween(
      begin: Colors.grey.shade500,
      end: const Color(0xFF00897B),
    ).animate(_searchAnimationController);

    _startTypingAnimation();
    
    fetchListPembayaran();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _typingTextController.dispose();
    _searchAnimationController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _startTypingAnimation() {
    _typingTimer?.cancel();
    _currentText = '';
    _typingTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted) return;
      if (_searchController.text.isEmpty && !isSearchActive) {
        setState(() {
          if (_currentText.length < _fullText.length) {
            _currentText = _fullText.substring(0, _currentText.length + 1);
          } else {
            // Hold then reset
            Future.delayed(const Duration(milliseconds: 2200), () {
              if (!mounted) return;
              if (_searchController.text.isEmpty && !isSearchActive) {
                setState(() => _currentText = '');
                _startTypingAnimation();
              }
            });
            timer.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _onSearchChanged() {
    isTyping = _searchController.text.isNotEmpty;
    isSearchActive = _searchController.text.isNotEmpty;

    if (isSearchActive) {
      _searchAnimationController.forward();
    } else {
      _searchAnimationController.reverse();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        if (_searchController.text.isEmpty) _startTypingAnimation();
      });
    }

    // Debounce 250ms
    _lastTypeTs = DateTime.now();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      if (_lastTypeTs != null &&
          DateTime.now().difference(_lastTypeTs!) >= const Duration(milliseconds: 250)) {
        setState(() => _applyFiltersAndSort());
      }
    });
  }

  void clearSearch() {
    _searchController.clear();
    _searchAnimationController.reverse();
    setState(() {
      isSearchActive = false;
      isTyping = false;
      _applyFiltersAndSort();
    });
    _startTypingAnimation();
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<int?> getPasienId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('pasien_id');
  }

  // MODIFIKASI: Fetch both medical and medicine payments
  Future<void> fetchListPembayaran() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final token = await getToken();
      final pasienId = await getPasienId();

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

      // Fetch medical payments (existing code)
      await _fetchMedicalPayments(token, pasienId);
      
      // TAMBAHKAN: Fetch medicine payments
      await _fetchMedicinePayments(token, pasienId);

      setState(() {
        _combineAndSortPayments();
        isLoading = false;
      });

    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Terjadi kesalahan koneksi. Silakan coba lagi.';
          isLoading = false;
        });
      }
    }
  }

  // TAMBAHKAN: Method untuk fetch pembayaran obat
  Future<void> _fetchMedicinePayments(String token, int pasienId) async {
    try {
      final url = 'https://admin.royal-klinik.cloud/api/penjualan-obat/riwayat/$pasienId';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('📊 Medicine payments response: ${response.statusCode}');
      print('📄 Medicine payments body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          List<dynamic> medicineData = data['data'];
          pembayaranObatList = medicineData.map((item) => _processMedicinePayment(item)).toList();
          print('✅ Loaded ${pembayaranObatList.length} medicine payments');
        }
      }
    } catch (e) {
      print('❌ Error fetching medicine payments: $e');
    }
  }

  // TAMBAHKAN: Process medicine payment data
  Map<String, dynamic> _processMedicinePayment(dynamic item) {
    if (item == null) return _createEmptyMedicinePayment();

    return {
      'id': item['kode_transaksi'],
      'type': 'medicine', // TAMBAHKAN identifier
      'total_tagihan': item['total_tagihan'] ?? 0,
      'status_pembayaran': item['status'] ?? 'Belum Bayar',
      'kode_transaksi': item['kode_transaksi'],
      'tanggal_pembayaran': item['tanggal_transaksi'],
      'tanggal_kunjungan': item['tanggal_transaksi'], // Use same date
      'no_antrian': null,
      'diagnosis': 'Pembelian Obat',
      'metode_pembayaran_nama': item['metode_pembayaran'],
      'pasien': {
        'nama_pasien': 'Pembelian Obat',
      },
      'poli': {
        'nama_poli': 'Apotek',
      },
      'resep': item['items'] ?? [],
      'layanan': [],
      'items': item['items'] ?? [], // Medicine items
      'total_items': item['total_items'] ?? 0,
      'is_emr_missing': false,
      'is_payment_missing': false,
      'uang_yang_diterima': item['uang_yang_diterima'],
      'kembalian': item['kembalian'],
    };
  }

  Map<String, dynamic> _createEmptyMedicinePayment() {
    return {
      'id': null,
      'type': 'medicine',
      'total_tagihan': 0,
      'status_pembayaran': 'Belum Bayar',
      'kode_transaksi': null,
      'tanggal_pembayaran': null,
      'tanggal_kunjungan': DateTime.now().toString(),
      'no_antrian': null,
      'diagnosis': 'Pembelian Obat',
      'metode_pembayaran_nama': null,
      'pasien': {'nama_pasien': 'Pembelian Obat'},
      'poli': {'nama_poli': 'Apotek'},
      'resep': [],
      'layanan': [],
      'items': [],
      'is_emr_missing': false,
      'is_payment_missing': false,
    };
  }

  // MODIFIKASI: Existing method untuk medical payments
  Future<void> _fetchMedicalPayments(String token, int pasienId) async {
    try {
      // Try list endpoint first
      final listUrl = 'https://admin.royal-klinik.cloud/api/pembayaran/list/$pasienId';
      final listResponse = await http.get(
        Uri.parse(listUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (listResponse.statusCode == 200) {
        final data = jsonDecode(listResponse.body);
        if (data['success'] == true && data['data'] != null) {
          pembayaranList = _processPembayaranData(data['data']);
          return;
        }
      }

      // Fallback to patient endpoint
      final patientUrl = 'https://admin.royal-klinik.cloud/api/pembayaran/pasien/$pasienId';
      final patientResponse = await http.get(
        Uri.parse(patientUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (patientResponse.statusCode == 200) {
        final data = jsonDecode(patientResponse.body);
        if (data['success'] == true && data['data'] != null) {
          if (data['data']['payments'] != null) {
            pembayaranList = _processPembayaranData(data['data']['payments']);
          } else {
            pembayaranList = [_processSinglePembayaran(data['data'])];
          }
          return;
        }
      }

      pembayaranList = [];
    } catch (e) {
      print('❌ Error fetching medical payments: $e');
      pembayaranList = [];
    }
  }

  // TAMBAHKAN: Combine and sort all payments
  void _combineAndSortPayments() {
    List<Map<String, dynamic>> allPayments = [];
    
    // Add medical payments with type identifier
    for (var payment in pembayaranList) {
      payment['type'] = 'medical';
      allPayments.add(payment);
    }
    
    // Add medicine payments
    allPayments.addAll(pembayaranObatList);
    
    // Sort by date (newest first)
    allPayments.sort((a, b) {
      final dateA = _parseDate(a['tanggal_kunjungan']);
      final dateB = _parseDate(b['tanggal_kunjungan']);
      return dateB.compareTo(dateA);
    });
    
    // Set as filtered list for display
    filteredList = allPayments;
    _applyFiltersAndSort();
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
    processed['id'] = item['id'];
    processed['type'] = 'medical'; // Set type
    processed['total_tagihan'] = item['total_tagihan'] ?? 0;
    processed['status_pembayaran'] = item['status_pembayaran'] ?? 'Belum Bayar';
    processed['kode_transaksi'] = item['kode_transaksi'];
    processed['tanggal_pembayaran'] = item['tanggal_pembayaran'];
    processed['tanggal_kunjungan'] = item['tanggal_kunjungan'];
    processed['no_antrian'] = item['no_antrian'];
    processed['diagnosis'] = item['diagnosis'];
    processed['metode_pembayaran_nama'] = item['metode_pembayaran_nama'];

    processed['pasien'] = {
      'nama_pasien': item['pasien']?['nama_pasien'] ?? 'Pasien',
    };
    processed['poli'] = {
      'nama_poli': item['poli']?['nama_poli'] ?? 'Umum',
    };
    processed['resep'] = item['resep'] ?? [];
    processed['layanan'] = item['layanan'] ?? [];
    processed['is_emr_missing'] = item['is_emr_missing'] ?? false;
    processed['is_payment_missing'] = item['is_payment_missing'] ?? false;

    return processed;
  }

  Map<String, dynamic> _createEmptyPembayaran() {
    return {
      'id': null,
      'type': 'medical',
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

  void _filterData() {
    setState(() {
      _applyFiltersAndSort();
    });
  }

  // MODIFIKASI: Update filter to include type and medicine-specific fields
  void _applyFiltersAndSort() {
    List<Map<String, dynamic>> allPayments = [];
    allPayments.addAll(pembayaranList.map((p) => {...p, 'type': 'medical'}));
    allPayments.addAll(pembayaranObatList);

    List<Map<String, dynamic>> filtered = allPayments;

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((payment) {
        final namaPasien = payment['pasien']?['nama_pasien']?.toString().toLowerCase() ?? '';
        final namaPoli = payment['poli']?['nama_poli']?.toString().toLowerCase() ?? '';
        final kodeTransaksi = payment['kode_transaksi']?.toString().toLowerCase() ?? '';
        final diagnosis = payment['diagnosis']?.toString().toLowerCase() ?? '';
        
        // TAMBAHKAN: Search in medicine items
        String medicineNames = '';
        if (payment['items'] != null) {
          for (var item in payment['items']) {
            medicineNames += (item['nama_obat']?.toString().toLowerCase() ?? '') + ' ';
          }
        }
        
        return namaPasien.contains(query) ||
               namaPoli.contains(query) ||
               kodeTransaksi.contains(query) ||
               diagnosis.contains(query) ||
               medicineNames.contains(query);
      }).toList();
    }

    // Apply status filter
    if (_selectedStatus != 'semua') {
      filtered = filtered.where((payment) {
        final status = payment['status_pembayaran']?.toString().toLowerCase() ?? '';
        return status.contains(_selectedStatus.toLowerCase());
      }).toList();
    }

    // TAMBAHKAN: Apply type filter
    if (_selectedType != 'semua') {
      filtered = filtered.where((payment) {
        final type = payment['type']?.toString() ?? '';
        return type == _selectedType;
      }).toList();
    }

    // Apply sorting
    switch (_selectedSortBy) {
      case 'tanggal_desc':
        filtered.sort((a, b) {
          final dateA = _parseDate(a['tanggal_kunjungan']);
          final dateB = _parseDate(b['tanggal_kunjungan']);
          return dateB.compareTo(dateA);
        });
        break;
      case 'tanggal_asc':
        filtered.sort((a, b) {
          final dateA = _parseDate(a['tanggal_kunjungan']);
          final dateB = _parseDate(b['tanggal_kunjungan']);
          return dateA.compareTo(dateB);
        });
        break;
      case 'total_desc':
        filtered.sort((a, b) {
          final totalA = toDoubleValue(a['total_tagihan']);
          final totalB = toDoubleValue(b['total_tagihan']);
          return totalB.compareTo(totalA);
        });
        break;
      case 'total_asc':
        filtered.sort((a, b) {
          final totalA = toDoubleValue(a['total_tagihan']);
          final totalB = toDoubleValue(b['total_tagihan']);
          return totalA.compareTo(totalB);
        });
        break;
      case 'status':
        filtered.sort((a, b) {
          final statusA = a['status_pembayaran'] ?? '';
          final statusB = b['status_pembayaran'] ?? '';
          return statusA.compareTo(statusB);
        });
        break;
    }

    filteredList = filtered;
  }

  DateTime _parseDate(dynamic date) {
    if (date == null) return DateTime.now();
    try {
      return DateTime.parse(date.toString());
    } catch (e) {
      return DateTime.now();
    }
  }

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

  // MODIFIKASI: Update filter dialog to include type filter
  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune, color: Color(0xFF00897B)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Filter & Urutkan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedSortBy = 'tanggal_desc';
                            _selectedStatus = 'semua';
                            _selectedType = 'semua'; // TAMBAHKAN reset
                            _applyFiltersAndSort();
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),

                  // TAMBAHKAN: Type filter section
                  const Text(
                    'Jenis pembayaran:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildTypeChip('Semua', 'semua', setModalState),
                      _buildTypeChip('Kunjungan Medis', 'medical', setModalState),
                      _buildTypeChip('Pembelian Obat', 'medicine', setModalState),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Sort by section
                  const Text(
                    'Urutkan berdasarkan:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildFilterChip('Tanggal Terbaru', 'tanggal_desc', setModalState),
                      _buildFilterChip('Tanggal Terlama', 'tanggal_asc', setModalState),
                      _buildFilterChip('Total Tertinggi', 'total_desc', setModalState),
                      _buildFilterChip('Total Terendah', 'total_asc', setModalState),
                      _buildFilterChip('Status', 'status', setModalState),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Filter by status
                  const Text(
                    'Filter status:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildStatusChip('Semua', 'semua', setModalState),
                      _buildStatusChip('Sudah Bayar', 'sudah bayar', setModalState),
                      _buildStatusChip('Belum Bayar', 'belum bayar', setModalState),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _applyFiltersAndSort();
                        });
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00897B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Terapkan Filter'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // TAMBAHKAN: Type filter chip
  Widget _buildTypeChip(String label, String value, StateSetter setModalState) {
    final isSelected = _selectedType == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setModalState(() {
          _selectedType = value;
        });
      },
      selectedColor: const Color(0xFF00897B).withOpacity(0.2),
      checkmarkColor: const Color(0xFF00897B),
    );
  }

  Widget _buildFilterChip(String label, String value, StateSetter setModalState) {
    final isSelected = _selectedSortBy == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setModalState(() {
          _selectedSortBy = value;
        });
      },
      selectedColor: const Color(0xFF00897B).withOpacity(0.2),
      checkmarkColor: const Color(0xFF00897B),
    );
  }

  Widget _buildStatusChip(String label, String value, StateSetter setModalState) {
    final isSelected = _selectedStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setModalState(() {
          _selectedStatus = value;
        });
      },
      selectedColor: const Color(0xFF00897B).withOpacity(0.2),
      checkmarkColor: const Color(0xFF00897B),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Riwayat Pembayaran'),
        backgroundColor: const Color(0xFF00897B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _showFilterDialog,
            icon: Stack(
              children: [
                const Icon(Icons.tune),
                if (_selectedSortBy != 'tanggal_desc' || _selectedStatus != 'semua' || _selectedType != 'semua')
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Animated Search bar like artikel page
            Container(
              color: Colors.white,
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 8 : 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Row(
                          children: [
                            Expanded(
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSearchActive ? const Color(0xFF00897B) : Colors.transparent,
                                    width: isSearchActive ? 2 : 1,
                                  ),
                                  boxShadow: isSearchActive
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF00897B).withOpacity(0.15),
                                            blurRadius: 10,
                                            spreadRadius: 1,
                                          ),
                                        ]
                                      : [],
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: _searchController.text.isEmpty && !isSearchActive
                                        ? _currentText
                                        : 'Ketik untuk mencari...',
                                    hintStyle: TextStyle(
                                      color: _searchController.text.isEmpty && !isSearchActive
                                          ? const Color(0xFF00897B).withOpacity(0.7)
                                          : Colors.grey.shade500,
                                      fontSize: 14,
                                      fontWeight: _searchController.text.isEmpty && !isSearchActive
                                          ? FontWeight.w500
                                          : FontWeight.normal,
                                    ),
                                    prefixIcon: AnimatedBuilder(
                                      animation: _typingTextController,
                                      builder: (context, _) {
                                        return AnimatedBuilder(
                                          animation: _colorAnimation,
                                          builder: (context, __) {
                                            return Transform.scale(
                                              scale: isSearchActive ? 1.0 + (_typingTextController.value * 0.1) : 1.0,
                                              child: Icon(Icons.search, color: _colorAnimation.value, size: 20),
                                            );
                                          },
                                        );
                                      },
                                    ),
                                    suffixIcon: isSearchActive
                                        ? AnimatedScale(
                                            scale: isSearchActive ? 1.0 : 0.0,
                                            duration: const Duration(milliseconds: 200),
                                            child: IconButton(
                                              icon: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade300,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(Icons.close, color: Colors.grey.shade700, size: 16),
                                              ),
                                              onPressed: clearSearch,
                                            ),
                                          )
                                        : null,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Search result info (animated) - only show when keyboard is not visible
                  if (isSearchActive && MediaQuery.of(context).viewInsets.bottom == 0) ...[
                    const SizedBox(height: 12),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: AnimatedOpacity(
                        opacity: isSearchActive ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF00897B).withOpacity(0.1),
                                const Color(0xFF4CAF50).withOpacity(0.05),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFF00897B).withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              AnimatedBuilder(
                                animation: _typingTextController,
                                builder: (context, _) {
                                  return Transform.rotate(
                                    angle: _typingTextController.value * 6.28,
                                    child: const Icon(Icons.search, size: 16, color: Color(0xFF00897B)),
                                  );
                                },
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 300),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: const Color(0xFF00897B),
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: isTyping ? 0.5 : 0.0,
                                  ),
                                  child: Text('Ditemukan ${filteredList.length} pembayaran untuk "${_searchController.text}"'),
                                ),
                              ),
                              TextButton(
                                onPressed: clearSearch,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(50, 30),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00897B).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Clear',
                                    style: TextStyle(color: Color(0xFF00897B), fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Results count - only show when keyboard is not visible
            if (!isLoading && (pembayaranList.isNotEmpty || pembayaranObatList.isNotEmpty) && MediaQuery.of(context).viewInsets.bottom == 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.white,
                child: Text(
                  'Menampilkan ${filteredList.length} dari ${pembayaranList.length + pembayaranObatList.length} pembayaran',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            
            // Content
            Expanded(child: _buildContent()),
          ],
        ),
      ),
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

    if (pembayaranList.isEmpty && pembayaranObatList.isEmpty) {
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
                'Riwayat pembayaran akan muncul setelah Anda melakukan kunjungan atau pembelian obat.',
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

    if (filteredList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'Tidak Ada Hasil',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Coba ubah kata kunci pencarian atau filter.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _selectedSortBy = 'tanggal_desc';
                    _selectedStatus = 'semua';
                    _selectedType = 'semua';
                    _applyFiltersAndSort();
                  });
                },
                icon: const Icon(Icons.clear),
                label: const Text('Reset Filter'),
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
        itemCount: filteredList.length,
        itemBuilder: (context, index) {
          final payment = filteredList[index];
          return _buildPaymentCard(payment, index);
        },
      ),
    );
  }

  // MODIFIKASI: Update payment card to handle both types
  Widget _buildPaymentCard(Map<String, dynamic> payment, int index) {
    final paymentType = payment['type'] ?? 'medical';
    final namaPasien = payment['pasien']?['nama_pasien'] ?? 'Pasien';
    final namaPoli = payment['poli']?['nama_poli'] ?? 'Umum';
    final status = payment['status_pembayaran'] ?? 'Belum Bayar';
    final totalTagihan = toDoubleValue(payment['total_tagihan']);
    final kodeTransaksi = payment['kode_transaksi'];
    final tanggalKunjungan = payment['tanggal_kunjungan'];
    final noAntrian = payment['no_antrian'];
    final metodePembayaran = payment['metode_pembayaran_nama'];
    final isEmrMissing = payment['is_emr_missing'] == true;
    final isPaymentMissing = payment['is_payment_missing'] == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final prefs = await SharedPreferences.getInstance();
          
          // Handle different navigation based on payment type
          if (paymentType == 'medicine') {
            // For medicine payments, show detail in a dialog or navigate to medicine detail page
            _showMedicinePaymentDetail(payment);
          } else {
            // For medical payments, navigate to existing Pembayaran page
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
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with type indicator
              Row(
                children: [
                  // TAMBAHKAN: Type indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: paymentType == 'medicine' 
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: paymentType == 'medicine' 
                            ? Colors.blue.withOpacity(0.3)
                            : Colors.green.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          paymentType == 'medicine' ? Icons.medication : Icons.local_hospital,
                          size: 12,
                          color: paymentType == 'medicine' ? Colors.blue : Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          paymentType == 'medicine' ? 'Obat' : 'Medis',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: paymentType == 'medicine' ? Colors.blue : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          namaPasien,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              paymentType == 'medicine' ? Icons.local_pharmacy : Icons.local_hospital,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              namaPoli,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
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
                        const SizedBox(width: 6),
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

              const SizedBox(height: 16),

              // Details row - responsive layout
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatDate(tanggalKunjungan),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  if (noAntrian != null && paymentType == 'medical')
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.confirmation_number,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'No. $noAntrian',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  // TAMBAHKAN: Show item count for medicine payments
                  if (paymentType == 'medicine' && payment['total_items'] != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${payment['total_items']} item',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // Payment amount
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF00897B).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF00897B).withOpacity(0.1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      paymentType == 'medicine' ? 'Total Pembelian' : 'Total Pembayaran',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
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
              ),

              // Additional info - responsive layout
              if (kodeTransaksi != null || metodePembayaran != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (kodeTransaksi != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.qr_code,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              kodeTransaksi,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    if (metodePembayaran != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.payment,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              metodePembayaran,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],

              // Special status indicators
              if (isEmrMissing || isPaymentMissing) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
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
                        size: 18,
                        color: isEmrMissing
                            ? Colors.blue.shade600
                            : Colors.amber.shade600,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isEmrMissing
                              ? 'Menunggu pemeriksaan dokter'
                              : 'Sedang diproses oleh admin',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
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

  // TAMBAHKAN: Method untuk show medicine payment detail
  void _showMedicinePaymentDetail(Map<String, dynamic> payment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.medication, color: Colors.blue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Detail Pembelian Obat',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Transaction Info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow('Kode Transaksi', payment['kode_transaksi'] ?? '-'),
                    _buildDetailRow('Tanggal', _formatDate(payment['tanggal_kunjungan'])),
                    _buildDetailRow('Status', payment['status_pembayaran'] ?? 'Belum Bayar'),
                    if (payment['metode_pembayaran_nama'] != null)
                      _buildDetailRow('Metode Pembayaran', payment['metode_pembayaran_nama']),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Items List
              const Text(
                'Daftar Obat:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: payment['items']?.length ?? 0,
                  itemBuilder: (context, index) {
                    final item = payment['items'][index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['nama_obat'] ?? 'Obat',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (item['dosis'] != null)
                                    Text(
                                      'Dosis: ${item['dosis']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Text(
                              '${item['jumlah'] ?? 0}x',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatCurrency(toDoubleValue(item['sub_total'])),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              // Total
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF00897B).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00897B).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Pembelian:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      formatCurrency(toDoubleValue(payment['total_tagihan'])),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00897B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const Text(': ', style: TextStyle(fontSize: 12)),
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
}