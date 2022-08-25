// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/src/messages.g.dart',
  dartTestOut: 'test/test_api.dart',
  objcHeaderOut: 'ios/Classes/messages.g.h',
  objcSourceOut: 'ios/Classes/messages.g.m',
  objcOptions: ObjcOptions(
    prefix: 'FLT',
  ),
  copyrightHeader: 'pigeons/copyright.txt',
))

class PausePointsMessage {
  int textureId;
  List<int?> pausePointsMs;
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
abstract class AVFoundationVideoPlayerApi {
  @ObjCSelector('initialize')
  void initialize();
  @ObjCSelector('create:')
  TextureMessage create(CreateMessage msg);
  @ObjCSelector('dispose:')
  void dispose(TextureMessage msg);
  @ObjCSelector('setLooping:')
  void setLooping(LoopingMessage msg);
  @ObjCSelector('setVolume:')
  void setVolume(VolumeMessage msg);
  @ObjCSelector('setPlaybackSpeed:')
  void setPlaybackSpeed(PlaybackSpeedMessage msg);
  @ObjCSelector('play:')
  void play(TextureMessage msg);
  @ObjCSelector('position:')
  PositionMessage position(TextureMessage msg);
  @ObjCSelector('seekTo:')
  void seekTo(PositionMessage msg);
  @ObjCSelector('pause:')
  void pause(TextureMessage msg);
  @ObjCSelector('setMixWithOthers:')
  void setMixWithOthers(MixWithOthersMessage msg);
  @ObjCSelector('setPausePoints:')
  void setPausePoints(PausePointsMessage msg);
}

@FlutterApi()
abstract class VideoPlayerFlutterApi {
  // setPausePoints által egy auto megállítás történt
  void autoPauseHappen(PositionMessage msg);
}

