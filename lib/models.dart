// lib/models.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole {
  manager,
  teacher,
  student,
}

class UserModel {
  final String uid;
  final String email;
  final String academyId;
  final UserRole role;
  final String name;
  final String? studentRecordId;

  UserModel({
    required this.uid,
    required this.email,
    required this.academyId,
    required this.role,
    required this.name,
    this.studentRecordId,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      academyId: data['academyId'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.toString() == 'UserRole.${data['role']}',
        orElse: () => UserRole.student,
      ),
      name: data['name'] ?? 'Nome não encontrado',
      studentRecordId: data['studentRecordId'],
    );
  }
}

class Aluno {
  final String id;
  String nome;
  String faixa;
  double peso;
  int? graus;
  String? userId;

  Aluno({
    required this.id,
    required this.nome,
    required this.faixa,
    required this.peso,
    this.graus,
    this.userId,
  });

  Aluno.novo({
    required this.nome,
    required this.faixa,
    required this.peso,
    this.graus,
  })  : id = '',
        userId = null;

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'faixa': faixa,
        'peso': peso,
        'graus': graus,
        'userId': userId,
      };

  static Aluno fromJson(String id, Map<String, dynamic> json) => Aluno(
        id: id,
        nome: json['nome'],
        faixa: json['faixa'],
        peso: json['peso']?.toDouble() ?? 0.0,
        graus: json['graus'] as int?,
        userId: json['userId'],
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Aluno && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class CheckinEntry {
  final String id;
  String studentId;
  DateTime date;

  CheckinEntry({required this.id, required this.studentId, required this.date});

  static CheckinEntry fromJson(String id, Map<String, dynamic> json) =>
      CheckinEntry(
        id: id,
        studentId: json['studentId'],
        date: (json['date'] as Timestamp).toDate(),
      );
}

class Luta {
  final Aluno aluno1;
  final Aluno aluno2;
  final double custo;
  Luta(this.aluno1, this.aluno2, this.custo);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Luta &&
          runtimeType == other.runtimeType &&
          ((aluno1 == other.aluno1 && aluno2 == other.aluno2) ||
              (aluno1 == other.aluno2 && aluno2 == other.aluno1));
  @override
  int get hashCode => aluno1.hashCode ^ aluno2.hashCode;
}

class StudyInstructional {
  final String id;
  String title;
  String createdByUid;
  String createdByName;
  String visibility; // 'public' ou 'private'
  List<StudyNote> notes;

  StudyInstructional({
    required this.id,
    required this.title,
    required this.createdByUid,
    required this.createdByName,
    required this.visibility,
    required this.notes,
  });

  factory StudyInstructional.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    var notesData = data['notes'] as List<dynamic>? ?? [];
    return StudyInstructional(
      id: doc.id,
      title: data['title'] ?? 'Sem Título',
      createdByUid: data['createdByUid'] ?? '',
      createdByName: data['createdByName'] ?? '',
      visibility: data['visibility'] ?? 'private',
      notes: notesData.map((noteData) => StudyNote.fromJson(noteData)).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'visibility': visibility,
      'notes': notes.map((note) => note.toJson()).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class StudyNote {
  String title;
  String description;

  StudyNote({required this.title, required this.description});

  factory StudyNote.fromJson(Map<String, dynamic> json) {
    return StudyNote(
      title: json['title'] ?? '',
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
    };
  }
}
