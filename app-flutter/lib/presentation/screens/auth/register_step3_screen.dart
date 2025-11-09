import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/api_service.dart';
import '../../../pages/dashboard_page.dart';
import '../../../constants.dart';

class RegisterStep3 extends StatefulWidget {
  final String nom, tel, mdp, langue;
  const RegisterStep3({super.key, required this.nom, required this.tel, required this.mdp, required this.langue});

  @override
  State<RegisterStep3> createState() => _RegisterStep3State();
}

class _RegisterStep3State extends State<RegisterStep3> {
  final cultureCtrl = TextEditingController();
  final superficieCtrl = TextEditingController();
  final dateSemiCtrl = TextEditingController();
  final localiteCtrl = TextEditingController();
  final latCtrl = TextEditingController();
  final lonCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _suggestions = [];
  Timer? _debounce;
  bool _isSearchingLocalite = false;
  bool loading = false;

  Future<List<Map<String, dynamic>>> _searchLocalites(String q) async {
    if (q.trim().length < 2) return [];
    final username = GEONAMES_USERNAME;
    final encoded = Uri.encodeComponent(q);
    final url =
        'https://secure.geonames.org/searchJSON?name_startsWith=$encoded&maxRows=10&username=$username&continentCode=AF&featureClass=P';
    final uri = Uri.parse(url);

    final resp = await http.get(uri).timeout(const Duration(seconds: 15), onTimeout: () {
      throw Exception('Délai dépassé lors de la recherche GeoNames');
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
      throw Exception('Erreur GeoNames: ${resp.statusCode}');
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

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => loading = true);
    try {
      final user = await ApiService.registerStep1({
        "nom_complet": widget.nom,
        "telephone": widget.tel,
        "mot_de_passe": widget.mdp,
        "langue": widget.langue
      });

      await ApiService.createChamp({
        "culture": cultureCtrl.text,
        "superficie": double.parse(superficieCtrl.text),
        "date_semi": dateSemiCtrl.text, // Format YYYY-MM-DD
        "localite": localiteCtrl.text,
        "latitude": double.parse(latCtrl.text),
        "longitude": double.parse(lonCtrl.text),
        "id_agriculteur": user["id"]
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt("id_agriculteur", user["id"]);
      await prefs.setString("nom_complet", widget.nom);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text("Inscription réussie !"),
            ],
          ),
          backgroundColor: const Color(0xFF0B7E1E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      Navigator.pushReplacementNamed(context, '/');

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text("Erreur: $e")),
            ],
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Créer un compte",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProgressIndicator(),
                const SizedBox(height: 32),

                const Text(
                  "Champ principal",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Renseignez les informations de votre premier champ",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 32),

                _buildTextField(
                  controller: cultureCtrl,
                  label: "Culture",
                  icon: Icons.eco_rounded,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer le type de culture';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                _buildTextField(
                  controller: superficieCtrl,
                  label: "Superficie (hectares)",
                  icon: Icons.square_foot_rounded,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Veuillez entrer la superficie';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Veuillez entrer un nombre valide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                _buildDateField(),
                const SizedBox(height: 20),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      controller: localiteCtrl,
                      label: "Localité (autocomplétion)",
                      icon: Icons.location_on_outlined,
                      onChanged: _onLocaliteChanged,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer la localité';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 6),

                    if (_isSearchingLocalite)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: LinearProgressIndicator(),
                      ),

                    if (_suggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            )
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
                                it['display'] ?? 'Nom inconnu',
                                style: const TextStyle(fontSize: 14),
                              ),
                              subtitle: Text(
                                'Lat: ${it['lat']}, Lon: ${it['lng']}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onTap: () => _selectLocalite(it),
                            );
                          },
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                const Text(
                  "Coordonnées GPS",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Ces informations aident à personnaliser les conseils météo",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        controller: latCtrl,
                        label: "Latitude",
                        icon: Icons.gps_fixed_rounded,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Obligatoire';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Nombre invalide';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildTextField(
                        controller: lonCtrl,
                        label: "Longitude",
                        icon: Icons.gps_fixed_rounded,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Obligatoire';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Nombre invalide';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: loading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B7E1E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      shadowColor: const Color(0xFF0B7E1E).withOpacity(0.3),
                    ),
                    child: loading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Créer mon compte",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        LinearProgressIndicator(
          value: 1.0,
          backgroundColor: Colors.grey[200],
          color: const Color(0xFF0B7E1E),
          borderRadius: BorderRadius.circular(10),
          minHeight: 6,
        ),
        const SizedBox(height: 12),
        const Align(
          alignment: Alignment.centerRight,
          child: Text(
            "3/3",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      style: const TextStyle(
        fontSize: 16,
        color: Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0B7E1E), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  Widget _buildDateField() {
    return TextFormField(
      controller: dateSemiCtrl,
      readOnly: true,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez sélectionner une date';
        }
        return null;
      },
      style: const TextStyle(
        fontSize: 16,
        color: Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: "Date de semis",
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: const Icon(Icons.calendar_today_rounded, color: Colors.grey),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0B7E1E), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFF0B7E1E),
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.black87,
                ),
                dialogBackgroundColor: Colors.white,
              ),
              child: child!,
            );
          },
        );
        if (date != null) {
          setState(() {
            dateSemiCtrl.text = date.toIso8601String().split('T')[0]; // Format YYYY-MM-DD
          });
        }
      },
    );
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
}