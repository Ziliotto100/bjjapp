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

// NOVO ENUM para o status do check-in
enum CheckinStatus {
  pending,
  approved,
}

// Helper para converter o enum de status do check-in para String e vice-versa
String checkinStatusToString(CheckinStatus status) {
  switch (status) {
    case CheckinStatus.pending:
      return 'pending';
    case CheckinStatus.approved:
      return 'approved';
  }
}

CheckinStatus checkinStatusFromString(String? statusString) {
  if (statusString == 'approved') {
    return CheckinStatus.approved;
  }
  return CheckinStatus.pending; // Padrão é pendente
}

/// Modelo para representar um Usuário do sistema (login via FirebaseAuth).
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
  final DateTime? dataNascimento;
  final Map<String, int> monthlyTrainingGoals;
  final Timestamp? lastNotificationCheck;

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
    this.dataNascimento,
    this.monthlyTrainingGoals = const {},
    this.lastNotificationCheck,
    this.createdAt,
    this.updatedAt,
    this.createdByUid,
    this.createdByName,
    this.lastUpdatedByUid,
    this.lastUpdatedByName,
  });

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

    final goalsData =
        data['monthlyTrainingGoals'] as Map<String, dynamic>? ?? {};
    final Map<String, int> goals = goalsData.map((key, value) {
      return MapEntry(key, (value as num).toInt());
    });

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
      dataNascimento: (data['dataNascimento'] as Timestamp?)?.toDate(),
      monthlyTrainingGoals: goals,
      lastNotificationCheck: data['lastNotificationCheck'],
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
      createdByUid: data['createdByUid'],
      createdByName: data['createdByName'],
      lastUpdatedByUid: data['lastUpdatedByUid'],
      lastUpdatedByName: data['lastUpdatedByName'],
    );
  }
}

class Aluno {
  final String id;
  String nome;
  String faixa;
  double peso;
  int? graus;
  final DateTime? dataNascimento;
  String? userId;
  PaymentStatus paymentStatus;

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

  Aluno.novo({
    this.id = '',
    required this.nome,
    required this.faixa,
    required this.peso,
    this.graus,
    this.dataNascimento,
    this.userId,
    this.createdByUid,
    this.createdByName,
  })  : paymentStatus = PaymentStatus.pendente,
        createdAt = null,
        updatedAt = null,
        lastUpdatedByUid = createdByUid,
        lastUpdatedByName = createdByName;

  Map<String, dynamic> toJson() {
    return {
      'nome': nome,
      'faixa': faixa,
      'peso': peso,
      'graus': graus,
      'dataNascimento':
          dataNascimento != null ? Timestamp.fromDate(dataNascimento!) : null,
      'userId': userId,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'lastUpdatedByUid': lastUpdatedByUid,
      'lastUpdatedByName': lastUpdatedByName,
    };
  }

  factory Aluno.fromJson(String id, Map<String, dynamic> json) {
    return Aluno(
      id: id,
      nome: json['nome'] ?? 'Sem nome',
      faixa: json['faixa'] ?? 'Branca',
      peso: (json['peso'] as num?)?.toDouble() ?? 0.0,
      graus: json['graus'],
      dataNascimento: (json['dataNascimento'] as Timestamp?)?.toDate(),
      userId: json['userId'],
      createdAt: json['createdAt'],
      updatedAt: json['updatedAt'],
      createdByUid: json['createdByUid'],
      createdByName: json['createdByName'],
      lastUpdatedByUid: json['lastUpdatedByUid'],
      lastUpdatedByName: json['lastUpdatedByName'],
    );
  }

