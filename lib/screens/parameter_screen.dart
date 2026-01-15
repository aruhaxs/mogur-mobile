import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ParameterScreen extends StatefulWidget {
  const ParameterScreen({super.key});

  @override
  State<ParameterScreen> createState() => _ParameterScreenState();
}

class _ParameterScreenState extends State<ParameterScreen> {
  bool _isLoading = false;

  final double _tinggiKolam = 100.0;
  final double _gapSensor = 20.0;
  double get _totalJarak => _tinggiKolam + _gapSensor; 

  final _minSuhuC = TextEditingController();
  final _maxSuhuC = TextEditingController();
  final _idealSuhuC = TextEditingController();

  final _minKeruhC = TextEditingController();
  final _maxKeruhC = TextEditingController();
  final _idealKeruhC = TextEditingController();

  final _minAirC = TextEditingController();
  final _maxAirC = TextEditingController();
  final _idealAirC = TextEditingController();

  final List<Map<String, dynamic>> _templates = [
    {
      "label": "Bibit (1-3 Bulan)",
      "desc": "Air rendah & hangat stabil",
      "suhu": [28, 30],      
      "keruh": [0, 25],      
      "air": [30, 50],       
    },
    {
      "label": "Pembesaran (4-8 Bulan)",
      "desc": "Ketinggian air sedang",
      "suhu": [26, 30],
      "keruh": [0, 50],
      "air": [60, 80],
    },
    {
      "label": "Siap Panen / Indukan",
      "desc": "Ketinggian air maksimal",
      "suhu": [25, 30],
      "keruh": [0, 100],     
      "air": [80, 100],      
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
    
    _minSuhuC.addListener(() => _hitungIdeal(_minSuhuC, _maxSuhuC, _idealSuhuC));
    _maxSuhuC.addListener(() => _hitungIdeal(_minSuhuC, _maxSuhuC, _idealSuhuC));
    
    _minKeruhC.addListener(() => _hitungIdeal(_minKeruhC, _maxKeruhC, _idealKeruhC));
    _maxKeruhC.addListener(() => _hitungIdeal(_minKeruhC, _maxKeruhC, _idealKeruhC));
    
    _minAirC.addListener(() => _hitungIdeal(_minAirC, _maxAirC, _idealAirC));
    _maxAirC.addListener(() => _hitungIdeal(_minAirC, _maxAirC, _idealAirC));
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await ApiService.getParameter();
    
    if (data != null) {
      _minSuhuC.text = data['batassuhu']['min'].toString();
      _maxSuhuC.text = data['batassuhu']['max'].toString();
      
      _minKeruhC.text = data['bataskekeruhan']['min'].toString();
      _maxKeruhC.text = data['bataskekeruhan']['max'].toString();
      
      double dbJarakMax = double.tryParse(data['batasjarak']['max'].toString()) ?? 0;
      double dbJarakMin = double.tryParse(data['batasjarak']['min'].toString()) ?? 0;

      double uiMaxAir = _totalJarak - dbJarakMax; 
      double uiMinAir = _totalJarak - dbJarakMin;

      _minAirC.text = uiMinAir.toStringAsFixed(0); 
      _maxAirC.text = uiMaxAir.toStringAsFixed(0);
      
      _hitungIdeal(_minSuhuC, _maxSuhuC, _idealSuhuC);
      _hitungIdeal(_minKeruhC, _maxKeruhC, _idealKeruhC);
      _hitungIdeal(_minAirC, _maxAirC, _idealAirC);
    }
    setState(() => _isLoading = false);
  }

  void _hitungIdeal(TextEditingController minC, TextEditingController maxC, TextEditingController idealC) {
    double min = double.tryParse(minC.text) ?? 0;
    double max = double.tryParse(maxC.text) ?? 0;
    double avg = (min + max) / 2;
    
    if (avg % 1 == 0) {
      idealC.text = avg.toInt().toString();
    } else {
      idealC.text = avg.toStringAsFixed(1);
    }
  }

  void _applyTemplate(Map<String, dynamic> template) {
    setState(() {
      _minSuhuC.text = template['suhu'][0].toString();
      _maxSuhuC.text = template['suhu'][1].toString();

      _minKeruhC.text = template['keruh'][0].toString();
      _maxKeruhC.text = template['keruh'][1].toString();

      _minAirC.text = template['air'][0].toString();
      _maxAirC.text = template['air'][1].toString();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Template '${template['label']}' diterapkan!"),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _saveData() async {
    double inputMaxAir = double.tryParse(_maxAirC.text) ?? 0;
    double inputMinAir = double.tryParse(_minAirC.text) ?? 0;

    if (inputMaxAir > 100) {
      _showError("Tinggi air maksimal tidak boleh > 100 cm.");
      return;
    }
    if (inputMinAir < 0) {
      _showError("Tinggi air tidak boleh minus.");
      return;
    }
    if (inputMinAir >= inputMaxAir) {
      _showError("Nilai Min Air harus lebih kecil dari Max Air.");
      return;
    }

    setState(() => _isLoading = true);

    double dbJarakMax = _totalJarak - inputMaxAir; 
    double dbJarakMin = _totalJarak - inputMinAir;
    double dbIdealJarak = (dbJarakMax + dbJarakMin) / 2;

    Map<String, dynamic> data = {
      "batassuhu": {
        "min": double.parse(_minSuhuC.text),
        "max": double.parse(_maxSuhuC.text),
        "ideal": double.parse(_idealSuhuC.text),
      },
      "bataskekeruhan": {
        "min": double.parse(_minKeruhC.text),
        "max": double.parse(_maxKeruhC.text),
        "ideal": double.parse(_idealKeruhC.text),
      },
      "batasjarak": { 
        "max": dbJarakMax, 
        "min": dbJarakMin, 
        "ideal": dbIdealJarak,
      }
    };

    bool success = await ApiService.saveParameter(data);
    setState(() => _isLoading = false);

    if (success) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.green, 
            content: Text("Parameter berhasil disimpan!"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      _showError("Gagal menyimpan ke server.");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.red, content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Atur Parameter", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0077C2),
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Pilih Template (Otomatis)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _templates.length,
                  itemBuilder: (context, index) {
                    final temp = _templates[index];
                    return GestureDetector(
                      onTap: () => _applyTemplate(temp),
                      child: Container(
                        width: 160,
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF0077C2).withOpacity(0.3)),
                          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5)],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(temp['label'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0077C2))),
                            const SizedBox(height: 4),
                            Text(temp['desc'], style: TextStyle(fontSize: 11, color: Colors.grey[600]), maxLines: 2),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              
              const SizedBox(height: 25),
              const Text("Kostumisasi Manual", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),

              _buildInputCard(
                title: "Batas Suhu Air (°C)",
                icon: Icons.thermostat,
                color: Colors.orange,
                minC: _minSuhuC,
                maxC: _maxSuhuC,
                idealC: _idealSuhuC,
                unit: "°C"
              ),

              _buildInputCard(
                title: "Batas Kekeruhan (NTU)",
                icon: Icons.water_drop,
                color: Colors.brown,
                minC: _minKeruhC,
                maxC: _maxKeruhC,
                idealC: _idealKeruhC,
                unit: "NTU"
              ),

              _buildInputCard(
                title: "Target Ketinggian Air (cm)",
                subtitle: "Max 100 cm (Tinggi Kolam)",
                icon: Icons.waves,
                color: Colors.blue,
                minC: _minAirC,
                maxC: _maxAirC,
                idealC: _idealAirC,
                unit: "cm"
              ),

              const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0077C2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _saveData,
                  child: const Text("SIMPAN PARAMETER", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
    );
  }

  Widget _buildInputCard({
    required String title,
    String? subtitle,
    required IconData icon,
    required Color color,
    required TextEditingController minC,
    required TextEditingController maxC,
    required TextEditingController idealC,
    required String unit,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    if(subtitle != null)
                       Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.red)),
                  ],
                )
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: _buildTextField("Min", minC, unit)),
                const SizedBox(width: 10),
                Expanded(child: _buildTextField("Max", maxC, unit)),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Ideal (Rata2)", style: TextStyle(fontSize: 10, color: Colors.grey)),
                        TextField(
                          controller: idealC,
                          enabled: false,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            suffixText: unit,
                          ),
                          style: TextStyle(color: color, fontWeight: FontWeight.bold),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String unit) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        suffixText: unit,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}