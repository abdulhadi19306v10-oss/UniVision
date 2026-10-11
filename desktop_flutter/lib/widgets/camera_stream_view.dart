import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../theme.dart';

// ponytail: native low-overhead MJPEG video stream widget using standard dart:io HttpClient
class CameraStreamView extends StatefulWidget {
  final String streamUrl;
  final bool isRunning;
  final double currentFps;

  const CameraStreamView({
    super.key,
    required this.streamUrl,
    required this.isRunning,
    this.currentFps = 0.0,
  });

  @override
  State<CameraStreamView> createState() => _CameraStreamViewState();
}

class _CameraStreamViewState extends State<CameraStreamView> {
  Uint8List? _currentFrame;
  HttpClient? _httpClient;
  StreamSubscription? _streamSub;
  bool _isConnected = false;
  Timer? _reconnectTimer;

  @override
  void initState() {
    super.initState();
    if (widget.isRunning) {
      _startStream();
    }
  }

  @override
  void didUpdateWidget(covariant CameraStreamView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning != oldWidget.isRunning) {
      if (widget.isRunning) {
        _startStream();
      } else {
        _stopStream();
      }
    }
  }

  @override
  void dispose() {
    _stopStream();
    _reconnectTimer?.cancel();
    super.dispose();
  }

  void _stopStream() {
    _streamSub?.cancel();
    _streamSub = null;
    _httpClient?.close(force: true);
    _httpClient = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _isConnected = false;
    _currentFrame = null;
  }


  Future<void> _startStream() async {
    _stopStream();
    try {
      _httpClient = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final request = await _httpClient!.getUrl(Uri.parse(widget.streamUrl));
      final response = await request.close();

      if (response.statusCode != 200) {
        _scheduleReconnect();
        return;
      }

      if (mounted) setState(() => _isConnected = true);

      final BytesBuilder builder = BytesBuilder(copy: false);

      _streamSub = response.listen(
        (chunk) {
          builder.add(chunk);
          final bytes = builder.takeBytes();

          // Find JPEG Start of Image (0xFF, 0xD8) and End of Image (0xFF, 0xD9)
          int start = -1;
          int end = -1;

          for (int i = 0; i < bytes.length - 1; i++) {
            if (start == -1 && bytes[i] == 0xFF && bytes[i + 1] == 0xD8) {
              start = i;
            }
            if (start != -1 && bytes[i] == 0xFF && bytes[i + 1] == 0xD9) {
              end = i + 2;
              break;
            }
          }

          if (start != -1 && end != -1 && end > start) {
            // High-performance zero-copy view over the byte array
            final frameData = Uint8List.sublistView(bytes, start, end);
            if (end < bytes.length) {
              builder.add(bytes.sublist(end));
            }
            if (mounted) {
              setState(() {
                _currentFrame = frameData;
              });
            }
          } else {
            // Keep buffering until complete frame arrives (guard against overflow > 1MB)
            if (bytes.length < 1024 * 1024) {
              builder.add(bytes);
            }
          }
        },
        onError: (_) {
          _scheduleReconnect();
        },
        onDone: () {
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!mounted || !widget.isRunning) return;
    setState(() => _isConnected = false);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && widget.isRunning) _startStream();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceSunken,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Live Video Feed or Placeholder
            if (widget.isRunning && _currentFrame != null)
              Image.memory(
                _currentFrame!,
                gaplessPlayback: true,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.low,
                width: double.infinity,
                height: double.infinity,
              )

            else if (widget.isRunning)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primary),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isConnected ? 'Initializing neural inference pipeline...' : 'Connecting to AI camera stream...',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              )
            else
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_off_rounded, size: 52, color: AppTheme.textMuted),
                    SizedBox(height: 12),
                    Text(
                      'AI Camera Feed Inactive',
                      style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Click "Start Camera Stream" below to activate YuNet face tracking and SFace recognition.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),

            // Top Status Badges
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.isRunning ? AppTheme.success : AppTheme.error,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.isRunning ? 'LIVE AI INFERENCE' : 'STANDBY',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

            if (widget.isRunning)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppTheme.border.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    'FPS: ${widget.currentFps.toStringAsFixed(1)}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
