import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:path/path.dart' as path;


class CreerAlerte extends StatefulWidget {
  final String uid;

  CreerAlerte({Key? key, required this.uid}) : super(key: key);

  @override
  _CreerAlerteState createState() => _CreerAlerteState();
}

class _CreerAlerteState extends State<CreerAlerte> {
  String artist = '';
  int days = 1,
      hours = 0,
      minutes = 0;
  bool sendNotifications = false;
  File? _image;
  bool YahooJapanAuction = true;
  bool YahooJapanShopping = true;
  bool Melonbooks = true;
  bool Rakuten = true;
  bool Booth = true;
  bool Surugaya = true;
  bool Toranoana = true;
  bool Mandarake = true;


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



    void addAlert() async {
      // Préparez les données de l'alerte
      final alertData = {
        'artist': artist,
        'days': days,
        'hours': hours,
        'minutes': minutes,
        'sendNotifications': sendNotifications,
        'sites': {
          'YahooJapanAuction': YahooJapanAuction,
          'YahooJapanShopping': YahooJapanShopping,
          'Melonbooks': Melonbooks,
          'Rakuten': Rakuten,
          'Booth': Booth,
          'Surugaya': Surugaya,
          'Toranoana': Toranoana,
          'Mandarake': Mandarake,
        },
      };

      void addAlertToFirestore(Map<String, dynamic> alertData) async {
        final firestoreInstance = FirebaseFirestore.instance;
        // Ajouter une nouvelle alerte dans une sous-collection pour cet utilisateur
        await firestoreInstance.collection('users')
            .doc(widget.uid)
            .collection('alerts')
            .add(
            alertData); // Utilisez add() pour créer un nouveau document avec un ID unique
      }

      Future<String> uploadImage(File image) async {
        String extension = path.extension(image.path);

        if (extension.toLowerCase() != '.png' && extension.toLowerCase() != '.jpg') {
          throw Exception('Only PNG and JPG files are allowed');
        }

        String fileName = 'alerts/${widget.uid}/${DateTime.now().millisecondsSinceEpoch}$extension';
        Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
        UploadTask uploadTask = storageRef.putFile(image);
        await uploadTask;
        return await storageRef.getDownloadURL();
      }

      void addAlertToSharedPreferences(Map<String, dynamic> alertData) async {
        final prefs = await SharedPreferences.getInstance();
        // Lire la liste existante d'alertes
        final List<String> alerts = prefs.getStringList('alerts') ?? [];
        // Ajouter la nouvelle alerte
        alerts.add(json.encode(alertData));
        // Sauvegarder la liste mise à jour
        await prefs.setStringList('alerts', alerts);
      }

      addAlertToFirestore(alertData);
      addAlertToSharedPreferences(alertData);

      String imageUrl = '';
      if (_image != null) {
        imageUrl = await uploadImage(_image!);
      }

      alertData['imageUrl'] = imageUrl;

      // Afficher un message ou effectuer une action après l'enregistrement
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Alert added")),
      );
    }



  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
    home: Scaffold(
      appBar: AppBar(
        title: Text("Créer une Alerte"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(labelText: "Artist"),
              onChanged: (value) {
                artist = value;
              },
            ),
            Row(
              children: [
                Expanded(
                  child: TimeCard(
                    label: "Jours",
                    minValue: 1,
                    maxValue: 7,
                    onChanged: (val) => setState(() => days = val),
                  ),
                ),
                Expanded(
                  child: TimeCard(
                    label: "Heures",
                    minValue: 0,
                    maxValue: 23,
                    onChanged: (val) => setState(() => hours = val),
                  ),
                ),
                Expanded(
                  child: TimeCard(
                    label: "Minutes",
                    minValue: 0,
                    maxValue: 59,
                    onChanged: (val) => setState(() => minutes = val),
                  ),
                ),
              ],
            ),
            CheckboxListTile(
              title: Text("Send notifications even if there are no new items"),
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
            _buildCheckboxListTile("Yahoo! Japan Auction", YahooJapanAuction, (bool value) {
              setState(() => YahooJapanAuction = value);
            }),
            _buildCheckboxListTile("Yahoo! Japan Shopping", YahooJapanShopping, (bool value) {
              setState(() => YahooJapanShopping = value);
            }),
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
                width: double.infinity,  // Prend la largeur maximale
                height: MediaQuery.of(context).size.width * 10 / 16,  // 16:10 ratio
                decoration: BoxDecoration(
                  image: DecorationImage(
                    fit: BoxFit.cover,
                    image: FileImage(_image!),  // Affiche l'image sélectionnée
                  ),
                ),
              ),
            ElevatedButton(
              onPressed: pickImage,
              child: Text(_image == null ? "Choose Image" : "Change Image"),
            ),
            ElevatedButton(
              onPressed: addAlert,
              child: Text('Add Alert'),
            ),
          ],
        ),
      ),
    )
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
  final int minValue, maxValue;
  final Function(int) onChanged;

  TimeCard({required this.label, required this.minValue, required this.maxValue, required this.onChanged});

  @override
  _TimeCardState createState() => _TimeCardState();
}

class _TimeCardState extends State<TimeCard> {
  int currentValue = 0;

  @override
  void initState() {
    super.initState();
    currentValue = widget.minValue;
  }

  @override
  Widget build(BuildContext context) {
    List<DropdownMenuItem<int>> menuItems = List.generate(
      widget.maxValue - widget.minValue + 1,
          (index) => DropdownMenuItem(value: widget.minValue + index, child: Text('${widget.minValue + index}')),
    );

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Text(widget.label),
          DropdownButton<int>(
            value: currentValue,
            items: menuItems,
            onChanged: (int? newValue) {
              setState(() {
                currentValue = newValue!;
                widget.onChanged(currentValue);
              });
            },
          ),
        ],
      ),
    );
  }
}
