import 'dart:io';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class VideoProcessor {
  static Future<String?> extractAudio(String videoPath) async {
    final Directory tempDir = await getTemporaryDirectory();
    final String audioPath = p.join(tempDir.path, "${DateTime.now().millisecondsSinceEpoch}.mp3");

    // Command to extract audio: -i input -vn -acodec libmp3lame -q:a 2 output
    final String command = "-i \"$videoPath\" -vn -acodec libmp3lame -q:a 2 \"$audioPath\"";

    print("Executing FFmpeg command: $command");
    
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      print("Audio extraction successful: $audioPath");
      return audioPath;
    } else if (ReturnCode.isCancel(returnCode)) {
      print("Audio extraction cancelled");
      return null;
    } else {
      print("Audio extraction failed");
      final logs = await session.getLogs();
      for (var log in logs) {
        print(log.getMessage());
      }
      return null;
    }
  }

  static Future<void> cleanup(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print("Cleaned up temporary file: $filePath");
      }
    } catch (e) {
      print("Cleanup failed: $e");
    }
  }
}

