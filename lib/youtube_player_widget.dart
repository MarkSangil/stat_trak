import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

String? extractYouTubeId(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;

  if (uri.queryParameters.containsKey('v')) {
    return uri.queryParameters['v'];
  }

  if (uri.host.contains('youtu.be')) {
    return uri.pathSegments.first;
  }

  return null;
}

class YouTubeVideoPlayer extends StatefulWidget {
  final String url;

  const YouTubeVideoPlayer({super.key, required this.url});

  @override
  State<YouTubeVideoPlayer> createState() => _YouTubeVideoPlayerState();
}

class _YouTubeVideoPlayerState extends State<YouTubeVideoPlayer> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    final videoId = extractYouTubeId(widget.url) ?? '';
    debugPrint('📺 Extracted video ID: $videoId');

    _controller = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        enableKeyboard: true,
        playsInline: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const Text('YouTube player only works on web for now.');
    }

    return YoutubePlayerScaffold(
      controller: _controller,
      aspectRatio: 16 / 9,
      builder: (context, player) {
        return player;
      },
    );
  }
}
