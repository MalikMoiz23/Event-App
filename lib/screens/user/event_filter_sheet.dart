import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../models/event.dart';
import '../../models/event_filter.dart';
import '../../theme/app_dimens.dart';
import '../../theme/category_style.dart';

/// The filter and sort sheet behind the Discover toolbar.
///
/// A sheet rather than a row of chips because there are six criteria: as
/// chips they would need two lines of horizontal scrolling, which hides most
/// of them and pushes the actual events off the screen. The chip row that
/// stays visible is the one people use constantly - category - and everything
/// else lives one tap away in here.
///
/// It edits a local copy and returns it on Apply, so backing out with the
/// system gesture leaves the list exactly as it was.
Future<EventFilter?> showEventFilterSheet(
  BuildContext context, {
  required EventFilter current,
  required List<String> availableTags,
}) {
  return showModalBottomSheet<EventFilter>(
    context: context,
    isScrollControlled: true,
    builder: (_) =>
        _EventFilterSheet(initial: current, availableTags: availableTags),
  );
}

class _EventFilterSheet extends StatefulWidget {
  const _EventFilterSheet({required this.initial, required this.availableTags});

  final EventFilter initial;
  final List<String> availableTags;

  @override
  State<_EventFilterSheet> createState() => _EventFilterSheetState();
}

