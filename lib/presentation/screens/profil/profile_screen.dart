import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Profil & Paramètres"),
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
            const Text(
              "Mamadou Ndiaye",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text("mamadou.ndiaye@example.com"),
            const SizedBox(height: 30),

            // 🔧 Paramètres d’alerte
            ListTile(
              leading: const Icon(Icons.notifications_active),
              title: const Text("Gérer les alertes"),
              subtitle: const Text("SMS, WhatsApp ou App"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),

            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text("Modifier le mot de passe"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),

            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                minimumSize: const Size(double.infinity, 50),
              ),
              icon: const Icon(Icons.logout),
              label: const Text("Déconnexion"),
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
