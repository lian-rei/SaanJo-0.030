import 'dart:io' as io;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';

Future<String> uploadImage(BuildContext context) async {
  final ImagePicker _picker = ImagePicker();
  final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

  if (image != null) {
    return await _uploadImageToStorage(image.path);
  }
  
  return '';
}

Future<String> _uploadImageToStorage(String filePath) async {
  String fileName = DateTime.now().millisecondsSinceEpoch.toString();
  
  if (await io.File(filePath).exists()) {
    try {
      Reference ref = FirebaseStorage.instance.ref().child("images/$fileName");
      await ref.putFile(io.File(filePath));
      return await ref.getDownloadURL();
    } catch (e) {
      print('Error uploading image: $e');
      return '';
    }
  }
  
  return '';
}
