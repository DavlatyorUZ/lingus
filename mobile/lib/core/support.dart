import 'package:url_launcher/url_launcher.dart';

abstract final class SupportContact {
  static final telegram = Uri.https('t.me', '/davlatyoruz');
  static final phone = Uri(scheme: 'tel', path: '+998934920107');
  static Future<bool> open(Uri uri) async {
    if (uri != telegram && uri != phone) throw ArgumentError('Unknown contact');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
