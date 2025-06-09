import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

 class StorageService {
   final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String> uploadImage(File imageFile, String path) async {
    Reference ref = _storage.ref().child(path);
     UploadTask uploadTask = ref.putFile(imageFile);
     TaskSnapshot snapshot = await uploadTask;
     return await snapshot.ref.getDownloadURL();
   }
 }
