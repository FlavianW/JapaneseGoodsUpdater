import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';


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

class SiteChecker {
  final String userId;
  final FirebaseFirestore firestore;

  SiteChecker({required this.userId, FirebaseFirestore? firestore})
      : firestore = firestore ?? FirebaseFirestore.instance;

  /// Récupère toutes les alertes pour un utilisateur donné
  Future<List<Alerte>> fetchUserAlerts() async {
    try {
      QuerySnapshot alertSnapshot = await firestore
          .collection('users')
          .doc(userId)
          .collection('alerts')
          .get();

      List<Alerte> alertes = alertSnapshot.docs
          .map((doc) => Alerte.fromFirestore(doc))
          .toList();

      return alertes;
    } catch (e) {
      print('Erreur lors de la récupération des alertes: $e');
      throw e; // Il serait mieux de gérer cette exception correctement
    }
  }

  /// Effectue la vérification des alertes
  Future<void> checkSites() async {
    List<Alerte> alertes = await fetchUserAlerts();
    for (var alerte in alertes) {
      // Ici, vous pouvez effectuer les vérifications nécessaires pour chaque alerte.
      // Par exemple, faire une requête HTTP ou vérifier si un produit est disponible.
      print('Vérification de l\'alerte pour ${alerte.artist}');
      // ...
      // Simuler un processus de vérification
      await Future.delayed(Duration(seconds: 2)); // Simulez un appel réseau ou un traitement
    }
  }
}

class Alerte {
  String artist;
  Map<String, bool> sites; // Supposons que chaque alerte a une liste de sites à vérifier

  Alerte({required this.artist, required this.sites});

  factory Alerte.fromFirestore(DocumentSnapshot doc) {
    return Alerte(
      artist: doc['artist'] ?? 'Unknown Artist',
      sites: Map<String, bool>.from(doc['sites'] ?? {}),
    );
  }
}
