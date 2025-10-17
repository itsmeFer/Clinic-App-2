import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// ===============================
/// Helpers umum
/// ===============================
String safeString(dynamic v, [String fallback = '-']) {
  if (v == null) return fallback;
  final s = v.toString().trim();
  return s.isEmpty ? fallback : s;
}

String stripHtmlTags(String htmlString) {
  final exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
  return htmlString.replaceAll(exp, '').replaceAll('&nbsp;', ' ').trim();
}

String formatDateShort(String dateString) {
  try {
    if (dateString.isEmpty) return '-';
    final d = DateTime.parse(dateString);
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${d.day} ${months[d.month]} ${d.year}';
  } catch (_) {
    return dateString.isEmpty ? '-' : dateString;
  }
}

String formatDateLong(String dateString) {
  try {
    if (dateString.isEmpty) return '-';
    final d = DateTime.parse(dateString);
    const months = ['', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return '${d.day} ${months[d.month]} ${d.year}';
  } catch (_) {
    return dateString.isEmpty ? '-' : dateString;
  }
}

String authorNameOf(Map<String, dynamic> a) {
  final author = a['author'];
  if (author is Map && author['username'] != null) return safeString(author['username'], 'Admin');
  return safeString(a['author_name'] ?? a['created_by'], 'Admin');
}

String categoryNameOf(Map<String, dynamic> a) {
  final cat = a['category'];
  if (cat is Map && cat['name'] != null) return safeString(cat['name'], 'Umum');
  return safeString(a['category_name'], 'Umum');
}

String imageUrlOf(Map<String, dynamic> a) {
  final url = a['imageUrl'] ?? a['image'] ?? a['thumbnail'];
  return safeString(url, '');
}

/// ===============================
/// LIST ARTIKEL + SEARCH ala PesanJadwal + FILTER KATEGORI
/// ===============================
class Artikel extends StatefulWidget {
  const Artikel({super.key});

  @override
  State<Artikel> createState() => _ArtikelState();
}

class _ArtikelState extends State<Artikel> with TickerProviderStateMixin {
  List<Map<String, dynamic>> articleList = [];
  bool isLoading = true;
  String errorMessage = '';
  int totalArticles = 0;
  int currentPage = 1;
  int totalPages = 1;

  // Search & Filter (animated like PesanJadwal)
  final TextEditingController _searchController = TextEditingController();
  bool isSearchActive = false;
  bool isTyping = false;

  late AnimationController _searchAnimationController;
  late AnimationController _typingTextController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  // Typing placeholder
  Timer? _typingTimer;
  String _currentText = '';
  final String _fullText = 'Cari judul, konten, penulis, atau kategori...';

  // Blink cursor effect is simulated by toggling hint text; reuse typing controller.

  // Debounce manual
  DateTime? _lastTypeTs;

  // Filter kategori
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _searchAnimationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _typingTextController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(CurvedAnimation(
      parent: _searchAnimationController,
      curve: Curves.elasticOut,
    ));

    _colorAnimation = ColorTween(
      begin: Colors.grey.shade500,
      end: const Color(0xFF00897B),
    ).animate(_searchAnimationController);

    _startTypingAnimation();

    _searchController.addListener(_onSearchChanged);
    fetchArticles();
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
    _typingTimer = Timer.periodic(const Duration(milliseconds: 80), (t) {
      if (!mounted) return;
      if (_searchController.text.isEmpty && !isSearchActive) {
        setState(() {
          if (_currentText.length < _fullText.length) {
            _currentText = _fullText.substring(0, _currentText.length + 1);
          } else {
            // hold then reset
            Future.delayed(const Duration(milliseconds: 2200), () {
              if (!mounted) return;
              if (_searchController.text.isEmpty && !isSearchActive) {
                setState(() => _currentText = '');
                _startTypingAnimation();
              }
            });
            t.cancel();
          }
        });
      } else {
        t.cancel();
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
        setState(() {}); // trigger filtered list rebuild
      }
    });
  }

  Future<void> fetchArticles() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      final response = await http.get(
        Uri.parse('https://backend.royal-klinik.cloud/api/upload/articles'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final d = data['data'];
          List<dynamic> raw;

          if (d is Map && d['articles'] is List) {
            raw = d['articles'];
            totalArticles = d['totalArticles'] ?? (d['articles'] as List).length;
            currentPage = d['currentPage'] ?? 1;
            totalPages = d['totalPages'] ?? 1;
          } else if (d is List) {
            raw = d;
            totalArticles = raw.length;
            currentPage = 1;
            totalPages = 1;
          } else {
            raw = [];
            totalArticles = 0;
            currentPage = 1;
            totalPages = 1;
          }

          setState(() {
            articleList = raw.map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map)).toList();
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = data['message'] ?? 'Gagal memuat artikel';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Gagal memuat artikel (${response.statusCode})';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Terjadi kesalahan: $e';
        isLoading = false;
      });
    }
  }

  // Kategori unik
  List<String> get categories {
    final s = <String>{};
    for (final a in articleList) {
      s.add(categoryNameOf(a));
    }
    final l = s.toList()..sort();
    return l;
  }

  // Filter & Search seperti PesanJadwal (_performSearch)
  List<Map<String, dynamic>> get searchFilteredArticles {
    final q = _searchController.text.trim().toLowerCase();
    final filtered = articleList.where((a) {
      final cat = categoryNameOf(a);
      final author = authorNameOf(a);
      final title = safeString(a['title'], '');
      final content = stripHtmlTags(safeString(a['content'], ''));
      final date = safeString(a['date'], '');

      final matchCat = _selectedCategory == null || cat == _selectedCategory;
      final matchQuery = q.isEmpty
          ? true
          : (title.toLowerCase().contains(q) ||
              content.toLowerCase().contains(q) ||
              author.toLowerCase().contains(q) ||
              cat.toLowerCase().contains(q) ||
              date.toLowerCase().contains(q));
      return matchCat && matchQuery;
    }).toList();

    return filtered;
  }

  void clearSearch() {
    _searchController.clear();
    _searchAnimationController.reverse();
    setState(() {
      isSearchActive = false;
      isTyping = false;
    });
    _startTypingAnimation();
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final listToShow = searchFilteredArticles;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Artikel Kesehatan'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchArticles,
            tooltip: 'Muat Ulang',
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00897B)))
          : errorMessage.isNotEmpty
              ? _ErrorView(message: errorMessage, onRetry: fetchArticles)
              : Stack(
                  children: [
                    Column(
                      children: [
                        // ===== Search Bar ala PesanJadwal =====
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(16),
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

                              // Info hasil pencarian (animated) mirip PesanJadwal
                              if (isSearchActive) ...[
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
                                              child: Text('Ditemukan ${listToShow.length} artikel untuk "${_searchController.text}"'),
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

                        // ===== Kategori Chips (tampil selalu) =====
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          width: double.infinity,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: const Text('Semua'),
                                    selected: _selectedCategory == null,
                                    onSelected: (v) => setState(() => _selectedCategory = null),
                                    selectedColor: const Color(0xFF00897B),
                                    backgroundColor: Colors.grey.shade100,
                                    labelStyle: TextStyle(
                                      color: _selectedCategory == null ? Colors.white : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                ...categories.map((c) => Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: ChoiceChip(
                                        label: Text(c),
                                        selected: _selectedCategory == c,
                                        onSelected: (v) => setState(() => _selectedCategory = v ? c : null),
                                        selectedColor: const Color(0xFF00897B),
                                        backgroundColor: Colors.grey.shade100,
                                        labelStyle: TextStyle(
                                          color: _selectedCategory == c ? Colors.white : Colors.black87,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    )),
                                if (_selectedCategory != null)
                                  TextButton.icon(
                                    onPressed: _clearFilters,
                                    icon: const Icon(Icons.filter_alt_off, size: 18),
                                    label: const Text('Reset'),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // ===== List Artikel =====
                        Expanded(
                          child: articleList.isEmpty
                              ? const _EmptyView()
                              : RefreshIndicator(
                                  onRefresh: fetchArticles,
                                  child: listToShow.isEmpty
                                      ? _NoMatchView(query: _searchController.text, category: _selectedCategory)
                                      : ListView.builder(
                                          padding: const EdgeInsets.all(16),
                                          itemCount: listToShow.length,
                                          itemBuilder: (context, index) {
                                            final a = listToShow[index];
                                            final img = imageUrlOf(a);
                                            final cat = categoryNameOf(a);
                                            final tgl = formatDateShort(safeString(a['date'], ''));
                                            final author = authorNameOf(a);
                                            final title = safeString(a['title'], 'Tanpa Judul');
                                            final preview = stripHtmlTags(safeString(a['content'], ''));

                                            final imageWidget = img.isEmpty
                                                ? Container(
                                                    height: 180,
                                                    color: Colors.grey.shade300,
                                                    child: const Column(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(Icons.image_not_supported, size: 50),
                                                        SizedBox(height: 8),
                                                        Text('Tidak ada gambar'),
                                                      ],
                                                    ),
                                                  )
                                                : Image.network(
                                                    img,
                                                    height: 180,
                                                    width: double.infinity,
                                                    fit: BoxFit.cover,
                                                    loadingBuilder: (c, child, prog) {
                                                      if (prog == null) return child;
                                                      return Container(
                                                        height: 180,
                                                        color: Colors.grey.shade300,
                                                        child: const Center(child: CircularProgressIndicator()),
                                                      );
                                                    },
                                                    errorBuilder: (c, e, s) {
                                                      return Container(
                                                        height: 180,
                                                        color: Colors.grey.shade300,
                                                        child: const Column(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            Icon(Icons.image_not_supported, size: 50),
                                                            SizedBox(height: 8),
                                                            Text('Gambar tidak dapat dimuat'),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  );

                                            return Card(
                                              margin: const EdgeInsets.only(bottom: 16),
                                              elevation: 2,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                              child: InkWell(
                                                onTap: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(builder: (_) => ArticleDetailPage(article: a)),
                                                ),
                                                borderRadius: BorderRadius.circular(12),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    ClipRRect(
                                                      borderRadius: const BorderRadius.only(
                                                        topLeft: Radius.circular(12),
                                                        topRight: Radius.circular(12),
                                                      ),
                                                      child: Stack(
                                                        children: [
                                                          imageWidget,
                                                          Positioned(
                                                            top: 12,
                                                            left: 12,
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                              decoration: BoxDecoration(
                                                                color: Colors.teal.withOpacity(0.9),
                                                                borderRadius: BorderRadius.circular(12),
                                                              ),
                                                              child: Text(
                                                                cat,
                                                                style: const TextStyle(
                                                                  fontSize: 12,
                                                                  color: Colors.white,
                                                                  fontWeight: FontWeight.w500,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets.all(16),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                tgl,
                                                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                                              ),
                                                              const SizedBox(width: 16),
                                                              Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                                                              const SizedBox(width: 4),
                                                              Flexible(
                                                                child: Text(
                                                                  author,
                                                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                                                  overflow: TextOverflow.ellipsis,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(height: 12),
                                                          Text(
                                                            title,
                                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                                            maxLines: 2,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          const SizedBox(height: 8),
                                                          Text(
                                                            preview,
                                                            style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.4),
                                                            maxLines: 3,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                          const SizedBox(height: 12),
                                                          Row(
                                                            mainAxisAlignment: MainAxisAlignment.end,
                                                            children: [
                                                              TextButton.icon(
                                                                onPressed: () => Navigator.push(
                                                                  context,
                                                                  MaterialPageRoute(builder: (_) => ArticleDetailPage(article: a)),
                                                                ),
                                                                icon: const Icon(Icons.arrow_forward, size: 16),
                                                                label: const Text('Baca Selengkapnya'),
                                                                style: TextButton.styleFrom(foregroundColor: Colors.teal),
                                                              ),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }
}

/// ===============================
/// DETAIL ARTIKEL
/// ===============================
class ArticleDetailPage extends StatelessWidget {
  final Map<String, dynamic> article;
  const ArticleDetailPage({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final img = imageUrlOf(article);
    final cat = categoryNameOf(article);
    final title = safeString(article['title'], 'Tanpa Judul');
    final date = formatDateLong(safeString(article['date'], ''));
    final authorName = authorNameOf(article);
    final authorInitial = authorName.isNotEmpty ? authorName[0].toUpperCase() : 'A';
    final content = stripHtmlTags(safeString(article['content'], ''));

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: img.isEmpty
                  ? Container(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                    )
                  : Image.network(
                      img,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        color: Colors.grey.shade300,
                        child: const Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                      ),
                    ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fitur berbagi akan segera tersedia')),
                  );
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.teal.shade100, borderRadius: BorderRadius.circular(16)),
                    child: Text(
                      cat,
                      style: TextStyle(fontSize: 12, color: Colors.teal.shade700, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, height: 1.3),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.teal.shade100,
                        child: Text(
                          authorInitial,
                          style: TextStyle(color: Colors.teal.shade700, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(authorName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                            Text(date, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      content,
                      style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Artikel disimpan'))),
                          icon: const Icon(Icons.bookmark_border),
                          label: const Text('Simpan'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.teal, side: const BorderSide(color: Colors.teal)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Artikel dibagikan'))),
                          icon: const Icon(Icons.share),
                          label: const Text('Bagikan'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ===============================
/// Widgets kecil: Empty / NoMatch / Error
/// ===============================
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Belum ada artikel tersedia', style: TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }
}

class _NoMatchView extends StatelessWidget {
  final String? query;
  final String? category;
  const _NoMatchView({this.query, this.category});

  @override
  Widget build(BuildContext context) {
    final hasQuery = (query ?? '').trim().isNotEmpty;
    final hasCategory = category != null;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.search_off, size: 64, color: Colors.grey.shade500),
        const SizedBox(height: 16),
        Center(
          child: Text('Tidak ditemukan artikel yang cocok', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
        ),
        const SizedBox(height: 8),
        if (hasQuery || hasCategory)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                [
                  if (hasQuery) 'Kata kunci: “$query”',
                  if (hasCategory) 'Kategori: $category',
                ].join(' • '),
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        const SizedBox(height: 24),
        Center(
          child: Text('Coba hapus filter atau ubah kata kunci.', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}
