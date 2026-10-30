import 'package:flutter/material.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/service_format.dart';

class ServiceStatusChip extends StatelessWidget {
  const ServiceStatusChip(this.status, {super.key});

  final ServiceStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      ServiceStatus.active => (scheme.primaryContainer, scheme.onPrimaryContainer),
      ServiceStatus.pending => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      ServiceStatus.suspended => (scheme.errorContainer, scheme.onErrorContainer),
      ServiceStatus.cancelled => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        serviceStatusLabel(context, status),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: foreground),
      ),
    );
  }
}
