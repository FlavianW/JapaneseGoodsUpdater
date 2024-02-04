import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'SiteChecker.dart';

class TaskManager {
  static SharedPreferences? _prefs;

  static Future<void> printSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    print('Shared Preferences:');
    prefs.getKeys().forEach((key) {
      print('$key: ${prefs.get(key)}');
    });
  }


  /// Initialise les SharedPreferences et Workmanager.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    Workmanager().initialize(
      callbackDispatcher, // Le point d'entrée de la tâche en arrière-plan
      isInDebugMode: true, // Mettez cela à false lorsque vous déployez l'application en production
    );
  }

  /// Planifie une tâche périodique avec Workmanager.
  static Future<void> setTaskScheduled(
      String taskName,
      bool isScheduled,
      int days,
      int hours,
      int minutes,
      String userId,
      String artistName
      ) async {
    await _prefs?.setBool(taskName, isScheduled);
    if (isScheduled) {
      Map<String, dynamic> inputData = {
        'userId': userId,
        'artistName': artistName,
      };
      Duration interval = Duration(days: days, hours: hours, minutes: minutes);
      await schedulePeriodicTask(taskName, interval, inputData);
    } else {
      await cancelTask(taskName);
    }
    print("Tâche $taskName mise à $isScheduled");
  }

  static Future<void> schedulePeriodicTask(
      String taskName,
      Duration interval,
      Map<String, dynamic> inputData
      ) async {
    await Workmanager().registerPeriodicTask(
      taskName,
      taskName,
      frequency: interval,
      inputData: inputData, // Passer inputData à la tâche
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
    );
    print("Tâche périodique $taskName planifiée pour s'exécuter toutes les ${interval.inMinutes} minutes.");
  }

  /// Annule une tâche spécifique.
  static Future<void> cancelTask(String taskName) async {
    await Workmanager().cancelByUniqueName(taskName);
    print("Tâche $taskName annulée.");
  }

  /// Annule toutes les tâches planifiées.
  static Future<void> cancelAllTasks() async {
    await Workmanager().cancelAll();
    print("Toutes les tâches annulées");
  }
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







