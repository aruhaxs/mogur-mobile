import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl =
      "https://mogur-4d3d4-default-rtdb.asia-southeast1.firebasedatabase.app";

  // --- COLLECTION: KONDISI (SENSOR) ---
  static Future<Map<String, dynamic>?> getKondisiKolam() async {
    try {
      final url = Uri.parse("$_baseUrl/kondisi.json");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print("Error API (Kondisi): $e");
      return null;
    }
  }

  // --- COLLECTION: POMPA (STATUS & KONTROL) ---
  static Future<Map<String, dynamic>?> getStatusPompa() async {
    try {
      final url = Uri.parse("$_baseUrl/pompa.json");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print("Error API (Pompa): $e");
      return null;
    }
  }

  static Future<void> updatePompaStatus({
    String? pompa,   // 'pompa1' atau 'pompa2'
    String? status,  // 'ON' atau 'OFF'
    int? speed,      // 0 - 1023
    String? mode,    // 'AUTO' atau 'MANUAL'
  }) async {
    try {
      final url = Uri.parse("$_baseUrl/pompa.json");
      Map<String, dynamic> data = {};

      if (mode != null) data['mode'] = mode;
      if (pompa != null && status != null) data[pompa] = status;
      if (pompa != null && speed != null) data['speed_$pompa'] = speed;

      await http.patch(url, body: json.encode(data));
    } catch (e) {
      print("Error Update Pompa: $e");
    }
  }

  // --- COLLECTION: PARAMETER ---
  static Future<Map<String, dynamic>?> getParameter() async {
    try {
      final url = Uri.parse("$_baseUrl/parameter.json");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print("Error Get Parameter: $e");
      return null;
    }
  }

  static Future<bool> saveParameter(Map<String, dynamic> data) async {
    try {
      final url = Uri.parse("$_baseUrl/parameter.json");
      final response = await http.put(
        url,
        body: json.encode(data),
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error Save Parameter: $e");
      return false;
    }
  }

  // --- COLLECTION: HISTORI ---
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
      print("Error Histori: $e");
      return [];
    }
  }
}