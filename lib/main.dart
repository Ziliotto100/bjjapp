import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'dart:async';

// ---- IMPORTS PARA IMAGEM OFFLINE ----
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:image_picker/image_picker.dart';
// ---- FIM DOS NOVOS IMPORTS ----

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Classe Aluno (sem alterações)
class Aluno {
  final String id;
  String nome;
  String faixa;
  double peso;
  int? graus;

  Aluno({
    required this.id,
    required this.nome,
    required this.faixa,
    required this.peso,
    this.graus,
  });

  Aluno.novo({
    required this.nome,
    required this.faixa,
    required this.peso,
    this.graus,
  }) : id = '';

  Map<String, dynamic> toJson() => {
        'nome': nome,
        'faixa': faixa,
        'peso': peso,
        'graus': graus,
      };

  static Aluno fromJson(String id, Map<String, dynamic> json) => Aluno(
        id: id,
        nome: json['nome'],
        faixa: json['faixa'],
        peso: json['peso']?.toDouble() ?? 0.0,
        graus: json['graus'] as int?,
      );

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

// AppBackground (sem alterações)
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({Key? key, required this.child}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage("assets/images/planofundo.png"),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.65),
            BlendMode.darken,
          ),
        ),
      ),
      child: child,
    );
  }
}

// Classe Luta (sem alterações)
class Luta {
  final Aluno aluno1;
  final Aluno aluno2;
  final double custo;
  Luta(this.aluno1, this.aluno2, this.custo);
  @override
  String toString() {
    return '${aluno1.nome} x ${aluno2.nome} (Custo: $custo)';
  }

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

// Extensão de String (sem alterações)
extension StringExtension on String {
  String capitalizeFirst() {
    if (this.isEmpty) return this;
    if (this.contains(" com ")) {
      return this.split(" ").map((word) => word.capitalizeFirst()).join(" ");
    }
    return "${this[0].toUpperCase()}${this.substring(1).toLowerCase()}";
  }
}

// Classe BjjApp (sem alterações de tema)
class BjjApp extends StatelessWidget {
  static const Color darkScaffoldBackground = Color(0xFF0A0F14);
  static const Color darkSurface = Color(0xFF10181F);
  static const Color primaryAccent = Color(0xFFD4AF37);
  static const Color primaryAccentForeground = Colors.black;
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFE0E0E0);
  static const Color textHint = Color(0xFFB0B0B0);
  static const Color borderNormal = Color(0xFF37474F);
  static const Color borderFocused = primaryAccent;
  static const Color successColor = Color(0xFF2ECC71);
  static const Color warningColor = Color(0xFFFFA726);
  static const Color errorColor = Color(0xFFE74C3C);
  static const Color infoColor = Color(0xFF54A0FF);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Match BJJ',
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('pt', 'BR'),
      ],
      theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: darkSurface,
          scaffoldBackgroundColor: Colors.transparent,
          dialogBackgroundColor: darkSurface,
          cardColor: darkSurface.withOpacity(0.85),
          canvasColor: darkScaffoldBackground,
          colorScheme: ColorScheme.dark(
            primary: primaryAccent,
            secondary: primaryAccent,
            surface: darkSurface,
            background: darkScaffoldBackground,
            error: errorColor,
            onPrimary: primaryAccentForeground,
            onSecondary: primaryAccentForeground,
            onSurface: textPrimary,
            onBackground: textPrimary,
            onError: Colors.white,
          ),
          hintColor: textHint,
          textTheme: TextTheme(
            bodyMedium: TextStyle(color: textSecondary, fontSize: 14),
            bodyLarge: TextStyle(color: textSecondary, fontSize: 16),
            bodySmall: TextStyle(color: textSecondary, fontSize: 12),
            headlineSmall: TextStyle(
                color: textPrimary, fontWeight: FontWeight.bold, fontSize: 24),
            titleLarge: TextStyle(
                color: textPrimary, fontWeight: FontWeight.bold, fontSize: 22),
            titleMedium: TextStyle(
                color: textPrimary, fontWeight: FontWeight.w500, fontSize: 18),
            titleSmall: TextStyle(color: textPrimary, fontSize: 16),
            labelLarge: TextStyle(
                color: primaryAccentForeground,
                fontWeight: FontWeight.bold,
                fontSize: 16),
          ).apply(fontFamily: 'Roboto'),
          appBarTheme: AppBarTheme(
            backgroundColor: darkSurface,
            elevation: 2.0,
            titleTextStyle: TextStyle(
                color: textPrimary,
                fontSize: 20.0,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto'),
            iconTheme: IconThemeData(color: textPrimary),
          ),
          bottomNavigationBarTheme: BottomNavigationBarThemeData(
            backgroundColor: darkSurface,
            selectedItemColor: primaryAccent,
            unselectedItemColor: textHint,
            elevation: 4.0,
            type: BottomNavigationBarType.fixed,
            selectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryAccent,
              foregroundColor: primaryAccentForeground,
              padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
              textStyle: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0)),
              elevation: 2,
            ),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: primaryAccent,
            foregroundColor: primaryAccentForeground,
            elevation: 4.0,
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: darkSurface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0)),
            titleTextStyle: TextStyle(
                color: textPrimary,
                fontSize: 19.0,
                fontWeight: FontWeight.bold,
                fontFamily: 'Roboto'),
            contentTextStyle: TextStyle(
                color: textSecondary, fontSize: 15, fontFamily: 'Roboto'),
          ),
          inputDecorationTheme: InputDecorationTheme(
            labelStyle: TextStyle(color: textHint),
            hintStyle: TextStyle(color: textHint.withOpacity(0.7)),
            filled: true,
            fillColor: darkScaffoldBackground.withOpacity(0.5),
            contentPadding:
                EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: borderNormal)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: borderNormal)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: borderFocused, width: 2.0)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: errorColor, width: 1.5)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8.0),
                borderSide: BorderSide(color: errorColor, width: 2.0)),
            errorStyle:
                TextStyle(color: errorColor, fontWeight: FontWeight.w500),
          ),
          dropdownMenuTheme: DropdownMenuThemeData(
            inputDecorationTheme: InputDecorationTheme(
              labelStyle: TextStyle(color: textHint),
              hintStyle: TextStyle(color: textHint.withOpacity(0.7)),
              filled: true,
              fillColor: darkScaffoldBackground.withOpacity(0.5),
              contentPadding:
                  EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: borderNormal)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: borderNormal)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: borderFocused, width: 2.0)),
            ),
            menuStyle: MenuStyle(
              backgroundColor: MaterialStatePropertyAll(darkSurface),
              shape: MaterialStatePropertyAll(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0))),
              elevation: MaterialStatePropertyAll(3.0),
            ),
            textStyle: TextStyle(color: textSecondary, fontFamily: 'Roboto'),
          ),
          popupMenuTheme: PopupMenuThemeData(
            color: darkSurface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0)),
            textStyle: TextStyle(color: textSecondary, fontFamily: 'Roboto'),
            elevation: 4.0,
          ),
          checkboxTheme: CheckboxThemeData(
            fillColor: MaterialStateProperty.resolveWith((states) =>
                states.contains(MaterialState.selected)
                    ? primaryAccent
                    : textHint.withOpacity(0.2)),
            checkColor: MaterialStateProperty.all(primaryAccentForeground),
            side: BorderSide(color: textHint.withOpacity(0.5)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4.0)),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
                foregroundColor: primaryAccent,
                textStyle: TextStyle(
                    fontWeight: FontWeight.bold, fontFamily: 'Roboto')),
          ),
          cardTheme: CardThemeData(
            color: darkSurface.withOpacity(0.85),
            elevation: 2.0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0)),
            margin: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
              TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            },
          ),
          segmentedButtonTheme: SegmentedButtonThemeData(
            style: SegmentedButton.styleFrom(
              backgroundColor: darkSurface,
              foregroundColor: textSecondary,
              selectedForegroundColor: primaryAccentForeground,
              selectedBackgroundColor: primaryAccent,
            ),
          )),
      home: AuthGate(),
    );
  }
}

// showBjjSnackBar (sem alterações)
void showBjjSnackBar(BuildContext context, String message,
    {String type = 'info'}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  Color backgroundColor;
  IconData icon;
  switch (type) {
    case 'success':
      backgroundColor = BjjApp.successColor;
      icon = Icons.check_circle_outline_rounded;
      break;
    case 'warning':
      backgroundColor = BjjApp.warningColor;
      icon = Icons.warning_amber_rounded;
      break;
    case 'error':
      backgroundColor = BjjApp.errorColor;
      icon = Icons.error_outline_rounded;
      break;
    default:
      backgroundColor = BjjApp.infoColor;
      icon = Icons.info_outline_rounded;
  }
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Row(children: [
      Icon(icon, color: Colors.white, size: 20),
      SizedBox(width: 10),
      Expanded(
          child: Text(message,
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
    ]),
    backgroundColor: backgroundColor,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
    behavior: SnackBarBehavior.floating,
    margin: EdgeInsets.fromLTRB(16, 10, 16, 10),
    elevation: 4.0,
    duration: Duration(seconds: 4),
  ));
}

// CheckinEntry e CheckinService (sem alterações)
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

class CheckinService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String? _userId;

  CheckinService() : _userId = FirebaseAuth.instance.currentUser?.uid;

  Future<void> saveCheckin(Aluno aluno, DateTime date) async {
    if (_userId == null) return;
    final dateOnly = DateTime(date.year, date.month, date.day);
    final querySnapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('checkins')
        .where('studentId', isEqualTo: aluno.id)
        .get();

    final alreadyCheckedIn = querySnapshot.docs.any((doc) {
      final checkin = CheckinEntry.fromJson(doc.id, doc.data());
      final entryDateOnly =
          DateTime(checkin.date.year, checkin.date.month, checkin.date.day);
      return entryDateOnly == dateOnly;
    });

    if (!alreadyCheckedIn) {
      await _firestore
          .collection('users')
          .doc(_userId)
          .collection('checkins')
          .add({
        'studentId': aluno.id,
        'date': Timestamp.fromDate(date),
      });
    } else {
      print(
          'Check-in para ${aluno.nome} no dia ${DateFormat('dd/MM/yyyy').format(date)} já existe.');
    }
  }

  Stream<List<CheckinEntry>> getCheckinsForStudentStream(Aluno aluno) {
    if (_userId == null) return Stream.value([]);
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('checkins')
        .where('studentId', isEqualTo: aluno.id)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CheckinEntry.fromJson(doc.id, doc.data()))
            .toList());
  }

  Future<void> removeCheckin(Aluno aluno, DateTime date) async {
    if (_userId == null) return;
    final dateOnly = DateTime(date.year, date.month, date.day);
    final querySnapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('checkins')
        .where('studentId', isEqualTo: aluno.id)
        .get();
    for (var doc in querySnapshot.docs) {
      final checkin = CheckinEntry.fromJson(doc.id, doc.data());
      final entryDateOnly =
          DateTime(checkin.date.year, checkin.date.month, checkin.date.day);
      if (entryDateOnly == dateOnly) {
        await doc.reference.delete();
        break;
      }
    }
  }

  static String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }
}

// --- INÍCIO DA SEÇÃO DE ESTUDOS (sem alterações) ---

// --- MODELOS DE DADOS PARA ESTUDOS ---

class StudyInstructional {
  final String id;
  String title;
  String instructor;
  Timestamp createdAt;

  StudyInstructional({
    required this.id,
    required this.title,
    required this.instructor,
    required this.createdAt,
  });

  factory StudyInstructional.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return StudyInstructional(
      id: doc.id,
      title: data['title'] ?? '',
      instructor: data['instructor'] ?? '',
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'instructor': instructor,
      'createdAt': createdAt,
    };
  }
}

class StudyNote {
  String id;
  String text;
  String? timestamp;
  Timestamp createdAt;
  String? localImagePath;

  StudyNote({
    required this.id,
    required this.text,
    this.timestamp,
    required this.createdAt,
    this.localImagePath,
  });

  factory StudyNote.fromMap(Map<String, dynamic> map) {
    return StudyNote(
      id: map['id'],
      text: map['text'],
      timestamp: map['timestamp'],
      createdAt: map['createdAt'] ?? Timestamp.now(),
      localImagePath: map['localImagePath'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'timestamp': timestamp,
      'createdAt': createdAt,
      'localImagePath': localImagePath,
    };
  }
}

class StudyChapter {
  final String id;
  String title;
  bool isCompleted;
  int order;
  List<StudyNote> notes;

  StudyChapter({
    required this.id,
    required this.title,
    this.isCompleted = false,
    required this.order,
    this.notes = const [],
  });

  factory StudyChapter.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    var notesData = data['notes'] as List<dynamic>? ?? [];
    return StudyChapter(
      id: doc.id,
      title: data['title'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      order: data['order'] ?? 0,
      notes: notesData.map((noteMap) => StudyNote.fromMap(noteMap)).toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'isCompleted': isCompleted,
      'order': order,
      'notes': notes.map((note) => note.toMap()).toList(),
    };
  }
}

// --- TELA DE DETALHES DO INSTRUCIONAL ---

class InstructionalDetailPage extends StatefulWidget {
  final String userId;
  final StudyInstructional instructional;

  const InstructionalDetailPage({
    Key? key,
    required this.userId,
    required this.instructional,
  }) : super(key: key);

  @override
  _InstructionalDetailPageState createState() =>
      _InstructionalDetailPageState();
}

class _InstructionalDetailPageState extends State<InstructionalDetailPage> {
  late final CollectionReference _chaptersCollection;

  @override
  void initState() {
    super.initState();
    _chaptersCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('instructionals')
        .doc(widget.instructional.id)
        .collection('chapters');
  }

  Future<void> _addChapter(String title, int order) async {
    await _chaptersCollection.add({
      'title': title,
      'isCompleted': false,
      'order': order,
      'notes': [],
    });
  }

  Future<void> _updateChapter(StudyChapter chapter) async {
    await _chaptersCollection.doc(chapter.id).update(chapter.toMap());
  }

  Future<void> _deleteChapter(String chapterId) async {
    final chapterDoc = await _chaptersCollection.doc(chapterId).get();
    if (chapterDoc.exists) {
      final chapter = StudyChapter.fromFirestore(chapterDoc);
      for (final note in chapter.notes) {
        if (note.localImagePath != null) {
          try {
            final file = File(note.localImagePath!);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            print("Erro ao deletar arquivo de imagem local: $e");
          }
        }
      }
    }
    await _chaptersCollection.doc(chapterId).delete();
  }

  Future<void> _reorderChapter(
      List<StudyChapter> chapters, int oldIndex, bool moveUp) async {
    int newIndex = moveUp ? oldIndex - 1 : oldIndex + 1;

    if (oldIndex < 0 ||
        oldIndex >= chapters.length ||
        newIndex < 0 ||
        newIndex >= chapters.length) {
      return;
    }

    StudyChapter chapterToMove = chapters[oldIndex];
    StudyChapter otherChapter = chapters[newIndex];

    int tempOrder = chapterToMove.order;
    chapterToMove.order = otherChapter.order;
    otherChapter.order = tempOrder;

    final batch = FirebaseFirestore.instance.batch();
    batch.update(_chaptersCollection.doc(chapterToMove.id),
        {'order': chapterToMove.order});
    batch.update(_chaptersCollection.doc(otherChapter.id),
        {'order': otherChapter.order});

    await batch.commit();
  }

