import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'Sidebar.dart';

class PerawatPage extends StatefulWidget {
  final Map<String, dynamic>? dokterData;

  const PerawatPage({
    Key? key,
    this.dokterData,
  }) : super(key: key);

  @override
  State<PerawatPage> createState() => _PerawatPageState();
}

class _PerawatPageState extends State<PerawatPage> {
  static const String baseUrl = 'http://10.19.0.247:8000/api';

  bool isLoading = true;
  String? errorMessage;
  List<dynamic> perawatList = [];

  @override
  void initState() {
    super.initState();
    _fetchPerawat();
  }

  Future<void> _fetchPerawat() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      // NOTE:
      // Sesuaikan endpoint ini dengan API kamu.
      // Misalnya: GET /api/dokter/perawat -> list perawat by dokter login
      final response = await http.get(
        Uri.parse('$baseUrl/dokter/perawat'),
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        // fleksibel: bisa data['data'], data['perawat'], atau langsung list
        final list = decoded is Map
            ? (decoded['data'] ?? decoded['perawat'] ?? [])
            : decoded;

        setState(() {
          perawatList = List<dynamic>.from(list);
        });
      } else {
        setState(() {
          errorMessage =
              'Gagal memuat data perawat (${response.statusCode}).';
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Terjadi kesalahan: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;
    final isTablet = screenWidth >= 768 && screenWidth < 1024;
    final isMobile = screenWidth < 768;

    return Scaffold(
      body: Row(
        children: [
          if (isDesktop || isTablet)
            SharedSidebar(
              currentPage: SidebarPage.perawat,
              dokterData: widget.dokterData,
              isCollapsed: false,
              onToggleCollapse: () {},
              onNavigate: (page) => NavigationHelper.navigateToPage(
                context,
                page,
                dokterData: widget.dokterData,
              ),
              onLogout: () => NavigationHelper.logout(context),
            ),

          // MAIN CONTENT
          Expanded(
            child: Column(
              children: [
                SharedTopHeader(
                  currentPage: SidebarPage.perawat,
                  dokterData: widget.dokterData,
                  isMobile: isMobile,
                  onRefresh: _fetchPerawat,
                ),
                Expanded(
                  child: Container(
                    color: const Color(0xFFF8FAFC),
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    child: _buildBody(isMobile),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: isMobile
          ? SharedMobileDrawer(
              currentPage: SidebarPage.perawat,
              dokterData: widget.dokterData,
              onNavigate: (page) => NavigationHelper.navigateToPage(
                context,
                page,
                dokterData: widget.dokterData,
              ),
              onLogout: () => NavigationHelper.logout(context),
            )
          : null,
    );
  }

  Widget _buildBody(bool isMobile) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _fetchPerawat,
              child: const Text('Coba lagi'),
            ),
          ],
        ),
      );
    }

    if (perawatList.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            FaIcon(
              FontAwesomeIcons.userNurse,
              size: 40,
              color: Color(0xFF94A3B8),
            ),
            SizedBox(height: 12),
            Text(
              'Belum ada perawat yang terikat dengan dokter ini.',
              style: TextStyle(
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final crossAxisCount = isMobile ? 1 : 2;

    return GridView.builder(
      itemCount: perawatList.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: isMobile ? 3.2 : 3.6,
      ),
      itemBuilder: (context, index) {
        final p = perawatList[index];

        final nama = p['nama_perawat'] ?? 'Perawat';
        final hp = p['no_hp_perawat'] ?? '-';
        final foto = p['foto_perawat'];
        final poli =
            (p['poli'] != null && p['poli'] is Map && p['poli']['nama_poli'] != null)
                ? p['poli']['nama_poli'].toString()
                : (p['nama_poli'] ?? '');

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFFE0F2FE),
                child: ClipOval(
                  child: SafeNetworkImage(
                    url: foto != null
                        ? 'http://10.19.0.247:8000/storage/$foto'
                        : null,
                    size: 60,
                    fallback: const FaIcon(
                      FontAwesomeIcons.userNurse,
                      size: 28,
                      color: Color(0xFF0EA5E9),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      nama,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (poli.toString().isNotEmpty)
                      Text(
                        'Poli: $poli',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const FaIcon(
                          FontAwesomeIcons.phone,
                          size: 12,
                          color: Color(0xFF22C55E),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            hp,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
