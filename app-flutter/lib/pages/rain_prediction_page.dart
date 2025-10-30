import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import '../services/model_api_service.dart';
import '../constants.dart';

class RainForecastPage extends ConsumerStatefulWidget {
  const RainForecastPage({super.key});

  @override
  ConsumerState<RainForecastPage> createState() => _RainForecastPageState();
}

class _RainForecastPageState extends ConsumerState<RainForecastPage> {
  bool _isLoading = true;
  bool _hasError = false;
  String _message = "";
  List<Map<String, dynamic>> _predictions = [];
  late ModelApiService _apiService;
  double? _lat, _lon;

  @override
  void initState() {
    super.initState();
    _apiService = ModelApiService(baseUrl: API_BASE_URL);
    _loadAndFetch();
  }

  Future<void> _loadAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    _lat = prefs.getDouble("lat") ?? 14.721;
    _lon = prefs.getDouble("lon") ?? -16.8882;

    final cached = prefs.getString('dashboard_cache');
    if (cached != null) {
      try {
        final data = jsonDecode(cached);
        final rainData = data["rain"];
        if (rainData != null && rainData["predictions"] != null) {
          setState(() {
            _predictions = List<Map<String, dynamic>>.from(rainData["predictions"]);
            _updateMessage();
            _isLoading = false;
            _hasError = false;
          });
        }
      } catch (_) {}
    }