  void _showAddChapterDialog({int currentCount = 0}) {
    final _titleController =
        TextEditingController(text: "Volume ${currentCount + 1}");
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Adicionar Capítulo/Volume'),
        content: TextFormField(
          controller: _titleController,
          decoration: InputDecoration(labelText: 'Nome (ex: Volume 1)'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (_titleController.text.trim().isNotEmpty) {
                _addChapter(_titleController.text.trim(), currentCount);
                Navigator.of(context).pop();
              }
            },
            child: Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  void _showEditChapterDialog(StudyChapter chapter) {
    final _titleController = TextEditingController(text: chapter.title);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Editar Capítulo/Volume'),
        content: TextFormField(
          controller: _titleController,
          decoration: InputDecoration(labelText: 'Novo nome'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (_titleController.text.trim().isNotEmpty) {
                chapter.title = _titleController.text.trim();
                _updateChapter(chapter);
                Navigator.of(context).pop();
              }
            },
            child: Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteChapterConfirmationDialog(StudyChapter chapter) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir Capítulo'),
        content: Text(
            'Tem certeza que deseja excluir o capítulo "${chapter.title}"? Todas as suas anotações e imagens serão perdidas.'),
        actions: [
          TextButton(
            child: Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: Text('Excluir'),
            style: ElevatedButton.styleFrom(backgroundColor: BjjApp.errorColor),
            onPressed: () {
              _deleteChapter(chapter.id);
              Navigator.of(ctx).pop();
              showBjjSnackBar(context, 'Capítulo excluído.', type: 'info');
            },
          ),
        ],
      ),
    );
  }

  void _showAddNoteDialog(StudyChapter chapter) {
    final _textController = TextEditingController();
    final _timeController = TextEditingController();
    XFile? _pickedImage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Adicionar Anotação'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      labelText: 'Sua anotação...',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 4,
                    autofocus: true,
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _timeController,
                    decoration: InputDecoration(
                      labelText: 'Timestamp (ex: 15:30)',
                      hintText: 'Opcional',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                    keyboardType: TextInputType.datetime,
                  ),
                  SizedBox(height: 20),
                  if (_pickedImage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: BjjApp.successColor, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _pickedImage!.name,
                              style: TextStyle(
                                  color: BjjApp.textHint, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  OutlinedButton.icon(
                    icon: Icon(
                        _pickedImage == null
                            ? Icons.add_photo_alternate_outlined
                            : Icons.check_circle_outline,
                        color: _pickedImage == null
                            ? BjjApp.textHint
                            : BjjApp.successColor),
                    label: Text(_pickedImage == null
                        ? 'Anexar Imagem'
                        : 'Imagem Anexada!'),
                    onPressed: () async {
                      final ImagePicker _picker = ImagePicker();
                      final XFile? image =
                          await _picker.pickImage(source: ImageSource.gallery);
                      if (image != null) {
                        setDialogState(() {
                          _pickedImage = image;
                        });
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: BjjApp.borderNormal),
                      foregroundColor: BjjApp.textHint,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancelar')),
              ElevatedButton(
                child: Text('Salvar'),
                onPressed: () async {
                  if (_textController.text.trim().isNotEmpty) {
                    String? savedImagePath;
                    if (_pickedImage != null) {
                      try {
                        final Directory appDir =
                            await getApplicationDocumentsDirectory();
                        final String fileName =
                            '${DateTime.now().millisecondsSinceEpoch}.jpg';
                        final File sourceFile = File(_pickedImage!.path);
                        final File newFile = await sourceFile
                            .copy(p.join(appDir.path, fileName));
                        savedImagePath = newFile.path;
                      } catch (e) {
                        if (mounted) {
                          showBjjSnackBar(context, 'Erro ao salvar imagem: $e',
                              type: 'error');
                        }
                      }
                    }

                    final newNote = StudyNote(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      text: _textController.text.trim(),
                      timestamp: _timeController.text.trim().isEmpty
                          ? null
                          : _timeController.text.trim(),
                      createdAt: Timestamp.now(),
                      localImagePath: savedImagePath,
                    );
                    chapter.notes.add(newNote);
                    _updateChapter(chapter);
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteNote(StudyChapter chapter, StudyNote note) async {
    if (note.localImagePath != null) {
      try {
        final file = File(note.localImagePath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        print("Erro ao deletar arquivo de imagem: $e");
      }
    }
    setState(() {
      chapter.notes.removeWhere((n) => n.id == note.id);
    });
    _updateChapter(chapter);
  }

  void _showImageDialog(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12.0),
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: BjjApp.darkSurface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Erro ao carregar imagem.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: BjjApp.errorColor),
                    ),
                  );
                },
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Fechar",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.instructional.title, style: TextStyle(fontSize: 18)),
      ),
      body: AppBackground(
        child: StreamBuilder<QuerySnapshot>(
          stream: _chaptersCollection.orderBy('order').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return EmptyStateWidget(
                icon: Icons.bookmark_add_outlined,
                title: 'Nenhum Capítulo Adicionado',
                message:
                    'Adicione o primeiro capítulo ou volume para começar a marcar seu progresso.',
              );
            }

            final chapters = snapshot.data!.docs
                .map((doc) => StudyChapter.fromFirestore(doc))
                .toList();

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 80.0),
              itemCount: chapters.length,
              itemBuilder: (context, index) {
                final chapter = chapters[index];
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: ExpansionTile(
                    key: PageStorageKey(chapter.id),
                    leading: Checkbox(
                      value: chapter.isCompleted,
                      onChanged: (bool? value) {
                        setState(() {
                          chapter.isCompleted = value ?? false;
                        });
                        _updateChapter(chapter);
                      },
                    ),
                    title: Text(chapter.title,
                        style: Theme.of(context).textTheme.titleMedium),
                    trailing: PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert_rounded,
                          color: BjjApp.textHint.withOpacity(0.9)),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditChapterDialog(chapter);
                        } else if (value == 'delete') {
                          _showDeleteChapterConfirmationDialog(chapter);
                        } else if (value == 'move_up') {
                          _reorderChapter(chapters, index, true);
                        } else if (value == 'move_down') {
                          _reorderChapter(chapters, index, false);
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit_note_rounded,
                                color: BjjApp.primaryAccent),
                            title: Text('Editar Título'),
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'move_up',
                          enabled: index > 0,
                          child: ListTile(
                            leading: Icon(Icons.arrow_upward_rounded,
                                color:
                                    index > 0 ? BjjApp.infoColor : Colors.grey),
                            title: Text('Mover para Cima'),
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'move_down',
                          enabled: index < chapters.length - 1,
                          child: ListTile(
                            leading: Icon(Icons.arrow_downward_rounded,
                                color: index < chapters.length - 1
                                    ? BjjApp.infoColor
                                    : Colors.grey),
                            title: Text('Mover para Baixo'),
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete_sweep_outlined,
                                color: BjjApp.errorColor),
                            title: Text('Excluir Capítulo'),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: Column(
                          children: [
                            if (chapter.notes.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16.0),
                                child: Text(
                                    'Nenhuma anotação para este capítulo.',
                                    style: TextStyle(color: BjjApp.textHint)),
                              ),
                            ...chapter.notes.map((note) {
                              return Card(
                                clipBehavior: Clip.antiAlias,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ListTile(
                                      leading: Icon(
                                          note.timestamp != null
                                              ? Icons.timelapse_rounded
                                              : Icons.notes_rounded,
                                          color: BjjApp.primaryAccent,
                                          size: 20),
                                      title: Text(note.text,
                                          style: TextStyle(
                                              fontSize: 14, height: 1.4)),
                                      subtitle: note.timestamp != null
                                          ? Text('Em: ${note.timestamp}',
                                              style: TextStyle(
                                                  color: BjjApp.textHint))
                                          : null,
                                      trailing: IconButton(
                                        icon: Icon(Icons.close,
                                            size: 18, color: BjjApp.textHint),
                                        onPressed: () =>
                                            _deleteNote(chapter, note),
                                      ),
                                    ),
                                    if (note.localImagePath != null)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            16, 0, 16, 12),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: TextButton.icon(
                                            icon: Icon(Icons.image_outlined,
                                                size: 16),
                                            label: Text("Ver Anexo"),
                                            onPressed: () {
                                              _showImageDialog(context,
                                                  note.localImagePath!);
                                            },
                                            style: TextButton.styleFrom(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 8),
                                              backgroundColor: BjjApp
                                                  .darkSurface
                                                  .withOpacity(0.5),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                            SizedBox(height: 8),
                            TextButton.icon(
                              icon: Icon(Icons.add_comment_outlined, size: 18),
                              label: Text('Adicionar Anotação'),
                              onPressed: () => _showAddNoteDialog(chapter),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: StreamBuilder<QuerySnapshot>(
          stream: _chaptersCollection.snapshots(),
          builder: (context, snapshot) {
            final count = snapshot.data?.docs.length ?? 0;
            return FloatingActionButton(
              onPressed: () => _showAddChapterDialog(currentCount: count),
              child: Icon(Icons.add_rounded),
              tooltip: 'Adicionar Capítulo/Volume',
            );
          }),
    );
  }
}

// --- TELA PRINCIPAL DE ESTUDOS (sem alterações) ---

class StudiesListPage extends StatelessWidget {
  final String userId;
  final Function(StudyInstructional) onDeleteInstructional;

  const StudiesListPage({
    Key? key,
    required this.userId,
    required this.onDeleteInstructional,
  }) : super(key: key);

  void _showDeleteConfirmation(
      BuildContext context, StudyInstructional instructional) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir Estudo'),
        content: Text(
            'Deseja realmente excluir o estudo sobre "${instructional.title}"? Todos os capítulos e anotações (incluindo imagens) serão perdidos.'),
        actions: [
          TextButton(
            child: Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: Text('Excluir'),
            style: ElevatedButton.styleFrom(backgroundColor: BjjApp.errorColor),
            onPressed: () {
              onDeleteInstructional(instructional);
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('instructionals')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.school_outlined,
              title: 'Nenhum Estudo Adicionado',
              message:
                  'Clique no botão "+" para adicionar seu primeiro instrucional e começar a anotar.',
            );
          }

          final instructionals = snapshot.data!.docs
              .map((doc) => StudyInstructional.fromFirestore(doc))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 80.0),
            itemCount: instructionals.length,
            itemBuilder: (context, index) {
              final instructional = instructionals[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: BjjApp.primaryAccent,
                    child: Icon(Icons.menu_book_rounded,
                        color: BjjApp.primaryAccentForeground),
                  ),
                  title: Text(instructional.title,
                      style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Text(
                    'Por: ${instructional.instructor}\nAdicionado em: ${DateFormat('dd/MM/yy').format(instructional.createdAt.toDate())}',
                    style: TextStyle(color: BjjApp.textHint, height: 1.4),
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline_rounded,
                        color: BjjApp.errorColor.withOpacity(0.8)),
                    onPressed: () =>
                        _showDeleteConfirmation(context, instructional),
                  ),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => InstructionalDetailPage(
                        userId: userId,
                        instructional: instructional,
                      ),
                    ));
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- DIÁLOGO PARA ADICIONAR NOVO INSTRUCIONAL (sem alterações) ---

class AddInstructionalDialog extends StatefulWidget {
  final Function(String title, String instructor) onAdd;
  const AddInstructionalDialog({Key? key, required this.onAdd})
      : super(key: key);

  @override
  _AddInstructionalDialogState createState() => _AddInstructionalDialogState();
}

class _AddInstructionalDialogState extends State<AddInstructionalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _instructorController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Adicionar Novo Estudo'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Nome do Instrucional',
                prefixIcon: Icon(Icons.title_rounded),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _instructorController,
              decoration: InputDecoration(
                labelText: 'Professor / Autor',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: Text('Cancelar'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        ElevatedButton(
          child: Text('Adicionar'),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onAdd(_titleController.text.trim(),
                  _instructorController.text.trim());
              Navigator.of(context).pop();
            }
          },
        )
      ],
    );
  }
}

// --- FIM DA SEÇÃO DE ESTUDOS ---

// --- Restante do código (HomePageDashboard, MainPage, etc.) ---

class HomePageDashboard extends StatelessWidget {
  final VoidCallback onNavigateToAlunos;
  final VoidCallback onNavigateToSorteio;
  final VoidCallback onNavigateToTreino;
  final VoidCallback onNavigateToPlacar;
  final VoidCallback onNavigateToCheckin;
  final VoidCallback onNavigateToEstudos;
  final bool isSparringMode;

  const HomePageDashboard({
    Key? key,
    required this.onNavigateToAlunos,
    required this.onNavigateToSorteio,
    required this.onNavigateToTreino,
    required this.onNavigateToPlacar,
    required this.onNavigateToCheckin,
    required this.onNavigateToEstudos,
    required this.isSparringMode,
  }) : super(key: key);

  Widget _buildDashboardButton(
      BuildContext context, IconData icon, String label, VoidCallback onPressed,
      {Color? color, bool important = false}) {
    final theme = Theme.of(context);
    return Card(
      elevation: important ? 5 : 3,
      margin: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: important
            ? BorderSide(color: color ?? BjjApp.primaryAccent, width: 1.5)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(icon,
                  size: 30,
                  color: important
                      ? (color ?? BjjApp.primaryAccent)
                      : (theme.colorScheme.onSurface.withOpacity(0.8))),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: important
                          ? (color ?? BjjApp.primaryAccent)
                          : BjjApp.textPrimary.withOpacity(0.9)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(height: MediaQuery.of(context).padding.top + 20),
              Text(
                'Match BJJ',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: BjjApp.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 38,
                      letterSpacing: 1.5,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Seu gerenciador de treinos de Jiu-Jitsu.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: BjjApp.textHint.withOpacity(0.9),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 56),
              _buildDashboardButton(
                context,
                Icons.people_alt_rounded,
                'Gerenciar Alunos',
                onNavigateToAlunos,
              ),
              _buildDashboardButton(
                context,
                Icons.shuffle_rounded,
                'Sorteio de Duplas',
                onNavigateToSorteio,
              ),
              if (isSparringMode)
                _buildDashboardButton(
                  context,
                  Icons.sports_kabaddi_rounded,
                  'Ver Rodadas (Treino)',
                  onNavigateToTreino,
                  color: BjjApp.warningColor,
                  important: true,
                )
              else
                _buildDashboardButton(
                  context,
                  Icons.sports_kabaddi_outlined,
                  'Treino (Inativo)',
                  onNavigateToTreino,
                  color: BjjApp.textHint.withOpacity(0.7),
                ),
              _buildDashboardButton(
                context,
                Icons.school_rounded,
                'Caderno de Estudos',
                onNavigateToEstudos,
              ),
              _buildDashboardButton(
                context,
                Icons.scoreboard_rounded,
                'Placar Individual',
                onNavigateToPlacar,
              ),
              _buildDashboardButton(
                context,
                Icons.calendar_today_rounded,
                'Check-in de Treino',
                onNavigateToCheckin,
              ),
              const SizedBox(height: 32),
              Text(
                'Desenvolvido por Ziliotto SmartDev',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: BjjApp.textHint.withOpacity(0.6),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Si vis pacem, para bellum',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: BjjApp.textHint.withOpacity(0.5),
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CheckinPage extends StatefulWidget {
  final List<Aluno> todosAlunos;
  const CheckinPage({Key? key, required this.todosAlunos}) : super(key: key);
  @override
  State<CheckinPage> createState() => _CheckinPageState();
}

class _CheckinPageState extends State<CheckinPage> {
  Aluno? _alunoSelecionado;
  final CheckinService _checkinService = CheckinService();
  StreamSubscription<List<CheckinEntry>>? _checkinsSubscription;
  List<CheckinEntry> _checkinsDoAlunoAtual = [];
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<CheckinEntry>> _eventosAgrupados = {};
  int _treinosNoMes = 0;
  int _treinosTotal = 0;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  void dispose() {
    _checkinsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fazerCheckinHoje() async {
    if (_alunoSelecionado == null) {
      showBjjSnackBar(context, 'Por favor, selecione um aluno.', type: 'error');
      return;
    }
    DateTime agora = DateTime.now();
    await _checkinService.saveCheckin(_alunoSelecionado!, agora);
    showBjjSnackBar(context,
        'Check-in realizado para ${_alunoSelecionado!.nome} em ${DateFormat('dd/MM/yyyy').format(agora)}!',
        type: 'success');
  }

  Future<void> _fazerCheckinRetroativo() async {
    if (_alunoSelecionado == null) {
      showBjjSnackBar(context, 'Selecione um aluno para marcar a presença.',
          type: 'warning');
      return;
    }

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: BjjApp.primaryAccent,
                  onPrimary: BjjApp.primaryAccentForeground,
                  onSurface: BjjApp.textPrimary,
                ),
            dialogBackgroundColor: BjjApp.darkSurface,
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      await _checkinService.saveCheckin(_alunoSelecionado!, pickedDate);
      showBjjSnackBar(context,
          'Check-in retroativo para ${_alunoSelecionado!.nome} em ${DateFormat('dd/MM/yyyy').format(pickedDate)} salvo!',
          type: 'success');
    }
  }

  void _carregarCheckinsDoAluno() {
    _checkinsSubscription?.cancel();

    if (_alunoSelecionado != null) {
      _checkinsSubscription = _checkinService
          .getCheckinsForStudentStream(_alunoSelecionado!)
          .listen((checkins) {
        if (!mounted) return;
        setState(() {
          _checkinsDoAlunoAtual = checkins;
          _agruparEventos();
          _calcularContadores();
        });
      });
    } else {
      if (!mounted) return;
      setState(() {
        _checkinsDoAlunoAtual = [];
        _eventosAgrupados = {};
        _treinosNoMes = 0;
        _treinosTotal = 0;
      });
    }
  }

  void _agruparEventos() {
    _eventosAgrupados = {};
    for (var checkin in _checkinsDoAlunoAtual) {
      final dataNormalizada =
          DateTime.utc(checkin.date.year, checkin.date.month, checkin.date.day);
      if (_eventosAgrupados[dataNormalizada] == null) {
        _eventosAgrupados[dataNormalizada] = [];
      }
      _eventosAgrupados[dataNormalizada]!.add(checkin);
    }
  }

  void _calcularContadores() {
    _treinosTotal = _checkinsDoAlunoAtual.length;
    _treinosNoMes = _checkinsDoAlunoAtual
        .where((c) =>
            c.date.year == _focusedDay.year &&
            c.date.month == _focusedDay.month)
        .length;
  }

  List<CheckinEntry> _getEventosParaDia(DateTime day) {
    final dataNormalizada = DateTime.utc(day.year, day.month, day.day);
    return _eventosAgrupados[dataNormalizada] ?? [];
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
    }

    if (_alunoSelecionado != null &&
        _getEventosParaDia(selectedDay).isNotEmpty) {
      _mostrarDialogoRemoverCheckin(selectedDay);
    }
  }

  void _mostrarDialogoRemoverCheckin(DateTime date) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remover Check-in'),
        content: Text(
            'Deseja remover o check-in de ${_alunoSelecionado!.nome} para o dia ${DateFormat('dd/MM/yyyy').format(date)}?'),
        actions: [
          TextButton(
            child: Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: Text('Remover'),
            style: ElevatedButton.styleFrom(
              backgroundColor: BjjApp.errorColor,
              foregroundColor: BjjApp.textPrimary,
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _checkinService.removeCheckin(_alunoSelecionado!, date);
              showBjjSnackBar(context, 'Check-in removido com sucesso!',
                  type: 'info');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Registro de Presença',
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<Aluno>(
                      value: _alunoSelecionado,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Selecione o Aluno',
                        prefixIcon: Icon(Icons.person_search_rounded),
                      ),
                      hint: Text("Selecione um aluno da lista"),
                      items: widget.todosAlunos.map((aluno) {
                        return DropdownMenuItem<Aluno>(
                          value: aluno,
                          child:
                              Text(aluno.nome, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (Aluno? aluno) {
                        setState(() {
                          _alunoSelecionado = aluno;
                        });
                        _carregarCheckinsDoAluno();
                      },
                      validator: (v) => v == null ? 'Selecione um aluno' : null,
                    ),
                    if (widget.todosAlunos.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Nenhum aluno cadastrado. Adicione na aba "Alunos".',
                          style: TextStyle(
                              color: BjjApp.warningColor, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: Icon(Icons.check_circle_outline_rounded),
                      label: Text('Fazer Check-in Hoje'),
                      onPressed:
                          _alunoSelecionado == null ? null : _fazerCheckinHoje,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 48),
                        backgroundColor: BjjApp.successColor,
                        foregroundColor: BjjApp.textPrimary,
                        disabledBackgroundColor: Colors.grey[700],
                        disabledForegroundColor: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: Icon(Icons.calendar_month_rounded),
                      label: Text('Check-in Retroativo'),
                      onPressed: _alunoSelecionado == null
                          ? null
                          : _fazerCheckinRetroativo,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(double.infinity, 48),
                        backgroundColor: BjjApp.infoColor,
                        foregroundColor: BjjApp.textPrimary,
                        disabledBackgroundColor: Colors.grey[700],
                        disabledForegroundColor: Colors.grey[400],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton.icon(
                        icon: Icon(Icons.leaderboard_rounded,
                            color: BjjApp.primaryAccent),
                        label: Text('Ver Ranking de Presença'),
                        onPressed: () {
                          if (widget.todosAlunos.isEmpty) {
                            showBjjSnackBar(context,
                                'Não há alunos para exibir no ranking.',
                                type: 'info');
                            return;
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RankingPage(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: BjjApp.primaryAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
                child: Column(
                  children: [
                    Text('Seus Treinos', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    if (_alunoSelecionado != null) ...[
                      TableCalendar<CheckinEntry>(
                        locale: 'pt_BR',
                        firstDay: DateTime.utc(DateTime.now().year - 2, 1, 1),
                        lastDay: DateTime.utc(DateTime.now().year + 2, 12, 31),
                        focusedDay: _focusedDay,
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDay, day),
                        calendarFormat: CalendarFormat.month,
                        eventLoader: _getEventosParaDia,
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            if (events.isNotEmpty) {
                              return Positioned(
                                right: 1,
                                bottom: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: BjjApp.infoColor.withOpacity(0.9),
                                  ),
                                  width: 7.0,
                                  height: 7.0,
                                ),
                              );
                            }
                            return null;
                          },
                        ),
                        calendarStyle: CalendarStyle(
                            outsideDaysVisible: false,
                            todayDecoration: BoxDecoration(
                                color: BjjApp.primaryAccent.withOpacity(0.3),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: BjjApp.primaryAccent, width: 1.5)),
                            selectedDecoration: BoxDecoration(
                              color: BjjApp.primaryAccent,
                              shape: BoxShape.circle,
                            ),
                            defaultTextStyle:
                                TextStyle(color: BjjApp.textSecondary),
                            weekendTextStyle: TextStyle(
                                color: BjjApp.textSecondary.withOpacity(0.7)),
                            todayTextStyle: TextStyle(
                                color: BjjApp.primaryAccentForeground,
                                fontWeight: FontWeight.bold)),
                        headerStyle: HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: TextStyle(
                              color: BjjApp.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w500),
                          leftChevronIcon: Icon(Icons.chevron_left,
                              color: BjjApp.textPrimary),
                          rightChevronIcon: Icon(Icons.chevron_right,
                              color: BjjApp.textPrimary),
                        ),
                        daysOfWeekStyle: DaysOfWeekStyle(
                            weekdayStyle:
                                TextStyle(color: BjjApp.textHint, fontSize: 13),
                            weekendStyle: TextStyle(
                                color: BjjApp.textHint.withOpacity(0.7),
                                fontSize: 13)),
                        onDaySelected: _onDaySelected,
                        onPageChanged: (focusedDay) {
                          if (mounted) {
                            setState(() {
                              _focusedDay = focusedDay;
                              _calcularContadores();
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildCounterChip(
                              'Treinos no Mês:', '$_treinosNoMes'),
                          _buildCounterChip(
                              'Total de Treinos:', '$_treinosTotal'),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32.0),
                        child: Text(
                          'Selecione um aluno para ver seus check-ins.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: BjjApp.textHint, fontSize: 14),
                        ),
                      )
                    ]
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCounterChip(String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: BjjApp.textHint, fontSize: 13)),
        SizedBox(height: 4),
        Chip(
          label: Text(value,
              style: TextStyle(
                  color: BjjApp.primaryAccentForeground,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          backgroundColor: BjjApp.primaryAccent,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ],
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLogin = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Ocorreu um erro.';
      if (e.code == 'user-not-found') {
        message = 'Nenhum usuário encontrado com este e-mail.';
      } else if (e.code == 'wrong-password') {
        message = 'Senha incorreta.';
      } else if (e.code == 'email-already-in-use') {
        message = 'Este e-mail já está em uso.';
      } else if (e.code == 'weak-password') {
        message = 'A senha é muito fraca.';
      }
      if (mounted) {
        showBjjSnackBar(context, message, type: 'error');
      }
    } catch (e) {
      if (mounted) {
        showBjjSnackBar(context, 'Ocorreu um erro inesperado.', type: 'error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _switchAuthMode() {
    setState(() {
      _isLogin = !_isLogin;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Match BJJ',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                              color: BjjApp.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 38)),
                  const SizedBox(height: 8),
                  Text(
                      _isLogin
                          ? 'Faça o login para continuar'
                          : 'Crie sua conta',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: BjjApp.textHint, fontSize: 16)),
                  const SizedBox(height: 40),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                        labelText: 'E-mail',
                        prefixIcon: Icon(Icons.email_outlined)),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) =>
                        (value == null || !value.contains('@'))
                            ? 'Por favor, insira um e-mail válido.'
                            : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                        labelText: 'Senha',
                        prefixIcon: Icon(Icons.lock_outline_rounded)),
                    obscureText: true,
                    validator: (value) => (value == null || value.length < 6)
                        ? 'A senha deve ter pelo menos 6 caracteres.'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton(
                      onPressed: _submit,
                      child: Text(_isLogin ? 'ENTRAR' : 'REGISTRAR'),
                      style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16)),
                    ),
                  TextButton(
                    onPressed: _switchAuthMode,
                    child: Text(
                        _isLogin
                            ? 'Não tem uma conta? Registre-se'
                            : 'Já tem uma conta? Faça o login',
                        style: TextStyle(color: BjjApp.textHint)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _paginaAtual = 0;
  List<Aluno> _alunosParticipantes = [];
  final _firestore = FirebaseFirestore.instance;
  String? get _userId => FirebaseAuth.instance.currentUser?.uid;
  Map<String, dynamic> _sparringState = {};
  bool get _isSparringMode => _sparringState['isSparringMode'] ?? false;
  int get _indiceRodadaAtual => _sparringState['indiceRodadaAtual'] ?? 0;
  List<List<String>> get _todasAsRodadas {
    final dynamic rodadasData = _sparringState['todasAsRodadas'];
    if (rodadasData is List) {
      return rodadasData.map<List<String>>((item) {
        if (item is Map && item.containsKey('lutas') && item['lutas'] is List) {
          return List<String>.from(item['lutas']);
        }
        if (item is List) {
          return List<String>.from(item);
        }
        return <String>[];
      }).toList();
    }
    return [];
  }

  String get _currentSparringTipoGeracao => _sparringState['tipoGeracao'] ?? '';
  StreamSubscription? _sparringStateSubscription;

  @override
  void initState() {
    super.initState();
    _carregarEstadoSparringEmTempoReal();
  }

  @override
  void dispose() {
    _sparringStateSubscription?.cancel();
    super.dispose();
  }

  void _carregarEstadoSparringEmTempoReal() {
    if (_userId == null) return;
    _sparringStateSubscription = _firestore
        .collection('users')
        .doc(_userId)
        .collection('state')
        .doc('sparring')
        .snapshots()
        .listen((doc) {
      if (mounted) {
        setState(() {
          _sparringState = doc.exists ? doc.data()! : {};
        });
      }
    });
  }

  Future<void> _salvarEstadoSparring(Map<String, dynamic> newState) async {
    if (_userId == null) return;
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('state')
        .doc('sparring')
        .set(newState, SetOptions(merge: true));
  }

  Future<void> _limparEstadoSparring() async {
    if (_userId == null) return;
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('state')
        .doc('sparring')
        .delete();
  }

  void _adicionarAluno(Aluno aluno) async {
    if (_userId == null) return;
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('alunos')
        .add(aluno.toJson());
    showBjjSnackBar(context, '${aluno.nome} adicionado!', type: 'success');
  }

  void _removerAluno(Aluno aluno) async {
    if (_userId == null) return;
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('alunos')
        .doc(aluno.id)
        .delete();
    showBjjSnackBar(context, '${aluno.nome} removido.', type: 'info');
  }

  void _editarAluno(Aluno alunoAntigo, Aluno alunoNovo) async {
    if (_userId == null) return;
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('alunos')
        .doc(alunoAntigo.id)
        .update(alunoNovo.toJson());
    showBjjSnackBar(context, '${alunoNovo.nome} atualizado!', type: 'success');
  }

  void _adicionarInstructional(StudyInstructional instructional) async {
    if (_userId == null) return;
    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('instructionals')
        .add(instructional.toMap());
    showBjjSnackBar(context, 'Estudo "${instructional.title}" adicionado!',
        type: 'success');
  }

  void _removerInstructional(StudyInstructional instructional) async {
    if (_userId == null) return;

    final chaptersSnapshot = await _firestore
        .collection('users')
        .doc(_userId)
        .collection('instructionals')
        .doc(instructional.id)
        .collection('chapters')
        .get();

    for (var doc in chaptersSnapshot.docs) {
      final chapter = StudyChapter.fromFirestore(doc);
      for (final note in chapter.notes) {
        if (note.localImagePath != null) {
          try {
            final file = File(note.localImagePath!);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (e) {
            print("Erro ao deletar arquivo de imagem local: $e");
          }
        }
      }
      await doc.reference.delete();
    }

    await _firestore
        .collection('users')
        .doc(_userId)
        .collection('instructionals')
        .doc(instructional.id)
        .delete();
    showBjjSnackBar(context, 'Estudo removido.', type: 'info');
  }

  Future<void> _fazerCheckinParaAlunos(List<Aluno> alunosAChecar) async {
    if (alunosAChecar.isEmpty || !mounted) return;
    final checkinService = CheckinService();
    final agora = DateTime.now();
    int checkinsRealizados = 0;
    for (final aluno in alunosAChecar) {
      await checkinService.saveCheckin(aluno, agora);
      checkinsRealizados++;
    }
    if (mounted && checkinsRealizados > 0) {
      showBjjSnackBar(
          context, '$checkinsRealizados check-ins confirmados para hoje!',
          type: 'success');
    }
  }

  Future<void> _fazerBackup() async {
    if (_userId == null) {
      if (mounted)
        showBjjSnackBar(context, 'Faça login para realizar o backup.',
            type: 'error');
      return;
    }
    if (mounted)
      showBjjSnackBar(
          context, 'Preparando backup... Isso pode levar um momento.',
          type: 'info');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Aviso de Backup'),
        content: Text(
            'Este backup salva os dados de alunos, check-ins e estudos (textos e referências). As imagens salvas localmente no aparelho NÃO são incluídas neste backup.'),
        actions: [
          TextButton(
            child: Text('Cancelar'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          ElevatedButton(
            child: Text('Continuar'),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed != true) return;

      try {
        final alunosSnapshot = await _firestore
            .collection('users')
            .doc(_userId)
            .collection('alunos')
            .get();
        final checkinsSnapshot = await _firestore
            .collection('users')
            .doc(_userId)
            .collection('checkins')
            .get();

        List<Map<String, dynamic>> alunosData = alunosSnapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();

        List<Map<String, dynamic>> checkinsData =
            checkinsSnapshot.docs.map((doc) {
          Map<String, dynamic> data = doc.data();
          data['id'] = doc.id;
          if (data['date'] is Timestamp) {
            data['date'] =
                (data['date'] as Timestamp).toDate().toIso8601String();
          }
          return data;
        }).toList();

        List<Map<String, dynamic>> studiesData = [];
        final instructionalsSnapshot = await _firestore
            .collection('users')
            .doc(_userId)
            .collection('instructionals')
            .get();

        for (var instructionalDoc in instructionalsSnapshot.docs) {
          Map<String, dynamic> instructionalData = instructionalDoc.data();
          instructionalData['id'] = instructionalDoc.id;
          if (instructionalData['createdAt'] is Timestamp) {
            instructionalData['createdAt'] =
                (instructionalData['createdAt'] as Timestamp)
                    .toDate()
                    .toIso8601String();
          }
          List<Map<String, dynamic>> chaptersData = [];
          final chaptersSnapshot =
              await instructionalDoc.reference.collection('chapters').get();
          for (var chapterDoc in chaptersSnapshot.docs) {
            Map<String, dynamic> chapterData = chapterDoc.data();
            chapterData['id'] = chapterDoc.id;
            if (chapterData['notes'] is List) {
              List<dynamic> notes = chapterData['notes'];
              chapterData['notes'] = notes.map((note) {
                if (note is Map && note['createdAt'] is Timestamp) {
                  note['createdAt'] = (note['createdAt'] as Timestamp)
                      .toDate()
                      .toIso8601String();
                }
                return note;
              }).toList();
            }
            chaptersData.add(chapterData);
          }
          instructionalData['chapters'] = chaptersData;
          studiesData.add(instructionalData);
        }

        final backupData = {
          'alunos': alunosData,
          'checkins': checkinsData,
          'studies': studiesData,
        };

        final jsonString = JsonEncoder.withIndent('  ').convert(backupData);
        final directory = await getTemporaryDirectory();
        final fileName =
            'matchbjj_backup_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
        final file = File('${directory.path}/$fileName');
        await file.writeAsString(jsonString);

        if (mounted) {
          Share.shareXFiles([XFile(file.path)], subject: 'Backup MatchBJJ');
        }
      } catch (e, s) {
        print('Erro no backup: $e\n$s');
        if (mounted) {
          showBjjSnackBar(context, 'Erro ao gerar backup: $e', type: 'error');
        }
      }
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  void _atualizarAlunosParticipantes(List<Aluno> novosParticipantes) {
    setState(() {
      _alunosParticipantes = novosParticipantes;
    });
  }

  Future<void> _navegarParaSelecaoAlunos(List<Aluno> todosOsAlunos) async {
    final List<Aluno>? r = await Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          SelecaoAlunosPage(
              todosOsAlunos: todosOsAlunos,
              alunosSelecionadosIniciais: _alunosParticipantes),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: Duration(milliseconds: 300),
    ));
    if (r != null) _atualizarAlunosParticipantes(r);
  }

  Future<void> _iniciarSparring(
      List<List<String>> rodadas, String tipoGeracao) async {
    if (rodadas.isEmpty) {
      showBjjSnackBar(context, 'Nenhuma rodada gerada para iniciar.',
          type: 'warning');
      return;
    }
    final List<Map<String, dynamic>> rodadasParaFirestore =
        rodadas.map((rodada) => {'lutas': rodada}).toList();

    final newState = {
      'isSparringMode': true,
      'indiceRodadaAtual': 1,
      'todasAsRodadas': rodadasParaFirestore,
      'tipoGeracao': tipoGeracao,
      'participantesIds': _alunosParticipantes.map((a) => a.id).toList(),
    };

    _salvarEstadoSparring(newState);

    setState(() {
      _paginaAtual = 3;
    });

    showBjjSnackBar(context, 'Treino iniciado! Vá para a aba "Treino".',
        type: 'info');
  }

  void _proximaRodadaSparring() {
    final newIndex = _indiceRodadaAtual + 1;
    _salvarEstadoSparring({'indiceRodadaAtual': newIndex});

    if (_todasAsRodadas.isNotEmpty &&
        newIndex > _todasAsRodadas.length &&
        mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted)
          showBjjSnackBar(
              context, 'Todas as rodadas foram exibidas! Clique em Finalizar.',
              type: 'info');
      });
    }
  }

  void _finalizarSparring() {
    setState(() {
      _sparringState = {};
      _paginaAtual = 0;
    });
    _limparEstadoSparring();
    showBjjSnackBar(context, 'Treino finalizado!', type: 'info');
  }

  void _navegarParaSecaoPorDashboard(int novaPagina) {
    setState(() {
      _paginaAtual = novaPagina;
    });
  }

  String _getAppBarTitle() {
    switch (_paginaAtual) {
      case 0:
        return '';
      case 1:
        return 'Gerenciar Alunos';
      case 2:
        return 'Sorteio de Duplas';
      case 3:
        return _isSparringMode ? 'Treino em Andamento' : 'Treino';
      case 4:
        return 'Meus Estudos';
      case 5:
        return 'Check-in de Treinos';
      default:
        return 'Match BJJ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _userId == null
          ? null
          : _firestore
              .collection('users')
              .doc(_userId)
              .collection('alunos')
              .orderBy('nome')
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: AppBackground(
                  child: Center(child: CircularProgressIndicator())));
        }

        if (!snapshot.hasData || snapshot.hasError) {
          return Scaffold(
              body: AppBackground(
                  child: Center(
                      child:
                          Text('Erro ao carregar dados. Tente reiniciar.'))));
        }

        final todosAlunos = snapshot.data!.docs
            .map((doc) =>
                Aluno.fromJson(doc.id, doc.data() as Map<String, dynamic>))
            .toList();

        _alunosParticipantes.removeWhere((p) => !todosAlunos.contains(p));

        final List<Widget> telasPrincipais = [
          HomePageDashboard(
            isSparringMode: _isSparringMode,
            onNavigateToAlunos: () => _navegarParaSecaoPorDashboard(1),
            onNavigateToSorteio: () => _navegarParaSecaoPorDashboard(2),
            onNavigateToTreino: () {
              if (!_isSparringMode) {
                showBjjSnackBar(
                    context, 'Inicie o Treino na aba "Sorteio" primeiro.',
                    type: 'warning');
                _navegarParaSecaoPorDashboard(2);
                return;
              }
              _navegarParaSecaoPorDashboard(3);
            },
            onNavigateToEstudos: () => _navegarParaSecaoPorDashboard(4),
            onNavigateToPlacar: () {
              if (todosAlunos.length < 2) {
                showBjjSnackBar(
                    context, 'Cadastre pelo menos dois alunos para lutar.',
                    type: 'warning');
                return;
              }
              Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) =>
                      MatchSetupPage(todosAlunos: todosAlunos)));
            },
            onNavigateToCheckin: () => _navegarParaSecaoPorDashboard(5),
          ),
          AlunosPage(
              alunos: todosAlunos,
              onAlunoRemovido: _removerAluno,
              onAlunoEditado: _editarAluno),
          DuplasPage(
              alunos: _alunosParticipantes,
              onSelecionarParticipantes: () =>
                  _navegarParaSelecaoAlunos(todosAlunos),
              onIniciarSparring: _iniciarSparring,
              onCheckinAlunos: _fazerCheckinParaAlunos,
              isSparringMode: _isSparringMode),
          SparringPage(
              alunosParticipantes: _alunosParticipantes,
              tipoGeracao: _currentSparringTipoGeracao,
              todasAsRodadas: _todasAsRodadas,
              indiceRodadaAtual: _indiceRodadaAtual,
              isSparringMode: _isSparringMode,
              onProximaRodada: _proximaRodadaSparring,
              onFinalizarSparring: _finalizarSparring),
          StudiesListPage(
            userId: _userId!,
            onDeleteInstructional: _removerInstructional,
          ),
          CheckinPage(todosAlunos: todosAlunos),
        ];

        if (_paginaAtual >= telasPrincipais.length) {
          _paginaAtual = 0;
        }

        return Scaffold(
          extendBodyBehindAppBar: _paginaAtual == 0,
          appBar: AppBar(
            title: Text(_getAppBarTitle()),
            centerTitle: true,
            backgroundColor: _paginaAtual == 0
                ? Colors.transparent
                : Theme.of(context).appBarTheme.backgroundColor,
            elevation:
                _paginaAtual == 0 ? 0 : Theme.of(context).appBarTheme.elevation,
            actions: [
              IconButton(
                icon: Icon(Icons.settings_rounded),
                tooltip: 'Configurações',
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => SettingsPage(
                      onBackup: _fazerBackup,
                      onRestore: _restaurarBackup,
                      onLogout: _logout,
                    ),
                  ));
                },
              ),
            ],
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) =>
                FadeTransition(opacity: animation, child: child),
            child: IndexedStack(
              key: ValueKey<int>(_paginaAtual),
              index: _paginaAtual,
              children: telasPrincipais,
            ),
          ),
          bottomNavigationBar: Visibility(
            visible: _paginaAtual != 0,
            child: BottomNavigationBar(
              currentIndex: _paginaAtual,
              onTap: (index) {
                if (index == 6) {
                  if (todosAlunos.length < 2) {
                    showBjjSnackBar(
                        context, 'Cadastre pelo menos dois alunos para lutar.',
                        type: 'warning');
                    return;
                  }
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) =>
                          MatchSetupPage(todosAlunos: todosAlunos)));
                } else {
                  if (index == 3 && !_isSparringMode) {
                    showBjjSnackBar(
                        context, 'Inicie o Treino na aba "Sorteio" primeiro.',
                        type: 'warning');
                    return;
                  }
                  setState(() {
                    _paginaAtual = index;
                  });
                }
              },
              items: const [
                BottomNavigationBarItem(
                    icon: Icon(Icons.dashboard_rounded), label: 'Início'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.people_alt_rounded), label: 'Alunos'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.shuffle_rounded), label: 'Sorteio'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.sports_kabaddi_rounded), label: 'Treino'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.school_rounded), label: 'Estudos'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.calendar_today_rounded),
                    label: 'Check-in'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.scoreboard_rounded), label: 'Placar'),
              ],
              type: BottomNavigationBarType.fixed,
              selectedFontSize: Theme.of(context)
                      .bottomNavigationBarTheme
                      .selectedLabelStyle
                      ?.fontSize ??
                  12,
              unselectedFontSize: Theme.of(context)
                      .bottomNavigationBarTheme
                      .unselectedLabelStyle
                      ?.fontSize ??
                  12,
            ),
          ),
          floatingActionButton: _paginaAtual == 1 || _paginaAtual == 4
              ? FloatingActionButton(
                  onPressed: () {
                    if (_paginaAtual == 1) {
                      showDialog(
                        context: context,
                        builder: (_) => AdicionarAlunoDialog(
                          onAlunoAdicionado: _adicionarAluno,
                        ),
                      );
                    } else if (_paginaAtual == 4) {
                      showDialog(
                        context: context,
                        builder: (_) => AddInstructionalDialog(
                          onAdd: (title, instructor) {
                            final newInstructional = StudyInstructional(
                              id: '',
                              title: title,
                              instructor: instructor,
                              createdAt: Timestamp.now(),
                            );
                            _adicionarInstructional(newInstructional);
                          },
                        ),
                      );
                    }
                  },
                  child: Icon(Icons.add_rounded),
                )
              : null,
        );
      },
    );
  }

