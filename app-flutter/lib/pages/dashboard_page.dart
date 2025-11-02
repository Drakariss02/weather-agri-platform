// lib/pages/dashboard_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lottie/lottie.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/model_api_service.dart';
import '../constants.dart';
import 'package:http/http.dart' as http;
// Import the detailed pages
import 'rain_prediction_page.dart';
import 'drought_forecast_page.dart';
import 'irrigation_forecast_page.dart';
import 'disease_forecast_page.dart';

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
      setState(() => _statusMessage = "Coordonnées non définies pour la météo");
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

            String condition = "ensoleillé";
            String icon = "☀️";
            if (avgHumidity > 75) {
              condition = "nuageux";
              icon = "⛅";
            }
            if (wind > 20) {
              condition = "venteux";
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
          "Erreur météo : ${response.statusCode} ${response.reasonPhrase}";
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "Erreur réseau météo";
      });
    }
  }

  Future<void> _loadAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    _lat = prefs.getDouble("lat") ?? 14.721;
    _lon = prefs.getDouble("lon") ?? -16.8882;
    _culture = prefs.getString("culture")?? "Inconnue";
    _localite = prefs.getString("localite")?? "Inconnue";

    // Charger le cache dès le début
    final cached = prefs.getString('dashboard_cache');
    if (cached != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(cached);
        setState(() {
          _rain = data['rain'];
          _drought = data['drought'];
          _irrigation = data['irrigation'];
          _disease = data['disease'];
          _statusMessage = "Affichage des données en cache...";
          _loading = false; // On montre le cache tout de suite
        });
      } catch (e) {
        debugPrint("Erreur décodage cache: $e");
      }
    } else {
      setState(() {
        _loading = true;
        _statusMessage = "Chargement initial...";
      });
    }

    // Lancer la récupération réseau en parallèle
    try {
      await _fetchAll();
    } catch (e) {
      if (cached == null) {
        setState(() {
          _statusMessage = "Erreur réseau ";
          _loading = false;
        });
      } else {
        setState(() {
          _statusMessage = "Mode hors ligne — affichage du cache";
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
      _statusMessage = "Données mises à jour";
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
                const Text(
                  "Prévisions Météo",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
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

  String _formatDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length == 3) {
      return "${parts[2]}/${parts[1]}";
    }
    return dateStr;
  }

  Widget _buildTopCard() {
    final highestAlerts = <String>[];
    double maxAlarm = 0.0;

    if (_rain != null) {
      final r = (_rain!['predictions'] as List).map((e) => e['rain_risk'] as num).cast<double>().toList();
      if (r.isNotEmpty) {
        final dayMax = r.reduce((a, b) => a > b ? a : b);
        if (dayMax > maxAlarm) { maxAlarm = dayMax; highestAlerts.clear(); highestAlerts.add('Pluie'); }
      }
    }
    if (_drought != null) {
      final r = (_drought!['predictions'] as List).map((e) => e['drought_risk'] as num).cast<double>().toList();
      if (r.isNotEmpty) {
        final dayMax = r.reduce((a, b) => a > b ? a : b);
        if (dayMax > maxAlarm) { maxAlarm = dayMax; highestAlerts.clear(); highestAlerts.add('Sécheresse'); }
        else if (dayMax == maxAlarm) highestAlerts.add('Sécheresse');
      }
    }
    if (_disease != null) {
      final r = (_disease!['predictions'] as List).map((e) => e['disease_risk'] as num).cast<double>().toList();
      if (r.isNotEmpty) {
        final dayMax = r.reduce((a, b) => a > b ? a : b);
        if (dayMax > maxAlarm) { maxAlarm = dayMax; highestAlerts.clear(); highestAlerts.add('Maladie'); }
        else if (dayMax == maxAlarm) highestAlerts.add('Maladie');
      }
    }
    if (_irrigation != null) {
      final r = (_irrigation!['predictions'] as List).map((e) => e['water_need_mm'] as num).cast<double>().toList();
      if (r.isNotEmpty) {
        final dayMax = r.reduce((a, b) => a > b ? a : b);
        final norm = (dayMax / 10.0).clamp(0.0, 1.0);
        if (norm > maxAlarm) { maxAlarm = norm; highestAlerts.clear(); highestAlerts.add('Irrigation'); }
      }
    }

    final alertText = (highestAlerts.isEmpty)
        ? "Aucun risque majeur détecté"
        : "Alerte: ${highestAlerts.join(' / ')} (${(maxAlarm*100).toStringAsFixed(0)}%)";

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
              child: Lottie.asset(
                'assets/lottie/summary.json',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.location_on),
                      Expanded(
                          child: Text(
                            "${_localite}  : Champs de ${_culture}",
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                      style: TextStyle(
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
                          "Pluie",
                          Icons.beach_access, // Alternative pour parapluie
                          Colors.blue,
                          const RainForecastPage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQuickActionButton(
                          "Sécheresse",
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
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateTo(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  Widget _buildMetricCard(String title, String value, String subtitle, IconData icon, Color color, VoidCallback onTap) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                  const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
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
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FDFA),
      appBar: AppBar(
        title: const Text(
          "AgriPredict",
          style: TextStyle(
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
            tooltip: "Actualiser",
          ),
        ],
      ),
      body: _loading
          ? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/lottie/loading.json',
              width: 100,
              height: 100,
            ),
            const SizedBox(height: 16),
            const Text(
              "Chargement des données...",
              style: TextStyle(fontSize: 16, color: Colors.grey),
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
                  Text("Prédictions",
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                          letterSpacing: 0.5)),
                ],
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85,
                children: [
                  _buildMetricCard(
                    "Risque Pluie",
                    _summaryLine(_rain, "rain_risk"),
                    "Probabilité moyenne",
                    Icons.beach_access, // Alternative pour parapluie
                    Colors.blue,
                        () => _navigateTo(const RainForecastPage()),
                  ),
                  _buildMetricCard(
                    "Risque Sécheresse",
                    _summaryLine(_drought, "drought_risk"),
                    "Niveau d'alerte",
                    Icons.wb_sunny,
                    Colors.orange,
                        () => _navigateTo(const DroughtForecastPage()),
                  ),
                  _buildMetricCard(
                    "Besoin Irrigation",
                    _summaryLine(_irrigation, "water_need_mm"),
                    "Moyenne quotidienne",
                    Icons.water_drop,
                    Colors.lightBlue,
                        () => _navigateTo(const IrrigationForecastPage()),
                  ),
                  _buildMetricCard(
                    "Risque Maladies",
                    _summaryLine(_disease, "disease_risk"),
                    "Probabilité moyenne",
                    Icons.eco,
                    Colors.green,
                        () => _navigateTo(const DiseaseForecastPage()),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Trends Section
             /* const Text(
                "Tendances des 3 prochains jours",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Column(
                children: [
                  if (_rain != null)
                    _buildTrendChart(
                      "Probabilité de Pluie",
                      _extractSeries(_rain, 'rain_risk', multiply: 100),
                      Colors.blue,
                    ),
                  const SizedBox(height: 12),
                  if (_irrigation != null)
                    _buildTrendChart(
                      "Besoins en Irrigation (mm)",
                      _extractSeries(_irrigation, 'water_need_mm'),
                      Colors.lightBlue,
                    ),
                  const SizedBox(height: 12),
                  if (_disease != null)
                    _buildTrendChart(
                      "Risque de Maladies",
                      _extractSeries(_disease, 'disease_risk', multiply: 100),
                      Colors.green,
                    ),
                ],
              ),
              const SizedBox(height: 20),*/

              // Status Message
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
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.grey[600],
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: TextStyle(color: Colors.grey[700]),
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

  String _summaryLine(Map<String, dynamic>? modelResp, String key) {
    if (modelResp == null) return "N/A";
    try {
      final preds = (modelResp['predictions'] as List)
          .map((e) => e[key] as num)
          .cast<double>()
          .toList();
      if (preds.isEmpty) return "N/A";

      final maxValue = preds.reduce((a, b) => a > b ? a : b);

      if (maxValue <= 1.0) {
        return "${(maxValue * 100).toStringAsFixed(0)}%";
      } else {
        return "${maxValue.toStringAsFixed(1)} mm";
      }
    } catch (e) {
      return "N/A";
    }
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
}