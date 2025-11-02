import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/api_service.dart';

class ChampsScreen extends StatefulWidget {
  const ChampsScreen({super.key});

  @override
  State<ChampsScreen> createState() => _ChampsScreenState();
}

class _ChampsScreenState extends State<ChampsScreen> {
  List<Map<String, dynamic>> champs = [];
  int? selectedChampId;

  final TextEditingController cultureCtrl = TextEditingController();
  final TextEditingController superficieCtrl = TextEditingController();
  final TextEditingController dateSemiCtrl = TextEditingController();
  final TextEditingController localiteCtrl = TextEditingController();
  final TextEditingController latCtrl = TextEditingController();
  final TextEditingController lonCtrl = TextEditingController();

  int? editingIndex;

  @override
  void initState() {
    super.initState();
    _loadChamps();
  }

  Future<void> _loadChamps() async {
    final prefs = await SharedPreferences.getInstance();
    final idAgriculteur = prefs.getInt('id_agriculteur');
    if (idAgriculteur == null) return;

    selectedChampId = prefs.getInt('selected_champ_id');

    try {
      final result = await ApiService.getChampsByAgriculteur(idAgriculteur);
      setState(() => champs = List<Map<String, dynamic>>.from(result));
      await _saveChamps();
    } catch (e) {
      final saved = prefs.getString('champs');
      if (saved != null) {
        setState(() => champs = List<Map<String, dynamic>>.from(jsonDecode(saved)));
      }
    }
  }

  Future<void> _saveChamps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('champs', jsonEncode(champs));
  }

  Future<void> _selectChamp(Map<String, dynamic> champ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('selected_champ_id', champ['id']);
    await prefs.setDouble('lat', champ['latitude'] ?? 0.0);
    await prefs.setDouble('lon', champ['longitude'] ?? 0.0);
    await prefs.setString('localite', champ['localite'] ?? "Inconnue");
    await prefs.setString('culture', champ['culture'] ?? "Inconnue");

    setState(() {
      selectedChampId = champ['id'];
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Champ '${champ['culture']}' sélectionné ✅\n"
              "Lat: ${champ['latitude']} | Lon: ${champ['longitude']}",
        ),
        backgroundColor: Colors.green[700],
      ),
    );
  }

  Future<void> _ajouterOuModifierChamp() async {
    if (cultureCtrl.text.isEmpty ||
        superficieCtrl.text.isEmpty ||
        dateSemiCtrl.text.isEmpty ||
        localiteCtrl.text.isEmpty ||
        latCtrl.text.isEmpty ||
        lonCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Veuillez remplir tous les champs"),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final idAgriculteur = prefs.getInt('id_agriculteur');
      if (idAgriculteur == null) throw Exception("Utilisateur non connecté");

      final champData = {
        "culture": cultureCtrl.text,
        "superficie": double.parse(superficieCtrl.text),
        "date_semi": DateTime.parse(dateSemiCtrl.text).toIso8601String(),
        "localite": localiteCtrl.text,
        "latitude": double.parse(latCtrl.text),
        "longitude": double.parse(lonCtrl.text),
        "id_agriculteur": idAgriculteur,
      };

      if (editingIndex == null) {
        final res = await ApiService.createChamp(champData);
        final newChamp = {...champData, "id": res["id"]};
        setState(() {
          champs.add(newChamp);
        });
      } else {
        final champId = champs[editingIndex!]["id"];
        final res = await ApiService.updateChamp(champId, champData);
        setState(() {
          champs[editingIndex!] = res;
        });
      }

      await _saveChamps();
      _viderFormulaire();
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur: $e"),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  void _viderFormulaire() {
    cultureCtrl.clear();
    superficieCtrl.clear();
    dateSemiCtrl.clear();
    localiteCtrl.clear();
    latCtrl.clear();
    lonCtrl.clear();
    editingIndex = null;
  }

  void _ouvrirFormulaire({int? index}) {
    if (index != null) {
      final champ = champs[index];
      editingIndex = index;
      cultureCtrl.text = champ["culture"] ?? "";
      superficieCtrl.text = champ["superficie"]?.toString() ?? "";
      localiteCtrl.text = champ["localite"] ?? "";
      latCtrl.text = champ["latitude"]?.toString() ?? "";
      lonCtrl.text = champ["longitude"]?.toString() ?? "";
      dateSemiCtrl.text = champ["date_semi"]?.toString().split('T')[0] ?? "";
    } else {
      _viderFormulaire();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    height: 5,
                    width: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  editingIndex == null
                      ? "Ajouter un Champ 🌾"
                      : "Modifier le Champ ✏️",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                const SizedBox(height: 12),
                _buildInput(cultureCtrl, "Culture (ex: Maïs, Riz...)", Icons.eco),
                const SizedBox(height: 12),
                _buildInput(superficieCtrl, "Superficie (ha)", Icons.square_foot,
                    keyboard: TextInputType.number),
                const SizedBox(height: 12),
                TextField(
                  controller: dateSemiCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: "Date de semis",
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (date != null) {
                      setState(() {
                        dateSemiCtrl.text = date.toIso8601String().split('T')[0];
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                _buildInput(localiteCtrl, "Localité", Icons.location_on),
                const SizedBox(height: 12),
                _buildInput(latCtrl, "Latitude", Icons.gps_fixed,
                    keyboard: TextInputType.number),
                const SizedBox(height: 12),
                _buildInput(lonCtrl, "Longitude", Icons.gps_fixed_outlined,
                    keyboard: TextInputType.number),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _ajouterOuModifierChamp,
                    icon: const Icon(Icons.save),
                    label: Text(editingIndex == null
                        ? "Enregistrer le champ"
                        : "Mettre à jour"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInput(TextEditingController controller, String label, IconData icon,
      {TextInputType keyboard = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.green[700]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _supprimerChamp(int index) async {
    final champ = champs[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Supprimer ce champ ?"),
        content: Text("Voulez-vous supprimer ${champ["culture"]}?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Annuler")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Supprimer"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ApiService.deleteChamp(champ["id"]);
        setState(() => champs.removeAt(index));
        await _saveChamps();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : $e"), backgroundColor: Colors.red[700]),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mes Champs"),
        backgroundColor: Colors.green[700],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ouvrirFormulaire(),
        icon: const Icon(Icons.add),
        label: const Text("Ajouter"),
        backgroundColor: Colors.green[700],
      ),
      body: champs.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.agriculture, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text("Aucun champ ajouté",
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: champs.length,
        itemBuilder: (context, i) {
          final champ = champs[i];
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Radio<int>(
                value: champ["id"],
                groupValue: selectedChampId,
                activeColor: Colors.green[700],
                onChanged: (_) => _selectChamp(champ),
              ),
              title: Text(champ["culture"] ?? "Culture"),
              subtitle: Text("${champ["localite"] ?? ''} — "
                  "${champ["superficie"] ?? ''} ha"),
              trailing: Wrap(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _ouvrirFormulaire(index: i),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _supprimerChamp(i),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