  Future<void> _restaurarBackup() async {
    if (_userId == null) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null || result.files.single.path == null) {
        if (mounted)
          showBjjSnackBar(context, 'Nenhum arquivo selecionado.', type: 'info');
        return;
      }
      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final backupData = jsonDecode(jsonString);
      if (backupData['alunos'] == null || backupData['checkins'] == null) {
        throw Exception('Arquivo de backup inválido ou corrompido.');
      }
      final bool? confirmado = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('⚠️ Atenção!'),
          content: Text(
              'Restaurar este backup irá APAGAR TODOS os seus dados atuais na nuvem (alunos, check-ins, estudos) e substituí-los pelos dados do arquivo. Os caminhos para as imagens salvas localmente podem não funcionar se o backup for de outro aparelho. Esta ação não pode ser desfeita. Deseja continuar?'),
          actions: [
            TextButton(
              child: Text('Cancelar'),
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            ElevatedButton(
              child: Text('Sim, Restaurar'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: BjjApp.errorColor,
                  foregroundColor: BjjApp.textPrimary),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      );
      if (confirmado != true) {
        if (mounted)
          showBjjSnackBar(context, 'Restauração cancelada.', type: 'info');
        return;
      }
      showBjjSnackBar(
          context, 'Restaurando dados... Isso pode levar um momento.',
          type: 'info');
      final batch = _firestore.batch();
      final collectionsToDelete = ['alunos', 'checkins', 'instructionals'];
      for (var collectionName in collectionsToDelete) {
        final collectionSnapshot = await _firestore
            .collection('users')
            .doc(_userId)
            .collection(collectionName)
            .get();
        for (var doc in collectionSnapshot.docs) {
          if (collectionName == 'instructionals') {
            final chaptersSnapshot =
                await doc.reference.collection('chapters').get();
            for (var chapterDoc in chaptersSnapshot.docs) {
              batch.delete(chapterDoc.reference);
            }
          }
          batch.delete(doc.reference);
        }
      }
      final List<dynamic> alunosFromBackup = backupData['alunos'];
      for (var alunoData in alunosFromBackup) {
        final alunoId =
            alunoData['id'] ?? _firestore.collection('users').doc().id;
        final docRef = _firestore
            .collection('users')
            .doc(_userId)
            .collection('alunos')
            .doc(alunoId);
        (alunoData as Map).remove('id');
        batch.set(docRef, alunoData);
      }
      final List<dynamic> checkinsFromBackup = backupData['checkins'];
      for (var checkinData in checkinsFromBackup) {
        final checkinId =
            checkinData['id'] ?? _firestore.collection('users').doc().id;
        final docRef = _firestore
            .collection('users')
            .doc(_userId)
            .collection('checkins')
            .doc(checkinId);
        (checkinData as Map).remove('id');
        checkinData['date'] =
            Timestamp.fromDate(DateTime.parse(checkinData['date']));
        batch.set(docRef, checkinData);
      }
      if (backupData['studies'] != null) {
        final List<dynamic> studiesFromBackup = backupData['studies'];
        for (var instructionalData in studiesFromBackup) {
          final instructionalId = instructionalData['id'] ??
              _firestore.collection('users').doc().id;
          final docRef = _firestore
              .collection('users')
              .doc(_userId)
              .collection('instructionals')
              .doc(instructionalId);

          final List<dynamic>? chaptersData = instructionalData['chapters'];
          (instructionalData as Map).remove('id');
          instructionalData.remove('chapters');
          instructionalData['createdAt'] = Timestamp.fromDate(
              DateTime.parse(instructionalData['createdAt']));

          batch.set(docRef, instructionalData);

          if (chaptersData != null) {
            for (var chapterData in chaptersData) {
              final chapterId =
                  chapterData['id'] ?? _firestore.collection('users').doc().id;
              final chapterDocRef =
                  docRef.collection('chapters').doc(chapterId);
              (chapterData as Map).remove('id');
              if (chapterData['notes'] is List) {
                chapterData['notes'] =
                    (chapterData['notes'] as List).map((note) {
                  if (note is Map && note['createdAt'] is String) {
                    note['createdAt'] =
                        Timestamp.fromDate(DateTime.parse(note['createdAt']));
                  }
                  return note;
                }).toList();
              }
              batch.set(chapterDocRef, chapterData);
            }
          }
        }
      }
      await batch.commit();
      if (mounted)
        showBjjSnackBar(context, 'Dados restaurados com sucesso!',
            type: 'success');
    } catch (e, s) {
      print('Erro ao restaurar: $e\n$s');
      if (mounted)
        showBjjSnackBar(context, 'Erro ao restaurar backup: $e', type: 'error');
    }
  }
}

