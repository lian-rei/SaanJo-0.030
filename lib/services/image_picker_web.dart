import 'dart:html' as html;
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'dart:async';

Future<String> uploadImage(BuildContext context) async {
  final completer = Completer<String>();
  final input = html.FileUploadInputElement();
  input.accept = 'image/*';
  input.click();

  input.onChange.listen((e) async {
    final files = input.files;
    if (files!.isEmpty) {
      completer.complete('');
      return;
    }

    final reader = html.FileReader();
    reader.readAsArrayBuffer(files[0]);
    reader.onLoadEnd.listen((e) async {
      final data = reader.result as Uint8List;
      final ref = FirebaseStorage.instance.ref().child("images/${files[0].name}");

      try {
        await ref.putData(data);
        final downloadUrl = await ref.getDownloadURL();
        completer.complete(downloadUrl);
      } catch (e) {
        print('Error uploading image: $e');
        completer.complete('');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
    });
  });

  return completer.future;
}
