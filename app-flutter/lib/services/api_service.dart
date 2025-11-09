import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // static const String baseUrl = "http://10.0.2.2:8000";

  static const String baseUrl = "http://10.34.70.172:8000";

  static Future<Map<String, dynamic>> registerStep1(Map<String, dynamic> data) async {
    final url = Uri.parse("$baseUrl/auth/register");
    final response = await http.post(url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data));
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Erreur d'inscription: ${response.body}");
    }
  }

  static Future<Map<String, dynamic>> createChamp(Map<String, dynamic> data) async {
    final url = Uri.parse("$baseUrl/champs/");
    final response = await http.post(url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data));
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Erreur lors de la création du champ: ${response.body}");
    }
  }

  static Future<Map<String, dynamic>> login(String tel, String mdp) async {
    final url = Uri.parse("$baseUrl/auth/login?telephone=$tel&mot_de_passe=$mdp");
    final response = await http.post(url);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Identifiants invalides");
    }
  }

  static Future<Map<String, dynamic>?> getChampByAgriculteur(int idAgriculteur) async {
    final url = Uri.parse("$baseUrl/champs/principal/$idAgriculteur");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception("Erreur lors de la récupération du champ principal");
    }
  }

  static Future<List<dynamic>> getChampsByAgriculteur(int id) async {
    final url = Uri.parse("$baseUrl/champs/agriculteur/$id");
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Erreur récupération champs: ${response.body}");
    }
  }

  static Future<Map<String, dynamic>> updateChamp(int id, Map<String, dynamic> data) async {
    final url = Uri.parse("$baseUrl/champs/$id");
    final response = await http.put(url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Erreur modification: ${response.body}");
    }
  }

  static Future<void> deleteChamp(int id) async {
    final url = Uri.parse("$baseUrl/champs/$id");
    final response = await http.delete(url);
    if (response.statusCode != 200) {
      throw Exception("Erreur suppression: ${response.body}");
    }
  }

}
