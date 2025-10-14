import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Artikel extends StatefulWidget {
  const Artikel({super.key});

  @override
  State<Artikel> createState() => _ArtikelState();
}

class _ArtikelState extends State<Artikel> {
  List<dynamic> articleList = [];
  bool isLoading = true;
  String errorMessage = '';
  int totalArticles = 0;
  int currentPage = 1;
  int totalPages = 1;

  @override
  void initState() {
    super.initState();
    fetchArticles();
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

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            articleList = data['data']['articles'] ?? [];
            totalArticles = data['data']['totalArticles'] ?? 0;
            currentPage = data['data']['currentPage'] ?? 1;
            totalPages = data['data']['totalPages'] ?? 1;
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
      print('❌ Error: $e');
      setState(() {
        errorMessage = 'Terjadi kesalahan: $e';
        isLoading = false;
      });
    }
  }

  String stripHtmlTags(String htmlString) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '').replaceAll('&nbsp;', ' ').trim();
  }

  String formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final months = [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return '${date.day} ${months[date.month]} ${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  void _showArticleDetail(Map<String, dynamic> article) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArticleDetailPage(article: article),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Artikel Kesehatan'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchArticles,
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          errorMessage,
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: fetchArticles,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba Lagi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : articleList.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.article_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Belum ada artikel tersedia',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Header info
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: Colors.teal.shade50,
                          child: Row(
                            children: [
                              Icon(Icons.article, color: Colors.teal.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Total $totalArticles artikel kesehatan',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.teal.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // List artikel
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: fetchArticles,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: articleList.length,
                              itemBuilder: (context, index) {
                                final article = articleList[index];
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: InkWell(
                                    onTap: () => _showArticleDetail(article),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Gambar artikel
                                        ClipRRect(
                                          borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(12),
                                            topRight: Radius.circular(12),
                                          ),
                                          child: Stack(
                                            children: [
                                              Image.network(
                                                article['imageUrl'],
                                                height: 180,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                loadingBuilder: (context, child, loadingProgress) {
                                                  if (loadingProgress == null) return child;
                                                  return Container(
                                                    height: 180,
                                                    color: Colors.grey.shade300,
                                                    child: const Center(
                                                      child: CircularProgressIndicator(),
                                                    ),
                                                  );
                                                },
                                                errorBuilder: (context, error, stackTrace) {
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
                                              ),
                                              // Badge kategori
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
                                                    article['category']['name'],
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
                                        // Content
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Tanggal dan penulis
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.calendar_today,
                                                    size: 14,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    formatDate(article['date']),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 16),
                                                  Icon(
                                                    Icons.person,
                                                    size: 14,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    article['author']['username'],
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              
                                              const SizedBox(height: 12),
                                              
                                              // Judul artikel
                                              Text(
                                                article['title'],
                                                style: const TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              
                                              const SizedBox(height: 8),
                                              
                                              // Preview konten
                                              Text(
                                                stripHtmlTags(article['content']),
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey,
                                                  height: 1.4,
                                                ),
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              
                                              const SizedBox(height: 12),
                                              
                                              // Read more button
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  TextButton.icon(
                                                    onPressed: () => _showArticleDetail(article),
                                                    icon: const Icon(
                                                      Icons.arrow_forward,
                                                      size: 16,
                                                    ),
                                                    label: const Text('Baca Selengkapnya'),
                                                    style: TextButton.styleFrom(
                                                      foregroundColor: Colors.teal,
                                                    ),
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
    );
  }
}

// Halaman detail artikel
class ArticleDetailPage extends StatelessWidget {
  final Map<String, dynamic> article;
  
  const ArticleDetailPage({super.key, required this.article});

  String stripHtmlTags(String htmlString) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '').replaceAll('&nbsp;', ' ').trim();
  }

  String formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final months = [
        '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      return '${date.day} ${months[date.month]} ${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
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
              background: Image.network(
                article['imageUrl'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade300,
                    child: const Icon(
                      Icons.image_not_supported,
                      size: 50,
                      color: Colors.grey,
                    ),
                  );
                },
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  // Implement share functionality
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
                  // Category badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      article['category']['name'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.teal.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Article title
                  Text(
                    article['title'],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Article meta info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.teal.shade100,
                        child: Text(
                          article['author']['username'][0].toUpperCase(),
                          style: TextStyle(
                            color: Colors.teal.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              article['author']['username'],
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              formatDate(article['date']),
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
                  
                  const SizedBox(height: 24),
                  
                  // Article content
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      stripHtmlTags(article['content']),
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.6,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            // Implement bookmark functionality
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Artikel disimpan')),
                            );
                          },
                          icon: const Icon(Icons.bookmark_border),
                          label: const Text('Simpan'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.teal,
                            side: const BorderSide(color: Colors.teal),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // Implement share functionality
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Artikel dibagikan')),
                            );
                          },
                          icon: const Icon(Icons.share),
                          label: const Text('Bagikan'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                          ),
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