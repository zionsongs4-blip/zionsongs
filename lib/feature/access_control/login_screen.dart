import 'package:flutter/material.dart';

import 'google_sign_in_service.dart';
import 'auth_repository.dart';
import '../home/home_page/home_page.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool loading = false;
  String? error;

  Future<void> _login() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final user = await GoogleSignInService.signIn();

      if (user == null) {
        setState(() {
          error = 'Sign-in cancelled';
        });
        return;
      }

      final approved =
          await AuthRepository.isUserApproved(user);

      if (!approved) {
        await GoogleSignInService.signOut();

        setState(() {
          error =
              'Access denied. Your account is not registered or approved.';
        });
        return;
      }

      Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (_) => const HomePage(),
  ),
);

    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Zion Songs',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: loading ? null : _login,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text(
                        'Sign in with Google',
                      ),
              ),

              if (error != null) ...[
                const SizedBox(height: 20),
                Text(
                  error!,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}