import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class ApplySchemeScreen extends StatefulWidget {
  const ApplySchemeScreen({super.key});

  @override
  _ApplySchemeScreenState createState() => _ApplySchemeScreenState();
}

class _ApplySchemeScreenState extends State<ApplySchemeScreen> {
  final _aadhaarController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _genderController = TextEditingController();
  final _addressController = TextEditingController();
  final _otpController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  final _secureStorage = const FlutterSecureStorage();

  String? _selectedScheme;
  String? _generatedOtp;
  String? _selectedCertificatePath;
  String? _selectedbillPath;

  List<String> _schemes = [];

  @override
  void initState() {
    super.initState();
    _fetchSchemes();
  }

  Future<void> _fetchSchemes() async {
    try {
      final response =
          await Supabase.instance.client.from('schemes').select('scheme_name');

      setState(() {
        // Use a Set to automatically remove duplicates
        _schemes = List<String>.from(
          (response as List<dynamic>)
              .map((row) => row['scheme_name'].toString())
              .toSet(), // Convert the list to a Set to remove duplicates
        );
      });
    } catch (e) {
      _showSnackBar('Error fetching schemes: $e');
    }
  }

  Future<void> _showOtpDialog() async {
    if (_aadhaarController.text.length != 12) {
      _showSnackBar('Please enter a valid Aadhaar number');
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('patients')
          .select('phone_no')
          .eq('aadhaar_no', _aadhaarController.text)
          .maybeSingle();

      if (response == null || response['phone_no'] == null) {
        _showSnackBar('No phone number found for the given Aadhaar number');
        return;
      }

      final phoneNumber = response['phone_no'];
      _generatedOtp = _generateOtp();

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

  String _generateOtp() {
    return (Random().nextInt(900000) + 100000).toString();
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

  Future<void> _verifyOtp() async {
    if (_otpController.text != _generatedOtp) {
      _showSnackBar('Invalid OTP');
    } else {
      _showSnackBar('OTP Verified Successfully');
      _fetchAndFillData();
    }
  }

  Future<void> _fetchAndFillData() async {
    try {
      final response = await Supabase.instance.client
          .from('patients')
          .select('name, phone_no, dob, gender, address')
          .eq('aadhaar_no', _aadhaarController.text)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _nameController.text = response['name'] ?? '';
          _phoneController.text = response['phone_no'] ?? '';
          _dobController.text = response['dob'] ?? '';
          _genderController.text = response['gender'] ?? '';
          _addressController.text = response['address'] ?? '';
        });
      } else {
        _showSnackBar('No patient data found');
      }
    } catch (e) {
      _showSnackBar('Error fetching data: $e');
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final supabase = Supabase.instance.client;
      // Fetch user ID from secure storage
      final userId = await _secureStorage.read(key: 'userId');
      print(userId);
      if (userId == null) {
        throw Exception('User ID not found in secure storage');
      }

      // Fetch hospital details based on the user ID
      final hospitalResponse = await Supabase.instance.client
          .from('hospitals')
          .select('sub_dist, dist, state')
          .eq('id', userId)
          .single();

      // Upload the PDF file if selected
      String? CertificateUrl;
      if (_selectedCertificatePath != null) {
        final fileBytes = await File(_selectedCertificatePath!).readAsBytes();
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${_selectedCertificatePath!.split('/').last}';
        await supabase.storage.from('documents').uploadBinary(
              'income_certificate/$fileName',
              fileBytes,
              fileOptions: const FileOptions(upsert: false),
            );
        CertificateUrl = supabase.storage
            .from('documents')
            .getPublicUrl('income_certificate/$fileName');
      }

      String? billUrl;
      if (_selectedbillPath != null) {
        final fileBytes = await File(_selectedbillPath!).readAsBytes();
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${_selectedbillPath!.split('/').last}';
        await supabase.storage.from('documents').uploadBinary(
              'bill/$fileName',
              fileBytes,
              fileOptions: const FileOptions(upsert: false),
            );
        billUrl =
            supabase.storage.from('documents').getPublicUrl('bill/$fileName');
      }

      // Insert the form data into the database
      await Supabase.instance.client.from('applied_schemes').insert({
        'aadhaar_no': _aadhaarController.text,
        'name': _nameController.text,
        'phone_no': _phoneController.text,
        'dob': _dobController.text,
        'gender': _genderController.text,
        'address': _addressController.text,
        'scheme_name': _selectedScheme,
        'sub_dist': hospitalResponse['sub_dist'],
        'dist': hospitalResponse['dist'],
        'state': hospitalResponse['state'],
        'income_certificate': CertificateUrl,
        'bill': billUrl,
      });

      _showSuccessDialog();
    } catch (e) {
      _showSnackBar('Error submitting form: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registration Successful'),
        content: const Text(
          'Your request has been sent to the sub-district admin. They will review your details and respond to you via email.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearFields();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickCertificatePdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null) {
      setState(() {
        _selectedCertificatePath = result.files.single.path;
      });
    }
  }

  Future<void> _pickBillPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null) {
      setState(() {
        _selectedbillPath = result.files.single.path;
      });
    }
  }

  void _clearFields() {
    setState(() {
      _selectedScheme = null;
      _aadhaarController.clear();
      _nameController.clear();
      _phoneController.clear();
      _dobController.clear();
      _genderController.clear();
      _addressController.clear();
      _otpController.clear();
    });
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
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Scheme',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedScheme,
                  items: _schemes
                      .map((scheme) => DropdownMenuItem<String>(
                            value: scheme,
                            child: Text(scheme),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() => _selectedScheme = value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _aadhaarController,
                  decoration: const InputDecoration(
                    labelText: 'Aadhaar Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  validator: (value) {
                    if (value == null || value.isEmpty || value.length != 12) {
                      return 'Aadhaar must be 12 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _showOtpDialog,
                  child: const Text('Send OTP'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dobController,
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _genderController,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Permanent Address',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _pickCertificatePdf,
                  child: const Text('Income Certificate'),
                ),
                if (_selectedCertificatePath != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Selected PDF: ${_selectedCertificatePath!.split('/').last}',
                      style: const TextStyle(fontSize: 14, color: Colors.black),
                    ),
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _pickBillPdf,
                  child: const Text('Upload Bill'),
                ),
                if (_selectedbillPath != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Selected PDF: ${_selectedbillPath!.split('/').last}',
                      style: const TextStyle(fontSize: 14, color: Colors.black),
                    ),
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _submitForm,
                  child: const Text('Submit'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
