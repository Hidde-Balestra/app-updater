import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mocks the Clipboard.setData/getData/hasStrings platform calls.
///
/// flutter_test's TestWidgetsFlutterBinding does not handle these by
/// default in `testWidgets` tests — `Clipboard.setData` hangs forever
/// waiting on a platform response that never arrives unless this is
/// installed (confirmed by hand; a bare `test()` body tolerates the
/// missing handler, but a real widget pump does not).
class MockClipboard {
  String? _text;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, _handle);
  }

  Future<Object?> _handle(MethodCall call) async {
    switch (call.method) {
      case 'Clipboard.setData':
        _text = (call.arguments as Map)['text'] as String?;
        return null;
      case 'Clipboard.getData':
        return {'text': _text};
      case 'Clipboard.hasStrings':
        return {'value': _text != null};
      default:
        return null;
    }
  }
}
