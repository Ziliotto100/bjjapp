// lib/video_picker_dialog.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models.dart';
import 'app_theme.dart';
import 'common_widgets.dart';

class VideoPickerDialog extends StatefulWidget {
  final String academyId;

  const VideoPickerDialog({super.key, required this.academyId});

  @override
  State<VideoPickerDialog> createState() => _VideoPickerDialogState();
}

class _VideoPickerDialogState extends State<VideoPickerDialog> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Anexar Vídeo da Videoteca'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Buscar vídeo por título...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('academies')
                    .doc(widget.academyId)
                    .collection('videos')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.data!.docs.isEmpty) {
                    return const EmptyStateWidget(
                      icon: Icons.video_library_outlined,
                      title: 'Videoteca Vazia',
                    );
                  }

                  final allVideos = snapshot.data!.docs
                      .map((doc) => VideoItem.fromFirestore(doc))
                      .toList();

                  final filteredVideos = allVideos.where((video) {
                    return video.title
                        .toLowerCase()
                        .contains(_searchController.text.toLowerCase());
                  }).toList();

                  return ListView.builder(
                    itemCount: filteredVideos.length,
                    itemBuilder: (context, index) {
                      final video = filteredVideos[index];
                      return Card(
                        child: ListTile(
                          leading: Image.network(video.thumbnailUrl,
                              width: 56, fit: BoxFit.cover),
                          title: Text(video.title),
                          subtitle: Text(video.uploadedByName),
                          onTap: () {
                            Navigator.of(context).pop(video);
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
