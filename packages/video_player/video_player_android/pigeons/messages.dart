// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/messages.g.dart',
  dartTestOut: 'test/test_api.dart',
  javaOut: 'android/src/main/java/io/flutter/plugins/videoplayer/Messages.java',
  javaOptions: JavaOptions(
    package: 'io.flutter.plugins.videoplayer',
  ),
  copyrightHeader: 'pigeons/copyright.txt',
))
class PausePointsMessage {
  int textureId;
  Int64List pausePointsMs;
  int sentTimestampFromFlutter;
  PausePointsMessage({
    required this.textureId,
    required this.pausePointsMs,
    required this.sentTimestampFromFlutter
  });
}

class TextureMessage {
  int textureId;
  int sentTimestampFromFlutter;
  TextureMessage({
    required this.textureId,
    required this.sentTimestampFromFlutter
  });
}


class LoopingMessage {
  int textureId;
  bool isLooping;
  LoopingMessage({
    required this.textureId,
    required this.isLooping,
  });
}

class VolumeMessage {
  int textureId;
  double volume;
  VolumeMessage({
    required this.textureId,
    required this.volume,
  });
}

class PlaybackSpeedMessage {
  int textureId;
  double speed;
  PlaybackSpeedMessage({
    required this.textureId,
    required this.speed,
  });
}

class PositionMessage {
  int textureId;
  int position;
  PositionMessage({
    required this.textureId,
    required this.position,
  });
}

class CreateMessage {
  String? asset;
  String? uri;
  String? packageName;
  String? formatHint;
  Map<String?, String?>? httpHeaders;
  CreateMessage({
    this.asset,
    this.uri,
    this.packageName,
    this.formatHint,
    this.httpHeaders,
  });
}

class MixWithOthersMessage {
  bool mixWithOthers;
  MixWithOthersMessage({
    required this.mixWithOthers,
  });
}

@HostApi(dartHostTestHandler: 'TestHostVideoPlayerApi')
abstract class AndroidVideoPlayerApi {
  void initialize();
  TextureMessage create(CreateMessage msg);
  void dispose(TextureMessage msg);
  void setLooping(LoopingMessage msg);
  void setVolume(VolumeMessage msg);
  void setPlaybackSpeed(PlaybackSpeedMessage msg);
  void play(TextureMessage msg);
  PositionMessage position(TextureMessage msg);
  void seekTo(PositionMessage msg);
  void pause(TextureMessage msg);
  void setMixWithOthers(MixWithOthersMessage msg);
  void setPausePoints(PausePointsMessage msg); // bdezso
}

@FlutterApi()
abstract class VideoPlayerFlutterApi {
  // setPausePoints által egy auto megállítás történt
  void autoPauseHappen(PositionMessage msg);
}

