import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class StatistikScreen extends StatefulWidget {
  const StatistikScreen({super.key});

  @override
  State<StatistikScreen> createState() => _StatistikScreenState();
}

class _StatistikScreenState extends State<StatistikScreen> {
  // 0 = 24 Jam, 1 = 7 Hari, 2 = 30 Hari
  int _selectedFilterIndex = 0; 
  bool _isLoading = true;
  List<Map<String, dynamic>> _allData = [];

  // Konstanta Fisik
  final double _totalJarak = 120.0;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final data = await ApiService.getRiwayat();
    setState(() {
      _allData = data;
      _isLoading = false;
    });
  }

  // --- LOGIKA FILTER DATA ---
  List<Map<String, dynamic>> _getFilteredData() {
    final now = DateTime.now();
    Duration cutOffDuration;

    switch (_selectedFilterIndex) {
      case 0: cutOffDuration = const Duration(hours: 24); break;
      case 1: cutOffDuration = const Duration(days: 7); break;
      case 2: cutOffDuration = const Duration(days: 30); break;
      default: cutOffDuration = const Duration(hours: 24);
    }

    final cutOffTime = now.subtract(cutOffDuration);

    // 1. Filter Berdasarkan Waktu
    var filtered = _allData.where((item) {
      try {
        DateTime dt = DateTime.parse(item['datetime']);
        return dt.isAfter(cutOffTime);
      } catch (e) {
        return false;
      }
    }).toList();

    // 2. Urutkan: Terlama -> Terbaru (Agar grafik jalan dari kiri ke kanan)
    filtered.sort((a, b) => a['datetime'].compareTo(b['datetime']));

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    // Siapkan data yang sudah difilter
    final data = _getFilteredData();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Statistik Kolam", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0077C2),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchData();
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 1. Tombol Filter (24 Jam, 7 Hari, 30 Hari)
                  _buildFilterButtons(),
                  const SizedBox(height: 20),

                  if (data.isEmpty)
                    const SizedBox(
                      height: 300,
                      child: Center(child: Text("Tidak ada data dalam rentang waktu ini.")),
                    )
                  else
                    Column(
                      children: [
                        // 2. Grafik Suhu
                        _buildChartCard(
                          title: "GRAFIK SUHU",
                          unit: "°C",
                          dataList: data,
                          valueKey: 'suhu', // Key di database
                          lineColor: Colors.orange,
                          isWaterLevel: false,
                        ),

                        // 3. Grafik Kekeruhan
                        _buildChartCard(
                          title: "GRAFIK KEKERUHAN",
                          unit: "NTU",
                          dataList: data,
                          valueKey: 'kekeruhan',
                          lineColor: Colors.brown,
                          isWaterLevel: false,
                        ),

                        // 4. Grafik Tinggi Air (Konversi)
                        _buildChartCard(
                          title: "GRAFIK TINGGI AIR",
                          unit: "cm",
                          dataList: data,
                          valueKey: 'jarak', // Ambil raw jarak
                          lineColor: Colors.blue,
                          isWaterLevel: true, // Aktifkan mode konversi (120 - jarak)
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildFilterButtons() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          _filterBtn("24 JAM", 0),
          _filterBtn("7 HARI", 1),
          _filterBtn("30 HARI", 2),
        ],
      ),
    );
  }

  Widget _filterBtn(String label, int index) {
    bool isSelected = _selectedFilterIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilterIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  // --- WIDGET CHART REUSABLE ---
  Widget _buildChartCard({
    required String title,
    required String unit,
    required List<Map<String, dynamic>> dataList,
    required String valueKey,
    required Color lineColor,
    required bool isWaterLevel,
  }) {
    // 1. Persiapkan Data Points (FlSpot) & Statistik
    List<FlSpot> spots = [];
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;
    double sumVal = 0;

    for (int i = 0; i < dataList.length; i++) {
      double rawVal = (dataList[i][valueKey] ?? 0).toDouble();
      double finalVal = rawVal;

      // === RUMUS KONVERSI TINGGI AIR ===
      if (isWaterLevel) {
        finalVal = _totalJarak - rawVal; // 120 - Jarak
        if (finalVal < 0) finalVal = 0; // Proteksi minus
      }

      // Hitung Min/Max/Avg
      if (finalVal < minVal) minVal = finalVal;
      if (finalVal > maxVal) maxVal = finalVal;
      sumVal += finalVal;

      // Tambahkan ke titik grafik (X = index, Y = nilai)
      spots.add(FlSpot(i.toDouble(), finalVal));
    }

    double avgVal = dataList.isNotEmpty ? sumVal / dataList.length : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Judul
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text("Satuan ($unit)", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
              Icon(Icons.show_chart, color: lineColor),
            ],
          ),
          const SizedBox(height: 20),

          // AREA GRAFIK
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true, 
                  drawVerticalLine: true,
                  getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
                  getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: (spots.length / 5).ceilToDouble(), // Agar label tidak numpuk
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < dataList.length) {
                          DateTime dt = DateTime.parse(dataList[index]['datetime']);
                          // Jika filter 24 Jam -> Tampilkan Jam (14:00)
                          // Jika filter Hari -> Tampilkan Tanggal (10 Jan)
                          String label = _selectedFilterIndex == 0 
                              ? DateFormat('HH:mm').format(dt) 
                              : DateFormat('d MMM').format(dt);
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.withOpacity(0.2))),
                minX: 0,
                maxX: (spots.length - 1).toDouble(),
                minY: (minVal - 5) < 0 ? 0 : (minVal - 5), // Beri ruang bawah
                maxY: maxVal + 5, // Beri ruang atas
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true, // Garis melengkung halus
                    color: lineColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false), // Sembunyikan titik agar bersih
                    belowBarData: BarAreaData(
                      show: true,
                      color: lineColor.withOpacity(0.1), // Arsir warna di bawah garis
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const Divider(height: 30),

          // RINGKASAN DATA (Rata-rata, Min, Max)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem("Rata-rata", avgVal, unit),
              _buildSummaryItem("Minimum", minVal, unit),
              _buildSummaryItem("Maksimum", maxVal, unit),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double val, String unit) {
    // Format angka: Jika bulat (100.0) -> 100, jika koma -> 100.5
    String valStr = (val == double.infinity || val == double.negativeInfinity) 
        ? "-" 
        : val.toStringAsFixed(1);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        const SizedBox(height: 4),
        Text(
          "$valStr $unit",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }
}