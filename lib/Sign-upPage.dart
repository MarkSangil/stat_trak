import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stattrak/map_page.dart';
import 'package:provider/provider.dart';
import 'providers/SupabaseProvider.dart';
import 'package:stattrak/login_page.dart';

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

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Signing up...')),
    );

    try {
      final supabaseProvider =
      Provider.of<SupabaseProvider>(context, listen: false);
      final user = await supabaseProvider.signUpUser(
        email: _emailController.text,
        password: _passwordController.text,
        name: _nameController.text,
      );

      if (user == null) {
        // Either sign-up failed, or user needs to confirm email
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Please check your email to confirm your account or try again.'),
          ),
        );
        return;
      }

      // Sign-up successful and profile created
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: LayoutBuilder( // Use LayoutBuilder for responsiveness
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final isLargeScreen = screenWidth > 800; // Example breakpoint

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context, isLargeScreen), // Pass isLargeScreen
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: isLargeScreen
                      ? _buildLargeScreenContent(context)  // Use extracted method
                      : _buildSmallScreenContent(context, isLargeScreen), // Pass isLargeScreen
                ),
              ),
              _buildFooterText(), // Extract footer
            ],
          );
        },
      ),
    );
  }

  // Extracted Header Widget
  Widget _buildHeader(BuildContext context, bool isLargeScreen) {
    return Container(
      color: const Color(0xFF1E88E5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(
            child: Stack(
              children: [
                Text(
                  'STATTRAK',
                  style: TextStyle(
                    fontFamily: 'RubikMonoOne',
                    fontSize: isLargeScreen ? 48 : 32,
                    foreground: Paint()
                      ..style = PaintingStyle.stroke
                      ..strokeWidth = 4
                      ..color = Colors.black,
                  ),
                ),
                Text(
                  'STATTRAK',
                  style: TextStyle(
                    fontFamily: 'RubikMonoOne',
                    fontSize: isLargeScreen ? 48 : 32,
                    color: const Color(0xFFFFA800),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: isLargeScreen ? 10 : 0),
          // Fix the SizedBox width
          SizedBox(
            width: 120, // Fixed width instead of isLargeScreen ? 104 : double.infinity
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
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              },
              child: const Text(
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
    );
  }

  // Extracted Large Screen Content
  Widget _buildLargeScreenContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(right: 40),
              child: Align( // Added Align widget
                alignment: Alignment.centerLeft,
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
          ),
          Expanded(
            flex: 1,
            child: _buildForm(context),
          ),
        ],
      ),
    );
  }

  // Extracted Small Screen Content
  Widget _buildSmallScreenContent(BuildContext context, bool isLargeScreen) { // Added isLargeScreen
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center, // Center on small screens
        children: [
          if (!isLargeScreen) // Add this condition
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                'A WEB-BASED INFORMATION FOR CYCLISTS THAT IT’S EASY AND FREE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'RubikMonoOne',
                  fontSize: 24, // Smaller font size for small screens
                  color: Colors.black,
                ),
              ),
            ),
          _buildForm(context),
        ],
      ),
    );
  }


  // Extracted Form Widget
  Widget _buildForm(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTextField(
              controller: _nameController,
              label: 'Name',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _passwordController,
              label: 'Password',
              obscureText: true,
            ),
            const SizedBox(height: 16),
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
                onPressed: _handleSignUp,
                child: const Text(
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
    );
  }

  // Extracted TextField Widget
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
        labelStyle: const TextStyle(
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

  // Extracted Footer Widget
  Widget _buildFooterText() {
    return Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: const TextSpan(
          style: TextStyle(
            fontFamily: 'Dangrek',
            fontSize: 14,
            color: Colors.black,
            height: 2.3,
          ),
          children: [
            TextSpan(
              text: 'By signing up for Stattrak, you agree to the ',
            ),
            TextSpan(
              text: 'Terms of Service',
              style: TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
            TextSpan(text: '. View our '),
            TextSpan(
              text: 'Privacy Policy',
              style: const TextStyle(
                color: Colors.blue,
                decoration: TextDecoration.underline,
              ),
            ),
            TextSpan(text: '.'),
          ],
        ),
      ),
    );
  }
}

