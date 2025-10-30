import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lottie/lottie.dart';
import 'package:iconsax/iconsax.dart';
import '../services/model_api_service.dart';
import '../constants.dart';
import 'dart:convert';

class DiseaseForecastPage extends ConsumerStatefulWidget {
  const DiseaseForecastPage({super.key});

  @override
  ConsumerState<DiseaseForecastPage> createState() => _DiseaseForecastPageState();
}

class _DiseaseForecastPageState extends ConsumerState<DiseaseForecastPage> {
  bool _loading = true;
  bool _hasError = false;
  String _message = "";
  List<Map<String, dynamic>> _predictions = [];

  late ModelApiService _api;
  double? _lat;
  double? _lon;

  @override
  void initState() {
    super.initState();
    _api = ModelApiService(baseUrl: API_BASE_URL);
    _loadAndFetch();
  }

  Future<void> _loadAndFetch() async {
    setState(() {
      _loading = true;
      _hasError = false;
      _message = "Chargement des données...";
    });

    final prefs = await SharedPreferences.getInstance();
    _lat = prefs.getDouble("lat") ?? 14.721;
    _lon = prefs.getDouble("lon") ?? -16.8882;

    final cached = prefs.getString('dashboard_cache');
    if (cached != null) {
      try {
        final data = jsonDecode(cached);
        final diseaseData = data["disease"];
        if (diseaseData != null && diseaseData["predictions"] != null) {
          setState(() {
            _predictions = List<Map<String, dynamic>>.from(diseaseData["predictions"]);
            _loading = false;
            _hasError = false;
            _message = "Affichage des dernières données enregistrées (cache)";
          });
        }
      } catch (_) {
      }
    }

    try {
        await _fetchForecast();
    } catch (e) {
      if (_predictions.isEmpty) {
        setState(() {
          _loading = false;
          _hasError = true;
          _message = "Erreur réseau — données du cache affichées";
        });
      } else {
        debugPrint("Erreur API : $e — cache conservé");
      }
    }
  }

  Future<void> _fetchForecast() async {
    final data = await _api.post("/predict/maladie/forecast", {"lat": _lat, "lon": _lon});
    setState(() {
      _predictions = List<Map<String, dynamic>>.from(data["predictions"]);
      final maxRisk = _predictions.isNotEmpty
          ? _predictions.map((e) => e["disease_risk"]).reduce((a, b) => a > b ? a : b)
          : 0.0;

      if (maxRisk > 0.6) {
        _message = "🦠 Risque élevé de maladies — Surveillance intensive requise";
      } else if (maxRisk > 0.3) {
        _message = "⚠️ Risque modéré — Surveillez l'apparition de symptômes";
      } else {
        _message = "🌿 Conditions saines — Faible risque de maladies";
      }

      _loading = false;
      _hasError = false;
    });

    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('dashboard_cache');
    final Map<String, dynamic> cacheData =
    cached != null ? jsonDecode(cached) : {};
    cacheData['disease'] = data;
    await prefs.setString('dashboard_cache', jsonEncode(cacheData));
  }

  Color _getRiskColor(double risk) {
    if (risk > 0.6) return const Color(0xFFE74C3C);
    if (risk > 0.3) return const Color(0xFFF39C12);
    return const Color(0xFF27AE60);
  }

  IconData _getRiskIcon(double risk) {
    if (risk > 0.6) return Icons.warning;
    if (risk > 0.3) return Icons.health_and_safety;
    return Icons.eco;
  }

  String _getRiskLevel(double risk) {
    if (risk > 0.6) return "ÉLEVÉ";
    if (risk > 0.3) return "MODÉRÉ";
    return "FAIBLE";
  }

  String _getDiseaseAdvice(double risk) {
    if (risk > 0.6) return "Traitement préventif recommandé";
    if (risk > 0.3) return "Surveillance renforcée";
    return "Aucune action nécessaire";
  }

  List<String> _getPreventiveMeasures(double risk) {
    if (risk > 0.6) {
      return [
        "• Appliquer un fongicide préventif",
        "• Éviter l'irrigation foliaire",
        "• Augmenter l'aération",
        "• Surveiller les premiers symptômes"
      ];
    } else if (risk > 0.3) {
      return [
        "• Vérifier l'humidité du feuillage",
        "• Inspecter les plantes régulièrement",
        "• Éviter les excès d'eau",
        "• Maintenir une bonne circulation d'air"
      ];
    } else {
      return [
        "• Maintenir les bonnes pratiques culturales",
        "• Surveiller l'humidité ambiante",
        "• Éviter le stress hydrique",
        "• Rotation des cultures si possible"
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFAF0),
      body: _loading
          ? _buildLoadingState()
          : _hasError
          ? _buildErrorState()
          : _buildContent(),
    );
  }

