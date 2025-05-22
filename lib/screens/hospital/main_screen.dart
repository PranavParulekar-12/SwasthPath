import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:iconsax/iconsax.dart';
import 'package:swasthapath/landing_page.dart';
import 'package:swasthapath/screens/hospital/add_patient_screen.dart';
import 'package:swasthapath/screens/hospital/apply_scheme_screen.dart';
import 'package:swasthapath/screens/hospital/enquri_screen.dart';
import 'package:swasthapath/screens/hospital/home_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final _secureStorage = const FlutterSecureStorage();

  // List of pages for each tab
  static const List<Widget> _pages = <Widget>[
    HomeScreen(),
    AddPatientScreen(),
    EnquriScreen(),
    ApplySchemeScreen(),
  ];

  static const List<String> _pagesTitle = <String>[
    'Home',
    'Add Patient',
    'Add Enquiry',
    'Apply Scheme',
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _logout(BuildContext context) async {
    // Clear user session
    await _secureStorage.delete(key: 'userId');

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
              // Implement logout functionality here
              _showLogoutDialog(context); // Call the logout function
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
            icon: Icon(Iconsax.user_add),
            label: 'Patient',
          ),
          BottomNavigationBarItem(
            icon: Icon(Iconsax.note_add),
            label: 'Enquery',
          ),
          BottomNavigationBarItem(
            icon: Icon(Iconsax.book),
            label: 'Scheme',
          ),
        ],
      ),
    );
  }
}
