// lib/models.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Enum para os diferentes tipos de papéis de usuário no sistema.
enum UserRole {
  superAdmin, // <<< NOVO PERFIL ADICIONADO AQUI
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
  final String? phoneNumber;
  final Map<String, String>? address;
  final Map<String, int> monthlyTrainingGoals;
  // *** NOVOS CAMPOS PARA UNIDADES ***
  final String? unitId;
  final String? unitName;
  final String? lastSelectedUnitId;
  final bool canUploadStudyVideos;

  // [MELHORIA] Campos de Auditoria
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final String? createdByUid;
  final String? createdByName;
  final String? lastUpdatedByUid;
  final String? lastUpdatedByName;

  // NOVO CAMPO PARA O POP-UP DE BOAS-VINDAS
  final bool hasSeenWelcomePopup;
  final List<String>? fcmTokens; // NOVO CAMPO ADICIONADO

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
    this.phoneNumber,
    this.address,
    this.monthlyTrainingGoals = const {},
    this.unitId,
    this.unitName,
    this.lastSelectedUnitId,
    this.canUploadStudyVideos = false,
    this.createdAt,
    this.updatedAt,
    this.createdByUid,
    this.createdByName,
    this.lastUpdatedByUid,
    this.lastUpdatedByName,
    this.hasSeenWelcomePopup = false,
    this.fcmTokens,
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
      // <<< NOVA VERIFICAÇÃO ADICIONADA AQUI >>>
      case 'superadmin':
        role = UserRole.superAdmin;
        break;
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

    Map<String, String>? addressMap;
    if (data['address'] is Map) {
      addressMap = Map<String, String>.from(data['address']);
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
      dataNascimento: (data['dataNascimento'] as Timestamp?)?.toDate(),
      phoneNumber: data['phoneNumber'],
      address: addressMap,
      monthlyTrainingGoals: goals,
      unitId: data['unitId'],
      unitName: data['unitName'],
      lastSelectedUnitId: data['lastSelectedUnitId'],
      canUploadStudyVideos: data['canUploadStudyVideos'] ?? false,
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
      createdByUid: data['createdByUid'],
      createdByName: data['createdByName'],
      lastUpdatedByUid: data['lastUpdatedByUid'],
      lastUpdatedByName: data['lastUpdatedByName'],
      hasSeenWelcomePopup: data['hasSeenWelcomePopup'] ?? false,
      fcmTokens: data['fcmTokens'] != null
          ? List<String>.from(data['fcmTokens'])
          : null,
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
  bool isActive;
  // CAMPOS ADICIONADOS
  String? phoneNumber;
  Map<String, String>? address;
  // *** NOVOS CAMPOS PARA UNIDADES ***
  String? unitId;
  String? unitName;

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
    this.isActive = true,
    this.phoneNumber,
    this.address,
    this.unitId,
    this.unitName,
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
    this.phoneNumber,
    this.address,
    this.unitId,
    this.unitName,
    this.createdByUid,
    this.createdByName,
  })  : paymentStatus = PaymentStatus.pendente,
        isActive = true,
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
      'isActive': isActive,
      'phoneNumber': phoneNumber,
      'address': address,
      'unitId': unitId,
      'unitName': unitName,
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
      isActive: json['isActive'] ?? true,
      phoneNumber: json['phoneNumber'],
      address: json['address'] != null
          ? Map<String, String>.from(json['address'])
          : null,
      unitId: json['unitId'],
      unitName: json['unitName'],
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
      isActive: user.isActive,
      phoneNumber: user.phoneNumber,
      address: user.address,
      unitId: user.unitId,
      unitName: user.unitName,
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
  final int orderIndex;

  StudySubject({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.orderIndex,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'createdAt': Timestamp.fromDate(createdAt),
      'orderIndex': orderIndex,
    };
  }

  factory StudySubject.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudySubject(
      id: doc.id,
      title: data['title'] ?? 'Sem Título',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      orderIndex: data['orderIndex'] ?? 0,
    );
  }
}

