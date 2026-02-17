import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // PENTING: URL INI TIDAK BOLEH ADA GARIS MIRING (/) DI BELAKANG
  static const String _baseUrl =
      "https://mogur-4d3d4-default-rtdb.asia-southeast1.firebasedatabase.app";

  // --- PERBAIKAN DI SINI (Hapus parameter limitToFirst) ---
  static Future<bool> checkAnyUserExists() async {
    try {
      // PERBAIKAN: Hapus "?limitToFirst=1" agar tidak error orderBy
      // Kita ambil langsung users.json
      final url = Uri.parse("$_baseUrl/users.json");
      
      print("🔍 Cek Database: $url");

      final response = await http.get(url);
      
      print("📩 Hasil: ${response.body}");

      if (response.statusCode == 200) {
        // Jika datanya "null", berarti kosong (Belum ada user)
        if (response.body == "null") return false;

        // Jika ada isinya (Map JSON), berarti SUDAH ADA user
        final data = json.decode(response.body);
        if (data is Map && data.isNotEmpty) {
          return true; // USER DITEMUKAN -> KE LOGIN
        }
      }
      return false; 
    } catch (e) {
      print("Error Cek User: $e");
      return false;
    }
  }

  // ... (SISA KODE KE BAWAH TETAP SAMA SEPERTI SEBELUMNYA) ...
  
  static Future<Map<String, dynamic>?> getKondisiKolam() async {
    try {
      final url = Uri.parse("$_baseUrl/kondisi.json");
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getStatusPompa() async {
    try {
      final url = Uri.parse("$_baseUrl/pompa.json");
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<void> updatePompaStatus({
    String? pompa,
    String? status,
    int? speed,
    String? mode,
  }) async {
    try {
      final url = Uri.parse("$_baseUrl/pompa.json");
      Map<String, dynamic> data = {};
      if (mode != null) data['mode'] = mode;
      if (pompa != null && status != null) data[pompa] = status;
      if (pompa != null && speed != null) data['speed_$pompa'] = speed;
      await http.patch(url, body: json.encode(data));
    } catch (e) {}
  }

  static Future<Map<String, dynamic>?> getParameter() async {
    try {
      final url = Uri.parse("$_baseUrl/parameter.json");
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<bool> saveParameter(Map<String, dynamic> data) async {
    try {
      final url = Uri.parse("$_baseUrl/parameter.json");
      final response = await http.put(url, body: json.encode(data));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getRiwayat() async {
    try {
      final url = Uri.parse("$_baseUrl/histori.json");
      final response = await http.get(url);

      if (response.statusCode == 200 && response.body != "null") {
        final Map<String, dynamic> rawData = json.decode(response.body);
        List<Map<String, dynamic>> listData = [];

        rawData.forEach((key, value) {
          listData.add({
            "id": key,
            "datetime": value['datetime'],
            "jarak": value['jarak'],
            "kekeruhan": value['kekeruhan'],
            "suhu": value['suhu'],
            "status": value['status'] ?? "-",
          });
        });

        listData.sort((a, b) => b['datetime'].compareTo(a['datetime']));
        return listData;
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}