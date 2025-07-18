// lib/models.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Enum para os diferentes tipos de papéis de usuário no sistema.
enum UserRole {
  manager, // Gerente da academia
  teacher, // Professor
  student, // Aluno
  unknown, // Papel desconhecido ou não definido
}

// Enum para o status de pagamento da mensalidade.
enum PaymentStatus {
  pago, // Pagamento realizado
  pendente, // Pagamento aguardando (dentro do prazo)
  atrasado, // Pagamento não realizado (após o vencimento)
}

/// Modelo para representar um Usuário do sistema (login via FirebaseAuth).
/// Pode ser um gerente, professor ou aluno com acesso ao app.
class UserModel {
  final String uid;
  final String name;
  final String email;
  final String academyId;
  final UserRole role;
  final String? studentRecordId; // Link para o registro de 'Aluno'
  final bool mustChangePassword;
  final bool isActive;
  // Campos de perfil para gerentes e professores
  final String? faixa;
  final int? graus;
  final double? peso;
  final String? profileImagePath;
  final DateTime? dataNascimento; // NOVO CAMPO

  // [MELHORIA] Campos de Auditoria
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final String? createdByUid;
  final String? createdByName;
  final String? lastUpdatedByUid;
  final String? lastUpdatedByName;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.academyId,
    required this.role,
    this.studentRecordId,
    required this.mustChangePassword,
    required this.isActive,
    this.faixa,
    this.graus,
    this.peso,
    this.profileImagePath,
    this.dataNascimento, // NOVO CAMPO
    this.createdAt,
    this.updatedAt,
    this.createdByUid,
    this.createdByName,
    this.lastUpdatedByUid,
    this.lastUpdatedByName,
  });

  // GETTER PARA CALCULAR A IDADE
  int? get idade {
    if (dataNascimento == null) return null;
    final hoje = DateTime.now();
    int idade = hoje.year - dataNascimento!.year;
    if (hoje.month < dataNascimento!.month ||
        (hoje.month == dataNascimento!.month &&
            hoje.day < dataNascimento!.day)) {
      idade--;
    }
    return idade;
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    UserRole role;
    switch (data['role']) {
      case 'manager':
        role = UserRole.manager;
        break;
      case 'teacher':
        role = UserRole.teacher;
        break;
      case 'student':
        role = UserRole.student;
        break;
      default:
        role = UserRole.unknown;
    }

    return UserModel(
      uid: doc.id,
      name: data['name'] ?? 'Nome não definido',
      email: data['email'] ?? '',
      academyId: data['academyId'] ?? '',
      role: role,
      studentRecordId: data['studentRecordId'],
      mustChangePassword: data['mustChangePassword'] ?? false,
      isActive: data['isActive'] ?? true,
      faixa: data['faixa'],
      graus: data['graus'],
      peso: (data['peso'] as num?)?.toDouble(),
      profileImagePath: data['profileImagePath'],
      dataNascimento:
          (data['dataNascimento'] as Timestamp?)?.toDate(), // NOVO CAMPO
      // [MELHORIA] Lendo campos de auditoria
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
      createdByUid: data['createdByUid'],
      createdByName: data['createdByName'],
      lastUpdatedByUid: data['lastUpdatedByUid'],
      lastUpdatedByName: data['lastUpdatedByName'],
    );
  }
}

/// Modelo para representar um Aluno na academia.
/// Pode ou não ter um `userId` associado (se tiver acesso de login).
class Aluno {
  final String id; // ID do documento na subcoleção 'students'
  String nome;
  String faixa;
  double peso;
  int? graus;
  final DateTime? dataNascimento; // CAMPO EXISTENTE
  String? userId; // ID do usuário no Auth, se tiver acesso
  PaymentStatus paymentStatus; // Usado na tela de mensalidades

  // [MELHORIA] Campos de Auditoria
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final String? createdByUid;
  final String? createdByName;
  final String? lastUpdatedByUid;
  final String? lastUpdatedByName;

  Aluno({
    required this.id,
    required this.nome,
    required this.faixa,
    required this.peso,
    this.graus,
    this.dataNascimento,
    this.userId,
    this.paymentStatus = PaymentStatus.pendente,
    this.createdAt,
    this.updatedAt,
    this.createdByUid,
    this.createdByName,
    this.lastUpdatedByUid,
    this.lastUpdatedByName,
  });

  // GETTER PARA CALCULAR A IDADE
  int? get idade {
    if (dataNascimento == null) return null;
    final hoje = DateTime.now();
    int idade = hoje.year - dataNascimento!.year;
    if (hoje.month < dataNascimento!.month ||
        (hoje.month == dataNascimento!.month &&
            hoje.day < dataNascimento!.day)) {
      idade--;
    }
    return idade;
  }

  // Construtor para criar um Aluno sem ID ainda (antes de salvar no Firestore)
  Aluno.novo({
    required this.nome,
    required this.faixa,
    required this.peso,
    this.graus,
    this.dataNascimento,
    this.userId,
    this.createdByUid,
    this.createdByName,
  })  : id = '',
        paymentStatus = PaymentStatus.pendente,
        createdAt = null, // Será definido no servidor
        updatedAt = null, // Será definido no servidor
        lastUpdatedByUid = createdByUid,
        lastUpdatedByName = createdByName;

