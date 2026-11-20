import 'package:campus_navigator/data/local_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalAuth.current.value = null;
  });

  test('sign up stores a hashed password and signs in', () async {
    final user = await LocalAuth.signUp('Asha', 'Asha@Example.com', 'secret1');
    expect(user.email, 'asha@example.com');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('local_auth_users_v1'), isNot(contains('secret1')));
    await LocalAuth.signOut();
    expect(LocalAuth.current.value, isNull);
    await LocalAuth.signIn('asha@example.com', 'secret1');
    expect(LocalAuth.current.value?.name, 'Asha');
  });

  test('rejects wrong password, duplicates and bad input', () async {
    await LocalAuth.signUp('Asha', 'asha@example.com', 'secret1');
    expect(
      () => LocalAuth.signIn('asha@example.com', 'wrong'),
      throwsA(isA<LocalAuthException>()),
    );
    expect(
      () => LocalAuth.signUp('B', 'asha@example.com', 'secret2'),
      throwsA(isA<LocalAuthException>()),
    );
    expect(
      () => LocalAuth.signUp('B', 'not-an-email', 'secret2'),
      throwsA(isA<LocalAuthException>()),
    );
    expect(
      () => LocalAuth.signUp('B', 'b@example.com', '123'),
      throwsA(isA<LocalAuthException>()),
    );
  });

  test('session is restored on restart', () async {
    await LocalAuth.signUp('Asha', 'asha@example.com', 'secret1');
    LocalAuth.current.value = null;
    await LocalAuth.restore();
    expect(LocalAuth.current.value?.email, 'asha@example.com');
  });
}
