import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/passes/domain/repositories/passes_repository.dart';

class HttpPassesRepository implements PassesRepository {
  HttpPassesRepository(this._api);

  static const maxPages = 10;

  final ApiClient _api;

  @override
  Future<Either<Failure, List<Pass>>> getPasses({
    bool includeExpired = false,
  }) async {
    final passes = <Pass>[];
    String? cursor;
    for (var page = 0; page < maxPages; page++) {
      final result = await _api.get<(List<Pass>, String?)>(
        '/v1/me/entitlements',
        query: {
          'status': includeExpired ? 'all' : 'current',
          'limit': 50,
          'cursor': ?cursor,
        },
        decode: (data) {
          final map = data! as Map;
          return (
            [
              for (final item in map['items']! as List)
                passFromJson(Map<String, Object?>.from(item as Map)),
            ],
            map['next_cursor'] as String?,
          );
        },
      );
      switch (result) {
        case Left(value: final failure):
          return Left(failure);
        case Right(value: (final items, final next)):
          passes.addAll(items);
          cursor = next;
      }
      if (cursor == null) break;
    }
    return Right(passes);
  }
}