class DuplasPage extends StatefulWidget {
  final List<Aluno> alunos;
  final VoidCallback onSelecionarParticipantes;
  final Function(List<List<String>>, String) onIniciarSparring;
  final Function(List<Aluno>) onCheckinAlunos;
  final bool isSparringMode;
  DuplasPage(
      {required this.alunos,
      required this.onSelecionarParticipantes,
      required this.onIniciarSparring,
      required this.onCheckinAlunos,
      required this.isSparringMode});
  @override
  _DuplasPageState createState() => _DuplasPageState();
}

class _DuplasPageState extends State<DuplasPage> {
  List<List<String>> _rodadasGeradas = [];
  String _tipoGeracao = 'Aleatório';
  final List<String> _opcoesGeracao = ['Aleatório', 'Por Faixa', 'Por Peso'];

  int _getBeltIndex(String faixa) {
    const List<String> ordemFaixas = [
      'Branca',
      'Cinza com Ponta Branca',
      'Cinza',
      'Cinza com Ponta Preta',
      'Amarela com Ponta Branca',
      'Amarela',
      'Amarela com Ponta Preta',
      'Laranja com Ponta Branca',
      'Laranja',
      'Laranja com Ponta Preta',
      'Verde com Ponta Branca',
      'Verde',
      'Verde com Ponta Preta',
      'Azul',
      'Roxa',
      'Marrom',
      'Preta'
    ];
    return ordemFaixas.indexOf(faixa.capitalizeFirst());
  }

  void _gerarRodadasAleatorias(List<Aluno> alunosParaGerar) {
    List<Aluno> tempAlunos = List.from(alunosParaGerar);
    tempAlunos.shuffle();
    Aluno? alunoFantasma;
    if (tempAlunos.length % 2 != 0) {
      alunoFantasma = Aluno.novo(nome: "DESCANSA", faixa: "", peso: 0);
      tempAlunos.add(alunoFantasma);
    }
    int numRodadas = tempAlunos.length - 1;
    if (numRodadas <= 0 && tempAlunos.length == 2) numRodadas = 1;
    if (numRodadas <= 0) {
      setState(() {
        _rodadasGeradas = [];
      });
      return;
    }
    List<List<String>> rodadasGeradasTemp = [];
    int halfSize = tempAlunos.length ~/ 2;
    for (int i = 0; i < numRodadas; i++) {
      List<String> rodadaAtual = [];
      for (int j = 0; j < halfSize; j++) {
        Aluno a1 = tempAlunos[j], a2 = tempAlunos[tempAlunos.length - 1 - j];
        if (a1.nome == "DESCANSA")
          rodadaAtual.add('${a2.nome} (descansa)');
        else if (a2.nome == "DESCANSA")
          rodadaAtual.add('${a1.nome} (descansa)');
        else
          rodadaAtual.add('${a1.nome} x ${a2.nome}');
      }
      rodadasGeradasTemp.add(rodadaAtual);
      if (tempAlunos.length > 2) tempAlunos.insert(1, tempAlunos.removeLast());
    }
    setState(() {
      _rodadasGeradas = rodadasGeradasTemp;
    });
  }

