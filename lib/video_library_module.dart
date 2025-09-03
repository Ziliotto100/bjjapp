// lib/video_library_module.dart
// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'dart:io'; // <-- CORREÇÃO: IMPORT ADICIONADO
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

import 'models.dart';
import 'common_widgets.dart';
import 'app_theme.dart';

// --- TELA PRINCIPAL QUE EXIBE PLAYLISTS E VÍDEOS ---
class VideoLibraryPage extends StatefulWidget {
  final UserModel user;
  final VideoPlaylist? currentPlaylist;

  const VideoLibraryPage({super.key, required this.user, this.currentPlaylist});

  @override
  State<VideoLibraryPage> createState() => _VideoLibraryPageState();
}

class _VideoLibraryPageState extends State<VideoLibraryPage> {
  final _searchController = TextEditingController();
  late Future<List<UserModel>> _allUsersFuture;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _allUsersFuture = _fetchAllUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<UserModel>> _fetchAllUsers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('academyId', isEqualTo: widget.user.academyId)
        .get();
    return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }

  CollectionReference get _playlistsCollection => FirebaseFirestore.instance
      .collection('academies')
      .doc(widget.user.academyId)
      .collection('video_playlists');

  CollectionReference get _videosCollection => FirebaseFirestore.instance
      .collection('academies')
      .doc(widget.user.academyId)
      .collection('videos');

  void _showAddPlaylistDialog({VideoPlaylist? playlistToEdit}) {
    final controller = TextEditingController(text: playlistToEdit?.name ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            playlistToEdit == null ? 'Nova Playlist' : 'Renomear Playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nome da Playlist'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                final data = {
                  'name': controller.text.trim(),
                  'createdAt': playlistToEdit?.createdAt ?? Timestamp.now(),
                };
                if (playlistToEdit != null) {
                  await _playlistsCollection
                      .doc(playlistToEdit.id)
                      .update(data);
                } else {
                  await _playlistsCollection.add(data);
                }
                Navigator.pop(context);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePlaylist(VideoPlaylist playlist) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Playlist?'),
        content: Text(
            'Isso excluirá a playlist "${playlist.name}" e todos os seus vídeos permanentemente. Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: errorColor),
            child: const Text('Excluir Tudo'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _recursiveDelete(playlist.id);
      showBjjSnackBar(
          context, 'Playlist e todos os seus vídeos foram excluídos.',
          type: 'success');
    } catch (e) {
      showBjjSnackBar(context, 'Erro ao excluir a playlist: $e', type: 'error');
    }
  }

  Future<void> _recursiveDelete(String playlistId) async {
    final batch = FirebaseFirestore.instance.batch();

    final videosSnapshot = await _videosCollection
        .where('playlistId', isEqualTo: playlistId)
        .get();
    for (final doc in videosSnapshot.docs) {
      final video = VideoItem.fromFirestore(doc);
      if (video.videoType == VideoType.uploaded) {
        try {
          await FirebaseStorage.instance.refFromURL(video.videoUrl).delete();
          await FirebaseStorage.instance
              .refFromURL(video.thumbnailUrl)
              .delete();
        } catch (e) {
          debugPrint(
              "Erro ao deletar arquivos do storage (provavelmente já foram removidos): $e");
        }
      }
      batch.delete(doc.reference);
    }

    batch.delete(_playlistsCollection.doc(playlistId));

    await batch.commit();
  }

  void _navigateToAddVideo() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddVideoPage(
          user: widget.user, playlistId: widget.currentPlaylist?.id),
    ));
  }

  void _showAddMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: darkSurface,
      builder: (context) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading:
                  const Icon(Icons.playlist_add_rounded, color: primaryAccent),
              title: const Text('Nova Playlist'),
              onTap: () {
                Navigator.pop(context);
                _showAddPlaylistDialog();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.video_call_outlined, color: primaryAccent),
              title: const Text('Adicionar Vídeo'),
              onTap: () {
                Navigator.pop(context);
                _navigateToAddVideo();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canManage = widget.user.role == UserRole.manager ||
        widget.user.role == UserRole.teacher;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.user.academyId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final academyData = snapshot.data?.data() as Map<String, dynamic>?;
        final bool hasAccess = academyData?['hasVideoLibraryAccess'] ?? false;

        if (!hasAccess) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: const AppBackground(
              child: SafeArea(
                child: EmptyStateWidget(
                  icon: Icons.play_disabled_rounded,
                  title: 'Recurso Premium',
                  message:
                      'As Videoaulas são um recurso exclusivo. Peça ao seu gerente para entrar em contato com o suporte para saber mais.',
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: widget.currentPlaylist != null
              ? AppBar(title: Text(widget.currentPlaylist!.name))
              : null,
          body: AppBackground(
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Buscar por título, tag ou professor...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                      ),
                    ),
                  ),
                  Expanded(
                    child: FutureBuilder<List<UserModel>>(
                      future: _allUsersFuture,
                      builder: (context, allUsersSnapshot) {
                        if (!allUsersSnapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        final allUsers = allUsersSnapshot.data!;
                        return _buildContentList(allUsers);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: canManage
              ? FloatingActionButton.extended(
                  heroTag: 'fab-${widget.currentPlaylist?.id ?? 'root'}',
                  onPressed: _showAddMenu,
                  label: const Text('Adicionar'),
                  icon: const Icon(Icons.add),
                )
              : null,
        );
      },
    );
  }

  Widget _buildContentList(List<UserModel> allUsers) {
    if (widget.currentPlaylist != null) {
      return _buildVideosGridForPlaylist(widget.currentPlaylist!.id, allUsers);
    } else {
      return _buildRootContentList(allUsers);
    }
  }

  Widget _buildRootContentList(List<UserModel> allUsers) {
    final searchQuery = _searchController.text.toLowerCase();

    return StreamBuilder<QuerySnapshot>(
      stream: _playlistsCollection.orderBy('name').snapshots(),
      builder: (context, playlistSnapshot) {
        if (playlistSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (playlistSnapshot.hasError) {
          return const EmptyStateWidget(
              icon: Icons.error, title: "Erro ao carregar playlists");
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _videosCollection
              .where('playlistId', isEqualTo: null)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, videoSnapshot) {
            if (videoSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (videoSnapshot.hasError) {
              return const EmptyStateWidget(
                  icon: Icons.error, title: "Erro ao carregar vídeos");
            }

            final playlists = playlistSnapshot.data!.docs
                .map((doc) => VideoPlaylist.fromFirestore(doc))
                .toList();
            final videos = videoSnapshot.data!.docs
                .map((doc) => VideoItem.fromFirestore(doc))
                .toList();

            final filteredPlaylists = playlists
                .where((f) => f.name.toLowerCase().contains(searchQuery))
                .toList();
            final filteredVideos = videos.where((v) {
              final titleMatches = v.title.toLowerCase().contains(searchQuery);
              final tagMatches =
                  v.tags.any((tag) => tag.toLowerCase().contains(searchQuery));
              final authorMatches =
                  v.uploadedByName.toLowerCase().contains(searchQuery);
              return titleMatches || tagMatches || authorMatches;
            }).toList();

            if (filteredPlaylists.isEmpty && filteredVideos.isEmpty) {
              return EmptyStateWidget(
                icon: searchQuery.isEmpty
                    ? Icons.video_library_outlined
                    : Icons.search_off,
                title: searchQuery.isEmpty
                    ? 'Videoteca Vazia'
                    : 'Nenhum Resultado',
              );
            }

            return AnimationLimiter(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final playlist = filteredPlaylists[index];
                          return AnimationConfiguration.staggeredList(
                            position: index,
                            duration: const Duration(milliseconds: 375),
                            child: SlideAnimation(
                              verticalOffset: 50.0,
                              child: FadeInAnimation(
                                child: _PlaylistListItem(
                                  playlist: playlist,
                                  user: widget.user,
                                  onTap: () => Navigator.of(context)
                                      .push(MaterialPageRoute(
                                    builder: (_) => VideoLibraryPage(
                                        user: widget.user,
                                        currentPlaylist: playlist),
                                  )),
                                  onEdit: () => _showAddPlaylistDialog(
                                      playlistToEdit: playlist),
                                  onDelete: () => _deletePlaylist(playlist),
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: filteredPlaylists.length,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(8.0),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 0.95,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final video = filteredVideos[index];
                          return AnimationConfiguration.staggeredGrid(
                            position: index,
                            duration: const Duration(milliseconds: 375),
                            columnCount: 2,
                            child: ScaleAnimation(
                              child: FadeInAnimation(
                                child: _VideoListItem(
                                    video: video,
                                    user: widget.user,
                                    allUsers: allUsers),
                              ),
                            ),
                          );
                        },
                        childCount: filteredVideos.length,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVideosGridForPlaylist(
      String playlistId, List<UserModel> allUsers) {
    final searchQuery = _searchController.text.toLowerCase();
    return StreamBuilder<QuerySnapshot>(
      stream: _videosCollection
          .where('playlistId', isEqualTo: playlistId)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, videoSnapshot) {
        if (videoSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (videoSnapshot.hasError) {
          return const EmptyStateWidget(
              icon: Icons.error, title: "Erro ao carregar vídeos");
        }
        final videos = videoSnapshot.data!.docs
            .map((doc) => VideoItem.fromFirestore(doc))
            .toList();
        final filteredVideos = videos.where((v) {
          final titleMatches = v.title.toLowerCase().contains(searchQuery);
          final tagMatches =
              v.tags.any((tag) => tag.toLowerCase().contains(searchQuery));
          final authorMatches =
              v.uploadedByName.toLowerCase().contains(searchQuery);
          return titleMatches || tagMatches || authorMatches;
        }).toList();

        if (filteredVideos.isEmpty) {
          return EmptyStateWidget(
            icon: searchQuery.isEmpty
                ? Icons.video_collection_outlined
                : Icons.search_off,
            title: searchQuery.isEmpty ? 'Playlist Vazia' : 'Nenhum Resultado',
          );
        }

        return AnimationLimiter(
          child: GridView.builder(
            padding: const EdgeInsets.all(8.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.95,
            ),
            itemCount: filteredVideos.length,
            itemBuilder: (context, index) {
              final video = filteredVideos[index];
              return AnimationConfiguration.staggeredGrid(
                position: index,
                duration: const Duration(milliseconds: 375),
                columnCount: 2,
                child: ScaleAnimation(
                  child: FadeInAnimation(
                    child: _VideoListItem(
                        video: video, user: widget.user, allUsers: allUsers),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _PlaylistListItem extends StatelessWidget {
  final VideoPlaylist playlist;
  final UserModel user;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PlaylistListItem(
      {required this.playlist,
      required this.user,
      required this.onTap,
      required this.onEdit,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final bool canManage =
        user.role == UserRole.manager || user.role == UserRole.teacher;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.playlist_play_rounded,
            color: primaryAccent, size: 40),
        title:
            Text(playlist.name, style: Theme.of(context).textTheme.titleMedium),
        trailing: canManage
            ? PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Renomear')),
                  const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                ],
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}

class _VideoListItem extends StatelessWidget {
  final VideoItem video;
  final UserModel user;
  final List<UserModel> allUsers;

  const _VideoListItem(
      {required this.video, required this.user, required this.allUsers});

  Future<void> _handleTap(BuildContext context) async {
    final userWatchedData = video.watchedBy[user.uid];
    int currentCount = 0;
    if (userWatchedData != null) {
      currentCount = userWatchedData['count'] ?? 0;
    }

    await FirebaseFirestore.instance
        .collection('academies')
        .doc(user.academyId)
        .collection('videos')
        .doc(video.id)
        .update({
      'watchedBy.${user.uid}': {
        'count': currentCount + 1,
        'lastWatched': Timestamp.now(),
      }
    });

    if (video.videoType == VideoType.youtube) {
      final uri = Uri.parse(video.videoUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        showBjjSnackBar(context, 'Não foi possível abrir o vídeo.',
            type: 'error');
      }
    } else {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => VideoPlayerPage(video: video),
      ));
    }
  }

  Future<void> _deleteVideo(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
            'Tem certeza que deseja excluir o vídeo "${video.title}" permanentemente?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: errorColor),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance
            .collection('academies')
            .doc(user.academyId)
            .collection('videos')
            .doc(video.id)
            .delete();

        if (video.videoType == VideoType.uploaded) {
          await FirebaseStorage.instance.refFromURL(video.videoUrl).delete();
          await FirebaseStorage.instance
              .refFromURL(video.thumbnailUrl)
              .delete();
        }

        showBjjSnackBar(context, 'Vídeo excluído com sucesso!',
            type: 'success');
      } catch (e) {
        showBjjSnackBar(context, 'Erro ao excluir o vídeo.', type: 'error');
      }
    }
  }

  void _navigateToEdit(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => AddVideoPage(
          user: user, videoToEdit: video, playlistId: video.playlistId),
    ));
  }

  void _showViewersDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _ViewersDialog(
          watchedByMap: Map<String, dynamic>.from(video.watchedBy),
          allUsers: allUsers),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool canManage =
        user.role == UserRole.manager || user.role == UserRole.teacher;
    final bool isWatched = video.watchedBy.containsKey(user.uid);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _handleTap(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 0, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: primaryAccent,
                    child: Text(
                      video.uploadedByName.isNotEmpty
                          ? video.uploadedByName[0]
                          : 'U',
                      style: const TextStyle(
                          color: primaryAccentForeground,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          video.uploadedByName,
                          style: const TextStyle(color: textHint, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (canManage)
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: textHint),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _navigateToEdit(context);
                          } else if (value == 'delete') {
                            _deleteVideo(context);
                          } else if (value == 'viewers') {
                            _showViewersDialog(context);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                              value: 'edit', child: Text('Editar')),
                          const PopupMenuItem(
                              value: 'delete', child: Text('Excluir')),
                          PopupMenuItem(
                            value: 'viewers',
                            child: Text(
                                'Visualizações (${video.watchedBy.length})'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                fit: StackFit.expand,
                children: [
                  Image.network(
                    video.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: darkSurface,
                      child: const Center(
                          child: Icon(Icons.videocam_off_outlined,
                              size: 40, color: textHint)),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                      Colors.black.withOpacity(0.0),
                      Colors.black.withOpacity(0.4)
                    ], begin: Alignment.center, end: Alignment.bottomCenter)),
                  ),
                  const Icon(Icons.play_circle_outline_rounded,
                      color: Colors.white70, size: 50),
                  if (isWatched)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20)),
                        child: const Icon(Icons.visibility,
                            color: Colors.white, size: 16),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoPlayerPage extends StatefulWidget {
  final VideoItem video;
  const VideoPlayerPage({super.key, required this.video});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    initializePlayer();
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> initializePlayer() async {
    _videoPlayerController =
        VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl));
    await _videoPlayerController.initialize();
    _createChewieController();
    setState(() {});
  }

  void _createChewieController() {
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController,
      autoPlay: true,
      looping: false,
      materialProgressColors: ChewieProgressColors(
        playedColor: primaryAccent,
        handleColor: primaryAccent,
        bufferedColor: Colors.grey.shade600,
        backgroundColor: Colors.grey.shade800,
      ),
      placeholder: Container(
        color: Colors.black,
      ),
      autoInitialize: true,
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Text(
            errorMessage,
            style: const TextStyle(color: Colors.white),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.video.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: _chewieController != null &&
                _chewieController!.videoPlayerController.value.isInitialized
            ? Chewie(
                controller: _chewieController!,
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Carregando Vídeo...'),
                ],
              ),
      ),
    );
  }
}

class AddVideoPage extends StatefulWidget {
  final UserModel user;
  final VideoItem? videoToEdit;
  final String? playlistId;

  const AddVideoPage(
      {super.key, required this.user, this.videoToEdit, this.playlistId});

  @override
  State<AddVideoPage> createState() => _AddVideoPageState();
}

class _AddVideoPageState extends State<AddVideoPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _videoUrlController = TextEditingController();
  final _tagsController = TextEditingController();

  VideoType _videoType = VideoType.youtube;
  XFile? _pickedVideo;
  XFile? _pickedThumbnail;

  String? _networkThumbnailUrl;
  bool _isLoading = false;
  double _uploadProgress = 0;

  bool get isEditing => widget.videoToEdit != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final video = widget.videoToEdit!;
      _titleController.text = video.title;
      _descriptionController.text = video.description;
      _videoUrlController.text = video.videoUrl;
      _tagsController.text = video.tags.join(', ');
      _networkThumbnailUrl = video.thumbnailUrl;
      _videoType = video.videoType;
    }
    _videoUrlController.addListener(_extractYoutubeThumbnail);
  }

  @override
  void dispose() {
    _videoUrlController.removeListener(_extractYoutubeThumbnail);
    _titleController.dispose();
    _descriptionController.dispose();
    _videoUrlController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _extractYoutubeThumbnail() {
    if (_videoType != VideoType.youtube) return;
    final url = _videoUrlController.text;
    String? videoId;

    if (url.contains("youtube.com/watch?v=")) {
      videoId = Uri.parse(url).queryParameters['v'];
    } else if (url.contains("youtu.be/")) {
      videoId = url.substring(url.lastIndexOf('/') + 1);
    }

    if (videoId != null && videoId.isNotEmpty) {
      setState(() {
        _networkThumbnailUrl =
            'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
      });
    } else {
      setState(() {
        _networkThumbnailUrl = null;
      });
    }
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _pickedVideo = video;
      });
    }
  }

  Future<void> _pickThumbnail() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
    if (image != null) {
      setState(() {
        _pickedThumbnail = image;
      });
    }
  }

  Future<String> _uploadFile(XFile file, String path) async {
    final ref = FirebaseStorage.instance.ref(path);
    final uploadTask = ref.putData(await file.readAsBytes());

    uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      if (mounted) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      }
    });

    await uploadTask;
    return await ref.getDownloadURL();
  }

  Future<void> _saveVideo() async {
    if (!_formKey.currentState!.validate()) return;

    if (_videoType == VideoType.youtube && _networkThumbnailUrl == null) {
      showBjjSnackBar(
          context, "Por favor, insira um link de vídeo do YouTube válido.",
          type: 'error');
      return;
    }

    if (_videoType == VideoType.uploaded &&
        _pickedVideo == null &&
        !isEditing) {
      showBjjSnackBar(context, "Por favor, selecione um vídeo para enviar.",
          type: 'error');
      return;
    }

    if (_videoType == VideoType.uploaded &&
        _pickedThumbnail == null &&
        !isEditing) {
      showBjjSnackBar(
          context, "Por favor, selecione uma imagem de capa (thumbnail).",
          type: 'error');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String finalVideoUrl = '';
      String finalThumbnailUrl = '';
      int? videoSizeBytes;

      if (_videoType == VideoType.youtube) {
        finalVideoUrl = _videoUrlController.text.trim();
        finalThumbnailUrl = _networkThumbnailUrl!;
      } else {
        if (isEditing) {
          finalVideoUrl = widget.videoToEdit!.videoUrl;
          finalThumbnailUrl = widget.videoToEdit!.thumbnailUrl;
          videoSizeBytes = widget.videoToEdit!.fileSizeBytes;
        }

        if (_pickedThumbnail != null) {
          final thumbName = 'thumb_${DateTime.now().millisecondsSinceEpoch}';
          final thumbPath =
              'academy_videos/${widget.user.academyId}/thumbnails/$thumbName';
          finalThumbnailUrl = await _uploadFile(_pickedThumbnail!, thumbPath);
        }

        if (_pickedVideo != null) {
          videoSizeBytes = await _pickedVideo!.length();
          final videoName = 'video_${DateTime.now().millisecondsSinceEpoch}';
          final videoPath =
              'academy_videos/${widget.user.academyId}/videos/$videoName';
          finalVideoUrl = await _uploadFile(_pickedVideo!, videoPath);
        }
      }

      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim().capitalizeWords())
          .where((t) => t.isNotEmpty)
          .toSet()
          .toList();

      final videoData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'videoUrl': finalVideoUrl,
        'thumbnailUrl': finalThumbnailUrl,
        'videoType': _videoType == VideoType.uploaded ? 'uploaded' : 'youtube',
        'tags': tags,
        'playlistId':
            isEditing ? widget.videoToEdit!.playlistId : widget.playlistId,
        'uploadedByUid':
            isEditing ? widget.videoToEdit!.uploadedByUid : widget.user.uid,
        'uploadedByName':
            isEditing ? widget.videoToEdit!.uploadedByName : widget.user.name,
        'createdAt': isEditing
            ? widget.videoToEdit!.createdAt
            : FieldValue.serverTimestamp(),
        'watchedBy': isEditing ? widget.videoToEdit!.watchedBy : {},
        'fileSizeBytes': videoSizeBytes,
      };

      final collectionRef = FirebaseFirestore.instance
          .collection('academies')
          .doc(widget.user.academyId)
          .collection('videos');

      if (isEditing) {
        await collectionRef.doc(widget.videoToEdit!.id).update(videoData);
      } else {
        await collectionRef.add(videoData);
      }

      Navigator.of(context).pop();
      showBjjSnackBar(context, 'Vídeo salvo com sucesso!', type: 'success');
    } catch (e) {
      showBjjSnackBar(context, 'Erro ao salvar o vídeo: $e', type: 'error');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _uploadProgress = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Vídeo' : 'Adicionar Vídeo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _isLoading ? null : _saveVideo,
            tooltip: 'Salvar',
          )
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: _isLoading
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LinearProgressIndicator(
                            value:
                                _uploadProgress > 0 ? _uploadProgress : null),
                        const SizedBox(height: 20),
                        const Text("Enviando vídeo, por favor aguarde..."),
                      ],
                    ),
                  ),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      TextFormField(
                        controller: _titleController,
                        textCapitalization: TextCapitalization.words,
                        decoration:
                            const InputDecoration(labelText: 'Título do Vídeo'),
                        validator: (v) =>
                            v!.trim().isEmpty ? 'O título é obrigatório' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                            labelText: 'Descrição', alignLabelWithHint: true),
                        maxLines: 3,
                        validator: (v) => v!.trim().isEmpty
                            ? 'A descrição é obrigatória'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<VideoType>(
                        segments: const [
                          ButtonSegment(
                              value: VideoType.youtube,
                              label: Text('Link YouTube'),
                              icon: Icon(Icons.link)),
                          ButtonSegment(
                              value: VideoType.uploaded,
                              label: Text('Enviar Vídeo'),
                              icon: Icon(Icons.upload_file)),
                        ],
                        selected: {_videoType},
                        onSelectionChanged: (newSelection) {
                          setState(() {
                            _videoType = newSelection.first;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_videoType == VideoType.youtube)
                        TextFormField(
                          controller: _videoUrlController,
                          decoration: const InputDecoration(
                              labelText: 'Link do Vídeo (YouTube)'),
                          validator: (v) => v!.trim().isEmpty
                              ? 'O link do vídeo é obrigatório'
                              : null,
                        )
                      else ...[
                        OutlinedButton.icon(
                          onPressed: _pickThumbnail,
                          icon: const Icon(Icons.image_outlined),
                          label: Text(_pickedThumbnail != null
                              ? 'Trocar Capa'
                              : 'Selecionar Capa (Thumbnail)'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickVideo,
                          icon: const Icon(Icons.video_library_outlined),
                          label: Text(_pickedVideo != null
                              ? 'Trocar Vídeo'
                              : 'Selecionar Vídeo do Celular'),
                        ),
                      ],
                      const SizedBox(height: 16),
                      if (_networkThumbnailUrl != null &&
                          _videoType == VideoType.youtube)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(_networkThumbnailUrl!),
                        ),
                      if (_pickedThumbnail != null &&
                          _videoType == VideoType.uploaded)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: kIsWeb
                              ? FutureBuilder<Uint8List>(
                                  future: _pickedThumbnail!.readAsBytes(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      return Image.memory(snapshot.data!,
                                          fit: BoxFit.cover);
                                    }
                                    return const SizedBox(
                                        height: 200,
                                        child: Center(
                                            child:
                                                CircularProgressIndicator()));
                                  },
                                )
                              : Image.file(File(_pickedThumbnail!.path),
                                  fit: BoxFit.cover),
                        ),
                      if (_pickedVideo != null &&
                          _videoType == VideoType.uploaded)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                              'Vídeo selecionado: ${_pickedVideo!.name}',
                              style: const TextStyle(color: textHint)),
                        ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _tagsController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                            labelText: 'Tags (separadas por vírgula)'),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _ViewersDialog extends StatelessWidget {
  final Map<String, dynamic> watchedByMap;
  final List<UserModel> allUsers;

  const _ViewersDialog({required this.watchedByMap, required this.allUsers});

  @override
  Widget build(BuildContext context) {
    final allUsersMap = {for (var user in allUsers) user.uid: user};

    final viewers = watchedByMap.entries.map((entry) {
      final user = allUsersMap[entry.key];
      final viewData = entry.value as Map<String, dynamic>;
      final lastWatched = (viewData['lastWatched'] as Timestamp?)?.toDate();
      return {
        'name': user?.name ?? 'Usuário desconhecido',
        'count': viewData['count'] ?? 0,
        'lastWatched': lastWatched,
      };
    }).toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    return AlertDialog(
      title: const Text('Visualizações'),
      content: SizedBox(
        width: double.maxFinite,
        child: viewers.isEmpty
            ? const Center(child: Text('Ninguém visualizou este vídeo ainda.'))
            : ListView.builder(
                shrinkWrap: true,
                itemCount: viewers.length,
                itemBuilder: (context, index) {
                  final viewer = viewers[index];
                  final lastWatchedDate = viewer['lastWatched'] as DateTime?;
                  return ListTile(
                    title: Text(viewer['name'] as String),
                    leading: const Icon(Icons.person_outline),
                    subtitle: lastWatchedDate != null
                        ? Text(
                            'Última vez: ${DateFormat('dd/MM/yy \'às\' HH:mm').format(lastWatchedDate)}')
                        : null,
                    trailing: Text('${viewer['count']}x',
                        style: const TextStyle(color: textHint)),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        )
      ],
    );
  }
}
