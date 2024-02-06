import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:background_fetch/background_fetch.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'Accueil.dart';
import 'SiteChecker.dart';


class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    var initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    var initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  static Future<void> showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'your_channel_id', // Assurez-vous que cet ID est unique et correspond à un canal configuré.
      'your_channel_name',
      channelDescription: 'your_channel_description',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    // Générer un ID de notification unique basé sur l'horodatage actuel.
    int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    await flutterLocalNotificationsPlugin.show(
      notificationId, // Utiliser un ID unique pour chaque notification.
      title,
      body,
      platformChannelSpecifics,
      payload: 'item_x', // payload optionnel pour plus d'informations.
    );
  }

}


class TaskManager {

  /// Initialisation de Background Fetch.
  static Future<void> initBackgroundFetch() async {
    // Configuration initiale de Background Fetch.
    BackgroundFetch.configure(BackgroundFetchConfig(
      minimumFetchInterval: 15,
      stopOnTerminate: false,
      startOnBoot: true,
      enableHeadless: true,
    ), (String taskId) async {
      // Ceci est le callback pour les tâches régulières. Vous pouvez faire votre logique de fetch ici.
      print("[BackgroundFetch] Event received: $taskId");

      // Indique à Background Fetch que la tâche est terminée.
      BackgroundFetch.finish(taskId);
    }).then((int status) {
      print('BackgroundFetch configure success: $status');
    }).catchError((e) {
      print('BackgroundFetch configure failed: $e');
    });

    // Enregistrement de la tâche sans tête.
    BackgroundFetch.registerHeadlessTask(backgroundFetchHeadlessTask);
  }

  static Future<void> setTaskEnabled(String taskName, bool isEnabled, {required int days, required int hours, required int minutes, required String userId, required String artistName}) async {
    if (isEnabled) {
      int intervalMinutes = days * 24 * 60 + hours * 60 + minutes;
      BackgroundFetch.scheduleTask(TaskConfig(
        taskId: taskName,
        delay: intervalMinutes * 60 * 1000,
        stopOnTerminate: false,
        startOnBoot: true,
        enableHeadless: true,
        periodic: true,
      ));
    } else {
      BackgroundFetch.stop(taskName);
    }
  }

  static Future<void> cancelTask(String taskName) async {
    // Avec Background Fetch, il n'y a pas de méthode directe pour annuler une tâche spécifique.
    // Vous devrez gérer cela logiquement dans vos callbacks en vérifiant si une tâche est toujours active.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("$taskName:isScheduled", false);
  }

  Future<void> configureTask(String taskName, int intervalMinutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$taskName:interval', intervalMinutes);
    await prefs.setBool('$taskName:enabled', true);
  }

  /// Callback pour les événements de fetch en arrière-plan.
  // Dans TaskManager ou un gestionnaire approprié
  static void onBackgroundFetch(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? artistesString = prefs.getStringList('artistes');
    if (artistesString != null) {
      for (var str in artistesString) {
        Artiste artiste = Artiste.fromJson(json.decode(str));
        // Vérifiez si la tâche doit être exécutée pour cet artiste basé sur leur configuration spécifique
        // Par exemple, comparer le temps actuel à la dernière fois que la notification a été envoyée
        // Si la tâche doit être exécutée, envoyez la notification
      }
    }
    BackgroundFetch.finish(taskId);
  }



  /// Callback pour les tâches headless.
  @pragma('vm:entry-point')
  static void backgroundFetchHeadlessTask(HeadlessTask task) async {
    String taskId = task.taskId;
    bool isTimeout = task.timeout;
    if (isTimeout) {
      print("[BackgroundFetch] Headless task timed-out: $taskId");
      BackgroundFetch.finish(taskId);
      return;
    }

    print("[BackgroundFetch] Headless event received: $taskId");

    // Assurez-vous que NotificationService est initialisé.
    await NotificationService.initialize();

    // Envoyez une notification indiquant que la tâche headless s'est exécutée.
    await NotificationService.showNotification(
        "Tâche headless exécutée",
        "La tâche headless $taskId a été exécutée avec succès."
    );

    // Indiquez à Background Fetch que la tâche est terminée.
    BackgroundFetch.finish(taskId);
  }
}

/*void callbackDispatcher() {
  print("Tâche en arrière-plan exécutée");
  Workmanager().executeTask((task, inputData) async {
    await Firebase.initializeApp(); // Ensure Firebase is initialized
    NotificationService.initialize();

    final String? userId = inputData?['userId'];
    final String? artistName = inputData?['artistName'];

    if (userId == null || artistName == null) {
      return Future.value(false); // End task if userId or artistName is null
    }

    // Reference to the user's alert document
    DocumentReference alertDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('alerts')
        .doc(artistName);

    DocumentSnapshot userPreferences = await alertDocRef.get();

    if (userPreferences.exists) {
      var data = userPreferences.data() as Map<String, dynamic>?; // Explicit cast
      if (data != null) {
        var sitesData = data['sites'] as Map<String, dynamic>?; // Explicit cast for 'sites'
        Map<String, int> lastCheckResults = data['siteResultsLastCheck'] != null ? Map<String, int>.from(data['siteResultsLastCheck']) : {};
        Map<String, int> newCheckResults = {};

        if (sitesData != null) {
          for (var entry in sitesData.entries) {
            String siteKey = entry.key;
            bool shouldCheck = entry.value;
            if (shouldCheck) {
              int resultCount = 0;
              switch (siteKey) {
                case 'Booth':
                  resultCount = await extractResultsBooth(artistName);
                  break;
                case 'Mandarake':
                  resultCount = await extractResultsMandarake(artistName);
                  break;
                case 'Melonbooks':
                  resultCount = await extractResultsMelonbooks(artistName);
                  break;
                case 'Rakuten':
                  resultCount = await extractResultsRakuten(artistName);
                  break;
                case 'Surugaya':
                  resultCount = await extractResultsSurugaya(artistName);
                  break;
                case 'Toranoana':
                  resultCount = await extractResultsToranoana(artistName);
                  break;
              }

              newCheckResults[siteKey] = resultCount;

              // If new items are available (compared to last check), send a notification
              if (resultCount > (lastCheckResults[siteKey] ?? 0)) {
                String notificationMessage = "Des nouveaux articles sont disponibles sur $siteKey pour $artistName.";
                await NotificationService.showNotification(
                    0, // Notification ID
                    "Alerte pour $artistName",
                    notificationMessage,
                    "Payload supplémentaire" // Used to identify the notification or pass additional data
                );
              }
            }
          }
        }

        // Update Firestore with the latest results
        await alertDocRef.update({
          'siteResultsLastCheck': newCheckResults,
        });
      }
    }
    return Future.value(true);
  });
  }*/



