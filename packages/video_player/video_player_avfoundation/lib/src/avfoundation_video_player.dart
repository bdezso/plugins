// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:rxdart/rxdart.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart' as inter;

import 'package:video_player_platform_interface/messages.g.dart' as interface_messages;
import 'messages.g.dart';


/// Implementation of  host -> flutter communication
class VideoPlayerFlutterApiImpl extends VideoPlayerFlutterApi{
  /// notify when host pause the video because of break points which was set by setPausePoints
  final BehaviorSubject<PositionMessage> _autoPauseHappenNotifier = BehaviorSubject<PositionMessage>();

  // Ez akkor hívódik meg, amikor a host üzenetet küld számunkra
  @override
  void autoPauseHappen(PositionMessage arg) {
    _autoPauseHappenNotifier.add(arg);
  }

  // stream
  Stream<PositionMessage> getAutoPauseStream(int textureId){
    return _autoPauseHappenNotifier.stream.where((PositionMessage event) => event.textureId == textureId);
  }
}

/// An iOS implementation of [VideoPlayerPlatform] that uses the
/// Pigeon-generated [VideoPlayerApi].
class AVFoundationVideoPlayer extends VideoPlayerPlatform {
  final AVFoundationVideoPlayerApi _api = AVFoundationVideoPlayerApi();
  final VideoPlayerFlutterApiImpl _hostToFlutterApi = VideoPlayerFlutterApiImpl();
  /// Registers this class as the default instance of [VideoPlayerPlatform].
  static void registerWith() {
    VideoPlayerPlatform.instance = AVFoundationVideoPlayer();
  }

  int getCurrentTimestamp(){
    return DateTime.now().microsecondsSinceEpoch;
  }

  @override
  Future<void> init() {
    VideoPlayerFlutterApi.setup(this._hostToFlutterApi);
    return _api.initialize();
  }

  @override 
  Stream<interface_messages.PositionMessage> getAutoPauseHappenStreamForTextureId(int textureId){
    return _hostToFlutterApi.getAutoPauseStream(textureId).map((event) => interface_messages.PositionMessage()..position = event.position..textureId=event.textureId);
  }
  

  @override
  Future<void> dispose(int textureId) {
    return _api.dispose(TextureMessage(textureId: textureId,sentTimestampFromFlutter: this.getCurrentTimestamp()));
  }

  @override
  Future<int?> create(DataSource dataSource) async {
    String? asset;
    String? packageName;
    String? uri;
    String? formatHint;
    Map<String, String> httpHeaders = <String, String>{};
    switch (dataSource.sourceType) {
      case DataSourceType.asset:
        asset = dataSource.asset;
        packageName = dataSource.package;
        break;
      case DataSourceType.network:
        uri = dataSource.uri;
        formatHint = _videoFormatStringMap[dataSource.formatHint];
        httpHeaders = dataSource.httpHeaders;
        break;
      case DataSourceType.file:
        uri = dataSource.uri;
        break;
      case DataSourceType.contentUri:
        uri = dataSource.uri;
        break;
    }
    final CreateMessage message = CreateMessage(
      asset: asset,
      packageName: packageName,
      uri: uri,
      httpHeaders: httpHeaders,
      formatHint: formatHint,
    );

    final TextureMessage response = await _api.create(message);
    return response.textureId;
  }

  @override
  Future<void> setLooping(int textureId, bool looping) {
    return _api.setLooping(LoopingMessage(
      textureId: textureId,
      isLooping: looping,
    ));
  }

  @override
  Future<void> play(int textureId) {
    return _api.play(TextureMessage(textureId: textureId,sentTimestampFromFlutter: this.getCurrentTimestamp()));
  }

  @override
  Future<void> pause(int textureId) {
    return _api.pause(TextureMessage(textureId: textureId,sentTimestampFromFlutter: this.getCurrentTimestamp()));
  }

  @override
  Future<void> setVolume(int textureId, double volume) {
    return _api.setVolume(VolumeMessage(
      textureId: textureId,
      volume: volume,
    ));
  }

  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) {
    assert(speed > 0);

    return _api.setPlaybackSpeed(PlaybackSpeedMessage(
      textureId: textureId,
      speed: speed,
    ));
  }

  @override
  Future<void> seekTo(int textureId, Duration position) {
    return _api.seekTo(PositionMessage(
      textureId: textureId,
      position: position.inMilliseconds,
    ));
  }

  @override
  Future<Duration> getPosition(int textureId) async {
    final PositionMessage response =
        await _api.position(TextureMessage(textureId: textureId,sentTimestampFromFlutter: this.getCurrentTimestamp()));
    return Duration(milliseconds: response.position);
  }

  @override
  Stream<VideoEvent> videoEventsFor(int textureId) {
    return _eventChannelFor(textureId)
        .receiveBroadcastStream()
        .map((dynamic event) {
      final Map<dynamic, dynamic> map = event as Map<dynamic, dynamic>;
      switch (map['event']) {
        case 'initialized':
          return VideoEvent(
            eventType: VideoEventType.initialized,
            duration: Duration(milliseconds: map['duration'] as int),
            size: Size((map['width'] as num?)?.toDouble() ?? 0.0,
                (map['height'] as num?)?.toDouble() ?? 0.0),
          );
        case 'completed':
          return VideoEvent(
            eventType: VideoEventType.completed,
          );
        case 'bufferingUpdate':
          final List<dynamic> values = map['values'] as List<dynamic>;

          return VideoEvent(
            buffered: values.map<DurationRange>(_toDurationRange).toList(),
            eventType: VideoEventType.bufferingUpdate,
          );
        case 'bufferingStart':
          return VideoEvent(eventType: VideoEventType.bufferingStart);
        case 'bufferingEnd':
          return VideoEvent(eventType: VideoEventType.bufferingEnd);
        default:
          return VideoEvent(eventType: VideoEventType.unknown);
      }
    });
  }

  @override
  Future<void> setPausePoints(int textureId, List<int> pausePoints ){
    print("Pause points called (avfoundation_video_player.dart)");
    return _api.setPausePoints(PausePointsMessage(textureId: textureId,pausePointsMs: pausePoints,sentTimestampFromFlutter: this.getCurrentTimestamp()));
  }

  @override
  Widget buildView(int textureId) {
    return Texture(textureId: textureId);
  }

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) {
    return _api
        .setMixWithOthers(MixWithOthersMessage(mixWithOthers: mixWithOthers));
  }

  EventChannel _eventChannelFor(int textureId) {
    return EventChannel('flutter.io/videoPlayer/videoEvents$textureId');
  }

  static const Map<VideoFormat, String> _videoFormatStringMap =
      <VideoFormat, String>{
    VideoFormat.ss: 'ss',
    VideoFormat.hls: 'hls',
    VideoFormat.dash: 'dash',
    VideoFormat.other: 'other',
  };

  DurationRange _toDurationRange(dynamic value) {
    final List<dynamic> pair = value as List<dynamic>;
    return DurationRange(
      Duration(milliseconds: pair[0] as int),
      Duration(milliseconds: pair[1] as int),
    );
  }
}