class StudyVolume {
  final String id;
  String title;
  final String subjectId;
  final DateTime createdAt;
  final int orderIndex;

  StudyVolume({
    required this.id,
    required this.title,
    required this.subjectId,
    required this.createdAt,
    required this.orderIndex,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'subjectId': subjectId,
      'createdAt': Timestamp.fromDate(createdAt),
      'orderIndex': orderIndex,
    };
  }

  factory StudyVolume.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudyVolume(
      id: doc.id,
      title: data['title'] ?? 'Sem Título',
      subjectId: data['subjectId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      orderIndex: data['orderIndex'] ?? 0,
    );
  }
}

class StudyNote {
  final String id;
  String? title;
  String content;
  List<String> tags;
  String? videoUrl;
  String? imagePath;
  final DateTime createdAt;
  DateTime updatedAt;
  final String? subjectId;
  final String? volumeId;

  StudyNote({
    required this.id,
    this.title,
    required this.content,
    required this.tags,
    this.videoUrl,
    this.imagePath,
    required this.createdAt,
    required this.updatedAt,
    this.subjectId,
    this.volumeId,
  });

  factory StudyNote.create({
    String? title,
    required String content,
    String? subjectId,
    String? volumeId,
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
      subjectId: subjectId,
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
      'subjectId': subjectId,
      'volumeId': volumeId,
    };
  }

  factory StudyNote.fromFirestore(DocumentSnapshot doc) {
    final json = doc.data() as Map<String, dynamic>;
    return StudyNote(
      id: doc.id,
      title: json['title'],
      content: json['content'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      videoUrl: json['videoUrl'],
      imagePath: json['imagePath'],
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
      subjectId: json['subjectId'],
      volumeId: json['volumeId'],
    );
  }
}

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
  final bool isPromo;
  final ProductStatus status;
  final Timestamp createdAt;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrls,
    required this.category,
    this.isFeatured = false,
    this.isPromo = false,
    required this.status,
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
      isPromo: data['isPromo'] ?? false,
      status: productStatusFromString(data['status']),
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
      'isPromo': isPromo,
      'status': productStatusToString(status),
      'createdAt': createdAt,
    };
  }
}

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

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }

  String capitalizeWords() {
    if (trim().isEmpty) return '';
    return trim().split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}

class PaymentRecord {
  final String id;
  final double amount;
  final DateTime paymentDate;
  final String paymentMethod;
  final String? notes;
  final String recordedByUid;

  PaymentRecord({
    required this.id,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    this.notes,
    required this.recordedByUid,
  });

  factory PaymentRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentRecord(
      id: doc.id,
      amount: (data['amount'] as num).toDouble(),
      paymentDate: (data['paymentDate'] as Timestamp).toDate(),
      paymentMethod: data['paymentMethod'] ?? 'Não informado',
      notes: data['notes'],
      recordedByUid: data['recordedByUid'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'paymentDate': Timestamp.fromDate(paymentDate),
      'paymentMethod': paymentMethod,
      'notes': notes,
      'recordedByUid': recordedByUid,
    };
  }
}

enum TrainingModality {
  gi,
  nogi,
}

String modalityToString(TrainingModality modality) {
  return modality == TrainingModality.gi ? 'Gi' : 'No-Gi';
}

TrainingModality modalityFromString(String? modalityString) {
  if (modalityString == 'No-Gi') {
    return TrainingModality.nogi;
  }
  return TrainingModality.gi;
}

class TrainingClass {
  final String id;
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final String teacherId;
  final String teacherName;
  final TrainingModality modality;
  final String description;
  final String level;
  final String? location;
  final String? recurringId;
  final String? audience;
  final bool isPrivate;
  final List<String> allowedStudentIds;
  final String? unitId;
  final String? unitName;

  TrainingClass({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.teacherId,
    required this.teacherName,
    required this.modality,
    this.description = '',
    this.level = 'Todos os Níveis',
    this.location,
    this.recurringId,
    this.audience = 'Adulto',
    this.isPrivate = false,
    this.allowedStudentIds = const [],
    this.unitId,
    this.unitName,
  });

