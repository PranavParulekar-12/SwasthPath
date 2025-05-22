import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:swasthapath/screens/hospital/main_screen.dart';
import 'package:swasthapath/screens/hospital/register_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _secureStorage = const FlutterSecureStorage();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isPasswordVisible = false;
  // ignore: unused_field
  final bool _isOtpVisible = false;
  bool _isOtpSent = false; // Track OTP sent status

  String? _userEmail; // Store email for OTP verification
  String? _otp; // Store OTP for comparison
  String? adminId;
  // Function to generate a random OTP
  String generateOtp() {
    final random = Random();
    int otp = random.nextInt(900000) + 100000; // Generates a 6-digit OTP
    return otp.toString();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      try {
        final supabase = Supabase.instance.client;

        // Query the database for the hospital with the given email
        final response = await supabase
            .from('hospitals')
            .select('password, status, id, email')
            .eq('email', email)
            .maybeSingle(); // Safely handles zero or one result

        if (response == null) {
          // No hospital found with that email
          _showErrorDialog("No hospital found with that email.");
          return;
        }

        final dbPassword = response['password'];
        final status = response['status'];

        // Check if the status is true (active)
        if (status == true) {
          if (password == dbPassword) {
            // Store the user email for OTP verification later
            _userEmail = response['email'];
            adminId = response['id'].toString();

            // Generate and send OTP
            _otp = generateOtp();
            await _sendOtpToEmail(_userEmail!, _otp!);

            // OTP sent, show OTP input field
            setState(() {
              _isOtpSent = true;
            });
          } else {
            // Password mismatch
            _showErrorDialog("Invalid email or password.");
          }
        } else {
          // Hospital is inactive
          _showErrorDialog(
              "Your account is inactive. Please contact the admin.");
        }
      } catch (error) {
        // Handle any errors (e.g., network issues, Supabase query errors)
        _showErrorDialog('An error occurred: ${error.toString()}');
      }
    }
  }

  Future<void> _sendOtpToEmail(String email, String otp) async {
    final url = Uri.parse(
        'https://api.sendgrid.com/v3/mail/send'); // SendGrid API endpoint

    final apiKey =
        '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'; // Replace with your actual SendGrid API key

    print(otp);
    final requestBody = {
      "personalizations": [
        {
          "to": [
            {
              "email": email, // Recipient email address
            }
          ],
          "subject": "Your OTP Code", // Email subject
        }
      ],
      "from": {
        "email":
            "bhuwad.atharva@gmail.com", // Your verified SendGrid sender email
      },
      "content": [
        {
          "type": "text/plain",
          "value": "Your OTP code is: $otp", // The OTP message
        }
      ],
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 202) {
        // OTP sent successfully
        print('OTP sent successfully!');
      } else {
        // Failed to send OTP
        _showErrorDialog("Failed to send OTP. Please try again.");
      }
    } catch (e) {
      // Handle errors such as network issues or invalid API key
    }
  }

  // Function to verify OTP
  Future<void> _verifyOtp() async {
    final otpEntered = _otpController.text.trim();
    if (otpEntered == _otp) {
      // OTP is correct, proceed to the next screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP verified successfully!')),
      );

      // Ensure adminId is converted to string if it's not already a string
      if (adminId != null) {
        await _secureStorage.write(key: 'userId', value: adminId.toString());
      } else {
        _showErrorDialog("Admin ID is not available.");
        return;
      }

      // Navigate to the main screen after successful OTP verification
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
        (route) => false, // Removes all previous routes
      );
    } else {
      // Invalid OTP
      _showErrorDialog("Invalid OTP. Please try again.");
    }
  }

  // Function to show an error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Error'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
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
                    return 'Please enter your password';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text('Login'),
              ),
              const SizedBox(height: 16),
              _isOtpSent
                  ? Column(
                      children: [
                        TextFormField(
                          controller: _otpController,
                          decoration: const InputDecoration(
                            labelText: 'Enter OTP',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter the OTP';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _verifyOtp,
                          child: const Text('Verify OTP'),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account?"),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegisterScreen(),
                        ),
                      );
                    },
                    child: const Text('Register here'),
                  ),
                ],
              ),
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
