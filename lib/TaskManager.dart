import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:japanesegoodstool/SiteChecker.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      initialNotificationTitle: 'JGT runnin in the background',
      initialNotificationContent: '',
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
  service.startService();
}

Future<void> setTaskEnabled(String taskName, bool isEnabled, {required int days, required int hours, required int minutes, required String userId, required String artistName}) async {
  if (isEnabled) {
    int intervalMinutes = days * 24 * 60 + hours * 60 + minutes;
    print("Paramètres de la tâche: $taskName, $days, $hours, $minutes, $userId, $artistName");
    // Convertir les paramètres en JSON pour les enregistrer
    String taskJson = json.encode({
      'taskName': taskName,
      'nextRun': DateTime.now().add(Duration(days: days, hours: hours, minutes: minutes)).toIso8601String(),
      'userId': userId,
      'artistName': artistName,
      'days': days,
      'hours': hours,
      'minutes': minutes,
    });

    print("Tâche encodée en JSON: $taskJson");
    final prefs = await SharedPreferences.getInstance();
    final tasks = prefs.getStringList('tasks') ?? [];
    tasks.add(taskJson);
    await prefs.setStringList('tasks', tasks);

    print("Tâche $taskName programmée pour exécution dans $intervalMinutes minutes.");
    print(intervalMinutes);
    List<String>? savedTasks = prefs.getStringList('tasks');
    print("Tâches enregistrées immédiatement après l'enregistrement: $savedTasks");
  } else {
    // Logique pour annuler la tâche
    print("Tâche $taskName annulée.");
  }
}

Future<void> cancelTask(String taskName) async {
  final prefs = await SharedPreferences.getInstance();
  final tasks = prefs.getStringList('tasks') ?? [];
  final updatedTasks = tasks.where((taskJson) {
    final task = json.decode(taskJson);
    return task['taskName'] != taskName;
  }).toList();

  // Mise à jour de la liste des tâches après l'annulation
  await prefs.setStringList('tasks', updatedTasks);
  print("Tâche $taskName annulée.");
}


@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('ic_notification');
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  Timer.periodic(Duration(minutes: 1), (timer) async {
    print('Running background task');
    final now = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    List<String>? tasks = prefs.getStringList('tasks');
    print(tasks);
    if (tasks == null) return;

    List<String> newTasks = []; // Start with an empty list to collect updated tasks

    for (String taskJson in tasks) {
      final Map<String, dynamic> task = json.decode(taskJson);
      final DateTime nextRun = DateTime.parse(task['nextRun']);

      if (now.isAfter(nextRun)) {
        // Display the notification
        int notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);
        var androidDetails = AndroidNotificationDetails(
          'channelId', 'channelName',
          channelDescription: 'channelDescription',
          importance: Importance.high,
          priority: Priority.high,
        );
        var platformDetails = NotificationDetails(android: androidDetails);
        await flutterLocalNotificationsPlugin.show(
          notificationId,
          'Tâche exécutée',
          'La tâche ${task['taskName']} a été exécutée avec succès.',
          platformDetails,
        );

        // Cancel (remove) the executed task
        await cancelTask(task['taskName']);

        // Calculate the next run based on the current task's configuration
        final nextRunUpdate = calculateNextRun(
          int.tryParse(task['days'].toString()) ?? 0,
          int.tryParse(task['hours'].toString()) ?? 0,
          int.tryParse(task['minutes'].toString()) ?? 15,
        );

        // Recreate the task with the new nextRun using setTaskEnabled
        await setTaskEnabled(
          task['taskName'],
          true,
          days: int.tryParse(task['days'].toString()) ?? 0,
          hours: int.tryParse(task['hours'].toString()) ?? 0,
          minutes: int.tryParse(task['minutes'].toString()) ?? 15,
          userId: task['userId'],
          artistName: task['artistName'],
        );
      } else {
        // If the task does not need to be executed yet, keep it as is
        newTasks.add(taskJson);
      }
    }
  });
}

DateTime calculateNextRun(int days, int hours, int minutes) {
  return DateTime.now().add(Duration(days: days, hours: hours, minutes: minutes));
}


@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  // Votre logique de service en arrière-plan pour iOS
  return true;
}