  Widget _buildLoadingState() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 200,
          floating: false,
          pinned: true,
          backgroundColor: const Color(0xFF8E44AD),
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              "Prévision Maladies",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)],
              ),
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF8E44AD), const Color(0xFF9B59B6).withOpacity(0.9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            height: 400,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset(
                  'assets/lottie/disease.json',
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: 20),
                Text(
                  "Analyse du risque de maladies...",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 200,
          floating: false,
          pinned: true,
          backgroundColor: const Color(0xFF8E44AD),
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              "Prévision Maladies",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            height: 400,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 20),
                Text(
                  "Impossible de charger les données",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _loadAndFetch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8E44AD),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Réessayer", style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final maxRisk = _predictions.isNotEmpty
        ? _predictions.map((e) => e["disease_risk"]).reduce((a, b) => a > b ? a : b)
        : 0.0;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 200,
          floating: false,
          pinned: true,
          backgroundColor: const Color(0xFF8E44AD),
          flexibleSpace: FlexibleSpaceBar(
            title: Text(
              "Prévision Maladies",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)],
              ),
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [const Color(0xFF8E44AD), const Color(0xFF9B59B6).withOpacity(0.9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 20,
                    bottom: 20,
                    child: Lottie.asset(
                      'assets/lottie/disease.json',
                      width: 120,
                      height: 120,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
                _buildPreventiveMeasures(maxRisk),
                const SizedBox(height: 24),
                _buildForecastCards(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertCard(double maxRisk) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getRiskColor(maxRisk).withOpacity(0.1),
            _getRiskColor(maxRisk).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getRiskColor(maxRisk).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getRiskColor(maxRisk).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(_getRiskIcon(maxRisk), color: _getRiskColor(maxRisk), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_getRiskLevel(maxRisk), style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: _getRiskColor(maxRisk), letterSpacing: 1.2,
                )),
                const SizedBox(height: 4),
                Text(_message, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Text(_getDiseaseAdvice(maxRisk), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    if (_predictions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.show_chart, color: Colors.grey[700], size: 20),
            const SizedBox(width: 8),
            Text("ÉVOLUTION DU RISQUE", style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700], letterSpacing: 0.5,
            )),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(show: true, drawVerticalLine: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true, reservedSize: 40,
                  getTitlesWidget: (value, meta) => Text("${(value * 100).toInt()}%", style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                )),
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true, reservedSize: 32,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < _predictions.length) {
                      return Text(_predictions[idx]["date"].toString().substring(8), style: TextStyle(fontSize: 10, color: Colors.grey[600]));
                    }
                    return const SizedBox.shrink();
                  },
                )),
              ),
              borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey[100]!)),
              lineBarsData: [
                LineChartBarData(
                  spots: _predictions.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value["disease_risk"])).toList(),
                  isCurved: true,
                  gradient: const LinearGradient(colors: [Color(0xFF8E44AD), Color(0xFFC39BD3)]),
                  barWidth: 3,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [const Color(0xFFC39BD3).withOpacity(0.1), Colors.transparent])),
                ),
              ],
              minY: 0,
              maxY: 1.0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreventiveMeasures(double risk) {
    final measures = _getPreventiveMeasures(risk);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _getRiskColor(risk).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _getRiskColor(risk).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.medical_services, color: _getRiskColor(risk), size: 20),
              const SizedBox(width: 8),
              Text("MESURES PRÉVENTIVES", style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: _getRiskColor(risk),
              )),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: measures.map((measure) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(measure, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.grey[700], size: 20),
            const SizedBox(width: 8),
            Text("PRÉVISIONS DÉTAILLÉES", style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700], letterSpacing: 0.5,
            )),
          ],
        ),
        const SizedBox(height: 12),
        ..._predictions.asMap().entries.map((entry) {
          final prediction = entry.value;
          final risk = prediction["disease_risk"];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              elevation: 2,
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getRiskColor(risk).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_getRiskIcon(risk), color: _getRiskColor(risk), size: 20),
                ),
                title: Text("${prediction["date"]}", style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text("Risque: ${(risk * 100).toStringAsFixed(0)}% • ${_getRiskLevel(risk)}"),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getRiskColor(risk).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(prediction["disease_alert"] ? "ALERTE" : "SAIN", style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: _getRiskColor(risk),
                  )),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}