  void _gerarRodadasHierarquicas(List<Aluno> alunos, String tipo) {
    List<Aluno> tempAlunos = List.from(alunos);
    List<Luta> todasLutasPossiveis = [];
    for (int i = 0; i < tempAlunos.length; i++) {
      for (int j = i + 1; j < tempAlunos.length; j++) {
        double custo = 0;
        if (tipo == 'Por Peso') {
          custo = (tempAlunos[i].peso - tempAlunos[j].peso).abs();
        } else {
          custo = (_getBeltIndex(tempAlunos[i].faixa) -
                  _getBeltIndex(tempAlunos[j].faixa))
              .abs()
              .toDouble();
          custo += (tempAlunos[i].peso - tempAlunos[j].peso).abs() * 0.01;
        }
        todasLutasPossiveis.add(Luta(tempAlunos[i], tempAlunos[j], custo));
      }
    }
    todasLutasPossiveis.sort((a, b) => a.custo.compareTo(b.custo));
    List<List<String>> rodadasConstruidas = [];
    Set<Set<String>> lutasJaRealizadasGlobal = {};
    int numAlunos = tempAlunos.length;
    int maxRodadasPossiveis = numAlunos - (numAlunos % 2 == 0 ? 1 : 0);
    if (numAlunos <= 1) maxRodadasPossiveis = 0;
    if (numAlunos == 2) maxRodadasPossiveis = 1;

    for (int r = 0; r < maxRodadasPossiveis; r++) {
      List<String> rodadaAtual = [];
      Set<String> alunosNestaRodada = {};
      List<Luta> lutasCandidatasParaRodada = List.from(todasLutasPossiveis);

      lutasCandidatasParaRodada.sort((a, b) {
        Set<String> parA = {a.aluno1.nome, a.aluno2.nome};
        Set<String> parB = {b.aluno1.nome, b.aluno2.nome};
        bool jaFezA = lutasJaRealizadasGlobal
            .any((parFeito) => parFeito.containsAll(parA));
        bool jaFezB = lutasJaRealizadasGlobal
            .any((parFeito) => parFeito.containsAll(parB));
        if (jaFezA && !jaFezB) return 1;
        if (!jaFezA && jaFezB) return -1;
        return a.custo.compareTo(b.custo);
      });

      while (alunosNestaRodada.length < (numAlunos - (numAlunos % 2))) {
        int indexLutaEscolhida = -1;
        for (int k = 0; k < lutasCandidatasParaRodada.length; k++) {
          Luta candidata = lutasCandidatasParaRodada[k];
          Set<String> parAtual = {candidata.aluno1.nome, candidata.aluno2.nome};
          bool jaLutaramGlobalmente = lutasJaRealizadasGlobal
              .any((parFeito) => parFeito.containsAll(parAtual));
          bool disponiveisNestaRodada =
              !alunosNestaRodada.contains(candidata.aluno1.nome) &&
                  !alunosNestaRodada.contains(candidata.aluno2.nome);

          if (disponiveisNestaRodada && !jaLutaramGlobalmente) {
            indexLutaEscolhida = k;
            break;
          }
        }
        if (indexLutaEscolhida == -1 && r > 0) {
          for (int k = 0; k < lutasCandidatasParaRodada.length; k++) {
            Luta candidata = lutasCandidatasParaRodada[k];
            bool disponiveisNestaRodada =
                !alunosNestaRodada.contains(candidata.aluno1.nome) &&
                    !alunosNestaRodada.contains(candidata.aluno2.nome);
            if (disponiveisNestaRodada) {
              indexLutaEscolhida = k;
              break;
            }
          }
        }
        if (indexLutaEscolhida != -1) {
          Luta escolhida = lutasCandidatasParaRodada[indexLutaEscolhida];
          rodadaAtual
              .add('${escolhida.aluno1.nome} x ${escolhida.aluno2.nome}');
          alunosNestaRodada.add(escolhida.aluno1.nome);
          alunosNestaRodada.add(escolhida.aluno2.nome);
          lutasJaRealizadasGlobal
              .add({escolhida.aluno1.nome, escolhida.aluno2.nome});
          lutasCandidatasParaRodada.removeWhere((l) =>
              l.aluno1.nome == escolhida.aluno1.nome ||
              l.aluno2.nome == escolhida.aluno1.nome ||
              l.aluno1.nome == escolhida.aluno2.nome ||
              l.aluno2.nome == escolhida.aluno2.nome);
        } else {
          break;
        }
      }
      if (numAlunos % 2 != 0) {
        Aluno? descansando = tempAlunos
            .firstWhereOrNull((a) => !alunosNestaRodada.contains(a.nome));
        if (descansando != null) {
          rodadaAtual.add('${descansando.nome} (descansa)');
          alunosNestaRodada.add(descansando.nome);
        }
      }
      if (rodadaAtual.isNotEmpty &&
          rodadaAtual.any((luta) => luta.contains('x'))) {
        rodadasConstruidas.add(rodadaAtual);
      } else if (rodadaAtual.isNotEmpty &&
          numAlunos % 2 != 0 &&
          rodadaAtual.length == 1 &&
          rodadaAtual.first.contains('(descansa)')) {
      } else {
        if (lutasJaRealizadasGlobal.length >= todasLutasPossiveis.length &&
            todasLutasPossiveis.isNotEmpty) break;
      }
      if (lutasJaRealizadasGlobal.length >= todasLutasPossiveis.length &&
          todasLutasPossiveis.isNotEmpty) break;
    }
    setState(() {
      _rodadasGeradas = rodadasConstruidas;
    });
  }

  void _gerarRodadasClicado() {
    if (widget.isSparringMode) {
      showBjjSnackBar(
          context, 'Finalize o treino atual antes de gerar novas rodadas.',
          type: 'warning');
      return;
    }
    if (widget.alunos.length < 2) {
      showBjjSnackBar(
          context, 'Selecione pelo menos dois alunos para gerar rodadas.',
          type: 'error');
      setState(() {
        _rodadasGeradas = [];
      });
      return;
    }
    setState(() {
      _rodadasGeradas = [];
    });
    List<Aluno> alunosParaProcessar = List.from(widget.alunos);
    if (_tipoGeracao == 'Aleatório') {
      _gerarRodadasAleatorias(alunosParaProcessar);
    } else {
      _gerarRodadasHierarquicas(alunosParaProcessar, _tipoGeracao);
    }
    if (mounted && _rodadasGeradas.isNotEmpty) {
      showBjjSnackBar(
          context, '${_rodadasGeradas.length} rodadas geradas ($_tipoGeracao)!',
          type: 'success');
    } else if (mounted && widget.alunos.length >= 2) {
      showBjjSnackBar(context,
          'Não foi possível gerar mais rodadas inéditas com o critério e alunos selecionados ou nenhuma combinação é possível.',
          type: 'warning');
    }
  }

  void _iniciarSparringClicado() {
    if (widget.isSparringMode) {
      showBjjSnackBar(
          context, 'Já existe um treino em andamento. Finalize-o primeiro.',
          type: 'warning');
      return;
    }
    if (_rodadasGeradas.isEmpty) {
      showBjjSnackBar(
          context, 'Gere as rodadas primeiro antes de iniciar o treino.',
          type: 'error');
      return;
    }

    showDialog<List<Aluno>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CheckinDialog(participantes: widget.alunos),
    ).then((alunosParaCheckin) {
      if (alunosParaCheckin != null && alunosParaCheckin.isNotEmpty) {
        widget.onCheckinAlunos(alunosParaCheckin);
      }
      widget.onIniciarSparring(_rodadasGeradas, _tipoGeracao);
    });
  }

  Widget _buildStepCard(BuildContext context,
      {required int step, required String title, required Widget child}) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$step. $title',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                  color: BjjApp.primaryAccent, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12.0),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ButtonStyle buttonStyle = ElevatedButton.styleFrom(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 18),
      textStyle: TextStyle(
          fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Roboto'),
    );
    final ButtonStyle disabledButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.grey[700],
      foregroundColor: Colors.grey[400],
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 18),
      textStyle: TextStyle(
          fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Roboto'),
    );

    return AppBackground(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStepCard(
                context,
                step: 1,
                title: 'Selecione os Alunos (${widget.alunos.length})',
                child: ElevatedButton.icon(
                    icon: Icon(Icons.group_add_outlined, size: 18),
                    onPressed: widget.isSparringMode
                        ? null
                        : widget.onSelecionarParticipantes,
                    label: const Text('Selecionar Alunos'),
                    style: widget.isSparringMode
                        ? disabledButtonStyle
                        : buttonStyle),
              ),
              _buildStepCard(
                context,
                step: 2,
                title: 'Defina e Gere as Lutas',
                child: Column(children: [
                  DropdownButtonFormField<String>(
                    value: _tipoGeracao,
                    decoration: InputDecoration(
                        labelText: 'Tipo de Sorteio',
                        prefixIcon: Icon(Icons.sort_rounded,
                            size: 20, color: BjjApp.textHint.withOpacity(0.8))),
                    items: _opcoesGeracao.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: widget.isSparringMode
                        ? null
                        : (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _tipoGeracao = newValue;
                                _rodadasGeradas = [];
                              });
                            }
                          },
                  ),
                  const SizedBox(height: 12.0),
                  ElevatedButton.icon(
                      icon: Icon(Icons.shuffle_outlined, size: 18),
                      onPressed:
                          widget.isSparringMode || widget.alunos.length < 2
                              ? null
                              : _gerarRodadasClicado,
                      label: const Text('Gerar Rodadas'),
                      style: widget.isSparringMode || widget.alunos.length < 2
                          ? disabledButtonStyle
                          : buttonStyle),
                ]),
              ),
              _buildStepCard(
                context,
                step: 3,
                title: 'Inicie o Treino',
                child: ElevatedButton.icon(
                    icon: Icon(Icons.play_circle_outline_rounded, size: 18),
                    onPressed: widget.isSparringMode || _rodadasGeradas.isEmpty
                        ? null
                        : _iniciarSparringClicado,
                    label: const Text('Iniciar Treino'),
                    style: (widget.isSparringMode || _rodadasGeradas.isEmpty)
                        ? disabledButtonStyle
                        : buttonStyle.copyWith(
                            backgroundColor:
                                MaterialStateProperty.all(BjjApp.successColor),
                            foregroundColor:
                                MaterialStateProperty.all(BjjApp.textPrimary),
                          )),
              ),
              const SizedBox(height: 15.0),
              Text(
                  widget.isSparringMode
                      ? 'Treino em andamento!'
                      : widget.alunos.isEmpty
                          ? 'Nenhum aluno selecionado para o treino.'
                          : _rodadasGeradas.isEmpty
                              ? '${widget.alunos.length} alunos selecionados. Gere as rodadas.'
                              : '${_rodadasGeradas.length} rodadas prontas para iniciar!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: BjjApp.textHint.withOpacity(0.9),
                      fontStyle: FontStyle.italic)),
            ],
          ),
        ),
      ),
    );
  }
}

class CheckinDialog extends StatefulWidget {
  final List<Aluno> participantes;
  const CheckinDialog({Key? key, required this.participantes})
      : super(key: key);
  @override
  State<CheckinDialog> createState() => _CheckinDialogState();
}

class _CheckinDialogState extends State<CheckinDialog> {
  late Set<Aluno> _alunosSelecionados;

  @override
  void initState() {
    super.initState();
    _alunosSelecionados = Set<Aluno>.from(widget.participantes);
  }

  void _toggleSelectAll() {
    setState(() {
      if (_alunosSelecionados.length == widget.participantes.length) {
        _alunosSelecionados.clear();
      } else {
        _alunosSelecionados = Set<Aluno>.from(widget.participantes);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Check-in do Treino'),
      content: Container(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Selecione os alunos para fazer o check-in de hoje:',
                style: Theme.of(context).textTheme.bodyMedium),
            SizedBox(height: 8),
            TextButton.icon(
              icon: Icon(
                _alunosSelecionados.length == widget.participantes.length
                    ? Icons.check_box_outlined
                    : Icons.check_box_outline_blank_rounded,
                size: 20,
              ),
              label: Text(
                _alunosSelecionados.length == widget.participantes.length
                    ? 'Desmarcar Todos'
                    : 'Marcar Todos',
              ),
              onPressed: _toggleSelectAll,
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
            ),
            Divider(),
            SizedBox(height: 8),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: widget.participantes.map((aluno) {
                    final isSelected = _alunosSelecionados.contains(aluno);
                    return CheckboxListTile(
                      title: Text(aluno.nome, style: TextStyle(fontSize: 15)),
                      value: isSelected,
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            _alunosSelecionados.add(aluno);
                          } else {
                            _alunosSelecionados.remove(aluno);
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 4),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Pular'),
          onPressed: () {
            Navigator.of(context).pop(<Aluno>[]);
          },
        ),
        ElevatedButton(
          child: Text('Confirmar (${_alunosSelecionados.length})'),
          style: ElevatedButton.styleFrom(backgroundColor: BjjApp.successColor),
          onPressed: () {
            Navigator.of(context).pop(_alunosSelecionados.toList());
          },
        ),
      ],
    );
  }
}

class SparringPage extends StatelessWidget {
  final List<Aluno> alunosParticipantes;
  final String tipoGeracao;
  final List<List<String>> todasAsRodadas;
  final int indiceRodadaAtual;
  final bool isSparringMode;
  final VoidCallback onProximaRodada;
  final VoidCallback onFinalizarSparring;
  SparringPage(
      {required this.alunosParticipantes,
      required this.tipoGeracao,
      required this.todasAsRodadas,
      required this.indiceRodadaAtual,
      required this.isSparringMode,
      required this.onProximaRodada,
      required this.onFinalizarSparring});

  Aluno? _findAlunoByName(String name) {
    try {
      return alunosParticipantes.firstWhere(
          (a) => a.nome.trim().toLowerCase() == name.trim().toLowerCase(),
          orElse: () => Aluno.novo(nome: name, faixa: 'Desconhecida', peso: 0));
    } catch (e) {
      return Aluno.novo(nome: name, faixa: 'Desconhecida', peso: 0);
    }
  }

  Color _getBeltColor(String faixa) {
    final fLower = faixa.toLowerCase();
    if (fLower.contains('cinza')) return Colors.grey;
    if (fLower.contains('amarela')) return Colors.yellow.shade700;
    if (fLower.contains('laranja')) return Colors.orange.shade700;
    if (fLower.contains('verde')) return Colors.green.shade700;
    switch (fLower) {
      case 'branca':
        return Colors.white;
      case 'azul':
        return Colors.blue.shade300;
      case 'roxa':
        return Colors.purple.shade300;
      case 'marrom':
        return Colors.brown.shade300;
      case 'preta':
        return Colors.grey.shade800;
      default:
        return Colors.grey.shade500;
    }
  }

  Widget _buildParticipantInfo(Aluno aluno, BuildContext context) {
    final theme = Theme.of(context);
    final beltColor = _getBeltColor(aluno.faixa);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 6.0),
          child: Icon(Icons.shield_outlined, color: beltColor, size: 18),
        ),
        Flexible(
          child: Text(
            aluno.nome,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
              fontSize: 17,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            softWrap: false,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: Text(
            "(${aluno.peso}kg)",
            style: TextStyle(
              fontSize: (theme.textTheme.bodySmall?.fontSize ?? 12),
              color: BjjApp.textHint.withOpacity(0.80),
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ButtonStyle buttonStyle = ElevatedButton.styleFrom(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 18),
      textStyle: TextStyle(
          fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Roboto'),
    );
    final ButtonStyle disabledButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.grey[700],
      foregroundColor: Colors.grey[400],
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 18),
      textStyle: TextStyle(
          fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Roboto'),
    );
    return AppBackground(
      child: Builder(builder: (context) {
        if (!isSparringMode)
          return EmptyStateWidget(
              icon: Icons.pause_circle_outline_rounded,
              title: 'Nenhum treino em andamento.',
              message:
                  'Vá para a aba "Sorteio" para configurar e iniciar um novo treino.');
        if (todasAsRodadas.isEmpty && isSparringMode)
          return EmptyStateWidget(
              icon: Icons.error_outline_rounded,
              title: 'Erro nas Rodadas do Treino',
              message:
                  'Não foi possível carregar as rodadas. Tente finalizar o treino atual e iniciar novamente.');

        List<String> duplasDaRodadaAtualStrings = [];
        String tituloRodada = '';
        bool fimSparring = indiceRodadaAtual > todasAsRodadas.length;

        if (isSparringMode && todasAsRodadas.isNotEmpty) {
          if (fimSparring) {
            duplasDaRodadaAtualStrings = todasAsRodadas.last;
            tituloRodada =
                'FIM DO TREINO - Última Rodada (${todasAsRodadas.length}/${todasAsRodadas.length})';
          } else if (indiceRodadaAtual > 0) {
            duplasDaRodadaAtualStrings = todasAsRodadas[indiceRodadaAtual - 1];
            tituloRodada =
                'Rodada $indiceRodadaAtual / ${todasAsRodadas.length}';
          } else {
            return EmptyStateWidget(
                icon: Icons.hourglass_empty_rounded,
                title: 'Preparando treino...',
                message: 'Aguarde um momento.');
          }
        } else if (isSparringMode && todasAsRodadas.isEmpty) {
          return EmptyStateWidget(
              icon: Icons.error_outline_rounded,
              title: 'Nenhuma Rodada Encontrada',
              message:
                  'Parece que não há rodadas para este treino. Tente finalizar e gerar novamente.');
        }

        return Column(children: [
          Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
              child: Text(tituloRodada,
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 24))),
          Expanded(
              child: duplasDaRodadaAtualStrings.isEmpty && isSparringMode
                  ? Center(
                      child: Text("Carregando rodada...",
                          style: TextStyle(color: BjjApp.textHint)))
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      itemCount: duplasDaRodadaAtualStrings.length,
                      itemBuilder: (context, index) {
                        final matchText = duplasDaRodadaAtualStrings[index];
                        Widget matchContent;

                        if (matchText.contains(" (descansa)")) {
                          String nome = matchText
                              .substring(0, matchText.indexOf(" (descansa)"))
                              .trim();
                          Aluno? aluno = _findAlunoByName(nome);
                          matchContent = Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (aluno != null)
                                _buildParticipantInfo(aluno, context),
                              Text(
                                " (descansa)",
                                style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: BjjApp.infoColor,
                                    fontSize:
                                        (theme.textTheme.bodySmall?.fontSize ??
                                            12)),
                              )
                            ],
                          );
                        } else if (matchText.contains(" x ")) {
                          List<String> nomes = matchText.split(" x ");
                          Aluno? aluno1 = _findAlunoByName(nomes[0].trim());
                          Aluno? aluno2 = _findAlunoByName(nomes[1].trim());

                          matchContent = Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (aluno1 != null)
                                Expanded(
                                    child:
                                        _buildParticipantInfo(aluno1, context)),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  "x",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: BjjApp.primaryAccent,
                                    fontSize:
                                        theme.textTheme.titleMedium?.fontSize,
                                  ),
                                ),
                              ),
                              if (aluno2 != null)
                                Expanded(
                                    child:
                                        _buildParticipantInfo(aluno2, context)),
                            ],
                          );
                        } else {
                          matchContent = Text(matchText,
                              style: theme.textTheme.titleMedium);
                        }

                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            side: BorderSide(
                                color: BjjApp.primaryAccent, width: 1.5),
                          ),
                          margin: EdgeInsets.symmetric(vertical: 8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 20.0, horizontal: 12.0),
                            child: Center(
                              child: matchContent,
                            ),
                          ),
                        );
                      })),
          Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    ElevatedButton.icon(
                        icon: Icon(Icons.skip_next_rounded, size: 18),
                        onPressed: fimSparring ? null : onProximaRodada,
                        label: const Text('Próxima'),
                        style: (fimSparring ? disabledButtonStyle : buttonStyle)
                            .copyWith(
                                padding: MaterialStateProperty.all(
                                    EdgeInsets.symmetric(
                                        vertical: 12, horizontal: 28)))),
                    ElevatedButton.icon(
                        icon: Icon(Icons.stop_circle_rounded, size: 18),
                        onPressed: onFinalizarSparring,
                        label: const Text('Finalizar'),
                        style: buttonStyle.copyWith(
                            backgroundColor: MaterialStateProperty.all(
                                BjjApp.errorColor.withOpacity(0.9)),
                            foregroundColor:
                                MaterialStateProperty.all(BjjApp.textPrimary),
                            padding: MaterialStateProperty.all(
                                EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 28)))),
                  ]))
        ]);
      }),
    );
  }
}

