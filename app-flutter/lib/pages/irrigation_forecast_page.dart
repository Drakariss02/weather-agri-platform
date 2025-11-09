// lib/pages/irrigation_forecast_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lottie/lottie.dart';
import '../services/model_api_service.dart';
import '../constants.dart';
import '../services/translation_service.dart';
import 'package:google_fonts/google_fonts.dart';

class IrrigationForecastPage extends ConsumerStatefulWidget {
  const IrrigationForecastPage({super.key});

  @override
  ConsumerState<IrrigationForecastPage> createState() => _IrrigationForecastPageState();
}

class _IrrigationForecastPageState extends ConsumerState<IrrigationForecastPage> {
  bool _loading = true;
  bool _hasError = false;
  String _message = "";
  List<Map<String, dynamic>> _predictions = [];
  late ModelApiService _api;
  double? _lat, _lon;

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
    });

    final prefs = await SharedPreferences.getInstance();
    _lat = prefs.getDouble("lat") ?? 14.7;
    _lon = prefs.getDouble("lon") ?? -16.9;

    //  Charger les données en cache si dispo
    final cached = prefs.getString('dashboard_cache');
    if (cached != null) {
      try {
        final data = jsonDecode(cached);
        final irrigationData = data["irrigation"];
        if (irrigationData != null && irrigationData["predictions"] != null) {
          setState(() {
            _predictions = List<Map<String, dynamic>>.from(irrigationData["predictions"]);
            _loading = false;
            _message = _computeMessageFromPredictions();
          });
        }
      } catch (_) {
        // ignore cache parse errors
      }
    }

    try {
      final data = await _api.post("/predict/irrigation/forecast", {"lat": _lat, "lon": _lon});
      setState(() {
        _predictions = List<Map<String, dynamic>>.from(data["predictions"] ?? []);
        _loading = false;
        _message = _computeMessageFromPredictions();
        _hasError = false;
      });

      final existingCache = prefs.getString('dashboard_cache');
      Map<String, dynamic> cacheMap = {};
      if (existingCache != null) cacheMap = jsonDecode(existingCache);
      cacheMap["irrigation"] = data;
      await prefs.setString('dashboard_cache', jsonEncode(cacheMap));
    } catch (e) {
      if (_predictions.isEmpty) {
        setState(() {
          _loading = false;
          _hasError = true;
          _message = TranslationService.tr('error_loading_forecast') ?? 'Erreur de chargement des prévisions';
        });
      } else {
        setState(() {
          _message = TranslationService.tr('mode_hors_ligne') ?? 'Mode hors ligne — affichage du cache';
        });
      }
    }
  }

  String _computeMessageFromPredictions() {
    if (_predictions.isEmpty) return TranslationService.tr('irrigation_no_data') ?? 'Aucune donnée disponible';
    final avgNeed = _predictions
        .map((e) => (e["water_need_mm"] as num?)?.toDouble() ?? 0.0)
        .reduce((a, b) => a + b) /
        _predictions.length;
    if (avgNeed > 5) {
      return TranslationService.tr('irrigation_high') ?? '🚿 Fort besoin d\'irrigation — Planifiez un arrosage important';
    } else if (avgNeed > 2) {
      return TranslationService.tr('irrigation_medium') ?? '💧 Irrigation légère recommandée — Arrosage modéré nécessaire';
    } else {
      return TranslationService.tr('irrigation_low') ?? '🌦️ Conditions optimales — Sol suffisamment humide';
    }
  }

  Color _getNeedColor(double need) {
    if (need > 5) return const Color(0xFF1976D2);
    if (need > 2) return const Color(0xFF42A5F5);
    return const Color(0xFF81D4FA);
  }

  IconData _getNeedIcon(double need) {
    if (need > 5) return Icons.water_drop;
    if (need > 2) return Icons.opacity;
    return Icons.grass;
  }

  String _getNeedLevel(double need) {
    if (need > 5) return TranslationService.tr('irrigation_high_label') ?? 'ÉLEVÉ';
    if (need > 2) return TranslationService.tr('irrigation_medium_label') ?? 'MODÉRÉ';
    return TranslationService.tr('irrigation_low_label') ?? 'FAIBLE';
  }

  String _getRecommendation(double need) {
    if (need > 5) return TranslationService.tr('recommendation_high') ?? 'Arrosage intensif requis';
    if (need > 2) return TranslationService.tr('recommendation_moderate') ?? 'Arrosage modéré recommandé';
    return TranslationService.tr('recommendation_low') ?? 'Aucun arrosage nécessaire';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
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
        _buildAppBar(),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 400,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset('assets/lottie/watering.json', width: 100, height: 100),
                const SizedBox(height: 20),
                Text(
                  TranslationService.tr('irrigation_loading') ?? 'Analyse des besoins en eau...',
                  style: GoogleFonts.notoSans(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500),
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
                Text(
                  TranslationService.tr('error_title') ?? "Oups ! Quelque chose s'est mal passé",
                  style: GoogleFonts.notoSans(fontSize: 18, color: Colors.grey[800], fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  _message,
                  style: GoogleFonts.notoSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _loadAndFetch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  ),
                  child: Text(
                    TranslationService.tr('retry') ?? 'Réessayer',
                    style: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar() => SliverAppBar(
    expandedHeight: 200,
    floating: false,
    pinned: true,
    backgroundColor: const Color(0xFF1E88E5),
    flexibleSpace: FlexibleSpaceBar(
      title: Text(
        TranslationService.tr('irrigation_forecast') ?? 'Prévision Irrigation',
        style: GoogleFonts.notoSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      background: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF1E88E5), const Color(0xFF64B5F6).withOpacity(0.9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 20, bottom: 20),
            child: Lottie.asset('assets/lottie/watering.json', width: 120, height: 120),
          ),
        ),
      ),
    ),
  );

  Widget _buildContent() {
    final avgNeed = _predictions.isNotEmpty
        ? _predictions.map((e) => (e["water_need_mm"] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a + b) /
        _predictions.length
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
                _buildAlertCard(avgNeed),
                const SizedBox(height: 24),
                _buildChartSection(),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.grey[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                      TranslationService.tr('irrigation_next_days') ?? 'BESOINS EN EAU SUR 3 JOURS',
                      style: GoogleFonts.notoSans(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700]),
                    ),)
                  ],
                ),
                const SizedBox(height: 12),
                _buildForecastCards(),

              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlertCard(double avgNeed) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_getNeedColor(avgNeed).withOpacity(0.1), _getNeedColor(avgNeed).withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getNeedColor(avgNeed).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _getNeedColor(avgNeed).withOpacity(0.2), shape: BoxShape.circle),
            child: Icon(_getNeedIcon(avgNeed), color: _getNeedColor(avgNeed), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_getNeedLevel(avgNeed),
                  style: GoogleFonts.notoSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _getNeedColor(avgNeed),
                      letterSpacing: 1.2)),
              const SizedBox(height: 4),
              Text(_message,
                  style: GoogleFonts.notoSans(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF2C3E50))),
              const SizedBox(height: 8),
              Text(
                "${TranslationService.tr('average_need') ?? 'Besoin moyen'}: ${avgNeed.toStringAsFixed(1)} mm/jour",
                style: GoogleFonts.notoSans(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
              ),
            ]),
          ),
        ],
      ),
    );
  }

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
          child: Text(
            TranslationService.tr('irrigation_no_data') ?? 'Aucune prévision disponible',
            style: GoogleFonts.notoSans(fontSize: 14, color: Colors.grey[500]),
          ),
        ),
      );
    }

    final maxNeed = _predictions.map((e) => (e["water_need_mm"] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.show_chart, color: Colors.grey[700], size: 20),
            const SizedBox(width: 8),
            Text(
              TranslationService.tr('irrigation_recommendation') ?? 'ÉVOLUTION DES BESOINS EN EAU',
              style: GoogleFonts.notoSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700], letterSpacing: 0.5),
            ),
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
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[100], strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, _) {
                        return Text("${value.toInt()} mm", style: GoogleFonts.notoSans(fontSize: 10));
                      }),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx < _predictions.length) {
                        final date = _predictions[idx]["date"]?.toString().substring(8) ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(date, style: GoogleFonts.notoSans(fontSize: 10)),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey[100]!)),
              lineBarsData: [
                LineChartBarData(
                  spots: _predictions
                      .asMap()
                      .entries
                      .map((e) => FlSpot(e.key.toDouble(), (e.value["water_need_mm"] as num?)?.toDouble() ?? 0.0))
                      .toList(),
                  isCurved: true,
                  gradient: const LinearGradient(colors: [Color(0xFF2196F3), Color(0xFF4FC3F7)]),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                      radius: 4,
                      color: const Color(0xFF2196F3),
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(colors: [const Color(0xFF4FC3F7).withOpacity(0.1), Colors.transparent]),
                  ),
                ),
              ],
              minY: 0,
              maxY: (maxNeed * 1.2).ceilToDouble(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForecastCards() {
    if (_predictions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Center(
          child: Text(
            TranslationService.tr('irrigation_no_data') ?? 'Aucune prévision disponible',
            style: GoogleFonts.notoSans(fontSize: 14, color: Colors.grey[500]),
          ),
        ),
      );
    }

    return Column(
      children: _predictions.asMap().entries.map((entry) {
        final index = entry.key;
        final prediction = entry.value;
        final need = (prediction["water_need_mm"] as num?)?.toDouble() ?? 0.0;
        final recommendation = prediction["recommendation"]?.toString() ?? _getRecommendation(need);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            elevation: 2,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                _showDayDetails(prediction, index);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 50,
                      decoration: BoxDecoration(color: _getNeedColor(need), borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: _getNeedColor(need).withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(_getNeedIcon(need), color: _getNeedColor(need), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          _formatDate(prediction["date"]),
                          style:  GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${TranslationService.tr('day') ?? 'Jour'} ${index + 1} • $recommendation",
                          style: GoogleFonts.notoSans(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ]),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: _getNeedColor(need).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          Text("${need.toStringAsFixed(1)}",
                              style: GoogleFonts.notoSans(fontSize: 14, fontWeight: FontWeight.w700, color: _getNeedColor(need))),
                          Text(TranslationService.tr('mm') ?? 'mm', style: GoogleFonts.notoSans(fontSize: 10, color: _getNeedColor(need).withOpacity(0.7))),
                        ],
                      ),
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
  }

  String _formatDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return "${parts[2]}/${parts[1]}";
      }
      return dateStr;
    } catch (_) {
      return dateStr;
    }
  }

  void _showDayDetails(Map<String, dynamic> prediction, int dayIndex) {
    final need = (prediction["water_need_mm"] as num?)?.toDouble() ?? 0.0;
    final recommendation = prediction["recommendation"]?.toString() ?? _getRecommendation(need);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: _getNeedColor(need).withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(_getNeedIcon(need), color: _getNeedColor(need), size: 24),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                "${TranslationService.tr('irrigation_next_days') ?? 'Besoins du'} ${_formatDate(prediction["date"])}",
                style:  GoogleFonts.notoSans(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF2C3E50)),
                  softWrap: true,
              ),)
            ],
          ),
          const SizedBox(height: 16),
          _buildDetailItem(TranslationService.tr('detail_rain_risk') ?? 'Besoin en eau', "${need.toStringAsFixed(1)} mm"),
          _buildDetailItem(TranslationService.tr('irrigation_level') ?? 'Niveau', _getNeedLevel(need)),
          _buildDetailItem(TranslationService.tr('irrigation_recommendation') ?? 'Recommandation', recommendation),
          _buildDetailItem(TranslationService.tr('practical_advice') ?? 'Conseil pratique', _getPracticalAdvice(need)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getNeedColor(need),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                TranslationService.tr('irrigation_understood') ?? TranslationService.tr('detail_understood') ?? 'Compris',
                style: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildDetailItem(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(flex: 3, child: Text(title, style: GoogleFonts.notoSans(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500))),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(value, textAlign: TextAlign.right, style: GoogleFonts.notoSans(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2C3E50))),
          ),
        ],
      ),
    );
  }

  String _getPracticalAdvice(double need) {
    if (need > 5) return TranslationService.tr('advice_high') ?? 'Arroser tôt le matin pendant 30-45 minutes';
    if (need > 2) return TranslationService.tr('advice_medium') ?? 'Arrosage léger de 15-20 minutes suffisant';
    return TranslationService.tr('advice_low') ?? 'Éviter l\'arrosage pour préserver l\'eau';
  }
}
