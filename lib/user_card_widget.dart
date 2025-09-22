// lib/user_card_widget.dart
// ignore_for_file: use_build_context_synchronously

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'models.dart';
import 'app_theme.dart';
import 'common_widgets.dart';
import 'manager_module.dart';

Future<void> _createAuditLog({
  required String academyId,
  required UserModel actor,
  required String actionType,
  required String description,
  String? targetUid,
  String? targetName,
}) async {
  try {
    await FirebaseFirestore.instance
        .collection('academies')
        .doc(academyId)
        .collection('audit_log')
        .add({
      'actorUid': actor.uid,
      'actorName': actor.name,
      'actionType': actionType,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
      'targetUid': targetUid,
      'targetName': targetName,
    });
  } catch (e) {
    debugPrint("Erro ao criar log de auditoria: $e");
  }
}

class PhotoViewPage extends StatelessWidget {
  final String imageUrl;
  final String heroTag;

  const PhotoViewPage({
    super.key,
    required this.imageUrl,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Hero(
          tag: heroTag,
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 1.0,
            maxScale: 4.0,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) =>
                  const Icon(Icons.broken_image, size: 100, color: textHint),
            ),
          ),
        ),
      ),
    );
  }
}

class UserCard extends StatelessWidget {
  final dynamic user;
  final String academyId;
  final UserModel currentUser;
  final String? profileImageUrl;

  const UserCard({
    super.key,
    required this.user,
    required this.academyId,
    required this.currentUser,
    this.profileImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final bool isStudent = user is Aluno;
    final String name = isStudent ? user.nome : user.name;
    final String? belt = isStudent ? user.faixa : user.faixa;
    final String heroTag = 'profile_pic_${isStudent ? user.id : user.uid}';

    final bool hasImage =
        profileImageUrl != null && profileImageUrl!.isNotEmpty;

    final childText = Text(
      name.isNotEmpty ? name[0].toUpperCase() : 'U',
      style: const TextStyle(fontSize: 24, color: primaryAccentForeground),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                if (hasImage) {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PhotoViewPage(
                      imageUrl: profileImageUrl!,
                      heroTag: heroTag,
                    ),
                  ));
                }
              },
              child: Hero(
                tag: heroTag,
                // --- INÍCIO DA ALTERAÇÃO ---
                // Alterado para usar CachedNetworkImage como filho, o que permite
                // tratar erros de carregamento sem quebrar a tela.
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: primaryAccent,
                  child: hasImage
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: profileImageUrl!,
                            fit: BoxFit.cover,
                            width: 56, // 2x o raio
                            height: 56, // 2x o raio
                            placeholder: (context, url) =>
                                Container(color: darkSurface),
                            errorWidget: (context, url, error) {
                              // Se a imagem falhar, mostra as iniciais do nome
                              return Center(child: childText);
                            },
                          ),
                        )
                      : Center(child: childText),
                ),
                // --- FIM DA ALTERAÇÃO ---
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  if (belt != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: darkSurface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        belt,
                        style:
                            const TextStyle(color: textSecondary, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.visibility_outlined, color: textHint),
              tooltip: 'Ver Detalhes',
              onPressed: () {
                if (isStudent) {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => StudentDetailPage(
                      academyId: academyId,
                      student: user,
                      currentUser: currentUser,
                    ),
                  ));
                } else {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProfessorDetailPage(
                      academyId: academyId,
                      professor: user,
                      currentUser: currentUser,
                    ),
                  ));
                }
              },
            ),
            if (currentUser.role == UserRole.manager ||
                (currentUser.role == UserRole.teacher && isStudent))
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: primaryAccent),
                tooltip: 'Editar / Gerenciar',
                onPressed: () {
                  if (isStudent) {
                    _showEditAlunoDialog(context, user, academyId, currentUser);
                  } else {
                    _showEditProfessorDialog(
                        context, user, academyId, currentUser);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

void _showEditAlunoDialog(BuildContext context, Aluno aluno, String academyId,
    UserModel currentUser) {
  showDialog(
    context: context,
    builder: (_) => AdicionarAlunoDialog(
      alunoParaEditar: aluno,
      academyId: academyId,
      currentUser: currentUser,
      onAlunoAdicionado: (alunoAtualizado, newImageFile) async {
        try {
          final batch = FirebaseFirestore.instance.batch();
          final studentRef = FirebaseFirestore.instance
              .collection('academies')
              .doc(academyId)
              .collection('students')
              .doc(alunoAtualizado.id);

          final dataToUpdate = {
            'nome': alunoAtualizado.nome,
            'faixa': alunoAtualizado.faixa,
            'peso': alunoAtualizado.peso,
            'graus': alunoAtualizado.graus,
            'dataNascimento': alunoAtualizado.dataNascimento != null
                ? Timestamp.fromDate(alunoAtualizado.dataNascimento!)
                : null,
            'phoneNumber': alunoAtualizado.phoneNumber,
            'address': alunoAtualizado.address,
            'unitId': alunoAtualizado.unitId,
            'unitName': alunoAtualizado.unitName,
            'lastUpdatedByUid': currentUser.uid,
            'lastUpdatedByName': currentUser.name,
            'updatedAt': FieldValue.serverTimestamp(),
          };

          batch.update(studentRef, dataToUpdate);

          if (alunoAtualizado.userId != null) {
            final userRef = FirebaseFirestore.instance
                .collection('users')
                .doc(alunoAtualizado.userId!);

            String? newImageUrl;
            if (newImageFile != null) {
              final ref = FirebaseStorage.instance
                  .ref()
                  .child('profile_images')
                  .child('${alunoAtualizado.userId}.jpg');
              if (kIsWeb) {
                await ref.putData(await newImageFile.readAsBytes());
              } else {
                await ref.putFile(File(newImageFile.path));
              }
              newImageUrl = await ref.getDownloadURL();
            }

            batch.update(userRef, {
              'name': alunoAtualizado.nome,
              'phoneNumber': alunoAtualizado.phoneNumber,
              'address': alunoAtualizado.address,
              'lastUpdatedByUid': currentUser.uid,
              'lastUpdatedByName': currentUser.name,
              'updatedAt': FieldValue.serverTimestamp(),
              if (newImageUrl != null) 'profileImagePath': newImageUrl,
            });
          }

          await batch.commit();

          await _createAuditLog(
            academyId: academyId,
            actor: currentUser,
            actionType: 'UPDATE_STUDENT',
            description:
                '${currentUser.name} editou os dados do aluno ${aluno.nome}.',
            targetName: aluno.nome,
            targetUid: aluno.userId,
          );

          if (context.mounted) {
            showBjjSnackBar(context, 'Aluno atualizado com sucesso!',
                type: 'success');
            // A pop é feita pelo próprio AdicionarAlunoDialog agora
          }
        } catch (e) {
          if (context.mounted) {
            showBjjSnackBar(context, 'Erro ao atualizar aluno: $e',
                type: 'error');
          }
        }
      },
    ),
  );
}

void _showEditProfessorDialog(BuildContext context, UserModel professor,
    String academyId, UserModel manager) {
  showDialog(
    context: context,
    builder: (_) => EditarProfessorDialog(
        professor: professor, academyId: academyId, manager: manager),
  );
}
