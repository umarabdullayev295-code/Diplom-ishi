import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class SubtitleSegment {
  final Duration start;
  final Duration end;
  final String text;

  SubtitleSegment({required this.start, required this.end, required this.text});

  @override
  String toString() => "[${start.inSeconds}s - ${end.inSeconds}s]: $text";
}

class TranscriptionService {
  final String apiKey = "w2HnvsF2134cvexPfu8dwrtOBQ7lvF4EUiTIu8WG";
  final String baseUrl = "https://api.muxlisa.uz/v1";

  Future<List<SubtitleSegment>?> transcribeAudio(String audioPath) async {
    print("Uploading audio for transcription: $audioPath");
    
    var request = http.MultipartRequest('POST', Uri.parse("$baseUrl/transcribe"));
    request.headers['Authorization'] = 'Bearer $apiKey';
    request.files.add(await http.MultipartFile.fromPath('file', audioPath));

    try {
      // Use client with longer timeout for large files
      var client = http.Client();
      var streamedResponse = await client.send(request).timeout(const Duration(minutes: 5));
      var response = await http.Response.fromStream(streamedResponse);
      client.close();

      if (response.statusCode == 200) {
        var jsonResponse = json.decode(response.body);
        
        if (jsonResponse['segments'] != null && jsonResponse['segments'] is List) {
          List<SubtitleSegment> segments = [];
          for (var item in jsonResponse['segments']) {
            segments.add(SubtitleSegment(
              start: Duration(milliseconds: ((item['start'] ?? 0) * 1000).toInt()),
              end: Duration(milliseconds: ((item['end'] ?? 0) * 1000).toInt()),
              text: item['text'] ?? "",
            ));
          }
          return segments;
        }
        return [];
      } else {
        print("Transcription failed (${response.statusCode}): ${response.body}");
        return null;
      }
  Future<String?> downloadFile(String url) async {
    try {
      print("Downloading file from: $url");
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final Directory tempDir = await getTemporaryDirectory();
        final String fileName = "${DateTime.now().millisecondsSinceEpoch}_remote.mp4";
        final String filePath = p.join(tempDir.path, fileName);
        final File file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        print("Download successful: $filePath");
        return filePath;
      } else {
        print("Download failed: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error downloading file: $e");
      return null;
    }
  }
}


