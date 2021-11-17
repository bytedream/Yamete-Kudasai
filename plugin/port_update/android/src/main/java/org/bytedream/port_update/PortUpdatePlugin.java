package org.bytedream.port_update;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.BatteryManager;

import io.flutter.Log;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.EventChannel.StreamHandler;

/** PortUpdatePlugin */
public class PortUpdatePlugin implements FlutterPlugin, StreamHandler {
  public static final String TAG = "PortUpdate";
  public static final String CHANNEL = "port/stream";

  private Context context;
  private EventChannel channel;

  private BroadcastReceiver batteryReceiver;
  private BroadcastReceiver headphoneReceiver;

  private int lastBatteryStatus;
  private int lastHeadphoneStatus;

  @Override
  public void onAttachedToEngine(FlutterPluginBinding flutterPluginBinding) {
    context = flutterPluginBinding.getApplicationContext();
    channel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), CHANNEL);
    channel.setStreamHandler(this);
  }

  @Override
  public void onDetachedFromEngine(FlutterPluginBinding binding) {
    context = null;
    channel.setStreamHandler(null);
  }

  @Override
  public void onListen(Object o, EventChannel.EventSink eventSink) {
    Log.w(TAG, "adding listener");

    batteryReceiver = createBatteryReceiver(eventSink);
    headphoneReceiver = createHeadphoneReceiver(eventSink);

    Intent batteryIntent = context.registerReceiver(batteryReceiver, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
    Intent headphoneIntent = context.registerReceiver(headphoneReceiver, new IntentFilter(Intent.ACTION_HEADSET_PLUG));

    if (batteryIntent != null) lastBatteryStatus = getBatteryStatus(batteryIntent);
    if (headphoneIntent != null) lastHeadphoneStatus = getHeadphoneStatus(headphoneIntent);
  }

  @Override
  public void onCancel(Object o) {
    Log.w(TAG, "canceling listener");
    context.unregisterReceiver(batteryReceiver);
    context.unregisterReceiver(headphoneReceiver);
  }

  private BroadcastReceiver createBatteryReceiver(EventChannel.EventSink eventSink) {
    return new BroadcastReceiver() {
      @Override
      public void onReceive(Context context, Intent intent) {
        int batteryStatus = getBatteryStatus(intent);
        if (batteryStatus != lastBatteryStatus || batteryStatus == -1) {
          lastBatteryStatus = batteryStatus;
          eventSink.success(getBatteryAction(batteryStatus).value);
        }
      }
    };
  }

  private int getBatteryStatus(Intent intent) {
    return intent.getIntExtra(BatteryManager.EXTRA_STATUS, -1);
  }

  private Action getBatteryAction(int batteryStatus) {
    switch (batteryStatus) {
      case BatteryManager.BATTERY_STATUS_CHARGING:
        return Action.BATTERY_CHARGING;
      case BatteryManager.BATTERY_STATUS_DISCHARGING:
        return Action.BATTERY_DISCHARGING;
      case BatteryManager.BATTERY_STATUS_FULL:
        return Action.BATTERY_FULL;
      default:
        return Action.UNKNOWN;
    }
  }

  private BroadcastReceiver createHeadphoneReceiver(EventChannel.EventSink eventSink) {
    return new BroadcastReceiver() {
      @Override
      public void onReceive(Context context, Intent intent) {
        int headphoneStatus = intent.getIntExtra("state", -1);
        if (headphoneStatus != lastHeadphoneStatus || headphoneStatus == -1) {
          lastHeadphoneStatus = headphoneStatus;
          eventSink.success(getHeadphoneAction(headphoneStatus).value);
        }
      }
    };
  }

  private int getHeadphoneStatus(Intent intent) {
    return intent.getIntExtra("state", -1);
  }

  private Action getHeadphoneAction(int headphoneStatus) {
    switch (headphoneStatus) {
      // unplugged
      case 0:
        return Action.HEADPHONE_DISCONNECTED;
      // plugged in
      case 1:
        return Action.HEADPHONE_CONNECTED;
      default:
        return Action.UNKNOWN;
    }
  }

  private enum Action {
    UNKNOWN(0),
    BATTERY_CHARGING(1),
    BATTERY_DISCHARGING(2),
    BATTERY_FULL(3),
    HEADPHONE_CONNECTED(4),
    HEADPHONE_DISCONNECTED(5);

    public final int value;

    Action(int value) {
      this.value = value;
    }
  }
}
