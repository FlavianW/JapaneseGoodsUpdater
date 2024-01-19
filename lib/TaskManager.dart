import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';


class TaskManager {
  static SharedPreferences? _prefs;


  /// Initialise les SharedPreferences.
  /// Doit être appelé au démarrage de l'application.
  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Vérifie si une tâche est déjà planifiée.
  static bool isTaskScheduled(String taskName) {
    return _prefs?.getBool(taskName) ?? false;
  }

  /// Définit l'état d'une tâche comme étant planifiée.
  static Future<void> setTaskScheduled(String taskName, bool isScheduled) async {
    await _prefs?.setBool(taskName, isScheduled);
  }

  /// Efface l'état planifié d'une tâche.
  static Future<void> clearTaskScheduled(String taskName) async {
    await _prefs?.remove(taskName);
  }
}
