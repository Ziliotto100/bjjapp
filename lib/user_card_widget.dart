// lib/user_card_widget.dart
import 'package:cached_network_image/cached_network_image.dart'; // NOVO IMPORT
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'models.dart';
import 'app_theme.dart';
import 'common_widgets.dart';
import 'manager_module.dart'; // Para StudentDetailPage e ProfessorDetailPage
// Para acesso a diálogos de edição

/// Página para visualizar uma imagem em tela cheia com zoom.
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
            // --- ALTERAÇÃO AQUI ---
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) =>
                  const Icon(Icons.broken_image, size: 100, color: textHint),
            ),
            // --- FIM DA ALTERAÇÃO ---
          ),
        ),
      ),
    );
  }
}

/// Card de usuário reutilizável para Alunos e Professores.
class UserCard extends StatelessWidget {
  final dynamic user; // Pode ser Aluno ou UserModel
  final String academyId;
  final UserModel currentUser; // O usuário logado (gerente ou professor)
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

    // --- ALTERAÇÃO AQUI ---
    final backgroundImage =
        hasImage ? CachedNetworkImageProvider(profileImageUrl!) : null;
    // --- FIM DA ALTERAÇÃO ---

    final childText = hasImage
        ? null
        : Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'U',
            style:
                const TextStyle(fontSize: 24, color: primaryAccentForeground),
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
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: primaryAccent,
                  backgroundImage: backgroundImage,
                  child: childText,
                ),
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
                    ),
                  ));
                } else {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => ProfessorDetailPage(
                      academyId: academyId,
                      professor: user,
                    ),
                  ));
                }
              },
            ),
            // --- ALTERAÇÃO PRINCIPAL AQUI ---
            // Habilita o botão de edição para gerentes (sempre) e para professores (apenas se for um aluno)
            if (currentUser.role == UserRole.manager ||
                (currentUser.role == UserRole.teacher && isStudent))
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: primaryAccent),
                tooltip: 'Editar / Gerenciar',
                onPressed: () {
                  if (isStudent) {
                    _showEditAlunoDialog(context, user, academyId, currentUser);
                  } else {
                    // Professores não podem editar outros professores, então apenas gerentes chegam aqui.
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

// Funções de diálogo movidas para cá para serem acessíveis por ambos os módulos.
// Elas precisam de um BuildContext que tenha acesso às rotas e dependências.

void _showEditAlunoDialog(BuildContext context, Aluno aluno, String academyId,
    UserModel currentUser) {
  showDialog(
    context: context,
    builder: (_) => AdicionarAlunoDialog(
      alunoParaEditar: aluno,
      academyId: academyId,
      currentUser: currentUser,
      onAlunoAdicionado: (alunoAtualizado) async {
        try {
          final dataToUpdate = {
            'nome': alunoAtualizado.nome,
            'faixa': alunoAtualizado.faixa,
            'peso': alunoAtualizado.peso,
            'graus': alunoAtualizado.graus,
            'dataNascimento': alunoAtualizado.dataNascimento != null
                ? Timestamp.fromDate(alunoAtualizado.dataNascimento!)
                : null,
            'lastUpdatedByUid': currentUser.uid,
            'lastUpdatedByName': currentUser.name,
            'updatedAt': FieldValue.serverTimestamp(),
          };

          await FirebaseFirestore.instance
              .collection('academies')
              .doc(academyId)
              .collection('students')
              .doc(alunoAtualizado.id)
              .update(dataToUpdate);

          if (alunoAtualizado.userId != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(alunoAtualizado.userId!)
                .update({'name': alunoAtualizado.nome});
          }
          if (context.mounted) {
            showBjjSnackBar(context, 'Aluno atualizado com sucesso!',
                type: 'success');
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
