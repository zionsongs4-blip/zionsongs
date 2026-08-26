import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_paths.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirestoreService instance = FirestoreService._();
  FirestoreService._();

  Stream<QuerySnapshot<Map<String, dynamic>>> streamHymns() {
    print('Reading hymns...');
    return _db.collection(FirestorePaths.hymns).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamViewlists() {
    print('Reading viewlists...');
    return _db.collection(FirestorePaths.viewlists).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMedleys() {
    print('Reading medleys...');
    return _db.collection(FirestorePaths.medleys).snapshots();
  }

  Future<void> createFolder(String collection, String docId, Map<String, dynamic> folderData) async {
    print('Creating folder...');
    final ref = _db.collection(collection).doc(docId);
    await ref.set(folderData, SetOptions(merge: true));
    print('Firestore update completed.');
  }

  Future<void> updateDocument(String collection, String docId, Map<String, dynamic> data) async {
    print('Updating document $collection/$docId...');
    final ref = _db.collection(collection).doc(docId);
    await ref.set(data, SetOptions(merge: true));
    print('Firestore update completed.');
  }
}
