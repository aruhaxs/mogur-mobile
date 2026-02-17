import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'main_navigation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  bool _isObscure = true;

  // --- LOGIKA LOGIN ---
  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      String? error = await AuthService.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      setState(() => _isLoading = false);

      if (error == null) {
        // SUKSES LOGIN
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainNavigation()),
        );
      } else if (error == "email-not-verified") {
        // GAGAL: BELUM VERIFIKASI
        if (!mounted) return;
        _showCustomDialog(
          isSuccess: false,
          title: "Email Belum Diverifikasi",
          message: "Silakan cek inbox atau folder spam email Anda dan klik link verifikasi yang telah kami kirim.",
        );
      } else {
        // GAGAL LAINNYA
        if (!mounted) return;
        _showCustomDialog(
          isSuccess: false,
          title: "Login Gagal",
          message: error,
        );
      }
    }
  }

  // --- LOGIKA LUPA SANDI ---
  void _showForgotPasswordDialog() {
    final emailResetController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Reset Kata Sandi", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
              const SizedBox(height: 10),
              const Text("Masukkan email akun Anda. Kami akan mengirimkan link untuk mereset sandi.", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              
              TextField(
                controller: emailResetController,
                decoration: InputDecoration(
                  labelText: "Email",
                  prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF0077C2)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0077C2), width: 1.5)),
                ),
              ),
              const SizedBox(height: 25),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Batal", style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () async {
                      String email = emailResetController.text.trim();
                      if (email.isEmpty) return;
                      
                      Navigator.pop(context); // Tutup dialog input
                      
                      String? error = await AuthService.resetPassword(email);
                      
                      if (!mounted) return;
                      if (error == null) {
                        _showCustomDialog(
                          isSuccess: true,
                          title: "Email Terkirim",
                          message: "Silakan cek email Anda untuk instruksi reset password.",
                        );
                      } else {
                        _showCustomDialog(
                          isSuccess: false,
                          title: "Gagal Mengirim",
                          message: error,
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0077C2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Kirim Link", style: TextStyle(color: Colors.white)),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- CUSTOM DIALOG UNIVERSAL (ERROR / SUKSES) ---
  void _showCustomDialog({required bool isSuccess, required String title, required String message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 5,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ikon (Centang Hijau atau Silang Merah)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    size: 60,
                    color: isSuccess ? Colors.green.shade400 : Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Judul
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isSuccess ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                
                // Pesan
                Text(
                  message,
                  style: const TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                
                // Tombol OK
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSuccess ? Colors.green : Colors.red,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text("OK, Mengerti", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Hero(tag: 'logo', child: Image.asset('assets/logo_mogur.png', height: 120)),
                const SizedBox(height: 20),
                const Text("Selamat Datang", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF0077C2))),
                const SizedBox(height: 8),
                Text("Silakan login untuk memantau kolam", style: TextStyle(fontSize: 14, color: Colors.grey[600])),
                const SizedBox(height: 40),

                // Input Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: "Email",
                    prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF0077C2)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0077C2), width: 1.5)),
                  ),
                  validator: (v) => v!.isEmpty ? "Email tidak boleh kosong" : null,
                ),
                const SizedBox(height: 16),

                // Input Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _isObscure,
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF0077C2)),
                    suffixIcon: IconButton(
                      icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _isObscure = !_isObscure),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0077C2), width: 1.5)),
                  ),
                  validator: (v) => v!.isEmpty ? "Password tidak boleh kosong" : null,
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: const Text("Lupa Kata Sandi?", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0077C2))),
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0077C2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 2,
                      shadowColor: const Color(0xFF0077C2).withOpacity(0.3),
                    ),
                    child: _isLoading 
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                      : const Text("MASUK APLIKASI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                Center(child: Text("Mogur v1.0.0 © 2026", style: TextStyle(color: Colors.grey[400], fontSize: 12))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}