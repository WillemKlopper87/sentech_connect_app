import 'dart:convert';
import 'dart:io';

/// Contract fixtures in test/fixtures/api/, copied from the platform's
/// response models (apps/api/openapi.json and the M1 plan's schemas).
/// When the contract changes, change the fixture and the mapping together.
Object? fixture(String name) => jsonDecode(File('test/fixtures/api/$name').readAsStringSync());

Map<String, Object?> fixtureMap(String name) => Map<String, Object?>.from(fixture(name)! as Map);

Map<String, Object?> tokenPair({String access = 'access-2', String refresh = 'refresh-2', int expiresIn = 900}) => {
      ...fixtureMap('token_pair.json'),
      'access_token': access,
      'refresh_token': refresh,
      'expires_in': expiresIn,
    };
