import 'package:permission_handler/permission_handler.dart';

class AppPermissions {
  static Future<bool> requestCamera() async {
    var status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<bool> requestMicrophone() async {
    var status = await Permission.microphone.request();
    return status.isGranted;
  }

  static Future<bool> requestStorage() async {
    var status = await Permission.storage.request();
    return status.isGranted;
  }
}
