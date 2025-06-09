import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart'; // Make sure this path is correct

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference _userRef = FirebaseFirestore.instance.collection(
    'users',
  );

  // Sign Up Method
  Future<User?> signUp(
    String email,
    String password,
    String name,
    String role,
  ) async {
    try {
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user;

      if (user == null) {
        throw Exception("User creation failed.");
      }

      // Create and store user model
      UserModel newUser = UserModel(
        uid: user.uid,
        email: email,
        name: name,
        role: role,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(newUser.toMap());

      // Persist to local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid', user.uid);
      await prefs.setString('email', email.trim());
      await prefs.setString('role', role.trim());
      await prefs.setString('name', name.trim());

      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception("Sign up failed: ${e.message}");
    } catch (e) {
      throw Exception("Sign up failed: ${e.toString()}");
    }
  }

  // Login and Get Role Method
  Future<Map<String, dynamic>> loginAndGetRole(
    String email,
    String password,
  ) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) throw Exception("No user found");

      // Fetch user data from Firestore
      DocumentSnapshot doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      if (!doc.exists) throw Exception("User data not found in Firestore");

      final data = doc.data() as Map<String, dynamic>;

      // Persist to local storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('uid', user.uid);
      await prefs.setString('email', user.email ?? '');
      await prefs.setString('role', data['role'] ?? '');
      await prefs.setString('name', data['name'] ?? '');

      return {
        'uid': user.uid,
        'email': user.email,
        'role': data['role'],
        'name': data['name'],
      };
    } on FirebaseAuthException catch (e) {
      throw Exception("Login failed: ${e.message}");
    } catch (e) {
      throw Exception("Login failed: ${e.toString()}");
    }
  }

  // Logout Method
  Future<void> logout() async {
    try {
      await _auth.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      throw Exception("Logout failed: ${e.toString()}");
    }
  }

  // Update Profile Method
  Future<void> updateProfile({
    required String name,
    required String email,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("No authenticated logged in");
    }

    // Update user data in Firestore
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'name': name,
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('email', email.trim());
    await prefs.setString('name', name.trim());
  }

  // Password Update Method
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception("No authenticated logged in");
    }

    // Reauthenticate the user
    final cred = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(cred);
    // Update the password
    await user.updatePassword(newPassword);
  }

  // Get current user data from local storage
  Future<Map<String, String>> getLocalUser() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'uid': prefs.getString('uid') ?? '',
      'email': prefs.getString('email') ?? '',
      'role': prefs.getString('role') ?? '',
      'name': prefs.getString('name') ?? '',
    };
  }

  Future<List<UserModel>> getUsersByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    final snapshots = await _userRef.where('uid', whereIn: ids).get();
    return snapshots.docs
        .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
        .toList();
  }

  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _userRef.doc(userId).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print("Failed to get user: $e");
      return null;
    }
  }
}
