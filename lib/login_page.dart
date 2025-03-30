import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:stattrak/Sign-upPage.dart';
import 'package:provider/provider.dart';
import 'providers/SupabaseProvider.dart';
import 'package:stattrak/DashboardPage.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logging in...')),
      );

      try {
        final supabaseProvider =
        Provider.of<SupabaseProvider>(context, listen: false);
        final user = await supabaseProvider.signInUser(
          email: _emailController.text,
          password: _passwordController.text,
        );

        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login failed. Check credentials or confirm email.')),
          );
          return;
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardPage()),
        );
      } catch (e) {
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
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final isLargeScreen = screenWidth > 800;

          return Column(
            children: [
              _buildHeader(context, isLargeScreen),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                  child: isLargeScreen
                      ? _buildLargeScreenContent(context)
                      : _buildSmallScreenContent(context),
                ),
              ),
              _buildFooterText(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isLargeScreen) {
    return Container(
      color: const Color(0xFF2F394D),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'STATTRAK',
            style: TextStyle(
              fontFamily: 'RubikMonoOne',
              fontSize: isLargeScreen ? 34 : 24,
              color: const Color(0xFFFFA800),
            ),
          ),
          // Fixed SizedBox - provide a fixed width instead of double.infinity
          SizedBox(
            width: 120, // Use a reasonable fixed width
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
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignUpPage()),
                );
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
    );
  }

  Widget _buildLargeScreenContent(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.only(right: 40),
            child: Align(
              alignment: Alignment.centerLeft,
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
        ),
        Expanded(
          flex: 1,
          child: _buildForm(context),
        ),
      ],
    );
  }

  Widget _buildSmallScreenContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Text(
            'A WEB-BASED INFORMATION FOR CYCLISTS\nTHAT IT’S EASY AND FREE',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'RubikMonoOne',
              fontSize: 24,
              color: Colors.black,
            ),
          ),
        ),
        _buildForm(context),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 350),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                onPressed: _handleLogin,
                child: const Text(
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
    );
  }


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
        labelStyle: const TextStyle(
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

  Widget _buildFooterText() {
    return  Center(
      child: RichText(
        textAlign: TextAlign.center,
        text: const TextSpan(
          style: TextStyle(
            fontFamily: 'RubikMonoOne',
            fontSize: 12,
            color: Colors.black,
            height: 2.3,
          ),
          children: [
            TextSpan(
              text: 'By signing up for Stattrak, you agree to the Terms of Service. View our Privacy Policy.',
            ),
          ],
        ),
      ),
    );
  }
}

