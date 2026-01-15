import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl =
      "https://mogur-4d3d4-default-rtdb.asia-southeast1.firebasedatabase.app";

  // --- COLLECTION: KONDISI ---
  static Future<Map<String, dynamic>?> getKondisiKolam() async {
    try {
      final url = Uri.parse("$_baseUrl/kondisi.json");
      
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data as Map<String, dynamic>;
      } else {
        print("Error API (Kondisi): ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error Connection (Kondisi): $e");
      return null;
    }
  }

  // --- COLLECTION: PARAMETER (GET) ---
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

  // --- COLLECTION: PARAMETER (PUT/SAVE) ---
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
  static Future<List<Map<String, dynamic>>> getRiwayat() async {
    try {
      final url = Uri.parse("$_baseUrl/histori.json");
      final response = await http.get(url);

      if (response.statusCode == 200 && response.body != "null") {
        final Map<String, dynamic> rawData = json.decode(response.body);
        
        // Konversi Map ke List agar bisa di-sort
        List<Map<String, dynamic>> listData = [];
        
        rawData.forEach((key, value) {
          listData.add({
            "id": key,
            "datetime": value['datetime'],
            "jarak": value['jarak'],         // Raw sensor data
            "kekeruhan": value['kekeruhan'],
            "suhu": value['suhu'],
          });
        });

        // Urutkan dari yang paling baru (Descending)
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