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

  // --- DATA KOLAM ---
  DateTime _tanggalTebarBibit = DateTime.now();
  String _jenisIkan = "Gurame Soang";
  int _jumlahIkan = 500;
  final String _spesifikKolam = "6m x 4m x 1m";
  final List<String> _opsiIkan = [
    "Gurame Soang", "Gurame Batu", "Gurame Bastar", "Gurame Kapas"
  ];

  // --- DATA KONTROL POMPA ---
  bool _isManualMode = false;
  double _speedPompa1 = 1023;
  double _speedPompa2 = 1023;

  // --- DATA PARAMETER ---
  Map<String, dynamic> _params = {};
  bool _isLoadingParams = true; 

  @override
  void initState() {
    super.initState();
    _loadSavedData();
    _fetchParameters(); 
    _fetchData();
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _fetchData();
    });
  }

  // --- PERSISTENT DATA ---
  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final String? savedDate = prefs.getString('tanggal_tebar');
      if (savedDate != null) _tanggalTebarBibit = DateTime.parse(savedDate);
      _jenisIkan = prefs.getString('jenis_ikan') ?? "Gurame Soang";
      _jumlahIkan = prefs.getInt('jumlah_ikan') ?? 500;
    });
  }

  Future<void> _saveAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tanggal_tebar', _tanggalTebarBibit.toIso8601String());
    await prefs.setString('jenis_ikan', _jenisIkan);
    await prefs.setInt('jumlah_ikan', _jumlahIkan);
  }

  // --- FETCH DATA ---
  Future<void> _fetchParameters() async {
    try {
      final params = await ApiService.getParameter();
      if (mounted) {
        setState(() {
          if (params != null) {
            _params = params;
            _isLoadingParams = false; 
          }
        });
      }
    } catch (e) {
      print("Error params: $e");
    }
  }

  Future<void> _fetchData() async {
    final dataKondisi = await ApiService.getKondisiKolam();
    final dataPompa = await ApiService.getStatusPompa();

    if (!_dataStreamController.isClosed) {
      Map<String, dynamic> combined = {};
      if (dataKondisi != null) combined.addAll(dataKondisi);
      if (dataPompa != null) combined['pompa_data'] = dataPompa;
      _dataStreamController.add(combined);
    }
  }

  // --- KONTROL POMPA ---
  void _toggleManualMode(bool value) {
    setState(() => _isManualMode = value);
    ApiService.updatePompaStatus(mode: value ? 'MANUAL' : 'AUTO');
  }

  void _controlPompa(String pompa, bool isActive) {
    if (!_isManualMode) {
      _showSnack("Aktifkan Mode Manual terlebih dahulu!");
      return;
    }
    ApiService.updatePompaStatus(pompa: pompa, status: isActive ? 'ON' : 'OFF', mode: 'MANUAL');
  }

  void _changeSpeedLocal(String pompa, double val) {
    if (!_isManualMode) return;
    setState(() {
      if (pompa == 'pompa1') _speedPompa1 = val; else _speedPompa2 = val;
    });
  }

  void _sendSpeedToApi(String pompa, double val) {
    ApiService.updatePompaStatus(pompa: pompa, speed: val.toInt(), mode: 'MANUAL');
  }

  // --- HELPER (PARSING AMAN) ---
  double _safeParse(dynamic value, double defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse(value.toString()) ?? defaultValue;
  }

  // --- HELPER UI ---
  void _showTimerDialog(String pompa) {
    if (!_isManualMode) {
      _showSnack("Aktifkan Mode Manual dulu");
      return;
    }
    int selectedSeconds = 10;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Set Timer $pompa"),
        content: StatefulBuilder(
          builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Pompa akan menyala selama:"),
                const SizedBox(height: 10),
                DropdownButton<int>(
                  value: selectedSeconds,
                  items: [10, 30, 60, 300, 600].map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e < 60 ? "$e Detik" : "${e~/60} Menit"),
                  )).toList(),
                  onChanged: (val) => setState(() => selectedSeconds = val!),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _runTimerPompa(pompa, selectedSeconds);
            },
            child: const Text("Mulai"),
          )
        ],
      ),
    );
  }

  void _runTimerPompa(String pompa, int durationSec) {
    _controlPompa(pompa, true);
    _showSnack("$pompa menyala selama $durationSec detik");
    Timer(Duration(seconds: durationSec), () {
      if (mounted) {
        _controlPompa(pompa, false);
        _showSnack("Timer selesai, $pompa dimatikan.");
      }
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 1)));
  }

  void _showEditDialog() {
    String tempJenis = _jenisIkan;
    int tempJumlah = _jumlahIkan;
    DateTime tempTanggal = _tanggalTebarBibit;
    TextEditingController jumlahController = TextEditingController(text: _jumlahIkan.toString());

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Edit Data Kolam", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0077C2))),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Jenis Ikan", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    DropdownButtonFormField<String>(
                      value: _opsiIkan.contains(tempJenis) ? tempJenis : _opsiIkan[0],
                      items: _opsiIkan.map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value));
                      }).toList(),
                      onChanged: (newValue) => setDialogState(() => tempJenis = newValue!),
                    ),
                    const SizedBox(height: 20),
                    const Text("Jumlah Ikan (Ekor)", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    TextField(
                      controller: jumlahController,
                      keyboardType: TextInputType.number,
                      onChanged: (val) {
                        if (val.isNotEmpty) tempJumlah = int.tryParse(val) ?? 0;
                      },
                    ),
                    const SizedBox(height: 20),
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
                        if (picked != null) setDialogState(() => tempTanggal = picked);
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
                            Text(DateFormat('dd MMMM yyyy').format(tempTanggal), style: const TextStyle(fontWeight: FontWeight.bold)),
                            const Icon(Icons.calendar_month, color: Color(0xFF0077C2)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0077C2), foregroundColor: Colors.white),
                  onPressed: () {
                    setState(() {
                      _jenisIkan = tempJenis;
                      _jumlahIkan = tempJumlah;
                      _tanggalTebarBibit = tempTanggal;
                    });
                    _saveAllData();
                    Navigator.pop(context);
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

  String _hitungUmurIkan() {
    final now = DateTime.now();
    final difference = now.difference(_tanggalTebarBibit).inDays;
    if (difference < 30) return "$difference Hari";
    final bulan = (difference / 30).floor();
    final hariSisa = difference % 30;
    return hariSisa == 0 ? "$bulan Bulan" : "$bulan Bln $hariSisa Hr";
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
        title: const Text("Dashboard Kolam", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: const Color(0xFF0077C2),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() => _isLoadingParams = true);
              _fetchParameters();
            },
          )
        ],
      ),
      body: _isLoadingParams
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF0077C2)),
                  const SizedBox(height: 15),
                  Text("Menyiapkan Data Kolam...", style: TextStyle(color: Colors.grey[600]))
                ],
              ),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: StreamBuilder<Map<String, dynamic>>(
                      stream: _dataStreamController.stream,
                      builder: (context, snapshot) {
                        
                        double suhu = 0, kekeruhan = 0, rawJarak = 0;
                        Map<String, dynamic> pompaData = {};
                        String infoSistem = "Sinkronisasi sensor...";

                        if (snapshot.hasData) {
                          final d = snapshot.data!;
                          suhu = (d['suhu'] ?? 0).toDouble();
                          kekeruhan = (d['kekeruhan'] ?? 0).toDouble();
                          rawJarak = (d['jarak'] ?? 0).toDouble();
                          
                          if (d['pompa_data'] != null) {
                            pompaData = d['pompa_data'];
                            infoSistem = pompaData['info'] ?? "Normal";
                            
                            String modeRemote = pompaData['mode'] ?? 'AUTO';
                            if (_timer != null && _timer!.tick < 2) { 
                               _isManualMode = modeRemote == 'MANUAL';
                            }
                          }
                        }

                        // --- 1. AMBIL PARAMETER DARI FIREBASE ---
                        // Parameter di Firebase adalah "Batas Jarak Sensor" (bukan tinggi air)
                        // Max: 20 cm (Jarak sensor dekat = Air Penuh)
                        // Min: 40 cm (Jarak sensor jauh = Air Surut)
                        double paramJarakMin = _safeParse(_params['batasjarak']?['min'], 40.0);
                        double paramJarakMax = _safeParse(_params['batasjarak']?['max'], 20.0);
                        
                        double paramSuhuMin = _safeParse(_params['batassuhu']?['min'], 25.0);
                        double paramSuhuMax = _safeParse(_params['batassuhu']?['max'], 30.0);
                        double paramNtuMax = _safeParse(_params['bataskekeruhan']?['max'], 100.0);

                        // --- 2. LOGIKA STATUS (MEMBANDINGKAN DATA MENTAH) ---
                        // "Penuh" jika Jarak Sensor < Batas Max (Misal: 5 < 20)
                        bool isPenuh = rawJarak < paramJarakMax; 
                        // "Surut" jika Jarak Sensor > Batas Min (Misal: 50 > 40)
                        bool isSurut = rawJarak > paramJarakMin; 
                        
                        bool isKeruh = kekeruhan > paramNtuMax;
                        bool isPanas = suhu > paramSuhuMax;
                        bool isDingin = suhu < paramSuhuMin;

                        // --- 3. LOGIKA TAMPILAN VISUAL ---
                        // Konversi ke "Ketinggian Air" untuk User Interface
                        double ketinggianAir = 120.0 - rawJarak;
                        if (ketinggianAir < 0) ketinggianAir = 0;

                        return Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, color: Color(0xFF0077C2)),
                                  const SizedBox(width: 10),
                                  Expanded(child: Text(infoSistem, style: const TextStyle(color: Color(0xFF0077C2), fontWeight: FontWeight.bold))),
                                ],
                              ),
                            ),
                            const SizedBox(height: 15),

                            _buildInfoKolamCard(),
                            const SizedBox(height: 20),
                            
                            _buildMainStatusAlert(isPenuh, isSurut, isPanas, isKeruh),
                            const SizedBox(height: 10),
                            
                            // A. AIR (UPDATE: Memakai Logika Raw Sensor vs Parameter)
                            _buildDetailedSensorCard(
                              title: "Ketinggian Air",
                              value: "${ketinggianAir.toStringAsFixed(0)} cm",
                              unit: "", // Unit disembunyikan agar bersih
                              icon: Icons.waves,
                              // Jika Penuh -> Orange/Merah (Peringatan), Jika Surut -> Orange, Normal -> Biru
                              color: isPenuh ? Colors.orange : (isSurut ? Colors.red : Colors.blue),
                              
                              // LABEL STATUS YANG AKURAT
                              status: isPenuh ? "PENUH" : (isSurut ? "SURUT" : "NORMAL"),
                              
                              // Menampilkan Parameter Asli
                              paramDesc: "Normal: Jarak Sensor ${paramJarakMax.toInt()}cm - ${paramJarakMin.toInt()}cm",
                              progressVal: (ketinggianAir / 120.0).clamp(0.0, 1.0),
                            ),
                            const SizedBox(height: 12),

                            // B. SUHU
                            _buildDetailedSensorCard(
                              title: "Suhu Air",
                              value: "${suhu.toStringAsFixed(1)}",
                              unit: "°C",
                              icon: Icons.thermostat,
                              color: (isPanas || isDingin) ? Colors.red : Colors.teal,
                              status: isPanas ? "PANAS" : (isDingin ? "DINGIN" : "IDEAL"),
                              paramDesc: "Ideal: ${paramSuhuMin.toStringAsFixed(1)} - ${paramSuhuMax.toStringAsFixed(1)} °C",
                              progressVal: (suhu / 40).clamp(0.0, 1.0),
                            ),
                            const SizedBox(height: 12),

                            // C. KEKERUHAN
                            _buildDetailedSensorCard(
                              title: "Kekeruhan (NTU)",
                              value: kekeruhan.toStringAsFixed(1),
                              unit: "NTU",
                              icon: Icons.water_drop,
                              color: isKeruh ? Colors.brown : Colors.lightBlue,
                              status: isKeruh ? "KERUH" : "JERNIH",
                              paramDesc: "Batas Maksimal: ${paramNtuMax.toInt()} NTU",
                              progressVal: (kekeruhan / 200).clamp(0.0, 1.0),
                            ),
                            
                            const SizedBox(height: 30),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Kontrol Pompa", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D3436))),
                                Row(
                                  children: [
                                    Text(_isManualMode ? "Manual" : "Otomatis", 
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _isManualMode ? Colors.orange : Colors.green)),
                                    Switch(
                                      value: _isManualMode,
                                      onChanged: _toggleManualMode,
                                      activeColor: Colors.orange,
                                      inactiveThumbColor: Colors.green,
                                      inactiveTrackColor: Colors.green.withOpacity(0.3),
                                    ),
                                  ],
                                )
                              ],
                            ),
                            const SizedBox(height: 10),

                            _buildPompaCard(
                              title: "Pompa 1 (Filter/Kuras)",
                              pompaKey: "pompa1",
                              statusOn: (pompaData['pompa1'] == "ON"),
                              speedVal: _speedPompa1,
                              color: Colors.orange,
                              desc: "Digunakan saat air keruh atau banjir.",
                            ),
                            
                            const SizedBox(height: 15),

                            _buildPompaCard(
                              title: "Pompa 2 (Isi Air)",
                              pompaKey: "pompa2",
                              statusOn: (pompaData['pompa2'] == "ON"),
                              speedVal: _speedPompa2,
                              color: Colors.blue,
                              desc: "Digunakan saat air surut.",
                            ),
                            const SizedBox(height: 50),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // --- WIDGET HELPER ---
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 25, top: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0077C2),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const CircleAvatar(radius: 26, backgroundImage: AssetImage('assets/logo_mogur.png')),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Selamat Datang,", style: TextStyle(color: Colors.white70, fontSize: 14)),
              Text(DateFormat('EEEE, d MMM yyyy').format(DateTime.now()), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoKolamCard() {
    return GestureDetector(
      onLongPress: _showEditDialog,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0077C2), Color(0xFF005A9E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: const Color(0xFF0077C2).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("INFORMASI KOLAM", style: TextStyle(color: Colors.white70, fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
                Icon(Icons.edit, color: Colors.white.withOpacity(0.5), size: 16),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Umur Ikan", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(_hitungUmurIkan(), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("Sejak: ${DateFormat('dd MMM yy').format(_tanggalTebarBibit)}", style: const TextStyle(color: Colors.white54, fontSize: 10)),
                  ],
                ),
              ],
            ),
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
        Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildMainStatusAlert(bool penuh, bool surut, bool panas, bool keruh) {
    if (!penuh && !surut && !panas && !keruh) return Container();
    String msg = "";
    Color alertColor = Colors.red;
    
    // Logika Alert sesuai status sensor
    if (penuh) { msg = "Air Penuh (Meluap)!"; alertColor = Colors.orange; }
    else if (surut) { msg = "Air Surut!"; alertColor = Colors.red; }
    else if (panas) msg = "Suhu Tinggi!";
    else if (keruh) msg = "Air Keruh!";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: alertColor.withOpacity(0.1), 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: alertColor.withOpacity(0.5))
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: alertColor),
          const SizedBox(width: 12),
          Expanded(child: Text("PERHATIAN: $msg Cek kondisi kolam.", style: TextStyle(color: alertColor, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildDetailedSensorCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required String status,
    required String paramDesc,
    required double progressVal,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
        border: Border.all(color: color.withOpacity(0.1), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
                        const SizedBox(width: 5),
                        if (unit.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Text(unit, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progressVal,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Icon(Icons.tune, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    paramDesc,
                    style: TextStyle(fontSize: 11, color: Colors.grey[700], fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildPompaCard({required String title, required String pompaKey, required bool statusOn, required double speedVal, required Color color, required String desc}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: statusOn ? Border.all(color: color, width: 2) : null,
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: statusOn ? color : Colors.grey.shade100, shape: BoxShape.circle),
                    child: Icon(Icons.settings_input_component, color: statusOn ? Colors.white : Colors.grey),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(statusOn ? "SEDANG MENYALA" : "MATI", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusOn ? color : Colors.grey)),
                    ],
                  ),
                ],
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(value: statusOn, activeColor: color, onChanged: (val) => _controlPompa(pompaKey, val)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(desc, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          
          if (_isManualMode) ...[
            const Divider(height: 20),
            Row(
              children: [
                const Icon(Icons.speed, size: 16, color: Colors.grey),
                const SizedBox(width: 5),
                const Text("Kekuatan:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                Expanded(
                  child: Slider(
                    value: speedVal,
                    min: 0,
                    max: 1023,
                    activeColor: color,
                    inactiveColor: color.withOpacity(0.2),
                    label: "${(speedVal/10.23).round()}%",
                    onChanged: (val) => _changeSpeedLocal(pompaKey, val),
                    onChangeEnd: (val) => _sendSpeedToApi(pompaKey, val),
                  ),
                ),
                Text("${(speedVal/10.23).round()}%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showTimerDialog(pompaKey),
                icon: const Icon(Icons.timer, size: 16),
                label: const Text("Set Timer"),
                style: TextButton.styleFrom(foregroundColor: color),
              ),
            )
          ]
        ],
      ),
    );
  }
}