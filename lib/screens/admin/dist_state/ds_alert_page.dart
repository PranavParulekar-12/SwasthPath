import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AlertPage extends StatefulWidget {
  const AlertPage({super.key});

  @override
  _AlertPageState createState() => _AlertPageState();
}

class _AlertPageState extends State<AlertPage> {
  final _formKey = GlobalKey<FormState>();
  final _alertNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _secureStorage = const FlutterSecureStorage();

  final List<Map<String, String>> _sentAlerts =
      []; // To store sent campaigns with details

  @override
  void dispose() {
    _alertNameController.dispose();
    _descriptionController.dispose();

    super.dispose();
  }

  Future<void> _sendAlertDetails() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      // Retrieve admin ID from secure storage
      final adminId = await _secureStorage.read(key: 'adminId');

      // Fetch admin's sub_dist
      final supabase = Supabase.instance.client;
      final adminResponse = await supabase
          .from('admin')
          .select('dist')
          .eq('id', adminId!)
          .single();
      final adminSubDist = adminResponse['dist'];

      // Build the message
      final message = """
        Dear ,
        We are arranging a alerting for the : ${_alertNameController.text}
       
        Description: ${_descriptionController.text}
       
 
        """;

      // Fetch phone numbers
      final phoneNumbersResponse = await supabase.from('patients').select('*');
      final phoneNumbers = phoneNumbersResponse as List<dynamic>;

      // Filter phone numbers based on sub_dist
      final filteredNumbers = phoneNumbers
          .where((element) => element['dist'] == adminSubDist)
          .toList();

      // Handle empty phone number list
      if (filteredNumbers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No phone numbers found in the database.'),
          ),
        );
        return;
      }

      // Clear text fields after sending SMS (assuming success)
      _alertNameController.clear();
      _descriptionController.clear();

      // Send SMS to filtered numbers
      for (final numberMap in filteredNumbers) {
        final phoneNumber = numberMap['phone_no'] as String;
        try {
          await _sendSms(phoneNumber, message);
        } catch (error) {
          print('Failed to send SMS to $phoneNumber: $error');
        }
      }

      // ... (rest of the code, including adding campaign to history and showing success message)
    } catch (error) {
      print('Error sending alert details: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send alert details: $error'),
        ),
      );
    }
  }

  Future<void> _sendSms(String phoneNumber, String message) async {
    final twilioAccountSid =
        'AC64826596076bc006f1c5d3ba05f4dfc3'; // Replace with your Twilio SID
    final twilioAuthToken =
        '89a725823b185664b9682e9185143826'; // Replace with your Twilio Auth Token
    final twilioPhoneNumber =
        '+19109943167'; // Replace with your Twilio phone number

    final url = Uri.parse(
        'https://api.twilio.com/2010-04-01/Accounts/AC64826596076bc006f1c5d3ba05f4dfc3/Messages.json');
    final response = await http.post(
      url,
      headers: {
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$twilioAccountSid:$twilioAuthToken'))}',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'From': twilioPhoneNumber,
        'To': '+91$phoneNumber',
        'Body': message,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      print('Failed to send SMS to $phoneNumber: ${response.body}');
    } else {
      print('Successfully sent SMS to $phoneNumber');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInputField('Alert Name', _alertNameController),
              _buildInputField('Description', _descriptionController,
                  maxLines: 4),
              Center(
                child: ElevatedButton(
                  onPressed: _sendAlertDetails,
                  child: const Text("Submit and Notify"),
                ),
              ),
              const SizedBox(height: 32),
              if (_sentAlerts.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Alert History",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    for (var alert in _sentAlerts)
                      GestureDetector(
                        onTap: () => _showAlertDetails(context, alert),
                        child: Text(alert['name']!,
                            style: const TextStyle(
                                fontSize: 16, color: Colors.blue)),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAlertDetails(BuildContext context, Map<String, String> alert) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(alert['name']!),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Description: ${alert['description']}"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInputField(String hintText, TextEditingController controller,
      {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hintText,
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return "Fill this field";
            return null;
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
