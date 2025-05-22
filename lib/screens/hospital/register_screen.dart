import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hospitalNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _passwordController = TextEditingController();

  String? _selectedPdfPath;
  bool _isPasswordVisible = false;

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null) {
      setState(() {
        _selectedPdfPath = result.files.single.path;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields.')),
      );
      return;
    }

    // Show a loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final supabase = Supabase.instance.client;

      // Fetch location details using the pincode
      final pincode = _pincodeController.text.trim();
      final locationResponse = await http.get(
        Uri.parse('https://api.postalpincode.in/pincode/$pincode'),
      );

      if (locationResponse.statusCode != 200) {
        throw Exception('Failed to fetch location details');
      }

      final locationData = jsonDecode(locationResponse.body);
      if (locationData == null ||
          locationData.isEmpty ||
          locationData[0]['Status'] != 'Success') {
        throw Exception('Invalid pincode or no data available');
      }

      final postOffice = locationData[0]['PostOffice'][0];
      final subDistrict = postOffice['Block'] ?? '';
      final district = postOffice['District'] ?? '';
      final state = postOffice['State'] ?? '';

      // Upload the PDF file if selected
      String? pdfUrl;
      if (_selectedPdfPath != null) {
        final fileBytes = await File(_selectedPdfPath!).readAsBytes();
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${_selectedPdfPath!.split('/').last}';

        await supabase.storage.from('documents').uploadBinary(
              'hospital_pdfs/$fileName',
              fileBytes,
              fileOptions: const FileOptions(upsert: false),
            );

        pdfUrl = supabase.storage
            .from('documents')
            .getPublicUrl('hospital_pdfs/$fileName');
      }

      // Insert hospital data into the database
      await supabase.from('hospitals').insert({
        'hospital_name': _hospitalNameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'phone_no': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'pincode': pincode,
        'sub_dist': subDistrict,
        'dist': district,
        'state': state,
        'certificate': pdfUrl,
      });

      // Show success message
      await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Registration Successful'),
            content: const Text(
                'Your request has been sent to the sub-district admin. They will review your details and respond to you via email.'),
            actions: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.of(context, rootNavigator: true).pop();
                  _clearTextfield();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    } catch (error) {
      // Show an error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${error.toString()}')),
      );
    } finally {
      // Dismiss the loading dialog
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _clearTextfield() {
    _hospitalNameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _addressController.clear();
    _pincodeController.clear();
    _passwordController.clear();
    _selectedPdfPath = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _hospitalNameController,
                  decoration: const InputDecoration(
                    labelText: 'Hospital Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter hospital name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter email';
                    } else if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                        .hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                  ),
                  obscureText: !_isPasswordVisible,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter password';
                    } else if (value.length < 6) {
                      return 'Password must be at least 6 characters long';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  maxLength: 10,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter phone number';
                    } else if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                      return 'Please enter a valid 10-digit phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _pincodeController,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Pincode',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter pincode';
                    } else if (!RegExp(r'^\d{6}$').hasMatch(value)) {
                      return 'Please enter a valid 6-digit pincode';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _pickPdf,
                  child: const Text('Upload NABH Certificate'),
                ),
                if (_selectedPdfPath != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'Selected PDF: ${_selectedPdfPath!.split('/').last}',
                      style: const TextStyle(fontSize: 14, color: Colors.black),
                    ),
                  ),
                const SizedBox(height: 16),
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
    _hospitalNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
