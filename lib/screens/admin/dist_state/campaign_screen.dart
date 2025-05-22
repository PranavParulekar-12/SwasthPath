import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CampaignPage extends StatefulWidget {
  const CampaignPage({super.key});

  @override
  _CampaignPageState createState() => _CampaignPageState();
}

class _CampaignPageState extends State<CampaignPage> {
  final _formKey = GlobalKey<FormState>();
  final _campaignNameController = TextEditingController();
  final _eligibilityController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();
  final _durationController = TextEditingController();
  final _locationController = TextEditingController();
  final _secureStorage = const FlutterSecureStorage();

  final List<Map<String, String>> _sentCampaigns =
      []; // To store sent campaigns with details

  @override
  void dispose() {
    _campaignNameController.dispose();
    _eligibilityController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _durationController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _sendCampaignDetails() async {
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
          .select('sub_dist')
          .eq('id', adminId!)
          .single();
      final adminSubDist = adminResponse['sub_dist'];

      // Build the message
      final message = """
        Dear ,
        We are arranging a camp: ${_campaignNameController.text}
        Eligibility: ${_eligibilityController.text}
        Description: ${_descriptionController.text}
        Date: ${_dateController.text}
        Duration: ${_durationController.text}
        Location: ${_locationController.text}
        """;

      // Fetch phone numbers
      final phoneNumbersResponse = await supabase.from('patients').select('*');
      final phoneNumbers = phoneNumbersResponse as List<dynamic>;

      // Filter phone numbers based on sub_dist
      final filteredNumbers = phoneNumbers
          .where((element) => element['sub_dist'] == adminSubDist)
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
      _campaignNameController.clear();
      _eligibilityController.clear();
      _descriptionController.clear();
      _dateController.clear();
      _durationController.clear();
      _locationController.clear();

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
      print('Error sending campaign details: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send campaign details: $error'),
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
              _buildInputField('Campaign Name', _campaignNameController),
              _buildInputField('Eligibility', _eligibilityController),
              _buildInputField('Description', _descriptionController,
                  maxLines: 4),
              _buildDateInputField(),
              _buildInputField('Duration', _durationController),
              _buildInputField('Location', _locationController),
              const SizedBox(height: 32),
              Center(
                child: ElevatedButton(
                  onPressed: _sendCampaignDetails,
                  child: const Text("Submit and Notify"),
                ),
              ),
              const SizedBox(height: 32),
              if (_sentCampaigns.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Campaign History",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    for (var campaign in _sentCampaigns)
                      GestureDetector(
                        onTap: () => _showCampaignDetails(context, campaign),
                        child: Text(campaign['name']!,
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

  void _showCampaignDetails(
      BuildContext context, Map<String, String> campaign) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(campaign['name']!),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Eligibility: ${campaign['eligibility']}"),
              Text("Description: ${campaign['description']}"),
              Text("Date: ${campaign['date']}"),
              Text("Duration: ${campaign['duration']}"),
              Text("Location: ${campaign['location']}"),
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

  Widget _buildDateInputField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _selectDate,
          child: AbsorbPointer(
            child: TextFormField(
              controller: _dateController,
              decoration: const InputDecoration(
                hintText: "Select Date",
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "Please select a date";
                }
                return null;
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _selectDate() async {
    DateTime initialDate = DateTime.now();
    DateTime firstDate = DateTime(2020);
    DateTime lastDate = DateTime(2101);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null && picked != initialDate) {
      setState(() {
        _dateController.text =
            "${picked.toLocal()}".split(' ')[0]; // Format: YYYY-MM-DD
      });
    }
  }
}
