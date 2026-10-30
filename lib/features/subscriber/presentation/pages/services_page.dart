import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sentech_connect_app/app/router/app_router.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/services_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/widgets/service_card.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

/// The customer's home internet services, newest first; ended services sit
/// under "Past services". Needs a [ServicesCubit] above it.
class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.servicesTitle)),
      body: SafeArea(
        child: BlocBuilder<ServicesCubit, ServicesState>(
          builder: (context, state) {
            switch (state.status) {
              case ServicesStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case ServicesStatus.failure:
                return FailureView(failure: state.failure, onRetry: context.read<ServicesCubit>().load);
              case ServicesStatus.loaded:
                final current = state.current;
                final past = state.past;
                return RefreshIndicator(
                  onRefresh: () => context.read<ServicesCubit>().load(keepVisible: true),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (state.services.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Text(
                            l10n.servicesEmpty,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      for (final s in current) ...[
                        ServiceCard(service: s, onTap: () => context.push(AppRoutes.serviceFor(s.id))),
                        const SizedBox(height: 12),
                      ],
                      if (past.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(l10n.servicesPastTitle, style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        for (final s in past) ...[
                          ServiceCard(service: s, onTap: () => context.push(AppRoutes.serviceFor(s.id))),
                          const SizedBox(height: 12),
                        ],
                      ],
                    ],
                  ),
                );
            }
          },
        ),
      ),
    );
  }
}
