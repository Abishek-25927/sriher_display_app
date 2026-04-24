import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

// ─── Constants ────────────────────────────────────────────────────────────────

const _kApiUrl = 'https://display.sriher.com/Dashboardview';
const _kApiKey =
    '933cdb13cb54e31e694f82bf7f75f0144a9495036db0243b85dd855be53c06f2';
const _kBaseUrl = 'https://display.sriher.com/uploads/';

// ─── Models ───────────────────────────────────────────────────────────────────

class _DashboardData {
  final int totalDevice;
  final int totTemp;
  final int totLocation;
  final int imgFile;
  final int vidFile;
  final List<String> imageUrls;
  final List<String> videoUrls;
  final List<Map<String, dynamic>> deviceList;
  final List<Map<String, dynamic>> tempList;
  final List<Map<String, dynamic>> locationList;
  final List<Map<String, dynamic>> overview;

  _DashboardData({
    required this.totalDevice,
    required this.totTemp,
    required this.totLocation,
    required this.imgFile,
    required this.vidFile,
    required this.imageUrls,
    required this.videoUrls,
    required this.deviceList,
    required this.tempList,
    required this.locationList,
    required this.overview,
  });

  factory _DashboardData.fromJson(Map<String, dynamic> json) {
    final imgs = (json['img'] as List? ?? [])
        .map((e) => '$_kBaseUrl${e['file_name']}')
        .toList();

    final vids = json['vid'] as List?;
    final vidUrls = (vids ?? [])
        .map((e) => '$_kBaseUrl${e['file_name']}')
        .toList();

    // Add vinci videos if any (fallback/additional)
    if (json['vinci'] != null && (json['vinci'] as List).isNotEmpty) {
      vidUrls.addAll(
        (json['vinci'] as List).map((e) => '$_kBaseUrl${e['file_name']}'),
      );
    }

    return _DashboardData(
      totalDevice: json['totaldevice'] ?? 0,
      totTemp: json['tot_temp'] ?? 0,
      totLocation: json['tot_location'] ?? 0,
      imgFile: json['img_file'] ?? 0,
      vidFile: json['vid_file'] ?? 0,
      imageUrls: imgs,
      videoUrls: vidUrls,
      deviceList: _maps(json['deviceList']),
      tempList: _maps(json['templist']),
      locationList: _maps(json['locationlist']),
      overview: _maps(json['overview']),
    );
  }

