// ignore_for_file: prefer_initializing_formals

import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
import 'package:sentech_connect_app/features/passes/data/repositories/pass_local_store.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/passes/domain/repositories/passes_repository.dart';

class HttpPassesRepository implements PassesRepository {
  HttpPassesRepository(
    this._api, {
    TokenStore? tokens,
    PassLocalStore? cache,
    DateTime Function()? now,
  }) : _tokens = tokens,
       _cache = cache,
       _now = now ?? DateTime.now;

  static const maxPages = 10;
  static const _incomplete = ServerFailure(
    'We could not load all of your passes. Please try again.',
  );

  final ApiClient _api;
  final TokenStore? _tokens;
  final PassLocalStore? _cache;
  final DateTime Function() _now;

  @override
  Future<Either<Failure, List<Pass>>> getPasses({
    bool includeExpired = false,
  }) async => (await getPassLoad(
    includeExpired: includeExpired,
  )).map((load) => load.passes);

  @override
  Future<Either<Failure, PassLoad>> getPassLoad({
    bool includeExpired = false,
  }) async {
    // One scope for the whole load: a sign-out, customer or tenant switch
    // between pages discards the operation instead of mixing customers.
    final scope = await _api.captureScope();
    final cache = _cache;
    final cacheGeneration = cache?.generation;
    final token = await _tokens?.read();
    if (!scope.isCurrent) return const Left(UnauthorizedFailure());
    final trusted = token != null && token.tenantSlug == _api.tenant.slug;
    final tenant = token?.tenantSlug;
    final user = token?.customerId;
    bool current() =>
        scope.isCurrent &&
        cache?.generation == cacheGeneration &&
        trusted &&
        tenant == _api.tenant.slug;
    final passes = <Pass>[];
    final seen = <String>{};
    String? cursor;
    for (var page = 0; page < maxPages; page++) {
      final result = await _api.get<(List<Pass>, String?)>(
        '/v1/me/entitlements',
        scope: scope,
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
      if (!scope.isCurrent ||
          cache != null && cache.generation != cacheGeneration) {
        return const Left(UnauthorizedFailure());
      }
      switch (result) {
        case Left(value: final failure):
          if (failure is NetworkFailure &&
              cache != null &&
              trusted &&
              tenant != null &&
              user != null) {
            final cached = await cache.read(
              tenant,
              user,
              includeExpired: includeExpired,
              isCurrent: current,
            );
            if (!scope.isCurrent || cache.generation != cacheGeneration) {
              return const Left(UnauthorizedFailure());
            }
            if (cached != null) return Right(cached);
          }
          return Left(failure);
        case Right(value: (final items, final next)):
          passes.addAll(items);
          cursor = next;
      }
      if (cursor == null) {
        if (!scope.isCurrent ||
            cache != null && cache.generation != cacheGeneration) {
          return const Left(UnauthorizedFailure());
        }
        final load = PassLoad(passes: passes, loadedAt: _now().toUtc());
        if (cache != null && trusted && tenant != null && user != null) {
          try {
            await cache.save(
              tenant,
              user,
              load,
              includeExpired: includeExpired,
              isCurrent: current,
            );
          } on Object {
            // A full local store cannot hide a valid server response.
          }
        }
        if (!scope.isCurrent ||
            cache != null && cache.generation != cacheGeneration) {
          return const Left(UnauthorizedFailure());
        }
        return Right(load);
      }
      // A repeated cursor would loop forever; hitting the page cap means the
      // list is incomplete. Both are failures, never a silently short list.
      if (!seen.add(cursor)) return const Left(_incomplete);
    }
    return const Left(_incomplete);
  }
}
