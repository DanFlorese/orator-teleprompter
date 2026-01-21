import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:orator_teleprompter/core/theme.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart'; // Asegúrate de tenerlo en pubspec.yaml
import 'package:orator_teleprompter/views/prompter/video_player_view.dart';

class VideoGalleryView extends StatefulWidget {
  const VideoGalleryView({super.key});

  @override
  State<VideoGalleryView> createState() => _VideoGalleryViewState();
}

class _VideoGalleryViewState extends State<VideoGalleryView> {
  List<FileSystemEntity> _videos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocalVideos();
  }

  Future<void> _loadLocalVideos() async {
    setState(() => _isLoading = true);
    final directory = await getApplicationDocumentsDirectory();
    final List<FileSystemEntity> files = directory.listSync();
    
    // Filtramos mp4 y ordenamos por fecha de creación (más reciente primero)
    final mp4Files = files.where((file) => file.path.endsWith('.mp4')).toList();
    mp4Files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));

    setState(() {
      _videos = mp4Files;
      _isLoading = false;
    });
  }

  // Función para borrar desde la galería
  Future<void> _deleteVideo(FileSystemEntity file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: graySurface,
        title: const Text('Delete video?', style: TextStyle(color: Colors.white)),
        content: const Text('This action cannot be undone.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('DELETE', style: TextStyle(color: redOrator))
          ),
        ],
      ),
    );

    if (confirm == true) {
      await file.delete();
      _loadLocalVideos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: blackBackground,
      appBar: AppBar(
        title: const Text('MY RECORDINGS', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLocalVideos)
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: redOrator))
        : _videos.isEmpty 
          ? _buildEmptyGallery()
          : _buildVideoGrid(),
    );
  }

  Widget _buildEmptyGallery() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library_outlined, size: 80, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 20),
          const Text('No videos recorded yet', style: TextStyle(color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _buildVideoGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(15),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 0.8,
      ),
      itemCount: _videos.length,
      itemBuilder: (context, index) {
        final videoFile = _videos[index];
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => VideoPlayerView(videoPath: videoFile.path))
          ).then((_) => _loadLocalVideos()), // Recarga al volver por si borró dentro
          onLongPress: () => _deleteVideo(videoFile),
          child: _buildVideoCard(videoFile),
        );
      },
    );
  }

  Widget _buildVideoCard(FileSystemEntity file) {
    return Container(
      decoration: BoxDecoration(
        color: graySurface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VideoThumbnailWidget(videoPath: file.path), // Widget de miniatura
                  Container(color: Colors.black26),
                  const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 40)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                file.path.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget auxiliar para las miniaturas
class VideoThumbnailWidget extends StatelessWidget {
  final String videoPath;
  const VideoThumbnailWidget({super.key, required this.videoPath});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: VideoThumbnail.thumbnailData(video: videoPath, imageFormat: ImageFormat.JPEG, quality: 50),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Image.memory(snapshot.data!, fit: BoxFit.cover);
        }
        return Container(color: Colors.black);
      },
    );
  }
}