  static List<Map<String, dynamic>> _maps(dynamic raw) =>
      (raw as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
}

// ─── Widget ───────────────────────────────────────────────────────────────────

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});
  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Animation<double>> _cardAnimations = [];

  // API state
  _DashboardData? _data;
  bool _loading = true;
  String? _error;

  // Slideshow
  int _slideIndex = 0;
  Timer? _slideTimer;
  late final PageController _pageCtrl;

  // Video (media_kit)
  late final Player _player = Player(
    configuration: const PlayerConfiguration(
      bufferSize: 1024 * 1024 * 16, // 16MB buffer
    ),
  );
  late final VideoController _videoController = VideoController(_player);
  bool _videoReady = false;
  bool _hasEverPlayed = true; // Autoplay by default
  bool _showControls = false; // Hide controls by default for signage
  String? _videoError; // non-null when init failed
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _bufferingSub;
  StreamSubscription? _errorSub;
  Timer? _videoReadyTimer;

  // Bottom table
  String _selectedCategory = 'Devices';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    for (int i = 0; i < 8; i++) {
      final s = i * 0.08;
      final e = (s + 0.4).clamp(0.0, 1.0);
      _cardAnimations.add(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(s, e, curve: Curves.easeOutBack),
        ),
      );
    }
    _controller.forward();
    _pageCtrl = PageController(initialPage: 5000);
    _fetchDashboard();
  }

  // ──────────────────── API ─────────────────────────────────────────────────

  Future<void> _fetchDashboard() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await http.post(
        Uri.parse(_kApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'api_key': _kApiKey}),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        if (body['status'] == 'Success') {
          final d = _DashboardData.fromJson(body['data']);
          setState(() {
            _data = d;
            _loading = false;
          });
          _startSlideshow(d.imageUrls.length);
          _initVideo(d.videoUrls);
          return;
        }
      }
      setState(() {
        _loading = false;
        _error = 'Server error';
      });
    } catch (ex) {
      setState(() {
        _loading = false;
        _error = ex.toString();
      });
    }
  }

  void _startSlideshow(int count) {
    _slideTimer?.cancel();
    if (count == 0) return;
    _slideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      if (_pageCtrl.hasClients) {
        final next = _pageCtrl.page!.round() + 1;
        _pageCtrl.animateToPage(
          next,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
        setState(() => _slideIndex = next % count);
      }
    });
  }

  void _initVideo(List<String> urls) {
    if (urls.isEmpty) return;
    setState(() {
      _videoReady = false;
      _hasEverPlayed = false;
      _videoError = null;
    });

    try {
      // Cancel any previous subscriptions / timers
      _durationSub?.cancel();
      _bufferingSub?.cancel();
      _videoReadyTimer?.cancel();
      _errorSub?.cancel();

      // Open a playlist for the slideshow
      final playlist = Playlist(urls.map((u) => Media(u)).toList());

      _errorSub = _player.stream.error.listen((err) {
        debugPrint('MediaKit Error: $err');
        if (mounted) {
          setState(() => _videoError = err.toString());
        }
      });

      _player.open(playlist, play: true);
      _hasEverPlayed = true;
      _videoReady = true; // Set ready immediately
      _player.setPlaylistMode(PlaylistMode.loop);
      _player.setVolume(0.0);

      void markReady() {
        if (!_videoReady && mounted) {
          setState(() => _videoReady = true);
          _durationSub?.cancel();
          _bufferingSub?.cancel();
          _videoReadyTimer?.cancel();
          _durationSub = null;
          _bufferingSub = null;
          _videoReadyTimer = null;
        }
      }

      _durationSub = _player.stream.duration.listen((dur) {
        if (dur > Duration.zero) markReady();
      });

      _bufferingSub = _player.stream.buffering.listen((buffering) {
        if (!buffering) markReady();
      });

      _videoReadyTimer = Timer(const Duration(seconds: 8), markReady);
    } catch (err) {
      debugPrint('Video init error: $err');
      setState(() => _videoError = err.toString());
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _bufferingSub?.cancel();
    _errorSub?.cancel();
    _videoReadyTimer?.cancel();
    _controller.dispose();
    _slideTimer?.cancel();
    _pageCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  // ──────────────────── Build ───────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.orange),
            SizedBox(height: 14),
            Text('Loading Dashboard…', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, color: Colors.redAccent, size: 48),
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchDashboard,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final d = _data!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _topCards(d),
          const SizedBox(height: 16),
          _midSection(d),
          const SizedBox(height: 28),
          _bottomSection(d),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ──────────────────── Top cards ───────────────────────────────────────────

  Widget _topCards(_DashboardData d) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _menuCard(
            'DEVICE DETAILS',
            Icons.tv,
            '${d.totalDevice}',
            const LinearGradient(
              colors: [Color(0xFFFF9800), Color(0xFFFFB74D)],
            ),
            _cardAnimations[0],
          ),
          _menuCard(
            'TEMPLATE DETAILS',
            Icons.dashboard_customize,
            '${d.totTemp}',
            const LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFF64B5F6)],
            ),
            _cardAnimations[1],
          ),
          _menuCard(
            'LOCATION',
            Icons.location_on,
            '${d.totLocation}',
            const LinearGradient(
              colors: [Color(0xFF388E3C), Color(0xFF81C784)],
            ),
            _cardAnimations[2],
          ),
          _menuCard(
            'FILES',
            Icons.insert_drive_file,
            '${d.imgFile}',
            const LinearGradient(
              colors: [Color(0xFF546E7A), Color(0xFF90A4AE)],
            ),
            _cardAnimations[3],
          ),
        ],
      ),
    );
  }

  Widget _menuCard(
    String title,
    IconData icon,
    String count,
    LinearGradient grad,
    Animation<double> anim,
  ) {
    return Expanded(
      child: ScaleTransition(
        scale: anim,
        child: Container(
          height: 80,
          margin: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            gradient: grad,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black45, // Darker shadow
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        count,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────── Mid section ─────────────────────────────────────────

  Widget _midSection(_DashboardData d) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left — image slideshow (no header text)
          Expanded(
            child: ScaleTransition(
              scale: _cardAnimations[4],
              child: _card(child: _slideshow(d.imageUrls), height: 420),
            ),
          ),
          const SizedBox(width: 20),
          // Right — video (no header text)
          Expanded(
            child: ScaleTransition(
              scale: _cardAnimations[5],
              child: _card(child: _videoPanel(d.videoUrls), height: 420),
            ),
          ),
        ],
      ),
    );
  }

  // Bare white card container
  Widget _card({required Widget child, double? height}) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35), // Big card is black/transparent
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // ── Slideshow ─────────────────────────────────────────────────────────────

  Widget _slideshow(List<String> urls) {
    if (urls.isEmpty) {
      return const Center(
        child: Text('No images', style: TextStyle(color: Colors.grey)),
      );
    }
    return Stack(
      children: [
        // Pages — 5 px padding on all sides
        PageView.builder(
          controller: _pageCtrl,
          onPageChanged: (i) => setState(() => _slideIndex = i % urls.length),
          itemCount: 10000,
          itemBuilder: (_, i) {
            final index = i % urls.length;
            return Padding(
              padding: const EdgeInsets.all(5),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  urls[index],
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: Colors.grey.shade100,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade100,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.grey.shade400,
                      size: 40,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        // Prev arrow
        Positioned(
          left: 6,
          top: 0,
          bottom: 0,
          child: Center(
            child: _arrowBtn(
              icon: Icons.chevron_left,
              onTap: () {
                final p = _pageCtrl.page!.round() - 1;
                _pageCtrl.animateToPage(
                  p,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              },
            ),
          ),
        ),
        // Next arrow
        Positioned(
          right: 6,
          top: 0,
          bottom: 0,
          child: Center(
            child: _arrowBtn(
              icon: Icons.chevron_right,
              onTap: () {
                final n = (_slideIndex + 1) % urls.length;
                _pageCtrl.animateToPage(
                  n,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              },
            ),
          ),
        ),
        // Dot indicators
        Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              urls.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: i == _slideIndex ? 16 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: i == _slideIndex ? Colors.orange : Colors.white70,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _arrowBtn({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black38,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  // ── Video panel ───────────────────────────────────────────────────────────

  Widget _videoPanel(List<String> urls) {
    // Error state — show message with retry button
    if (_videoError != null) {
      return _videoPanelPlaceholder(
        urls.isNotEmpty ? urls.first : null,
        'Video Error: $_videoError',
        showRetry: true,
        onRetry: () => _initVideo(urls),
      );
    }

    // Video is ready — VLC-style controls (media_kit)
    return StreamBuilder<bool>(
      stream: _player.stream.playing,
      builder: (context, playingSnap) {
        final isPlaying = playingSnap.data ?? false;

        // Always treat as has ever played if we are autoplaying
        if (!_hasEverPlayed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _hasEverPlayed = true);
          });
        }

        return StreamBuilder<Duration>(
          stream: _player.stream.position,
          builder: (context, positionSnap) {
            final position = positionSnap.data ?? Duration.zero;

            return StreamBuilder<Duration>(
              stream: _player.stream.duration,
              builder: (context, durationSnap) {
                final duration = durationSnap.data ?? Duration.zero;

                return StreamBuilder<double>(
                  stream: _player.stream.volume,
                  builder: (context, volumeSnap) {
                    final volume = volumeSnap.data ?? 100.0;
                    final isMuted = volume == 0.0;
                    final progress = duration.inMilliseconds > 0
                        ? (position.inMilliseconds / duration.inMilliseconds)
                              .clamp(0.0, 1.0)
                        : 0.0;

                    return GestureDetector(
                      onTap: () {
                        setState(() => _showControls = !_showControls);
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Stack(
                          children: [
                            // ── Video frame (rendered by media_kit) ──
                            Positioned.fill(
                              child: Container(
                                color: Colors.black,
                                child: Video(
                                  controller: _videoController,
                                  fill: Colors.black,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),

                            // ── Gradient overlay (when controls visible) ──
                            if (_showControls)
                              Positioned.fill(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.transparent,
                                        Colors.black54,
                                      ],
                                      stops: [0.0, 0.5, 1.0],
                                    ),
                                  ),
                                ),
                              ),

                            // ── Big centered Play/Pause (only while controls showing) ──
                            if (_showControls)
                              Center(
                                child: GestureDetector(
                                  onTap: () => _player.playOrPause(),
                                  child: Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.55),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white54,
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                      color: Colors.white,
                                      size: 42,
                                    ),
                                  ),
                                ),
                              ),

                            // ── Bottom control bar (only while playing & controls showing) ──
                            if (_hasEverPlayed && _showControls)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  color: Colors.black54,
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    4,
                                    8,
                                    6,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Scrub slider
                                      SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 3,
                                          thumbShape:
                                              const RoundSliderThumbShape(
                                                enabledThumbRadius: 6,
                                              ),
                                          overlayShape:
                                              const RoundSliderOverlayShape(
                                                overlayRadius: 10,
                                              ),
                                          activeTrackColor: Colors.orange,
                                          inactiveTrackColor: Colors.white30,
                                          thumbColor: Colors.orange,
                                        ),
                                        child: Slider(
                                          value: progress.toDouble(),
                                          onChanged: (v) {
                                            _player.seek(
                                              Duration(
                                                milliseconds:
                                                    (v *
                                                            duration
                                                                .inMilliseconds)
                                                        .toInt(),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                      // Time row
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () => _player.playOrPause(),
                                            child: Icon(
                                              isPlaying
                                                  ? Icons.pause
                                                  : Icons.play_arrow,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 10,
                                            ),
                                          ),
                                          const Spacer(),
                                          GestureDetector(
                                            onTap: () => _player.setVolume(
                                              isMuted ? 100.0 : 0.0,
                                            ),
                                            child: Icon(
                                              isMuted
                                                  ? Icons.volume_off
                                                  : Icons.volume_up,
                                              color: Colors.white70,
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _videoPanelPlaceholder(
    String? url,
    String message, {
    bool showRetry = false,
    VoidCallback? onRetry,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.ondemand_video_rounded,
              color: Colors.white54,
              size: 48,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            if (url != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  url.split('/').last,
                  style: const TextStyle(color: Colors.orange, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            if (showRetry && onRetry != null) ...[
              const SizedBox(height: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry', style: TextStyle(fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ──────────────────── Bottom section ──────────────────────────────────────

  Widget _bottomSection(_DashboardData d) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left: category selector
          Expanded(
            flex: 1,
            child: Column(
              children: [
                ScaleTransition(
                  scale: _cardAnimations[6],
                  child: Card(
                    elevation: 4,
                    color: Colors.black.withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.white10),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          const Text(
                            'Progress Track',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Divider(color: Colors.white12),
                          _categoryRow(
                            Icons.tv,
                            Colors.orange,
                            'Devices',
                            d.deviceList.length,
                          ),
                          _categoryRow(
                            Icons.dashboard_customize,
                            Colors.blue,
                            'Templates',
                            d.tempList.length,
                          ),
                          _categoryRow(
                            Icons.location_on,
                            Colors.green,
                            'Locations',
                            d.locationList.length,
                          ),
                          _categoryRow(
                            Icons.view_quilt,
                            Colors.purple,
                            'Over Views',
                            d.overview.length,
                          ),
                          _categoryRow(
                            Icons.video_library,
                            Colors.redAccent,
                            'Videos',
                            d.vidFile,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(top: 12, left: 4),
                    child: Text(
                      '© 2026 SRIHER Display',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 20),

          // Right: dynamic table
          Expanded(
            flex: 4,
            child: ScaleTransition(
              scale: _cardAnimations[7],
              child: Card(
                elevation: 4,
                color: Colors.white,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(children: [_tableHeader(), _tableBody(d)]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryBtn(String label, IconData icon, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () => setState(() => _selectedCategory = label),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.tealAccent.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Colors.tealAccent.withValues(alpha: 0.5)
                  : Colors.white10,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.tealAccent : Colors.white70,
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.tealAccent : Colors.white70,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: Colors.tealAccent,
                  size: 14,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryRow(IconData icon, Color color, String label, int count) {
    final bool sel = _selectedCategory == label;
    final double progress = count > 0 ? (count / 12).clamp(0.0, 1.0) : 0.0;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _selectedCategory = label),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: sel ? color.withValues(alpha: 0.07) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: color, size: 15),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: sel ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_ios,
                  color: sel ? color : Colors.grey.shade400,
                  size: 11,
                ),
              ],
            ),
            const SizedBox(height: 5),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: progress),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (_, v, __) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: LinearProgressIndicator(
                  value: v,
                  backgroundColor: color.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Table header / body ───────────────────────────────────────────────────

  List<String> get _headers {
    switch (_selectedCategory) {
      case 'Devices':
        return ['Device Name', 'Device Code', 'Model'];
      case 'Templates':
        return ['Template Name', 'Duration'];
      case 'Locations':
        return ['Location', 'Floor', 'Sub Location'];
      case 'Over Views':
        return ['Device', 'Schedule', 'Template', 'Duration', 'Location'];
      default:
        return [];
    }
  }

  List<List<String>> _rows(_DashboardData d) {
    switch (_selectedCategory) {
      case 'Devices':
        return d.deviceList
            .map(
              (e) => [
                (e['device_name'] ?? '-').toString(),
                (e['device_code'] ?? '-').toString(),
                (e['device_model'] ?? '-').toString(),
              ],
            )
            .toList();
      case 'Templates':
        return d.tempList
            .map(
              (e) => [
                (e['temp_name'] ?? '-').toString(),
                (e['duration'] ?? '-').toString(),
              ],
            )
            .toList();
      case 'Locations':
        return d.locationList
            .map(
              (e) => [
                (e['location_name'] ?? '-').toString(),
                (e['floor'] ?? '-').toString(),
                (e['sublocation'] ?? '-').toString(),
              ],
            )
            .toList();
      case 'Over Views':
        if (d.overview.isEmpty) return [];
        return d.overview
            .map(
              (e) => [
                (e['device_name'] ?? '-').toString(),
                (e['schedule_name'] ?? '-').toString(),
                (e['template_name'] ?? '-').toString(),
                (e['template_duration'] ?? '-').toString(),
                (e['location_name'] ?? '-').toString(),
              ],
            )
            .toList();
      default:
        return [];
    }
  }

  Widget _tableHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: const BoxDecoration(color: Color(0xFF0A192F)),
      child: Row(
        children: _headers
            .map(
              (h) => Expanded(
                child: Text(
                  h,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _tableBody(_DashboardData d) {
    final rows = _rows(d);
    if (rows.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_rounded, color: Colors.grey.shade300, size: 40),
              const SizedBox(height: 10),
              Text(
                'No data for $_selectedCategory',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    return SizedBox(
      height: 220,
      child: SingleChildScrollView(
        child: Column(
          children: List.generate(rows.length, (i) {
            return Container(
              color: i.isEven ? Colors.grey.shade50 : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Row(
                children: rows[i]
                    .map(
                      (cell) => Expanded(
                        child: Text(
                          cell,
                          style: const TextStyle(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
              ),
            );
          }),
        ),
      ),
    );
  }
}
