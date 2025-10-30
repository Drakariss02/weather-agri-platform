import 'package:flutter/material.dart';

class MeteoScreen extends StatelessWidget {
  const MeteoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final champ = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(title: Text('Prévisions - ${champ?['nom'] ?? 'Inconnu'}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Localisation : ${champ?['localisation']}', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            const Text('Prévisions météo sur 3 jours', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: const [
                  ListTile(leading: Icon(Icons.wb_sunny), title: Text('Lundi : 30°C - Ensoleillé')),
                  ListTile(leading: Icon(Icons.cloud), title: Text('Mardi : 27°C - Nuageux')),
                  ListTile(leading: Icon(Icons.grain), title: Text('Mercredi : 25°C - Pluie légère')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
