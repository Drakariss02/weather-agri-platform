import 'package:flutter/material.dart';
import 'package:meteo_agro_app/presentation/screens/auth/register_step1_screen.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/auth/register_screen.dart';
import 'presentation/screens/champs/champs_screen.dart';
import 'presentation/screens/alert/alert_screen.dart';
import 'presentation/screens/profil/profile_screen.dart';
import 'pages/rain_prediction_page.dart';
import 'pages/drought_forecast_page.dart';
import 'pages/irrigation_forecast_page.dart';
import 'pages/disease_forecast_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/main_navigation_screen.dart';
import 'presentation/screens/auth/login_page.dart';
void main() {
  runApp(const MeteoAgriApp());
}

class MeteoAgriApp extends StatelessWidget {
  const MeteoAgriApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Météo & Agri',
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginPage(),
        '/register': (context) => const RegisterStep1(),
        '/home': (context) => const MainNavigationScreen(),
        '/champs': (context) =>   ChampsScreen(),
        //'/alert': (context) => const AlertScreen(),
       '/profile': (context) => const ProfileScreen(),
        '/pluie': (context) => const RainForecastPage(),
        '/secheresse': (context) => const DroughtForecastPage(),
        '/irrigation': (context) => const IrrigationForecastPage(),
        '/maladie': (context) => const DiseaseForecastPage(),
      },
    );
  }
}
