import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  Stream<List<Task>> streamTasks(String uid, String sortField, bool descending) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .orderBy(sortField, descending: descending)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => Task.fromDoc(doc)).toList());
  }

  Future<void> addTask(
    String uid,
    String name,
    String description,
    int waga,
    DateTime termin,
    int czasTrwania,
  ) {
    return _db.collection('users').doc(uid).collection('tasks').add({
      'Nazwa': name,
      'Opis': description,
      'waga': waga,
      'termin': Timestamp.fromDate(termin),
      'czas_trwania': czasTrwania,
    });
  }

  Future<void> updateTask(String uid, Task task) {
    return _db.collection('users').doc(uid).collection('tasks').doc(task.id).update({
      'Nazwa': task.name,
      'Opis': task.description,
      'waga': task.waga,
      'termin': Timestamp.fromDate(task.termin),
      'czas_trwania': task.czasTrwania,
    });
  }

  Future<void> deleteTask(String uid, String taskId) {
    return _db.collection('users').doc(uid).collection('tasks').doc(taskId).delete();
  }
}
