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
import 'package:japanesegoodstool/TaskManager.dart';

class EditAlerte extends StatefulWidget {
  final String uid;
  final String alerteId;

  final VoidCallback onAlertAdded;

  const EditAlerte(
      {Key? key,
      required this.uid,
      required this.alerteId,
      required this.onAlertAdded})
      : super(key: key);

  @override
  _EditAlerteState createState() => _EditAlerteState();
}

class _EditAlerteState extends State<EditAlerte> {
  final FirebaseFirestore firestoreInstance = FirebaseFirestore.instance;
  TextEditingController artistController = TextEditingController();
  String artistBase = '';
  int days = 1;
  int hours = 0;
  int minutes = 0;
  bool sendNotifications = false;
  bool Melonbooks = false;
  bool Rakuten = false;
  bool Booth = false;
  bool Surugaya = false;
  bool Toranoana = false;
  bool Mandarake = false;
  File? _image;
  String imageBase = '';
  Widget? imageUrlWidget;

  @override
  void initState() {
    super.initState();
    loadAlertData();
  }

  void loadAlertData() async {
    try {
      var existingAlerts = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('alerts')
          .where('artist', isEqualTo: widget.alerteId)
          .limit(1)
          .get();

      if (existingAlerts.docs.isNotEmpty) {
        var alertData = existingAlerts.docs[0].data() as Map<String, dynamic>;
        setState(() {
          artistBase = alertData['artist'] ?? '';
          artistController.text = alertData['artist'] ?? '';
          days = alertData['days'] ?? 1;
          hours = alertData['hours'] ?? 0;
          minutes = alertData['minutes'] ?? 0;
          sendNotifications = alertData['sendNotifications'] ?? false;
          Melonbooks = alertData['sites']['Melonbooks'] ?? false;
          Rakuten = alertData['sites']['Rakuten'] ?? false;
          Booth = alertData['sites']['Booth'] ?? false;
          Surugaya = alertData['sites']['Surugaya'] ?? false;
          Toranoana = alertData['sites']['Toranoana'] ?? false;
          Mandarake = alertData['sites']['Mandarake'] ?? false;
          imageBase = alertData['imageUrl'] ?? '';

          // Check if there is an image
          if (alertData['imageUrl'] != '') {
            imageUrlWidget = Image.network(alertData['imageUrl']);
          }
        });
      }
    } catch (e) {}
  }

