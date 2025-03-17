import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // for clickable text spans
import 'package:supabase_flutter/supabase_flutter.dart'; // import Supabase
import 'map_page.dart';
import 'login_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA), // Off-white background
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // -- TOP BAR --
          Container(
            color: const Color(0xFF1E88E5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left: "STATTRAK" with stroke + fill
                Stack(
                  children: [
                    // 1) Black stroke
                    Text(
                      'STATTRAK',
                      style: TextStyle(
                        fontFamily: 'RubikMonoOne',
                        fontSize: 48,
                        foreground: Paint()
                          ..style = PaintingStyle.stroke
                          ..strokeWidth = 4
                          ..color = Colors.black,
                      ),
                    ),
                    // 2) Orange fill
                    Text(
                      'STATTRAK',
                      style: TextStyle(
                        fontFamily: 'RubikMonoOne',
                        fontSize: 48,
                        color: const Color(0xFFFFA800),
                      ),
                    ),
                  ],
                ),
                // Right: "Log In" button
                SizedBox(
                  width: 104,
                  height: 42,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFA800),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginPage()),
                      );
                    },
                    child: Text(
                      'Log In',
                      style: TextStyle(
                        fontFamily: 'DMMono',
                        fontSize: 16,
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT: Big heading
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 40),
                      child: Text(
                        'A WEB-BASED INFORMATION FOR CYCLISTS THAT IT’S EASY AND FREE',
                        style: TextStyle(
                          fontFamily: 'RubikMonoOne',
                          fontSize: 34,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  // RIGHT: Sign-up form
                  Expanded(
                    flex: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Name
                            _buildTextField(
                              controller: _nameController,
                              label: 'Name',
                            ),
                            const SizedBox(height: 16),
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
                            const SizedBox(height: 16),
                            // Confirm Password
                            _buildTextField(
                              controller: _confirmPasswordController,
                              label: 'Confirm Password',
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please confirm your password';
                                }
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            // SIGN UP BUTTON
                            SizedBox(
                              width: 212,
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFA800),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.zero,
                                  ),
                                ),
                                onPressed: () async {
                                  if (_formKey.currentState!.validate()) {
                                    // Show signing up message
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Signing up...')),
                                    );

                                    try {
                                      // 1) Sign up with Supabase Auth
                                      final response = await Supabase
                                          .instance.client.auth.signUp(
                                        email: _emailController.text,
                                        password: _passwordController.text,
                                      );

                                      // Check if the sign-up was unsuccessful
                                      if (response.user == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Sign-up error: Unable to create user.'),
                                          ),
                                        );
                                        return;
                                      }

                                      // 2) Insert a row in user_profiles for the new user
                                      final user = response.user;
                                      final insertResponse = await Supabase
                                          .instance.client
                                          .from('user_profiles')
                                          .insert({
                                        'user_id': user!.id,
                                        'name': _nameController.text,
                                      });

                                      // If no exception is thrown, assume success
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(builder: (context) => MapPage()),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Exception: $e')),
                                      );
                                    }
                                  }
                                }, // Ensure comma here
                                child: Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    fontFamily: 'DMMono',
                                    fontSize: 20,
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
          // -- FOOTER TEXT --
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: _buildFooterText(),
          ),
        ],
      ),
    );
  }

  // Reusable text field builder
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator ??
              (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your $label';
            }
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontFamily: 'DMMono',
          fontSize: 20,
        ),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
        ),
      ),
      style: const TextStyle(
        fontFamily: 'DMMono',
        fontSize: 20,
      ),
    );
  }

  // Footer with clickable Terms and Privacy
  Widget _buildFooterText() {
    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: TextStyle(
            fontFamily: 'Dangrek',
            fontSize: 14,
            color: Colors.black,
            height: 2.3,
          ),
          children: [
            const TextSpan(
              text: 'By signing up for Stattrak, you agree to the ',
            ),
            TextSpan(
              text: 'Terms of Service',
              style: const TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()..onTap = () {
                // TODO: open Terms of Service link
              },
            ),
            const TextSpan(text: '. View our '),
            TextSpan(
              text: 'Privacy Policy',
              style: const TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()..onTap = () {
                // TODO: open Privacy Policy link
              },
            ),
            const TextSpan(text: '.'),
          ],
        ),
      ),
    );
  }
}
