// lib/pages/rain_forecast_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/model_api_service.dart';
import '../constants.dart';
import '../services/translation_service.dart';

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
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

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
      } catch (e) {
        print("Erreur décodage cache pluie: $e");
      }
    }

    try {
      await _fetchForecast();
    } catch (e) {
      if (_predictions.isEmpty) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _message = TranslationService.tr('error_network_no_data');
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
      final predictions = List<Map<String, dynamic>>.from(data['predictions'] ?? []);

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
      print("Erreur fetch rain forecast: $e");
      setState(() {
        _isLoading = false;
        _hasError = true;
        _message = TranslationService.tr('error_loading_forecast');
      });
    }
  }

  void _updateMessage() {
    if (_predictions.isEmpty) {
      _message = TranslationService.tr('no_data');
      return;
    }

    final maxRisk = _predictions
        .map((p) => (p['rain_risk'] as num?)?.toDouble() ?? 0.0)
        .reduce((a, b) => a > b ? a : b);

    if (maxRisk > 0.7) {
      _message = TranslationService.tr('rain_msg_high');
    } else if (maxRisk > 0.4) {
      _message = TranslationService.tr('rain_msg_medium');
    } else {
      _message = TranslationService.tr('rain_msg_low');
    }
  }

  Color _getRiskColor(double risk) {
    if (risk > 0.7) return const Color(0xFF3498DB);
    if (risk > 0.4) return const Color(0xFFF39C12);
    return const Color(0xFF2ECC71);
  }

  IconData _getRiskIcon(double risk, bool rainExpected) {
    if (rainExpected == true) return Icons.beach_access;
    if (risk > 0.7) return Icons.cloudy_snowing;
    if (risk > 0.4) return Icons.cloud;
    return Icons.wb_sunny;
  }

  String _getRiskLevel(double risk) {
    if (risk > 0.7) return TranslationService.tr('risk_high');
    if (risk > 0.4) return TranslationService.tr('risk_medium');
    return TranslationService.tr('risk_low');
  }

  String _getRecommendation(double risk) {
    if (risk > 0.7) return TranslationService.tr('rec_high');
    if (risk > 0.4) return TranslationService.tr('rec_medium');
    return TranslationService.tr('rec_low');
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
        child: SizedBox(
          height: 420,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/lottie/rain_cloud.json', width: 110, height: 110),
              const SizedBox(height: 20),
              Text(
                TranslationService.tr('loading_weather'),
                style: GoogleFonts.notoSans(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  TranslationService.tr('loading_wait'),
                  style: GoogleFonts.notoSans(fontSize: 12, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
              ),
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
          height: 420,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/lottie/error.json', width: 120, height: 120),
              const SizedBox(height: 20),
              Text(
                TranslationService.tr('error_title'),
                style: GoogleFonts.notoSans(fontSize: 18, color: Colors.grey[800], fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                _message,
                style: GoogleFonts.notoSans(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _loadAndFetch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E8B57),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                ),
                child: Text(
                  TranslationService.tr('retry'),
                  style: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                ),
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
      title: Text(
        TranslationService.tr('rain_forecast'),
        style: GoogleFonts.notoSans(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
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
        ? _predictions.map((p) => (p['rain_risk'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a > b ? a : b)
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
                    Text(
                      TranslationService.tr('forecast_3days'),
                      style: GoogleFonts.notoSans(
                          fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700], letterSpacing: 0.5),
                    ),
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
              Text(
                _getRiskLevel(maxRisk),
                style: GoogleFonts.notoSans(
                    fontSize: 12, fontWeight: FontWeight.w700, color: _getRiskColor(maxRisk), letterSpacing: 1.2),
              ),
              const SizedBox(height: 4),
              Text(
                _message,
                style: GoogleFonts.notoSans(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFF2C3E50)),
              ),
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
          child: Text(
            TranslationService.tr('no_data'),
            style: GoogleFonts.notoSans(fontSize: 14, color: Colors.grey[500]),
          ),
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
            Text(
              TranslationService.tr('forecast_3days'),
              style: GoogleFonts.notoSans(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[700]),
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
              gridData: FlGridData(show: true, drawVerticalLine: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (v, _) => Text("${v.toInt()}${TranslationService.tr('percent')}",
                        style: GoogleFonts.notoSans(fontSize: 10)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < _predictions.length) {
                        final dateStr = _predictions[idx]["date"]?.toString() ?? '';
                        final label = dateStr.length >= 10 ? dateStr.substring(8, 10) : dateStr;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(label, style: GoogleFonts.notoSans(fontSize: 10)),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: _predictions
                      .asMap()
                      .entries
                      .map((e) => FlSpot(e.key.toDouble(), (e.value["rain_risk"] as num?)?.toDouble() ?? 0.0 * 100))
                      .toList()
                      .map((s) => FlSpot(s.x, s.y * 1)) // ensure double
                      .toList(),
                  isCurved: true,
                  barWidth: 3,
                  gradient: const LinearGradient(colors: [Color(0xFF2E8B57), Color(0xFF56CCF2)]),
                  dotData: FlDotData(show: false),
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
      final risk = (prediction["rain_risk"] as num?)?.toDouble() ?? 0.0;
      final rainExpected = prediction["rain_expected"] == true;

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
                    decoration: BoxDecoration(color: _getRiskColor(risk).withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(_getRiskIcon(risk, rainExpected), color: _getRiskColor(risk), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(prediction["date"]?.toString() ?? ''),
                          style: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF2C3E50)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${TranslationService.tr('day')} ${index + 1} • ${rainExpected ? TranslationService.tr('rain_expected') : TranslationService.tr('no_rain')}",
                          style: GoogleFonts.notoSans(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: _getRiskColor(risk).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      "${(risk * 100).toInt()}${TranslationService.tr('percent')}",
                      style: GoogleFonts.notoSans(fontSize: 14, fontWeight: FontWeight.w700, color: _getRiskColor(risk)),
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
    final risk = (prediction["rain_risk"] as num?)?.toDouble() ?? 0.0;
    final rainExpected = prediction["rain_expected"] == true;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                  child: Icon(_getRiskIcon(risk, rainExpected), color: _getRiskColor(risk), size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  "${TranslationService.tr('detail_rain_risk')} ${_formatDate(prediction["date"]?.toString() ?? '')}",
                  style: GoogleFonts.notoSans(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF2C3E50)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDetailItem(TranslationService.tr('detail_rain_risk'), "${(risk * 100).toStringAsFixed(0)}${TranslationService.tr('percent')}"),
            _buildDetailItem(TranslationService.tr('detail_prob'), rainExpected ? TranslationService.tr('risk_high') : TranslationService.tr('risk_low')),
            _buildDetailItem(TranslationService.tr('detail_recommendation'), _getRecommendation(risk)),
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
                  style: GoogleFonts.notoSans(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              title,
              style: GoogleFonts.notoSans(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: GoogleFonts.notoSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF2C3E50)),
              textAlign: TextAlign.right,
              softWrap: true,
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
    );
  }
}
