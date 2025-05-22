import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class AddPatientScreen extends StatefulWidget {
  const AddPatientScreen({super.key});

  @override
  State<AddPatientScreen> createState() => _AddPatientScreenState();
}

class _AddPatientScreenState extends State<AddPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _patientNameController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _addressController = TextEditingController();
  final _genderController = TextEditingController();
  final _pincodeController = TextEditingController();

  void _clearFields() {
    _patientNameController.clear();
    _aadhaarController.clear();
    _phoneController.clear();
    _dobController.clear();
    _addressController.clear();
    _genderController.clear();
    _pincodeController.clear();
  }

  void fetchDetails() async {
    final String phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showSnackBar("Please enter a phone number");
      return;
    }

    try {
      // Fetch multiple Aadhaar details for the phone number
      final List<dynamic> response = await Supabase.instance.client
          .from('aadhaar_api')
          .select('id, name, dob, gender, address, adhar_no, pincode, phone_no')
          .eq('phone_no', phone);

      if (response.isEmpty) {
        _showSnackBar("No details found for this phone number");
        return;
      }

      // Check for Aadhaar numbers in the 'patients' table
      final List aadhaarNumbers =
          response.map((user) => user['adhar_no']).toList();
      List<String> availableAadhaar = [];

      for (var aadhaar in aadhaarNumbers) {
        final diseaseResponse = await Supabase.instance.client
            .from('patients')
            .select('aadhaar_no')
            .eq('aadhaar_no', aadhaar);

        if (diseaseResponse.isEmpty) {
          availableAadhaar
              .add(aadhaar); // This Aadhaar is not in the disease table
        }
      }

      if (availableAadhaar.isEmpty) {
        _showSnackBar("Both Aadhaar numbers are already exists.");
        return;
      }

      // If there are multiple Aadhaar numbers, show them to the user for selection
      if (availableAadhaar.length > 1) {
        _showAadhaarSelectionDialog(availableAadhaar, response);
      } else {
        // If only one Aadhaar is available, show that automatically
        final selectedUser = response.firstWhere((user) =>
            user['adhar_no'] == availableAadhaar.first); // Get the user object
        // Generate OTP and send it first before displaying Aadhaar details
        final String otp = _generateOTP();
        print(otp);
        final otpSent = await _sendOtp(phone: phone, otp: otp);
        if (!otpSent) {
          _showSnackBar("Failed to send OTP. Please try again.");
          return;
        }

        // Show OTP dialog for verification (this blocks the UI)
        final otpVerified = await _showOtpDialog(otp);
        if (!otpVerified) {
          _showSnackBar("OTP verification failed. Please try again.");
          return;
        }

        // Now, after OTP is verified, set the Aadhaar details
        _setAadhaarDetails(selectedUser);

        // Proceed with saving patient details to the database after OTP verification
        await _submitForm();
      }
    } catch (error) {
      _showSnackBar("Error fetching details: $error");
    }
  }

  void _setAadhaarDetails(dynamic user) {
    setState(() {
      _patientNameController.text =
          user['name'] ?? ''; // Default to empty string if null
      _dobController.text = user['dob'] ?? '';
      _genderController.text = user['gender'] ?? '';
      _addressController.text = user['address'] ?? '';
      _aadhaarController.text = user['adhar_no'] ?? '';
      _pincodeController.text = user['pincode'] ?? '';
    });
  }

  Future<bool> _showOtpDialog(String generatedOtp) async {
    final TextEditingController otpController = TextEditingController();
    bool verified = false;

    // Show OTP dialog and block the UI until verification is done
    await showDialog(
      context: context,
      barrierDismissible: false, // Prevent closing without verification
      builder: (context) => AlertDialog(
        title: const Text('OTP Verification'),
        content: TextFormField(
          controller: otpController,
          decoration: const InputDecoration(labelText: 'Enter OTP'),
          keyboardType: TextInputType.number,
          maxLength: 6,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (otpController.text == generatedOtp) {
                verified = true;
                Navigator.of(context).pop();
              } else {
                _showSnackBar("Incorrect OTP. Please try again.");
              }
            },
            child: const Text('Verify'),
          ),
        ],
      ),
    );

    return verified;
  }

  void _showAadhaarSelectionDialog(
      List<String> availableAadhaar, List<dynamic> response) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Aadhaar Number'),
        content: ListView.builder(
          shrinkWrap: true,
          itemCount: availableAadhaar.length,
          itemBuilder: (context, index) {
            final aadhaar = availableAadhaar[index];
            return ListTile(
              title: Text(aadhaar),
              onTap: () async {
                final selectedAadhaar = aadhaar;
                final user = response
                    .firstWhere((user) => user['adhar_no'] == selectedAadhaar);
                _setAadhaarDetails(user);

                // Generate OTP and send it
                final String otp = _generateOTP();
                final otpSent =
                    await _sendOtp(phone: user['phone_no'], otp: otp);
                if (!otpSent) {
                  _showSnackBar("Failed to send OTP. Please try again.");
                  return;
                }

                // Show OTP dialog for verification
                final otpVerified = await _showOtpDialog(otp);
                if (!otpVerified) {
                  _showSnackBar("OTP verification failed. Please try again.");
                  return;
                }

                Navigator.of(context).pop();
                await _submitForm();
              },
            );
          },
        ),
      ),
    );
  }

  void _showMultipleUsersDialog(List<dynamic> response) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Multiple Users Found'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: response.length,
            itemBuilder: (context, index) {
              final user = response[index];
              return ListTile(
                title: Text(user['name'] ?? 'Unknown'),
                subtitle: Text('Phone: ${user['phone_no'] ?? 'N/A'}'),
                onTap: () {
                  setState(() {
                    _patientNameController.text = user['name'] ?? '';
                    _dobController.text = user['dob'] ?? '';
                    _genderController.text = user['gender'] ?? '';
                    _addressController.text = user['address'] ?? '';
                    _aadhaarController.text = user['adhar_no'] ?? '';
                    _pincodeController.text = user['pincode'] ?? '';
                  });
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
      ),
    );
  }

  String _generateOTP() {
    final random = Random();
    return List.generate(6, (index) => random.nextInt(10)).join();
  }

  Future<bool> _sendOtp({required phone, required otp}) async {
    final fullPhoneNo = '+91$phone';
    // Send SMS using Twilio
    const accountSid =
        'AC64826596076bc006f1c5d3ba05f4dfc3'; // Replace with your Twilio Account SID
    const authToken =
        '89a725823b185664b9682e9185143826'; // Replace with your Twilio Auth Token
    const fromPhoneNumber =
        '+19109943167'; // Replace with your Twilio phone number

    final twilioUrl =
        'https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json';

    // ignore: unused_local_variable
    final twilioResponse = await http.post(
      Uri.parse(twilioUrl),
      headers: {
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$accountSid:$authToken'))}',
      },
      body: {
        'To': fullPhoneNo,
        'From': fromPhoneNumber,
        'Body': 'Your otp:$otp \nDon,t share it with any one',
      },
    );
    return Future.delayed(const Duration(seconds: 1), () => true);
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fill all required fields.');
      return;
    }

    _showLoadingIndicator();

    try {
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
      final supabase = Supabase.instance.client;

      await supabase.from('patients').insert([
        {
          'name': _patientNameController.text.trim(),
          'aadhaar_no': _aadhaarController.text.trim(),
          'phone_no': _phoneController.text.trim(),
          'dob': _dobController.text.trim(),
          'address': _addressController.text.trim(),
          'gender': _genderController.text.trim(),
          'pincode': _pincodeController.text.trim(),
          'sub_dist': subDistrict,
          'dist': district,
          'state': state,
        }
      ]);

      _showSnackBar('Patient added successfully!');
      _clearFields();
    } catch (error) {
      _showSnackBar('Error: $error');
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _showLoadingIndicator() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 10,
                  keyboardType: TextInputType.phone,
                  validator: (value) => value != null && value.trim().isNotEmpty
                      ? null
                      : 'Phone is required',
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: fetchDetails,
                  child: const Text('Fetch Details'),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _patientNameController,
                  label: 'Patient Name',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _aadhaarController,
                  label: 'Aadhaar Number',
                  maxLength: 12,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _dobController,
                  label: 'Date of Birth',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _addressController,
                  label: 'Address',
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _genderController,
                  label: 'Gender',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _pincodeController,
                  label: 'PIN Code',
                  maxLength: 6,
                  keyboardType: TextInputType.number,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    int maxLength = 0,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    IconData? suffixIcon,
    void Function()? onTap,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black),
        border: const OutlineInputBorder(
          borderSide: BorderSide(
            color: Colors.black,
          ),
        ),
        suffixIcon: suffixIcon != null ? Icon(suffixIcon) : null,
      ),
      style: const TextStyle(color: Colors.black),
      enabled: false,
      maxLength: maxLength > 0 ? maxLength : null,
      maxLines: maxLines,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      validator: validator,
    );
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _aadhaarController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    _genderController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }
}
