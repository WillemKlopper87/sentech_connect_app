import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/local_registration_repository.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/registration_details.dart';

void main() {
  const details = RegistrationDetails(
    fullName: 'Lindiwe Khumalo',
    email: 'lindiwe@example.com',
    mobileNumber: '0810000000',
    address: '12 Lifalethu Ave, eMbalenhle',
    latitude: -26.5,
    longitude: 29.1,
    marketingPush: true,
  );

  test('stores details in the secure store and never persists GPS coordinates', () async {
    final store = InMemorySecureStore();
    final repo = LocalRegistrationRepository(store);

    expect((await repo.save(details)).isRight(), isTrue);

    final raw = jsonDecode(store.snapshot.values.single) as Map<String, dynamic>;
    expect(raw.containsKey('latitude'), isFalse);
    expect(raw.containsKey('longitude'), isFalse);

    final saved = (await repo.getSaved()).getOrElse((_) => null);
    expect(saved?.email, 'lindiwe@example.com');
    expect(saved?.hasDeviceLocation, isFalse);
    expect(saved?.marketingPush, isTrue);
  });

  test('clear removes everything', () async {
    final store = InMemorySecureStore();
    final repo = LocalRegistrationRepository(store);
    await repo.save(details);

    await repo.clear();

    expect(store.snapshot, isEmpty);
    expect((await repo.getSaved()).getOrElse((_) => details), isNull);
  });
}
