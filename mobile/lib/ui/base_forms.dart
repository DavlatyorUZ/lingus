import 'package:material_ui/material_ui.dart';

import '../core/morphology.dart';
import 'design.dart';

/// Displays alternatives without claiming contextual disambiguation.
class BaseFormsCard extends StatelessWidget {
  final List<BaseForm> forms;
  final ValueChanged<BaseForm> onOpen;
  final bool originalExists;
  const BaseFormsCard({
    super.key,
    required this.forms,
    required this.onOpen,
    this.originalExists = false,
  });
  @override
  Widget build(BuildContext c) {
    if (forms.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Glass(
        color: palette(c).elevated,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AppIcon(
                  AppIcons.swapHoriz,
                  size: 18,
                  color: Theme.of(c).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    forms.every((f) => f.unchanged)
                        ? 'Infinitiv'
                        : 'Asosiy shakl',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (originalExists && forms.any((f) => !f.unchanged))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '“${forms.first.input}” alohida lug‘at so‘zi ham bo‘lishi mumkin.',
                  style: TextStyle(color: muted(c), fontSize: 10),
                ),
              ),
            ...forms.map(
              (f) => InkWell(
                onTap: () => onOpen(f),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              f.unchanged
                                  ? f.infinitive
                                  : '${f.input} → ${f.infinitive}',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${f.partOfSpeech} · ${f.reasons.join('; ')}',
                              style: TextStyle(
                                color: muted(c),
                                fontSize: 10,
                                height: 1.6,
                              ),
                            ),
                            if (f.meaning.isNotEmpty ||
                                f.definition.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text(
                                f.meaning.isNotEmpty
                                    ? f.meaning
                                    : 'Inglizcha: ${f.definition}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      AppIcon(AppIcons.chevronRight, size: 18),
                    ],
                  ),
                ),
              ),
            ),
            if (forms.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text(
                  'Mos ma’noni gapdagi kontekstga qarab tanlang.',
                  style: TextStyle(color: muted(c), fontSize: 10),
                ),
              ),
            if (forms.any((f) => f.unchanged))
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Text(
                  'Zamon gapdagi kontekstga bog‘liq. Bu yerda fe’lning asosiy shakli berilgan.',
                  style: TextStyle(color: muted(c), fontSize: 10),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
