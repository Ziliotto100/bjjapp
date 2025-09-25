// lib/models.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// --- INÍCIO DA ALTERAÇÃO ---
// Novo modelo para os Currículos
class Curriculum {
  final String id;
  String name;
  String description;

  Curriculum({
    required this.id,
    required this.name,
    this.description = '',
  });

  factory Curriculum.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Curriculum(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
    };
  }
}
// --- FIM DA ALTERAÇÃO ---

// Enum para os diferentes tipos de papéis de usuário no sistema.
enum UserRole {
  superAdmin,
  manager,
  teacher,
  student,
  unknown,
}

// Enum para o status de pagamento da mensalidade.
enum PaymentStatus {
  pago,
  pendente,
  atrasado,
}

// Enum para o status do check-in
enum CheckinStatus {
  pending,
  approved,
}

String checkinStatusToString(CheckinStatus status) {
  return status.name;
}

CheckinStatus checkinStatusFromString(String? statusString) {
  return statusString == 'approved'
      ? CheckinStatus.approved
      : CheckinStatus.pending;
}

/// Modelo para representar um Usuário do sistema (login via FirebaseAuth).
class UserModel {
  final String uid;
  final String name;
  final String email;
  final String academyId;
  final UserRole role;
  final String? studentRecordId;
  final bool mustChangePassword;
  final bool isActive;
  final String? faixa;
  final int? graus;
  final double? peso;
  final String? profileImagePath;
  final DateTime? dataNascimento;
  final String? phoneNumber;
  final Map<String, String>? address;
  final Map<String, int> monthlyTrainingGoals;
  final String? unitId;
  final String? unitName;
  final String? lastSelectedUnitId;
  final bool canUploadStudyVideos;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final String? createdByUid;
  final String? createdByName;
  final String? lastUpdatedByUid;
  final String? lastUpdatedByName;
  final bool hasSeenWelcomePopup;
  final List<String>? fcmTokens;

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
    final Map<String, int> goals =
        goalsData.map((key, value) => MapEntry(key, (value as num).toInt()));

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
  String? phoneNumber;
  Map<String, String>? address;
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
  final Timestamp createdAt;

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
    required this.createdAt,
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
      createdAt: json['createdAt'] ?? Timestamp.now(),
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
      'createdAt': createdAt,
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
    return trim().split(RegExp(r'\\s+')).map((word) {
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
  final String? curriculumId;
  final String? curriculumName;

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
    this.audience,
    this.isPrivate = false,
    this.allowedStudentIds = const [],
    this.unitId,
    this.unitName,
    this.curriculumId,
    this.curriculumName,
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
      audience: data['audience'],
      isPrivate: data['isPrivate'] ?? false,
      allowedStudentIds: List<String>.from(data['allowedStudentIds'] ?? []),
      unitId: data['unitId'],
      unitName: data['unitName'],
      curriculumId: data['curriculumId'],
      curriculumName: data['curriculumName'],
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
      'curriculumId': curriculumId,
      'curriculumName': curriculumName,
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
      name: data['name'] ?? 'Playlist sem nome',
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
// ==           MODELOS PARA O DIÁRIO DE TREINOS (ATUALIZADOS)            ==
// =========================================================================

enum SparringEventType {
  finalizacao,
  joelhoNaBarriga,
  montada,
  passagem,
  queda,
  raspagem,
  reversao,
}

String sparringEventTypeToString(SparringEventType type) {
  return type.name;
}

SparringEventType sparringEventTypeFromString(String? s) {
  return SparringEventType.values.firstWhere((e) => e.name == s,
      orElse: () => SparringEventType.finalizacao);
}

String getSparringEventTypeName(SparringEventType type) {
  switch (type) {
    case SparringEventType.finalizacao:
      return 'Finalização';
    case SparringEventType.joelhoNaBarriga:
      return 'Joelho na Barriga';
    case SparringEventType.montada:
      return 'Montada';
    case SparringEventType.passagem:
      return 'Passagem';
    case SparringEventType.queda:
      return 'Queda';
    case SparringEventType.raspagem:
      return 'Raspagem';
    case SparringEventType.reversao:
      return 'Reversão';
  }
}

class SparringEvent {
  SparringEventType type;
  String technique;
  bool wasSuccessful;

  SparringEvent({
    required this.type,
    required this.technique,
    required this.wasSuccessful,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': sparringEventTypeToString(type),
      'technique': technique,
      'wasSuccessful': wasSuccessful,
    };
  }

  factory SparringEvent.fromMap(Map<String, dynamic> map) {
    return SparringEvent(
      type: sparringEventTypeFromString(map['type']),
      technique: map['technique'] ?? '',
      wasSuccessful: map['wasSuccessful'] ?? false,
    );
  }
}

enum PhysicalCondition {
  disposto,
  normal,
  cansado,
}

String physicalConditionToString(PhysicalCondition condition) {
  return condition.name;
}

PhysicalCondition physicalConditionFromString(String? s) {
  return PhysicalCondition.values
      .firstWhere((e) => e.name == s, orElse: () => PhysicalCondition.normal);
}

class SparringRound {
  String partnerName;
  String notes;
  int rating;
  List<SparringEvent> events;
  int? durationInMinutes;
  PhysicalCondition? physicalCondition;

  SparringRound({
    this.partnerName = '',
    this.notes = '',
    this.rating = 3,
    List<SparringEvent>? events,
    this.durationInMinutes,
    this.physicalCondition,
  }) : events = events ?? [];

  Map<String, dynamic> toMap() {
    return {
      'partnerName': partnerName,
      'notes': notes,
      'rating': rating,
      'events': events.map((e) => e.toMap()).toList(),
      'durationInMinutes': durationInMinutes,
      'physicalCondition': physicalCondition != null
          ? physicalConditionToString(physicalCondition!)
          : null,
    };
  }

  factory SparringRound.fromMap(Map<String, dynamic> map) {
    return SparringRound(
      partnerName: map['partnerName'] ?? '',
      notes: map['notes'] ?? '',
      rating: map['rating'] ?? 3,
      events: (map['events'] as List<dynamic>? ?? [])
          .map((eventData) => SparringEvent.fromMap(eventData))
          .toList(),
      durationInMinutes: map['durationInMinutes'],
      physicalCondition: physicalConditionFromString(map['physicalCondition']),
    );
  }
}

class TrainingLog {
  final String id;
  final String userId;
  final DateTime date;
  final String? classTopic;
  final List<String> techniques;
  final String generalNotes;
  final int performanceRating;
  final List<SparringRound> sparringRounds;
  final Timestamp createdAt;
  Timestamp updatedAt;
  final String? injuriesOrPains;
  final int? durationInMinutes;

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
    this.injuriesOrPains,
    this.durationInMinutes,
  });

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
      'injuriesOrPains': injuriesOrPains,
      'durationInMinutes': durationInMinutes,
    };
  }

  factory TrainingLog.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TrainingLog(
      id: doc.id,
      userId: data['userId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      classTopic: data['classTopic'],
      techniques:
          List<String>.from(data['techniques'] ?? data['trainingGoals'] ?? []),
      generalNotes: data['generalNotes'] ?? '',
      performanceRating: data['performanceRating'] ?? 3,
      sparringRounds: (data['sparringRounds'] as List<dynamic>? ?? [])
          .map((roundData) => SparringRound.fromMap(roundData))
          .toList(),
      createdAt: data['createdAt'] ?? Timestamp.now(),
      updatedAt: data['updatedAt'] ?? Timestamp.now(),
      injuriesOrPains: data['injuriesOrPains'],
      durationInMinutes: data['durationInMinutes'],
    );
  }
}

