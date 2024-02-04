import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import 'Accueil.dart';
import 'SiteChecker.dart';



class CreerAlerte extends StatefulWidget {
  final String uid;
  final VoidCallback onAlertAdded;


  const CreerAlerte({Key? key, required this.uid, required this.onAlertAdded}) : super(key: key);

  @override
  _CreerAlerteState createState() => _CreerAlerteState();
}

class _CreerAlerteState extends State<CreerAlerte> {

  TextEditingController artistController = TextEditingController();
  String? artistError; // Variable pour le message d'erreur

  String artist = '';
  int days = 1,
      hours = 0,
      minutes = 0;
  bool sendNotifications = false;
  File? _image;
  bool Melonbooks = true;
  bool Rakuten = true;
  bool Booth = true;
  bool Surugaya = true;
  bool Toranoana = true;
  bool Mandarake = true;

  void initState() {
    super.initState();
    days = 1; // Assurez-vous que days est initialisé à 1 par défaut
    hours = 0; // Initialisez à la valeur par défaut souhaitée
    minutes = 0; // Initialisez à la valeur par défaut souhaitée
    // Toute autre initialisation nécessaire peut être ajoutée ici
  }


  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();

    // Sélectionner une image depuis la galerie
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 600,
      imageQuality: 100,
    );

    if (pickedFile != null) {
      // Recadrer l'image sélectionnée pour obtenir un rapport d'aspect 16:10
      File imageFile = File(pickedFile.path);

      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),  // Définir le rapport d'aspect 16:10
        uiSettings: [AndroidUiSettings(
            toolbarTitle: 'Cropper',
            toolbarColor: Colors.deepOrange,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: true  // Verrouiller le rapport d'aspect
        )],
      );

      if (croppedFile != null) {
        setState(() {
          _image = File(croppedFile.path);  // Convertir CroppedFile en File
        });
      }
    }
  }

  bool isDurationValid(int days, int hours, int minutes) {
    // Convertissez tout en minutes et vérifiez si le total est >= 15 minutes
    int totalMinutes = days * 24 * 60 + hours * 60 + minutes;
    return totalMinutes >= 15;
  }

  void showErrorDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop(); // Ferme la boîte de dialogue
              },
            ),
          ],
        );
      },
    );
  }

  Future<String> uploadImage(File image) async {
    String extension = path.extension(image.path);
    if (extension.toLowerCase() != '.png' && extension.toLowerCase() != '.jpg') {
      throw Exception('Only PNG and JPG files are allowed');
    }

    String fileName = 'alerts/${widget.uid}/${DateTime.now().millisecondsSinceEpoch}$extension';
    print(fileName);
    Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
    UploadTask uploadTask = storageRef.putFile(image);
    // Attendre la fin de l'upload
    await uploadTask;
    // Récupérer et retourner l'URL de l'image
    String downloadUrl = await storageRef.getDownloadURL();
    print(downloadUrl);
    return downloadUrl;
  }

    void addAlert() async {
      if (!isDurationValid(days, hours, minutes)) {
        showErrorDialog(
            "Invalid Duration",
            "Length between checks must be at least 15 minutes."
        );
        return;
      }
      Future<void> showArtistExistsDialog() async {
        return showDialog<void>(
          context: context,
          barrierDismissible: false, // L'utilisateur doit appuyer sur un bouton pour fermer la boîte de dialogue
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Alerte Existe Déjà'),
              content: const SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    Text('Une alerte pour cet artiste existe déjà.'),
                    Text('Veuillez essayer avec un nom d\'artiste différent.'),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('OK'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // Ferme la boîte de dialogue
                  },
                ),
              ],
            );
          },
        );
      }



      final firestoreInstance = FirebaseFirestore.instance;
      var existingAlerts = await firestoreInstance.collection('users')
          .doc(widget.uid)
          .collection('alerts')
          .where('artist', isEqualTo: artistController.text)
          .get();

      if (existingAlerts.docs.isNotEmpty) {
        // Affiche un popup si un artiste avec le même nom existe déjà
        await showArtistExistsDialog();
        return;
      }

      // Préparez les données de l'alerte
      final alertData = {
        'artist': artistController.text,
        'days': days,
        'hours': hours,
        'minutes': minutes,
        'sendNotifications': sendNotifications,
        'imageUrl': null,
        'sites': {
          'Melonbooks': Melonbooks,
          'Rakuten': Rakuten,
          'Booth': Booth,
          'Surugaya': Surugaya,
          'Toranoana': Toranoana,
          'Mandarake': Mandarake,
        },
        'siteResults': {},
      };

      // Collecte des résultats pour chaque site activé
      // Initialize siteResults map to store the results from each site
      Map<String, int> siteResults = {};

      // Check each site and add the future to a list
      List<Future> checkFutures = [];
      if (Melonbooks) checkFutures.add(extractResultsMelonbooks(artistController.text).then((result) => siteResults['Melonbooks'] = result));
      if (Rakuten) checkFutures.add(extractResultsRakuten(artistController.text).then((result) => siteResults['Rakuten'] = result));
      if (Booth) checkFutures.add(extractResultsBooth(artistController.text).then((result) => siteResults['Booth'] = result));
      if (Surugaya) checkFutures.add(extractResultsSurugaya(artistController.text).then((result) => siteResults['Surugaya'] = result));
      if (Toranoana) checkFutures.add(extractResultsToranoana(artistController.text).then((result) => siteResults['Toranoana'] = result));
      if (Mandarake) checkFutures.add(extractResultsMandarake(artistController.text).then((result) => siteResults['Mandarake'] = result));

      // Wait for all the checks to complete
      await Future.wait(checkFutures);

      // Mise à jour de alertData avec les résultats des sites
      alertData['siteResults'] = siteResults;

      try {
        if (_image != null) {
          String imageUrl = await uploadImage(_image!);
          alertData['imageUrl'] = imageUrl;
          print(alertData['imageUrl']);
        }
      } catch (e) {
        print("Erreur lors du téléchargement de l'image : $e");
      }


      if (artistController.text.isEmpty) {
        setState(() {
          artistError = "Artist field cannot be empty"; // Définir le message d'erreur
        });
        return; // Ne pas continuer si le champ est vide
      }

      if (!mounted) return;
      setState(() {
        artistError = null;
      });

      print(alertData);
      print("Alert added");
      await firestoreInstance.collection('users').doc(widget.uid).collection('alerts').add(alertData);

      // Update SharedPreferences to reflect the new alert, including its active task status
      final prefs = await SharedPreferences.getInstance();
      List<String>? artistesString = prefs.getStringList('artistes') ?? [];
      artistesString.add(json.encode({
        'nom': artistController.text,
        'notifzero': sendNotifications,
        'imageUrl': alertData['imageUrl'],
        'isTaskActive': true, // Set this to true as the task for this alert should be active
        'days': days,
        'hours': hours,
        'minutes': minutes,
      }));
      await prefs.setStringList('artistes', artistesString);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Alert added")));
      widget.onAlertAdded();


      Navigator.pop(context); // Retournez à l'écran précédent après l'ajout
      // Afficher un message ou effectuer une action après l'enregistrement
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Alert added")),
      );

    }



  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text("Créer une Alerte"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context); // Revenir à l'écran précédent
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: artistController,
                decoration: InputDecoration(
                  labelText: "Artist",
                  errorText: artistError,
                ),
                onChanged: (value) {
                  if (artistError != null) {
                    setState(() {
                      artistError = null;
                    });
                  }
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: TimeCard(
                      label: "Days",
                      minValue: 0,
                      maxValue: 7,
                      defaultValue: days, // Assurez-vous que la valeur par défaut est bien passée
                      onChanged: (val) => setState(() => days = val),
                    ),
                  ),
                  Expanded(
                    child: TimeCard(
                      label: "Hours",
                      minValue: 0,
                      maxValue: 59,
                      defaultValue: hours, // Assurez-vous de fournir la valeur actuelle de days comme defaultValue
                      onChanged: (val) => setState(() => hours = val),
                    ),
                  ),
                  Expanded(
                    child: TimeCard(
                      label: "Minutes",
                      minValue: 0,
                      maxValue: 59,
                      defaultValue: minutes, // Assurez-vous de fournir la valeur actuelle de days comme defaultValue
                      onChanged: (val) => setState(() => minutes = val),
                    ),
                  ),
                ],
              ),
              CheckboxListTile(
                title: const Text("Send notifications even if there are no new items"),
                value: sendNotifications,
                onChanged: (bool? newValue) {
                  setState(() {
                    sendNotifications = newValue ?? false;
                  });
                },
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  "Sites to check",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              // Ajout des CheckboxListTile pour chaque site
              _buildCheckboxListTile("Melonbooks", Melonbooks, (bool value) {
                setState(() => Melonbooks = value);
              }),
              _buildCheckboxListTile("Rakuten", Rakuten, (bool value) {
                setState(() => Rakuten = value);
              }),
              _buildCheckboxListTile("Booth", Booth, (bool value) {
                setState(() => Booth = value);
              }),
              _buildCheckboxListTile("Surugaya", Surugaya, (bool value) {
                setState(() => Surugaya = value);
              }),
              _buildCheckboxListTile("Toranoana", Toranoana, (bool value) {
                setState(() => Toranoana = value);
              }),
              _buildCheckboxListTile("Mandarake", Mandarake, (bool value) {
                setState(() => Mandarake = value);
              }),
              if (_image != null)
                Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.width * 10 / 16,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      fit: BoxFit.cover,
                      image: FileImage(_image!),
                    ),
                  ),
                ),
              ElevatedButton(
                onPressed: pickImage,
                child: Text(_image == null ? "Choose Image" : "Change Image"),
              ),
              ElevatedButton(
                onPressed: addAlert,
                child: const Text('Add Alert'),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildCheckboxListTile(String title, bool currentValue, Function(bool) onChanged) {
    return CheckboxListTile(
      title: Text(title),
      value: currentValue,
      onChanged: (bool? newValue) {
        onChanged(newValue ?? false);
      },
    );
  }
}

