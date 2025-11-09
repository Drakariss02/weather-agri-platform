import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/translation_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _nomComplet;
  String? _numero;
  String _currentLang = TranslationService.currentLang;

  final Map<String, String> _languages = {
    'fr': 'Français',
    'wolof': 'Wolof',
    'peul': 'Peul/Pulaar',
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nomComplet = prefs.getString('nom_complet') ?? "";
      _numero = prefs.getString('numero') ?? "";
      _currentLang = prefs.getString('langue') ?? TranslationService.currentLang;
    });
  }

  Future<void> _changeLanguage(String langCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('langue', langCode);
    setState(() {
      _currentLang = langCode;
      TranslationService.setLanguage(langCode);
    });
    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(TranslationService.tr('profile_title') ?? "Profil & Paramètres"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundImage: AssetImage('assets/images/user.png'),
            ),
            const SizedBox(height: 16),
            Text(
              _nomComplet ?? "",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(_numero ?? ""),
            const SizedBox(height: 30),

            ListTile(
              leading: const Icon(Icons.notifications_active),
              title: Text(TranslationService.tr('manage_alerts') ?? "Gérer les alertes"),
              subtitle: Text(TranslationService.tr('manage_alerts_sub') ?? "SMS, WhatsApp ou App"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),

            ListTile(
              leading: const Icon(Icons.lock),
              title: Text(TranslationService.tr('change_password') ?? "Modifier le mot de passe"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),

            const SizedBox(height: 20),

            //  Sélecteur de langue
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(TranslationService.tr('language') ?? "Langue"),
              trailing: DropdownButton<String>(
                value: _currentLang,
                items: _languages.entries
                    .map((entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) _changeLanguage(value);
                },
              ),
            ),

            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 50),
              ),
              icon: const Icon(Icons.logout),
              label: Text(TranslationService.tr('logout') ?? "Déconnexion"),
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/');
              },
            ),
          ],
        ),
      ),
    );
  }
}