enum GoalStatus { pending, completed }

String goalStatusToString(GoalStatus status) {
  return status.name;
}

GoalStatus goalStatusFromString(String? statusString) {
  return statusString == 'completed'
      ? GoalStatus.completed
      : GoalStatus.pending;
}

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
// Adicione estas classes ao final do arquivo lib/models.dart

class TaughtTechnique {
  String name;
  String description;
  String? videoId;
  String? videoTitle;
  String? videoThumbnailUrl;

  TaughtTechnique({
    required this.name,
    this.description = '',
    this.videoId,
    this.videoTitle,
    this.videoThumbnailUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'videoId': videoId,
      'videoTitle': videoTitle,
      'videoThumbnailUrl': videoThumbnailUrl,
    };
  }

  factory TaughtTechnique.fromMap(Map<String, dynamic> map) {
    return TaughtTechnique(
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      videoId: map['videoId'],
      videoTitle: map['videoTitle'],
      videoThumbnailUrl: map['videoThumbnailUrl'],
    );
  }
}

class LessonPlan {
  final String id;
  final String academyId;
  final String classId;
  final DateTime classDate;
  // --- INÍCIO DA CORREÇÃO ---
  final String? curriculumId; // Campo que estava faltando
  // --- FIM DA CORREÇÃO ---
  String warmup;
  List<TaughtTechnique> techniques;
  String observations;
  final String createdByUid;
  final String createdByName;
  final Timestamp createdAt;
  String lastUpdatedByUid;
  String lastUpdatedByName;
  Timestamp lastUpdatedAt;

