package io.flutter.plugins.videoplayer;

import android.content.Context;
import android.os.Build;
import android.util.LongSparseArray;

import androidx.annotation.NonNull;

import io.flutter.FlutterInjector;
import io.flutter.Log;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugins.videoplayer.Messages.AndroidVideoPlayerApi;
import io.flutter.plugins.videoplayer.Messages.CreateMessage;
import io.flutter.plugins.videoplayer.Messages.LoopingMessage;
import io.flutter.plugins.videoplayer.Messages.MixWithOthersMessage;
import io.flutter.plugins.videoplayer.Messages.PlaybackSpeedMessage;
import io.flutter.plugins.videoplayer.Messages.PositionMessage;
import io.flutter.plugins.videoplayer.Messages.TextureMessage;
import io.flutter.plugins.videoplayer.Messages.VolumeMessage;
import io.flutter.view.TextureRegistry;

import java.security.KeyManagementException;
import java.security.NoSuchAlgorithmException;
import java.util.Map;
import javax.net.ssl.HttpsURLConnection;

/** Android platform implementation of the VideoPlayerPlugin. */
public class VideoPlayerPlugin implements FlutterPlugin, AndroidVideoPlayerApi {
  private static final String TAG = "VideoPlayerPlugin";
  private final LongSparseArray<VideoPlayer> videoPlayers = new LongSparseArray<>();
  private FlutterState flutterState;
  private VideoPlayerOptions options = new VideoPlayerOptions();
  private static Messages.VideoPlayerFlutterApi hostToFlutterApi;

