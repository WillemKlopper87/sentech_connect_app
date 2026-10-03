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

  test('stores details in the secure store and never persists the address or GPS coordinates', () async {
    final store = InMemorySecureStore();
    final repo = LocalRegistrationRepository(store);

    expect((await repo.save(details)).isRight(), isTrue);

    final raw = jsonDecode(store.snapshot.values.single) as Map<String, dynamic>;
    expect(raw.containsKey('latitude'), isFalse);
    expect(raw.containsKey('longitude'), isFalse);
    // The location notice says nothing location-derived stays on the phone.
    expect(raw.containsKey('address'), isFalse);
    expect(store.snapshot.values.single, isNot(contains('Lifalethu')));

    final saved = (await repo.getSaved()).getOrElse((_) => null);
    expect(saved?.email, 'lindiwe@example.com');
    expect(saved?.hasDeviceLocation, isFalse);
    expect(saved?.marketingPush, isTrue);
  });

  test('a record saved by an older version loses its address and coordinates on read', () async {
    final store = InMemorySecureStore();
    await store.write('registration_details', jsonEncode(details.toJson()));
    final repo = LocalRegistrationRepository(store);

    final saved = (await repo.getSaved()).getOrElse((_) => null);

    expect(saved?.email, 'lindiwe@example.com');
    expect(saved?.address, isEmpty);
    expect(saved?.hasDeviceLocation, isFalse);
    final raw = store.snapshot.values.single;
    expect(raw, isNot(contains('Lifalethu')));
    expect(raw, isNot(contains('latitude')));
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
