import 'dart:convert';
import 'dart:async';
import 'package:RoyalClinic/pasien/edit_profile.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'RiwayatKunjungan.dart';
import 'package:intl/intl.dart'; // Tambahkan import ini untuk format tanggal

class PesanJadwal extends StatefulWidget {
  final List<dynamic>? allJadwal;
  final int? poliId;
  final String? namaPoli;

  const PesanJadwal({Key? key, this.allJadwal, this.poliId, this.namaPoli})
    : super(key: key);

  @override
  State<PesanJadwal> createState() => _PesanJadwalState();
}

class _PesanJadwalState extends State<PesanJadwal>
    with TickerProviderStateMixin {
  bool isLoading = false;
  bool isLoadingPoli = false;
  List<dynamic> poliList = [];
  List<dynamic> dokterList = [];
  List<dynamic> filteredDokter = [];
  List<dynamic> searchFilteredDokter = [];
  int? selectedPoliId;

  // Search controllers and animations
  final TextEditingController _searchController = TextEditingController();
  bool isSearchActive = false;
  bool isTyping = false;

  // Animation controllers
  late AnimationController _searchAnimationController;
  late AnimationController _typingTextController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  // Typing animation variables
  int _currentIndex = 0;
  String _currentText = '';
  Timer? _typingTimer;
  bool _showCursor = true;
  final String _fullText = 'Cari nama dokter atau poli...';

  Map<int, TextEditingController> keluhanControllers = {};
  Map<int, Map<String, dynamic>?> selectedJadwal = {};
  Map<int, bool> expandedDokter = {};

  @override
  void initState() {
    super.initState();
    selectedJadwal.clear();

    // Initialize animation controllers
    _searchAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _typingTextController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Setup animations
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

    // Start typing text animation
    _startTypingAnimation();

    // Start cursor blink animation
    _typingTextController.repeat(reverse: true);

    if (widget.poliId != null) {
      selectedPoliId = widget.poliId;
      if (widget.allJadwal != null) {
        dokterList = widget.allJadwal!;
        filteredDokter = widget.allJadwal!;
        searchFilteredDokter = filteredDokter;
      } else {
        fetchAllDokter();
      }
    } else {
      if (widget.allJadwal != null) {
        dokterList = widget.allJadwal!;
        filteredDokter = widget.allJadwal!;
        searchFilteredDokter = filteredDokter;
      } else {
        fetchAllDokter();
      }
      fetchPoli();
    }

    _searchController.addListener(_onSearchChanged);
  }

  void _startTypingAnimation() {
    _typingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) return;

      if (_searchController.text.isEmpty && !isSearchActive) {
        setState(() {
          if (_currentText.length < _fullText.length) {
            _currentText = _fullText.substring(0, _currentText.length + 1);
          } else {
            Timer(const Duration(milliseconds: 3000), () {
              if (!mounted) return;
              setState(() {
                _currentText = '';
              });
              timer.cancel();
              Timer(const Duration(milliseconds: 500), () {
                if (mounted &&
                    _searchController.text.isEmpty &&
                    !isSearchActive) {
                  _startTypingAnimation();
                }
              });
            });
            timer.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchAnimationController.dispose();
    _typingTextController.dispose();
    if (_typingTimer != null) _typingTimer!.cancel();
    for (var controller in keluhanControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      isTyping = _searchController.text.isNotEmpty;
      isSearchActive = _searchController.text.isNotEmpty;
    });

    if (_searchController.text.isNotEmpty) {
      _searchAnimationController.forward();
    } else {
      _searchAnimationController.reverse();
      Timer(const Duration(milliseconds: 500), () {
        if (mounted && _searchController.text.isEmpty) {
          _currentText = '';
          _startTypingAnimation();
        }
      });
    }

    _performSearch(_searchController.text);
  }

  void _performSearch(String query) {
    setState(() {
      isSearchActive = query.isNotEmpty;

      if (query.isEmpty) {
        searchFilteredDokter = filteredDokter;
      } else {
        final lowercaseQuery = query.toLowerCase();

        searchFilteredDokter = filteredDokter.where((dokter) {
          // Search by doctor name
          final dokterName = (dokter['nama_dokter'] ?? '').toLowerCase();

          // Search by poli name
          final poliName = (dokter['poli']?['nama_poli'] ?? '').toLowerCase();

          return dokterName.contains(lowercaseQuery) ||
              poliName.contains(lowercaseQuery);
        }).toList();
      }
    });
  }

  Future<void> fetchPoli() async {
    if (mounted) {
      setState(() => isLoadingPoli = true);
    }

    try {
      final response = await http.get(
        Uri.parse('http://10.227.74.71:8000/api/getDataPoli'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        if (mounted) {
          setState(() {
            poliList = data['data'];
            isLoadingPoli = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => isLoadingPoli = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoadingPoli = false);
      }
    }
  }

  Future<void> fetchAllDokter() async {
    if (mounted) {
      setState(() => isLoading = true);
    }

    try {
      final response = await http.get(
        Uri.parse('http://10.227.74.71:8000/api/getAllDokter'),
        headers: {'Content-Type': 'application/json'},
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        print('Data received: ${data['data'].length} doctors');
        if (mounted) {
          setState(() {
            dokterList = data['data'];
            filteredDokter = dokterList;
            searchFilteredDokter = filteredDokter;
            isLoading = false;
          });
          print('dokterList length after setState: ${dokterList.length}');
          print('searchFilteredDokter length: ${searchFilteredDokter.length}');
        }
      } else {
        print('API call failed: ${data['message'] ?? 'Unknown error'}');
        if (mounted) {
          setState(() => isLoading = false);
        }
      }
    } catch (e) {
      print('Exception in fetchAllDokter: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> filterByPoli(int poliId) async {
    if (mounted) {
      setState(() => isLoading = true);
    }

    try {
      // Filter dokter berdasarkan poli_id
      List<dynamic> newDokter = dokterList.where((dokter) {
        return dokter['poli']?['id'] == poliId;
      }).toList();

      if (mounted) {
        setState(() {
          filteredDokter = newDokter;
          selectedPoliId = poliId;
          selectedJadwal.clear();
          isLoading = false;
          _performSearch(_searchController.text);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Kesalahan koneksi: $e')));
      }
    }
  }

  void resetFilter() {
    if (mounted) {
      setState(() {
        filteredDokter = dokterList;
        selectedPoliId = null;
        selectedJadwal.clear();
        _performSearch(_searchController.text);
      });
    }
  }

  void clearSearch() {
    _searchController.clear();
    _searchAnimationController.reverse();
    setState(() {
      isSearchActive = false;
      isTyping = false;
      searchFilteredDokter = filteredDokter;
    });
  }

  Future<int?> getPasienId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('pasien_id');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  // FUNGSI BARU: Mengonversi hari Indonesia ke nomor hari
  int getHariNumber(String hari) {
    final hariMapping = {
      'Senin': 1,
      'Selasa': 2,
      'Rabu': 3,
      'Kamis': 4,
      'Jumat': 5,
      'Sabtu': 6,
      'Minggu': 0,
    };
    return hariMapping[hari] ?? 1;
  }

DateTime getNextDateByDay(
  int dayOfWeek, {
  String? jamAwal,
  String? jamSelesai,
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  int daysUntilTarget = (dayOfWeek - today.weekday) % 7;

  // Jika hari yang sama (daysUntilTarget == 0)
  if (daysUntilTarget == 0) {
    // Jika ada info jam praktik, cek apakah masih dalam jam kerja
    if (jamAwal != null && jamSelesai != null) {
      if (_isWithinWorkingHours(now, jamAwal, jamSelesai)) {
        // ✅ PERBAIKAN: Masih dalam jam kerja, gunakan hari ini
        return today;
      } else {
        // ✅ PERBAIKAN: Sudah lewat jam kerja, loncat ke minggu depan
        daysUntilTarget = 7;
      }
    } else {
      // ✅ PERBAIKAN: Jika tidak ada info jam dan masih siang (sebelum jam 17:00), 
      // gunakan hari ini. Jika sudah sore, gunakan minggu depan
      if (now.hour < 17) {
        return today;
      } else {
        daysUntilTarget = 7;
      }
    }
  }

  return today.add(Duration(days: daysUntilTarget));
}

// Helper function untuk cek jam kerja
bool _isWithinWorkingHours(DateTime now, String jamAwal, String jamSelesai) {
  try {
    // Parse jam awal (contoh: "08:00")
    final awalParts = jamAwal.split(':');
    final jamAwalInt = int.parse(awalParts[0]);
    final menitAwalInt = int.parse(awalParts[1]);

    // Parse jam selesai (contoh: "16:00")
    final selesaiParts = jamSelesai.split(':');
    final jamSelesaiInt = int.parse(selesaiParts[0]);
    final menitSelesaiInt = int.parse(selesaiParts[1]);

    // Waktu sekarang dalam menit sejak tengah malam
    final nowMinutes = now.hour * 60 + now.minute;

    // Jam kerja dalam menit sejak tengah malam
    final startMinutes = jamAwalInt * 60 + menitAwalInt;
    final endMinutes = jamSelesaiInt * 60 + menitSelesaiInt;

    // ✅ PERBAIKAN: Beri toleransi 30 menit sebelum jam tutup untuk booking
    final bookingCutoffMinutes = endMinutes - 30;

    // Cek apakah masih dalam rentang waktu untuk booking
    return nowMinutes >= startMinutes && nowMinutes <= bookingCutoffMinutes;
  } catch (e) {
    print('Error parsing working hours: $e');
    // ✅ PERBAIKAN: Jika error parsing, cek berdasarkan jam sekarang
    // Jam 8 pagi sampai 4 sore adalah jam kerja default
    return now.hour >= 8 && now.hour < 16;
  }
}

  // FUNGSI BARU: Format tanggal dalam bahasa Indonesia
  String formatTanggalIndonesia(DateTime date) {
    final bulanIndonesia = [
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

    return '${date.day} ${bulanIndonesia[date.month - 1]} ${date.year}';
  }

  // FUNGSI BARU: Format jadwal dengan hari dan tanggal
  // PERBAIKAN - pass jam kerja
  String formatJadwalDropdown(Map<String, dynamic> jadwal) {
    final hari = jadwal['hari'];
    final jamAwal = jadwal['jam_awal'];
    final jamSelesai = jadwal['jam_selesai'];

    final hariNumber = getHariNumber(hari);
    final tanggalTerdekat = getNextDateByDay(
      hariNumber,
      jamAwal: jamAwal,
      jamSelesai: jamSelesai,
    );
    final tanggalFormatted = formatTanggalIndonesia(tanggalTerdekat);

    return "$hari, $tanggalFormatted ($jamAwal - $jamSelesai)";
  }

  Future<void> pesanSekarang(int dokterId) async {
  final pasienId = await getPasienId();
  final token = await getToken();
  final keluhan = keluhanControllers[dokterId]?.text.trim() ?? '';
  final selectedJadwalData = selectedJadwal[dokterId];

  if (pasienId == null || token == null) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data pasien atau token tidak ditemukan'),
        ),
      );
    }
    return;
  }

  if (keluhan.isEmpty || selectedJadwalData == null) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih jadwal dan isi keluhan terlebih dahulu'),
        ),
      );
    }
    return;
  }

  // Cari dokter untuk mendapatkan poli_id
  final dokter = searchFilteredDokter.firstWhere(
    (d) => (d['id_dokter'] ?? d['id']) == dokterId,
    orElse: () => null,
  );

  if (dokter == null) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data dokter tidak ditemukan')),
      );
    }
    return;
  }

  final poliId = dokter['poli']?['id'];
  if (poliId == null) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data poli dokter tidak ditemukan')),
      );
    }
    return;
  }

  // ✅ PERBAIKAN: Hitung tanggal yang benar berdasarkan jadwal yang dipilih
  final hari = selectedJadwalData['hari'];
  final jamAwal = selectedJadwalData['jam_awal'];
  final jamSelesai = selectedJadwalData['jam_selesai'];
  
  final hariNumber = getHariNumber(hari);
  final tanggalKunjungan = getNextDateByDay(
    hariNumber,
    jamAwal: jamAwal,
    jamSelesai: jamSelesai,
  );
  
  // Format tanggal untuk dikirim ke backend (YYYY-MM-DD)
  final tanggalKunjunganString = 
      '${tanggalKunjungan.year}-${tanggalKunjungan.month.toString().padLeft(2, '0')}-${tanggalKunjungan.day.toString().padLeft(2, '0')}';

  if (mounted) {
    setState(() => isLoading = true);
  }

  try {
    final response = await http.post(
      Uri.parse('http://10.227.74.71:8000/api/kunjungan/create'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'pasien_id': pasienId,
        'dokter_id': dokterId,
        'poli_id': poliId,
        'tanggal_kunjungan': tanggalKunjunganString, // ✅ Menggunakan tanggal yang benar
        'keluhan_awal': keluhan,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200 && data['success'] == true) {
      final dokterNama = dokter['nama_dokter'] ?? 'Dokter';

      keluhanControllers[dokterId]?.clear();
      if (mounted) {
        setState(() => selectedJadwal[dokterId] = null);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Berhasil memesan dengan $dokterNama untuk tanggal $tanggalKunjunganString, No Antrian: ${data['Data No Antrian'] ?? '-'}',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const RiwayatKunjungan()),
        );
      }
    }
    // Handle error responses...
    else if (response.statusCode == 422 &&
        data['error_code'] == 'PROFILE_INCOMPLETE') {
      if (mounted) {
        _showProfileIncompleteDialog();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'Gagal memesan jadwal')),
        );
      }
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kesalahan koneksi: $e')));
    }
  } finally {
    if (mounted) {
      setState(() => isLoading = false);
    }
  }
}

  // Tambahkan method untuk dialog profil tidak lengkap
  void _showProfileIncompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.person_outline,
                color: Colors.orange.shade600,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Text(
                'Profil Belum Lengkap',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: const Text(
            'Mohon lengkapi data profil Anda terlebih dahulu sebelum membuat janji dengan dokter.\n\nData yang harus diisi:\n• Nama lengkap\n• Alamat\n• Tanggal lahir\n• Jenis kelamin',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Tutup dialog
              },
              child: Text(
                'Nanti',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                  Navigator.pop(context, MaterialPageRoute(builder: (context) => EditProfilePage(),));
              },
              child: const Text(
                'Lengkapi Profil',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          widget.namaPoli != null
              ? 'Dokter ${widget.namaPoli}'
              : 'Pesan Jadwal Dokter',
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Search Bar
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.white,
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
                                      color: isSearchActive
                                          ? const Color(0xFF00897B)
                                          : Colors.transparent,
                                      width: isSearchActive ? 2 : 1,
                                    ),
                                    boxShadow: isSearchActive
                                        ? [
                                            BoxShadow(
                                              color: const Color(
                                                0xFF00897B,
                                              ).withOpacity(0.15),
                                              blurRadius: 10,
                                              spreadRadius: 1,
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText:
                                          _searchController.text.isEmpty &&
                                              !isSearchActive
                                          ? _currentText +
                                                (_showCursor &&
                                                        _currentText.length <
                                                            _fullText.length
                                                    ? '|'
                                                    : '')
                                          : 'Ketik untuk mencari...',
                                      hintStyle: TextStyle(
                                        color:
                                            _searchController.text.isEmpty &&
                                                !isSearchActive
                                            ? const Color(
                                                0xFF00897B,
                                              ).withOpacity(0.7)
                                            : Colors.grey.shade500,
                                        fontSize: 14,
                                        fontWeight:
                                            _searchController.text.isEmpty &&
                                                !isSearchActive
                                            ? FontWeight.w500
                                            : FontWeight.normal,
                                      ),
                                      prefixIcon: AnimatedBuilder(
                                        animation: _typingTextController,
                                        builder: (context, child) {
                                          return AnimatedBuilder(
                                            animation: _colorAnimation,
                                            builder: (context, child) {
                                              return Transform.scale(
                                                scale: isSearchActive
                                                    ? 1.0 +
                                                          (_typingTextController
                                                                  .value *
                                                              0.1)
                                                    : 1.0,
                                                child: Icon(
                                                  Icons.search,
                                                  color: _colorAnimation.value,
                                                  size: 20,
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                      suffixIcon: isSearchActive
                                          ? AnimatedScale(
                                              scale: isSearchActive ? 1.0 : 0.0,
                                              duration: const Duration(
                                                milliseconds: 200,
                                              ),
                                              child: IconButton(
                                                icon: Container(
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade300,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.close,
                                                    color: Colors.grey.shade700,
                                                    size: 16,
                                                  ),
                                                ),
                                                onPressed: clearSearch,
                                              ),
                                            )
                                          : null,
                                      border: InputBorder.none,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
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

                    // Search Results Info with animation
                    if (isSearchActive) ...[
                      const SizedBox(height: 12),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: AnimatedOpacity(
                          opacity: isSearchActive ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF00897B).withOpacity(0.1),
                                  const Color(0xFF4CAF50).withOpacity(0.05),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF00897B).withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                AnimatedBuilder(
                                  animation: _typingTextController,
                                  builder: (context, child) {
                                    return Transform.rotate(
                                      angle: _typingTextController.value * 6.28,
                                      child: Icon(
                                        Icons.search,
                                        size: 16,
                                        color: const Color(0xFF00897B),
                                      ),
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
                                    child: Text(
                                      'Ditemukan ${searchFilteredDokter.length} dokter untuk "${_searchController.text}"',
                                    ),
                                  ),
                                ),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  child: TextButton(
                                    onPressed: clearSearch,
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(50, 30),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF00897B,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Text(
                                        'Clear',
                                        style: TextStyle(
                                          color: Color(0xFF00897B),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
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

              // Filter Poli (hanya tampil jika tidak ada pencarian aktif)
              if (!isSearchActive && widget.poliId == null) ...[
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Poli',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (isLoadingPoli)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(
                              color: Color(0xFF00897B),
                            ),
                          ),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              // Chip "Semua"
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: const Text('Semua'),
                                  selected: selectedPoliId == null,
                                  onSelected: (selected) {
                                    if (selected) resetFilter();
                                  },
                                  selectedColor: const Color(0xFF00897B),
                                  backgroundColor: Colors.grey.shade100,
                                  labelStyle: TextStyle(
                                    color: selectedPoliId == null
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              // Chip untuk setiap poli
                              ...poliList
                                  .map(
                                    (poli) => Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        label: Text(poli['nama_poli']),
                                        selected: selectedPoliId == poli['id'],
                                        onSelected: (selected) {
                                          if (selected) {
                                            filterByPoli(poli['id']);
                                          }
                                        },
                                        selectedColor: const Color(0xFF00897B),
                                        backgroundColor: Colors.grey.shade100,
                                        labelStyle: TextStyle(
                                          color: selectedPoliId == poli['id']
                                              ? Colors.white
                                              : Colors.black87,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              // Info Filter Aktif
              if (!isSearchActive &&
                  (selectedPoliId != null || widget.namaPoli != null)) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  color: const Color(0xFF00897B).withOpacity(0.1),
                  child: Row(
                    children: [
                      Icon(
                        Icons.filter_list,
                        color: const Color(0xFF00897B),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.namaPoli != null
                              ? '${searchFilteredDokter.length} dokter ${widget.namaPoli}'
                              : '${searchFilteredDokter.length} dokter ditemukan',
                          style: const TextStyle(
                            color: Color(0xFF00897B),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (widget.poliId == null)
                        TextButton(
                          onPressed: resetFilter,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(50, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Reset',
                            style: TextStyle(
                              color: Color(0xFF00897B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              // List Dokter
              Expanded(
                child: Builder(
                  builder: (context) {
                    print(
                      'Building ListView with ${searchFilteredDokter.length} doctors',
                    );

                    if (isLoading) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Color(0xFF00897B)),
                            SizedBox(height: 16),
                            Text('Memuat data dokter...'),
                          ],
                        ),
                      );
                    }

                    if (searchFilteredDokter.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.medical_services_outlined,
                              size: 80,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isSearchActive
                                  ? 'Tidak ditemukan dokter dengan kata kunci "${_searchController.text}"'
                                  : selectedPoliId != null
                                  ? 'Tidak ada dokter dengan poli ini'
                                  : 'Tidak ada dokter tersedia',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (isSearchActive) ...[
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: clearSearch,
                                child: const Text(
                                  'Hapus Pencarian',
                                  style: TextStyle(
                                    color: Color(0xFF00897B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: searchFilteredDokter.length,
                      itemBuilder: (context, index) {
                        print('Building item $index');
                        final dokter = searchFilteredDokter[index];
                        final dokterId = dokter['id_dokter'] ?? dokter['id'];
                        final jadwalList =
                            dokter['jadwal'] as List<dynamic>? ?? [];

                        print(
                          'Doctor: ${dokter['nama_dokter']}, ID: $dokterId, Jadwal count: ${jadwalList.length}',
                        );

                        // Skip this item if dokterId is still null
                        if (dokterId == null) {
                          print('Skipping doctor due to null ID');
                          return const SizedBox.shrink();
                        }

                        keluhanControllers.putIfAbsent(
                          dokterId,
                          () => TextEditingController(),
                        );

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
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
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header Dokter - Always visible
                                Row(
                                  children: [
                                    Container(
                                      width: 70,
                                      height: 70,
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF00897B,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: dokter['foto_dokter'] != null
                                            ? Image.network(
                                                'http://10.227.74.71:8000/storage/${dokter['foto_dokter']}',
                                                fit: BoxFit.cover,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) {
                                                      return const Icon(
                                                        Icons.person,
                                                        size: 40,
                                                        color: Color(
                                                          0xFF00897B,
                                                        ),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            dokter['nama_dokter'] ??
                                                'Nama tidak tersedia',
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF00897B,
                                              ).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              dokter['poli']?['nama_poli'] ??
                                                  'Poli Umum',
                                              style: const TextStyle(
                                                color: Color(0xFF00897B),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),

                                // Toggle Button - Lihat Semua / Sembunyikan
                                Center(
                                  child: TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        expandedDokter[dokterId] =
                                            !(expandedDokter[dokterId] ??
                                                false);
                                      });
                                    },
                                    icon: AnimatedRotation(
                                      turns: expandedDokter[dokterId] == true
                                          ? 0.5
                                          : 0.0,
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      child: Icon(
                                        Icons.keyboard_arrow_down,
                                        color: const Color(0xFF00897B),
                                      ),
                                    ),
                                    label: Text(
                                      expandedDokter[dokterId] == true
                                          ? 'Sembunyikan Detail'
                                          : 'Lihat Semua Detail',
                                      style: const TextStyle(
                                        color: Color(0xFF00897B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),

                                // Expanded Details
                                if (expandedDokter[dokterId] == true) ...[
                                  const SizedBox(height: 16),

                                  // Info Dokter
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      children: [
                                        _buildInfoRow(
                                          Icons.phone,
                                          'No. HP',
                                          dokter['no_hp'] ?? '-',
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  // UPDATED: Jadwal Tersedia dengan Klik Langsung
                                  const Text(
                                    'Jadwal Tersedia - Pilih Salah Satu',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (jadwalList.isEmpty)
                                    const Text(
                                      'Tidak ada jadwal tersedia',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                      ),
                                    )
                                  else
                                    ...jadwalList.map((jadwal) {
                                      final hari = jadwal['hari'];
                                      final jamAwal = jadwal['jam_awal'];
                                      final jamSelesai = jadwal['jam_selesai'];

                                      print(
                                        'DEBUG jadwal: $hari, $jamAwal - $jamSelesai',
                                      );

                                      final hariNumber = getHariNumber(hari);

                                      // Pass jam kerja spesifik jadwal ini
                                      final tanggalTerdekat = getNextDateByDay(
                                        hariNumber,
                                        jamAwal: jamAwal,
                                        jamSelesai: jamSelesai,
                                      );

                                      final tanggalFormatted =
                                          formatTanggalIndonesia(
                                            tanggalTerdekat,
                                          );

                                      // ... rest of UI code

                                      final isSelected =
                                          selectedJadwal[dokterId] == jadwal;

                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              selectedJadwal[dokterId] = jadwal;
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: AnimatedContainer(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? const Color(
                                                      0xFF00897B,
                                                    ).withOpacity(0.15)
                                                  : const Color(
                                                      0xFF00897B,
                                                    ).withOpacity(0.05),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isSelected
                                                    ? const Color(0xFF00897B)
                                                    : const Color(
                                                        0xFF00897B,
                                                      ).withOpacity(0.2),
                                                width: isSelected ? 2 : 1,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 200,
                                                  ),
                                                  width: 8,
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? const Color(
                                                            0xFF00897B,
                                                          )
                                                        : const Color(
                                                            0xFF00897B,
                                                          ).withOpacity(0.5),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .calendar_today,
                                                            size: 16,
                                                            color: isSelected
                                                                ? const Color(
                                                                    0xFF00897B,
                                                                  )
                                                                : const Color(
                                                                    0xFF00897B,
                                                                  ).withOpacity(
                                                                    0.7,
                                                                  ),
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          Text(
                                                            '$hari, $tanggalFormatted',
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  isSelected
                                                                  ? FontWeight
                                                                        .w700
                                                                  : FontWeight
                                                                        .w600,
                                                              color: isSelected
                                                                  ? const Color(
                                                                      0xFF00897B,
                                                                    )
                                                                  : const Color(
                                                                      0xFF00897B,
                                                                    ).withOpacity(
                                                                      0.8,
                                                                    ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Row(
                                                        children: [
                                                          Icon(
                                                            Icons.access_time,
                                                            size: 16,
                                                            color: isSelected
                                                                ? Colors
                                                                      .grey
                                                                      .shade700
                                                                : Colors
                                                                      .grey
                                                                      .shade600,
                                                          ),
                                                          const SizedBox(
                                                            width: 6,
                                                          ),
                                                          Text(
                                                            '${jadwal['jam_awal']} - ${jadwal['jam_selesai']}',
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  isSelected
                                                                  ? FontWeight
                                                                        .w500
                                                                  : FontWeight
                                                                        .normal,
                                                              color: isSelected
                                                                  ? Colors
                                                                        .grey
                                                                        .shade700
                                                                  : Colors
                                                                        .grey
                                                                        .shade600,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (isSelected)
                                                  AnimatedScale(
                                                    scale: isSelected
                                                        ? 1.0
                                                        : 0.0,
                                                    duration: const Duration(
                                                      milliseconds: 200,
                                                    ),
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            4,
                                                          ),
                                                      decoration:
                                                          const BoxDecoration(
                                                            color: Color(
                                                              0xFF00897B,
                                                            ),
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                      child: const Icon(
                                                        Icons.check,
                                                        color: Colors.white,
                                                        size: 14,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),

                                  if (jadwalList.isNotEmpty) ...[
                                    const SizedBox(height: 16),

                                    // Jadwal yang dipilih
                                    if (selectedJadwal[dokterId] != null) ...[
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(
                                                0xFF00897B,
                                              ).withOpacity(0.1),
                                              const Color(
                                                0xFF4CAF50,
                                              ).withOpacity(0.05),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: const Color(
                                              0xFF00897B,
                                            ).withOpacity(0.3),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF00897B),
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.event_available,
                                                color: Colors.white,
                                                size: 16,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Jadwal Terpilih:',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Color(0xFF00897B),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    formatJadwalDropdown(
                                                      selectedJadwal[dokterId]!,
                                                    ),
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: Color(0xFF00897B),
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],

                                    // Keluhan
                                    const Text(
                                      'Keluhan Awal',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: keluhanControllers[dokterId],
                                      decoration: InputDecoration(
                                        hintText: 'Jelaskan keluhan Anda...',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF00897B),
                                          ),
                                        ),
                                        contentPadding: const EdgeInsets.all(
                                          12,
                                        ),
                                      ),
                                      maxLines: 3,
                                    ),

                                    const SizedBox(height: 16),

                                    // Button Pesan
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFF00897B,
                                          ),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          elevation: 0,
                                        ),
                                        onPressed:
                                            isLoading ||
                                                selectedJadwal[dokterId] == null
                                            ? null
                                            : () => pesanSekarang(dokterId),
                                        child: const Text(
                                          'Pesan Sekarang',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),

          // Loading Overlay
          if (isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF00897B)),
                      SizedBox(height: 16),
                      Text(
                        'Memproses pesanan...',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF00897B)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