class TimeCard extends StatefulWidget {
  final String label;
  final int minValue, maxValue, defaultValue;
  final Function(int) onChanged;

  const TimeCard({
    super.key,
    required this.label,
    required this.minValue,
    required this.maxValue,
    required this.defaultValue,
    required this.onChanged,
  });

  @override
  _TimeCardState createState() => _TimeCardState();
}

class _TimeCardState extends State<TimeCard> {
  late int currentValue; // Ajoutez cette ligne ici

  @override
  void initState() {
    super.initState();
    currentValue = widget.defaultValue; // Initialisez currentValue avec defaultValue
  }

  @override
  Widget build(BuildContext context) {
    List<DropdownMenuItem<int>> menuItems = List.generate(
      widget.maxValue - widget.minValue + 1,
          (index) => DropdownMenuItem(
        value: widget.minValue + index,
        child: Text('${widget.minValue + index}'),
      ),
    );

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Text(widget.label),
          DropdownButton<int>(
            value: currentValue, // Utilisez la valeur de currentValue ici
            items: menuItems,
            onChanged: (int? newValue) {
              setState(() {
                currentValue = newValue!; // Mettez à jour currentValue
                widget.onChanged(newValue); // Appelez widget.onChanged avec la nouvelle valeur
              });
            },
          ),
        ],
      ),
    );
  }
}
