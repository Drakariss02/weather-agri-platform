import 'package:flutter/material.dart';

class AlertScreen extends StatelessWidget {
  const AlertScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> alerts = [
      {"type": "Pluie", "message": "Risque de forte pluie dans 3h", "date": "17 Oct 2025"},
      {"type": "Sécheresse", "message": "Humidité faible depuis 5 jours", "date": "15 Oct 2025"},
      {"type": "Maladie", "message": "Risque de mildiou sur le champ de maïs", "date": "14 Oct 2025"},
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Alertes & Notifications"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: alerts.length,
          itemBuilder: (context, index) {
            final alert = alerts[index];
            return Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: Icon(
                  alert["type"] == "Pluie"
                      ? Icons.water_drop
                      : alert["type"] == "Sécheresse"
                          ? Icons.wb_sunny
                          : Icons.bug_report,
                  color: Colors.green,
                ),
                title: Text(alert["type"]!),
                subtitle: Text(alert["message"]!),
                trailing: Text(
                  alert["date"]!,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
