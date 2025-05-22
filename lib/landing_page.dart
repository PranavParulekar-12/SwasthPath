import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:swasthapath/screens/admin/admin_login_screen.dart';
import 'package:swasthapath/screens/admin/dist_state/ds_admin_main.dart';
import 'package:swasthapath/screens/admin/sub_dist/admin_main_screen.dart';
import 'package:swasthapath/screens/admin/super/super_admin_main.dart';
import 'package:swasthapath/screens/hospital/login_screen.dart';
import 'package:swasthapath/screens/hospital/main_screen.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _isLoading = true; // Track loading state

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  // Method to check the login status
  Future<void> _checkLoginStatus() async {
    try {
      final userId = await _secureStorage.read(key: 'userId');

      if (userId != null) {
        // Navigate to MainScreen if logged in
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainScreen()),
          (route) => false,
        );
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking login status: $e');
      setState(() {
        _isLoading = false;
      });
    }

    try {
      final adminId = await _secureStorage.read(key: 'adminId');
      final role = await _secureStorage.read(key: 'role');

      if (adminId != null) {
        if (role != null && role == 'sub_dist') {
          // Navigate to MainScreen if logged in
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const AdminMainScreen()),
            (route) => false,
          );
        } else if (role != null && role == 'dist' || role == 'state') {
          // Navigate to MainScreen if logged in
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const DsAdminMain()),
            (route) => false,
          );
        } else if (role != null && role == 'super') {
          // Navigate to MainScreen if logged in
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const SuperAdminMain()),
            (route) => false,
          );
        }
      } else {
        // Set _isLoading to false when checking is done
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking login status: $e');
      setState(() {
        _isLoading = false; // Stop loading if error occurs
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Choose Your Role"),
        centerTitle: true,
      ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 300,
                    child: GridView.count(
                      crossAxisCount: 1,
                      shrinkWrap: true,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      children: [
                        // Admin Tile
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AdminLoginScreen(),
                              ),
                            );
                          },
                          child: GridTile(
                            footer: const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  "Admin",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            child: Card(
                              elevation: 5,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/admin.png',
                                    width: 80,
                                    height: 80,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Hospital Tile
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginScreen(),
                              ),
                            );
                          },
                          child: GridTile(
                            footer: const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  "Hospital",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            child: Card(
                              elevation: 5,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/hospital.png',
                                    width: 80,
                                    height: 80,
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
      ),
    );
  }
}