class AlunosPage extends StatefulWidget {
  final List<Aluno> alunos;
  final Function(Aluno) onAlunoRemovido;
  final Function(Aluno, Aluno) onAlunoEditado;
  AlunosPage(
      {required this.alunos,
      required this.onAlunoRemovido,
      required this.onAlunoEditado});
  @override
  _AlunosPageState createState() => _AlunosPageState();
}

class _AlunosPageState extends State<AlunosPage>
    with SingleTickerProviderStateMixin {
  late List<Aluno> _alunosFiltrados;
  TextEditingController _searchController = TextEditingController();
  String _currentSortOrder = 'nome';

  @override
  void initState() {
    super.initState();
    _alunosFiltrados = List.from(widget.alunos);
    _searchController.addListener(_filterAndSortAlunos);
    _sortAlunos();
  }

  @override
  void didUpdateWidget(covariant AlunosPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!ListEquality().equals(widget.alunos, oldWidget.alunos)) {
      _filterAndSortAlunos();
    } else {
      _filterAndSortAlunos();
    }
  }

  void _filterAndSortAlunos() {
    String query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _alunosFiltrados = List.from(widget.alunos);
      } else {
        _alunosFiltrados = widget.alunos
            .where((aluno) =>
                aluno.nome.toLowerCase().contains(query) ||
                aluno.faixa.toLowerCase().contains(query))
            .toList();
      }
      _sortAlunos();
    });
  }

  int _getBeltIndex(String faixa) {
    const List<String> ordemFaixas = [
      'Preta',
      'Marrom',
      'Roxa',
      'Azul',
      'Verde com Ponta Preta',
      'Verde',
      'Verde com Ponta Branca',
      'Laranja com Ponta Preta',
      'Laranja',
      'Laranja com Ponta Branca',
      'Amarela com Ponta Preta',
      'Amarela',
      'Amarela com Ponta Branca',
      'Cinza com Ponta Preta',
      'Cinza',
      'Cinza com Ponta Branca',
      'Branca'
    ];
    int index = ordemFaixas.indexOf(faixa.capitalizeFirst());
    return index == -1 ? ordemFaixas.length : index;
  }

  void _sortAlunos() {
    _alunosFiltrados.sort((a, b) {
      switch (_currentSortOrder) {
        case 'faixa':
          int beltComparison =
              _getBeltIndex(a.faixa).compareTo(_getBeltIndex(b.faixa));
          if (beltComparison != 0) return beltComparison;
          return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
        case 'peso':
          int weightComparison = b.peso.compareTo(a.peso);
          if (weightComparison != 0) return weightComparison;
          return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
        case 'nome':
        default:
          return a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterAndSortAlunos);
    _searchController.dispose();
    super.dispose();
  }

  Color _getCorFaixa(String f) {
    final fLower = f.toLowerCase();
    if (fLower.contains('cinza')) return Colors.grey;
    if (fLower.contains('amarela')) return Colors.yellow.shade700;
    if (fLower.contains('laranja')) return Colors.orange.shade700;
    if (fLower.contains('verde')) return Colors.green.shade700;

    switch (fLower) {
      case 'branca':
        return Colors.white;
      case 'azul':
        return Colors.blue.shade300;
      case 'roxa':
        return Colors.purple.shade300;
      case 'marrom':
        return Colors.brown.shade300;
      case 'preta':
        return Colors.grey.shade800;
      default:
        return Colors.grey.shade500;
    }
  }

  Color _getCorTextoInicialAvatar(String f) {
    final c = _getCorFaixa(f);
    return c.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppBackground(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar aluno por nome ou faixa...',
                prefixIcon: Icon(Icons.search_rounded,
                    color: BjjApp.textHint.withOpacity(0.8)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded,
                            color: BjjApp.textHint.withOpacity(0.8)),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(
                    value: 'nome',
                    label: Text('A-Z'),
                    icon: Icon(Icons.sort_by_alpha_rounded)),
                ButtonSegment<String>(
                    value: 'faixa',
                    label: Text('Faixa'),
                    icon: Icon(Icons.shield_outlined)),
                ButtonSegment<String>(
                    value: 'peso',
                    label: Text('Peso'),
                    icon: Icon(Icons.fitness_center_rounded)),
              ],
              selected: {_currentSortOrder},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() {
                  _currentSortOrder = newSelection.first;
                  _sortAlunos();
                });
              },
              style: Theme.of(context).segmentedButtonTheme.style,
            ),
          ),
          Expanded(
            child: Builder(builder: (context) {
              if (widget.alunos.isEmpty)
                return EmptyStateWidget(
                    icon: Icons.no_accounts_rounded,
                    title: 'Nenhum Aluno Cadastrado',
                    message:
                        'Clique no botão "+" para adicionar o primeiro aluno.');
              if (_alunosFiltrados.isEmpty && _searchController.text.isNotEmpty)
                return EmptyStateWidget(
                    icon: Icons.search_off_rounded,
                    title: 'Nenhum Aluno Encontrado',
                    message: 'Tente buscar por outro nome ou faixa.');

              return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8.0, 0.0, 8.0, 80.0),
                  itemCount: _alunosFiltrados.length,
                  itemBuilder: (context, index) {
                    final a = _alunosFiltrados[index];
                    final corFaixaAvatar = _getCorFaixa(a.faixa);
                    final corTextoAvatar = _getCorTextoInicialAvatar(a.faixa);
                    String g = '';
                    if (a.graus != null && a.graus! > 0) {
                      g = ' (${a.graus}º grau)';
                    }
                    return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                            onTap: () {
                              _mostrarDialogoEdicao(context, a);
                            },
                            child: ListTile(
                                leading: CircleAvatar(
                                    backgroundColor: corFaixaAvatar,
                                    child: Text(
                                        a.nome.isNotEmpty
                                            ? a.nome[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                            color: corTextoAvatar,
                                            fontWeight: FontWeight.bold))),
                                title: Text(a.nome,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontSize: 17)),
                                subtitle: Text(
                                    'Faixa: ${a.faixa}$g - Peso: ${a.peso}kg',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                        color: BjjApp.textSecondary
                                            .withOpacity(0.85))),
                                trailing: PopupMenuButton<String>(
                                    icon: Icon(Icons.more_vert_rounded,
                                        color:
                                            BjjApp.textHint.withOpacity(0.9)),
                                    onSelected: (v) {
                                      if (v == 'editar')
                                        _mostrarDialogoEdicao(context, a);
                                      else if (v == 'excluir')
                                        _mostrarDialogoExclusao(context, a);
                                    },
                                    itemBuilder: (c) => [
                                          PopupMenuItem<String>(
                                              value: 'editar',
                                              child: ListTile(
                                                  leading: Icon(
                                                      Icons.edit_note_rounded,
                                                      color:
                                                          BjjApp.primaryAccent),
                                                  title: Text('Editar'))),
                                          PopupMenuItem<String>(
                                              value: 'excluir',
                                              child: ListTile(
                                                  leading: Icon(
                                                      Icons
                                                          .delete_sweep_rounded,
                                                      color: BjjApp.errorColor),
                                                  title: Text('Excluir')))
                                        ]))));
                  });
            }),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoEdicao(BuildContext context, Aluno alunoAntigo) {
    final _nomeController = TextEditingController(text: alunoAntigo.nome);
    final _pesoController =
        TextEditingController(text: alunoAntigo.peso.toString());
    String? _faixaSelecionada =
        alunoAntigo.faixa.isEmpty ? null : alunoAntigo.faixa;
    int? _grauSelecionado = alunoAntigo.graus;
    final List<String> _faixas = [
      'Branca',
      'Cinza com Ponta Branca',
      'Cinza',
      'Cinza com Ponta Preta',
      'Amarela com Ponta Branca',
      'Amarela',
      'Amarela com Ponta Preta',
      'Laranja com Ponta Branca',
      'Laranja',
      'Laranja com Ponta Preta',
      'Verde com Ponta Branca',
      'Verde',
      'Verde com Ponta Preta',
      'Azul',
      'Roxa',
      'Marrom',
      'Preta'
    ];
    final List<int> _opcoesGraus = [1, 2, 3, 4, 5, 6];
    final _formKey = GlobalKey<FormState>();

    showDialog(
        context: context,
        builder: (BuildContext context) {
          return StatefulBuilder(builder: (context, setDialogState) {
            bool mostrarGraus = _faixaSelecionada != null;
            return AlertDialog(
              title: const Text('Editar Aluno'),
              content: SingleChildScrollView(
                  child: Form(
                      key: _formKey,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        TextFormField(
                            controller: _nomeController,
                            decoration: InputDecoration(
                                labelText: 'Nome',
                                prefixIcon: Icon(Icons.person_outline_rounded)),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Nome inválido'
                                : null),
                        const SizedBox(height: 16.0),
                        DropdownButtonFormField<String>(
                            value: _faixaSelecionada,
                            decoration: InputDecoration(
                                labelText: 'Faixa',
                                prefixIcon: Icon(Icons.shield_outlined)),
                            hint: Text("Selecione a Faixa"),
                            onChanged: (String? v) => setDialogState(() {
                                  _faixaSelecionada = v;
                                }),
                            items: _faixas
                                .map((v) => DropdownMenuItem<String>(
                                    value: v, child: Text(v)))
                                .toList(),
                            validator: (v) =>
                                v == null ? 'Selecione uma faixa' : null),
                        if (mostrarGraus) ...[
                          const SizedBox(height: 16.0),
                          DropdownButtonFormField<int>(
                              value: _grauSelecionado,
                              decoration: InputDecoration(
                                  labelText: 'Graus (opcional)',
                                  prefixIcon: Icon(Icons.star_border_rounded)),
                              hint: Text("Graus (opcional)"),
                              onChanged: (int? v) =>
                                  setDialogState(() => _grauSelecionado = v),
                              items: [
                                DropdownMenuItem<int>(
                                    value: null, child: Text("Nenhum")),
                                ..._opcoesGraus.map((v) =>
                                    DropdownMenuItem<int>(
                                        value: v, child: Text('$vº Grau')))
                              ].toList())
                        ],
                        const SizedBox(height: 16.0),
                        TextFormField(
                            controller: _pesoController,
                            decoration: InputDecoration(
                                labelText: 'Peso (kg)',
                                prefixIcon: Icon(Icons.fitness_center_rounded)),
                            keyboardType:
                                TextInputType.numberWithOptions(decimal: true),
                            validator: (v) {
                              if (v == null || v.isEmpty)
                                return 'Peso inválido';
                              final x = double.tryParse(v.replaceAll(',', '.'));
                              return (x == null || x <= 0)
                                  ? 'Peso inválido (deve ser > 0)'
                                  : null;
                            }),
                      ]))),
              actions: <Widget>[
                TextButton(
                    child: const Text('Cancelar'),
                    onPressed: () => Navigator.of(context).pop()),
                ElevatedButton.icon(
                    icon: Icon(Icons.save_alt_rounded, size: 18),
                    label: const Text('Salvar'),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        widget.onAlunoEditado(
                            alunoAntigo,
                            Aluno.novo(
                                nome: _nomeController.text.trim(),
                                faixa: _faixaSelecionada!,
                                peso: double.parse(
                                    _pesoController.text.replaceAll(',', '.')),
                                graus: _grauSelecionado));
                        Navigator.of(context).pop();
                      }
                    })
              ],
            );
          });
        });
  }

  void _mostrarDialogoExclusao(BuildContext context, Aluno aluno) {
    showDialog(
        context: context,
        builder: (c) => AlertDialog(
                title: Text('Excluir Aluno'),
                content: Text(
                    'Deseja realmente excluir ${aluno.nome}? Esta ação não pode ser desfeita.'),
                actions: [
                  TextButton(
                      child: Text('Cancelar'),
                      onPressed: () => Navigator.of(c).pop()),
                  ElevatedButton.icon(
                      icon: Icon(Icons.delete_forever_rounded, size: 18),
                      label: Text('Excluir'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: BjjApp.errorColor,
                          foregroundColor: BjjApp.textPrimary),
                      onPressed: () {
                        widget.onAlunoRemovido(aluno);
                        Navigator.of(c).pop();
                      })
                ]));
  }
}

class AdicionarAlunoDialog extends StatefulWidget {
  final Function(Aluno) onAlunoAdicionado;
  AdicionarAlunoDialog({required this.onAlunoAdicionado});
  @override
  _AdicionarAlunoDialogState createState() => _AdicionarAlunoDialogState();
}

