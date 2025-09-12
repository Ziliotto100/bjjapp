// lib/tutorials_module.dart
// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // CORREÇÃO APLICADA AQUI

import 'app_theme.dart';
import 'common_widgets.dart';
import 'models.dart';

/// Tela que exibe a lista de vídeos tutoriais para o usuário.
class TutorialsPage extends StatefulWidget {
  final UserModel user;

  const TutorialsPage({super.key, required this.user});

  @override
  State<TutorialsPage> createState() => _TutorialsPageState();
}

class _TutorialsPageState extends State<TutorialsPage> {
  // Busca as playlists visíveis para o usuário
  Stream<List<TutorialPlaylist>> _getPlaylistsStream() {
    return FirebaseFirestore.instance
        .collection('tutorial_playlists')
        .orderBy('orderIndex')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TutorialPlaylist.fromFirestore(doc))
            .toList());
  }

  // Busca os tutoriais que pertencem a uma playlist específica
  Stream<List<Tutorial>> _getTutorialsForPlaylistStream(String playlistId) {
    return FirebaseFirestore.instance
        .collection('tutorials')
        .where('playlistId', isEqualTo: playlistId)
        .where('visibleTo', arrayContains: widget.user.role.name)
        .orderBy('orderIndex')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Tutorial.fromFirestore(doc)).toList());
  }

  // Busca tutoriais que não pertencem a nenhuma playlist
  Stream<List<Tutorial>> _getOrphanTutorialsStream() {
    return FirebaseFirestore.instance
        .collection('tutorials')
        .where('playlistId', isNull: true)
        .where('visibleTo', arrayContains: widget.user.role.name)
        .orderBy('orderIndex')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Tutorial.fromFirestore(doc)).toList());
  }

  Future<void> _launchVideo(BuildContext context, String videoUrl) async {
    final uri = Uri.parse(videoUrl);
    if (!await canLaunchUrl(uri)) {
      showBjjSnackBar(context, 'Não foi possível abrir o vídeo.',
          type: 'error');
    } else {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Central de Ajuda'),
      ),
      body: AppBackground(
        child: SafeArea(
          child: StreamBuilder<List<TutorialPlaylist>>(
            stream: _getPlaylistsStream(),
            builder: (context, playlistSnapshot) {
              if (playlistSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (playlistSnapshot.hasError) {
                return const EmptyStateWidget(
                  icon: Icons.error_outline,
                  title: 'Erro ao Carregar',
                );
              }

              final playlists = playlistSnapshot.data ?? [];

              return StreamBuilder<List<Tutorial>>(
                stream: _getOrphanTutorialsStream(),
                builder: (context, orphanSnapshot) {
                  if (orphanSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final orphanTutorials = orphanSnapshot.data ?? [];

                  if (playlists.isEmpty && orphanTutorials.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.help_outline_rounded,
                      title: 'Nenhum Tutorial',
                      message: 'Ainda não há vídeos de ajuda disponíveis.',
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.all(8.0),
                    children: [
                      ...playlists.map((playlist) {
                        return Card(
                          child: ExpansionTile(
                            leading: const Icon(Icons.video_library_rounded,
                                color: primaryAccent),
                            title: Text(playlist.name,
                                style: Theme.of(context).textTheme.titleMedium),
                            children: [
                              StreamBuilder<List<Tutorial>>(
                                stream:
                                    _getTutorialsForPlaylistStream(playlist.id),
                                builder: (context, tutorialSnapshot) {
                                  if (!tutorialSnapshot.hasData) {
                                    return const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: Center(
                                          child: CircularProgressIndicator()),
                                    );
                                  }
                                  final tutorials = tutorialSnapshot.data!;
                                  if (tutorials.isEmpty) {
                                    return const ListTile(
                                        title: Text(
                                            'Nenhum vídeo nesta playlist.',
                                            style: TextStyle(color: textHint)));
                                  }
                                  return Column(
                                    children: tutorials
                                        .map((tutorial) => ListTile(
                                              leading: const Icon(
                                                  Icons
                                                      .play_circle_outline_rounded,
                                                  size: 30),
                                              title: Text(tutorial.title),
                                              subtitle:
                                                  Text(tutorial.description),
                                              onTap: () => _launchVideo(
                                                  context, tutorial.videoUrl),
                                            ))
                                        .toList(),
                                  );
                                },
                              )
                            ],
                          ),
                        );
                      }),
                      // Exibe os vídeos sem playlist
                      ...orphanTutorials.map(
                        (tutorial) => Card(
                          child: ListTile(
                            leading: const Icon(
                                Icons.play_circle_outline_rounded,
                                color: textHint,
                                size: 40),
                            title: Text(tutorial.title),
                            subtitle: Text(tutorial.description),
                            onTap: () =>
                                _launchVideo(context, tutorial.videoUrl),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
