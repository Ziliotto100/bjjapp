// lib/models.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// --- ENUMS ---

// Função auxiliar para converter String para UserRole
UserRole _roleFromString(String? role) {
  return UserRole.values.firstWhere(
    (e) => e.toString() == 'UserRole.$role',
    orElse: () => UserRole.student,
  );
}

enum UserRole {
  manager,
  teacher,
  student,
}

enum PaymentStatus { pago, pendente, atrasado }

// --- MODELOS DE USUÁRIO E AUTENTICAÇÃO ---

class UserModel {
  final String uid;
  final String email;
  final String academyId;
  final UserRole role;
  final String name;
  final String? studentRecordId;
  final bool mustChangePassword;
  final bool isActive;
  final String? faixa;
  final int? graus;
  final double? peso;

  UserModel({
    required this.uid,
    required this.email,
    required this.academyId,
    required this.role,
    required this.name,
    this.studentRecordId,
    required this.mustChangePassword,
    this.isActive = true,
    this.faixa,
    this.graus,
    this.peso,
  });

  factory UserModel.fromFirestore(DocumentSnapshot<Object?> doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: data['name'] ?? 'Nome Ausente',
      email: data['email'] ?? 'E-mail Ausente',
      academyId: data['academyId'] ?? '',
      role: _roleFromString(data['role']),
      studentRecordId: data['studentRecordId'],
      mustChangePassword: data['mustChangePassword'] ?? false,
      isActive: data['isActive'] ?? true,
      faixa: data['faixa'],
      graus: data['graus'],
      peso: data['peso']?.toDouble(),
    );
  }
}

// --- MODELOS PRINCIPAIS DA ACADEMIA ---

class Aluno {
  final String id;
  String nome;
  String faixa;
  double peso;
  int? graus;
  String? userId;
  final bool isActive;
  PaymentStatus paymentStatus; // Novo campo para status da mensalidade

  Aluno({
    required this.id,
    required this.nome,
    required this.faixa,
    required this.peso,
    this.graus,
    this.userId,
    this.isActive = true,
    this.paymentStatus = PaymentStatus.pendente, // Padrão
  });

  Aluno.novo({
    required this.nome,
    required this.faixa,
    required this.peso,
    this.graus,
  })  : id = '',
        userId = null,
        isActive = true,
        paymentStatus = PaymentStatus.pendente;

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'faixa': faixa,
        'peso': peso,
        'graus': graus,
        'userId': userId,
        'isActive': isActive,
      };

  static Aluno fromJson(String id, Map<String, dynamic> json) => Aluno(
        id: id,
        nome: json['nome'] ?? 'Nome Ausente',
        faixa: json['faixa'] ?? 'Faixa Ausente',
        peso: json['peso']?.toDouble() ?? 0.0,
        graus: json['graus'] as int?,
        userId: json['userId'],
        isActive: json['isActive'] ?? true,
      );

  factory Aluno.fromUserModel(UserModel user) {
    return Aluno(
      id: user.uid,
      nome: user.name,
      faixa: user.faixa ?? 'Não informada',
      peso: user.peso ?? 0.0,
      graus: user.graus,
      userId: user.uid,
      isActive: user.isActive,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Aluno && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return '$nome ($faixa - ${peso}kg)';
  }
}

class CheckinEntry {
  final String id;
  String studentId;
  DateTime date;

  CheckinEntry({required this.id, required this.studentId, required this.date});

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'date': Timestamp.fromDate(date),
      };

  static CheckinEntry fromJson(String id, Map<String, dynamic> json) =>
      CheckinEntry(
        id: id,
        studentId: json['studentId'],
        date: (json['date'] as Timestamp).toDate(),
      );
}

// --- NOVO MODELO PARA MENSALIDADES ---
class MonthlyFee {
  final String id;
  final String studentId;
  final double amount;
  final DateTime paymentDate;
  final String
      paymentMethod; // 'dinheiro', 'pix', 'cartao_debito', 'cartao_credito'
  final int paymentYear;
  final int paymentMonth;

  MonthlyFee({
    required this.id,
    required this.studentId,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    required this.paymentYear,
    required this.paymentMonth,
  });

  factory MonthlyFee.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MonthlyFee(
      id: doc.id,
      studentId: data['studentId'],
      amount: data['amount']?.toDouble() ?? 0.0,
      paymentDate: (data['paymentDate'] as Timestamp).toDate(),
      paymentMethod: data['paymentMethod'],
      paymentYear: data['paymentYear'],
      paymentMonth: data['paymentMonth'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'amount': amount,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'paymentMethod': paymentMethod,
      'paymentYear': paymentYear,
      'paymentMonth': paymentMonth,
    };
  }
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

  @override
  String toString() {
    if (aluno1.nome == "DESCANSA") return '${aluno2.nome} (descansa)';
    if (aluno2.nome == "DESCANSA") return '${aluno1.nome} (descansa)';
    return '${aluno1.nome} x ${aluno2.nome}';
  }
}

// --- MODELOS DE ESTUDOS ---

class StudyNote {
  String title;
  String description;

  StudyNote({required this.title, required this.description});

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
    };
  }

  factory StudyNote.fromJson(Map<String, dynamic> json) {
    return StudyNote(
      title: json['title'] ?? 'Sem Título',
      description: json['description'] ?? 'Sem Descrição',
    );
  }
}

class StudyInstructional {
  final String id;
  String title;
  final String createdByUid;
  final String createdByName;
  String visibility;
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

// --- MODELOS PARA O PLACAR ---

class MatchSettings {
  final Aluno athlete1;
  final Aluno athlete2;
  final String kimonoColor1;
  final String kimonoColor2;
  final Duration matchDuration;

  MatchSettings({
    required this.athlete1,
    required this.athlete2,
    required this.kimonoColor1,
    required this.kimonoColor2,
    required this.matchDuration,
  });

  Color get colorForAthlete1 => _getColorFromString(kimonoColor1);
  Color get colorForAthlete2 => _getColorFromString(kimonoColor2);

  Color _getColorFromString(String color) {
    switch (color) {
      case 'Azul':
        return Colors.blue.shade600;
      case 'Preto':
        return Colors.grey.shade800;
      case 'Branco':
      default:
        return Colors.white;
    }
  }
}
