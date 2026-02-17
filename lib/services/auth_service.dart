import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // URL DATABASE (SAMA DENGAN API SERVICE - TANPA GARIS MIRING DI AKHIR)
  static const String _baseUrl =
      "https://mogur-4d3d4-default-rtdb.asia-southeast1.firebasedatabase.app";

  // --- 1. REGISTER LENGKAP ---
  static Future<String?> register({
    required String nama,
    required String email,
    required String phone,
    required String password,
  }) async {
    UserCredential? userCredential;
    try {
      // A. Buat Akun Auth
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // B. Simpan ke Realtime Database
      String uid = userCredential.user!.uid;
      final url = Uri.parse("$_baseUrl/users/$uid.json");

      final response = await http.put(
        url,
        body: json.encode({
          "nama": nama,
          "email": email,
          "phone": phone,
          "role": "owner",
          "created_at": DateTime.now().toIso8601String(),
        }),
      );

      // Jika Gagal Simpan DB -> Hapus Akun Auth
      if (response.statusCode != 200) {
        await userCredential.user?.delete();
        return "Gagal menyimpan ke database. Coba lagi.";
      }

      // C. Kirim Verifikasi Email
      if (userCredential.user != null && !userCredential.user!.emailVerified) {
        await userCredential.user!.sendEmailVerification();
      }

      // D. Logout
      await _auth.signOut();

      return null; // Sukses
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') return "Email sudah terdaftar.";
      if (e.code == 'weak-password') return "Password terlalu lemah.";
      return e.message;
    } catch (e) {
      if (userCredential?.user != null) await userCredential!.user!.delete();
      return "Error: $e";
    }
  }

  // --- 2. LOGIN ---
  static Future<String?> login(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        if (userCredential.user!.emailVerified) {
          return null; // Sukses
        } else {
          await _auth.signOut();
          return "email-not-verified";
        }
      }
      return "Login gagal.";
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        return "Email atau Password salah.";
      }
      return e.message;
    } catch (e) {
      return "Kesalahan koneksi internet.";
    }
  }

  // --- 3. RESET PASSWORD ---
  static Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // --- 4. LOGOUT ---
  static Future<void> logout() async {
    await _auth.signOut();
  }

  static User? get currentUser => _auth.currentUser;
}