  factory TrainingClass.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TrainingClass(
      id: doc.id,
      dayOfWeek: data['dayOfWeek'] ?? '',
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      teacherId: data['teacherId'] ?? '',
      teacherName: data['teacherName'] ?? '',
      modality: modalityFromString(data['modality']),
      description: data['description'] ?? '',
      level: data['level'] ?? 'Todos os Níveis',
      location: data['location'],
      recurringId: data['recurringId'],
      audience: data['audience'] ?? 'Adulto',
      isPrivate: data['isPrivate'] ?? false,
      allowedStudentIds: List<String>.from(data['allowedStudentIds'] ?? []),
      unitId: data['unitId'],
      unitName: data['unitName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'modality': modalityToString(modality),
      'description': description,
      'level': level,
      'location': location,
      'recurringId': recurringId,
      'audience': audience,
      'isPrivate': isPrivate,
      'allowedStudentIds': allowedStudentIds,
      'unitId': unitId,
      'unitName': unitName,
    };
  }
}

class AuditLogEntry {
  final String id;
  final String actorUid;
  final String actorName;
  final String actionType;
  final String description;
  final Timestamp timestamp;
  final String? targetUid;
  final String? targetName;

  AuditLogEntry({
    required this.id,
    required this.actorUid,
    required this.actorName,
    required this.actionType,
    required this.description,
    required this.timestamp,
    this.targetUid,
    this.targetName,
  });

  factory AuditLogEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AuditLogEntry(
      id: doc.id,
      actorUid: data['actorUid'] ?? '',
      actorName: data['actorName'] ?? '',
      actionType: data['actionType'] ?? 'UNKNOWN',
      description: data['description'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      targetUid: data['targetUid'],
      targetName: data['targetName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'actorUid': actorUid,
      'actorName': actorName,
      'actionType': actionType,
      'description': description,
      'timestamp': timestamp,
      'targetUid': targetUid,
      'targetName': targetName,
    };
  }
}

enum VideoType { youtube, uploaded }

class VideoPlaylist {
  final String id;
  final String name;
  final Timestamp createdAt;

