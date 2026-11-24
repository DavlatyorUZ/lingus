import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// A conservative budget; it never attempts to infer FPS from debug builds.
class DeviceBudget {
  static bool lowMemory = true;
  static bool batterySaver = false;
  static Future<void> inspect() async {
    try {
      final data = await const MethodChannel('uz.lingoy/performance')
          .invokeMapMethod<String, dynamic>('budget');
      lowMemory =
          data?['lowRam'] == true ||
          ((data?['memoryMb'] as num?)?.toInt() ?? 2048) <= 3072;
      batterySaver = data?['batterySaver'] == true;
    } on PlatformException {
      lowMemory = true;
    } on MissingPluginException {
      lowMemory = true;
    }
  }
}

class MotionPolicy extends InheritedWidget {
  final bool light;
  const MotionPolicy({super.key, required this.light, required super.child});
  static bool lightOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MotionPolicy>()?.light ??
      false;
  @override
  bool updateShouldNotify(MotionPolicy oldWidget) => light != oldWidget.light;
}