class _AdicionarAlunoDialogState extends State<AdicionarAlunoDialog> {
  final nC = TextEditingController(), pC = TextEditingController();
  String? fS;
  int? gS;
  final List<String> faixasList = [
    'Branca',
    'Cinza com Ponta Branca',
    'Cinza',
    'Cinza com Ponta Preta',
    'Amarela com Ponta Branca',
    'Amarela',
    'Amarela com Ponta Preta',
    'Laranja com Ponta Branca',
    'Laranja',
    'Laranja com Ponta Preta',
    'Verde com Ponta Branca',
    'Verde',
    'Verde com Ponta Preta',
    'Azul',
    'Roxa',
    'Marrom',
    'Preta'
  ];
  final List<int> grausList = [1, 2, 3, 4, 5, 6];
  final formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    bool mostrarGrausDropdown = fS != null;
    return AlertDialog(
      title: Text('Adicionar Novo Aluno'),
      content: SingleChildScrollView(
          child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                    controller: nC,
                    decoration: InputDecoration(
                        labelText: 'Nome',
                        prefixIcon: Icon(Icons.person_add_alt_1_rounded)),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Nome inválido'
                        : null),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                    value: fS,
                    isExpanded: true,
                    decoration: InputDecoration(
                        labelText: 'Faixa',
                        prefixIcon: Icon(Icons.shield_outlined)),
                    hint: Text("Selecione a Faixa"),
                    onChanged: (v) => setState(() {
                          fS = v;
                        }),
                    items: faixasList
                        .map((v) =>
                            DropdownMenuItem<String>(value: v, child: Text(v)))
                        .toList(),
                    validator: (v) => v == null ? 'Selecione uma faixa' : null),
                if (mostrarGrausDropdown) ...[
                  SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                      value: gS,
                      decoration: InputDecoration(
                          labelText: 'Graus (opcional)',
                          prefixIcon: Icon(Icons.star_outline_rounded)),
                      hint: Text("Graus (opcional)"),
                      onChanged: (v) => setState(() => gS = v),
                      items: [
                        DropdownMenuItem<int>(
                            value: null, child: Text("Nenhum")),
                        ...grausList.map((v) => DropdownMenuItem<int>(
                            value: v, child: Text('$vº Grau')))
                      ].toList())
                ],
                SizedBox(height: 16),
                TextFormField(
                    controller: pC,
                    decoration: InputDecoration(
                        labelText: 'Peso (kg)',
                        prefixIcon: Icon(Icons.fitness_center_rounded)),
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Peso inválido';
                      final x = double.tryParse(v.replaceAll(',', '.'));
                      return (x == null || x <= 0)
                          ? 'Peso inválido (deve ser > 0)'
                          : null;
                    }),
              ]))),
      actions: [
        TextButton(
            child: Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop()),
        ElevatedButton.icon(
            icon: Icon(Icons.person_add_rounded, size: 18),
            label: Text('Adicionar'),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                widget.onAlunoAdicionado(Aluno.novo(
                  nome: nC.text.trim(),
                  faixa: fS!,
                  peso: double.parse(pC.text.replaceAll(',', '.')),
                  graus: gS,
                ));
                Navigator.of(context).pop();
              }
            })
      ],
    );
  }
}

class SelecaoAlunosPage extends StatefulWidget {
  final List<Aluno> todosOsAlunos;
  final List<Aluno> alunosSelecionadosIniciais;
  SelecaoAlunosPage(
      {required this.todosOsAlunos, required this.alunosSelecionadosIniciais});
  @override
  _SelecaoAlunosPageState createState() => _SelecaoAlunosPageState();
}

class _SelecaoAlunosPageState extends State<SelecaoAlunosPage> {
  late Set<Aluno> _alunosAtuaisSelecionados;
  TextEditingController _searchController = TextEditingController();
  List<Aluno> _alunosFiltradosParaSelecao = [];

  @override
  void initState() {
    super.initState();
    _alunosAtuaisSelecionados =
        Set<Aluno>.from(widget.alunosSelecionadosIniciais);
    _alunosFiltradosParaSelecao = List.from(widget.todosOsAlunos);
    _searchController.addListener(_filtrarAlunosParaSelecao);
  }

  void _filtrarAlunosParaSelecao() {
    String query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _alunosFiltradosParaSelecao = List.from(widget.todosOsAlunos);
      } else {
        _alunosFiltradosParaSelecao = widget.todosOsAlunos
            .where((aluno) =>
                aluno.nome.toLowerCase().contains(query) ||
                aluno.faixa.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_filtrarAlunosParaSelecao);
    _searchController.dispose();
    super.dispose();
  }

  Color _getCorFaixa(String f) {
    final fLower = f.toLowerCase();
    if (fLower.contains('cinza')) return Colors.grey;
    if (fLower.contains('amarela')) return Colors.yellow.shade700;
    if (fLower.contains('laranja')) return Colors.orange.shade700;
    if (fLower.contains('verde')) return Colors.green.shade700;

    switch (fLower) {
      case 'branca':
        return Colors.white;
      case 'azul':
        return Colors.blue.shade300;
      case 'roxa':
        return Colors.purple.shade300;
      case 'marrom':
        return Colors.brown.shade300;
      case 'preta':
        return Colors.grey.shade800;
      default:
        return Colors.grey.shade500;
    }
  }

