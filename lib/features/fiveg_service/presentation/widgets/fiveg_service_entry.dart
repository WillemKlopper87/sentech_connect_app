import 'package:flutter/material.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/entities/fiveg_usage.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/repositories/fiveg_repository.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// The "5G data" row on a fixed-wireless service's detail page. It reads the
/// allowance once and hides itself quietly when the feature is not available
/// for the service, or when the read fails: no error is shown for a row that
/// was never promised.
class FiveGServiceEntry extends StatefulWidget {
  const FiveGServiceEntry({super.key, required this.serviceId, required this.repository, required this.onOpen});

  final String serviceId;
  final FiveGRepository repository;
  final VoidCallback onOpen;

  @override
  State<FiveGServiceEntry> createState() => _FiveGServiceEntryState();
}

class _FiveGServiceEntryState extends State<FiveGServiceEntry> {
  FiveGUsage? _usage;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    final result = await widget.repository.getUsage(widget.serviceId);
    if (!mounted) return;
    setState(() => _usage = result.match((_) => null, (usage) => usage));
  }

  @override
  Widget build(BuildContext context) {
    final usage = _usage;
    if (usage == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final percent = usage.usedPercent;
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        minTileHeight: 48,
        leading: const Icon(Icons.signal_cellular_alt_outlined),
        title: Text(l10n.fivegTitle),
        subtitle: Text(percent == null ? l10n.fivegEntryFairUse : l10n.fivegEntryUsed('$percent')),
        trailing: const Icon(Icons.chevron_right),
        onTap: widget.onOpen,
      ),
    );
  }
}