  // Converte um objeto Aluno para um Map JSON para salvar no Firestore.
  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'faixa': faixa,
      'peso': peso,
      'graus': graus,
      'dataNascimento':
          dataNascimento != null ? Timestamp.fromDate(dataNascimento!) : null,
      'userId': userId,
      // [MELHORIA] Salvando campos de auditoria
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'lastUpdatedByUid': lastUpdatedByUid,
      'lastUpdatedByName': lastUpdatedByName,
    };
  }

  // Cria um objeto Aluno a partir de um documento do Firestore.
  factory Aluno.fromJson(String id, Map<String, dynamic> json) {
    return Aluno(
      id: id,
      nome: json['nome'] ?? 'Sem nome',
      faixa: json['faixa'] ?? 'Branca',
      peso: (json['peso'] as num?)?.toDouble() ?? 0.0,
      graus: json['graus'],
      dataNascimento: (json['dataNascimento'] as Timestamp?)?.toDate(),
      userId: json['userId'],
      // [MELHORIA] Lendo campos de auditoria
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      createdByUid: json['createdByUid'],
      createdByName: json['createdByName'],
      lastUpdatedByUid: json['lastUpdatedByUid'],
      lastUpdatedByName: json['lastUpdatedByName'],
    );
  }

  // Converte um UserModel (professor) em um objeto Aluno para participar de sorteios/lutas.
  factory Aluno.fromUserModel(UserModel user) {
    return Aluno(
      id: user.uid, // Usa o UID do usuário como ID único do participante
      nome: user.name,
      faixa: user.faixa ?? 'Preta', // Padrão para professores
      peso: user.peso ?? 80.0, // Um peso padrão
      graus: user.graus,
      userId: user.uid,
      dataNascimento: user.dataNascimento, // Passa a data de nascimento
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Aluno && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Modelo para armazenar as configurações de uma luta no placar.
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

  Color _getColorFromString(String colorString) {
    switch (colorString.toLowerCase()) {
      case 'azul':
        return Colors.blue.shade300;
      case 'preto':
        return Colors.grey.shade800;
      case 'branco':
      default:
        return Colors.white;
    }
  }
}

/// Modelo para representar um registro de pagamento de mensalidade.
class MonthlyFee {
  final String id;
  final String studentId;
  final double amount;
  final DateTime paymentDate;
  final String paymentMethod;
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
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MonthlyFee(
      id: doc.id,
      studentId: data['studentId'],
      amount: (data['amount'] as num).toDouble(),
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
      'paymentDate': paymentDate,
      'paymentMethod': paymentMethod,
      'paymentYear': paymentYear,
      'paymentMonth': paymentMonth,
    };
  }
}

/// Modelo para um registro de check-in (presença).
class CheckinEntry {
  final String id;
  final String studentId;
  final DateTime date;
  final String? creatorId;
  final String? creatorName;

  CheckinEntry({
    required this.id,
    required this.studentId,
    required this.date,
    this.creatorId,
    this.creatorName,
  });

  factory CheckinEntry.fromJson(String id, Map<String, dynamic> json) {
    return CheckinEntry(
      id: id,
      studentId: json['studentId'],
      date: (json['date'] as Timestamp).toDate(),
      creatorId: json['creatorId'],
      creatorName: json['creatorName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'date': Timestamp.fromDate(date),
      'creatorId': creatorId,
      'creatorName': creatorName,
    };
  }
}

/// Modelo auxiliar para a geração de lutas nos sorteios.
class Luta {
  final Aluno aluno1;
  final Aluno aluno2;
  final double custo; // Diferença de peso ou faixa

  Luta(this.aluno1, this.aluno2, this.custo);
}

/// Modelo para uma anotação no caderno de estudos pessoal de cada usuário.
class StudyNote {
  final String id;
  String title;
  String content;
  List<String> tags;
  String? videoUrl;
  String? imagePath;
  final DateTime createdAt;
  DateTime updatedAt;

  StudyNote({
    required this.id,
    required this.title,
    required this.content,
    required this.tags,
    this.videoUrl,
    this.imagePath,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StudyNote.create({
    required String title,
    required String content,
    List<String>? tags,
    String? videoUrl,
    String? imagePath,
  }) {
    final now = DateTime.now();
    return StudyNote(
      id: now.millisecondsSinceEpoch.toString(),
      title: title,
      content: content,
      tags: tags ?? [],
      videoUrl: videoUrl,
      imagePath: imagePath,
      createdAt: now,
      updatedAt: now,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'tags': tags,
      'videoUrl': videoUrl,
      'imagePath': imagePath,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory StudyNote.fromJson(Map<String, dynamic> json) {
    return StudyNote(
      id: json['id'],
      title: json['title'],
      content: json['content'],
      tags: List<String>.from(json['tags']),
      videoUrl: json['videoUrl'],
      imagePath: json['imagePath'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}
