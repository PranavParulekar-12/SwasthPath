import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:iconsax/iconsax.dart';
import 'package:swasthapath/landing_page.dart';
import 'package:swasthapath/screens/admin/super/super_admin_addscheme.dart';
import 'package:swasthapath/screens/admin/super/super_admin_banner.dart';
import 'package:swasthapath/screens/admin/super/super_admin_home.dart';
import 'package:swasthapath/screens/admin/super/super_admin_report.dart';

class SuperAdminMain extends StatefulWidget {
  const SuperAdminMain({super.key});

  @override
  State<SuperAdminMain> createState() => _SuperAdminMainState();
}

class _SuperAdminMainState extends State<SuperAdminMain> {
  int _selectedIndex = 0;
  final _secureStorage = const FlutterSecureStorage();

  // List of pages for each tab
  static final List<Widget> _pages = <Widget>[
    const SuperAdminDiseases(),
    const SuperAdminScheme(),
    const SuperAdminAddScheme(),
    UploadBannerScreen(),
  ];

  static const List<String> _pagesTitle = <String>[
    'Disease Report',
    'Scheme Report',
    'Add Scheme',
    'Add Banner',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _logout(BuildContext context) async {
    // Clear user session
    await _secureStorage.delete(key: 'adminId');
    await _secureStorage.delete(key: 'role');

    // Navigate to Login Screen
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LandingPage()),
      (route) => false,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close the dialog
                await _logout(context); // Call the logout function
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _pagesTitle[_selectedIndex],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () {
              _showLogoutDialog(context); // Show the logout confirmation dialog
            },
          ),
        ],
      ),

      body: _pages[_selectedIndex], // Display page based on selected index
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Iconsax.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Iconsax.note),
            label: 'Scheme',
          ),
          BottomNavigationBarItem(
            icon: Icon(Iconsax.add),
            label: 'Scheme',
          ),
          BottomNavigationBarItem(
            icon: Icon(Iconsax.image),
            label: 'Banner',
          ),
        ],
      ),
    );
  }
}
