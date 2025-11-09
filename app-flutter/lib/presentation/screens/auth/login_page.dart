import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/api_service.dart';
import '../../../pages/dashboard_page.dart';
import '../../../services/translation_service.dart';
import 'register_step1_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final telCtrl = TextEditingController();
  final mdpCtrl = TextEditingController();
  bool loading = false;

  Future<void> _login() async {
    setState(() => loading = true);
    try {
      final res = await ApiService.login(telCtrl.text, mdpCtrl.text);
      final prefs = await SharedPreferences.getInstance();

      final int idAgriculteur = res['id'];
      await prefs.setInt('id_agriculteur', idAgriculteur);
      await prefs.setString('nom_complet', res['nom_complet']);
      await prefs.setString('numero', res['telephone']);
      await prefs.setString('langue', res['langue']);
      TranslationService.setLanguage(res['langue']);

      final champ = await ApiService.getChampByAgriculteur(idAgriculteur);

      if (champ != null) {
        await prefs.setDouble("lat", champ["latitude"]);
        await prefs.setDouble("lon", champ["longitude"]);
        await prefs.setString("culture", champ["culture"]);
        await prefs.setString("localite", champ["localite"]);
        await prefs.setInt("id_champ_principal", champ["id"]);
      }

      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur : $e")),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.agriculture, size: 80, color: Colors.green),
              const SizedBox(height: 16),
              Text("Connexion",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold, color: Colors.green[800])),
              const SizedBox(height: 24),
              TextField(
                controller: telCtrl,
                decoration: const InputDecoration(labelText: "Téléphone"),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: mdpCtrl,
                decoration: const InputDecoration(labelText: "Mot de passe"),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: loading ? null : _login,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, minimumSize: const Size.fromHeight(50)),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Se connecter"),
              ),
              TextButton(
                  onPressed: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const RegisterStep1()));
                  },
                  child: const Text("Créer un compte"))
            ],
          ),
        ),
      ),
    );
  }
}
