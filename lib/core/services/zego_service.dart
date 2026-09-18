import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';
import '../../app/router.dart';

class ZegoService {
  static const int appID = 869972860;
  static const String appSign =
      '3b5932ceed04be468703070f979396f9290f45854fb74a104ac7fa830d8b99bb';

  static void init({required String userID, required String userName}) {
    ZegoUIKitPrebuiltCallInvitationService().setNavigatorKey(rootNavigatorKey);

    ZegoUIKitPrebuiltCallInvitationService().init(
      appID: appID,
      appSign: appSign,
      userID: userID,
      userName: userName,
      plugins: [ZegoUIKitSignalingPlugin()],
      requireConfig: (ZegoCallInvitationData data) {
        final config = (data.type == ZegoCallInvitationType.videoCall)
            ? ZegoUIKitPrebuiltCallConfig.oneOnOneVideoCall()
            : ZegoUIKitPrebuiltCallConfig.oneOnOneVoiceCall();

        return config;
      },
      notificationConfig: ZegoCallInvitationNotificationConfig(
        androidNotificationConfig: ZegoCallAndroidNotificationConfig(
          channelID: "CallKit",
          channelName: "CallKit",
          sound: "call_ringtone",
        ),
      ),
    );
  }

  static void uninit() {
    ZegoUIKitPrebuiltCallInvitationService().uninit();
  }
}
