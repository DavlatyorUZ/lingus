import 'package:material_ui/material_ui.dart';

import 'design.dart';
import '../screens/online_tools.dart';

class ComingTools extends StatelessWidget {
  const ComingTools({super.key});

  @override
  Widget build(BuildContext c) {
    const items = [
      ('Matn tarjima', 'assets/icons/google-translate.svg'),
      ('AI tarjima', 'assets/icons/sparkles.svg'),
      ('Rasm tarjima', 'assets/icons/camera.svg'),
      ('Grammatika', AppIcons.spellcheck),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(
        items.length,
        (i) => PressFeedback(
          child: ActionChip(
            key: ValueKey('coming-tool-$i'),
            avatar: AppIcon(items[i].$2, size: 18),
            label: Text(
              const ['Matn', 'AI', 'Rasm', 'Grammatika'][i],
              softWrap: false,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            onPressed: () => Navigator.push(
              c,
              MaterialPageRoute(builder: (_) => OnlineToolScreen(mode: i)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ),
    );
  }
}

class SearchComposer extends StatefulWidget {
  final TextEditingController controller;
  final bool reverse, busy, listening;
  final VoidCallback onSwap, onSearch, onClear;
  final VoidCallback? onVoice;
  final ValueChanged<String> onChanged;
  const SearchComposer({
    super.key,
    required this.controller,
    required this.reverse,
    required this.busy,
    required this.onSwap,
    required this.onSearch,
    required this.onClear,
    required this.onChanged,
    this.onVoice,
    this.listening = false,
  });
  @override
  State<SearchComposer> createState() => _SearchComposerState();
}

class _SearchComposerState extends State<SearchComposer> {
  final focus = FocusNode();
  @override
  void initState() {
    super.initState();
    focus.addListener(changed);
  }

  void changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    focus.removeListener(changed);
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) => AnimatedContainer(
    key: const ValueKey('search-dock'),
    duration: motionDuration(c, 180),
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    decoration: BoxDecoration(
      color: palette(c).surface,
      borderRadius: BorderRadius.circular(32),
      border: Border.all(
        color: focus.hasFocus
            ? Theme.of(c).colorScheme.primary.withValues(alpha: .7)
            : palette(c).border.withValues(alpha: .65),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: ink.withValues(alpha: dark(c) ? .16 : .05),
          blurRadius: focus.hasFocus ? 18 : 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      children: [
        PressFeedback(
          child: IconButton(
            tooltip: 'Qidirish',
            onPressed: widget.onSearch,
            icon: widget.busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : AppIcon(AppIcons.search, size: 20, color: muted(c)),
          ),
        ),
        Expanded(
          child: TextField(
            key: const ValueKey('dictionary-query'),
            focusNode: focus,
            controller: widget.controller,
            textInputAction: TextInputAction.search,
            maxLength: 160,
            onSubmitted: (_) => widget.onSearch(),
            onChanged: widget.onChanged,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: 'So‘z qidiring',
              counterText: '',
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              isDense: true,
            ),
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: widget.controller,
          builder: (_, value, child) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Tozalash',
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onClear,
                  icon: const AppIcon(AppIcons.close, size: 17),
                ),
        ),
        if (widget.onVoice != null)
          PressFeedback(
            child: IconButton(
              tooltip: 'Ovozli qidiruv',
              visualDensity: VisualDensity.compact,
              onPressed: widget.listening ? null : widget.onVoice,
              icon: widget.listening
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : AppIcon(AppIcons.mic, size: 20, color: muted(c)),
            ),
          ),
        PressFeedback(
          child: Semantics(
            button: true,
            label: widget.reverse
                ? 'O‘zbekchadan inglizchaga. Almashtirish'
                : 'Inglizchadan o‘zbekchaga. Almashtirish',
            child: GestureDetector(
              key: const ValueKey('search-language'),
              onTap: widget.onSwap,
              child: Container(
                width: 84,
                height: 44,
                decoration: BoxDecoration(
                  color: palette(c).elevated,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Stack(
                  children: [
                    AnimatedAlign(
                      alignment: widget.reverse
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      duration: motionDuration(c, 190),
                      curve: Curves.easeOutCubic,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Theme.of(c).colorScheme.primary,
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        for (final language in ['EN', 'UZ'])
                          Expanded(
                            child: Center(
                              child: Text(
                                language,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: (language == 'UZ') == widget.reverse
                                      ? Theme.of(c).colorScheme.onPrimary
                                      : muted(c),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
