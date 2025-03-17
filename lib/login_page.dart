import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'map_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      // Show quick "Logging in..." message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logging in...')),
      );

      try {
        // 1) Call signInWithPassword
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

        // 2) Check if login was successful
        if (response.user == null) {
          // If user is null, login failed
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login failed. Check your credentials.')),
          );
          return;
        }

        // 3) Success: Navigate to your home/map page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MapPage()),
        );
      } catch (e) {
        // Catch any other errors
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // -- TOP BAR --
          Container(
            color: const Color(0xFF2F394D),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left: "STATTRAK"
                Text(
                  'STATTRAK',
                  style: TextStyle(
                    fontFamily: 'RubikMonoOne',
                    fontSize: 34,
                    color: const Color(0xFFFFA800),
                  ),
                ),
                // Right: "Sign Up" button
                SizedBox(
                  width: 80,
                  height: 36,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFA800),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    onPressed: () {
                      // TODO: Navigate to your SignUpPage
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(builder: (context) => SignUpPage()),
                      // );
                    },
                    child: Text(
                      'Sign Up',
                      style: TextStyle(
                        fontFamily: 'RubikMonoOne',
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // -- MAIN CONTENT --
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT: Big heading
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 40),
                      child: Text(
                        'A WEB-BASED INFORMATION FOR CYCLISTS\nTHAT IT’S EASY AND FREE',
                        style: TextStyle(
                          fontFamily: 'RubikMonoOne',
                          fontSize: 34,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  // RIGHT: Login form
                  Expanded(
                    flex: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 350),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Email
                            _buildTextField(
                              controller: _emailController,
                              label: 'Email',
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 16),

                            // Password
                            _buildTextField(
                              controller: _passwordController,
                              label: 'Password',
                              obscureText: true,
                            ),
                            const SizedBox(height: 24),

                            // LOG IN BUTTON
                            SizedBox(
                              width: 120,
                              height: 40,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFA800),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.zero,
                                  ),
                                ),
                                onPressed: _handleLogin, // Use the method
                                child: Text(
                                  'Log In',
                                  style: TextStyle(
                                    fontFamily: 'RubikMonoOne',
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // -- FOOTER --
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'By signing up for Stattrak, you agree to the Terms of Service. View our Privacy Policy.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'RubikMonoOne',
                fontSize: 12,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper for text fields
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your $label';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'RubikMonoOne',
          fontSize: 14,
          color: Colors.black,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Colors.black, width: 1),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Colors.black),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Colors.black, width: 2),
        ),
      ),
      style: const TextStyle(
        fontFamily: 'RubikMonoOne',
        fontSize: 14,
        color: Colors.black,
      ),
    );
  }
}
