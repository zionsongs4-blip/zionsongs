import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'auth_repository.dart';

class AuthRepository {
  AuthRepository._();

  static final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static Future<bool> isUserApproved(User user) async {
    final email = user.email;

    if (email == null) {
      return false;
    }

    final query = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return false;
    }

    final data = query.docs.first.data();

    return data['status'] == 'approved';
  }
}