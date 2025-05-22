import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:swasthapath/screens/admin/sub_dist/certificate_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthHospitals extends StatefulWidget {
  const AuthHospitals({super.key});

  @override
  _AuthHospitalsState createState() => _AuthHospitalsState();
}

class _AuthHospitalsState extends State<AuthHospitals> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _hospitals = [];
  bool _isLoading = false;
  final _secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _fetchHospitals();
  }

  Future<void> _fetchHospitals() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Retrieve admin ID from secure storage
      final adminId = await _secureStorage.read(key: 'adminId');
      if (adminId == null) {
        _showError("Admin ID not found. Please log in again.");
        return;
      }

      // Fetch admin's sub_district based on admin ID
      final adminResponse = await _supabase
          .from('admin')
          .select('sub_dist')
          .eq('id', adminId)
          .single();

      if (adminResponse['sub_dist'] == null) {
        _showError("Admin data not found.");
        return;
      }

      final adminSubDist = adminResponse['sub_dist'];

      // Fetch hospitals where sub_dist matches the admin's sub_district and status is false
      final response = await _supabase
          .from('hospitals')
          .select()
          .eq('sub_dist', adminSubDist)
          .eq('status', false);

      setState(() {
        _hospitals = (response as List<dynamic>)
            .map((hospital) => hospital as Map<String, dynamic>)
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

  Future<void> _verifyHospital(
      int id, String email, String hospitalName) async {
    try {
      // Update the hospital's status
      await _supabase.from('hospitals').update({'status': true}).eq('id', id);

      // Send email notification
      final emailSent = await _sendEmail(
        recipientEmail: email,
        hospitalName: hospitalName,
      );

      if (emailSent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Verification email sent successfully.')),
        );
      } else {
        _showError("Failed to send verification email.");
      }

      // Refresh the list
      _fetchHospitals();
    } catch (e) {
      _showError("Error verifying hospital: $e");
    }
  }

  Future<bool> _sendEmail({
    required String recipientEmail,
    required String hospitalName,
  }) async {
    const sendGridApiKey =
        "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"; // Replace with actual API Key
    const sendGridUrl = 'https://api.sendgrid.com/v3/mail/send';
    const senderEmail =
        'bhuwad.atharva@gmail.com'; // Replace with verified sender email

    final emailData = {
      "personalizations": [
        {
          "to": [
            {"email": recipientEmail}
          ],
          "subject": "Hospital Request Approved"
        }
      ],
      "from": {"email": senderEmail},
      "content": [
        {
          "type": "text/plain",
          "value": '''
Dear $hospitalName,

Congratulations! Your request to join our network has been approved. You can now access all our features and services.

For any queries, feel free to reach out to us.

Best regards,
The Team
          '''
        }
      ]
    };

    try {
      final response = await http.post(
        Uri.parse(sendGridUrl),
        headers: {
          'Authorization': 'Bearer $sendGridApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(emailData),
      );

      return response.statusCode == 202;
    } catch (e) {
      debugPrint("Error sending email: $e");
      return false;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $message')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListView.builder(
                itemCount: _hospitals.length,
                itemBuilder: (context, index) {
                  final hospital = _hospitals[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text(hospital['hospital_name'] ?? 'Unknown Name'),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: () {
                              final pdfPath = hospital['certificate'] ?? '';
                              if (pdfPath.isNotEmpty) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PDFViewScreen(
                                      pdfUrl: pdfPath,
                                    ),
                                  ),
                                );
                              } else {
                                _showError("No document available.");
                              }
                            },
                            child: const Text('Certificate'),
                          ),
                          const SizedBox(width: 5),
                          hospital['status'] == true
                              ? const Icon(Icons.check, color: Colors.green)
                              : ElevatedButton(
                                  onPressed: () => _verifyHospital(
                                    hospital['id'],
                                    hospital['email'] ?? '',
                                    hospital['hospital_name'] ?? 'Hospital',
                                  ),
                                  child: const Text('Verify'),
                                ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
