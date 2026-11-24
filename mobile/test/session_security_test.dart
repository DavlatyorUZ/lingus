import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lingoy/core/account_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  final alice = <String, dynamic>{
    'id': 'alice',
    'name': 'Ali',
    'email': 'a@example.com',
  };
  final bob = <String, dynamic>{
    'id': 'bob',
    'name': 'Vali',
    'email': 'b@example.com',
  };
  test(
    'Native auth requests cannot overwrite refresh cookies concurrently',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      final calls = <String>[];
      final api = AccountApi(
        transport: (path, method, body) async {
          if (path == '/auth/csrf') {
            return {'csrfToken': 'csrf'};
          }
          calls.add(path);
          if (path == '/auth/login') {
            entered.complete();
            await release.future;
          }
          return {'ok': true};
        },
      );
      final login = api.request('/auth/login', method: 'POST', body: {});
      await entered.future;
      final poll = api.request('/auth/mobile/poll', method: 'POST', body: {});
      await Future<void>.delayed(Duration.zero);
      expect(calls, ['/auth/login']);
      release.complete();
      await Future.wait([login, poll]);
      expect(calls, ['/auth/login', '/auth/mobile/poll']);
    },
  );
  test(
    'Native saved-word mutation is not replayed under another account',
    () async {
      var posts = 0;
      final api = AccountApi(
        transport: (path, method, body) async {
          if (path == '/auth/csrf') {
            return {'csrfToken': 'csrf'};
          }
          if (path == '/auth/refresh') {
            return {'user': bob, 'accessToken': 'bob-token'};
          }
          posts++;
          throw const ApiFailure('expired', 401);
        },
      );
      await api.accept({'user': alice, 'accessToken': 'alice-token'});
      await expectLater(
        api.request('/saved', method: 'POST', body: {'changes': []}),
        throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 401)),
      );
      expect(posts, 1);
      expect(api.user?['id'], 'alice');
    },
  );
  test(
    'Successful native refresh retains the current account database binding',
    () async {
      var bindings = 0;
      final api = AccountApi(
        transport: (path, method, body) async => path == '/auth/csrf'
            ? {'csrfToken': 'csrf'}
            : {'user': alice, 'accessToken': 'new-token'},
      );
      api.onAccount = (_) async {
        bindings++;
      };
      await api.accept({'user': alice, 'accessToken': 'old-token'});
      await api.refresh();
      expect(bindings, 1);
      expect(api.user?['id'], 'alice');
    },
  );
}
