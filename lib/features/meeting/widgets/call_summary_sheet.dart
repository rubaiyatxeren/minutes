import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/localization/app_localizations.dart';

/// Shown right after a call ends (`conferenceTerminated`) so the person
/// gets a quick recap — how long it ran and who was on it — instead of
/// just being dumped back on the previous screen with no confirmation.
Future<void> showCallSummarySheet(
  BuildContext context, {
  required String topic,
  required Duration duration,
  required List<String> participantNames,
}) {
  String formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  return showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      final t = AppLocalizations.of(context);
      return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.call_end_rounded,
                  color: AppColors.danger, size: 30),
            ),
            const SizedBox(height: 16),
            Text(t.callEnded,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            if (topic.isNotEmpty)
              Text(topic,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SummaryStat(
                  icon: Icons.timer_outlined,
                  label: t.duration,
                  value: formatDuration(duration),
                ),
                _SummaryStat(
                  icon: Icons.people_outline_rounded,
                  label: t.participants,
                  value: '${participantNames.isEmpty ? 1 : participantNames.length}',
                ),
              ],
            ),
            if (participantNames.isNotEmpty) ...[
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: participantNames
                    .map((n) => Chip(
                          label: Text(n, style: const TextStyle(fontSize: 12)),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(t.done),
              ),
            ),
          ],
        ),
      ),
      );
    },
  );
}

class _SummaryStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryStat(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(height: 6),
        Text(value,
            style:
                const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
