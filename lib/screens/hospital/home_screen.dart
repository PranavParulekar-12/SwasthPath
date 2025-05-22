import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final PageController _pageController = PageController();
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _schemes = [];
  bool _isLoading = false;
  int _currentPage = 0;
  List<Map<String, dynamic>> _banners = [];
  // ignore: unused_field
  bool _isBannerLoading = false;

  @override
  void initState() {
    super.initState();
    _autoSlide();
    _fetchSchemes();
    _fetchBanners();
  }

  Future<void> _fetchBanners() async {
    setState(() {
      _isBannerLoading = true;
    });

    try {
      final response = await _supabase.from('banner').select('id, banner_url');

      setState(() {
        _banners = (response as List<dynamic>)
            .map((banner) => banner as Map<String, dynamic>)
            .toList();
      });
    } catch (e) {
      _showError("Error fetching banners: $e");
    } finally {
      setState(() {
        _isBannerLoading = false;
      });
    }
  }

  Future<void> _fetchSchemes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _supabase
          .from('schemes')
          .select('scheme_id, scheme_name, description');

      setState(() {
        _schemes = (response as List<dynamic>)
            .map((scheme) => scheme as Map<String, dynamic>)
            .toList();
      });
    } catch (e) {
      _showError("Error fetching data: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $message')),
    );
  }

  void _autoSlide() {
    Future.delayed(const Duration(seconds: 3), () {
      if (_pageController.hasClients) {
        setState(() {
          _currentPage = (_currentPage + 1) % _banners.length;
        });
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        _autoSlide();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 200,
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _banners.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return Image.network(
                      _banners[index]['banner_url'],
                      fit: BoxFit.cover,
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.0),
            child: Text(
              'Schemes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: ListView.builder(
                      itemCount: _schemes.length,
                      itemBuilder: (context, index) {
                        final scheme = _schemes[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: ListTile(
                            title: Text(
                              scheme['scheme_name'] ?? 'No Name',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ID: ${scheme['scheme_id']}'),
                                Text(scheme['description'] ?? 'No Description'),
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
