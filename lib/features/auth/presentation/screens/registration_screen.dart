import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/widgets/app_layout.dart';
import '../../../../core/widgets/fade_in.dart';
import '../../../../core/theme/page_transition.dart';
import '../../../../core/navigation/main_navigation.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool obscurePassword = true;
  bool isLoading = false;

  Future<void> _register() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final email = emailController.text.trim();

      // Check if email exists in Customer Billing Table (customers collection)
      final customerQuery = await FirebaseFirestore.instance
          .collection('customers')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (customerQuery.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Your email is not associated with any purchased product. Please contact support."),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        setState(() => isLoading = false);
        return;
      }

      final customerDoc = customerQuery.docs.first;
      final customerId = customerDoc.id;

      // Query linked product
      final productQuery = await FirebaseFirestore.instance
          .collection('products')
          .where('customer_id', isEqualTo: customerId)
          .limit(1)
          .get();
      final productId = productQuery.docs.isNotEmpty ? productQuery.docs.first.id : '';

      // Query linked invoice
      final invoiceQuery = await FirebaseFirestore.instance
          .collection('invoices')
          .where('customer_id', isEqualTo: customerId)
          .limit(1)
          .get();
      final invoiceNumber = invoiceQuery.docs.isNotEmpty
          ? (invoiceQuery.docs.first.data()['invoice_number'] ?? '')
          : '';

      // Create User in Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
              email: email,
              password: passwordController.text.trim());

      // Save User Details in Firestore (users_id collection) with linked records
      await FirebaseFirestore.instance
          .collection('users_id')
          .doc(userCredential.user!.uid)
          .set({
        'uid': userCredential.user!.uid,
        'name': nameController.text.trim(),
        'email': email,
        'phone': phoneController.text.trim(),
        'role': 'customer',
        'customer_id': customerId,
        'productId': productId,
        'invoiceNumber': invoiceNumber,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          FadePageRoute(page: const MainNavigation()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Registration Failed")),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppLayout(
      showBack: true,
      title: "Create Account",
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FadeInWidget(
              delay: 100,
              child: Text(
                "Join Service Management",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 30),

            // Name Field
            FadeInWidget(
              delay: 200,
              child: _inputField(
                label: "Full Name",
                controller: nameController,
                icon: Icons.person_outline,
              ),
            ),

            // Email Field
            FadeInWidget(
              delay: 300,
              child: _inputField(
                label: "Email Address",
                controller: emailController,
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
            ),

            // Phone Field
            FadeInWidget(
              delay: 400,
              child: _inputField(
                label: "Phone Number",
                controller: phoneController,
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
            ),

            // Password Field
            FadeInWidget(
              delay: 500,
              child: _inputField(
                label: "Password",
                controller: passwordController,
                icon: Icons.lock_outline,
                isPassword: true,
                obscureText: obscurePassword,
                onTogglePassword: () {
                  setState(() {
                    obscurePassword = !obscurePassword;
                  });
                },
              ),
            ),

            // Confirm Password Field
            FadeInWidget(
              delay: 600,
              child: _inputField(
                label: "Confirm Password",
                controller: confirmPasswordController,
                icon: Icons.lock_reset_outlined,
                isPassword: true,
                obscureText: obscurePassword,
                onTogglePassword: () {
                  setState(() {
                    obscurePassword = !obscurePassword;
                  });
                },
              ),
            ),

            const SizedBox(height: 30),

            // Register Button
            FadeInWidget(
              delay: 700,
              child: GestureDetector(
                onTap: isLoading ? null : _register,
                child: Container(
                  width: double.infinity,
                  height: 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [Color(0xff0D47A1), Color(0xff1976D2)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff0D47A1).withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "CREATE ACCOUNT",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              letterSpacing: 1.2,
                            ),
                          ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),

            // Login Link
            FadeInWidget(
              delay: 800,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Already have an account? ",
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      "Login",
                      style: TextStyle(
                        color: Color(0xff1976D2),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onTogglePassword,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xff1976D2)),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey,
                  ),
                  onPressed: onTogglePassword,
                )
              : null,
        ),
      ),
    );
  }
}