  VideoPlaylist({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  factory VideoPlaylist.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VideoPlaylist(
      id: doc.id,
      name: data['name'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'createdAt': createdAt,
    };
  }
}

class VideoItem {
  final String id;
  final String title;
  final String description;
  final String videoUrl;
  final VideoType videoType;
  final String thumbnailUrl;
  final String uploadedByUid;
  final String uploadedByName;
  final Timestamp createdAt;
  final List<String> tags;
  final String? playlistId;
  final Map<String, dynamic> watchedBy;
  final int? fileSizeBytes;

  VideoItem({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.videoType,
    required this.thumbnailUrl,
    required this.uploadedByUid,
    required this.uploadedByName,
    required this.createdAt,
    required this.tags,
    this.playlistId,
    this.watchedBy = const {},
    this.fileSizeBytes,
  });

  factory VideoItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    Map<String, dynamic> parsedWatchedBy = {};
    final watchedByData = data['watchedBy'];

    if (watchedByData is Map) {
      parsedWatchedBy = Map<String, dynamic>.from(watchedByData);
    } else if (watchedByData is List) {
      for (var userId in watchedByData) {
        if (userId is String) {
          parsedWatchedBy[userId] = {
            'count': 1,
            'lastWatched': null,
          };
        }
      }
    }

    return VideoItem(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      videoType: (data['videoType'] == 'uploaded')
          ? VideoType.uploaded
          : VideoType.youtube,
      thumbnailUrl: data['thumbnailUrl'] ?? '',
      uploadedByUid: data['uploadedByUid'] ?? '',
      uploadedByName: data['uploadedByName'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      tags: List<String>.from(data['tags'] ?? []),
      playlistId: data['playlistId'],
      watchedBy: parsedWatchedBy,
      fileSizeBytes: data['fileSizeBytes'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'videoUrl': videoUrl,
      'videoType': videoType == VideoType.uploaded ? 'uploaded' : 'youtube',
      'thumbnailUrl': thumbnailUrl,
      'uploadedByUid': uploadedByUid,
      'uploadedByName': uploadedByName,
      'createdAt': createdAt,
      'tags': tags,
      'playlistId': playlistId,
      'watchedBy': watchedBy,
      'fileSizeBytes': fileSizeBytes,
    };
  }
}

class SparringSession {
  final String id;
  final Timestamp startedAt;
  final String generationType;
  final List<String> participantIds;
  final List<Map<String, dynamic>> allRounds;
  final String createdByUid;
  final String createdByName;

  SparringSession({
    required this.id,
    required this.startedAt,
    required this.generationType,
    required this.participantIds,
    required this.allRounds,
    required this.createdByUid,
    required this.createdByName,
  });

  factory SparringSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SparringSession(
      id: doc.id,
      startedAt: data['startedAt'] ?? Timestamp.now(),
      generationType: data['generationType'] ?? 'Aleatório',
      participantIds: List<String>.from(data['participants'] ?? []),
      allRounds: List<Map<String, dynamic>>.from(data['allRounds'] ?? []),
      createdByUid: data['createdByUid'] ?? '',
      createdByName: data['createdByName'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startedAt': startedAt,
      'generationType': generationType,
      'participants': participantIds,
      'allRounds': allRounds,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
    };
  }
}

class MonthlyFee {
  final String id;
  final String studentId;
  final String studentName;
  final double amount;
  final DateTime? paymentDate;
  final String? paymentMethod;
  final int paymentYear;
  final int paymentMonth;
  final PaymentStatus status;

  MonthlyFee({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.amount,
    this.paymentDate,
    this.paymentMethod,
    required this.paymentYear,
    required this.paymentMonth,
    required this.status,
  });

  factory MonthlyFee.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    PaymentStatus status;
    switch (data['status']) {
      case 'pago':
        status = PaymentStatus.pago;
        break;
      case 'atrasado':
        status = PaymentStatus.atrasado;
        break;
      default:
        status = PaymentStatus.pendente;
    }

    return MonthlyFee(
      id: doc.id,
      studentId: data['studentId'],
      studentName: data['studentName'],
      amount: (data['amount'] as num).toDouble(),
      paymentDate: (data['paymentDate'] as Timestamp?)?.toDate(),
      paymentMethod: data['paymentMethod'],
      paymentYear: data['paymentYear'],
      paymentMonth: data['paymentMonth'],
      status: status,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'amount': amount,
      'paymentDate':
          paymentDate != null ? Timestamp.fromDate(paymentDate!) : null,
      'paymentMethod': paymentMethod,
      'paymentYear': paymentYear,
      'paymentMonth': paymentMonth,
      'status': status.name,
    };
  }
}

class TutorialPlaylist {
  final String id;
  final String name;
  final int orderIndex;

  TutorialPlaylist({
    required this.id,
    required this.name,
    required this.orderIndex,
  });

  factory TutorialPlaylist.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TutorialPlaylist(
      id: doc.id,
      name: data['name'] ?? 'Playlist sem nome',
      orderIndex: data['orderIndex'] ?? 99,
    );
  }
}

class Tutorial {
  final String id;
  final String title;
  final String description;
  final String videoUrl;
  final List<String> visibleTo;
  final int orderIndex;
  final String? playlistId;

  Tutorial({
    required this.id,
    required this.title,
    required this.description,
    required this.videoUrl,
    required this.visibleTo,
    required this.orderIndex,
    this.playlistId,
  });

