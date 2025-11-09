// lib/presentation/screens/champs/champs_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/api_service.dart';
import '../../../services/translation_service.dart';
import '../../../constants.dart';

class ChampsScreen extends StatefulWidget {
  const ChampsScreen({super.key});

  @override
  State<ChampsScreen> createState() => _ChampsScreenState();
}

class _ChampsScreenState extends State<ChampsScreen> {
  List<Map<String, dynamic>> champs = [];
  bool _loading = true;
  int? selectedChampId;

  final TextEditingController cultureCtrl = TextEditingController();
  final TextEditingController superficieCtrl = TextEditingController();
  final TextEditingController dateSemiCtrl = TextEditingController();
  final TextEditingController localiteCtrl = TextEditingController();
  final TextEditingController latCtrl = TextEditingController();
  final TextEditingController lonCtrl = TextEditingController();

  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;
  bool _isSearchingLocalite = false;

  int? _editingChampId;

  @override
  void initState() {
    super.initState();
    _loadChamps();
  }

  @override
  void dispose() {
    cultureCtrl.dispose();
    superficieCtrl.dispose();
    dateSemiCtrl.dispose();
    localiteCtrl.dispose();
    latCtrl.dispose();
    lonCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadChamps() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final idAgriculteur = prefs.getInt('id_agriculteur');
      selectedChampId = prefs.getInt('selected_champ_id');

      if (idAgriculteur == null) {
        throw Exception(TranslationService.tr('champs_no_user') ?? "Aucun utilisateur connecté");
      }

      final res = await ApiService.getChampsByAgriculteur(idAgriculteur);
      setState(() {
        champs = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });

      await _saveChampsCache();
    } catch (e) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString('champs');
        if (saved != null) {
          setState(() {
            champs = List<Map<String, dynamic>>.from(jsonDecode(saved));
          });
        }
      } catch (_) {}

      print("Erreur chargement champs: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${TranslationService.tr('champs_load_error') ?? "Impossible de charger les champs"}: $e",
              style: GoogleFonts.notoSans(),
            ),
          ),
        );
      }
      setState(() => _loading = false);
    }
  }

  Future<void> _saveChampsCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('champs', jsonEncode(champs));
  }

  Future<void> _selectChamp(Map<String, dynamic> champ) async {
    final prefs = await SharedPreferences.getInstance();

    final id = champ['id'] is int ? champ['id'] as int : int.tryParse(champ['id']?.toString() ?? '');
    final lat = (champ['latitude'] is num) ? (champ['latitude'] as num).toDouble() : double.tryParse(champ['latitude']?.toString() ?? '') ?? 0.0;
    final lng = (champ['longitude'] is num) ? (champ['longitude'] as num).toDouble() : double.tryParse(champ['longitude']?.toString() ?? '') ?? 0.0;
    final localite = champ['localite'];
    final culture = champ['culture'];

    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            TranslationService.tr('champs_select_error') ?? "Impossible de sélectionner: ID manquant",
            style: GoogleFonts.notoSans(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await prefs.setInt('selected_champ_id', id);
    await prefs.setDouble('lat', lat);
    await prefs.setDouble('lon', lng);
    await prefs.setString('culture', culture);
    await prefs.setString('localite', localite);

    setState(() {
      selectedChampId = id;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${TranslationService.tr('champs_selected') ?? "Champ"} '${champ['culture'] ?? ''}' ${TranslationService.tr('champs_selected_suffix') ?? "sélectionné ✅"} (Lat: $lat, Lon: $lng)",
            style: GoogleFonts.notoSans(),
          ),
          backgroundColor: Colors.green[700],
        ),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _searchLocalites(String q) async {
    if (q.trim().length < 2) return [];
    final username = GEONAMES_USERNAME;
    final encoded = Uri.encodeComponent(q);
    final url =
        'https://secure.geonames.org/searchJSON?name_startsWith=$encoded&maxRows=10&username=$username&continentCode=AF&featureClass=P';
    final uri = Uri.parse(url);

    final resp = await http.get(uri).timeout(const Duration(seconds: 15), onTimeout: () {
      throw Exception(TranslationService.tr('champs_geonames_timeout') ?? 'Délai dépassé lors de la recherche GeoNames');
    });

    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      final List items = body['geonames'] ?? [];
      return items.map<Map<String, dynamic>>((it) {
        final name = it['name'] ?? '';
        final admin = it['adminName1'] ?? '';
        final country = it['countryName'] ?? '';
        final lat = it['lat'] ?? it['latitude'] ?? '';
        final lng = it['lng'] ?? it['longitude'] ?? '';

        final display = [name, admin, country].where((s) => s != null && s.toString().isNotEmpty).join(', ');
        return {
          'display': display,
          'name': name,
          'admin': admin,
          'country': country,
          'lat': lat.toString(),
          'lng': lng.toString(),
        };
      }).toList();
    } else {
      throw Exception('${TranslationService.tr('champs_geonames_error') ?? "Erreur GeoNames"}: ${resp.statusCode}');
    }
  }

  void _onLocaliteChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _suggestions = [];
        _isSearchingLocalite = false;
      });
      return;
    }

    setState(() {
      _isSearchingLocalite = true;
    });

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final res = await _searchLocalites(value);
        setState(() {
          _suggestions = res;
        });
      } catch (e) {
        print("Erreur recherche localités: $e");
        setState(() {
          _suggestions = [];
        });
      } finally {
        setState(() {
          _isSearchingLocalite = false;
        });
      }
    });
  }

  void _selectLocalite(Map<String, dynamic> item) {
    setState(() {
      localiteCtrl.text = item['display'] ?? item['name'] ?? '';
      latCtrl.text = item['lat'] ?? '';
      lonCtrl.text = item['lng'] ?? '';
      _suggestions = [];
    });
  }

  Future<void> _ajouterChamp() async {
    if (cultureCtrl.text.isEmpty ||
        superficieCtrl.text.isEmpty ||
        dateSemiCtrl.text.isEmpty ||
        localiteCtrl.text.isEmpty ||
        latCtrl.text.isEmpty ||
        lonCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            TranslationService.tr('champs_fill_all') ?? "Veuillez remplir tous les champs",
            style: GoogleFonts.notoSans(),
          ),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final idAgr = prefs.getInt('id_agriculteur');
      if (idAgr == null) throw Exception(TranslationService.tr('champs_no_user') ?? "Utilisateur non connecté");

      final Map<String, dynamic> champData = {
        "culture": cultureCtrl.text.trim(),
        "superficie": double.tryParse(superficieCtrl.text.replaceAll(',', '.')) ?? 0.0,
        "date_semi": dateSemiCtrl.text,
        "localite": localiteCtrl.text.trim(),
        "latitude": double.parse(latCtrl.text),
        "longitude": double.parse(lonCtrl.text),
        "id_agriculteur": idAgr,
      };

      final res = await ApiService.createChamp(champData);

      int? createdId;
      if (res is Map) {
        if (res.containsKey('champ_id')) {
          createdId = (res['champ_id'] is int) ? res['champ_id'] as int : int.tryParse(res['champ_id']?.toString() ?? '');
        } else if (res.containsKey('id')) {
          createdId = (res['id'] is int) ? res['id'] as int : int.tryParse(res['id']?.toString() ?? '');
        }
      }

      setState(() {
        champs.add({
          "id": createdId,
          "culture": champData['culture'],
          "superficie": champData['superficie'],
          "date_semi": champData['date_semi'],
          "localite": champData['localite'],
          "latitude": champData['latitude'],
          "longitude": champData['longitude'],
          "id_agriculteur": champData['id_agriculteur'],
        });
      });
      await _saveChampsCache();

      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslationService.tr('champs_add_success') ?? "Champ ajouté avec succès ✅",
              style: GoogleFonts.notoSans(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      _clearForm();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${TranslationService.tr('error') ?? "Erreur"}: $e",
              style: GoogleFonts.notoSans(),
            ),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  void _ouvrirFormulaireModification(int index) {
    final champ = champs[index];
    _editingChampId = (champ['id'] is int) ? champ['id'] as int : int.tryParse(champ['id']?.toString() ?? '');
    cultureCtrl.text = champ['culture']?.toString() ?? '';
    superficieCtrl.text = (champ['superficie']?.toString() ?? '');
    dateSemiCtrl.text = champ['date_semi']?.toString() ?? '';
    localiteCtrl.text = champ['localite']?.toString() ?? '';
    latCtrl.text = (champ['latitude']?.toString() ?? '');
    lonCtrl.text = (champ['longitude']?.toString() ?? '');
    _showFormSheet();
  }

  Future<void> _modifierChamp(int id, Map<String, dynamic> data) async {
    try {
      await ApiService.updateChamp(id, data);
      await _loadChamps();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslationService.tr('champs_edit_success') ?? "Champ modifié avec succès ✅",
              style: GoogleFonts.notoSans(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${TranslationService.tr('champs_edit_error') ?? "Erreur de modification"}: $e",
              style: GoogleFonts.notoSans(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _supprimerChamp(int id) async {
    try {
      await ApiService.deleteChamp(id);
      await _loadChamps();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslationService.tr('champs_delete_success') ?? "Champ supprimé ✅",
              style: GoogleFonts.notoSans(),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "${TranslationService.tr('champs_delete_error') ?? "Erreur suppression"}: $e",
              style: GoogleFonts.notoSans(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearForm() {
    cultureCtrl.clear();
    superficieCtrl.clear();
    dateSemiCtrl.clear();
    localiteCtrl.clear();
    latCtrl.clear();
    lonCtrl.clear();
    _editingChampId = null;
    _suggestions = [];
  }

  void _showFormSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final isEditing = _editingChampId != null;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
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
                      const SizedBox(height: 12),
                      Text(
                        isEditing
                            ? TranslationService.tr('champs_edit_title') ?? "Modifier le champ"
                            : TranslationService.tr('champs_add_title') ?? "Ajouter un Champ",
                        style: GoogleFonts.notoSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInput(cultureCtrl, TranslationService.tr('champs_culture_label') ?? "Culture (ex: Maïs, Riz...)", Icons.eco),
                      const SizedBox(height: 12),
                      _buildInput(
                        superficieCtrl,
                        TranslationService.tr('champs_area_label') ?? "Superficie (ha)",
                        Icons.square_foot,
                        keyboard: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: dateSemiCtrl,
                        readOnly: true,
                        style: GoogleFonts.notoSans(),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.calendar_today),
                          labelText: TranslationService.tr('champs_sowing_date') ?? "Date de semis",
                          labelStyle: GoogleFonts.notoSans(),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: DateTime.tryParse(dateSemiCtrl.text) ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2035),
                          );
                          if (date != null) {
                            setModalState(() {
                              dateSemiCtrl.text = date.toIso8601String().split('T')[0];
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // --- Autocomplete localité ---
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: localiteCtrl,
                            style: GoogleFonts.notoSans(),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.location_city),
                              labelText: TranslationService.tr('champs_location_label') ?? "Localité (autocomplétion)",
                              labelStyle: GoogleFonts.notoSans(),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onChanged: (value) {
                              _onLocaliteChanged(value);
                              setModalState(() {});
                            },
                          ),
                          const SizedBox(height: 6),

                          if (_isSearchingLocalite)
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: LinearProgressIndicator(),
                            ),

                          if (_suggestions.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: ListView.builder(
                                shrinkWrap: true,
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: _suggestions.length,
                                itemBuilder: (ctx, idx) {
                                  final it = _suggestions[idx];
                                  return ListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    title: Text(
                                      it['display'] ?? TranslationService.tr('champs_unknown_name') ?? 'Nom inconnu',
                                      style: GoogleFonts.notoSans(fontSize: 14),
                                    ),
                                    subtitle: Text(
                                      '${TranslationService.tr('champs_lat') ?? "Lat"}: ${it['lat']}, ${TranslationService.tr('champs_lon') ?? "Lon"}: ${it['lng']}',
                                      style: GoogleFonts.notoSans(fontSize: 12),
                                    ),
                                    onTap: () {
                                      _selectLocalite(it);
                                      setModalState(() {});
                                    },
                                  );
                                },
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInput(
                              latCtrl,
                              TranslationService.tr('champs_latitude') ?? "Latitude",
                              Icons.gps_fixed,
                              keyboard: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInput(
                              lonCtrl,
                              TranslationService.tr('champs_longitude') ?? "Longitude",
                              Icons.gps_fixed_outlined,
                              keyboard: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (isEditing && _editingChampId != null) {
                              final champData = {
                                "culture": cultureCtrl.text.trim(),
                                "superficie": double.tryParse(superficieCtrl.text.replaceAll(',', '.')) ?? 0.0,
                                "date_semi": dateSemiCtrl.text,
                                "localite": localiteCtrl.text.trim(),
                                "latitude": double.parse(latCtrl.text),
                                "longitude": double.parse(lonCtrl.text),
                              };
                              await _modifierChamp(_editingChampId!, champData);
                              Navigator.pop(context);
                            } else {
                              await _ajouterChamp();
                            }
                          },
                          icon: const Icon(Icons.save),
                          label: Text(
                            isEditing
                                ? TranslationService.tr('champs_save_changes') ?? "Enregistrer les modifications"
                                : TranslationService.tr('champs_save_field') ?? "Enregistrer le champ",
                            style: GoogleFonts.notoSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helper input
  Widget _buildInput(
      TextEditingController controller,
      String label,
      IconData icon, {
        TextInputType keyboard = TextInputType.text,
      }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      style: GoogleFonts.notoSans(),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.notoSans(),
        prefixIcon: Icon(icon, color: Colors.green[700]),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          TranslationService.tr('champs_title') ?? "Mes Champs",
          style: GoogleFonts.notoSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green[700],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _editingChampId = null;
          _clearForm();
          _showFormSheet();
        },
        icon: const Icon(Icons.add),
        label: Text(
          TranslationService.tr('champs_add_button') ?? "Ajouter",
          style: GoogleFonts.notoSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.green[700],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : champs.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.agriculture, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              TranslationService.tr('champs_empty') ?? "Aucun champ ajouté",
              style: GoogleFonts.notoSans(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: champs.length,
        itemBuilder: (context, i) {
          final champ = champs[i];
          final id = (champ['id'] is int) ? champ['id'] as int : int.tryParse(champ['id']?.toString() ?? '');
          final isSelected = id != null && id == selectedChampId;

          return Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 3,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Radio<int>(
                value: id ?? -1,
                groupValue: selectedChampId,
                onChanged: (val) {
                  if (id != null) _selectChamp(champ);
                },
                activeColor: Colors.green[700],
              ),
              title: Text(
                "${champ['culture'] ?? '—'} • ${champ['superficie'] ?? ''} ${TranslationService.tr('champs_hectares') ?? "ha"}",
                style: GoogleFonts.notoSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
              ),
              subtitle: Text(
                "${champ['localite'] ?? ''}",
                style: GoogleFonts.notoSans(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _ouvrirFormulaireModification(i),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      final champId = (champ['id'] is int) ? champ['id'] as int : int.tryParse(champ['id']?.toString() ?? '');
                      if (champId != null) {
                        _supprimerChamp(champId);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              TranslationService.tr('champs_delete_id_error') ?? "Impossible de supprimer: ID manquant",
                              style: GoogleFonts.notoSans(),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
              tileColor: isSelected ? Colors.green.shade50 : null,
              onTap: () {
                Navigator.pushReplacementNamed(context, '/home', arguments: champ);
              },
            ),
          );
        },
      ),
    );
  }
}