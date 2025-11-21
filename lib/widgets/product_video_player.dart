import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class ProductVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const ProductVideoPlayer({super.key, required this.videoUrl});

  @override
  State<ProductVideoPlayer> createState() => _ProductVideoPlayerState();
}

class _ProductVideoPlayerState extends State<ProductVideoPlayer> {
  late VideoPlayerController _controller;
  late Future<void> _initializeVideoPlayerFuture;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void didUpdateWidget(ProductVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the video URL changes, we need to create a new controller
    if (widget.videoUrl != oldWidget.videoUrl) {
      // Dispose the old controller and chewie instance first
      _chewieController?.dispose();
      _controller.dispose();
      // Initialize the new controller
      _initializeController();
    }
  }

  void _initializeController() {
    if (widget.videoUrl.startsWith('http')) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    } else {
      _controller = VideoPlayerController.file(File(widget.videoUrl));
    }
    _initializeVideoPlayerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    // Ensure the controller and chewie are disposed when the widget is removed
    _chewieController?.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializeVideoPlayerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError || _controller.value.hasError) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 48),
                  SizedBox(height: 8),
                  Text('ไม่สามารถเล่นวิดีโอได้', style: TextStyle(color: Colors.red)),
                ],
              ),
            );
          }

          // Create the Chewie controller only after initialization is complete
          _chewieController ??= ChewieController(
            videoPlayerController: _controller,
            autoPlay: false,
            looping: false,
            aspectRatio: _controller.value.aspectRatio > 0 ? _controller.value.aspectRatio : 16 / 9,
          );
          return Chewie(controller: _chewieController!);
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
