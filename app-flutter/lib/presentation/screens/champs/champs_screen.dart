import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChampsScreen extends StatefulWidget {
  const ChampsScreen({super.key});

  @override
  State<ChampsScreen> createState() => _ChampsScreenState();
}

class _ChampsScreenState extends State<ChampsScreen> {
  List<Map<String, dynamic>> champs = [];

  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _cultureController = TextEditingController();
  final TextEditingController _localisationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadChamps();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _cultureController.dispose();
    _localisationController.dispose();
    super.dispose();
  }

  // Charger les champs sauvegardés
  Future<void> _loadChamps() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedChamps = prefs.getStringList('champs');
    
    if (savedChamps != null && savedChamps.isNotEmpty) {
      setState(() {
        champs = savedChamps.map((champStr) {
          List<String> parts = champStr.split('|');
          return {
            'nom': parts[0],
            'culture': parts[1],
            'localisation': parts[2],
          };
        }).toList();
      });
    } else {
      // Champs par défaut
      setState(() {
        champs = [
          {'nom': 'Champ Principal', 'culture': 'Maïs', 'localisation': 'Saint-Louis, Sénégal'},
          {'nom': 'Champ de mil', 'culture': 'Mil', 'localisation': 'Thiès, Sénégal'},
        ];
      });
      _saveChamps();
    }
  }

  // Sauvegarder les champs
  Future<void> _saveChamps() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> champsStr = champs.map((champ) {
      return '${champ['nom']}|${champ['culture']}|${champ['localisation']}';
    }).toList();
    await prefs.setStringList('champs', champsStr);
  }

  void _ajouterChamp() {
    if (_nomController.text.isEmpty || 
        _cultureController.text.isEmpty || 
        _localisationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Veuillez remplir tous les champs"),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }

    setState(() {
      champs.add({
        'nom': _nomController.text,
        'culture': _cultureController.text,
        'localisation': _localisationController.text,
      });
    });
    
    _saveChamps();
    _nomController.clear();
    _cultureController.clear();
    _localisationController.clear();
    Navigator.pop(context);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Champ ajouté avec succès"),
        backgroundColor: Colors.green[700],
      ),
    );
  }

  void _supprimerChamp(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Confirmer la suppression"),
          content: Text("Voulez-vous vraiment supprimer ce champ ?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Annuler"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  champs.removeAt(index);
                });
                _saveChamps();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Champ supprimé"),
                    backgroundColor: Colors.orange[700],
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
              ),
              child: Text("Supprimer"),
            ),
          ],
        );
      },
    );
  }

  void _modifierChamp(int index) {
    _nomController.text = champs[index]['nom'];
    _cultureController.text = champs[index]['culture'];
    _localisationController.text = champs[index]['localisation'];

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Row(
          children: [
            Icon(Icons.edit, color: Colors.green[700]),
            SizedBox(width: 10),
            Text('Modifier le champ'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nomController,
                decoration: InputDecoration(
                  labelText: 'Nom du champ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Icon(Icons.agriculture),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _cultureController,
                decoration: InputDecoration(
                  labelText: 'Culture',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Icon(Icons.eco),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _localisationController,
                decoration: InputDecoration(
                  labelText: 'Localisation',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _nomController.clear();
              _cultureController.clear();
              _localisationController.clear();
              Navigator.pop(context);
            },
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                champs[index] = {
                  'nom': _nomController.text,
                  'culture': _cultureController.text,
                  'localisation': _localisationController.text,
                };
              });
              _saveChamps();
              _nomController.clear();
              _cultureController.clear();
              _localisationController.clear();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Champ modifié avec succès"),
                  backgroundColor: Colors.green[700],
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
            ),
            child: Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _ouvrirFormulaireAjout() {
    _nomController.clear();
    _cultureController.clear();
    _localisationController.clear();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Row(
          children: [
            Icon(Icons.add_circle, color: Colors.green[700]),
            SizedBox(width: 10),
            Text('Ajouter un champ'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nomController,
                decoration: InputDecoration(
                  labelText: 'Nom du champ',
                  hintText: 'Ex: Mon Champ de Maïs',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Icon(Icons.agriculture),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _cultureController,
                decoration: InputDecoration(
                  labelText: 'Culture',
                  hintText: 'Ex: Maïs, Mil, Arachide, Riz',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Icon(Icons.eco),
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _localisationController,
                decoration: InputDecoration(
                  labelText: 'Localisation',
                  hintText: 'Ex: Kaolack, Sénégal',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: _ajouterChamp,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
            ),
            child: Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _selectionnerChamp(Map<String, dynamic> champ) {
    // Naviguer vers HomeScreen avec les données du champ
    Navigator.pushReplacementNamed(
      context,
      '/home',
      arguments: champ,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text('Gestion des Champs'),
        backgroundColor: Colors.green[700],
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ouvrirFormulaireAjout,
        backgroundColor: Colors.green[700],
        icon: Icon(Icons.add),
        label: Text(isMobile ? 'Ajouter' : 'Ajouter un champ'),
      ),
      body: champs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.agriculture,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Aucun champ enregistré',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Appuyez sur + pour ajouter un champ',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(isMobile ? 8 : 16),
              itemCount: champs.length,
              itemBuilder: (context, index) {
                final champ = champs[index];
                return Card(
                  margin: EdgeInsets.only(bottom: 12),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () => _selectionnerChamp(champ),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.agriculture,
                                  color: Colors.green[700],
                                  size: 28,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      champ['nom'],
                                      style: TextStyle(
                                        fontSize: isMobile ? 16 : 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[800],
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(Icons.eco, size: 14, color: Colors.grey[600]),
                                        SizedBox(width: 4),
                                        Text(
                                          champ['culture'],
                                          style: TextStyle(
                                            fontSize: isMobile ? 13 : 14,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                                        SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            champ['localisation'],
                                            style: TextStyle(
                                              fontSize: isMobile ? 12 : 13,
                                              color: Colors.grey[600],
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: () => _selectionnerChamp(champ),
                                icon: Icon(Icons.visibility, size: 18),
                                label: Text('Voir météo'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.green[700],
                                ),
                              ),
                              SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.edit, color: Colors.blue[700]),
                                onPressed: () => _modifierChamp(index),
                                tooltip: 'Modifier',
                              ),
                              IconButton(
                                icon: Icon(Icons.delete, color: Colors.red[700]),
                                onPressed: () => _supprimerChamp(index),
                                tooltip: 'Supprimer',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}