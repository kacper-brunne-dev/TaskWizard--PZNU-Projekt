import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  final String id;
  final String name;
  final String description;
  final int weight;
  final DateTime dueDate;
  final int durationMinutes;
  final bool done;

  Task({
    required this.id,
    required this.name,
    required this.description,
    required this.weight,
    required this.dueDate,
    required this.durationMinutes,
    this.done = false,
  });

  /// Alias for fromDocument
  factory Task.fromDoc(DocumentSnapshot doc) => Task.fromDocument(doc);

  factory Task.fromDocument(DocumentSnapshot doc) {
    final data = doc.data()! as Map<String, dynamic>;
    return Task(
      id: doc.id,
      name: data['Nazwa'] as String? ?? '',
      description: data['Opis'] as String? ?? '',
      weight: data['waga'] is int
          ? data['waga'] as int
          : int.tryParse(data['waga'].toString()) ?? 1,
      dueDate: (data['termin'] as Timestamp).toDate(),
      durationMinutes: data['czas_trwania'] is int
          ? data['czas_trwania'] as int
          : int.tryParse(data['czas_trwania'].toString()) ?? 0,
      done: data['zrobione'] as bool? ?? false,
    );
  }

  int get waga => weight;
  DateTime get termin => dueDate;
  int get czasTrwania => durationMinutes;

  Map<String, dynamic> toMap() {
    return {
      'Nazwa':        name,
      'Opis':         description,
      'waga':         weight,
      'termin':       Timestamp.fromDate(dueDate),
      'czas_trwania': durationMinutes,
      'zrobione':     done,
    };
  }
}
