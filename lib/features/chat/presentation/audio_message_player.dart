import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/api/api_client.dart';

class AudioMessagePlayer extends ConsumerStatefulWidget {
  final String audioUrl;
  final bool isMe;

  const AudioMessagePlayer({
    super.key,
    required this.audioUrl,
    required this.isMe,
  });

  @override
  ConsumerState<AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends ConsumerState<AudioMessagePlayer> {
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  bool _isDownloading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _localPath;

  @override
  void dispose() {
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _initPlayer() {
    if (_audioPlayer != null) return;

    _audioPlayer = AudioPlayer();

    _audioPlayer!.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer!.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });

    _audioPlayer!.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });

    _audioPlayer!.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  Future<void> _togglePlay() async {
    _initPlayer();

    if (_isPlaying) {
      await _audioPlayer!.pause();
      return;
    }

    await AudioPlayer.global.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
      ),
    );

    // Wenn lokaler Pfad schon existiert, spiele direkt ab
    if (_localPath != null && File(_localPath!).existsSync()) {
      await _audioPlayer!.play(DeviceFileSource(_localPath!));
      return;
    }

    // Ansonsten lade herunter (Dio nutzt den Zertifikats-Bypass)
    setState(() {
      _isDownloading = true;
    });

    try {
      final dio = ref.read(apiClientProvider);
      final dir = await getTemporaryDirectory();

      // Dateiname aus der URL extrahieren oder hashen
      final fileName = widget.audioUrl.split('/').last;
      final savePath = '${dir.path}/$fileName';

      final fullUrl =
          widget.audioUrl.startsWith('http') &&
              !widget.audioUrl.startsWith('http://localhost')
          ? widget.audioUrl
          : 'https://rhz.internet-box.ch:8443/storage/${widget.audioUrl.split('storage/').last}';

      if (!File(savePath).existsSync()) {
        await dio.download(fullUrl, savePath);
      }

      _localPath = savePath;
      await _audioPlayer!.play(DeviceFileSource(_localPath!));
    } catch (e) {
      debugPrint("Audio download error: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Audio Fehler: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isMe ? Colors.white : Colors.black87;
    final iconColor = widget.isMe ? Colors.white : Colors.teal;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _isDownloading
            ? Padding(
                padding: const EdgeInsets.all(12.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: iconColor,
                    strokeWidth: 2,
                  ),
                ),
              )
            : IconButton(
                icon: Icon(
                  _isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  color: iconColor,
                  size: 32,
                ),
                onPressed: _togglePlay,
              ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SliderTheme(
              data: SliderThemeData(
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                trackHeight: 2,
                activeTrackColor: widget.isMe ? Colors.white : Colors.teal,
                inactiveTrackColor: widget.isMe
                    ? Colors.white38
                    : Colors.teal.withOpacity(0.3),
                thumbColor: iconColor,
              ),
              child: SizedBox(
                width: 120,
                child: Slider(
                  min: 0,
                  max: _duration.inMilliseconds.toDouble() > 0
                      ? _duration.inMilliseconds.toDouble()
                      : 1.0,
                  value: _position.inMilliseconds.toDouble().clamp(
                    0,
                    _duration.inMilliseconds.toDouble() > 0
                        ? _duration.inMilliseconds.toDouble()
                        : 1.0,
                  ),
                  onChanged: (val) {
                    if (_audioPlayer != null) {
                      _audioPlayer!.seek(Duration(milliseconds: val.toInt()));
                    }
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                _formatDuration(_position),
                style: TextStyle(color: textColor, fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
