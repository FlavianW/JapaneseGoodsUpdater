import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'SiteChecker.dart';

class TaskManager {
  static SharedPreferences? _prefs;

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
  Workmanager().executeTask((task, inputData) async {
    // Initialisez le service de notification si ce n'est pas déjà fait
    NotificationService.initialize();
    print("InputData reçu: $inputData");
    // Assurez-vous d'initialiser Firebase ici si nécessaire
    final String userId = inputData?['userId'];
    final String artistName = inputData?['artistName'];



    await NotificationService.showNotification(
        0, // ID de la notification
        "Alerte pour $artistName",
        "Des nouveaux articles sont disponibles pour $artistName.",
        "Payload supplémentaire" // Utilisé pour identifier la notification ou passer des données supplémentaires
    );

    return Future.value(true); // Retournez true si la tâche a été exécutée avec succès
  });
}

