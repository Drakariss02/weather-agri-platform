import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic>? champData;
  
  const HomeScreen({Key? key, this.champData}) : super(key: key);
  
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final String userName = "Mamadou Ndiaye";
  String location = "Saint-Louis, Sénégal";
  final double temperature = 32.5;
  final int humidity = 65;
  final String weather = "Ensoleillé";
  
  String champName = "Champ Principal";
  final TextEditingController _champController = TextEditingController();

  final List<String> alerts = [
    "Risque de sécheresse demain",
    "Pluie prévue dans 2 heures"
  ];

  final List<String> recommendations = [
    "Arroser le champ principal",
    "Vérifier les plants de maïs"
  ];

  final List<double> tempData = [28, 30, 32, 33, 31, 29, 27];
  final List<String> days = ["Lun", "Mar", "Mer", "Jeu", "Ven", "Sam", "Dim"];

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  @override
  void dispose() {
    _champController.dispose();
    super.dispose();
  }

  // Vérifier si c'est le premier lancement
  Future<void> _checkFirstLaunch() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
    String? savedChampName = prefs.getString('champName');
    
    if (savedChampName != null) {
      setState(() {
        champName = savedChampName;
      });
    }
    
    if (isFirstLaunch) {
      // Attendre que le widget soit complètement construit
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showChampNameDialog();
      });
    }
  }

  // Afficher le modal de configuration du nom du champ
  void _showChampNameDialog() {
    _champController.text = champName;
    
    showDialog(
      context: context,
      barrierDismissible: false, // Empêcher la fermeture en cliquant à l'extérieur
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(Icons.agriculture, color: Colors.green[700], size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Configuration du champ",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Votre champ s'appelle actuellement \"Champ Principal\".",
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              SizedBox(height: 8),
              Text(
                "Veuillez modifier le nom de votre champ :",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 16),
              TextField(
                controller: _champController,
                decoration: InputDecoration(
                  labelText: "Nom du champ",
                  hintText: "Ex: Mon Champ de Maïs",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.green[700]!, width: 2),
                  ),
                  prefixIcon: Icon(Icons.edit, color: Colors.green[700]),
                ),
                maxLength: 30,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _saveChampName(champName); // Garder "Champ Principal"
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
              ),
              child: Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () {
                String newName = _champController.text.trim();
                if (newName.isNotEmpty) {
                  _saveChampName(newName);
                  Navigator.of(context).pop();
                } else {
                  // Afficher un message d'erreur si le champ est vide
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Veuillez entrer un nom pour votre champ"),
                      backgroundColor: Colors.red[700],
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text("Modifier"),
            ),
          ],
        );
      },
    );
  }

  // Sauvegarder le nom du champ et marquer comme non premier lancement
  Future<void> _saveChampName(String name) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('champName', name);
    await prefs.setBool('isFirstLaunch', false);
    
    setState(() {
      champName = name;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Le nom de votre champ a été enregistré : $name"),
        backgroundColor: Colors.green[700],
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _onTabTapped(int index) {
    if (index == 0) {
      setState(() {
        _currentIndex = index;
      });
    } else if (index == 1) {
      Navigator.pushNamed(context, '/pluie');
    } else if (index == 2) {
      Navigator.pushNamed(context, '/secheresse');
    } else if (index == 3) {
      Navigator.pushNamed(context, '/irrigation');
    } else if (index == 4) {
      Navigator.pushNamed(context, '/maladie');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;

    return Scaffold(
      appBar: AppBar(
        title: Text("Bonjour, $userName"),
        backgroundColor: Colors.green[700],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12.0 : 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWeatherCard(context, isMobile),
              SizedBox(height: isMobile ? 16 : 24),
              Text(
                "Prévisions de Température (7 jours)",
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              _buildTemperatureChart(context, isMobile),
              SizedBox(height: isMobile ? 16 : 24),
              if (isTablet)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildAlerts(isMobile)),
                    SizedBox(width: 16),
                    Expanded(child: _buildRecommendations(isMobile)),
                  ],
                )
              else ...[
                _buildAlerts(isMobile),
                SizedBox(height: isMobile ? 16 : 24),
                _buildRecommendations(isMobile),
              ],
              SizedBox(height: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.green[700],
        unselectedItemColor: Colors.grey,
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Accueil",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cloudy_snowing),
            label: "Pluie",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.wb_sunny),
            label: "Secheresse",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.opacity),
            label: "Irrigation",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.eco),
            label: "Maladie",
          ),
        ],
      ),
    );
  }

  // Widget pour la carte météo (avec le nom du champ)
  Widget _buildWeatherCard(BuildContext context, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[400]!, Colors.green[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 8,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16.0 : 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Affichage du nom du champ
            Row(
              children: [
                Icon(Icons.agriculture, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  champName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            isMobile
                ? Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                location,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                weather,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            Icons.wb_sunny,
                            size: 40,
                            color: Colors.yellow[300],
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  "${temperature.toStringAsFixed(1)}°C",
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  "Température",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  "$humidity%",
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  "Humidité",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            location,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            weather,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            "${temperature.toStringAsFixed(1)}°C",
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Humidité: $humidity%",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        Icons.wb_sunny,
                        size: 50,
                        color: Colors.yellow[300],
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  // Widget pour le graphique de température
  Widget _buildTemperatureChart(BuildContext context, bool isMobile) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        height: isMobile ? 200 : 280,
        padding: EdgeInsets.fromLTRB(isMobile ? 8 : 16, 16, isMobile ? 8 : 16, 8),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              horizontalInterval: 5,
              verticalInterval: 1,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey[300],
                  strokeWidth: 1,
                );
              },
              getDrawingVerticalLine: (value) {
                return FlLine(
                  color: Colors.grey[300],
                  strokeWidth: 1,
                );
              },
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    int index = value.toInt();
                    if (index >= 0 && index < days.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          days[index],
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                            fontSize: isMobile ? 10 : 12,
                          ),
                        ),
                      );
                    }
                    return Text('');
                  },
                  interval: 1,
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      '${value.toInt()}°',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 10 : 12,
                      ),
                    );
                  },
                  interval: 5,
                  reservedSize: isMobile ? 30 : 40,
                ),
              ),
              topTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
                left: BorderSide(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
            ),
            minY: 20,
            maxY: 35,
            lineBarsData: [
              LineChartBarData(
                spots: List.generate(
                  tempData.length,
                  (index) => FlSpot(
                    index.toDouble(),
                    tempData[index],
                  ),
                ),
                isCurved: true,
                gradient: LinearGradient(
                  colors: [
                    Colors.orange[400]!,
                    Colors.orange[600]!,
                  ],
                ),
                barWidth: isMobile ? 2 : 4,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: isMobile ? 3 : 5,
                      color: Colors.orange[700]!,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange[400]!.withOpacity(0.3),
                      Colors.orange[600]!.withOpacity(0.1),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
            lineTouchData: LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                  return touchedBarSpots.map((barSpot) {
                    return LineTooltipItem(
                      '${barSpot.y.toStringAsFixed(0)}°C',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    );
                  }).toList();
                },
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildAlerts(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "⚠️ Alertes Importantes",
          style: TextStyle(
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        Column(
          children: alerts
              .map((alert) => Container(
                    margin: EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      border: Border(
                        left: BorderSide(
                          color: Colors.red[700]!,
                          width: 4,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.all(isMobile ? 8 : 12),
                      leading: Icon(
                        Icons.warning_rounded,
                        color: Colors.red[700],
                        size: isMobile ? 20 : 28,
                      ),
                      title: Text(
                        alert,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: isMobile ? 13 : 15,
                        ),
                      ),
                      trailing: isMobile
                          ? null
                          : Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.red[400],
                            ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // Widget pour les recommandations
  Widget _buildRecommendations(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "💡 Recommandations",
          style: TextStyle(
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        Column(
          children: recommendations
              .map((rec) => Container(
                    margin: EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      border: Border(
                        left: BorderSide(
                          color: Colors.blue[700]!,
                          width: 4,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.all(isMobile ? 8 : 12),
                      leading: Icon(
                        Icons.agriculture,
                        color: Colors.green[700],
                        size: isMobile ? 20 : 28,
                      ),
                      title: Text(
                        rec,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: isMobile ? 13 : 15,
                        ),
                      ),
                      trailing: isMobile
                          ? null
                          : Icon(
                              Icons.check_circle,
                              size: 20,
                              color: Colors.green[600],
                            ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}