class _EventFilterSheetState extends State<_EventFilterSheet> {
  late EventFilter _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return SafeArea(
      child: ConstrainedBox(
        // Never taller than three quarters of the screen: the sheet has to
        // read as a layer over the list, not a replacement for it.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.xl, 0, Gap.md, Gap.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Filter & sort', style: text.titleLarge),
                  ),
                  TextButton(
                    onPressed: _draft.isClear
                        ? null
                        : () => setState(
                            // The search text belongs to the field in the
                            // toolbar, so Reset leaves it alone.
                            () => _draft = EventFilter(query: _draft.query),
                          ),
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  Gap.xl,
                  Gap.lg,
                  Gap.xl,
                  Gap.xl,
                ),
                children: [
                  _Label('Sort by'),
                  Gap.h8,
                  _ChipWrap(
                    children: [
                      for (final sort in EventSort.values)
                        ChoiceChip(
                          label: Text(sort.label),
                          selected: _draft.sort == sort,
                          onSelected: (_) => setState(
                            () => _draft = _draft.copyWith(sort: sort),
                          ),
                        ),
                    ],
                  ),

                  Gap.h24,
                  _Label('Category'),
                  Gap.h8,
                  _ChipWrap(
                    children: [
                      for (final category in EventCategory.values)
                        FilterChip(
                          avatar: Icon(
                            CategoryStyle.iconOf(category),
                            size: 15,
                            color: CategoryStyle.tintOf(
                              category,
                              Theme.of(context).brightness,
                            ),
                          ),
                          label: Text(category.label),
                          selected: _draft.categories.contains(category),
                          onSelected: (selected) => setState(() {
                            final next = {..._draft.categories};
                            selected
                                ? next.add(category)
                                : next.remove(category);
                            _draft = _draft.copyWith(categories: next);
                          }),
                        ),
                    ],
                  ),

                  Gap.h24,
                  _Label('Price'),
                  Gap.h8,
                  SegmentedButton<PriceFilter>(
                    segments: [
                      for (final price in PriceFilter.values)
                        ButtonSegment(value: price, label: Text(price.label)),
                    ],
                    selected: {_draft.price},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) => setState(
                      () => _draft = _draft.copyWith(price: selection.first),
                    ),
                  ),

                  Gap.h24,
                  _Label('Dates'),
                  Gap.h8,
                  _ChipWrap(
                    children: [
                      _PresetChip(
                        label: 'Today',
                        selected: _matchesPreset(_DatePreset.today),
                        onTap: () => _applyPreset(_DatePreset.today),
                      ),
                      _PresetChip(
                        label: 'This week',
                        selected: _matchesPreset(_DatePreset.week),
                        onTap: () => _applyPreset(_DatePreset.week),
                      ),
                      _PresetChip(
                        label: 'This month',
                        selected: _matchesPreset(_DatePreset.month),
                        onTap: () => _applyPreset(_DatePreset.month),
                      ),
                    ],
                  ),
                  Gap.h12,
                  Row(
                    children: [
                      Expanded(
                        child: _DateField(
                          label: 'From',
                          value: _draft.from,
                          onPick: (picked) => setState(
                            () => _draft = _draft.copyWith(from: picked),
                          ),
                        ),
                      ),
                      Gap.w12,
                      Expanded(
                        child: _DateField(
                          label: 'To',
                          value: _draft.to,
                          onPick: (picked) => setState(
                            // End of the chosen day, so "to 5 Sep" includes
                            // an event that evening rather than excluding
                            // everything after midnight.
                            () => _draft = _draft.copyWith(
                              to: DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                23,
                                59,
                                59,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_draft.from != null || _draft.to != null) ...[
                    Gap.h8,
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () => setState(
                          () => _draft = _draft.copyWith(clearDates: true),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Clear dates'),
                      ),
                    ),
                  ],

                  if (widget.availableTags.isNotEmpty) ...[
                    Gap.h24,
                    _Label('Tags'),
                    Gap.h8,
                    _ChipWrap(
                      children: [
                        for (final tag in widget.availableTags)
                          FilterChip(
                            label: Text(tag),
                            selected: _draft.tags.contains(tag),
                            onSelected: (selected) => setState(() {
                              final next = {..._draft.tags};
                              selected ? next.add(tag) : next.remove(tag);
                              _draft = _draft.copyWith(tags: next);
                            }),
                          ),
                      ],
                    ),
                  ],

                  Gap.h16,
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _draft.hideSoldOut,
                    onChanged: (value) => setState(
                      () => _draft = _draft.copyWith(hideSoldOut: value),
                    ),
                    title: const Text('Hide sold out'),
                    subtitle: const Text('Events you can still get a seat at'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Gap.xl,
                Gap.md,
                Gap.xl,
                Gap.lg,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _draft.activeCriteriaCount == 0
                          ? 'No filters applied'
                          : '${_draft.activeCriteriaCount} filter'
                                '${_draft.activeCriteriaCount == 1 ? '' : 's'} applied',
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Gap.w12,
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(_draft),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(132, 48),
                    ),
                    child: const Text('Show results'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _matchesPreset(_DatePreset preset) {
    final (from, to) = preset.range();
    return _draft.from?.day == from.day &&
        _draft.from?.month == from.month &&
        _draft.to?.day == to.day &&
        _draft.to?.month == to.month;
  }

  void _applyPreset(_DatePreset preset) {
    setState(() {
      if (_matchesPreset(preset)) {
        _draft = _draft.copyWith(clearDates: true);
        return;
      }
      final (from, to) = preset.range();
      _draft = _draft.copyWith(from: from, to: to);
    });
  }
}

enum _DatePreset {
  today,
  week,
  month;

  (DateTime, DateTime) range() {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return switch (this) {
      _DatePreset.today => (
        startOfToday,
        startOfToday.add(const Duration(days: 1, seconds: -1)),
      ),
      // Runs to the end of Sunday, taking Monday as the first day.
      _DatePreset.week => (
        startOfToday,
        startOfToday
            .add(Duration(days: 7 - now.weekday + 1))
            .subtract(const Duration(seconds: 1)),
      ),
      _DatePreset.month => (
        startOfToday,
        DateTime(
          now.year,
          now.month + 1,
          1,
        ).subtract(const Duration(seconds: 1)),
      ),
    };
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: Gap.sm, runSpacing: Gap.sm, children: children);
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onPick,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: now.subtract(const Duration(days: 365 * 2)),
          lastDate: now.add(const Duration(days: 365 * 3)),
        );
        if (picked != null) onPick(picked);
      },
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: Gap.md),
      ),
      icon: Icon(
        Icons.event_outlined,
        size: 17,
        color: scheme.onSurfaceVariant,
      ),
      label: Text(
        value == null ? label : Formatters.dayMonth.format(value!),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: value == null ? scheme.onSurfaceVariant : scheme.onSurface,
        ),
      ),
    );
  }
}
