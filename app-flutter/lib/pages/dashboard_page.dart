// lib/pages/dashboard_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/model_api_service.dart';
import '../constants.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

import 'rain_prediction_page.dart';
import 'drought_forecast_page.dart';
import 'irrigation_forecast_page.dart';
import 'disease_forecast_page.dart';
import '../services/translation_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loading = true;
  String _statusMessage = "";
  double? _lat;
  double? _lon;
  String? _culture;
  String? _localite;

  late ModelApiService _api;

  Map<String, dynamic>? _rain;
  Map<String, dynamic>? _drought;
  Map<String, dynamic>? _irrigation;
  Map<String, dynamic>? _disease;

  List<Map<String, dynamic>> _weatherForecast = [];

  @override
  void initState() {
    super.initState();
    _api = ModelApiService(baseUrl: API_BASE_URL);
    _loadAndFetch().then((_) => _fetchWeatherForecast());
  }

  Future<void> _fetchWeatherForecast() async {
    if (_lat == null || _lon == null) {
      setState(() => _statusMessage = TranslationService.tr('coord_non_def'));
      return;
    }

    try {
      final url =
          'https://api.open-meteo.com/v1/forecast?latitude=$_lat&longitude=$_lon&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,windspeed_10m_max,relative_humidity_2m_max,relative_humidity_2m_min&timezone=auto';

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final dates = (data['daily']['time'] as List).cast<String>();
        final tempMax = (data['daily']['temperature_2m_max'] as List).cast<num>();
        final tempMin = (data['daily']['temperature_2m_min'] as List).cast<num>();
        final humidityMax = (data['daily']['relative_humidity_2m_max'] as List).cast<num>();
        final humidityMin = (data['daily']['relative_humidity_2m_min'] as List).cast<num>();
        final windSpeed = (data['daily']['windspeed_10m_max'] as List).cast<num>();

        final today = DateTime.now();
        final forecast = <Map<String, dynamic>>[];

        for (int i = 0; i < dates.length && forecast.length < 3; i++) {
          final date = DateTime.parse(dates[i]);
          if (date.isAfter(today) || date.day == today.day) {
            final avgTemp = ((tempMax[i] + tempMin[i]) / 2).round();
            final avgHumidity = ((humidityMax[i] + humidityMin[i]) / 2).round();
            final wind = windSpeed[i].round();

            String condition = TranslationService.tr('sunny');
            String icon = "☀️";
            if (avgHumidity > 75) {
              condition = TranslationService.tr('cloudy');
              icon = "⛅";
            }
            if (wind > 20) {
              condition = TranslationService.tr('windy');
              icon = "💨";
            }

            forecast.add({
              'date': dates[i],
              'temp': avgTemp,
              'humidity': avgHumidity,
              'wind_speed': wind,
              'condition': condition,
              'icon': icon,
            });
          }
        }

        setState(() {
          _weatherForecast = forecast;
        });
      } else {
        setState(() {
          _statusMessage =
          "${TranslationService.tr('erreur_meteo')} : ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = TranslationService.tr('erreur_reseau_meteo');
      });
    }
  }

  Future<void> _loadAndFetch() async {
    final prefs = await SharedPreferences.getInstance();

    _lat = prefs.getDouble("lat") ?? 14.721;
    _lon = prefs.getDouble("lon") ?? -16.8882;
    _culture = prefs.getString("culture") ?? TranslationService.tr('N/A');
    _localite = prefs.getString("localite") ?? TranslationService.tr('N/A');

    final cached = prefs.getString('dashboard_cache');
    if (cached != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(cached);
        setState(() {
          _rain = data['rain'];
          _drought = data['drought'];
          _irrigation = data['irrigation'];
          _disease = data['disease'];
          _statusMessage = TranslationService.tr('affichage_cache');
          _loading = false; // on affiche cache d'abord
        });
      } catch (e) {
        debugPrint("Erreur décodage cache: $e");
      }
    } else {
      setState(() {
        _loading = true;
        _statusMessage = TranslationService.tr('loading_initial');
      });
    }

    try {
      await _fetchAll();
    } catch (e) {
      if (cached == null) {
        setState(() {
          _statusMessage = TranslationService.tr('erreur_reseau_meteo');
          _loading = false;
        });
      } else {
        setState(() {
          _statusMessage = TranslationService.tr('mode_hors_ligne');
        });
      }
    }
  }

  Future<void> _fetchAll() async {
    final lat = _lat!;
    final lon = _lon!;

    final futures = await Future.wait([
      _api.post("/predict/rain/forecast", {"lat": lat, "lon": lon}),
      _api.post("/predict/secheresse/forecast", {"lat": lat, "lon": lon}),
      _api.post("/predict/irrigation/forecast", {"lat": lat, "lon": lon}),
      _api.post("/predict/maladie/forecast", {"lat": lat, "lon": lon}),
    ]);

    setState(() {
      _rain = futures[0] as Map<String, dynamic>?;
      _drought = futures[1] as Map<String, dynamic>?;
      _irrigation = futures[2] as Map<String, dynamic>?;
      _disease = futures[3] as Map<String, dynamic>?;
      _statusMessage = TranslationService.tr('maj_donnees');
      _loading = false;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dashboard_cache', jsonEncode({
      'rain': _rain,
      'drought': _drought,
      'irrigation': _irrigation,
      'disease': _disease,
    }));
    await prefs.setString('dashboard_cache_date', DateTime.now().toIso8601String());
  }

  Widget _buildTopCard() {
    final highestAlerts = <String>[];
    double maxAlarm = 0.0;

    if (_rain != null) {
      try {
        final r = (_rain!['predictions'] as List).map((e) => (e['rain_risk'] as num).toDouble()).toList();
        if (r.isNotEmpty) {
          final dayMax = r.reduce((a, b) => a > b ? a : b);
          if (dayMax > maxAlarm) {
            maxAlarm = dayMax;
            highestAlerts.clear();
            highestAlerts.add(TranslationService.tr('rain'));
          }
        }
      } catch (_) {}
    }

    if (_drought != null) {
      try {
        final r = (_drought!['predictions'] as List).map((e) => (e['drought_risk'] as num).toDouble()).toList();
        if (r.isNotEmpty) {
          final dayMax = r.reduce((a, b) => a > b ? a : b);
          if (dayMax > maxAlarm) {
            maxAlarm = dayMax;
            highestAlerts.clear();
            highestAlerts.add(TranslationService.tr('drought'));
          } else if (dayMax == maxAlarm) highestAlerts.add(TranslationService.tr('drought'));
        }
      } catch (_) {}
    }

    if (_disease != null) {
      try {
        final r = (_disease!['predictions'] as List).map((e) => (e['disease_risk'] as num).toDouble()).toList();
        if (r.isNotEmpty) {
          final dayMax = r.reduce((a, b) => a > b ? a : b);
          if (dayMax > maxAlarm) {
            maxAlarm = dayMax;
            highestAlerts.clear();
            highestAlerts.add(TranslationService.tr('disease'));
          } else if (dayMax == maxAlarm) highestAlerts.add(TranslationService.tr('disease'));
        }
      } catch (_) {}
    }

    if (_irrigation != null) {
      try {
        final r = (_irrigation!['predictions'] as List).map((e) => (e['water_need_mm'] as num).toDouble()).toList();
        if (r.isNotEmpty) {
          final dayMax = r.reduce((a, b) => a > b ? a : b);
          final norm = (dayMax / 10.0).clamp(0.0, 1.0);
          if (norm > maxAlarm) {
            maxAlarm = norm;
            highestAlerts.clear();
            highestAlerts.add(TranslationService.tr('irrigation'));
          }
        }
      } catch (_) {}
    }

    final alertText = (highestAlerts.isEmpty)
        ? TranslationService.tr('no_risk')
        : "${TranslationService.tr('alert')}: ${highestAlerts.join(' / ')} (${(maxAlarm * 100).toStringAsFixed(0)}${TranslationService.tr('percent')})";

    final alertColor = maxAlarm > 0.7 ? Colors.redAccent :
    maxAlarm > 0.4 ? Colors.orange : Colors.green;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 6,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.green.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: Lottie.asset('assets/lottie/summary.json', fit: BoxFit.contain),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "${_localite ?? TranslationService.tr('N/A')}  : ${TranslationService.tr('localite_champs')} ${_culture ?? ''}",
                          style: GoogleFonts.notoSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.grey[800],
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: alertColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: alertColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      alertText,
                      style: GoogleFonts.notoSans(
                        color: alertColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickActionButton(
                          TranslationService.tr('rain'),
                          Icons.beach_access,
                          Colors.blue,
                          const RainForecastPage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQuickActionButton(
                          TranslationService.tr('drought'),
                          Icons.wb_sunny,
                          Colors.orange,
                          const DroughtForecastPage(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, Color color, Widget page) {
    return ElevatedButton(
      onPressed: () => _navigateTo(page),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.notoSans(fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateTo(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  Widget _buildMetricCard(
      String title,
      String value,
      String subtitle,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Icône et flèche ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 16, color: Colors.grey),
                ],
              ),

              // --- Contenu textuel ---
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🟢 Titre
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // 🟢 Valeur principale
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        value,
                        style: GoogleFonts.notoSans(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // 🟢 Sous-titre (évite overflow)
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSans(
                        fontSize: 12,
                        color: Colors.grey[600],
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendChart(String title, List<double> values, Color color) {
    if (values.isEmpty) return const SizedBox.shrink();

    final spots = values.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.notoSans(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      color: color,
                      dotData: FlDotData(show: false),
                      isCurved: true,
                      barWidth: 3,
                      gradient: LinearGradient(
                        colors: [color, color.withOpacity(0.5)],
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [color.withOpacity(0.1), Colors.transparent],
                        ),
                      ),
                    ),
                  ],
                  minY: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<double> _extractSeries(Map<String, dynamic>? modelResp, String key, {double multiply = 1.0}) {
    if (modelResp == null) return [];
    try {
      final preds = (modelResp['predictions'] as List).map((e) => (e[key] as num).toDouble() * multiply).toList();
      return preds;
    } catch (_) {
      return [];
    }
  }

  String _summaryLine(Map<String, dynamic>? modelResp, String key) {
    if (modelResp == null) return TranslationService.tr('N/A');
    try {
      final preds = (modelResp['predictions'] as List).map((e) => (e[key] as num).toDouble()).toList();
      if (preds.isEmpty) return TranslationService.tr('N/A');

      final maxValue = preds.reduce((a, b) => a > b ? a : b);

      if (maxValue <= 1.0) {
        return "${(maxValue * 100).toStringAsFixed(0)}${TranslationService.tr('percent')}";
      } else {
        return "${maxValue.toStringAsFixed(1)} ${TranslationService.tr('mm')}";
      }
    } catch (e) {
      return TranslationService.tr('N/A');
    }
  }

  String _formatDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length == 3) {
      return "${parts[2]}/${parts[1]}";
    }
    return dateStr;
  }
  Widget _buildWeatherCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2E8B57), Color(0xFF4CAF50)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  TranslationService.tr('weather_forecast'),
                  style: GoogleFonts.notoSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 23,
                  ),
                ),

                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _fetchWeatherForecast,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _weatherForecast.map((day) => _buildWeatherDay(day)).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherDay(Map<String, dynamic> day) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            _formatDate(day['date']),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            day['icon'],
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(height: 8),
          Text(
            '${day['temp']}°C',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.water_drop, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              Text(
                '${day['humidity']}%',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.air, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              Text(
                '${day['wind_speed']} km/h',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FDFA),
      appBar: AppBar(
        title: Text(
          TranslationService.tr('dashboard_title'),
          style: GoogleFonts.notoSans(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFF2E8B57),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAndFetch,
            tooltip: TranslationService.tr('refresh'),
          ),
        ],
      ),
      body: _loading
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset('assets/lottie/loading.json', width: 100, height: 100),
            const SizedBox(height: 16),
            Text(
              TranslationService.tr('loading'),
              style: GoogleFonts.notoSans(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: _loadAndFetch,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopCard(),
              const SizedBox(height: 20),
              _buildWeatherCard(),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.grey[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    TranslationService.tr('predictions'),
                    style: GoogleFonts.notoSans(fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.85,
                children: [
                  _buildMetricCard(
                    TranslationService.tr('risque_pluie'),
                    _summaryLine(_rain, "rain_risk"),
                    TranslationService.tr('average_probability'),
                    Icons.beach_access,
                    Colors.blue,
                        () => _navigateTo(const RainForecastPage()),

                  ),
                  _buildMetricCard(
                    TranslationService.tr('risque_secheresse'),
                    _summaryLine(_drought, "drought_risk"),
                    TranslationService.tr('niveau_alerte'),
                    Icons.wb_sunny,
                    Colors.orange,
                        () => _navigateTo(const DroughtForecastPage()),
                  ),
                  _buildMetricCard(
                    TranslationService.tr('besoin_irrigation'),
                    _summaryLine(_irrigation, "water_need_mm"),
                    TranslationService.tr('average_need'),
                    Icons.water_drop,
                    Colors.lightBlue,
                        () => _navigateTo(const IrrigationForecastPage()),
                  ),
                  _buildMetricCard(
                    TranslationService.tr('risque_maladie'),
                    _summaryLine(_disease, "disease_risk"),
                    TranslationService.tr('average_probability'),
                    Icons.eco,
                    Colors.green,
                        () => _navigateTo(const DiseaseForecastPage()),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline_rounded, color: Colors.grey[600], size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: GoogleFonts.notoSans(color: Colors.grey[700]),
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
