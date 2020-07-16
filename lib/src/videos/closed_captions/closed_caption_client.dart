import '../../extensions/helpers_extension.dart';
import '../../reverse_engineering/responses/closed_caption_track_response.dart'
    hide ClosedCaption, ClosedCaptionPart;
import '../../reverse_engineering/responses/video_info_response.dart';
import '../../reverse_engineering/youtube_http_client.dart';
import '../videos.dart';
import 'closed_caption.dart';
import 'closed_caption_manifest.dart';
import 'closed_caption_part.dart';
import 'closed_caption_track.dart';
import 'closed_caption_track_info.dart';
import 'language.dart';

/// Queries related to closed captions of YouTube videos.
class ClosedCaptionClient {
  final YoutubeHttpClient _httpClient;

  /// Initializes an instance of [ClosedCaptionClient]
  ClosedCaptionClient(this._httpClient);

  /// Gets the manifest that contains information
  /// about available closed caption tracks in the specified video.
  Future<ClosedCaptionManifest> getManifest(dynamic videoId) async {
    videoId = VideoId.fromString(videoId);
    var videoInfoResponse =
        await VideoInfoResponse.get(_httpClient, videoId.value);
    var playerResponse = videoInfoResponse.playerResponse;

    var tracks = playerResponse.closedCaptionTrack.map((track) =>
        ClosedCaptionTrackInfo(Uri.parse(track.url),
            Language(track.languageCode, track.languageName),
            isAutoGenerated: track.autoGenerated));
    return ClosedCaptionManifest(tracks);
  }

  /// Gets the actual closed caption track which is
  /// identified by the specified metadata.
  Future<ClosedCaptionTrack> get(ClosedCaptionTrackInfo trackInfo) async {
    var response = await ClosedCaptionTrackResponse.get(
        _httpClient, trackInfo.url.toString());

    var captions = response.closedCaptions
        .where((e) => !e.text.isNullOrWhiteSpace)
        .map((e) => ClosedCaption(e.text, e.offset, e.duration,
            e.getParts().map((f) => ClosedCaptionPart(f.text, f.offset))));
    return ClosedCaptionTrack(captions);
  }

  ///
  Future<String> getSrt(ClosedCaptionTrackInfo trackInfo) async {
    var track = await get(trackInfo);

    var buffer = StringBuffer();
    for (var i = 0; i < track.captions.length; i++) {
      var caption = track.captions[i];

      // Line number
      buffer.writeln('${i + 1}');

      // Time start --> time end
      buffer.write(caption.offset.toSrtFormat());
      buffer.write(' --> ');
      buffer.write(caption.end.toSrtFormat());
      buffer.writeln();

      // Actual text
      buffer.writeln(caption.text);
      buffer.writeln();
    }
    return buffer.toString();
  }
}

extension on Duration {
  String toSrtFormat() {
    String threeDigits(int n) {
      if (n >= 1000) {
        return n.toString().substring(0, 3);
      }
      if (n >= 100) {
        return '$n';
      }
      if (n >= 10) {
        return '0$n';
      }
      return '00$n';
    }

    String twoDigits(int n) {
      if (n >= 10) {
        return '$n';
      }
      return '0$n';
    }

    if (inMicroseconds < 0) {
      return '-${-this}';
    }
    var twoDigitHours = twoDigits(inHours);
    var twoDigitMinutes =
    twoDigits(inMinutes.remainder(Duration.minutesPerHour));
    var twoDigitSeconds =
    twoDigits(inSeconds.remainder(Duration.secondsPerMinute));
    var fourDigitsUs =
    threeDigits(inMilliseconds.remainder(1000));
    return '$twoDigitHours:$twoDigitMinutes:$twoDigitSeconds,$fourDigitsUs';
  }
}
