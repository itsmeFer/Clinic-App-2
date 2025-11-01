import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class Pemeriksaan extends StatefulWidget {
  final Map<String, dynamic> kunjunganData;

  const Pemeriksaan({super.key, required this.kunjunganData});

  @override
  State<Pemeriksaan> createState() => _PemeriksaanState();
}

class _PemeriksaanState extends State<Pemeriksaan>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _formKey = GlobalKey<FormState>();

  // Controllers untuk form
  final _keluhanUtamaController = TextEditingController();
  final _riwayatPenyakitDahuluController = TextEditingController();
  final _riwayatKeluargaController = TextEditingController();
  final _tekananDarahController = TextEditingController();
  final _suhuTubuhController = TextEditingController();
  final _nadiController = TextEditingController();
  final _pernapasanController = TextEditingController();
  final _saturasiOksigenController = TextEditingController();
  final _diagnosisController = TextEditingController();

  // Focus nodes untuk optimasi keyboard
  final List<FocusNode> _focusNodes = [];

  bool _isLoading = false;

  // Obat related
  List<Map<String, dynamic>> _availableObat = [];
  List<Map<String, dynamic>> _selectedResep = [];
  bool _isLoadingObat = false;
  final _searchObatController = TextEditingController();
  String _searchObatQuery = '';
  String _riwayatDiagnosisOtomatis = '';

  // Layanan related
  List<Map<String, dynamic>> _availableLayanan = [];
  List<Map<String, dynamic>> _selectedLayanan = [];
  bool _isLoadingLayanan = false;
  final _searchLayananController = TextEditingController();
  String _searchLayananQuery = '';

  // Search debounce timers
  Timer? _obatSearchDebounce;
  Timer? _layananSearchDebounce;

  // API Configuration
  static const String baseUrl = 'https://admin.royal-klinik.cloud/api';
  String? _authToken;

  // Performance optimization: Cache filtered results
  List<Map<String, dynamic>>? _cachedFilteredObat;
  List<Map<String, dynamic>>? _cachedFilteredLayanan;
  String _lastObatQuery = '';
  String _lastLayananQuery = '';

  @override
  void initState() {
    super.initState();

    // Initialize focus nodes (15 text fields total)
    for (int i = 0; i < 15; i++) {
      _focusNodes.add(FocusNode());
    }

    // Setup search listeners with debouncing - Increase debounce time
    _searchObatController.addListener(() {
      _onObatSearchChanged(_searchObatController.text);
    });

    _searchLayananController.addListener(() {
      _onLayananSearchChanged(_searchLayananController.text);
    });

    _initializeData();
  }

  @override
  void dispose() {
    // Dispose focus nodes
    for (var node in _focusNodes) {
      node.dispose();
    }

    // Cancel timers
    _obatSearchDebounce?.cancel();
    _layananSearchDebounce?.cancel();

    // Dispose controllers
    _keluhanUtamaController.dispose();
    _riwayatPenyakitDahuluController.dispose();
    _riwayatKeluargaController.dispose();
    _tekananDarahController.dispose();
    _suhuTubuhController.dispose();
    _nadiController.dispose();
    _pernapasanController.dispose();
    _saturasiOksigenController.dispose();
    _diagnosisController.dispose();
    _searchObatController.dispose();
    _searchLayananController.dispose();

    super.dispose();
  }

  // Increased debounce time for better performance
  void _onObatSearchChanged(String query) {
    _obatSearchDebounce?.cancel();
    _obatSearchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _searchObatQuery = query;
          _cachedFilteredObat = null; // Clear cache
        });
      }
    });
  }

  void _onLayananSearchChanged(String query) {
    _layananSearchDebounce?.cancel();
    _layananSearchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _searchLayananQuery = query;
          _cachedFilteredLayanan = null; // Clear cache
        });
      }
    });
  }

  String formatTanggalForAPI(DateTime tanggal) {
    return "${tanggal.year}-${tanggal.month.toString().padLeft(2, '0')}-${tanggal.day.toString().padLeft(2, '0')}";
  }

  Future<void> _initializeData() async {
    await _getAuthToken();
    await Future.wait([
      _loadKunjunganData(),
      _loadAvailableObat(),
      _loadAvailableLayanan(),
      _loadRiwayatDiagnosis(),
    ]);
    _fillInitialData();
  }

  Future<void> _loadKunjunganData() async {
    if (!mounted) return;

    try {
      final token = await getToken();
      final kunjunganId = widget.kunjunganData['id'];

      if (kunjunganId == null) {
        print('⚠️ Kunjungan ID not found');
        return;
      }

      print('🔍 Loading kunjungan data for ID: $kunjunganId');

      final response = await http.get(
        Uri.parse('$baseUrl/dokter/get-data-kunjungan/$kunjunganId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('📡 Kunjungan response: ${response.statusCode}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final kunjunganData = data['data'];

          setState(() {
            widget.kunjunganData['tanggal_kunjungan'] =
                kunjunganData['tanggal_kunjungan'];
            widget.kunjunganData['keluhan_awal'] =
                kunjunganData['keluhan_awal'];
            widget.kunjunganData['no_antrian'] = kunjunganData['no_antrian'];
          });

          _fillInitialData();
          print(
            '✅ Kunjungan data loaded: ${kunjunganData['tanggal_kunjungan']}',
          );
        }
      }
    } catch (e) {
      print('❌ Error loading kunjungan data: $e');
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> _getAuthToken() async {
    _authToken = await getToken();
  }

  void _fillInitialData() {
    if (widget.kunjunganData['keluhan_awal'] != null) {
      _keluhanUtamaController.text = widget.kunjunganData['keluhan_awal'];
    }
  }

  // API Methods
  Future<void> _loadAvailableObat() async {
    if (!mounted) return;

    setState(() {
      _isLoadingObat = true;
    });

    try {
      final token = await getToken();

      final response = await http.get(
        Uri.parse('$baseUrl/dokter/get-data-obat'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          setState(() {
            _availableObat = List<Map<String, dynamic>>.from(data['Data Obat']);
            _cachedFilteredObat = null; // Clear cache
          });
        } else {
          _showErrorSnackbar('Failed to load medications: ${data['message']}');
        }
      } else {
        _showErrorSnackbar('Server error: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Network error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingObat = false;
        });
      }
    }
  }

  Future<void> _loadRiwayatDiagnosis() async {
    try {
      final token = await getToken();
      final pasienId = widget.kunjunganData['pasien']?['id'];

      if (pasienId == null) {
        print('⚠️ Pasien ID not found, skipping riwayat load');
        return;
      }

      print('🔍 Loading riwayat diagnosis for pasien_id: $pasienId');

      final response = await http.get(
        Uri.parse('$baseUrl/pasien/riwayat-diagnosis/$pasienId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('📡 Riwayat response: ${response.statusCode}');
      print('📄 Riwayat body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['riwayat'] != null) {
          setState(() {
            _riwayatDiagnosisOtomatis = data['riwayat'];
            if (_riwayatDiagnosisOtomatis.isNotEmpty) {
              _riwayatPenyakitDahuluController.text = _riwayatDiagnosisOtomatis;
            }
          });
          print(
            '✅ Riwayat diagnosis loaded: ${_riwayatDiagnosisOtomatis.substring(0, 50)}...',
          );
        }
      }
    } catch (e) {
      print('❌ Error loading riwayat diagnosis: $e');
    }
  }

  Future<void> _loadAvailableLayanan() async {
    if (!mounted) return;

    setState(() {
      _isLoadingLayanan = true;
    });

    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        _showErrorSnackbar('Token tidak ditemukan. Silakan login ulang.');
        return;
      }

      print('🔍 Loading SEMUA layanan (tanpa filter poli)');

      final response = await http.get(
        Uri.parse('$baseUrl/dokter/get-layanan'), // endpoint dokter
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      print('📡 Layanan response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final body = json.decode(response.body);

        // ✅ respons kamu: {"success":true,"message":"...","data":[...],"total":5}
        final list = (body is Map && body['data'] is List)
            ? List<Map<String, dynamic>>.from(body['data'])
            : <Map<String, dynamic>>[];

        // Normalisasi field agar UI konsisten
        final normalized = list
            .map((e) {
              // Gunakan angka mentah bila ada, fallback dari string lokal "50.000,00"
              final raw = (e['harga_layanan_raw'] ?? e['harga_layanan'] ?? '0')
                  .toString();
              final numeric =
                  double.tryParse(
                    raw.contains(',')
                        ? raw.replaceAll('.', '').replaceAll(',', '.')
                        : raw,
                  ) ??
                  0.0;

              return {
                'id': e['id'],
                'nama_layanan': e['nama_layanan'] ?? e['nama'] ?? 'Layanan',
                'harga_layanan':
                    numeric, // disimpan numerik → formatter kamu aman
                'poli_id': e['poli_id'], // boleh null
              };
            })
            .where((e) => e['id'] != null && e['nama_layanan'] != null)
            .toList();

        setState(() {
          _availableLayanan = normalized;
          _cachedFilteredLayanan = null; // reset cache filter
        });

        print('✅ Loaded ${_availableLayanan.length} layanan (semua poli)');
        if (_availableLayanan.isNotEmpty) {
          print('🧪 Contoh item: ${_availableLayanan.first}');
        }
      } else {
        _showErrorSnackbar('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Error loading layanan: $e');
      if (mounted) {
        _showErrorSnackbar('Network error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLayanan = false;
        });
      }
    }
  }

  Future<void> _saveEMR() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await getToken();

      final emrData = {
        'kunjungan_id': widget.kunjunganData['id'],
        'keluhan_utama': _keluhanUtamaController.text.trim(),
        'riwayat_penyakit_dahulu': _riwayatPenyakitDahuluController.text.trim(),
        'riwayat_penyakit_keluarga': _riwayatKeluargaController.text.trim(),
        'tekanan_darah': _tekananDarahController.text.trim().isNotEmpty
            ? _tekananDarahController.text.trim()
            : null,
        'suhu_tubuh': _suhuTubuhController.text.trim().isNotEmpty
            ? double.tryParse(_suhuTubuhController.text.trim())
            : null,
        'nadi': _nadiController.text.trim().isNotEmpty
            ? int.tryParse(_nadiController.text.trim())
            : null,
        'pernapasan': _pernapasanController.text.trim().isNotEmpty
            ? int.tryParse(_pernapasanController.text.trim())
            : null,
        'saturasi_oksigen': _saturasiOksigenController.text.trim().isNotEmpty
            ? int.tryParse(_saturasiOksigenController.text.trim())
            : null,
        'diagnosis': _diagnosisController.text.trim(),
        'resep': _selectedResep,
        'layanan': _selectedLayanan,
      };

      print('Sending EMR Data: ${json.encode(emrData)}');

      final response = await http.post(
        Uri.parse('$baseUrl/dokter/save-emr'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(emrData),
      );

      print('EMR Response Status: ${response.statusCode}');
      print('EMR Response Body: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          final responseData = data['data'];

          print('EMR saved successfully');
          print('Kunjungan status: ${responseData['kunjungan']?['status']}');

          String successMessage = 'EMR berhasil disimpan!';
          if (responseData['kunjungan']?['status'] == 'Payment') {
            successMessage += '\nStatus kunjungan diubah ke Payment.';
          }

          _showSuccessSnackbar(successMessage);

          Navigator.pop(context, {
            'success': true,
            'emr_data': responseData,
            'status_updated': true,
            'new_status': responseData['kunjungan']?['status'],
          });
        } else {
          String errorMessage = 'Failed to save EMR';
          if (data['errors'] != null) {
            Map<String, dynamic> errors = data['errors'];
            errorMessage = errors.values.first[0] ?? errorMessage;
          } else if (data['message'] != null) {
            errorMessage = data['message'];
          }
          _showErrorSnackbar(errorMessage);
        }
      } else {
        try {
          final errorData = json.decode(response.body);
          String errorMessage =
              errorData['message'] ?? 'Server error: ${response.statusCode}';

          if (response.statusCode == 400 && errorMessage.contains('Engaged')) {
            errorMessage =
                'Kunjungan harus dalam status Engaged untuk membuat EMR';
          }

          _showErrorSnackbar(errorMessage);
        } catch (e) {
          _showErrorSnackbar('Server error: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error saving EMR: $e');
      if (mounted) {
        _showErrorSnackbar('Network error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // UI Helper Methods
  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  void _showSuccessSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  // Obat Methods
  void _addObatToResep(Map<String, dynamic> obat) {
    bool alreadyAdded = _selectedResep.any(
      (resep) => resep['obat_id'] == obat['id'],
    );

    if (alreadyAdded) {
      _showErrorSnackbar('Obat sudah ditambahkan ke resep');
      return;
    }

    _showAddObatDialog(obat);
  }

  Future<void> _showAddObatDialog(Map<String, dynamic> obat) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    final keteranganController = TextEditingController();
    final jumlahController = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Tambah Obat ke Resep',
          style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.6,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.teal.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          obat['nama_obat'] ?? 'Unknown Medicine',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.teal.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Stok: ${obat['jumlah'] ?? 0} | Dosis: ${obat['dosis'] ?? 0}mg',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  TextFormField(
                    controller: jumlahController,
                    decoration: InputDecoration(
                      labelText: 'Jumlah',
                      labelStyle: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Colors.teal,
                          width: 2,
                        ),
                      ),
                      suffixText: 'tablet',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 10 : 12,
                        vertical: isSmallScreen ? 12 : 16,
                      ),
                    ),
                    style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Jumlah harus diisi';
                      }
                      final jumlah = int.tryParse(value);
                      if (jumlah == null || jumlah <= 0) {
                        return 'Jumlah harus angka positif';
                      }
                      if (jumlah > (obat['jumlah'] ?? 0)) {
                        return 'Jumlah melebihi stok tersedia';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  TextFormField(
                    controller: keteranganController,
                    decoration: InputDecoration(
                      labelText: 'Keterangan Penggunaan',
                      labelStyle: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                      hintText: 'Contoh: 3x sehari sebelum makan',
                      hintStyle: TextStyle(fontSize: isSmallScreen ? 11 : 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Colors.teal,
                          width: 2,
                        ),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 10 : 12,
                        vertical: isSmallScreen ? 12 : 16,
                      ),
                    ),
                    style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Keterangan harus diisi';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05,
          vertical: 20,
        ),
        actionsPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05,
          vertical: 16,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final jumlah = int.parse(jumlahController.text);
                final keterangan = keteranganController.text.trim();

                setState(() {
                  _selectedResep.add({
                    'obat_id': obat['id'],
                    'nama_obat': obat['nama_obat'],
                    'dosis': obat['dosis'],
                    'total_harga': obat['total_harga'],
                    'jumlah': jumlah,
                    'keterangan': keterangan,
                  });
                });

                Navigator.pop(context);
                _showSuccessSnackbar(
                  '${obat['nama_obat']} berhasil ditambahkan',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Tambah',
              style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
            ),
          ),
        ],
      ),
    );
  }

  // Layanan Methods
  void _addLayananToSelection(Map<String, dynamic> layanan) {
    bool alreadyAdded = _selectedLayanan.any(
      (selected) => selected['layanan_id'] == layanan['id'],
    );

    if (alreadyAdded) {
      _showErrorSnackbar('Layanan sudah ditambahkan');
      return;
    }

    _showAddLayananDialog(layanan);
  }

  Future<void> _showAddLayananDialog(Map<String, dynamic> layanan) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    final jumlahController = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Tambah Layanan',
          style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          layanan['nama_layanan'] ?? 'Unknown Service',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Harga: Rp ${_formatPrice(layanan['harga_layanan'])}',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  TextFormField(
                    controller: jumlahController,
                    decoration: InputDecoration(
                      labelText: 'Jumlah',
                      labelStyle: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Colors.blue,
                          width: 2,
                        ),
                      ),
                      suffixText: 'kali',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 10 : 12,
                        vertical: isSmallScreen ? 12 : 16,
                      ),
                    ),
                    style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Jumlah harus diisi';
                      }
                      final jumlah = int.tryParse(value);
                      if (jumlah == null || jumlah <= 0) {
                        return 'Jumlah harus angka positif';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05,
          vertical: 20,
        ),
        actionsPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05,
          vertical: 16,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final jumlah = int.parse(jumlahController.text);

                setState(() {
                  _selectedLayanan.add({
                    'layanan_id': layanan['id'],
                    'nama_layanan': layanan['nama_layanan'],
                    'harga_layanan': layanan['harga_layanan'],
                    'jumlah': jumlah,
                  });
                });

                Navigator.pop(context);
                _showSuccessSnackbar(
                  '${layanan['nama_layanan']} berhasil ditambahkan',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Tambah',
              style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
            ),
          ),
        ],
      ),
    );
  }

  // Optimized getter methods with caching
  List<Map<String, dynamic>> get _filteredObat {
    if (_searchObatQuery == _lastObatQuery && _cachedFilteredObat != null) {
      return _cachedFilteredObat!;
    }

    _lastObatQuery = _searchObatQuery;

    if (_searchObatQuery.isEmpty) {
      _cachedFilteredObat = _availableObat;
    } else {
      final query = _searchObatQuery.toLowerCase();
      _cachedFilteredObat = _availableObat
          .where(
            (obat) => (obat['nama_obat'] ?? '')
                .toString()
                .toLowerCase()
                .contains(query),
          )
          .toList();
    }

    return _cachedFilteredObat!;
  }

  List<Map<String, dynamic>> get _filteredLayanan {
    if (_searchLayananQuery == _lastLayananQuery &&
        _cachedFilteredLayanan != null) {
      return _cachedFilteredLayanan!;
    }

    _lastLayananQuery = _searchLayananQuery;

    if (_searchLayananQuery.isEmpty) {
      _cachedFilteredLayanan = _availableLayanan;
    } else {
      final query = _searchLayananQuery.toLowerCase();
      _cachedFilteredLayanan = _availableLayanan
          .where(
            (layanan) => (layanan['nama_layanan'] ?? '')
                .toString()
                .toLowerCase()
                .contains(query),
          )
          .toList();
    }

    return _cachedFilteredLayanan!;
  }

  void _removeObatFromResep(int index) {
    setState(() {
      _selectedResep.removeAt(index);
    });
  }

  void _removeLayananFromSelection(int index) {
    setState(() {
      _selectedLayanan.removeAt(index);
    });
  }

  void _editResepItem(int index) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    final resep = _selectedResep[index];
    final keteranganController = TextEditingController(
      text: resep['keterangan'],
    );
    final jumlahController = TextEditingController(
      text: resep['jumlah'].toString(),
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Edit Resep',
          style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      resep['nama_obat'],
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  TextFormField(
                    controller: jumlahController,
                    decoration: InputDecoration(
                      labelText: 'Jumlah',
                      labelStyle: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Colors.teal,
                          width: 2,
                        ),
                      ),
                      suffixText: 'tablet',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 10 : 12,
                        vertical: isSmallScreen ? 12 : 16,
                      ),
                    ),
                    style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Jumlah harus diisi';
                      }
                      final jumlah = int.tryParse(value);
                      if (jumlah == null || jumlah <= 0) {
                        return 'Jumlah harus angka positif';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  TextFormField(
                    controller: keteranganController,
                    decoration: InputDecoration(
                      labelText: 'Keterangan Penggunaan',
                      labelStyle: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                      hintText: 'Contoh: 3x sehari sebelum makan',
                      hintStyle: TextStyle(fontSize: isSmallScreen ? 11 : 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Colors.teal,
                          width: 2,
                        ),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 10 : 12,
                        vertical: isSmallScreen ? 12 : 16,
                      ),
                    ),
                    style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Keterangan harus diisi';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05,
          vertical: 20,
        ),
        actionsPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05,
          vertical: 16,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final jumlah = int.parse(jumlahController.text);
                final keterangan = keteranganController.text.trim();

                setState(() {
                  _selectedResep[index]['jumlah'] = jumlah;
                  _selectedResep[index]['keterangan'] = keterangan;
                });

                Navigator.pop(context);
                _showSuccessSnackbar('Resep berhasil diperbarui');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Simpan',
              style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
            ),
          ),
        ],
      ),
    );
  }

  void _editLayananItem(int index) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    final layanan = _selectedLayanan[index];
    final jumlahController = TextEditingController(
      text: layanan['jumlah'].toString(),
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Edit Layanan',
          style: TextStyle(fontSize: isSmallScreen ? 16 : 18),
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.4,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      layanan['nama_layanan'],
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  TextFormField(
                    controller: jumlahController,
                    decoration: InputDecoration(
                      labelText: 'Jumlah',
                      labelStyle: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Colors.blue,
                          width: 2,
                        ),
                      ),
                      suffixText: 'kali',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 10 : 12,
                        vertical: isSmallScreen ? 12 : 16,
                      ),
                    ),
                    style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Jumlah harus diisi';
                      }
                      final jumlah = int.tryParse(value);
                      if (jumlah == null || jumlah <= 0) {
                        return 'Jumlah harus angka positif';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05,
          vertical: 20,
        ),
        actionsPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05,
          vertical: 16,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Batal',
              style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final jumlah = int.parse(jumlahController.text);

                setState(() {
                  _selectedLayanan[index]['jumlah'] = jumlah;
                });

                Navigator.pop(context);
                _showSuccessSnackbar('Layanan berhasil diperbarui');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Simpan',
              style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
            ),
          ),
        ],
      ),
    );
  }

  // Optimized widget builders
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? iconColor,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Card(
      elevation: 2,
      margin: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          color: Colors.white,
        ),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                decoration: BoxDecoration(
                  color: (iconColor ?? Colors.teal).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      color: iconColor ?? Colors.teal.shade700,
                      size: isSmallScreen ? 20 : 24,
                    ),
                    SizedBox(width: isSmallScreen ? 6 : 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: (iconColor ?? Colors.teal),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isSmallScreen ? 14 : 18),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? suffixText,
    int maxLines = 1,
    bool required = false,
    TextInputType? keyboardType,
    bool readOnly = false,
    FocusNode? focusNode,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      maxLines: maxLines,
      keyboardType: keyboardType,
      readOnly: readOnly,
      inputFormatters: inputFormatters,
      style: TextStyle(
        fontSize: isSmallScreen ? 13 : 14,
        color: readOnly ? Colors.grey.shade700 : null,
      ),
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        labelStyle: TextStyle(
          fontSize: isSmallScreen ? 12 : 14,
          color: readOnly ? Colors.grey.shade600 : Colors.teal.shade700,
        ),
        hintText: hint,
        hintStyle: TextStyle(fontSize: isSmallScreen ? 11 : 12),
        suffixText: suffixText,
        suffixStyle: TextStyle(fontSize: isSmallScreen ? 11 : 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.teal, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
        fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
        filled: true,
        contentPadding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 12 : 16,
          vertical: isSmallScreen ? 14 : 16,
        ),
      ),
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return '$label harus diisi';
              }
              return null;
            }
          : null,
    );
  }

  String _formatTanggal(String? tanggal) {
    if (tanggal == null || tanggal.isEmpty) {
      return 'Tidak tersedia';
    }

    try {
      DateTime dateTime;

      if (tanggal.contains('T')) {
        dateTime = DateTime.parse(tanggal).toLocal();
      } else if (tanggal.contains('-')) {
        List<String> parts = tanggal.split('-');
        if (parts.length == 3) {
          if (parts[0].length == 4) {
            dateTime = DateTime(
              int.parse(parts[0]),
              int.parse(parts[1]),
              int.parse(parts[2]),
            );
          } else {
            dateTime = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          }
        } else {
          return tanggal;
        }
      } else {
        return tanggal;
      }

      return '${dateTime.day.toString().padLeft(2, '0')}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.year}';
    } catch (e) {
      print('⚠️ Error formatting date: $e for input: $tanggal');
      return tanggal;
    }
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';

    try {
      if (price is String) {
        double parsedPrice = double.parse(price);
        return parsedPrice.toStringAsFixed(0);
      } else if (price is num) {
        return price.toStringAsFixed(0);
      } else {
        return price.toString();
      }
    } catch (e) {
      return price.toString();
    }
  }

  Widget _buildPatientInfoCard() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.blue.shade50,
        ),
        padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person,
                    color: Colors.blue.shade700,
                    size: isSmallScreen ? 20 : 24,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 10 : 12),
                Text(
                  'Informasi Pasien',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 14 : 16),
            _buildInfoRow(
              'Nama',
              widget.kunjunganData['pasien']?['nama_pasien'] ??
                  'Tidak tersedia',
              isSmallScreen,
            ),
            SizedBox(height: isSmallScreen ? 8 : 10),
            Row(
              children: [
                Text(
                  'No. Antrian: ',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isSmallScreen ? 12 : 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 6 : 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.kunjunganData['no_antrian']?.toString() ?? '-',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: isSmallScreen ? 12 : 14,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 8 : 10),
            _buildInfoRow(
              'Keluhan',
              widget.kunjunganData['keluhan_awal'] ?? 'Tidak ada keluhan',
              isSmallScreen,
            ),
            SizedBox(height: isSmallScreen ? 8 : 10),
            _buildInfoRow(
              'Tanggal Kunjungan',
              _formatTanggal(widget.kunjunganData['tanggal_kunjungan']),
              isSmallScreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isSmallScreen) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isSmallScreen ? 12 : 14,
            color: Colors.grey.shade700,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 14,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  // Optimized ListView builders with RepaintBoundary
  Widget _buildObatList() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    if (_isLoadingObat) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.teal),
        ),
      );
    }

    final filteredObat = _filteredObat;

    if (filteredObat.isEmpty) {
      return Container(
        padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: isSmallScreen ? 32 : 40,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            Text(
              _searchObatQuery.isNotEmpty
                  ? 'Tidak ada obat yang ditemukan dengan kata kunci "$_searchObatQuery"'
                  : 'Tidak ada obat tersedia',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: isSmallScreen ? 12 : 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      height: isSmallScreen ? 200 : 250,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
        itemCount: filteredObat.length,
        cacheExtent: 300, // Increased cache
        itemBuilder: (context, index) {
          final obat = filteredObat[index];
          final isSelected = _selectedResep.any(
            (resep) => resep['obat_id'] == obat['id'],
          );

          return RepaintBoundary(
            child: _ObatListItem(
              obat: obat,
              isSelected: isSelected,
              isSmallScreen: isSmallScreen,
              onAdd: () => _addObatToResep(obat),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLayananList() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    if (_isLoadingLayanan) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.blue),
        ),
      );
    }

    final filteredLayanan = _filteredLayanan;

    if (filteredLayanan.isEmpty) {
      return Container(
        padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: isSmallScreen ? 32 : 40,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            Text(
              _searchLayananQuery.isNotEmpty
                  ? 'Tidak ada layanan yang ditemukan dengan kata kunci "$_searchLayananQuery"'
                  : 'Tidak ada layanan tersedia',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: isSmallScreen ? 12 : 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      height: isSmallScreen ? 200 : 250,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
        itemCount: filteredLayanan.length,
        cacheExtent: 300, // Increased cache
        itemBuilder: (context, index) {
          final layanan = filteredLayanan[index];
          final isSelected = _selectedLayanan.any(
            (selected) => selected['layanan_id'] == layanan['id'],
          );

          return RepaintBoundary(
            child: _LayananListItem(
              layanan: layanan,
              isSelected: isSelected,
              isSmallScreen: isSmallScreen,
              onAdd: () => _addLayananToSelection(layanan),
              formatPrice: _formatPrice,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Pemeriksaan Pasien',
          style: TextStyle(
            color: Colors.white,
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: IconThemeData(
          color: Colors.white,
          size: isSmallScreen ? 20 : 24,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Patient Information Card
                _buildPatientInfoCard(),

                SizedBox(height: isSmallScreen ? 16 : 20),

                // Medical Examination Form
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Anamnesis Section
                      _buildSectionCard(
                        title: 'Anamnesis',
                        icon: Icons.description,
                        children: [
                          _buildTextFormField(
                            controller: _keluhanUtamaController,
                            label: 'Keluhan Utama',
                            hint:
                                'Keluhan utama dari pasien (tidak dapat diubah)',
                            maxLines: 3,
                            required: true,
                            readOnly: true,
                            focusNode: _focusNodes[0],
                          ),
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          if (_riwayatDiagnosisOtomatis.isNotEmpty)
                            Container(
                              margin: EdgeInsets.only(
                                bottom: isSmallScreen ? 12 : 16,
                              ),
                              padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.blue.shade700,
                                    size: isSmallScreen ? 16 : 20,
                                  ),
                                  SizedBox(width: isSmallScreen ? 8 : 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Riwayat Diagnosis Otomatis',
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 12 : 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue.shade800,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Riwayat penyakit dahulu telah diisi otomatis dari diagnosis sebelumnya. Anda dapat mengedit jika diperlukan.',
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 10 : 12,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          _buildTextFormField(
                            controller: _riwayatPenyakitDahuluController,
                            label: 'Riwayat Penyakit Dahulu',
                            hint: _riwayatDiagnosisOtomatis.isNotEmpty
                                ? 'Riwayat telah diisi otomatis dari diagnosis sebelumnya, Anda dapat mengedit jika diperlukan'
                                : 'Riwayat penyakit yang pernah dialami...',
                            maxLines: 5,
                            readOnly: false,
                            focusNode: _focusNodes[1],
                          ),
                          SizedBox(height: isSmallScreen ? 12 : 16),
                          _buildTextFormField(
                            controller: _riwayatKeluargaController,
                            label: 'Riwayat Keluarga',
                            hint: 'Riwayat penyakit keluarga...',
                            maxLines: 3,
                            focusNode: _focusNodes[2],
                          ),
                        ],
                      ),

                      // Vital Signs Section
                      _buildSectionCard(
                        title: 'Tanda Vital',
                        icon: Icons.favorite,
                        iconColor: Colors.red,
                        children: [
                          if (isSmallScreen) ...[
                            _buildTextFormField(
                              controller: _tekananDarahController,
                              label: 'Tekanan Darah',
                              hint: '120/80',
                              suffixText: 'mmHg',
                              focusNode: _focusNodes[3],
                            ),
                            const SizedBox(height: 12),
                            _buildTextFormField(
                              controller: _suhuTubuhController,
                              label: 'Suhu Tubuh',
                              hint: '36.5',
                              suffixText: '°C',
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,1}'),
                                ),
                              ],
                              focusNode: _focusNodes[4],
                            ),
                            const SizedBox(height: 12),
                            _buildTextFormField(
                              controller: _nadiController,
                              label: 'Nadi',
                              hint: '80',
                              suffixText: 'bpm',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              focusNode: _focusNodes[5],
                            ),
                            const SizedBox(height: 12),
                            _buildTextFormField(
                              controller: _pernapasanController,
                              label: 'Pernapasan',
                              hint: '20',
                              suffixText: '/menit',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              focusNode: _focusNodes[6],
                            ),
                            const SizedBox(height: 12),
                            _buildTextFormField(
                              controller: _saturasiOksigenController,
                              label: 'Saturasi Oksigen',
                              hint: '98',
                              suffixText: '%',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              focusNode: _focusNodes[7],
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextFormField(
                                    controller: _tekananDarahController,
                                    label: 'Tekanan Darah',
                                    hint: '120/80',
                                    suffixText: 'mmHg',
                                    focusNode: _focusNodes[3],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextFormField(
                                    controller: _suhuTubuhController,
                                    label: 'Suhu Tubuh',
                                    hint: '36.5',
                                    suffixText: '°C',
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(
                                        RegExp(r'^\d+\.?\d{0,1}'),
                                      ),
                                    ],
                                    focusNode: _focusNodes[4],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextFormField(
                                    controller: _nadiController,
                                    label: 'Nadi',
                                    hint: '80',
                                    suffixText: 'bpm',
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    focusNode: _focusNodes[5],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTextFormField(
                                    controller: _pernapasanController,
                                    label: 'Pernapasan',
                                    hint: '20',
                                    suffixText: '/menit',
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    focusNode: _focusNodes[6],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildTextFormField(
                              controller: _saturasiOksigenController,
                              label: 'Saturasi Oksigen',
                              hint: '98',
                              suffixText: '%',
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              focusNode: _focusNodes[7],
                            ),
                          ],
                        ],
                      ),

                      // Diagnosis Section
                      _buildSectionCard(
                        title: 'Diagnosis',
                        icon: Icons.medical_services,
                        children: [
                          _buildTextFormField(
                            controller: _diagnosisController,
                            label: 'Diagnosis',
                            hint: 'Masukkan diagnosis...',
                            maxLines: 4,
                            required: true,
                            focusNode: _focusNodes[8],
                          ),
                        ],
                      ),

                      // Services Section
                      _buildSectionCard(
                        title: 'Layanan Medis',
                        icon: Icons.medical_services_outlined,
                        iconColor: Colors.blue,
                        children: [
                          // Search Bar for Services
                          Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchLayananController,
                              focusNode: _focusNodes[9],
                              style: TextStyle(
                                fontSize: isSmallScreen ? 13 : 14,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Cari Layanan',
                                labelStyle: TextStyle(
                                  fontSize: isSmallScreen ? 12 : 14,
                                  color: Colors.blue.shade700,
                                ),
                                hintText: 'Masukkan nama layanan...',
                                hintStyle: TextStyle(
                                  fontSize: isSmallScreen ? 11 : 12,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Colors.blue,
                                  size: isSmallScreen ? 20 : 24,
                                ),
                                suffixIcon: _searchLayananQuery.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.clear,
                                          size: isSmallScreen ? 18 : 20,
                                        ),
                                        onPressed: () {
                                          _searchLayananController.clear();
                                          setState(() {
                                            _searchLayananQuery = '';
                                          });
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.blue,
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 12 : 16,
                                  vertical: isSmallScreen ? 14 : 16,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: isSmallScreen ? 14 : 16),

                          // Available Services List
                          Row(
                            children: [
                              Icon(
                                Icons.local_hospital,
                                color: Colors.blue.shade600,
                                size: isSmallScreen ? 18 : 20,
                              ),
                              SizedBox(width: isSmallScreen ? 6 : 8),
                              Text(
                                'Daftar Layanan Tersedia:',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isSmallScreen ? 10 : 12),

                          _buildLayananList(),

                          SizedBox(height: isSmallScreen ? 16 : 20),

                          // Selected Services
                          Row(
                            children: [
                              Icon(
                                Icons.assignment_turned_in,
                                color: Colors.blue.shade600,
                                size: isSmallScreen ? 18 : 20,
                              ),
                              SizedBox(width: isSmallScreen ? 6 : 8),
                              Text(
                                'Layanan yang Dipilih:',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                              const Spacer(),
                              if (_selectedLayanan.isNotEmpty)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 6 : 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade600,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_selectedLayanan.length} layanan',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 10 : 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: isSmallScreen ? 10 : 12),

                          _buildSelectedLayananList(isSmallScreen),
                        ],
                      ),

                      // Prescription Section
                      _buildSectionCard(
                        title: 'Resep Obat',
                        icon: Icons.medication,
                        children: [
                          // Search Bar
                          Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  spreadRadius: 1,
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchObatController,
                              focusNode: _focusNodes[10],
                              style: TextStyle(
                                fontSize: isSmallScreen ? 13 : 14,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Cari Obat',
                                labelStyle: TextStyle(
                                  fontSize: isSmallScreen ? 12 : 14,
                                  color: Colors.teal.shade700,
                                ),
                                hintText: 'Masukkan nama obat...',
                                hintStyle: TextStyle(
                                  fontSize: isSmallScreen ? 11 : 12,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Colors.teal,
                                  size: isSmallScreen ? 20 : 24,
                                ),
                                suffixIcon: _searchObatQuery.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(
                                          Icons.clear,
                                          size: isSmallScreen ? 18 : 20,
                                        ),
                                        onPressed: () {
                                          _searchObatController.clear();
                                          setState(() {
                                            _searchObatQuery = '';
                                          });
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Colors.teal,
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 12 : 16,
                                  vertical: isSmallScreen ? 14 : 16,
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: isSmallScreen ? 14 : 16),

                          // Available Medications List
                          Row(
                            children: [
                              Icon(
                                Icons.local_pharmacy,
                                color: Colors.teal.shade600,
                                size: isSmallScreen ? 18 : 20,
                              ),
                              SizedBox(width: isSmallScreen ? 6 : 8),
                              Text(
                                'Daftar Obat Tersedia:',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.teal.shade700,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isSmallScreen ? 10 : 12),

                          _buildObatList(),

                          SizedBox(height: isSmallScreen ? 16 : 20),

                          // Selected Prescriptions
                          Row(
                            children: [
                              Icon(
                                Icons.receipt_long,
                                color: Colors.teal.shade600,
                                size: isSmallScreen ? 18 : 20,
                              ),
                              SizedBox(width: isSmallScreen ? 6 : 8),
                              Text(
                                'Resep yang Dipilih:',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.teal.shade700,
                                ),
                              ),
                              const Spacer(),
                              if (_selectedResep.isNotEmpty)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isSmallScreen ? 6 : 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.shade600,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_selectedResep.length} obat',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 10 : 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: isSmallScreen ? 10 : 12),

                          _buildSelectedResepList(isSmallScreen),
                        ],
                      ),

                      SizedBox(height: isSmallScreen ? 20 : 24),

                      // Action Buttons
                      _buildActionButtons(isSmallScreen),

                      SizedBox(height: isSmallScreen ? 20 : 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedLayananList(bool isSmallScreen) {
    if (_selectedLayanan.isEmpty) {
      return Container(
        padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(
              Icons.medical_services_outlined,
              size: isSmallScreen ? 36 : 48,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Text(
              'Belum ada layanan yang dipilih',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
                fontSize: isSmallScreen ? 12 : 14,
              ),
            ),
            SizedBox(height: isSmallScreen ? 4 : 6),
            Text(
              'Gunakan pencarian di atas untuk mencari dan menambah layanan',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: isSmallScreen ? 10 : 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: List.generate(_selectedLayanan.length, (index) {
        final layanan = _selectedLayanan[index];
        return RepaintBoundary(
          child: Container(
            margin: EdgeInsets.only(bottom: isSmallScreen ? 10 : 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 4 : 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.medical_services_outlined,
                      color: Colors.blue.shade700,
                      size: isSmallScreen ? 14 : 16,
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 8 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          layanan['nama_layanan'] ?? 'Unknown Service',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isSmallScreen ? 13 : 16,
                            color: Colors.blue.shade800,
                          ),
                        ),
                        Text(
                          'Jumlah: ${layanan['jumlah']} kali | Harga: Rp ${_formatPrice(layanan['harga_layanan'])}',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 10 : 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _editLayananItem(index),
                        icon: Icon(Icons.edit, size: isSmallScreen ? 16 : 18),
                        color: Colors.blue.shade600,
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.all(isSmallScreen ? 2 : 4),
                      ),
                      SizedBox(width: isSmallScreen ? 2 : 4),
                      IconButton(
                        onPressed: () => _removeLayananFromSelection(index),
                        icon: Icon(Icons.delete, size: isSmallScreen ? 16 : 18),
                        color: Colors.red.shade600,
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.all(isSmallScreen ? 2 : 4),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSelectedResepList(bool isSmallScreen) {
    if (_selectedResep.isEmpty) {
      return Container(
        padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(
              Icons.medication_outlined,
              size: isSmallScreen ? 36 : 48,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Text(
              'Belum ada obat yang dipilih',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
                fontSize: isSmallScreen ? 12 : 14,
              ),
            ),
            SizedBox(height: isSmallScreen ? 4 : 6),
            Text(
              'Gunakan pencarian di atas untuk mencari dan menambah obat',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: isSmallScreen ? 10 : 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: List.generate(_selectedResep.length, (index) {
        final resep = _selectedResep[index];
        return RepaintBoundary(
          child: Container(
            margin: EdgeInsets.only(bottom: isSmallScreen ? 10 : 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 4 : 6),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.medication,
                          color: Colors.teal.shade700,
                          size: isSmallScreen ? 14 : 16,
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 8 : 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              resep['nama_obat'] ?? 'Unknown Medicine',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: isSmallScreen ? 13 : 16,
                                color: Colors.teal.shade800,
                              ),
                            ),
                            Text(
                              'Jumlah: ${resep['jumlah']} tablet | Dosis: ${resep['dosis']}mg',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 10 : 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _editResepItem(index),
                            icon: Icon(
                              Icons.edit,
                              size: isSmallScreen ? 16 : 18,
                            ),
                            color: Colors.blue.shade600,
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.all(isSmallScreen ? 2 : 4),
                          ),
                          SizedBox(width: isSmallScreen ? 2 : 4),
                          IconButton(
                            onPressed: () => _removeObatFromResep(index),
                            icon: Icon(
                              Icons.delete,
                              size: isSmallScreen ? 16 : 18,
                            ),
                            color: Colors.red.shade600,
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.all(isSmallScreen ? 2 : 4),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: isSmallScreen ? 8 : 12),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Keterangan Penggunaan:',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 10 : 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          resep['keterangan'] ?? 'Belum ada keterangan',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 11 : 14,
                            color: Colors.black87,
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
      }),
    );
  }

  Widget _buildActionButtons(bool isSmallScreen) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(isSmallScreen ? 14 : 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      Navigator.pop(context);
                    },
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  vertical: isSmallScreen ? 14 : 16,
                ),
                side: BorderSide(color: Colors.grey.shade400),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Batal',
                style: TextStyle(
                  fontSize: isSmallScreen ? 12 : 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(width: isSmallScreen ? 12 : 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isLoading ? null : _saveEMR,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: isSmallScreen ? 14 : 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isLoading
                  ? SizedBox(
                      height: isSmallScreen ? 16 : 20,
                      width: isSmallScreen ? 16 : 20,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Simpan EMR',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// Separate widget classes for better performance - with optimizations
class _ObatListItem extends StatelessWidget {
  final Map<String, dynamic> obat;
  final bool isSelected;
  final bool isSmallScreen;
  final VoidCallback onAdd;

  const _ObatListItem({
    required this.obat,
    required this.isSelected,
    required this.isSmallScreen,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 3 : 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.green.shade300 : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        dense: isSmallScreen,
        contentPadding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 8 : 12,
          vertical: isSmallScreen ? 4 : 6,
        ),
        leading: Container(
          padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.green.shade100 : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isSelected ? Icons.check_circle : Icons.medication,
            color: isSelected ? Colors.green.shade600 : Colors.blue.shade600,
            size: isSmallScreen ? 16 : 20,
          ),
        ),
        title: Text(
          obat['nama_obat'] ?? 'Unknown Medicine',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isSmallScreen ? 12 : 14,
            color: isSelected ? Colors.green.shade800 : Colors.grey.shade800,
          ),
        ),
        subtitle: Text(
          'Stok: ${obat['jumlah'] ?? 0} | Dosis: ${obat['dosis'] ?? 0}mg | Rp ${_formatPrice(obat['total_harga'])}',
          style: TextStyle(
            fontSize: isSmallScreen ? 10 : 12,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: isSelected
            ? Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 6 : 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Dipilih',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 10 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : ElevatedButton(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12 : 16,
                    vertical: isSmallScreen ? 6 : 8,
                  ),
                  minimumSize: Size(0, isSmallScreen ? 28 : 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Tambah',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      ),
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    try {
      if (price is String) {
        double parsedPrice = double.parse(price);
        return parsedPrice.toStringAsFixed(0);
      } else if (price is num) {
        return price.toStringAsFixed(0);
      } else {
        return price.toString();
      }
    } catch (e) {
      return price.toString();
    }
  }
}

class _LayananListItem extends StatelessWidget {
  final Map<String, dynamic> layanan;
  final bool isSelected;
  final bool isSmallScreen;
  final VoidCallback onAdd;
  final String Function(dynamic) formatPrice;

  const _LayananListItem({
    required this.layanan,
    required this.isSelected,
    required this.isSmallScreen,
    required this.onAdd,
    required this.formatPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: isSmallScreen ? 3 : 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.green.shade300 : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        dense: isSmallScreen,
        contentPadding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 8 : 12,
          vertical: isSmallScreen ? 4 : 6,
        ),
        leading: Container(
          padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.green.shade100 : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isSelected ? Icons.check_circle : Icons.medical_services_outlined,
            color: isSelected ? Colors.green.shade600 : Colors.blue.shade600,
            size: isSmallScreen ? 16 : 20,
          ),
        ),
        title: Text(
          layanan['nama_layanan'] ?? 'Unknown Service',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isSmallScreen ? 12 : 14,
            color: isSelected ? Colors.green.shade800 : Colors.grey.shade800,
          ),
        ),
        subtitle: Text(
          'Harga: Rp ${formatPrice(layanan['harga_layanan'])}',
          style: TextStyle(
            fontSize: isSmallScreen ? 10 : 12,
            color: Colors.grey.shade600,
          ),
        ),
        trailing: isSelected
            ? Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 6 : 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.shade600,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Dipilih',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallScreen ? 10 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : ElevatedButton(
                onPressed: onAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12 : 16,
                    vertical: isSmallScreen ? 6 : 8,
                  ),
                  minimumSize: Size(0, isSmallScreen ? 28 : 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Tambah',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10 : 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      ),
    );
  }
}