  bool isDurationValid(int days, int hours, int minutes) {
    // Check if the total amount of minutes is > 15 minutes
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
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void updateAlert() async {
    if (!isDurationValid(days, hours, minutes)) {
      showErrorDialog("Invalid Duration",
          "Length between checks must be at least 15 minutes.");
      return;
    }
    try {
      Map<String, dynamic> updateData = {
        'artist': artistController.text,
        'days': days,
        'hours': hours,
        'minutes': minutes,
        'sendNotifications': sendNotifications,
        'sites': {
          'Melonbooks': Melonbooks,
          'Rakuten': Rakuten,
          'Booth': Booth,
          'Surugaya': Surugaya,
          'Toranoana': Toranoana,
          'Mandarake': Mandarake,
        },
      };

      Future<String> uploadImage(File image) async {
        String extension = path.extension(image.path);

        if (extension.toLowerCase() != '.png' &&
            extension.toLowerCase() != '.jpg') {
          throw Exception('Only PNG and JPG files are allowed');
        }

        String fileName =
            'alerts/${widget.uid}/${DateTime.now().millisecondsSinceEpoch}$extension';
        Reference storageRef = FirebaseStorage.instance.ref().child(fileName);
        UploadTask uploadTask = storageRef.putFile(image);
        await uploadTask;
        return await storageRef.getDownloadURL();
      }

      Future<void> deleteImage(String imageUrl) async {
        try {
          Reference storageRef = FirebaseStorage.instance.refFromURL(imageUrl);
          await storageRef.delete();
        } catch (e) {}
      }

      if (_image != null && imageBase != '') {
        // upload pic and get URL
        String imageUrl = await uploadImage(_image!);
        updateData['imageUrl'] = imageUrl;

        // delete old image from firestore
        if (imageBase.isNotEmpty) {
          await deleteImage(imageBase);
        }
      } else {
        // If no new pic, stay with the current
        updateData['imageUrl'] = imageBase;
      }

      var querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('alerts')
          .where('artist', isEqualTo: widget.alerteId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        var documentId = querySnapshot.docs.first.id; // get doc ID

        await firestoreInstance
            .collection('users')
            .doc(widget.uid)
            .collection('alerts')
            .doc(documentId)
            .update(updateData)
            .then((_) async {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("Alert updated")));

          if (artistController.text != artistBase) {
            await cancelTask('task_' + artistBase);
            await setTaskEnabled("task_" + artistController.text, true,
                days: days,
                hours: hours,
                minutes: minutes,
                userId: widget.uid,
                artistName: artistController.text,
                notifzero: sendNotifications,
                FirstCheck: true);
          }

          final prefs = await SharedPreferences.getInstance();
          List<String>? artistesString = prefs.getStringList('artistes');
          if (artistesString != null) {
            List<String> updatedArtistesString = [];
            for (var str in artistesString) {
              var artiste = json.decode(str);
              if (artiste['nom'] == artistBase) {
                // Keep old name
                artiste['nom'] = artistController.text; // New name
                artiste['hours'] = hours;
                artiste['minutes'] = minutes;
                artiste['days'] = days;
                artiste['sendNotifications'] = sendNotifications;
                artiste['isTaskActive'] = true;
              }
              updatedArtistesString.add(json.encode(artiste));
            }
            await prefs.setStringList('artistes', updatedArtistesString);
          }

          widget.onAlertAdded();

          Navigator.pop(context);
        }).catchError((error) {});
      }
    } catch (e) {}
  }

  Future<void> pickImage() async {
    final ImagePicker picker = ImagePicker();

    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 600,
      imageQuality: 100,
    );

    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);

      CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Cropper',
            toolbarColor: Colors.deepOrange,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.ratio16x9,
            lockAspectRatio: true,
          )
        ],
      );

      if (croppedFile != null) {
        setState(() {
          _image = File(croppedFile.path);
          imageUrlWidget =
              null; // Reset imageUrlWidget to remove the previous image
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text("Edit Alert"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
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
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TimeCard(
                      label: "Days",
                      minValue: 0,
                      maxValue: 7,
                      value: days,
                      onChanged: (val) => setState(() => days = val),
                    ),
                  ),
                  Expanded(
                    child: TimeCard(
                      label: "Hours",
                      minValue: 0,
                      maxValue: 23,
                      value: hours,
                      onChanged: (val) => setState(() => hours = val),
                    ),
                  ),
                  Expanded(
                    child: TimeCard(
                      label: "Minutes",
                      minValue: 0,
                      maxValue: 59,
                      value: minutes,
                      onChanged: (val) => setState(() => minutes = val),
                    ),
                  ),
                ],
              ),
              CheckboxListTile(
                title: const Text(
                    "Send notifications even if there are no new items"),
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
              _buildSiteCheckbox("Melonbooks", Melonbooks,
                  (value) => setState(() => Melonbooks = value!)),
              _buildSiteCheckbox("Rakuten", Rakuten,
                  (value) => setState(() => Rakuten = value!)),
              _buildSiteCheckbox(
                  "Booth", Booth, (value) => setState(() => Booth = value!)),
              _buildSiteCheckbox("Surugaya", Surugaya,
                  (value) => setState(() => Surugaya = value!)),
              _buildSiteCheckbox("Toranoana", Toranoana,
                  (value) => setState(() => Toranoana = value!)),
              _buildSiteCheckbox("Mandarake", Mandarake,
                  (value) => setState(() => Mandarake = value!)),
              if (imageUrlWidget != null) imageUrlWidget!,
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
                onPressed: updateAlert,
                child: const Text('Update Alert'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSiteCheckbox(
      String title, bool value, void Function(bool?) onChanged) {
    return CheckboxListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }
}

class TimeCard extends StatefulWidget {
  final String label;
  final int minValue, maxValue, value;
  final Function(int) onChanged;

  const TimeCard(
      {Key? key,
      required this.label,
      required this.minValue,
      required this.maxValue,
      required this.value,
      required this.onChanged})
      : super(key: key);

  @override
  _TimeCardState createState() => _TimeCardState();
}

class _TimeCardState extends State<TimeCard> {
  @override
  Widget build(BuildContext context) {
    List<DropdownMenuItem<int>> menuItems = List.generate(
      widget.maxValue - widget.minValue + 1,
      (index) => DropdownMenuItem(
          value: widget.minValue + index,
          child: Text('${widget.minValue + index}')),
    );

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Text(widget.label),
          DropdownButton<int>(
            value: widget.value,
            items: menuItems,
            onChanged: (int? newValue) {
              setState(() {
                widget.onChanged(newValue ?? 0);
              });
            },
          ),
        ],
      ),
    );
  }
}
