import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:swasthapath/screens/admin/dist_state/ds_admin_main.dart';
import 'package:swasthapath/screens/admin/sub_dist/admin_main_screen.dart';
import 'package:swasthapath/screens/admin/super/super_admin_main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _secureStorage = const FlutterSecureStorage();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isOtpFieldVisible = false;
  String? _generatedOtp;

  final String sendgridApiKey =
      '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';
  final String fromEmail = 'bhuwad.atharva@gmail.com';

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      try {
        final supabase = Supabase.instance.client;

        // Query the database for the admin with the given email
        final response = await supabase
            .from('admin')
            .select('password, id, role')
            .eq('email', email)
            .maybeSingle();

        if (response == null) {
          _showErrorDialog("No admin found with that email.");
          return;
        }

        final dbPassword = response['password'];

        if (password == dbPassword) {
          // Generate and send OTP
          _generatedOtp = _generateOtp();
          await _sendOtp(email, _generatedOtp!);
          setState(() {
            _isOtpFieldVisible = true;
          });
        } else {
          _showErrorDialog("Invalid email or password.");
        }
      } catch (error) {}
    }
  }

  String _generateOtp() {
    return (Random().nextInt(900000) + 100000).toString();
  }

  Future<void> _sendOtp(String recipientEmail, String otp) async {
    final url = Uri.parse('https://api.sendgrid.com/v3/mail/send');
    final headers = {
      'Authorization': 'Bearer $sendgridApiKey',
      'Content-Type': 'application/json',
    };
    print(otp);
    final emailBody = {
      'personalizations': [
        {
          'to': [
            {'email': recipientEmail}
          ],
          'subject': 'Your OTP Code'
        }
      ],
      'from': {'email': fromEmail},
      'content': [
        {
          'type': 'text/plain',
          'value': 'Your OTP code is $otp. Please do not share it with anyone.'
        }
      ]
    };

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(emailBody),
      );

      if (response.statusCode == 202) {
        _showSnackBar('OTP sent to $recipientEmail');
      } else {
        _showSnackBar('Failed to send OTP: ${response.body}');
      }
    } catch (e) {}
  }

  Future<void> _verifyOtp(String userId, String role) async {
    if (_otpController.text == _generatedOtp) {
      _showSnackBar('OTP Verified Successfully');

      await _secureStorage.write(key: 'adminId', value: userId);
      await _secureStorage.write(key: 'role', value: role);

      // Navigate to the appropriate screen based on role
      if (role == 'sub_dist') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AdminMainScreen()),
          (route) => false,
        );
      } else if (role == 'dist' || role == 'state') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const DsAdminMain()),
          (route) => false,
        );
      } else if (role == 'super') {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const SuperAdminMain()),
          (route) => false,
        );
      } else {
        _showErrorDialog("Invalid role assigned.");
      }
    } else {
      _showSnackBar('Invalid OTP');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Login Failed'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter your email'
                    : null,
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
                    onPressed: () => setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    }),
                  ),
                ),
                obscureText: !_isPasswordVisible,
                validator: (value) => value == null || value.isEmpty
                    ? 'Please enter your password'
                    : null,
              ),
              const SizedBox(height: 16),
              if (_isOtpFieldVisible) ...[
                TextFormField(
                  controller: _otpController,
                  decoration: const InputDecoration(
                    labelText: 'Enter OTP',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final supabase = Supabase.instance.client;
                    final response = await supabase
                        .from('admin')
                        .select('id, role')
                        .eq('email', _emailController.text.trim())
                        .maybeSingle();

                    if (response != null) {
                      await _verifyOtp(response['id'].toString(),
                          response['role'].toString());
                    }
                  },
                  child: const Text('Verify OTP'),
                ),
              ],
              if (!_isOtpFieldVisible)
                ElevatedButton(
                  onPressed: _submitForm,
                  child: const Text('Login'),
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }
}
