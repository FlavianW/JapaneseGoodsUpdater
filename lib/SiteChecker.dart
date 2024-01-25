import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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

Future<int> extractResults(String htmlContent) async {
  try {
    // Parse le contenu HTML
    dom.Document document = parser.parse(htmlContent);

    // Recherche la balise spécifique avec le sélecteur CSS
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
  } catch (e) {
    print('Error parsing HTML: $e');
    return 0; // Retourne 0 en cas d'erreur
  }
}
