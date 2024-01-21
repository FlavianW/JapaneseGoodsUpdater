import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

class TaskManager {
  static SharedPreferences? _prefs;

  /// Annule toutes les tâches planifiées.
  static Future<void> cancelAllTasks() async {
    await Workmanager().cancelAll();
    print("Toutes les tâches annulées");
  }


  /// Initialise les SharedPreferences.
  /// Doit être appelé au démarrage de l'application.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Vérifie si une tâche est déjà planifiée.
  static bool isTaskScheduled(String taskName) {
    print("Interrogation tâche $taskName");
    return _prefs?.getBool(taskName) ?? false;
  }

  /// Définit l'état d'une tâche comme étant planifiée.
  static Future<void> setTaskScheduled(String taskName, bool isScheduled, int days, int hours, int minutes) async {
    print("Set tâche $taskName à $isScheduled");
    await _prefs?.setBool(taskName, isScheduled);
  }

  /// Efface l'état planifié d'une tâche.
  static Future<void> clearTaskScheduled(String taskName) async {
    print("Delete tâche $taskName");
    await _prefs?.remove(taskName);
  }
}