  Color _getCorTextoInicialAvatar(String f) {
    final c = _getCorFaixa(f);
    return c.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  void _selecionarTodosFiltrados() {
    setState(() {
      for (var aluno in _alunosFiltradosParaSelecao) {
        _alunosAtuaisSelecionados.add(aluno);
      }
    });
  }

  void _desmarcarTodosFiltrados() {
    setState(() {
      for (var aluno in _alunosFiltradosParaSelecao) {
        _alunosAtuaisSelecionados.remove(aluno);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Selecionar Alunos para o Treino')),
      body: AppBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar aluno...',
                  prefixIcon: Icon(Icons.search_rounded,
                      color: BjjApp.textHint.withOpacity(0.8)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded,
                              color: BjjApp.textHint.withOpacity(0.8)),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    icon: Icon(Icons.check_box_outlined, size: 20),
                    label: Text(
                        'Marcar Visíveis (${_alunosFiltradosParaSelecao.length})'),
                    onPressed: _alunosFiltradosParaSelecao.isNotEmpty
                        ? _selecionarTodosFiltrados
                        : null,
                    style: TextButton.styleFrom(
                        foregroundColor: BjjApp.successColor),
                  ),
                  TextButton.icon(
                    icon: Icon(Icons.disabled_by_default_outlined, size: 20),
                    label: Text('Desmarcar Visíveis'),
                    onPressed: _alunosFiltradosParaSelecao.isNotEmpty
                        ? _desmarcarTodosFiltrados
                        : null,
                    style: TextButton.styleFrom(
                        foregroundColor: BjjApp.warningColor),
                  ),
                ],
              ),
            ),
            Expanded(
              child: widget.todosOsAlunos.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.person_search_rounded,
                      title: 'Nenhum Aluno Cadastrado',
                      message: 'Adicione alunos na aba "Alunos" primeiro.')
                  : _alunosFiltradosParaSelecao.isEmpty &&
                          _searchController.text.isNotEmpty
                      ? EmptyStateWidget(
                          icon: Icons.search_off_rounded,
                          title: 'Nenhum Aluno Encontrado na Busca')
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 80),
                          itemCount: _alunosFiltradosParaSelecao.length,
                          itemBuilder: (context, index) {
                            final a = _alunosFiltradosParaSelecao[index];
                            final s = _alunosAtuaisSelecionados.contains(a);
                            final corFaixaAvatar = _getCorFaixa(a.faixa);
                            final corTextoAvatar =
                                _getCorTextoInicialAvatar(a.faixa);
                            String g = '';
                            if (a.graus != null && a.graus! > 0) {
                              g = ' (${a.graus}º grau)';
                            }
                            return Card(
                              elevation: s ? 4 : 1.5,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                side: s
                                    ? BorderSide(
                                        color: BjjApp.primaryAccent, width: 1.5)
                                    : BorderSide.none,
                              ),
                              child: CheckboxListTile(
                                title: Text(a.nome,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                            color: s
                                                ? BjjApp.primaryAccent
                                                : BjjApp.textPrimary
                                                    .withOpacity(0.95))),
                                subtitle: Text(
                                    'Faixa: ${a.faixa}$g - Peso: ${a.peso}kg',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                        color: BjjApp.textSecondary
                                            .withOpacity(s ? 0.9 : 0.75))),
                                value: s,
                                onChanged: (v) => setState(() {
                                  if (v == true)
                                    _alunosAtuaisSelecionados.add(a);
                                  else
                                    _alunosAtuaisSelecionados.remove(a);
                                }),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                secondary: CircleAvatar(
                                    backgroundColor: corFaixaAvatar,
                                    child: Text(
                                        a.nome.isNotEmpty
                                            ? a.nome[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                            color: corTextoAvatar,
                                            fontWeight: FontWeight.bold))),
                                tileColor: s
                                    ? BjjApp.darkSurface.withOpacity(0.6)
                                    : Colors.transparent,
                              ),
                            );
                          }),
            ),
          ],
        ),
      ),
      floatingActionButton: widget.todosOsAlunos.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () =>
                  Navigator.of(context).pop(_alunosAtuaisSelecionados.toList()),
              label: Text('Confirmar (${_alunosAtuaisSelecionados.length})'),
              icon: const Icon(Icons.check_circle_outline_rounded))
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  const EmptyStateWidget({
    Key? key,
    required this.icon,
    required this.title,
    this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: BjjApp.textHint.withOpacity(0.5), size: 60),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: BjjApp.textPrimary.withOpacity(0.75),
                fontWeight: FontWeight.w600,
                fontSize: 17,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: BjjApp.textHint.withOpacity(0.65),
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MatchSetupPage extends StatefulWidget {
  final List<Aluno> todosAlunos;
  const MatchSetupPage({Key? key, required this.todosAlunos}) : super(key: key);
  @override
  _MatchSetupPageState createState() => _MatchSetupPageState();
}

class _MatchSetupPageState extends State<MatchSetupPage> {
  Aluno? _selectedAluno1;
  Aluno? _selectedAluno2;
  String _kimonoColor1 = 'Branco';
  String _kimonoColor2 = 'Azul';
  Duration _fightDuration = Duration(minutes: 5);
  final List<String> _kimonoOptions = ['Branco', 'Azul', 'Preto'];

  void _validateAndStartMatch() {
    if (_selectedAluno1 == null || _selectedAluno2 == null) {
      showBjjSnackBar(context, 'Selecione os dois atletas para continuar.',
          type: 'warning');
      return;
    }
    if (_selectedAluno1 == _selectedAluno2) {
      showBjjSnackBar(context, 'Os atletas devem ser diferentes.',
          type: 'warning');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ScoreboardPage(
          aluno1: _selectedAluno1!,
          aluno2: _selectedAluno2!,
          kimonoColor1: _kimonoColor1,
          kimonoColor2: _kimonoColor2,
          initialTime: _fightDuration,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configurar Luta Individual'),
      ),
      body: AppBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildAthleteSetupCard(
                playerNumber: 1,
                title: 'Atleta 1 (Esquerda)',
                selectedAluno: _selectedAluno1,
                onAlunoChanged: (aluno) {
                  setState(() {
                    _selectedAluno1 = aluno;
                  });
                },
                kimonoColor: _kimonoColor1,
                onKimonoChanged: (color) {
                  if (color != null) {
                    setState(() {
                      _kimonoColor1 = color;
                    });
                  }
                },
              ),
              SizedBox(height: 16),
              _buildAthleteSetupCard(
                playerNumber: 2,
                title: 'Atleta 2 (Direita)',
                selectedAluno: _selectedAluno2,
                onAlunoChanged: (aluno) {
                  setState(() {
                    _selectedAluno2 = aluno;
                  });
                },
                kimonoColor: _kimonoColor2,
                onKimonoChanged: (color) {
                  if (color != null) {
                    setState(() {
                      _kimonoColor2 = color;
                    });
                  }
                },
              ),
              SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DropdownButtonFormField<Duration>(
                    value: _fightDuration,
                    items: List.generate(10, (index) => index + 1)
                        .map((min) => DropdownMenuItem(
                              value: Duration(minutes: min),
                              child: Text('$min minutos'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _fightDuration = value;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      labelText: 'Tempo de Luta',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                icon: Icon(Icons.play_arrow_rounded),
                label: Text('Iniciar Luta'),
                onPressed: _validateAndStartMatch,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: BjjApp.successColor,
                  foregroundColor: BjjApp.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAthleteSetupCard({
    required int playerNumber,
    required String title,
    required Aluno? selectedAluno,
    required ValueChanged<Aluno?> onAlunoChanged,
    required String kimonoColor,
    required ValueChanged<String?> onKimonoChanged,
  }) {
    List<Aluno> availableAlunos = List.from(widget.todosAlunos);
    if (playerNumber == 1 && _selectedAluno2 != null) {
      availableAlunos.remove(_selectedAluno2);
    } else if (playerNumber == 2 && _selectedAluno1 != null) {
      availableAlunos.remove(_selectedAluno1);
    }
    Aluno? currentValidSelection = selectedAluno;
    if (selectedAluno != null && !availableAlunos.contains(selectedAluno)) {
      currentValidSelection = null;
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 18)),
            SizedBox(height: 16),
            DropdownButtonFormField<Aluno>(
              value: currentValidSelection,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Selecionar Aluno',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              items: availableAlunos.map((aluno) {
                return DropdownMenuItem<Aluno>(
                  value: aluno,
                  child: Text(aluno.nome, overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: onAlunoChanged,
              validator: (value) => value == null ? 'Selecione um aluno' : null,
            ),
            SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: kimonoColor,
              decoration: InputDecoration(
                labelText: 'Cor do Kimono',
                prefixIcon: Icon(Icons.style_outlined),
              ),
              items: _kimonoOptions.map((color) {
                return DropdownMenuItem<String>(
                  value: color,
                  child: Text(color),
                );
              }).toList(),
              onChanged: onKimonoChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class ScoreboardPage extends StatefulWidget {
  final Aluno aluno1;
  final Aluno aluno2;
  final String kimonoColor1;
  final String kimonoColor2;
  final Duration initialTime;
  const ScoreboardPage({
    Key? key,
    required this.aluno1,
    required this.aluno2,
    required this.kimonoColor1,
    required this.kimonoColor2,
    required this.initialTime,
  }) : super(key: key);
  @override
  _ScoreboardPageState createState() => _ScoreboardPageState();
}

class _ScoreboardPageState extends State<ScoreboardPage> {
  Map<String, int> _scores1 = _defaultScores();
  Map<String, int> _scores2 = _defaultScores();
  int _totalScore1 = 0;
  int _totalScore2 = 0;
  late Duration _editableInitialTime;
  late Duration _currentTime;
  Timer? _timer;
  bool _isTimerRunning = false;
  bool _isMatchOver = false;

  static Map<String, int> _defaultScores() =>
      {'montada': 0, 'passagem': 0, 'queda': 0, 'vantagem': 0, 'punicao': 0};

  @override
  void initState() {
    super.initState();
    _editableInitialTime = widget.initialTime;
    _currentTime = _editableInitialTime;
    _calculateTotalScores();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateScore(int player, String type, int changeDirection) {
    if (_isMatchOver) return;
    setState(() {
      if (type == 'punicao') {
        _handlePenaltyUpdate(player, changeDirection);
      } else {
        _handleStandardScoreUpdate(player, type, changeDirection);
      }
    });
  }

  void _handlePenaltyUpdate(int player, int changeDirection) {
    if (_isMatchOver) return;
    Map<String, int> penalizedScores = (player == 1) ? _scores1 : _scores2;
    int currentPenaltyCount = penalizedScores['punicao'] ?? 0;
    if (changeDirection == 1) {
      int newPenaltyCount = currentPenaltyCount + 1;
      penalizedScores['punicao'] = newPenaltyCount;
      if (newPenaltyCount >= 4) {
        setState(() {
          _isMatchOver = true;
        });
        _stopTimer();
        _handleEndOfMatch();
        return;
      }
      _applyPenaltyConsequence(newPenaltyCount, player, true);
    } else if (changeDirection == -1) {
      if (currentPenaltyCount > 0) {
        _applyPenaltyConsequence(currentPenaltyCount, player, false);
        penalizedScores['punicao'] = currentPenaltyCount - 1;
      }
    }
    _calculateTotalScores();
  }

  void _applyPenaltyConsequence(
      int penaltyCountForConsequence, int penalizedPlayer, bool isAdding) {
    Map<String, int> opponentScores =
        (penalizedPlayer == 1) ? _scores2 : _scores1;
    int effectivePenaltyCount = penaltyCountForConsequence;

    if (isAdding) {
      if (effectivePenaltyCount == 2) {
        opponentScores['vantagem'] = (opponentScores['vantagem'] ?? 0) + 1;
        showBjjSnackBar(context, 'Vantagem concedida ao oponente!',
            type: 'info');
      } else if (effectivePenaltyCount == 3) {
        _addPointsToOpponent(opponentScores, 2);
        showBjjSnackBar(context, '2 Pontos concedidos ao oponente!',
            type: 'success');
      }
    } else {
      if (effectivePenaltyCount == 3) {
        _removePointsFromOpponent(opponentScores, 2);
        showBjjSnackBar(context, '2 Pontos removidos do oponente.',
            type: 'info');
      } else if (effectivePenaltyCount == 2) {
        opponentScores['vantagem'] =
            ((opponentScores['vantagem'] ?? 0) - 1).clamp(0, 999);
        showBjjSnackBar(context, 'Vantagem removida do oponente.',
            type: 'info');
      }
    }
  }

  void _addPointsToOpponent(Map<String, int> opponentScores, int points) {
    opponentScores['queda'] = (opponentScores['queda'] ?? 0) + points;
  }

  void _removePointsFromOpponent(Map<String, int> opponentScores, int points) {
    opponentScores['queda'] =
        ((opponentScores['queda'] ?? 0) - points).clamp(0, 999);
  }

  void _handleStandardScoreUpdate(
      int player, String type, int changeDirection) {
    Map<String, int> currentScores = (player == 1) ? _scores1 : _scores2;
    int incrementValue;
    switch (type) {
      case 'montada':
        incrementValue = 4;
        break;
      case 'passagem':
        incrementValue = 3;
        break;
      case 'queda':
        incrementValue = 2;
        break;
      default:
        incrementValue = 1;
        break;
    }
    int valueChange = incrementValue * changeDirection;
    int newValue = (currentScores[type] ?? 0) + valueChange;
    currentScores[type] = newValue.clamp(0, 999);
    if (type != 'vantagem') {
      _calculateTotalScores();
    }
  }

  void _calculateTotalScores() {
    setState(() {
      _totalScore1 = (_scores1['montada']!) +
          (_scores1['passagem']!) +
          (_scores1['queda']!);
      _totalScore2 = (_scores2['montada']!) +
          (_scores2['passagem']!) +
          (_scores2['queda']!);
    });
  }

  void _startTimer() {
    if (_isTimerRunning || _isMatchOver) return;
    setState(() {
      _isTimerRunning = true;
    });
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_currentTime.inSeconds > 0) {
          _currentTime -= Duration(seconds: 1);
        } else {
          _stopTimer();
          _isMatchOver = true;
          showBjjSnackBar(context, 'Tempo da luta encerrado!', type: 'info');
          _handleEndOfMatch();
        }
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    if (mounted) {
      setState(() {
        _isTimerRunning = false;
      });
    }
  }

  void _restartFight() {
    _stopTimer();
    setState(() {
      _scores1 = _defaultScores();
      _scores2 = _defaultScores();
      _calculateTotalScores();
      _currentTime = _editableInitialTime;
      _isTimerRunning = false;
      _isMatchOver = false;
    });
    if (mounted) {
      showBjjSnackBar(context, 'Placar e cronômetro reiniciados.',
          type: 'info');
    }
  }

  void _handleEndOfMatch() {
    String winnerMessage = "Luta encerrada!";
    if ((_scores1['punicao'] ?? 0) >= 4) {
      winnerMessage =
          "${widget.aluno2.nome} venceu por desclassificação de ${widget.aluno1.nome}!";
    } else if ((_scores2['punicao'] ?? 0) >= 4) {
      winnerMessage =
          "${widget.aluno1.nome} venceu por desclassificação de ${widget.aluno2.nome}!";
    } else if (_totalScore1 > _totalScore2) {
      winnerMessage = "${widget.aluno1.nome} venceu por pontos!";
    } else if (_totalScore2 > _totalScore1) {
      winnerMessage = "${widget.aluno2.nome} venceu por pontos!";
    } else {
      if ((_scores1['vantagem'] ?? 0) > (_scores2['vantagem'] ?? 0)) {
        winnerMessage = "${widget.aluno1.nome} venceu por vantagens!";
      } else if ((_scores2['vantagem'] ?? 0) > (_scores1['vantagem'] ?? 0)) {
        winnerMessage = "${widget.aluno2.nome} venceu por vantagens!";
      } else {
        if ((_scores1['punicao'] ?? 0) < (_scores2['punicao'] ?? 0)) {
          winnerMessage = "${widget.aluno1.nome} venceu (menos punições)!";
        } else if ((_scores2['punicao'] ?? 0) < (_scores1['punicao'] ?? 0)) {
          winnerMessage = "${widget.aluno2.nome} venceu (menos punições)!";
        } else {
          winnerMessage = "A luta terminou empatada!";
        }
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text("Fim da Luta!"),
        content: Text(winnerMessage),
        actions: <Widget>[
          ElevatedButton(
            child: Text("OK"),
            onPressed: () {
              Navigator.of(ctx).pop();
            },
          )
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }

  Color _getKimonoColor(String colorName) {
    switch (colorName.toLowerCase()) {
      case 'branco':
        return Colors.white;
      case 'azul':
        return BjjApp.infoColor;
      case 'preto':
        return Colors.grey.shade600;
      default:
        return BjjApp.textHint;
    }
  }

  Widget _buildPlayerHeader(int playerNumber) {
    Aluno currentAluno = (playerNumber == 1) ? widget.aluno1 : widget.aluno2;
    String kimonoColorName =
        (playerNumber == 1) ? widget.kimonoColor1 : widget.kimonoColor2;
    int totalScore = (playerNumber == 1) ? _totalScore1 : _totalScore2;
    bool useIdentifier = widget.kimonoColor1 == widget.kimonoColor2;

    Map<String, int> scores = (playerNumber == 1) ? _scores1 : _scores2;
    int advantages = scores['vantagem'] ?? 0;
    int punishments = scores['punicao'] ?? 0;

    final headerContent = Container(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              currentAluno.nome.toUpperCase(),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: BjjApp.textPrimary),
            ),
          ),
          SizedBox(height: 4),
          Text(
            '$totalScore',
            style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: _getKimonoColor(kimonoColorName)),
          ),
          SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('V:',
                  style: TextStyle(
                      fontSize: 12,
                      color: BjjApp.textHint,
                      fontWeight: FontWeight.w500)),
              Text(' $advantages',
                  style: TextStyle(
                      fontSize: 14,
                      color: BjjApp.textSecondary,
                      fontWeight: FontWeight.bold)),
              SizedBox(width: 12),
              Text('P:',
                  style: TextStyle(
                      fontSize: 12,
                      color: BjjApp.textHint,
                      fontWeight: FontWeight.w500)),
              Text(' $punishments',
                  style: TextStyle(
                      fontSize: 14,
                      color: punishments >= 4
                          ? BjjApp.errorColor
                          : BjjApp.textSecondary,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );

    if (playerNumber == 2 && useIdentifier) {
      return Expanded(
        child: GradientBorderContainer(
          gradient: LinearGradient(
            colors: [
              BjjApp.primaryAccent.withOpacity(0.7),
              BjjApp.primaryAccent.withOpacity(0.4)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderWidth: 2.0,
          child: headerContent,
        ),
      );
    }

    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: BjjApp.darkSurface,
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: _getKimonoColor(kimonoColorName), width: 1.5),
        ),
        child: headerContent,
      ),
    );
  }

  Widget _buildScoreControl(String type, int player) {
    Map<String, int> scores = (player == 1) ? _scores1 : _scores2;
    String scoreLabel;
    int pointsPerClick = 1;
    switch (type) {
      case 'montada':
        scoreLabel = 'Montada / Costas (+4)';
        pointsPerClick = 4;
        break;
      case 'passagem':
        scoreLabel = 'Passagem (+3)';
        pointsPerClick = 3;
        break;
      case 'queda':
        scoreLabel = 'Queda / Raspagem (+2)';
        pointsPerClick = 2;
        break;
      case 'vantagem':
        scoreLabel = 'Vantagens (+1)';
        break;
      default:
        scoreLabel = 'Punições (+1)';
        break;
    }

    int displayValue = scores[type] ?? 0;
    if (type != 'vantagem' && type != 'punicao') {
      displayValue = (scores[type] ?? 0) ~/ pointsPerClick;
    }

    return Card(
      color: BjjApp.darkSurface.withOpacity(0.7),
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
        child: Column(
          children: [
            Text(scoreLabel,
                style: TextStyle(fontSize: 12, color: BjjApp.textSecondary)),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(Icons.remove_circle_outline_rounded),
                  iconSize: 32,
                  color: BjjApp.textHint,
                  onPressed: _isMatchOver
                      ? null
                      : () => _updateScore(player, type, -1),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
                Container(
                  width: 40,
                  alignment: Alignment.center,
                  child: Text('$displayValue',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: type == 'punicao' && displayValue >= 4
                              ? BjjApp.errorColor
                              : BjjApp.primaryAccent)),
                ),
                IconButton(
                  icon: Icon(Icons.add_circle_outline_rounded),
                  iconSize: 32,
                  color: BjjApp.textHint,
                  onPressed:
                      _isMatchOver ? null : () => _updateScore(player, type, 1),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: onPressed == null ? Colors.grey[700]?.withOpacity(0.5) : color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, size: 32),
        color: BjjApp.primaryAccentForeground,
        onPressed: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Placar da Luta'),
        automaticallyImplyLeading: true,
      ),
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Row(
                    children: [
                      _buildPlayerHeader(1),
                      SizedBox(width: 8),
                      _buildPlayerHeader(2),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildTimerControlButton(
                      icon: _isTimerRunning
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      onPressed: _isMatchOver
                          ? null
                          : (_isTimerRunning ? _stopTimer : _startTimer),
                      color: _isTimerRunning
                          ? BjjApp.warningColor
                          : BjjApp.successColor,
                    ),
                    Text(
                      _formatDuration(_currentTime),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: _currentTime.inSeconds == 0
                            ? BjjApp.errorColor
                            : BjjApp.primaryAccent,
                      ),
                    ),
                    _buildTimerControlButton(
                      icon: Icons.restart_alt_rounded,
                      onPressed: _restartFight,
                      color: BjjApp.errorColor,
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Divider(color: BjjApp.borderNormal),
                SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _buildScoreControl('montada', 1),
                              _buildScoreControl('passagem', 1),
                              _buildScoreControl('queda', 1),
                              _buildScoreControl('vantagem', 1),
                              _buildScoreControl('punicao', 1),
                            ],
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            children: [
                              _buildScoreControl('montada', 2),
                              _buildScoreControl('passagem', 2),
                              _buildScoreControl('queda', 2),
                              _buildScoreControl('vantagem', 2),
                              _buildScoreControl('punicao', 2),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GradientBorderContainer extends StatelessWidget {
  final Widget child;
  final Gradient gradient;
  final double borderWidth;
  final double borderRadius;
  const GradientBorderContainer({
    Key? key,
    required this.child,
    required this.gradient,
    this.borderWidth = 1.5,
    this.borderRadius = 8.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: BjjApp.darkSurface,
          borderRadius:
              BorderRadius.circular(max(0, borderRadius - borderWidth)),
        ),
        child: child,
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  final VoidCallback onBackup;
  final VoidCallback onRestore;
  final VoidCallback onLogout;
  const SettingsPage({
    Key? key,
    required this.onBackup,
    required this.onRestore,
    required this.onLogout,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Configurações e Dados'),
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          children: [
            if (user != null)
              ListTile(
                leading: Icon(Icons.person_pin_rounded, color: BjjApp.textHint),
                title: Text('Conta Logada'),
                subtitle: Text(
                  user.email ?? 'E-mail não disponível',
                  style: TextStyle(color: BjjApp.textSecondary),
                ),
                onTap: null,
              ),
            if (user != null)
              Divider(
                height: 20,
                thickness: 1,
                indent: 16,
                endIndent: 16,
                color: BjjApp.borderNormal,
              ),
            ListTile(
              leading: Icon(Icons.backup_rounded, color: BjjApp.infoColor),
              title: Text('Fazer Backup dos Dados'),
              subtitle: Text('Salva alunos, check-ins e estudos em um arquivo'),
              onTap: onBackup,
            ),
            ListTile(
              leading:
                  Icon(Icons.restore_page_rounded, color: BjjApp.successColor),
              title: Text('Restaurar Backup'),
              subtitle: Text('Carrega dados de um arquivo .json selecionado'),
              onTap: onRestore,
            ),
            Divider(
              height: 20,
              thickness: 1,
              indent: 16,
              endIndent: 16,
              color: BjjApp.borderNormal,
            ),
            ListTile(
              leading: Icon(Icons.logout_rounded, color: BjjApp.errorColor),
              title: Text('Sair da Conta'),
              subtitle: Text('Finalizar a sessão atual e voltar para o login'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Sair da Conta'),
                    content: Text('Tem certeza que deseja sair?'),
                    actions: [
                      TextButton(
                        child: Text('Cancelar'),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                      ElevatedButton(
                        child: Text('Sair'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: BjjApp.errorColor,
                            foregroundColor: BjjApp.textPrimary),
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          onLogout();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: AppBackground(
                child: Center(child: CircularProgressIndicator())),
          );
        }
        if (!snapshot.hasData) {
          return LoginPage();
        }
        snapshot.data!.reload().catchError((e) {
          FirebaseAuth.instance.signOut();
        });
        return MainPage();
      },
    );
  }
}

// ***** PÁGINA DO RANKING CORRIGIDA *****
class RankingPage extends StatefulWidget {
  const RankingPage({Key? key}) : super(key: key);
  @override
  _RankingPageState createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> {
  Map<String, int> _checkinCounts = {};
  List<Aluno> _todosAlunos = [];
  bool _isLoading = true;
  String _filter = 'total';

  @override
  void initState() {
    super.initState();
    _fetchRankingData();
  }

  Future<void> _fetchRankingData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    try {
      // Obter os dados de forma assíncrona
      final alunosSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('alunos')
          .get();
      final fetchedAlunos = alunosSnapshot.docs
          .map((doc) => Aluno.fromJson(doc.id, doc.data()))
          .toList();

      final checkinsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('checkins')
          .get();
      final allCheckins = checkinsSnapshot.docs
          .map((doc) => CheckinEntry.fromJson(doc.id, doc.data()))
          .toList();

      // Processar os dados com base no filtro
      final now = DateTime.now();
      final Map<String, int> counts = {
        for (var aluno in fetchedAlunos) aluno.id: 0
      };

      for (var checkin in allCheckins) {
        bool shouldCount = false;
        switch (_filter) {
          case 'total':
            shouldCount = true;
            break;
          case 'mes':
            if (checkin.date.month == now.month &&
                checkin.date.year == now.year) {
              shouldCount = true;
            }
            break;
          case 'ano':
            if (checkin.date.year == now.year) {
              shouldCount = true;
            }
            break;
        }
        if (shouldCount) {
          counts.update(checkin.studentId, (value) => value + 1,
              ifAbsent: () => 1);
        }
      }

      // Atualizar o estado com os novos dados de uma só vez
      if (mounted) {
        setState(() {
          _todosAlunos = fetchedAlunos;
          _checkinCounts = counts;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Erro ao buscar dados do ranking: $e");
      if (mounted) {
        showBjjSnackBar(context, "Erro ao carregar o ranking.", type: "error");
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rankedAlunos = List<Aluno>.from(_todosAlunos);
    rankedAlunos.sort((a, b) {
      final countA = _checkinCounts[a.id] ?? 0;
      final countB = _checkinCounts[b.id] ?? 0;
      if (countB.compareTo(countA) != 0) {
        return countB.compareTo(countA);
      }
      return a.nome.compareTo(b.nome);
    });

    return Scaffold(
      appBar: AppBar(title: Text('Ranking de Presença')),
      body: AppBackground(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: SegmentedButton<String>(
                segments: const <ButtonSegment<String>>[
                  ButtonSegment<String>(value: 'mes', label: Text('Mês Atual')),
                  ButtonSegment<String>(value: 'ano', label: Text('Este Ano')),
                  ButtonSegment<String>(value: 'total', label: Text('Total')),
                ],
                selected: {_filter},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _filter = newSelection.first;
                  });
                  _fetchRankingData();
                },
                style: Theme.of(context).segmentedButtonTheme.style,
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : rankedAlunos.isEmpty
                      ? EmptyStateWidget(
                          icon: Icons.group_off_rounded,
                          title: "Nenhum aluno encontrado.")
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 16.0),
                          itemCount: rankedAlunos.length,
                          itemBuilder: (context, index) {
                            final aluno = rankedAlunos[index];
                            final count = _checkinCounts[aluno.id] ?? 0;
                            final rank = index + 1;
                            Widget leadingIcon;
                            if (rank == 1) {
                              leadingIcon = Icon(Icons.emoji_events,
                                  color: BjjApp.primaryAccent, size: 30);
                            } else if (rank == 2) {
                              leadingIcon = Icon(Icons.emoji_events,
                                  color: Color(0xFFC0C0C0), size: 28);
                            } else if (rank == 3) {
                              leadingIcon = Icon(Icons.emoji_events,
                                  color: Color(0xFFCD7F32), size: 26);
                            } else {
                              leadingIcon = CircleAvatar(
                                radius: 14,
                                backgroundColor: BjjApp.darkSurface,
                                child: Text(
                                  '$rank',
                                  style: TextStyle(
                                      color: BjjApp.textHint,
                                      fontWeight: FontWeight.bold),
                                ),
                              );
                            }
                            return Card(
                              child: ListTile(
                                leading: leadingIcon,
                                title: Text(aluno.nome,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                trailing: Text(
                                  '$count treinos',
                                  style: TextStyle(
                                    color: BjjApp.primaryAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    BjjApp(),
  );
}
