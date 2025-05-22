import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class SuperAdminAddScheme extends StatefulWidget {
  const SuperAdminAddScheme({super.key});

  @override
  State<SuperAdminAddScheme> createState() => _SuperAdminAddSchemeState();
}

class _SuperAdminAddSchemeState extends State<SuperAdminAddScheme> {
  final _formKey = GlobalKey<FormState>();
  final _schemeNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  Future<void> _sendSms({
    required String phoneNumber,
    required String schemeName,
    required String patientName,
    required String description,
  }) async {
    final fullPhoneNo =
        '+91$phoneNumber'; // Replace '+91' with the appropriate country code if needed.
    const accountSid =
        'AC64826596076bc006f1c5d3ba05f4dfc3'; // Replace with your Twilio Account SID
    const authToken =
        '89a725823b185664b9682e9185143826'; // Replace with your Twilio Auth Token
    const fromPhoneNumber =
        '+19109943167'; // Replace with your Twilio phone number

    final twilioUrl =
        'https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json';

    try {
      final response = await http.post(
        Uri.parse(twilioUrl),
        headers: {
          'Authorization':
              'Basic ${base64Encode(utf8.encode('$accountSid:$authToken'))}',
        },
        body: {
          'To': fullPhoneNo,
          'From': fromPhoneNumber,
          'Body':
              'Dear $patientName,\n\nWe are pleased to introduce a new scheme: "$schemeName".\n\nDescription: $description\n\nFor more details, please contact us or visit our office.\n\nThank you,\nSwasthpath',
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint('SMS sent successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('SMS sent successfully')),
        );
      } else {
        debugPrint(
            'Failed to send SMS. Status code: ${response.statusCode}, Body: ${response.body}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Failed to send SMS. Status code: ${response.statusCode}')),
        );
      }
    } catch (e) {
      debugPrint('Error sending SMS: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending SMS: $e')),
      );
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final supabase = Supabase.instance.client;

      // Insert data into the Supabase table
      // ignore: unused_local_variable
      final response = await supabase.from('schemes').insert({
        'scheme_name': _schemeNameController.text,
        'description': _descriptionController.text,
      }).select();

      // Fetch all patients' phone numbers
      final patientsResponse =
          await supabase.from('patients').select('phone_no, name');

      final patients = patientsResponse as List<dynamic>;
      for (var patient in patients) {
        final phoneNo = patient['phone_no'];
        final name = patient['name'];
        await _sendSms(
          phoneNumber: phoneNo,
          schemeName: _schemeNameController.text,
          patientName: name,
          description: _descriptionController.text,
        );
      }

      Navigator.of(context).pop(); // Close the loading dialog

      // Clear the text fields
      _schemeNameController.clear();
      _descriptionController.clear();

      // Show success dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Success'),
          content: const Text(
              'Scheme registered and notifications sent successfully!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close the loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Scheme Name
                TextFormField(
                  controller: _schemeNameController,
                  decoration: const InputDecoration(
                    labelText: 'Scheme Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter scheme name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Submit Button
                Center(
                  child: ElevatedButton(
                    onPressed: _submitForm,
                    child: const Text('Submit'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _schemeNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
