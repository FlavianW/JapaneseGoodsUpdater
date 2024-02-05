import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:background_fetch/background_fetch.dart';
import 'package:workmanager/workmanager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'SiteChecker.dart';

class TaskManager {
  static const String taskUniqueId = "com.example.japanesegodstool.backgroundFetchTask";

  /// Initialisation de Background Fetch.
  static Future<void> initBackgroundFetch() async {
    await Firebase.initializeApp();
    BackgroundFetch.configure(BackgroundFetchConfig(
      minimumFetchInterval: 15,
      stopOnTerminate: false,
      startOnBoot: true,
      enableHeadless: true,
    ), onBackgroundFetch);
    BackgroundFetch.registerHeadlessTask(onBackgroundFetchHeadless);
  }

  static Future<void> setTaskEnabled(String taskName, bool isEnabled, {required int days, required int hours, required int minutes, required String userId, required String artistName}) async {
    final prefs = await SharedPreferences.getInstance();
    String taskConfig = jsonEncode({
      'isEnabled': isEnabled,
      'days': days,
      'hours': hours,
      'minutes': minutes,
      'userId': userId,
      'artistName': artistName,
    });
    await prefs.setString(taskName, taskConfig);
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
  // Callback pour Background Fetch
  static void onBackgroundFetch(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    // Vérifiez ici les configurations de tâche et exécutez la logique conditionnelle
    String? taskConfig = prefs.getString(taskId);
    if (taskConfig != null) {
      Map<String, dynamic> config = jsonDecode(taskConfig);
      if (config['isEnabled']) {
        print("Tâche en arrière-plan exécutée");
      }
    }
    BackgroundFetch.finish(taskId);
  }


  /// Callback pour les tâches headless.
  static void onBackgroundFetchHeadless(HeadlessTask task) async {
    var taskId = task.taskId;
    if (task.timeout) {
      // La tâche a expiré. Vous devez terminer immédiatement.
      BackgroundFetch.finish(taskId);
      return;
    }

    print("[BackgroundFetch] Headless event received.");

}

void callbackDispatcher() {
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
  }
}