  LessonPlan({
    required this.id,
    required this.academyId,
    required this.classId,
    required this.classDate,
    this.curriculumId, // Adicionado ao construtor
    this.warmup = '',
    this.techniques = const [],
    this.observations = '',
    required this.createdByUid,
    required this.createdByName,
    required this.createdAt,
    required this.lastUpdatedByUid,
    required this.lastUpdatedByName,
    required this.lastUpdatedAt,
  });

  factory LessonPlan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return LessonPlan(
      id: doc.id,
      academyId: data['academyId'] ?? '',
      classId: data['classId'] ?? '',
      classDate: (data['classDate'] as Timestamp).toDate(),
      curriculumId: data['curriculumId'], // Lendo o campo do Firestore
      warmup: data['warmup'] ?? '',
      techniques: (data['techniques'] as List<dynamic>? ?? [])
          .map((techData) => TaughtTechnique.fromMap(techData))
          .toList(),
      observations: data['observations'] ?? '',
      createdByUid: data['createdByUid'] ?? '',
      createdByName: data['createdByName'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      lastUpdatedByUid: data['lastUpdatedByUid'] ?? '',
      lastUpdatedByName: data['lastUpdatedByName'] ?? '',
      lastUpdatedAt: data['lastUpdatedAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'academyId': academyId,
      'classId': classId,
      'classDate': Timestamp.fromDate(classDate),
      'curriculumId': curriculumId, // Escrevendo o campo no Firestore
      'warmup': warmup,
      'techniques': techniques.map((t) => t.toMap()).toList(),
      'observations': observations,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'createdAt': createdAt,
      'lastUpdatedByUid': lastUpdatedByUid,
      'lastUpdatedByName': lastUpdatedByName,
      'lastUpdatedAt': lastUpdatedAt,
    };
  }
}

class WeeklyPlan {
  final String id;
  final String academyId;
  final DateTime weekStartDate;
  final List<TaughtTechnique> techniques;
  final String observations;
  final String lastUpdatedByUid;
  final String lastUpdatedByName;
  final Timestamp lastUpdatedAt;

  WeeklyPlan({
    required this.id,
    required this.academyId,
    required this.weekStartDate,
    required this.techniques,
    required this.observations,
    required this.lastUpdatedByUid,
    required this.lastUpdatedByName,
    required this.lastUpdatedAt,
  });

  factory WeeklyPlan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return WeeklyPlan(
      id: doc.id,
      academyId: data['academyId'] ?? '',
      weekStartDate: (data['weekStartDate'] as Timestamp).toDate(),
      techniques: (data['techniques'] as List<dynamic>? ?? [])
          .map((techData) => TaughtTechnique.fromMap(techData))
          .toList(),
      observations: data['observations'] ?? '',
      lastUpdatedByUid: data['lastUpdatedByUid'] ?? '',
      lastUpdatedByName: data['lastUpdatedByName'] ?? '',
      lastUpdatedAt: data['lastUpdatedAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'academyId': academyId,
      'weekStartDate': Timestamp.fromDate(weekStartDate),
      'techniques': techniques.map((t) => t.toMap()).toList(),
      'observations': observations,
      'lastUpdatedByUid': lastUpdatedByUid,
      'lastUpdatedByName': lastUpdatedByName,
      'lastUpdatedAt': lastUpdatedAt,
    };
  }
}
