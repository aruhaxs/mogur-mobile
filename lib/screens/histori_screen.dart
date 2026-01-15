import 'dart:io';
// PENTING: hide Border agar tidak bentrok dengan Flutter
import 'package:excel/excel.dart' hide Border; 
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';

class HistoriScreen extends StatefulWidget {
  const HistoriScreen({super.key});

  @override
  State<HistoriScreen> createState() => _HistoriScreenState();
}

class _HistoriScreenState extends State<HistoriScreen> {
  bool _isLoading = true;
  
  List<Map<String, dynamic>> _masterList = [];
  List<Map<String, dynamic>> _filteredList = [];
  List<Map<String, dynamic>> _paginatedList = [];

  DateTimeRange? _selectedDateRange;
  int _currentPage = 0;
  final int _itemsPerPage = 20;

  final double _totalJarak = 120.0;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getRiwayat();
    
    setState(() {
      _masterList = data;
      _filteredList = List.from(_masterList);
      _currentPage = 0;
      _updatePagination();
      _isLoading = false;
    });
  }

  void _updatePagination() {
    final int startIndex = _currentPage * _itemsPerPage;
    final int endIndex = startIndex + _itemsPerPage;
    
    setState(() {
      if (startIndex >= _filteredList.length) {
        _paginatedList = [];
      } else {
        _paginatedList = _filteredList.sublist(
          startIndex, 
          endIndex > _filteredList.length ? _filteredList.length : endIndex
        );
      }
    });
  }

  void _nextPage() {
    if ((_currentPage + 1) * _itemsPerPage < _filteredList.length) {
      setState(() {
        _currentPage++;
        _updatePagination();
      });
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
        _updatePagination();
      });
    }
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      initialDateRange: _selectedDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0077C2),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0077C2),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _applyFilter();
      });
    }
  }

  void _applyFilter() {
    if (_selectedDateRange == null) {
      _filteredList = List.from(_masterList);
    } else {
      _filteredList = _masterList.where((item) {
        DateTime? itemDate;
        try {
          itemDate = DateTime.parse(item['datetime']);
        } catch (e) {
          return false;
        }
        return itemDate.isAfter(_selectedDateRange!.start.subtract(const Duration(days: 1))) && 
               itemDate.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }
    _currentPage = 0;
    _updatePagination();
  }

  void _resetFilter() {
    setState(() {
      _selectedDateRange = null;
      _applyFilter();
    });
  }

  // --- LOGIKA EKSPOR EXCEL (DIPERBARUI) ---
  Future<void> _exportToExcel() async {
    if (_filteredList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tidak ada data untuk diekspor")),
      );
      return;
    }

    var excel = Excel.createExcel();
    String sheetName = "Laporan Kolam";
    Sheet sheet = excel[sheetName];
    excel.delete('Sheet1'); 

    // 1. HEADER (Sudah dihapus Status & Raw Jarak)
    List<String> headers = [
      "No",
      "Tanggal & Waktu",
      "Tinggi Air (cm)",
      "Suhu (°C)",
      "Kekeruhan (NTU)"
    ];
    sheet.appendRow(headers.map((e) => TextCellValue(e)).toList());

    // 2. ISI DATA
    for (int i = 0; i < _filteredList.length; i++) {
      var item = _filteredList[i];
      
      double rawJarak = (item['jarak'] ?? 0).toDouble();
      double suhu = (item['suhu'] ?? 0).toDouble();
      double kekeruhan = (item['kekeruhan'] ?? 0).toDouble();
      String tgl = item['datetime'] ?? "-";

      // Hitung Tinggi Air
      double tinggiAir = _totalJarak - rawJarak;
      if (tinggiAir < 0) tinggiAir = 0;
      if (tinggiAir > 100) tinggiAir = 100;

      // Masukkan Data ke Baris Excel
      List<CellValue> row = [
        IntCellValue(i + 1),
        TextCellValue(tgl),
        DoubleCellValue(tinggiAir),
        DoubleCellValue(suhu),
        DoubleCellValue(kekeruhan),
      ];
      sheet.appendRow(row);
    }

    try {
      var fileBytes = excel.save();
      Directory tempDir = await getTemporaryDirectory();
      
      String timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      String fileName = "Laporan_Mogur_$timestamp.xlsx";
      File file = File("${tempDir.path}/$fileName");
      
      await file.writeAsBytes(fileBytes!);

      await Share.shareXFiles([XFile(file.path)], text: 'Laporan Monitoring Kolam Mogur');
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal ekspor: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          "Riwayat & Laporan",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0077C2),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            tooltip: "Unduh Excel",
            onPressed: () => _exportToExcel(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tanggal
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDateRange,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18, color: Color(0xFF0077C2)),
                          const SizedBox(width: 10),
                          Text(
                            _selectedDateRange == null
                                ? "Filter Tanggal"
                                : "${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}",
                            style: TextStyle(
                              color: _selectedDateRange == null ? Colors.grey : Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_selectedDateRange != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: _resetFilter,
                  ),
              ],
            ),
          ),

          // List Data
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredList.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _paginatedList.length,
                        itemBuilder: (context, index) {
                          final item = _paginatedList[index];
                          return _buildHistoryCard(item);
                        },
                      ),
          ),

          // Paginasi
          if (!_isLoading && _filteredList.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _currentPage > 0 ? _prevPage : null,
                    icon: Icon(Icons.arrow_back_ios, size: 18, color: _currentPage > 0 ? const Color(0xFF0077C2) : Colors.grey),
                  ),
                  Text(
                    "Halaman ${_currentPage + 1} dari ${(_filteredList.length / _itemsPerPage).ceil()}",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: (_currentPage + 1) * _itemsPerPage < _filteredList.length ? _nextPage : null,
                    icon: Icon(Icons.arrow_forward_ios, size: 18, color: (_currentPage + 1) * _itemsPerPage < _filteredList.length ? const Color(0xFF0077C2) : Colors.grey),
                  ),
                ],
              ),
            )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            "Tidak ada data ditemukan",
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    String dateStr = item['datetime'] ?? "-";
    double suhu = (item['suhu'] ?? 0).toDouble();
    double kekeruhan = (item['kekeruhan'] ?? 0).toDouble();
    double rawJarak = (item['jarak'] ?? 0).toDouble();

    double tinggiAir = _totalJarak - rawJarak;
    if (tinggiAir < 0) tinggiAir = 0;
    if (tinggiAir > 100) tinggiAir = 100;

    DateTime? dt;
    try {
      dt = DateTime.parse(dateStr);
      dateStr = DateFormat("dd MMM yyyy, HH:mm").format(dt);
    } catch (e) {
      // ignore
    }

    Color colorAir = (tinggiAir < 50) ? Colors.red : (tinggiAir > 100 ? Colors.purple : Colors.blue);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      dateStr,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2D3436)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildParamItem("Tinggi Air", "${tinggiAir.toStringAsFixed(1)} cm", Icons.waves, colorAir),
                _buildVerticalDivider(),
                _buildParamItem("Suhu", "${suhu.toStringAsFixed(1)} °C", Icons.thermostat, Colors.teal),
                _buildVerticalDivider(),
                _buildParamItem("Kekeruhan", "${kekeruhan.toStringAsFixed(0)} NTU", Icons.water_drop, Colors.lightBlue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParamItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(width: 1, height: 30, color: Colors.grey[200]);
  }
}