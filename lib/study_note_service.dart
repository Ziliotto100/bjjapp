// ignore_for_file: empty_catches

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:image_picker/image_picker.dart';
import 'models.dart';

class StudyNoteService {
  // O nome do arquivo e do diretório agora serão dinâmicos.

  /// Obtém o caminho completo para o diretório de documentos do aplicativo.
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  /// Obtém o arquivo de anotações específico do usuário.
  Future<File> _localFile(String userId) async {
    final path = await _localPath;
    // O nome do arquivo agora inclui o ID do usuário para garantir a privacidade.
    return File('$path/study_notes_$userId.json');
  }

  /// Carrega as anotações apenas do usuário especificado.
  Future<List<StudyNote>> loadNotes(String userId) async {
    try {
      final file = await _localFile(userId);
      if (!await file.exists()) {
        return [];
      }
      final contents = await file.readAsString();
      if (contents.isEmpty) {
        return [];
      }
      final List<dynamic> jsonList = json.decode(contents);
      return jsonList.map((json) => StudyNote.fromJson(json)).toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e) {
      return [];
    }
  }

  /// Salva as anotações para o usuário especificado.
  Future<File> saveNotes(String userId, List<StudyNote> notes) async {
    final file = await _localFile(userId);
    final jsonList = notes.map((note) => note.toJson()).toList();
    return file.writeAsString(json.encode(jsonList));
  }

  /// Obtém o diretório de imagens específico do usuário.
  Future<Directory> _getImagesDirectory(String userId) async {
    final path = await _localPath;
    // O nome da pasta de imagens também inclui o ID do usuário.
    final imagesDir = Directory(p.join(path, 'study_images_$userId'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }
    return imagesDir;
  }

  /// Salva uma imagem na pasta do usuário especificado.
  Future<String?> saveImage(String userId, XFile imageFile) async {
    try {
      final imagesDir = await _getImagesDirectory(userId);
      final fileName = p.basename(imageFile.path);
      final newPath = p.join(imagesDir.path, fileName);
      final savedFile = await File(imageFile.path).copy(newPath);
      return savedFile.path;
    } catch (e) {
      return null;
    }
  }

  /// Deleta um arquivo de imagem. O caminho já é único, não precisa do userId.
  Future<void> deleteImage(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return;
    try {
      final file = File(imagePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {}
  }
}
