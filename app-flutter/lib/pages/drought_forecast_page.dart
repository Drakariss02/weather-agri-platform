import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:lottie/lottie.dart';
import 'package:iconsax/iconsax.dart';
import '../services/model_api_service.dart';
import '../services/translation_service.dart';
import '../constants.dart';
import 'package:google_fonts/google_fonts.dart';

class DroughtForecastPage extends ConsumerStatefulWidget {
  const DroughtForecastPage({super.key});

  @override
  ConsumerState<DroughtForecastPage> createState() => _DroughtForecastPageState();
}

class _DroughtForecastPageState extends ConsumerState<DroughtForecastPage> {
  bool _loading = true;
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
    });

    final prefs = await SharedPreferences.getInstance();
    _lat = prefs.getDouble("lat") ?? 14.7;
    _lon = prefs.getDouble("lon") ?? -16.9;

    final cached = prefs.getString('dashboard_cache');
    if (cached != null) {
      try {
        final data = jsonDecode(cached);
        final droughtData = data["drought"];
        if (droughtData != null && droughtData["predictions"] != null) {
          setState(() {
            _predictions = List<Map<String, dynamic>>.from(droughtData["predictions"]);
            _message = TranslationService.tr('affichage_cache');
            _loading = false;
          });
        }
      } catch (_) {}
    }

    try {
      final data = await _api.post("/predict/secheresse/forecast", {"lat": _lat, "lon": _lon});
      setState(() {
        _predictions = List<Map<String, dynamic>>.from(data["predictions"]);
        final avgRisk = _predictions.map((e) => e["drought_risk"]).reduce((a, b) => a + b) / _predictions.length;
        if (avgRisk > 0.7) {
          _message = TranslationService.tr('drought_msg_high');
        } else if (avgRisk > 0.4) {
          _message = TranslationService.tr('drought_msg_medium');
        } else {
          _message = TranslationService.tr('drought_msg_low');
        }
        _loading = false;
      });

      final existingCache = prefs.getString('dashboard_cache');
      Map<String, dynamic> fullCache = {};
      if (existingCache != null) {
        fullCache = jsonDecode(existingCache);
      }
      fullCache["drought"] = data;
      await prefs.setString('dashboard_cache', jsonEncode(fullCache));
    } catch (e) {
      if (_predictions.isEmpty) {
        setState(() {
          _message = TranslationService.tr('error_network_no_data');
          _loading = false;
        });
      }
    }
  }

  Color _getRiskColor(double risk) {
    if (risk > 0.7) return const Color(0xFFE74C3C);
    if (risk > 0.4) return const Color(0xFFF39C12);
    return const Color(0xFF27AE60);
  }

  IconData _getRiskIcon(double risk) {
    if (risk > 0.7) return Iconsax.warning_2;
    if (risk > 0.4) return Iconsax.info_circle;
    return Iconsax.tick_circle;
  }

  String _getRiskLevel(double risk) {
    if (risk > 0.7) return TranslationService.tr('risk_high');
    if (risk > 0.4) return TranslationService.tr('risk_medium');
    return TranslationService.tr('risk_low');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FDFA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFFD35400),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                TranslationService.tr('drought_forecast'),
                style: GoogleFonts.notoSans(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black.withOpacity(0.3), blurRadius: 4)],
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFFD35400), const Color(0xFFE67E22).withOpacity(0.9)],
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
                        'assets/lottie/drought.json',
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
            child: _loading
                ? _buildLoadingState()
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return SizedBox(
      height: 400,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset('assets/lottie/drought.json', width: 100, height: 100),
          const SizedBox(height: 20),
          Text(
            TranslationService.tr('loading_weather'),
            style: GoogleFonts.notoSans(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            TranslationService.tr('loading_wait'),
            style: GoogleFonts.notoSans(fontSize: 13, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAlertCard(),
          const SizedBox(height: 24),
          _buildChartSection(),
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(Iconsax.calendar_1, color: Colors.grey[700], size: 20),
              const SizedBox(width: 8),
              Text(
                TranslationService.tr('forecast_3days'),
                style: GoogleFonts.notoSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildPredictionCards(),
        ],
      ),
    );
  }

  Widget _buildAlertCard() {
    final avgRisk = _predictions.isNotEmpty
        ? _predictions.map((e) => e["drought_risk"]).reduce((a, b) => a + b) / _predictions.length
        : 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getRiskColor(avgRisk).withOpacity(0.1),
            _getRiskColor(avgRisk).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getRiskColor(avgRisk).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getRiskColor(avgRisk).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getRiskIcon(avgRisk),
              color: _getRiskColor(avgRisk),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _message,
              style:  GoogleFonts.notoSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2C3E50),
              ),
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
            Icon(Iconsax.chart_1, color: Colors.grey[700], size: 20),
            const SizedBox(width: 8),
            Text(
              TranslationService.tr('risk_evolution'),
              style: GoogleFonts.notoSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                letterSpacing: 0.5,
              ),
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Colors.grey[100],
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        "${value.toInt()}%",
                        style: GoogleFonts.notoSans(
                          fontSize: 10,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < _predictions.length) {
                        final date = _predictions[idx]["date"].toString().substring(8);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            date,
                            style: GoogleFonts.notoSans(
                              fontSize: 10,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey[100]!),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: _predictions.asMap().entries.map((e) =>
                      FlSpot(e.key.toDouble(), e.value["drought_risk"] * 100)
                  ).toList(),
                  isCurved: true,
                  gradient: LinearGradient(
                    colors: [const Color(0xFFD35400), const Color(0xFFF4A261)],
                  ),
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(show: true),
                  belowBarData: BarAreaData(show: true),
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

  Widget _buildPredictionCards() {
    return Column(
      children: _predictions.asMap().entries.map((entry) {
        final index = entry.key;
        final prediction = entry.value;
        final risk = prediction["drought_risk"];
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
                      height: 50,
                      decoration: BoxDecoration(
                        color: _getRiskColor(risk),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getRiskColor(risk).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getRiskIcon(risk),
                        color: _getRiskColor(risk),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDate(prediction["date"]),
                            style: GoogleFonts.notoSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "${TranslationService.tr('day')} ${index + 1} • ${_getRiskLevel(risk)}",
                            style: GoogleFonts.notoSans(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _getRiskColor(risk).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${(risk * 100).toInt()}%",
                        style: GoogleFonts.notoSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _getRiskColor(risk),
                        ),
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

  void _showDayDetails(Map<String, dynamic> prediction, int index) {
    final risk = prediction["drought_risk"];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getRiskColor(risk).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getRiskIcon(risk),
                      color: _getRiskColor(risk),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "${TranslationService.tr('forecast_of')} ${_formatDate(prediction["date"])}",
                    style: GoogleFonts.notoSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildDetailItem(TranslationService.tr('risk_level'), _getRiskLevel(risk)),
              _buildDetailItem(TranslationService.tr('drought_index'), "${(risk * 100).toStringAsFixed(1)}%"),
              _buildDetailItem(TranslationService.tr('recommendation'), _getRecommendation(risk)),
              _buildDetailItem(TranslationService.tr('pratical_advice'), _getAdvice(risk)),
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
                  child: Text(
                    TranslationService.tr('detail_understood'),
                    style: GoogleFonts.notoSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getRecommendation(double risk) {
    if (risk > 0.7) return TranslationService.tr('rec_drought_high');
    if (risk > 0.4) return TranslationService.tr('rec_drought_medium');
    return TranslationService.tr('rec_drought_low');
  }

  String _getAdvice(double risk) {
    if (risk > 0.7) return TranslationService.tr('advice_drought_high');
    if (risk > 0.4) return TranslationService.tr('advice_drought_medium');
    return TranslationService.tr('advice_drought_low');
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

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label : ",
            style: GoogleFonts.notoSans(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Color(0xFF2C3E50),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.notoSans(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
