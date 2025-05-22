import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class EnquriScreen extends StatefulWidget {
  const EnquriScreen({super.key});

  @override
  _EnquriScreenState createState() => _EnquriScreenState();
}

class _EnquriScreenState extends State<EnquriScreen> {
  final aadhaarController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final dobController = TextEditingController();
  final genderController = TextEditingController();
  final diseaseController = TextEditingController();
  final _otpController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final _secureStorage = const FlutterSecureStorage();
  String? _generatedOtp;

  Future<void> _fetchAndFillData() async {
    try {
      final response = await Supabase.instance.client
          .from('patients')
          .select('name, phone_no, dob, gender, address')
          .eq('aadhaar_no', aadhaarController.text)
          .maybeSingle();

      if (response != null) {
        setState(() {
          nameController.text = response['name'] ?? '';
          phoneController.text = response['phone_no'] ?? '';
          dobController.text = response['dob'] ?? '';
          genderController.text = response['gender'] ?? '';
        });
      } else {
        _showSnackBar('No patient data found');
      }
    } catch (e) {
      _showSnackBar('Error fetching data: $e');
    }
  }

  Future<void> submitForm() async {
    if (!_formKey.currentState!.validate()) {
      // If validation fails, stop submission.
      return;
    }

    try {
      // Step 1: Fetch the user ID from secure storage.
      final userId = await _secureStorage.read(key: 'userId');
      if (userId == null) {
        throw Exception('User ID not found in secure storage');
      }

      // Step 2: Retrieve `sub_dist`, `dist`, and `state` from the `hospitals` table.
      final hospitalResponse = await Supabase.instance.client
          .from('hospitals')
          .select('sub_dist, dist, state')
          .eq('id', userId)
          .single();

      final subDistrict = hospitalResponse['sub_dist'] ?? '';
      final district = hospitalResponse['dist'] ?? '';
      final state = hospitalResponse['state'] ?? '';

      // Step 3: Insert data into the `diseases` table.
      final response = await Supabase.instance.client.from('diseases').insert({
        'aadhaar_no': aadhaarController.text,
        'name': nameController.text,
        'phone_no': phoneController.text,
        'dob': dobController.text,
        'gender': genderController.text,
        'disease': diseaseController.text,
        'sub_dist': subDistrict,
        'dist': district,
        'state': state,
      });

      if (response is PostgrestException) {
        throw Exception(response.message);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Query added successfully!')),
      );
      _clearFields();
    } catch (e) {
      print('Error submitting form: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting form: $e')),
      );
    }
  }

  String _generateOtp() {
    return (Random().nextInt(900000) + 100000).toString();
  }

  Future<void> _showOtpDialog() async {
    if (aadhaarController.text.length != 12) {
      _showSnackBar('Please enter a valid Aadhaar number');
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('patients')
          .select('phone_no')
          .eq('aadhaar_no', aadhaarController.text)
          .maybeSingle();

      if (response == null || response['phone_no'] == null) {
        _showSnackBar('No phone number found for the given Aadhaar number');
        return;
      }

      final phoneNumber = response['phone_no'];
      _generatedOtp = _generateOtp();
      print('Generated OTP: $_generatedOtp');

      await _sendOtp(phoneNumber, _generatedOtp!);
      _showOtpVerificationDialog(phoneNumber);
    } catch (e) {
      _showSnackBar('Error sending OTP: $e');
    }
  }

  void _showOtpVerificationDialog(String phoneNumber) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Verify OTP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('An OTP has been sent to $phoneNumber'),
            const SizedBox(height: 10),
            TextFormField(
              controller: _otpController,
              decoration: const InputDecoration(
                labelText: 'Enter OTP',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _verifyOtp();
              Navigator.of(context).pop();
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text != _generatedOtp) {
      _showSnackBar('Invalid OTP');
    } else {
      _showSnackBar('OTP Verified Successfully');
      _fetchAndFillData();
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendOtp(String phoneNumber, String otp) async {
    try {
      final fullPhoneNo = '+91$phoneNumber';
      const accountSid = 'AC64826596076bc006f1c5d3ba05f4dfc3';
      const authToken = '89a725823b185664b9682e9185143826';
      const fromPhoneNumber = '+19109943167';

      final twilioUrl =
          'https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json';

      await http.post(
        Uri.parse(twilioUrl),
        headers: {
          'Authorization':
              'Basic ${base64Encode(utf8.encode('$accountSid:$authToken'))}',
        },
        body: {
          'To': fullPhoneNo,
          'From': fromPhoneNumber,
          'Body': 'Your OTP is $otp. Please do not share it with anyone.',
        },
      );
    } catch (e) {
      throw Exception('Error sending OTP: $e');
    }
  }

  void _clearFields() {
    nameController.clear();
    aadhaarController.clear();
    phoneController.clear();
    dobController.clear();
    genderController.clear();
    diseaseController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 20),
                TextFormField(
                  controller: aadhaarController,
                  decoration: const InputDecoration(
                    labelText: 'Aadhaar Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter Aadhaar number';
                    } else if (value.length != 12 ||
                        !RegExp(r'^[0-9]+$').hasMatch(value)) {
                      return 'Enter a valid 12-digit Aadhaar number';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    if (_formKey.currentState != null) {
                      _formKey.currentState!.validate();
                    }
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _showOtpDialog,
                  child: const Text('Fetch Details'),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    labelStyle: TextStyle(color: Colors.black),
                    border: OutlineInputBorder(),
                    disabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black),
                    ),
                  ),
                  enabled: false,
                  style: const TextStyle(color: Colors.black),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    labelStyle: TextStyle(color: Colors.black),
                    border: OutlineInputBorder(),
                    disabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black),
                    ),
                  ),
                  enabled: false,
                  style: const TextStyle(color: Colors.black),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: dobController,
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth',
                    labelStyle: TextStyle(color: Colors.black),
                    border: OutlineInputBorder(),
                    disabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black),
                    ),
                  ),
                  enabled: false,
                  style: const TextStyle(color: Colors.black),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: genderController,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    labelStyle: TextStyle(color: Colors.black),
                    border: OutlineInputBorder(),
                    disabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.black),
                    ),
                  ),
                  enabled: false,
                  style: const TextStyle(color: Colors.black),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: diseaseController,
                  decoration: const InputDecoration(
                    labelText: 'Disease',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Please enter diseases'
                      : null,
                  onChanged: (value) {
                    if (_formKey.currentState != null) {
                      _formKey.currentState!.validate();
                    }
                  },
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: submitForm,
                  child: const Text('Submit'),
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
    nameController.dispose();
    aadhaarController.dispose();

    phoneController.dispose();
    dobController.dispose();
    genderController.dispose();
    diseaseController.dispose();
    super.dispose();
  }
}
