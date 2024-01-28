import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static void initialize() {
    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    _notificationsPlugin.initialize(initializationSettings);
  }

  static Future<void> showNotification(
      int id, String title, String body, String payload) async {
    const NotificationDetails notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'main_channel', // id
        'Main Channel', // title
        importance: Importance.max,
        priority: Priority.high,
      ),
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }
}

Future<int> extractResultsBooth(String artistName) async {
  try {
    // Encode l'artiste en format URL
    String encodedArtistName = Uri.encodeComponent(artistName);
    String url = 'https://booth.pm/en/search/$encodedArtistName'+'?in_stock=true';

    // Envoie la requête HTTP
    var response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      String htmlContent = response.body;

      // Parse le contenu HTML
      dom.Document document = parser.parse(htmlContent);

      // Recherche la balise spécifique avec le sélecteur CSS
      // NOTE: Ce sélecteur doit être ajusté selon la structure de la page et ce que vous essayez de trouver
      dom.Element? specificTag = document.querySelector(".u-d-flex.u-align-items-center.u-pb-300.u-tpg-body2.u-justify-content-between > b");

      if (specificTag != null) {
        // Extraire le nombre de la chaîne de texte
        RegExp regExp = RegExp(r'\d+'); // Regex pour trouver des chiffres
        Iterable<RegExpMatch> matches = regExp.allMatches(specificTag.text);

        if (matches.isNotEmpty) {
          // Convertit le premier match trouvé en nombre
          return int.parse(matches.first.group(0) ?? '0');
        } else {
          return 0; // Retourne 0 si aucun nombre n'est trouvé
        }
      } else {
        return 0; // Retourne 0 si le tag n'est pas trouvé
      }
    } else {
      print('Failed to load webpage');
      return 0; // En cas d'échec du chargement de la page
    }
  } catch (e) {
    print('Error parsing HTML: $e');
    return 0; // Retourne 0 en cas d'erreur
  }
}

Future<int> extractResultsMandarake(String artistName) async {
  try {
    // Encode le nom de l'artiste pour l'URL
    String encodedArtistName = Uri.encodeComponent(artistName);
    String url = 'https://order.mandarake.co.jp/order/listPage/list?soldOut=1&keyword=$encodedArtistName&lang=en';

    // Envoie la requête HTTP
    var response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      String htmlContent = response.body;

      // Parse le contenu HTML
      dom.Document document = parser.parse(htmlContent);

      // Utilise le sélecteur CSS pour trouver le nombre de résultats
      dom.Element? resultCountElement = document.querySelector('div.count');

      if (resultCountElement != null) {
        // Le texte devrait être quelque chose comme "Search result: X items"
        String resultText = resultCountElement.text;

        // Utilise RegExp pour extraire le nombre
        RegExp regExp = RegExp(r'\d+');
        Iterable<RegExpMatch> matches = regExp.allMatches(resultText);

        if (matches.isNotEmpty) {
          // Convertit le premier match trouvé en nombre
          return int.parse(matches.first.group(0) ?? '0');
        } else {
          return 0; // Retourne 0 si aucun nombre n'est trouvé
        }
      } else {
        return 0; // Retourne 0 si l'élément n'est pas trouvé
      }
    } else {
      print('Failed to load webpage');
      return 0; // En cas d'échec du chargement de la page
    }
  } catch (e) {
    print('Error parsing HTML: $e');
    return 0; // Retourne 0 en cas d'erreur
  }
}