    try {
      await _fetchForecast();
    } catch (e) {
      if (_predictions.isEmpty) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _message = "Erreur réseau — aucune donnée disponible";
        });
      }
    }
  }

  Future<void> _fetchForecast() async {
    try {
      final resp = await _apiService.post(
        "/predict/rain/forecast",
        {"lat": _lat, "lon": _lon},
      );

      final data = resp;
      final predictions = List<Map<String, dynamic>>.from(data['predictions']);

      setState(() {
        _predictions = predictions;
        _updateMessage();
        _isLoading = false;
        _hasError = false;
      });

      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('dashboard_cache');
      final Map<String, dynamic> cacheData = cached != null ? jsonDecode(cached) : {};
      cacheData['rain'] = data;
      await prefs.setString('dashboard_cache', jsonEncode(cacheData));
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _message = "Erreur de chargement des prévisions";
      });
    }
  }

  void _updateMessage() {
    if (_predictions.isEmpty) return;
    final maxRisk = _predictions.map((p) => p['rain_risk']).reduce((a, b) => a > b ? a : b);
    if (maxRisk > 0.7) {
      _message = "🌧️ Fort risque de pluie — Préparez vos cultures à l'humidité";
    } else if (maxRisk > 0.4) {
      _message = "🌤️ Risque modéré — Surveillez les prévisions régulièrement";
    } else {
      _message = "☀️ Conditions optimales — Faible risque de précipitations";
    }
  }

  Color _getRiskColor(double risk) {
    if (risk > 0.7) return const Color(0xFF3498DB);
    if (risk > 0.4) return const Color(0xFFF39C12);
    return const Color(0xFF2ECC71);
  }

  IconData _getRiskIcon(double risk, bool rainExpected) {
    if (rainExpected) return Icons.beach_access;
    if (risk > 0.7) return Icons.cloudy_snowing;
    if (risk > 0.4) return Icons.cloud;
    return Icons.wb_sunny;
  }

  String _getRiskLevel(double risk) {
    if (risk > 0.7) return "ÉLEVÉ";
    if (risk > 0.4) return "MODÉRÉ";
    return "FAIBLE";
  }

  String _getRecommendation(double risk) {
    if (risk > 0.7) return "Protégez vos cultures de l'excès d'eau";
    if (risk > 0.4) return "Surveillez l'humidité du sol";
    return "Conditions idéales pour l'irrigation";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      body: _isLoading
          ? _buildLoadingState()
          : _hasError
          ? _buildErrorState()
          : _buildContent(),
    );
  }

  Widget _buildLoadingState() => CustomScrollView(
    slivers: [
      _buildAppBar(),
      SliverToBoxAdapter(
        child: Container(
          height: 400,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/lottie/rain_cloud.json', width: 100, height: 100),
              const SizedBox(height: 20),
              Text("Analyse des données météo...",
                  style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              const SizedBox(height: 10),
              Text("Cette opération peut prendre quelques secondes",
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _buildErrorState() => CustomScrollView(
    slivers: [
      _buildAppBar(),
      SliverToBoxAdapter(
        child: Container(
          height: 400,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/lottie/error.json', width: 120, height: 120),
              const SizedBox(height: 20),
              Text("Oups ! Quelque chose s'est mal passé",
                  style: TextStyle(fontSize: 18, color: Colors.grey[800], fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(_message,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _loadAndFetch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E8B57),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                child: const Text("Réessayer",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _buildAppBar() => SliverAppBar(
    expandedHeight: 200,
    pinned: true,
    backgroundColor: const Color(0xFF2E8B57),
    flexibleSpace: FlexibleSpaceBar(
      title: const Text(
        "Prévision Pluie",
        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      background: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2E8B57), Color(0xFF56CCF2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Lottie.asset('assets/lottie/rain_cloud.json', width: 120, height: 120),
          ),
        ),
      ),
    ),
  );

  Widget _buildContent() {
    final maxRisk = _predictions.isNotEmpty
        ? _predictions.map((p) => p['rain_risk']).reduce((a, b) => a > b ? a : b)
        : 0.0;

    return CustomScrollView(
      slivers: [
        _buildAppBar(),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAlertCard(maxRisk),
                const SizedBox(height: 24),
                _buildChartSection(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.grey[700], size: 20),
                    const SizedBox(width: 8),
                    Text("PRÉVISIONS SUR 3 JOURS",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[700],
                            letterSpacing: 0.5)),
                  ],
                ),
                const SizedBox(height: 12),
                _buildPredictionCards(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertCard(double maxRisk) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [_getRiskColor(maxRisk).withOpacity(0.1), _getRiskColor(maxRisk).withOpacity(0.05)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _getRiskColor(maxRisk).withOpacity(0.3)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _getRiskColor(maxRisk).withOpacity(0.2), shape: BoxShape.circle),
          child: Icon(_getRiskIcon(maxRisk, maxRisk > 0.7), color: _getRiskColor(maxRisk), size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_getRiskLevel(maxRisk),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _getRiskColor(maxRisk),
                      letterSpacing: 1.2)),
              const SizedBox(height: 4),
              Text(_message,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF2C3E50))),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildChartSection() {
    if (_predictions.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Center(
          child: Text("Aucune donnée disponible",
              style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.show_chart, color: Colors.grey[700], size: 20),
            const SizedBox(width: 8),
            Text("ÉVOLUTION DU RISQUE",
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                    letterSpacing: 0.5)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: true, drawVerticalLine: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (v, _) => Text("${v.toInt()}%", style: TextStyle(fontSize: 10)))),
                bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < _predictions.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(_predictions[idx]["date"].toString().substring(8),
                                  style: const TextStyle(fontSize: 10)),
                            );
                          }
                          return const SizedBox.shrink();
                        })),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: _predictions
                      .asMap()
                      .entries
                      .map((e) => FlSpot(e.key.toDouble(), e.value["rain_risk"] * 100))
                      .toList(),
                  isCurved: true,
                  barWidth: 3,
                  gradient: const LinearGradient(colors: [Color(0xFF2E8B57), Color(0xFF56CCF2)]),
                ),
              ],
              minY: 0,
              maxY: 100,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPredictionCards() => Column(
    children: _predictions.asMap().entries.map((entry) {
      final index = entry.key;
      final prediction = entry.value;
      final risk = prediction["rain_risk"];
      final rainExpected = prediction["rain_expected"];

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          elevation: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showDayDetails(prediction, index),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration:
                    BoxDecoration(color: _getRiskColor(risk), borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration:
                    BoxDecoration(color: _getRiskColor(risk).withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(_getRiskIcon(risk, rainExpected),
                        color: _getRiskColor(risk), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_formatDate(prediction["date"]),
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2C3E50))),
                        const SizedBox(height: 4),
                        Text(
                            "Jour ${index + 1} • ${rainExpected ? 'Pluie attendue' : 'Pas de pluie'}",
                            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: _getRiskColor(risk).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text("${(risk * 100).toInt()}%",
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _getRiskColor(risk))),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList(),
  );

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) return "${parts[2]}/${parts[1]}";
      return dateStr;
    } catch (_) {
      return dateStr;
    }
  }

  void _showDayDetails(Map<String, dynamic> prediction, int dayIndex) {
    final risk = prediction["rain_risk"];
    final rainExpected = prediction["rain_expected"];
    showModalBottomSheet(
      context: context,
      shape:
      const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: _getRiskColor(risk).withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(_getRiskIcon(risk, rainExpected),
                      color: _getRiskColor(risk), size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  "Prévision du ${_formatDate(prediction["date"])}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2C3E50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailItem("Risque de pluie", "${(risk * 100).toStringAsFixed(0)}%"),
            _buildDetailItem("Probabilité", rainExpected ? "Élevée" : "Faible"),
            _buildDetailItem("Recommandation", _getRecommendation(risk)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getRiskColor(risk),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  "Compris",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // ✅ pour bien aligner si plusieurs lignes
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C3E50),
              ),
              textAlign: TextAlign.right,
              softWrap: true, // ✅ permet de passer à la ligne
              overflow: TextOverflow.visible, // ✅ évite le débordement
            ),
          ),
        ],
      ),
    );
  }

}