  factory Aluno.fromUserModel(UserModel user) {
    return Aluno(
      id: user.uid,
      nome: user.name,
      faixa: user.faixa ?? 'Preta',
      peso: user.peso ?? 80.0,
      graus: user.graus,
      userId: user.uid,
      dataNascimento: user.dataNascimento,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Aluno && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

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

class CheckinEntry {
  final String id;
  final String studentId;
  final DateTime date;
  final String? creatorId;
  final String? creatorName;
  final CheckinStatus status;
  final String? classId;
  final String? className;
  final String? studentName;

  CheckinEntry({
    required this.id,
    required this.studentId,
    required this.date,
    this.creatorId,
    this.creatorName,
    this.status = CheckinStatus.pending,
    this.classId,
    this.className,
    this.studentName,
  });

  factory CheckinEntry.fromJson(String id, Map<String, dynamic> json) {
    return CheckinEntry(
      id: id,
      studentId: json['studentId'] ?? '',
      date: (json['date'] as Timestamp).toDate(),
      creatorId: json['creatorId'],
      creatorName: json['creatorName'],
      status: checkinStatusFromString(json['status']),
      classId: json['classId'],
      className: json['className'],
      studentName: json['studentName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'studentId': studentId,
      'date': Timestamp.fromDate(date),
      'creatorId': creatorId,
      'creatorName': creatorName,
      'status': checkinStatusToString(status),
      'classId': classId,
      'className': className,
      'studentName': studentName,
    };
  }
}

class Luta {
  final Aluno aluno1;
  final Aluno aluno2;
  final double custo;

  Luta(this.aluno1, this.aluno2, this.custo);
}

class StudySubject {
  final String id;
  String title;
  final DateTime createdAt;

  StudySubject({
    required this.id,
    required this.title,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory StudySubject.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudySubject(
      id: doc.id,
      title: data['title'] ?? 'Sem Título',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}

class StudyVolume {
  final String id;
  String title;
  final String subjectId;
  final DateTime createdAt;

  StudyVolume({
    required this.id,
    required this.title,
    required this.subjectId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'subjectId': subjectId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory StudyVolume.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudyVolume(
      id: doc.id,
      title: data['title'] ?? 'Sem Título',
      subjectId: data['subjectId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }
}

class StudyNote {
  final String id;
  String title;
  String content;
  List<String> tags;
  String? videoUrl;
  String? imagePath;
  final DateTime createdAt;
  DateTime updatedAt;
  final String volumeId;

  StudyNote({
    required this.id,
    required this.title,
    required this.content,
    required this.tags,
    this.videoUrl,
    this.imagePath,
    required this.createdAt,
    required this.updatedAt,
    required this.volumeId,
  });

  factory StudyNote.create({
    required String title,
    required String content,
    required String volumeId,
    List<String>? tags,
    String? videoUrl,
    String? imagePath,
  }) {
    final now = DateTime.now();
    return StudyNote(
      id: '',
      title: title,
      content: content,
      tags: tags ?? [],
      videoUrl: videoUrl,
      imagePath: imagePath,
      createdAt: now,
      updatedAt: now,
      volumeId: volumeId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'tags': tags,
      'videoUrl': videoUrl,
      'imagePath': imagePath,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'volumeId': volumeId,
    };
  }

  factory StudyNote.fromFirestore(DocumentSnapshot doc) {
    final json = doc.data() as Map<String, dynamic>;
    return StudyNote(
      id: doc.id,
      title: json['title'] ?? 'Sem título',
      content: json['content'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      videoUrl: json['videoUrl'],
      imagePath: json['imagePath'],
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
      volumeId: json['volumeId'] ?? '',
    );
  }
}

// --- MODELO DE PRODUTOS DA LOJA ATUALIZADO ---

enum ProductStatus { disponivel, esgotado, sobEncomenda }

String productStatusToString(ProductStatus status) {
  switch (status) {
    case ProductStatus.disponivel:
      return 'Disponível';
    case ProductStatus.esgotado:
      return 'Esgotado';
    case ProductStatus.sobEncomenda:
      return 'Sob Encomenda';
  }
}

ProductStatus productStatusFromString(String? statusString) {
  switch (statusString) {
    case 'Esgotado':
      return ProductStatus.esgotado;
    case 'Sob Encomenda':
      return ProductStatus.sobEncomenda;
    default:
      return ProductStatus.disponivel;
  }
}

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final List<String> imageUrls;
  final String category;
  final bool isFeatured;
  final bool isPromo; // NOVO CAMPO
  final ProductStatus status; // NOVO CAMPO
  final Timestamp createdAt;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrls,
    required this.category,
    this.isFeatured = false,
    this.isPromo = false, // NOVO
    required this.status, // NOVO
    required this.createdAt,
  });

  bool get isNew {
    return DateTime.now().difference(createdAt.toDate()).inDays <= 15;
  }

  factory Product.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    List<String> urls = [];
    if (data['imageUrls'] is List) {
      urls = List<String>.from(data['imageUrls']);
    } else if (data['imageUrl'] is String) {
      urls.add(data['imageUrl']);
    }

    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      imageUrls: urls,
      category: data['category'] ?? 'Geral',
      isFeatured: data['isFeatured'] ?? false,
      isPromo: data['isPromo'] ?? false, // NOVO
      status: productStatusFromString(data['status']), // NOVO
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'imageUrls': imageUrls,
      'category': category,
      'isFeatured': isFeatured,
      'isPromo': isPromo, // NOVO
      'status': productStatusToString(status), // NOVO
      'createdAt': createdAt,
    };
  }
}

// --- NOVO MODELO PARA NOTIFICAÇÕES ---
class NotificationModel {
  final String id;
  final String title;
  final String message;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String academyId;
  final Timestamp createdAt;
  final List<String> readBy; // <-- NOVO CAMPO

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.academyId,
    required this.createdAt,
    this.readBy = const [], // <-- NOVO PARÂMETRO
  });

  factory NotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NotificationModel(
      id: doc.id,
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderRole: data['senderRole'] ?? '',
      academyId: data['academyId'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      readBy: List<String>.from(data['readBy'] ?? []), // <-- NOVA ATRIBUIÇÃO
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'message': message,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'academyId': academyId,
      'createdAt': createdAt,
      'readBy': readBy, // <-- NOVO CAMPO
    };
  }
}

// --- NOVO MODELO PARA HISTÓRICO DE GRADUAÇÃO ---
class GraduationHistory {
  final String id;
  final String belt;
  final int? degree;
  final DateTime date;
  final String? promotedByUid;
  final String? promotedByName;

  GraduationHistory({
    required this.id,
    required this.belt,
    this.degree,
    required this.date,
    this.promotedByUid,
    this.promotedByName,
  });

  factory GraduationHistory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return GraduationHistory(
      id: doc.id,
      belt: data['belt'] ?? 'Branca',
      degree: data['degree'],
      date: (data['date'] as Timestamp).toDate(),
      promotedByUid: data['promotedByUid'],
      promotedByName: data['promotedByName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'belt': belt,
      'degree': degree,
      'date': Timestamp.fromDate(date),
      'promotedByUid': promotedByUid,
      'promotedByName': promotedByName,
    };
  }
}
