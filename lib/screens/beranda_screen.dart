import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class BerandaScreen extends StatefulWidget {
  const BerandaScreen({super.key});

  @override
  State<BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<BerandaScreen> {
  final StreamController<Map<String, dynamic>> _dataStreamController =
      StreamController<Map<String, dynamic>>();
  Timer? _timer;

  // --- VARIABEL DATA KOLAM (Tidak Final agar bisa diedit) ---
  DateTime _tanggalTebarBibit = DateTime.now();
  String _jenisIkan = "Gurame Soang"; // Default
  int _jumlahIkan = 500; // Default
  final String _spesifikKolam = "6m x 4m x 1m"; // Ukuran kolam tetap

  // Opsi Dropdown untuk Jenis Ikan
  final List<String> _opsiIkan = [
    "Gurame Soang",
    "Gurame Batu",
    "Gurame Bastar",
    "Gurame Kapas"
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedData(); // Load semua data yang tersimpan
    _fetchData();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchData();
    });
  }

  // --- LOGIKA SIMPAN & LOAD DATA (PERSISTENCE) ---
  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Load Tanggal
      final String? savedDate = prefs.getString('tanggal_tebar');
      if (savedDate != null) {
        _tanggalTebarBibit = DateTime.parse(savedDate);
      }
      // Load Jenis Ikan
      _jenisIkan = prefs.getString('jenis_ikan') ?? "Gurame Soang";
      // Load Jumlah Ikan
      _jumlahIkan = prefs.getInt('jumlah_ikan') ?? 500;
    });
  }

  Future<void> _saveAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tanggal_tebar', _tanggalTebarBibit.toIso8601String());
    await prefs.setString('jenis_ikan', _jenisIkan);
    await prefs.setInt('jumlah_ikan', _jumlahIkan);
  }

  // --- LOGIKA FORM EDIT (DIALOG) ---
  void _showEditDialog() {
    // Variabel sementara untuk menampung inputan user sebelum disimpan
    String tempJenis = _jenisIkan;
    int tempJumlah = _jumlahIkan;
    DateTime tempTanggal = _tanggalTebarBibit;
    
    // Controller untuk input angka
    TextEditingController jumlahController = TextEditingController(text: _jumlahIkan.toString());

    showDialog(
      context: context,
      builder: (context) {
        // Menggunakan StatefulBuilder agar tampilan dalam dialog bisa update (utk tanggal)
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Edit Data Kolam", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0077C2))),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. INPUT JENIS IKAN (Dropdown)
                    const Text("Jenis Ikan", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    DropdownButtonFormField<String>(
                      value: _opsiIkan.contains(tempJenis) ? tempJenis : _opsiIkan[0],
                      items: _opsiIkan.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setDialogState(() {
                          tempJenis = newValue!;
                        });
                      },
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 2. INPUT JUMLAH IKAN
                    const Text("Jumlah Ikan (Ekor)", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    TextField(
                      controller: jumlahController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: "Masukkan jumlah",
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onChanged: (val) {
                        if (val.isNotEmpty) {
                          tempJumlah = int.tryParse(val) ?? 0;
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // 3. INPUT TANGGAL (Date Picker Trigger)
                    const Text("Tanggal Tebar Bibit", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: tempTanggal,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null && picked != tempTanggal) {
                          setDialogState(() {
                            tempTanggal = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('dd MMMM yyyy').format(tempTanggal),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Icon(Icons.calendar_month, color: Color(0xFF0077C2)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Batal", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0077C2),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    // Simpan data ke variabel utama & SharedPrefs
                    setState(() {
                      _jenisIkan = tempJenis;
                      _jumlahIkan = tempJumlah;
                      _tanggalTebarBibit = tempTanggal;
                    });
                    _saveAllData(); // Simpan permanen
                    Navigator.pop(context);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Informasi kolam berhasil diperbarui!")),
                    );
                  },
                  child: const Text("Simpan"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- LOGIKA MENGHITUNG UMUR ---
  String _hitungUmurIkan() {
    final now = DateTime.now();
    final difference = now.difference(_tanggalTebarBibit).inDays;
    
    if (difference < 30) {
      return "$difference Hari";
    } else {
      final bulan = (difference / 30).floor();
      final hariSisa = difference % 30;
      if (hariSisa == 0) return "$bulan Bulan";
      return "$bulan Bulan $hariSisa Hari";
    }
  }

  Future<void> _fetchData() async {
    final data = await ApiService.getKondisiKolam();
    if (data != null && !_dataStreamController.isClosed) {
      _dataStreamController.add(data);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _dataStreamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Dashboard Kolam",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0077C2),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: () {},
          )
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  // --- KARTU INFORMASI KOLAM (NEW) ---
                  _buildInfoKolamCard(),
                  
                  const SizedBox(height: 20),

                  // --- STREAM DATA SENSOR ---
                  StreamBuilder<Map<String, dynamic>>(
                    stream: _dataStreamController.stream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Padding(
                          padding: EdgeInsets.only(top: 50),
                          child: CircularProgressIndicator(),
                        );
                      }

                      final data = snapshot.data ?? {};
                      final double suhu = (data['suhu'] ?? 0).toDouble();
                      final double kekeruhan = (data['kekeruhan'] ?? 0).toDouble();
                      final double rawJarakSensor = (data['jarak'] ?? 0).toDouble();

                      // Rumus: 120 - bacaan sensor
                      double ketinggianAir = 120.0 - rawJarakSensor;

                      // Logic Status
                      bool isBanjir = ketinggianAir > 100;
                      bool isSurut = ketinggianAir < 50;
                      bool isKeruh = kekeruhan > 200;
                      bool isPanas = suhu > 32;

                      return Column(
                        children: [
                          // 1. Status Utama
                          _buildMainStatusAlert(isBanjir, isSurut, isPanas, isKeruh),
                          
                          const SizedBox(height: 20),
                          
                          // 2. Sensor Cards (Memanjang ke bawah)
                          _buildWideSensorCard(
                            title: "Ketinggian Air",
                            value: "${ketinggianAir.toStringAsFixed(1)} cm",
                            icon: isBanjir ? Icons.warning_amber : Icons.waves,
                            color: isBanjir ? Colors.purple : (isSurut ? Colors.red : Colors.blue),
                            status: isBanjir ? "Banjir / Meluap" : (isSurut ? "Perlu Diisi" : "Optimal"),
                            desc: "Kapasitas ${(ketinggianAir).toInt()}%",
                          ),
                          
                          const SizedBox(height: 12),

                          _buildWideSensorCard(
                            title: "Suhu Air",
                            value: "${suhu.toStringAsFixed(1)} °C",
                            icon: Icons.thermostat,
                            color: isPanas ? Colors.orange : Colors.teal,
                            status: isPanas ? "Terlalu Panas" : "Normal",
                            desc: "Rentang ideal: 25 - 30 °C",
                          ),

                          const SizedBox(height: 12),

                          _buildWideSensorCard(
                            title: "Kekeruhan",
                            value: "${kekeruhan.toStringAsFixed(1)} NTU",
                            icon: Icons.water_drop,
                            color: isKeruh ? Colors.brown : Colors.lightBlue,
                            status: isKeruh ? "Air Kotor" : "Jernih",
                            desc: isKeruh ? "Segera kuras filter" : "Kualitas air terjaga",
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- WIDGET HEADER ---
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 25, top: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0077C2),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const CircleAvatar(
              radius: 26,
              backgroundImage: AssetImage('assets/logo_mogur.png'),
            ),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Selamat Datang,",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              Text(
                DateFormat('EEEE, d MMM yyyy').format(DateTime.now()),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- WIDGET INFORMASI KOLAM (INTERAKTIF) ---
  Widget _buildInfoKolamCard() {
    return GestureDetector(
      onLongPress: _showEditDialog, // MENGGUNAKAN FUNGSI EDIT DIALOG YANG BARU
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0077C2), Color(0xFF005A9E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0077C2).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "INFORMASI KOLAM",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(Icons.edit, color: Colors.white.withOpacity(0.5), size: 16),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                // Info Jenis & Jumlah
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(Icons.set_meal, _jenisIkan),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.numbers, "$_jumlahIkan Ekor"),
                      const SizedBox(height: 8),
                      _buildInfoRow(Icons.pool, _spesifikKolam),
                    ],
                  ),
                ),
                Container(width: 1, height: 60, color: Colors.white24),
                const SizedBox(width: 20),
                // Info Umur Ikan (Highlight)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "Umur Ikan",
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _hitungUmurIkan(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Sejak: ${DateFormat('dd MMM yy').format(_tanggalTebarBibit)}",
                      style: const TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                "(Tahan kartu ini untuk ubah data ikan)",
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10, fontStyle: FontStyle.italic),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  // --- WIDGET ALERT STATUS ---
  Widget _buildMainStatusAlert(bool banjir, bool surut, bool panas, bool keruh) {
    if (!banjir && !surut && !panas && !keruh) {
      return Container(); // Sembunyikan jika semua aman
    }

    String msg = "";
    if (banjir) msg = "Air Meluap!";
    else if (surut) msg = "Air Surut!";
    else if (panas) msg = "Suhu Tinggi!";
    else if (keruh) msg = "Air Keruh!";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "PERHATIAN: $msg Cek kondisi kolam.",
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          )
        ],
      ),
    );
  }

  // --- WIDGET SENSOR MEMANJANG (DESIGN BARU) ---
  Widget _buildWideSensorCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String status,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon Box
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          
          // Title & Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),

          // Value & Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D3436),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}