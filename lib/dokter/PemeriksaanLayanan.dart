// lib/dokter/PemeriksaanLayanan.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:RoyalClinic/dokter/Sidebar.dart' as Sidebar;

class PemeriksaanLayanan extends StatefulWidget {
  final Map<String, dynamic> kunjunganData;

  const PemeriksaanLayanan({Key? key, required this.kunjunganData})
    : super(key: key);

  @override
  State<PemeriksaanLayanan> createState() => _PemeriksaanLayananState();
}

class _PemeriksaanLayananState extends State<PemeriksaanLayanan>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _formKey = GlobalKey<FormState>();

  // Controllers form EMR
  final _keluhanUtamaController = TextEditingController();
  final _riwayatPenyakitDahuluController = TextEditingController();
  final _riwayatKeluargaController = TextEditingController();
  final _tekananDarahController = TextEditingController();
  final _suhuTubuhController = TextEditingController();
  final _nadiController = TextEditingController();
  final _pernapasanController = TextEditingController();
  final _saturasiOksigenController = TextEditingController();
  final _diagnosisController = TextEditingController();

  bool _isLoading = false;
  bool _isSidebarCollapsed = false;
  Map<String, dynamic>? _dokterData;

  bool _isEditingAnamnesis = false;
  bool _isEditingVital = false;

  // Obat & Layanan
  List<Map<String, dynamic>> _availableObat = [];
  List<Map<String, dynamic>> _selectedResep = [];
  bool _isLoadingObat = false;
  final _searchObatController = TextEditingController();
  String _searchObatQuery = '';

  List<Map<String, dynamic>> _availableLayanan = [];
  List<Map<String, dynamic>> _selectedLayanan = [];
  List<Map<String, dynamic>> _orderedLayanan = [];
  bool _isLoadingLayanan = false;
  final _searchLayananController = TextEditingController();
  String _searchLayananQuery = '';

  Timer? _obatSearchDebounce;
  Timer? _layananSearchDebounce;

  // API
  static const String baseUrl = 'http://10.19.0.247:8000/api';

  // Colors
  static const Color _slate900 = Color(0xFF0F172A);
  static const Color _slate700 = Color(0xFF334155);
  static const Color _slate600 = Color(0xFF475569);
  static const Color _slate500 = Color(0xFF64748B);
  static const Color _slate400 = Color(0xFF94A3B8);
  static const Color _slate200 = Color(0xFFE2E8F0);
  static const Color _slate100 = Color(0xFFF1F5F9);
  static const Color _slate50 = Color(0xFFF8FAFC);

  static const Color _blue600 = Color(0xFF2563EB);
  static const Color _blue500 = Color(0xFF3B82F6);
  static const Color _blue100 = Color(0xFFDBEAFE);
  static const Color _blue50 = Color(0xFFEFF6FF);

  static const Color _emerald600 = Color(0xFF059669);
  static const Color _emerald500 = Color(0xFF10B981);
  static const Color _emerald100 = Color(0xFFD1FAE5);
  static const Color _emerald50 = Color(0xFFF0FDF4);

  static const Color _red500 = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    debugPrint('kunjunganData awal: ${jsonEncode(widget.kunjunganData)}');

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
    _obatSearchDebounce?.cancel();
    _layananSearchDebounce?.cancel();

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

  // ================== INIT DATA ==================
  Future<void> _initializeData() async {
    await Future.wait([
      _loadKunjunganData(),
      _loadAvailableObat(),
      _loadAvailableLayanan(),
      _loadOrderedLayanan(), // biar layanan dari order pasien ikut tampil
    ]);

    // JANGAN panggil _loadEMRfromServer di sini lagi
    _fillInitialData();
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // Ambil detail kunjungan (tanggal, keluhan awal, dll)
  Future<void> _loadKunjunganData() async {
    if (!mounted) return;

    try {
      final token = await getToken();

      // pakai kunjungan_id dulu, kalau ga ada baru fallback ke id
      final kunjunganId =
          widget.kunjunganData['kunjungan_id'] ?? widget.kunjunganData['id'];

      if (kunjunganId == null) return;

      final response = await http.get(
        Uri.parse('$baseUrl/dokter/get-data-kunjungan/$kunjunganId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] is Map) {
          final kunjunganData = Map<String, dynamic>.from(
            data['data'] as Map<dynamic, dynamic>,
          );

          setState(() {
            widget.kunjunganData.addAll(kunjunganData);
          });

          // setelah kunjunganData di-update, isi ulang controller
          _fillInitialData();
        }
      } else {
        debugPrint(
          'get-data-kunjungan gagal: ${response.statusCode} ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Error _loadKunjunganData: $e');
    }
  }

  // Isi controller dari kunjunganData + emr + order
  void _fillInitialData() {
    final root = widget.kunjunganData;

    // EMR (kalau ada)
    final emrRaw = root['emr'];
    Map<String, dynamic> emr = {};
    if (emrRaw is Map<String, dynamic>) {
      emr = emrRaw;
    } else if (emrRaw is Map) {
      emr = Map<String, dynamic>.from(emrRaw);
    }

    // ORDER (dari penjualan_layanan ➜ getLayananOrderDokter)
    final orderRaw = root['order'];
    Map<String, dynamic> order = {};
    if (orderRaw is Map<String, dynamic>) {
      order = orderRaw;
    } else if (orderRaw is Map) {
      order = Map<String, dynamic>.from(orderRaw);
    }

    // ANAMNESIS
    _setIfEmpty(
      _keluhanUtamaController,
      root['keluhan_awal'] ?? emr['keluhan_utama'] ?? order['keluhan_utama'],
    );

    _setIfEmpty(
      _riwayatPenyakitDahuluController,
      emr['riwayat_penyakit_dahulu'] ??
          root['riwayat_penyakit_dahulu'] ??
          order['riwayat_penyakit_dahulu'],
    );

    _setIfEmpty(
      _riwayatKeluargaController,
      emr['riwayat_penyakit_keluarga'] ??
          root['riwayat_penyakit_keluarga'] ??
          order['riwayat_penyakit_keluarga'],
    );

    // VITAL SIGN
    _setIfEmpty(
      _tekananDarahController,
      root['tekanan_darah'] ?? emr['tekanan_darah'] ?? order['tekanan_darah'],
    );

    _setIfEmpty(
      _suhuTubuhController,
      root['suhu_tubuh'] ?? emr['suhu_tubuh'] ?? order['suhu_tubuh'],
    );

    _setIfEmpty(_nadiController, root['nadi'] ?? emr['nadi'] ?? order['nadi']);

    _setIfEmpty(
      _pernapasanController,
      root['pernapasan'] ?? emr['pernapasan'] ?? order['pernapasan'],
    );

    _setIfEmpty(
      _saturasiOksigenController,
      root['saturasi_oksigen'] ??
          emr['saturasi_oksigen'] ??
          order['saturasi_oksigen'],
    );

    // DIAGNOSIS (kalau nanti EMR lama / edit)
    _setIfEmpty(
      _diagnosisController,
      root['diagnosis'] ?? emr['diagnosis'] ?? order['diagnosis'],
    );
  }

  // ➜ tambahkan helper INI kalau belum ada
  void _setIfEmpty(TextEditingController c, dynamic v) {
    if (v == null) return;
    if (c.text.trim().isNotEmpty) return;

    final text = v.toString();
    if (text.trim().isEmpty) return;

    c.text = text;
  }

  // ================== OBAT & LAYANAN ==================

  void _onObatSearchChanged(String query) {
    _obatSearchDebounce?.cancel();
    _obatSearchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _searchObatQuery = query;
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
        });
      }
    });
  }

  Future<void> _loadAvailableObat() async {
    if (!mounted) return;

    setState(() => _isLoadingObat = true);

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
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Network error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingObat = false);
      }
    }
  }

  Future<void> _loadAvailableLayanan() async {
    if (!mounted) return;

    setState(() => _isLoadingLayanan = true);

    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/dokter/get-layanan'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final list = (body is Map && body['data'] is List)
            ? List<Map<String, dynamic>>.from(body['data'])
            : <Map<String, dynamic>>[];

        final normalized = list
            .map((e) {
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
                'harga_layanan': numeric,
                'poli_id': e['poli_id'],
              };
            })
            .where((e) => e['id'] != null && e['nama_layanan'] != null)
            .toList();

        setState(() => _availableLayanan = normalized);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Gagal memuat layanan. Silakan coba lagi.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingLayanan = false);
      }
    }
  }

  Future<void> _loadOrderedLayanan() async {
    if (!mounted) return;

    final kunjunganId =
        widget.kunjunganData['id'] ?? widget.kunjunganData['kunjungan_id'];

    if (kunjunganId == null) return;

    try {
      final token = await getToken();

      final res = await http.get(
        Uri.parse('$baseUrl/dokter/detail-order-layanan/$kunjunganId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (!mounted) return;

      if (res.statusCode == 200) {
        final body = json.decode(res.body);

        final list = (body is Map && body['data'] is List)
            ? List<Map<String, dynamic>>.from(body['data'])
            : <Map<String, dynamic>>[];

        setState(() => _orderedLayanan = list);
      }
    } catch (_) {
      // silent
    }
  }

  // ================== SAVE EMR ==================

 Future<void> _saveEMR() async {
  if (!_formKey.currentState!.validate()) return;

  // --- Ambil kunjungan_id yang benar ---
  final root = widget.kunjunganData;
  final orderRaw = root['order'];

  final Map<String, dynamic> order =
      orderRaw is Map<String, dynamic> ? orderRaw
      : (orderRaw is Map ? Map<String, dynamic>.from(orderRaw) : {});

  // kemungkinan lokasi id kunjungan:
  dynamic kunjunganIdDynamic =
      root['kunjungan_id'] ??        // kalau sudah dikirim langsung
      root['id'] ??                  // fallback
      order['kunjungan_id'];         // dari order (contoh: 12)

  // pastikan jadi int
  final int? kunjunganId = kunjunganIdDynamic is int
      ? kunjunganIdDynamic
      : int.tryParse(kunjunganIdDynamic?.toString() ?? '');

  if (kunjunganId == null) {
    _showErrorSnackbar(
      'ID kunjungan tidak ditemukan. '
      'Silakan buka ulang halaman ini dari daftar layanan.',
    );
    return;
  }

  setState(() => _isLoading = true);

  try {
    final token = await getToken();

    // --- payload yang dikirim ke API ---
    final emrData = <String, dynamic>{
      'kunjungan_id': kunjunganId,
      'diagnosis': _diagnosisController.text.trim(),
      'keluhan_utama': _keluhanUtamaController.text.trim(),
      'riwayat_penyakit_dahulu':
          _riwayatPenyakitDahuluController.text.trim(),
      'riwayat_penyakit_keluarga':
          _riwayatKeluargaController.text.trim(),
      'tekanan_darah': _tekananDarahController.text.trim(),
      'suhu_tubuh': _suhuTubuhController.text.trim(),
      'nadi': _nadiController.text.trim(),
      'pernapasan': _pernapasanController.text.trim(),
      'saturasi_oksigen': _saturasiOksigenController.text.trim(),
    };

    // kirim layanan tambahan kalau ada
    if (_selectedLayanan.isNotEmpty) {
      emrData['layanan'] = _selectedLayanan.map((l) {
        return {
          'layanan_id': l['layanan_id'] ?? l['id'],
          'jumlah': l['jumlah'] ?? 1,
        };
      }).toList();
    }

    // DEBUG: lihat payload di console
    debugPrint('PAYLOAD SAVE EMR LAYANAN: ${json.encode(emrData)}');

    final response = await http.post(
      Uri.parse('$baseUrl/dokter/save-emr-layanan'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: json.encode(emrData),
    );

    if (!mounted) return;

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);

      if (data['success'] == true) {
        final msg = data['message'] ?? 'EMR berhasil disimpan';
        _showSuccessSnackbar(msg);

        Navigator.pop(context, {
          'success': true,
          'emr_data': data['data'],
          'status_updated': true,
          'message': msg,
        });
      } else {
        _showErrorSnackbar(data['message'] ?? 'Gagal menyimpan EMR');
      }
    } else if (response.statusCode == 422) {
      // validation error dari Laravel
      final body = json.decode(response.body);
      debugPrint('VALIDATION ERROR: $body');
      _showErrorSnackbar(body['message'] ?? 'Validasi gagal (422)');
    } else {
      debugPrint('SERVER ERROR ${response.statusCode}: ${response.body}');
      _showErrorSnackbar('Server error: ${response.statusCode}');
    }
  } catch (e) {
    if (mounted) {
      _showErrorSnackbar('Network error: $e');
    }
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}


  // ================== SNACKBAR ==================

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: _red500,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: _emerald500,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ================== OBAT & LAYANAN UI HELPER ==================

  List<Map<String, dynamic>> get _filteredObat {
    if (_searchObatQuery.isEmpty) return _availableObat;
    final q = _searchObatQuery.toLowerCase();
    return _availableObat
        .where(
          (o) => (o['nama_obat'] ?? '').toString().toLowerCase().contains(q),
        )
        .toList();
  }

  List<Map<String, dynamic>> get _filteredLayanan {
    if (_searchLayananQuery.isEmpty) return _availableLayanan;
    final q = _searchLayananQuery.toLowerCase();
    return _availableLayanan
        .where(
          (l) => (l['nama_layanan'] ?? '').toString().toLowerCase().contains(q),
        )
        .toList();
  }

  void _addObatToResep(Map<String, dynamic> obat) {
    final already = _selectedResep.any((r) => r['obat_id'] == obat['id']);
    if (already) {
      _showErrorSnackbar('Obat sudah ditambahkan');
      return;
    }
    _showAddObatDialog(obat);
  }

  Future<void> _showAddObatDialog(Map<String, dynamic> obat) async {
    final keteranganController = TextEditingController();
    final jumlahController = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Tambah Obat ke Resep',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _slate900,
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildObatInfoCard(obat),
              const SizedBox(height: 16),
              _buildInput(
                controller: jumlahController,
                label: 'Jumlah',
                hint: 'Masukkan jumlah',
                suffix: 'tablet',
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
                    return 'Jumlah melebihi stok';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildInput(
                controller: keteranganController,
                label: 'Keterangan Penggunaan',
                hint: 'Contoh: 3x sehari sebelum makan',
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
        actions: [
          _buildSecondaryButton('Batal', () => Navigator.pop(context)),
          const SizedBox(width: 8),
          _buildPrimaryButton('Tambah', () {
            if (formKey.currentState!.validate()) {
              setState(() {
                _selectedResep.add({
                  'obat_id': obat['id'],
                  'nama_obat': obat['nama_obat'],
                  'dosis': obat['dosis'],
                  'total_harga': obat['total_harga'],
                  'jumlah': int.parse(jumlahController.text),
                  'keterangan': keteranganController.text.trim(),
                });
              });
              Navigator.pop(context);
              _showSuccessSnackbar('${obat['nama_obat']} berhasil ditambahkan');
            }
          }),
        ],
      ),
    );
  }

  void _addLayananToSelection(Map<String, dynamic> layanan) {
    final already = _selectedLayanan.any(
      (selected) => selected['layanan_id'] == layanan['id'],
    );
    if (already) {
      _showErrorSnackbar('Layanan sudah ditambahkan');
      return;
    }
    _showAddLayananDialog(layanan);
  }

  Future<void> _showAddLayananDialog(Map<String, dynamic> layanan) async {
    final jumlahController = TextEditingController(text: '1');
    final formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Tambah Layanan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _slate900,
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLayananInfoCard(layanan),
              const SizedBox(height: 16),
              _buildInput(
                controller: jumlahController,
                label: 'Jumlah',
                hint: 'Masukkan jumlah',
                suffix: 'kali',
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
        actions: [
          _buildSecondaryButton('Batal', () => Navigator.pop(context)),
          const SizedBox(width: 8),
          _buildPrimaryButton('Tambah', () {
            if (formKey.currentState!.validate()) {
              setState(() {
                _selectedLayanan.add({
                  'layanan_id': layanan['id'],
                  'nama_layanan': layanan['nama_layanan'],
                  'harga_layanan': layanan['harga_layanan'],
                  'jumlah': int.parse(jumlahController.text),
                });
              });
              Navigator.pop(context);
              _showSuccessSnackbar(
                '${layanan['nama_layanan']} berhasil ditambahkan',
              );
            }
          }),
        ],
      ),
    );
  }

  void _removeObatFromResep(int index) {
    setState(() => _selectedResep.removeAt(index));
  }

  void _removeLayananFromSelection(int index) {
    setState(() => _selectedLayanan.removeAt(index));
  }

  // ================== FORMAT & UI HELPER ==================

  String _formatTanggal(String? tanggal) {
    if (tanggal == null || tanggal.isEmpty) return 'Tidak tersedia';

    try {
      DateTime dateTime;
      if (tanggal.contains('T')) {
        dateTime = DateTime.parse(tanggal).toLocal();
      } else if (tanggal.contains('-')) {
        final parts = tanggal.split('-');
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

      return '${dateTime.day.toString().padLeft(2, '0')}-'
          '${dateTime.month.toString().padLeft(2, '0')}-'
          '${dateTime.year}';
    } catch (_) {
      return tanggal;
    }
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    try {
      if (price is String) {
        final p = double.parse(price);
        return p.toStringAsFixed(0);
      } else if (price is num) {
        return price.toStringAsFixed(0);
      } else {
        return price.toString();
      }
    } catch (_) {
      return price.toString();
    }
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    String? hint,
    String? suffix,
    bool readOnly = false,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    Widget? prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _slate700,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: TextStyle(
            fontSize: 14,
            color: readOnly ? _slate500 : _slate900,
          ),
          decoration: InputDecoration(
            hintText: hint,
            suffixText: suffix,
            prefixIcon: prefixIcon,
            filled: true,
            fillColor: readOnly ? _slate50 : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _slate200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _slate200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _blue500, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _red500),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: _blue600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        elevation: 0,
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildSecondaryButton(String text, VoidCallback onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: _slate700,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        side: const BorderSide(color: _slate200),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildBadge(String text, {Color? backgroundColor, Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? _slate100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor ?? _slate700,
        ),
      ),
    );
  }

  Widget _buildObatInfoCard(Map<String, dynamic> obat) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _emerald50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _emerald100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            obat['nama_obat'] ?? 'Unknown Medicine',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _slate900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Stok: ${obat['jumlah'] ?? 0} • Dosis: ${obat['dosis'] ?? 0}mg',
            style: const TextStyle(fontSize: 13, color: _slate600),
          ),
        ],
      ),
    );
  }

  Widget _buildLayananInfoCard(Map<String, dynamic> layanan) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _blue50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _blue100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            layanan['nama_layanan'] ?? 'Unknown Service',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: _slate900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Harga: Rp ${_formatPrice(layanan['harga_layanan'])}',
            style: const TextStyle(fontSize: 13, color: _slate600),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField({
    required TextEditingController controller,
    required String label,
    String? suffix,
    int maxLines = 1,
    required bool isEditable,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _slate700,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: !isEditable,
          maxLines: maxLines,
          style: TextStyle(
            fontSize: 14,
            color: isEditable ? _slate900 : _slate600,
          ),
          decoration: InputDecoration(
            suffixText: suffix,
            filled: true,
            fillColor: isEditable ? Colors.white : _slate50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: _slate200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(color: isEditable ? _blue500 : _slate200),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(6)),
              borderSide: BorderSide(color: _blue500, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPerawatInfoCard() {
    final emrRaw = widget.kunjunganData['emr'];

    Map<String, dynamic>? emr;
    if (emrRaw is Map<String, dynamic>) {
      emr = emrRaw;
    } else if (emrRaw is Map) {
      emr = Map<String, dynamic>.from(emrRaw);
    }

    final perawatRaw =
        (emr != null ? emr['perawat'] : null) ??
        widget.kunjunganData['perawat'];

    Map<String, dynamic>? perawat;
    if (perawatRaw is Map<String, dynamic>) {
      perawat = perawatRaw;
    } else if (perawatRaw is Map) {
      perawat = Map<String, dynamic>.from(perawatRaw);
    }

    if (perawat == null) return const SizedBox.shrink();

    return _buildCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _emerald100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person_outline,
                color: _emerald600,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pemeriksaan Awal Perawat',
                    style: TextStyle(fontSize: 12, color: _slate500),
                  ),
                  Text(
                    perawat['nama_perawat'] ?? 'Perawat',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _slate900,
                    ),
                  ),
                ],
              ),
            ),
            _buildBadge(
              'Selesai',
              backgroundColor: _emerald600,
              textColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  // ================== BUILD UI ==================

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth >= 1024;
    final bool isTablet = screenWidth >= 768 && screenWidth < 1024;
    final bool isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: _slate50,
      body: Row(
        children: [
          if (isDesktop || isTablet)
            Sidebar.SharedSidebar(
              currentPage: Sidebar.SidebarPage.layananDokter,
              dokterData: _dokterData,
              isCollapsed: _isSidebarCollapsed,
              onToggleCollapse: () {
                setState(() => _isSidebarCollapsed = !_isSidebarCollapsed);
              },
              onNavigate: (page) => Sidebar.NavigationHelper.navigateToPage(
                context,
                page,
                dokterData: _dokterData,
              ),
              onLogout: () => Sidebar.NavigationHelper.logout(context),
            ),

          Expanded(
            child: Column(
              children: [
                Sidebar.SharedTopHeader(
                  currentPage: Sidebar.SidebarPage.layananDokter,
                  dokterData: _dokterData,
                  isMobile: isMobile,
                  onRefresh: _initializeData,
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(
                                  Icons.arrow_back,
                                  color: _slate600,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(color: _slate200),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pemeriksaan Layanan',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w600,
                                        color: _slate900,
                                      ),
                                    ),
                                    Text(
                                      'Lengkapi pemeriksaan & EMR untuk layanan yang dipesan pasien',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: _slate600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          _buildPatientInfoCard(),
                          _buildPerawatInfoCard(),

                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // ANAMNESIS
                                _buildCard(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: _emerald100,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.description_outlined,
                                                size: 16,
                                                color: _emerald600,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Anamnesis',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: _slate900,
                                              ),
                                            ),
                                            const Spacer(),
                                            TextButton.icon(
                                              onPressed: () {
                                                setState(() {
                                                  _isEditingAnamnesis =
                                                      !_isEditingAnamnesis;
                                                });
                                              },
                                              style: TextButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                backgroundColor:
                                                    _isEditingAnamnesis
                                                    ? _emerald50
                                                    : Colors.white,
                                                shape: StadiumBorder(
                                                  side: BorderSide(
                                                    color: _emerald600,
                                                  ),
                                                ),
                                              ),
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 16,
                                                color: _emerald600,
                                              ),
                                              label: Text(
                                                _isEditingAnamnesis
                                                    ? 'Selesai Edit'
                                                    : 'Edit Data',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: _emerald600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),

                                        _buildEditableField(
                                          controller: _keluhanUtamaController,
                                          label: 'Keluhan Utama',
                                          maxLines: 3,
                                          isEditable: _isEditingAnamnesis,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildEditableField(
                                          controller:
                                              _riwayatPenyakitDahuluController,
                                          label: 'Riwayat Penyakit Dahulu',
                                          maxLines: 4,
                                          isEditable: _isEditingAnamnesis,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildEditableField(
                                          controller:
                                              _riwayatKeluargaController,
                                          label: 'Riwayat Keluarga',
                                          maxLines: 3,
                                          isEditable: _isEditingAnamnesis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // TANDA VITAL
                                _buildCard(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: _emerald100,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.favorite_outline,
                                                size: 16,
                                                color: _emerald600,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Tanda Vital',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: _slate900,
                                              ),
                                            ),
                                            const Spacer(),
                                            TextButton.icon(
                                              onPressed: () {
                                                setState(() {
                                                  _isEditingVital =
                                                      !_isEditingVital;
                                                });
                                              },
                                              style: TextButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                                backgroundColor: _isEditingVital
                                                    ? _blue50
                                                    : Colors.white,
                                                shape: StadiumBorder(
                                                  side: BorderSide(
                                                    color: _blue600,
                                                  ),
                                                ),
                                              ),
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 16,
                                                color: _blue600,
                                              ),
                                              label: Text(
                                                _isEditingVital
                                                    ? 'Selesai Edit'
                                                    : 'Edit Data',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: _blue600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),

                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildEditableField(
                                                controller:
                                                    _tekananDarahController,
                                                label: 'Tekanan Darah',
                                                suffix: 'mmHg',
                                                isEditable: _isEditingVital,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: _buildEditableField(
                                                controller:
                                                    _suhuTubuhController,
                                                label: 'Suhu Tubuh',
                                                suffix: '°C',
                                                isEditable: _isEditingVital,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildEditableField(
                                                controller: _nadiController,
                                                label: 'Nadi',
                                                suffix: 'bpm',
                                                isEditable: _isEditingVital,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: _buildEditableField(
                                                controller:
                                                    _pernapasanController,
                                                label: 'Pernapasan',
                                                suffix: '/menit',
                                                isEditable: _isEditingVital,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        _buildEditableField(
                                          controller:
                                              _saturasiOksigenController,
                                          label: 'Saturasi Oksigen',
                                          suffix: '%',
                                          isEditable: _isEditingVital,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // DIAGNOSIS
                                _buildCard(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: _blue100,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.medical_services_outlined,
                                                size: 16,
                                                color: _blue600,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Diagnosis',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: _slate900,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            _buildBadge(
                                              'Dokter',
                                              backgroundColor: _blue600,
                                              textColor: Colors.white,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        _buildInput(
                                          controller: _diagnosisController,
                                          label: 'Diagnosis',
                                          hint:
                                              'Masukkan diagnosis berdasarkan pemeriksaan...',
                                          maxLines: 4,
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return 'Diagnosis harus diisi';
                                            }
                                            return null;
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                _buildLayananSection(),
                                // _buildResepSection(),  nanti mana tau butuh resep

                                // BUTTONS
                                _buildCard(
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: _buildSecondaryButton(
                                            'Batal',
                                            () => Navigator.pop(context),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          flex: 2,
                                          child: _isLoading
                                              ? Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 12,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: _blue600.withOpacity(
                                                      0.6,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                  child: const Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      SizedBox(
                                                        width: 16,
                                                        height: 16,
                                                        child: CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          valueColor:
                                                              AlwaysStoppedAnimation<
                                                                Color
                                                              >(Colors.white),
                                                        ),
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Menyimpan...',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              : _buildPrimaryButton(
                                                  'Selesaikan EMR',
                                                  _saveEMR,
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      drawer: isMobile
          ? Sidebar.SharedMobileDrawer(
              currentPage: Sidebar.SidebarPage.layananDokter,
              dokterData: _dokterData,
              onNavigate: (page) => Sidebar.NavigationHelper.navigateToPage(
                context,
                page,
                dokterData: _dokterData,
              ),
              onLogout: () => Sidebar.NavigationHelper.logout(context),
            )
          : null,
    );
  }

  Widget _buildPatientInfoCard() {
    final root = widget.kunjunganData;
    final orderRaw = root['order'] ?? root;

    Map<String, dynamic> order = {};
    if (orderRaw is Map<String, dynamic>) {
      order = orderRaw;
    } else if (orderRaw is Map) {
      order = Map<String, dynamic>.from(orderRaw);
    }

    final namaPasien =
        (order['nama_pasien'] ?? root['nama_pasien'] ?? 'Tidak tersedia')
            .toString();
    final noRm = (order['no_rekam_medis'] ?? root['no_rekam_medis'] ?? '-')
        .toString();
    final poliNama = (order['nama_poli'] ?? root['nama_poli'] ?? '-')
        .toString();
    final ringkasan =
        (order['ringkasan_layanan'] ?? root['ringkasan_layanan'] ?? '-')
            .toString();

    final tanggal =
        (order['tanggal_kunjungan'] ??
                root['tanggal_kunjungan'] ??
                order['created_at'] ??
                root['created_at'] ??
                '-')
            .toString();

    return _buildCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _blue100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.person_outline,
                color: _blue600,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    namaPasien,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _slate900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildBadge('RM $noRm'),
                      const SizedBox(width: 8),
                      _buildBadge(poliNama),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (ringkasan.isNotEmpty && ringkasan != '-')
                    Text(
                      ringkasan,
                      style: const TextStyle(fontSize: 13, color: _slate600),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Tanggal: ${_formatTanggal(tanggal)}',
                    style: const TextStyle(fontSize: 12, color: _slate500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================== LAYANAN & RESEP SECTION ==================

  Widget _buildLayananSection() {
    final root = widget.kunjunganData;
    final order = root['order'] ?? {};

    String ringkasan =
        (root['ringkasan_layanan'] ??
                order['ringkasan_layanan'] ??
                order['nama_layanan'] ??
                order['layanan'] ??
                '')
            .toString()
            .trim();

    if (ringkasan.isEmpty && _orderedLayanan.isNotEmpty) {
      final names = _orderedLayanan
          .map((e) => (e['nama_layanan'] ?? '').toString().trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      ringkasan = names.join(', ');
    }

    return _buildCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _blue100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.medical_services_outlined,
                    size: 16,
                    color: _blue600,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Layanan Medis',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _slate900,
                  ),
                ),
                const SizedBox(width: 8),
                _buildBadge('Opsional'),
              ],
            ),

            const SizedBox(height: 16),

            const Text(
              'Layanan yang dipilih pasien',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _slate900,
              ),
            ),
            const SizedBox(height: 10),

            if (_orderedLayanan.isNotEmpty)
              Column(
                children: _orderedLayanan.map((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _slate200),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.medical_services_outlined,
                          size: 20,
                          color: _blue600,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (item['nama_layanan'] ?? 'Layanan').toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  color: _slate900,
                                ),
                              ),
                              Text(
                                'Rp ${_formatPrice(item['harga_layanan'])}'
                                '${item['jumlah'] != null ? ' • ${item['jumlah']}x' : ''}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: _slate600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _slate50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _slate200),
                ),
                child: Text(
                  ringkasan.isNotEmpty
                      ? ringkasan
                      : 'Belum ada layanan dari pasien.',
                  style: const TextStyle(fontSize: 13, color: _slate700),
                ),
              ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            const Text(
              'Layanan Tambahan',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _slate900,
              ),
            ),
            const SizedBox(height: 12),

            _buildInput(
              controller: _searchLayananController,
              label: 'Cari Layanan',
              hint: 'Ketik nama layanan...',
              prefixIcon: const Icon(Icons.search, size: 16, color: _slate400),
            ),
            const SizedBox(height: 16),
            _buildLayananList(),

            if (_selectedLayanan.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Layanan Tambahan Terpilih',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _slate900,
                ),
              ),
              const SizedBox(height: 8),
              _buildSelectedLayananList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResepSection() {
    return _buildCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _emerald100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.medication_outlined,
                    size: 16,
                    color: _emerald600,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Resep Obat',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _slate900,
                  ),
                ),
                const SizedBox(width: 8),
                _buildBadge('Opsional'),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _emerald50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _emerald100),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: _emerald600),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Resep obat bersifat opsional dan dapat ditambahkan sesuai kebutuhan.',
                      style: TextStyle(fontSize: 12, color: _emerald600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildInput(
              controller: _searchObatController,
              label: 'Cari Obat',
              hint: 'Ketik nama obat...',
              prefixIcon: const Icon(Icons.search, size: 16, color: _slate400),
            ),
            const SizedBox(height: 16),
            _buildObatList(),
            if (_selectedResep.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Resep Terpilih',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _slate900,
                ),
              ),
              const SizedBox(height: 8),
              _buildSelectedResepList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLayananList() {
    if (_isLoadingLayanan) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(color: _blue600)),
      );
    }

    final list = _filteredLayanan;

    if (list.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off, size: 48, color: _slate400),
              const SizedBox(height: 8),
              Text(
                _searchLayananQuery.isNotEmpty
                    ? 'Tidak ada layanan ditemukan'
                    : 'Tidak ada layanan tersedia',
                style: const TextStyle(color: _slate500),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: ListView.builder(
        itemCount: list.length,
        itemBuilder: (context, index) {
          final layanan = list[index];
          final isSelected = _selectedLayanan.any(
            (selected) => selected['layanan_id'] == layanan['id'],
          );

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? _emerald50 : Colors.white,
              border: Border.all(color: isSelected ? _emerald500 : _slate200),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.medical_services_outlined,
                  color: isSelected ? _emerald500 : _slate400,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        layanan['nama_layanan'] ?? 'Unknown Service',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: _slate900,
                        ),
                      ),
                      Text(
                        'Rp ${_formatPrice(layanan['harga_layanan'])}',
                        style: const TextStyle(fontSize: 12, color: _slate500),
                      ),
                    ],
                  ),
                ),
                if (!isSelected)
                  _buildPrimaryButton(
                    'Tambah',
                    () => _addLayananToSelection(layanan),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildObatList() {
    if (_isLoadingObat) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator(color: _emerald600)),
      );
    }

    final list = _filteredObat;

    if (list.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off, size: 48, color: _slate400),
              const SizedBox(height: 8),
              Text(
                _searchObatQuery.isNotEmpty
                    ? 'Tidak ada obat ditemukan'
                    : 'Tidak ada obat tersedia',
                style: const TextStyle(color: _slate500),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 250,
      child: ListView.builder(
        itemCount: list.length,
        itemBuilder: (context, index) {
          final obat = list[index];
          final isSelected = _selectedResep.any(
            (r) => r['obat_id'] == obat['id'],
          );

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? _emerald50 : Colors.white,
              border: Border.all(color: isSelected ? _emerald500 : _slate200),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? Icons.check_circle : Icons.medication_outlined,
                  color: isSelected ? _emerald500 : _slate400,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        obat['nama_obat'] ?? 'Unknown Medicine',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: _slate900,
                        ),
                      ),
                      Text(
                        'Stok: ${obat['jumlah'] ?? 0} • Dosis: ${obat['dosis'] ?? 0}mg',
                        style: const TextStyle(fontSize: 12, color: _slate500),
                      ),
                    ],
                  ),
                ),
                if (!isSelected)
                  _buildPrimaryButton('Tambah', () => _addObatToResep(obat)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedLayananList() {
    return Column(
      children: _selectedLayanan.map((layanan) {
        final index = _selectedLayanan.indexOf(layanan);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _slate200),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.medical_services_outlined,
                color: _blue600,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      layanan['nama_layanan'] ?? 'Unknown Service',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: _slate900,
                      ),
                    ),
                    Text(
                      '${layanan['jumlah']} kali • Rp ${_formatPrice(layanan['harga_layanan'])}',
                      style: const TextStyle(fontSize: 12, color: _slate500),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _removeLayananFromSelection(index),
                icon: const Icon(Icons.close, color: _red500, size: 16),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSelectedResepList() {
    return Column(
      children: _selectedResep.map((resep) {
        final index = _selectedResep.indexOf(resep);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _slate200),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.medication_outlined,
                    color: _emerald600,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resep['nama_obat'] ?? 'Unknown Medicine',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: _slate900,
                          ),
                        ),
                        Text(
                          '${resep['jumlah']} tablet • ${resep['dosis']}mg',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => _removeObatFromResep(index),
                    icon: const Icon(Icons.close, color: _red500, size: 16),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _slate50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Keterangan:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _slate500,
                      ),
                    ),
                    Text(
                      resep['keterangan'] ?? 'Belum ada keterangan',
                      style: const TextStyle(fontSize: 14, color: _slate900),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
