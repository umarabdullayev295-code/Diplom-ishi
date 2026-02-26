import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'video_processor.dart';
import 'transcription_service.dart';

void main() {
  runApp(const VideoSearchApp());
}

class VideoSearchApp extends StatelessWidget {
  const VideoSearchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IVSP - Perfect Search',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF020617), // Slate 950
        primaryColor: const Color(0xFF38BDF8),
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF38BDF8),
          brightness: Brightness.dark,
          surface: const Color(0xFF0F172A),
        ),
        useMaterial3: true,
      ),
      home: const SearchScreen(),
    );
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  VideoPlayerController? _controller;
  List<SubtitleSegment> _segments = [];
  bool _isProcessing = false;
  String _status = "Video kutmoqda...";
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _listController = ScrollController();
  int _activeSegmentIndex = -1;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowCompression: false,
    );

    if (result != null) {
      File file = File(result.files.single.path!);
      _initializeVideo(file: file);
      _processVideo(path: file.path, isLocal: true);
    }
  }

  Future<void> _loadFromUrl() async {
    String? url = await showDialog<String>(
      context: context,
      builder: (context) => _buildUrlDialog(),
    );

    if (url != null && url.isNotEmpty) {
      _initializeVideo(url: url);
      _processVideo(path: url, isLocal: false);
    }
  }

  Widget _buildUrlDialog() {
    final TextEditingController urlController = TextEditingController();
    return AlertDialog(
      backgroundColor: const Color(0xFF0F172A),
      title: Text("Vidio linkini kiriting", style: GoogleFonts.outfit(color: Colors.white)),
      content: TextField(
        controller: urlController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "https://example.com/video.mp4",
          hintStyle: const TextStyle(color: Colors.white24),
          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blue)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Bekor qilish")),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, urlController.text),
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8), foregroundColor: Colors.black),
          child: const Text("Yuklash"),
        ),
      ],
    );
  }

  void _initializeVideo({File? file, String? url}) {
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    
    if (file != null) {
      _controller = VideoPlayerController.file(file);
    } else if (url != null) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(url));
    }

    _controller!.initialize().then((_) {
      setState(() {});
      _controller!.addListener(_onVideoUpdate);
    });
  }

  Future<void> _processVideo({required String path, required bool isLocal}) async {
    setState(() {
      _isProcessing = true;
      _status = isLocal ? "Audio qirqib olinmoqda..." : "Video yuklanmoqda va tahlil qilinmoqda...";
      _segments = [];
    });

    try {
      String? localPath = path;
      if (!isLocal) {
        localPath = await TranscriptionService().downloadFile(path);
      }

      if (localPath != null) {
        String? audioPath = await VideoProcessor.extractAudio(localPath);
        if (audioPath != null) {
          setState(() => _status = "AI tahlil qilmoqda...");
          List<SubtitleSegment>? segments = await TranscriptionService().transcribeAudio(audioPath);
          if (segments != null) {
            setState(() {
              _segments = segments;
              _status = "Muvaffaqiyatli yakunlandi!";
            });
            VideoProcessor.cleanup(audioPath);
            if (!isLocal) VideoProcessor.cleanup(localPath);
          } else {
            setState(() => _status = "Tizimda xatolik");
          }
        } else {
          setState(() => _status = "Audio xatoligi");
        }
      } else {
        setState(() => _status = "Yuklab olishda xatolik");
      }
    } catch (e) {
      setState(() => _status = "Xato: $e");
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _seekTo(Duration position) {
    _controller?.seekTo(position);
    _controller?.play();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoUpdate);
    _controller?.dispose();
    _searchController.dispose();
    _listController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF38BDF8).withAlpha(30),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).blur(blurX: 100, blurY: 100).scale(begin: const Offset(1, 1), end: const Offset(1.5, 1.5), duration: 5.seconds),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildVideoPreview(),
                        _buildSearchAndControls(),
                        _buildStatusLine(),
                        _buildSegmentsList(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Muxlisa AI", style: GoogleFonts.outfit(fontSize: 14, color: Colors.white54, letterSpacing: 1.5)),
              Text("V-SEARCH", style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: _loadFromUrl,
                icon: const Icon(Icons.link_rounded, color: Colors.white70),
                tooltip: "Linkdan yuklash",
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _pickVideo,
                icon: const Icon(Icons.add_rounded),
                style: IconButton.styleFrom(backgroundColor: const Color(0xFF38BDF8), foregroundColor: Colors.black87),
              ).animate().scale(delay: 200.ms, curve: Curves.backOut),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview() {
    return Container(
      height: 220,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white10),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(50), blurRadius: 30, offset: const Offset(0, 15)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_controller?.value.isInitialized == true)
            VideoPlayer(_controller!)
          else
            const Icon(Icons.play_circle_outline, size: 80, color: Colors.white24),
          
          // Subtitle Overlay (YouTube Style)
          if (_controller?.value.isInitialized == true && _activeSegmentIndex != -1)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _segments[_activeSegmentIndex].text,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 200.ms),

          if (_controller?.value.isInitialized == true)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: VideoProgressIndicator(_controller!, allowScrubbing: true, colors: const VideoProgressColors(playedColor: Color(0xFF38BDF8))),
            ),
          if (_controller?.value.isInitialized == true)
            GestureDetector(
              onTap: () => setState(() => _controller!.value.isPlaying ? _controller!.pause() : _controller!.play()),
              child: Center(
                child: AnimatedOpacity(
                  opacity: _controller!.value.isPlaying ? 0.0 : 1.0,
                  duration: 200.ms,
                  child: const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.black45,
                    child: Icon(Icons.play_arrow_rounded, size: 40, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildSearchAndControls() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white12),
            ),
            child: TextField(
              controller: _searchController,
              cursorColor: const Color(0xFF38BDF8),
              decoration: InputDecoration(
                hintText: "Kerakli so'zni yozing...",
                hintStyle: GoogleFonts.outfit(color: Colors.white30),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white30),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildStatusLine() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        children: [
          if (_isProcessing)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.right(12),
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF38BDF8)),
            ).animate(onPlay: (c) => c.repeat()).fade(duration: 500.ms),
          Text(_status, style: GoogleFonts.outfit(fontSize: 12, color: Colors.white60, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildSegmentsList() {
    final filtered = _segments.where((s) {
      if (_searchController.text.isEmpty) return true;
      return s.text.toLowerCase().contains(_searchController.text.toLowerCase());
    }).toList();

    return ListView.builder(
      controller: _listController,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final segment = filtered[index];
        final isActualActive = _segments.indexOf(segment) == _activeSegmentIndex;

        return GestureDetector(
          onTap: () => _seekTo(segment.start),
          child: AnimatedContainer(
            duration: 300.ms,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isActualActive ? const Color(0xFF38BDF8).withAlpha(20) : Colors.white.withAlpha(5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isActualActive ? const Color(0xFF38BDF8).withAlpha(100) : Colors.white10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        segment.text,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: isActualActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActualActive ? const Color(0xFF38BDF8) : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${_formatDuration(segment.start)} → ${_formatDuration(segment.end)}",
                        style: GoogleFonts.outfit(fontSize: 12, color: Colors.white38),
                      ),
                    ],
                  ),
                ),
                if (isActualActive)
                  const Icon(Icons.equalizer_rounded, color: Color(0xFF38BDF8), size: 20)
                      .animate(onPlay: (c) => c.repeat())
                      .scale(duration: 500.ms, begin: const Offset(1, 0.5), end: const Offset(1, 1.2)),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}