  /** Constructor for the VideoPlayerPlugin. */
  public VideoPlayerPlugin() {}

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    this.hostToFlutterApi = new Messages.VideoPlayerFlutterApi(binding.getBinaryMessenger());
    Log.d(TAG, "Host-to-Flutter API initialized");

    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
      try {
        HttpsURLConnection.setDefaultSSLSocketFactory(new CustomSSLSocketFactory());
      } catch (KeyManagementException | NoSuchAlgorithmException e) {
        Log.w(
            TAG,
            "Failed to enable TLSv1.1 and TLSv1.2 Protocols for API level 19 and below.\n"
                + "For more information about Socket Security, please consult the following link:\n"
                + "https://developer.android.com/reference/javax/net/ssl/SSLSocket",
            e);
      }
    }

    final FlutterInjector injector = FlutterInjector.instance();
    this.flutterState =
        new FlutterState(
            binding.getApplicationContext(),
            binding.getBinaryMessenger(),
            injector.flutterLoader()::getLookupKeyForAsset,
            injector.flutterLoader()::getLookupKeyForAsset,
            binding.getTextureRegistry());
    flutterState.startListening(this, binding.getBinaryMessenger());
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    if (flutterState == null) {
      Log.w(TAG, "Detached from engine before registering.");
      return;
    }
    flutterState.stopListening(binding.getBinaryMessenger());
    disposeAllPlayers();
    flutterState = null;
  }

  private void disposeAllPlayers() {
    for (int i = 0; i < videoPlayers.size(); i++) {
      videoPlayers.valueAt(i).dispose();
    }
    videoPlayers.clear();
  }

  private void onDestroy() {
    disposeAllPlayers();
  }

  public void initialize() {
    disposeAllPlayers();
  }

  public void autoPauseCallback(Long textureId, Long ms) {
    if (this.hostToFlutterApi != null) {
      VideoPlayer player = videoPlayers.get(textureId);
      if (player == null) return;
      player.pause();

      this.hostToFlutterApi.autoPauseHappen(
          new PositionMessage.Builder()
              .setPosition(ms)
              .setTextureId(textureId)
              .build(),
          (Void t) -> {});
    } else {
      Log.d(TAG, "Host-to-Flutter API is null");
    }
  }

  public TextureMessage create(CreateMessage arg) {
    TextureRegistry.SurfaceTextureEntry handle =
        flutterState.textureRegistry.createSurfaceTexture();
    EventChannel eventChannel =
        new EventChannel(
            flutterState.binaryMessenger, "flutter.io/videoPlayer/videoEvents" + handle.id());

    VideoPlayer player;

    if (arg.getAsset() != null) {
      String assetLookupKey;
      if (arg.getPackageName() != null) {
        assetLookupKey =
            flutterState.keyForAssetAndPackageName.get(arg.getAsset(), arg.getPackageName());
      } else {
        assetLookupKey = flutterState.keyForAsset.get(arg.getAsset());
      }
      player =
          new VideoPlayer(
              flutterState.applicationContext,
              eventChannel,
              handle,
              "asset:///" + assetLookupKey,
              null,
              null,
              options,
              new VideoPlayerPluginCallback(this, handle.id()));
    } else {
      @SuppressWarnings("unchecked")
      Map<String, String> httpHeaders = arg.getHttpHeaders();
      player =
          new VideoPlayer(
              flutterState.applicationContext,
              eventChannel,
              handle,
              arg.getUri(),
              arg.getFormatHint(),
              httpHeaders,
              options,
              new VideoPlayerPluginCallback(this, handle.id()));
    }
    videoPlayers.put(handle.id(), player);
    return new TextureMessage.Builder().setTextureId(handle.id()).build();
  }

  public void dispose(TextureMessage arg) {
    VideoPlayer player = videoPlayers.get(arg.getTextureId());
    if (player != null) {
      player.dispose();
      videoPlayers.remove(arg.getTextureId());
    }
  }

  public void setLooping(LoopingMessage arg) {
    VideoPlayer player = videoPlayers.get(arg.getTextureId());
    if (player != null) {
      player.setLooping(arg.getIsLooping());
    }
  }

  public void setVolume(VolumeMessage arg) {
    VideoPlayer player = videoPlayers.get(arg.getTextureId());
    if (player != null) {
      player.setVolume(arg.getVolume());
    }
  }

  public void setPlaybackSpeed(PlaybackSpeedMessage arg) {
    VideoPlayer player = videoPlayers.get(arg.getTextureId());
    if (player != null) {
      player.setPlaybackSpeed(arg.getSpeed());
    }
  }

  public void play(TextureMessage arg) {
    VideoPlayer player = videoPlayers.get(arg.getTextureId());
    if (player != null) {
      player.play();
    }
  }

  public PositionMessage position(TextureMessage arg) {
    VideoPlayer player = videoPlayers.get(arg.getTextureId());
    if (player != null) {
      player.sendBufferingUpdate();
      return new PositionMessage.Builder()
          .setPosition(player.getPosition())
          .setTextureId(arg.getTextureId())
          .build();
    }
    return null;
  }

  public void seekTo(PositionMessage arg) {
    VideoPlayer player = videoPlayers.get(arg.getTextureId());
    if (player != null) {
      player.seekTo(arg.getPosition().intValue());
    }
  }

  public void pause(TextureMessage arg) {
    VideoPlayer player = videoPlayers.get(arg.getTextureId());
    if (player != null) {
      player.pause();
    }
  }

  @Override
  public void setMixWithOthers(MixWithOthersMessage arg) {
    options.mixWithOthers = arg.getMixWithOthers();
  }

  @Override
  public void setPausePoints(@NonNull Messages.PausePointsMessage msg) {
    VideoPlayer player = videoPlayers.get(msg.getTextureId());
    if (player != null) {
      player.setPausePoints(msg.getPausePointsMs());
    }
  }

  private static final class FlutterState {
    private final Context applicationContext;
    private final BinaryMessenger binaryMessenger;
    private final TextureRegistry textureRegistry;

    private FlutterState(
        Context applicationContext,
        BinaryMessenger messenger,
        KeyForAssetFn keyForAsset,
        KeyForAssetAndPackageName keyForAssetAndPackageName,
        TextureRegistry textureRegistry) {
      this.applicationContext = applicationContext;
      this.binaryMessenger = messenger;
      this.textureRegistry = textureRegistry;
    }

    void startListening(VideoPlayerPlugin methodCallHandler, BinaryMessenger messenger) {
      AndroidVideoPlayerApi.setup(messenger, methodCallHandler);
    }

    void stopListening(BinaryMessenger messenger) {
      AndroidVideoPlayerApi.setup(messenger, null);
    }
  }
}