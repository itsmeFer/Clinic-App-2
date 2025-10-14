import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class Katalog extends StatefulWidget {
  const Katalog({super.key});

  @override
  State<Katalog> createState() => _KatalogState();
}

class _KatalogState extends State<Katalog> {
  List<dynamic> catalogList = [];
  bool isLoading = true;
  String errorMessage = '';
  int totalCatalogs = 0;
  int currentPage = 1;
  int totalPages = 1;

  @override
  void initState() {
    super.initState();
    fetchCatalog();
  }

  Future<void> fetchCatalog() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      final response = await http.get(
        Uri.parse('https://backend.royal-klinik.cloud/api/upload/catalogs'),
        headers: {'Content-Type': 'application/json'},
      );

      print('📥 Status Code: ${response.statusCode}');
      print('📥 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            catalogList = data['data']['catalogs'] ?? [];
            totalCatalogs = data['data']['totalCatalogs'] ?? 0;
            currentPage = data['data']['currentPage'] ?? 1;
            totalPages = data['data']['totalPages'] ?? 1;
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = data['message'] ?? 'Gagal memuat katalog';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Gagal memuat katalog (${response.statusCode})';
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

  String formatPrice(String? priceStr) {
    if (priceStr == null || priceStr.isEmpty) return 'Rp 0';
    try {
      double price = double.parse(priceStr);
      return 'Rp ${price.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
    } catch (e) {
      return 'Rp $priceStr';
    }
  }

  String calculateDiscount(String? originalStr, String? discountStr) {
    if (originalStr == null || discountStr == null) return '';
    try {
      double original = double.parse(originalStr);
      double discount = double.parse(discountStr);
      if (original <= discount) return '';
      double percentage = ((original - discount) / original) * 100;
      return '${percentage.toStringAsFixed(0)}%';
    } catch (e) {
      return '';
    }
  }

  String stripHtmlTags(String? htmlString) {
    if (htmlString == null || htmlString.isEmpty) return 'Tidak ada deskripsi';
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '').replaceAll('&nbsp;', ' ').trim();
  }

  // Helper method untuk safe image loading
  Widget buildSafeNetworkImage({
    required String? imageUrl,
    required double height,
    required double? width,
    required BoxFit fit,
    BorderRadius? borderRadius,
  }) {
    Widget imageWidget;

    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      imageWidget = Image.network(
        imageUrl,
        height: height,
        width: width,
        fit: fit,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: height,
            width: width,
            color: Colors.grey.shade300,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
                color: Colors.teal,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: height,
            width: width,
            color: Colors.grey.shade300,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  'Gambar tidak dapat dimuat',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          );
        },
      );
    } else {
      imageWidget = Container(
        height: height,
        width: width,
        color: Colors.grey.shade300,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'Tidak ada gambar',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: imageWidget,
      );
    }
    
    return imageWidget;
  }

  // Safe getter for nested properties
  String getSafeString(Map<String, dynamic> data, String key, [String defaultValue = '']) {
    try {
      return data[key]?.toString() ?? defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  String getSafeNestedString(Map<String, dynamic> data, String parentKey, String childKey, [String defaultValue = '']) {
    try {
      return data[parentKey]?[childKey]?.toString() ?? defaultValue;
    } catch (e) {
      return defaultValue;
    }
  }

  Future<void> _launchWhatsApp(String? waLink) async {
    if (waLink == null || waLink.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link WhatsApp tidak tersedia'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final Uri url = Uri.parse(waLink);
      
      await launchUrl(
        url, 
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      print('Error launching WhatsApp: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak dapat membuka WhatsApp: $e'),
          backgroundColor: Colors.red,
          action: SnackBarAction(
            label: 'Copy Link',
            textColor: Colors.white,
            onPressed: () {
              print('WhatsApp Link: $waLink');
            },
          ),
        ),
      );
    }
  }

  void _showCatalogDetail(Map<String, dynamic> catalog) {
    final String title = getSafeString(catalog, 'title', 'Judul tidak tersedia');
    final String imageUrl = getSafeString(catalog, 'imageUrl');
    final String categoryName = getSafeNestedString(catalog, 'category', 'name', 'Kategori tidak tersedia');
    final String content = getSafeString(catalog, 'content');
    final String priceOriginal = getSafeString(catalog, 'price_original', '0');
    final String priceDiscount = getSafeString(catalog, 'price_discount', '0');
    final String waLink = getSafeString(catalog, 'waLink');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header dengan gambar
              Stack(
                children: [
                  buildSafeNetworkImage(
                    imageUrl: imageUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withOpacity(0.5),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
              // Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          categoryName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.teal.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Harga
                      Row(
                        children: [
                          Text(
                            formatPrice(priceDiscount),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (priceOriginal != priceDiscount && priceOriginal != '0') ...[
                            Text(
                              formatPrice(priceOriginal),
                              style: const TextStyle(
                                fontSize: 14,
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '-${calculateDiscount(priceOriginal, priceDiscount)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Deskripsi
                      const Text(
                        'Deskripsi:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        stripHtmlTags(content),
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Tombol WhatsApp
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _launchWhatsApp(waLink),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.chat),
                          label: const Text(
                            'Tanya via WhatsApp',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Katalog Layanan'),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchCatalog,
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
                        onPressed: fetchCatalog,
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
              : catalogList.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Belum ada katalog tersedia',
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
                              Icon(Icons.inventory_2, color: Colors.teal.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Total $totalCatalogs layanan tersedia',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.teal.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // List katalog
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: fetchCatalog,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: catalogList.length,
                              itemBuilder: (context, index) {
                                final catalog = catalogList[index];
                                
                                // Safe getters untuk semua properties
                                final String title = getSafeString(catalog, 'title', 'Judul tidak tersedia');
                                final String imageUrl = getSafeString(catalog, 'imageUrl');
                                final String categoryName = getSafeNestedString(catalog, 'category', 'name', 'Kategori tidak tersedia');
                                final String content = getSafeString(catalog, 'content');
                                final String priceOriginal = getSafeString(catalog, 'price_original', '0');
                                final String priceDiscount = getSafeString(catalog, 'price_discount', '0');
                                final String waLink = getSafeString(catalog, 'waLink');
                                
                                final hasDiscount = priceOriginal != priceDiscount && priceOriginal != '0';
                                
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  elevation: 3,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: InkWell(
                                    onTap: () => _showCatalogDetail(catalog),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Gambar
                                        Stack(
                                          children: [
                                            buildSafeNetworkImage(
                                              imageUrl: imageUrl,
                                              height: 180,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              borderRadius: const BorderRadius.only(
                                                topLeft: Radius.circular(12),
                                                topRight: Radius.circular(12),
                                              ),
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
                                                  categoryName,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Badge diskon
                                            if (hasDiscount)
                                              Positioned(
                                                top: 12,
                                                right: 12,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red,
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    '-${calculateDiscount(priceOriginal, priceDiscount)}',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        // Content
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                stripHtmlTags(content),
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey,
                                                ),
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 12),
                                              // Harga
                                              Row(
                                                children: [
                                                  Text(
                                                    formatPrice(priceDiscount),
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.teal,
                                                    ),
                                                  ),
                                                  if (hasDiscount) ...[
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      formatPrice(priceOriginal),
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        decoration: TextDecoration.lineThrough,
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                  ],
                                                  const Spacer(),
                                                  IconButton(
                                                    onPressed: () => _launchWhatsApp(waLink),
                                                    icon: const Icon(Icons.chat, color: Colors.green),
                                                    style: IconButton.styleFrom(
                                                      backgroundColor: Colors.green.shade50,
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