  factory Tutorial.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Tutorial(
      id: doc.id,
      title: data['title'] ?? 'Sem Título',
      description: data['description'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      visibleTo: List<String>.from(data['visibleTo'] ?? []),
      orderIndex: data['orderIndex'] ?? 99,
      playlistId: data['playlistId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'videoUrl': videoUrl,
      'visibleTo': visibleTo,
      'orderIndex': orderIndex,
      'playlistId': playlistId,
    };
  }
}

// =========================================================================
// ==           INÍCIO DOS NOVOS MODELOS PARA O DIÁRIO DE TREINOS         ==
// =========================================================================

/// Representa uma única rodada de sparring dentro de um diário de treino.
class SparringRound {
  String partnerName;
  int submissionsFor;
  int submissionsAgainst;
  int sweepsFor;
  int passesFor;

  SparringRound({
    this.partnerName = '',
    this.submissionsFor = 0,
    this.submissionsAgainst = 0,
    this.sweepsFor = 0,
    this.passesFor = 0,
  });

  // Converte o objeto para um Map, para ser salvo no Firestore.
  Map<String, dynamic> toMap() {
    return {
      'partnerName': partnerName,
      'submissionsFor': submissionsFor,
      'submissionsAgainst': submissionsAgainst,
      'sweepsFor': sweepsFor,
      'passesFor': passesFor,
    };
  }

  // Cria um objeto a partir de um Map vindo do Firestore.
  factory SparringRound.fromMap(Map<String, dynamic> map) {
    return SparringRound(
      partnerName: map['partnerName'] ?? '',
      submissionsFor: map['submissionsFor'] ?? 0,
      submissionsAgainst: map['submissionsAgainst'] ?? 0,
      sweepsFor: map['sweepsFor'] ?? 0,
      passesFor: map['passesFor'] ?? 0,
    );
  }
}

/// Representa uma entrada completa no diário de treinos do aluno.
class TrainingLog {
  final String id;
  final String userId;
  final DateTime date;
  final String? classTopic;
  final List<String> techniques;
  final String generalNotes;
  final int performanceRating; // De 1 a 5
  final List<SparringRound> sparringRounds;
  final Timestamp createdAt;
  Timestamp updatedAt;

  TrainingLog({
    required this.id,
    required this.userId,
    required this.date,
    this.classTopic,
    this.techniques = const [],
    this.generalNotes = '',
    this.performanceRating = 3,
    this.sparringRounds = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  // Converte o objeto para um Map para o Firestore.
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'classTopic': classTopic,
      'techniques': techniques,
      'generalNotes': generalNotes,
      'performanceRating': performanceRating,
      'sparringRounds': sparringRounds.map((round) => round.toMap()).toList(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  // Cria um objeto a partir de um DocumentSnapshot do Firestore.
  factory TrainingLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TrainingLog(
      id: doc.id,
      userId: data['userId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      classTopic: data['classTopic'],
      techniques: List<String>.from(data['techniques'] ?? []),
      generalNotes: data['generalNotes'] ?? '',
      performanceRating: data['performanceRating'] ?? 3,
      sparringRounds: (data['sparringRounds'] as List<dynamic>? ?? [])
          .map((roundData) => SparringRound.fromMap(roundData))
          .toList(),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
    );
  }
}

enum GoalStatus { pending, completed }

// Helper para converter o enum de status da meta para String e vice-versa
String goalStatusToString(GoalStatus status) {
  return status.name;
}

GoalStatus goalStatusFromString(String? statusString) {
  if (statusString == 'completed') {
    return GoalStatus.completed;
  }
  return GoalStatus.pending;
}

/// Modelo para as metas de treino do aluno.
class TrainingGoal {
  final String id;
  final String userId;
  final String description;
  final DateTime? deadline;
  final GoalStatus status;
  final Timestamp createdAt;

  TrainingGoal({
    required this.id,
    required this.userId,
    required this.description,
    this.deadline,
    this.status = GoalStatus.pending,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'description': description,
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'status': goalStatusToString(status),
      'createdAt': createdAt,
    };
  }

  factory TrainingGoal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TrainingGoal(
      id: doc.id,
      userId: data['userId'] ?? '',
      description: data['description'] ?? '',
      deadline: (data['deadline'] as Timestamp?)?.toDate(),
      status: goalStatusFromString(data['status']),
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }
}
