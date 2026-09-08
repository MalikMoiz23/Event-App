import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../models/agenda_item.dart';
import '../../models/event.dart';
import '../../models/event_draft.dart';
import '../../models/event_image.dart';
import '../../services/event_service.dart';
import '../../theme/app_dimens.dart';
import '../../widgets/state_views.dart';

/// Create or edit an event.
///
/// Grouped into sections rather than presented as one column of eighteen
/// fields: only the first group is required, and an admin publishing a
/// five-minute notice should not have to scroll past coordinates and
/// organiser contact details to reach the save button.
///
/// The gallery and the running order are only offered while editing. Both are
/// rows in other tables that reference the event's id, and a new event has no
/// id until it is saved - so rather than holding them in memory and hoping
/// the insert succeeds, the form says so and enables them afterwards.
class EventFormScreen extends StatefulWidget {
  const EventFormScreen({
    super.key,
    required this.createdBy,
    this.existingEvent,
  });

  final String createdBy;
  final Event? existingEvent;

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _charges;
  late final TextEditingController _capacity;
  late final TextEditingController _venueName;
  late final TextEditingController _venueAddress;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late final TextEditingController _organizerName;
  late final TextEditingController _organizerPhone;
  late final TextEditingController _organizerEmail;
  final _tagInput = TextEditingController();

  late EventCategory _category;
  late DateTime _startsAt;
  late DateTime _endsAt;
  late List<String> _tags;
  late bool _published;

  Uint8List? _pickedImageBytes;
  String? _pickedImageExtension;
  String? _imageUrl;
  bool _submitting = false;

  Event? get _existing => widget.existingEvent;
  bool get _isEditing => _existing != null;

  @override
  void initState() {
    super.initState();
    final e = _existing;
    _name = TextEditingController(text: e?.name ?? '');
    _description = TextEditingController(text: e?.description ?? '');
    _charges = TextEditingController(
      text: e == null ? '0' : e.charges.toStringAsFixed(0),
    );
    _capacity = TextEditingController(text: e?.capacity?.toString() ?? '');
    _venueName = TextEditingController(text: e?.venueName ?? '');
    _venueAddress = TextEditingController(text: e?.venueAddress ?? '');
    _latitude = TextEditingController(text: e?.latitude?.toString() ?? '');
    _longitude = TextEditingController(text: e?.longitude?.toString() ?? '');
    _organizerName = TextEditingController(text: e?.organizerName ?? '');
    _organizerPhone = TextEditingController(text: e?.organizerPhone ?? '');
    _organizerEmail = TextEditingController(text: e?.organizerEmail ?? '');

    _category = e?.category ?? EventCategory.general;
    _startsAt = e?.eventDate ?? _nextRoundHour();
    _endsAt = e?.endDate ?? _startsAt.add(const Duration(hours: 3));
    _tags = [...?e?.tags];
    _published = e?.isPublished ?? true;
    _imageUrl = e?.imageUrl;
  }

  /// A sensible default start: tomorrow, on the hour.
  static DateTime _nextRoundHour() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 18);
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _description,
      _charges,
      _capacity,
      _venueName,
      _venueAddress,
      _latitude,
      _longitude,
      _organizerName,
      _organizerPhone,
      _organizerEmail,
      _tagInput,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit event' : 'New event'),
        actions: [
          if (_isEditing)
            Padding(
              padding: const EdgeInsets.only(right: Gap.sm),
              child: Center(
                child: Text(
                  _published ? 'Published' : 'Draft',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Gap.page,
              Gap.lg,
              Gap.page,
              Gap.huge,
            ),
            children: [
              _CoverPicker(
                bytes: _pickedImageBytes,
                imageUrl: _imageUrl,
                onPick: _pickCover,
                onClear: _pickedImageBytes == null && _imageUrl == null
                    ? null
                    : () => setState(() {
                        _pickedImageBytes = null;
                        _pickedImageExtension = null;
                        _imageUrl = null;
                      }),
              ),

              _Section(
                title: 'The basics',
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Event name'),
                    validator: (v) => (v == null || v.trim().length < 3)
                        ? 'Give the event a name'
                        : null,
                  ),
                  Gap.h16,
                  TextFormField(
                    controller: _description,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                      helperText: 'Shown on the event page and in shares',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Describe the event'
                        : null,
                  ),
                  Gap.h16,
                  DropdownButtonFormField<EventCategory>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: [
                      for (final category in EventCategory.values)
                        DropdownMenuItem(
                          value: category,
                          child: Text(category.label),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _category = value);
                    },
                  ),
                ],
              ),

              _Section(
                title: 'When',
                children: [
                  _DateTimeRow(
                    label: 'Starts',
                    value: _startsAt,
                    onTap: () => _pickDateTime(isStart: true),
                  ),
                  const Divider(height: Gap.xl),
                  _DateTimeRow(
                    label: 'Ends',
                    value: _endsAt,
                    onTap: () => _pickDateTime(isStart: false),
                  ),
                  Gap.h8,
                  Text(
                    'Runs for ${Formatters.span(_startsAt, _endsAt)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              _Section(
                title: 'Where',
                children: [
                  TextFormField(
                    controller: _venueName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Venue',
                      hintText: 'Officers Mess',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                  ),
                  Gap.h16,
                  TextFormField(
                    controller: _venueAddress,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      hintText: 'HIT Taxila Cantt',
                    ),
                  ),
                  Gap.h16,
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _latitude,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Latitude',
                          ),
                          validator: (v) => _validateCoordinate(v, 90),
                        ),
                      ),
                      Gap.w12,
                      Expanded(
                        child: TextFormField(
                          controller: _longitude,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Longitude',
                          ),
                          validator: (v) => _validateCoordinate(v, 180),
                        ),
                      ),
                    ],
                  ),
                  Gap.h8,
                  Text(
                    'Coordinates are optional. With them, "Directions" drops '
                    'an exact pin; without them it searches for the address.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              _Section(
                title: 'Tickets',
                children: [
                  TextFormField(
                    controller: _charges,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      prefixText: 'PKR ',
                      helperText: 'Enter 0 for free entry',
                    ),
                    validator: (v) {
                      final value = double.tryParse((v ?? '').trim());
                      if (value == null) return 'Enter a number, or 0';
                      if (value < 0) return 'Price cannot be negative';
                      return null;
                    },
                  ),
                  Gap.h16,
                  TextFormField(
                    controller: _capacity,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Capacity',
                      prefixIcon: Icon(Icons.event_seat_outlined),
                      helperText:
                          'Leave empty for unlimited. Once full, further '
                          'bookings join a waitlist automatically.',
                    ),
                    validator: (v) {
                      final raw = (v ?? '').trim();
                      if (raw.isEmpty) return null;
                      final value = int.tryParse(raw);
                      if (value == null || value < 1) {
                        return 'Enter a seat count above zero';
                      }
                      // Lowering capacity below what is already booked is a
                      // real mistake: it makes the meter read as oversold and
                      // nobody gets waitlisted correctly afterwards.
                      return null;
                    },
                  ),
                  Gap.h16,
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _published,
                    onChanged: (value) => setState(() => _published = value),
                    title: const Text('Published'),
                    subtitle: Text(
                      _published
                          ? 'Visible to everyone and open for booking'
                          : 'Only admins can see this, and nobody can book',
                    ),
                  ),
                ],
              ),

              _Section(
                title: 'Tags',
                children: [
                  TextFormField(
                    controller: _tagInput,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _addTag(),
                    decoration: InputDecoration(
                      labelText: 'Add a tag',
                      hintText: 'sports, outdoor, families',
                      prefixIcon: const Icon(Icons.sell_outlined),
                      suffixIcon: IconButton(
                        tooltip: 'Add',
                        icon: const Icon(Icons.add_rounded),
                        onPressed: _addTag,
                      ),
                    ),
                  ),
                  if (_tags.isNotEmpty) ...[
                    Gap.h12,
                    Wrap(
                      spacing: Gap.sm,
                      runSpacing: Gap.sm,
                      children: [
                        for (final tag in _tags)
                          InputChip(
                            label: Text(tag),
                            onDeleted: () => setState(() => _tags.remove(tag)),
                          ),
                      ],
                    ),
                  ],
                ],
              ),

              _Section(
                title: 'Organiser',
                children: [
                  TextFormField(
                    controller: _organizerName,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Contact name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                  ),
                  Gap.h16,
                  TextFormField(
                    controller: _organizerPhone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.call_outlined),
                    ),
                  ),
                  Gap.h16,
                  TextFormField(
                    controller: _organizerEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                    validator: (v) {
                      final email = (v ?? '').trim();
                      if (email.isEmpty) return null;
                      return RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(email)
                          ? null
                          : 'Enter a valid email address';
                    },
                  ),
                ],
              ),

              if (_isEditing) ...[
                _GalleryEditor(eventId: _existing!.id),
                _AgendaEditor(eventId: _existing!.id, eventStart: _startsAt),
              ] else
                _Section(
                  title: 'Photos and running order',
                  children: [
                    Text(
                      'Save the event first. Both attach to it by id, so they '
                      'become available as soon as it exists.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

              Gap.h32,
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isEditing ? 'Save changes' : 'Publish event'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _validateCoordinate(String? value, double limit) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return null;
    final parsed = double.tryParse(raw);
    if (parsed == null) return 'Enter a number';
    if (parsed < -limit || parsed > limit) return 'Must be between ±$limit';
    return null;
  }

  void _addTag() {
    final tag = _tagInput.text.trim();
    if (tag.isEmpty) return;
    setState(() {
      // Case-insensitive de-dupe: "Sports" and "sports" would otherwise
      // become two separate filter chips for the same thing.
      if (!_tags.any((t) => t.toLowerCase() == tag.toLowerCase())) {
        _tags.add(tag);
      }
      _tagInput.clear();
    });
  }

  Future<void> _pickCover() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    // `file.path` is a blob: URL on web with no usable extension - `name`
    // holds the original filename on every platform.
    final name = file.name;
    final extension = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : 'jpg';
    if (!mounted) return;
    setState(() {
      _pickedImageBytes = bytes;
      _pickedImageExtension = extension;
    });
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _startsAt : _endsAt;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;

    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        // Keep the duration the admin already chose rather than snapping the
        // end back to a default three hours.
        final duration = _endsAt.difference(_startsAt);
        _startsAt = combined;
        _endsAt = combined.add(
          duration.isNegative ? const Duration(hours: 3) : duration,
        );
      } else {
        _endsAt = combined;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    if (!_endsAt.isAfter(_startsAt)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('The end time must be after the start.')),
      );
      return;
    }

    // Captured before the first await: reaching for context across an async
    // gap is what use_build_context_synchronously exists to catch.
    final service = context.read<EventService>();
    final navigator = Navigator.of(context);

    setState(() => _submitting = true);
    try {
      var imageUrl = _imageUrl;
      final bytes = _pickedImageBytes;
      final extension = _pickedImageExtension;
      if (bytes != null && extension != null) {
        imageUrl = await service.uploadCoverImage(
          bytes: bytes,
          fileExtension: extension,
        );
      }

      final draft = EventDraft(
        name: _name.text,
        description: _description.text,
        charges: double.tryParse(_charges.text.trim()) ?? 0,
        category: _category,
        eventDate: _startsAt,
        endDate: _endsAt,
        imageUrl: imageUrl,
        venueName: _venueName.text,
        venueAddress: _venueAddress.text,
        latitude: double.tryParse(_latitude.text.trim()),
        longitude: double.tryParse(_longitude.text.trim()),
        organizerName: _organizerName.text,
        organizerPhone: _organizerPhone.text,
        organizerEmail: _organizerEmail.text,
        capacity: int.tryParse(_capacity.text.trim()),
        tags: _tags,
        isPublished: _published,
      );

      final existing = _existing;
      if (existing != null) {
        await service.updateEvent(existing.id, draft);
        navigator.pop();
      } else {
        final created = await service.createEvent(
          draft,
          createdBy: widget.createdBy,
        );
        // Straight back into the form for the new event, so the gallery and
        // running order can be filled in without hunting for it in the list.
        navigator.pushReplacement(
          MaterialPageRoute(
            builder: (_) => EventFormScreen(
              createdBy: widget.createdBy,
              existingEvent: created,
            ),
          ),
        );
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              _published
                  ? 'Published. Add photos and a running order below.'
                  : 'Saved as a draft. Publish it when you are ready.',
            ),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save the event: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: Gap.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: Gap.xs, bottom: Gap.md),
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverPicker extends StatelessWidget {
  const _CoverPicker({
    required this.bytes,
    required this.imageUrl,
    required this.onPick,
    required this.onClear,
  });

  final Uint8List? bytes;
  final String? imageUrl;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasImage = bytes != null || imageUrl != null;

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Material(
            color: scheme.surfaceContainerHigh,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: Corner.lgAll,
              side: BorderSide(color: scheme.outlineVariant),
            ),
            child: InkWell(
              onTap: onPick,
              child: bytes != null
                  ? Image.memory(bytes!, fit: BoxFit.cover)
                  : (imageUrl != null
                        ? Image.network(
                            imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, _, _) =>
                                _Prompt(scheme: scheme),
                          )
                        : _Prompt(scheme: scheme)),
            ),
          ),
        ),
        Gap.h8,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: onPick,
              icon: const Icon(Icons.image_outlined, size: 18),
              label: Text(hasImage ? 'Replace cover' : 'Add a cover photo'),
            ),
            if (onClear != null)
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Remove'),
              ),
          ],
        ),
      ],
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 32,
            color: scheme.onSurfaceVariant,
          ),
          Gap.h8,
          Text(
            'Optional - a category icon is used if you skip it',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _DateTimeRow extends StatelessWidget {
  const _DateTimeRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: Corner.smAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Gap.h2,
                  Text(Formatters.fullDateTime.format(value)),
                ],
              ),
            ),
            Icon(Icons.edit_calendar_outlined, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Extra photos, saved immediately rather than on form submit.
///
/// Each one is its own row, so batching them into the parent save would mean
/// holding several megabytes of image bytes in memory and rolling back
/// uploads if the event update failed.
class _GalleryEditor extends StatefulWidget {
  const _GalleryEditor({required this.eventId});

  final String eventId;

  @override
  State<_GalleryEditor> createState() => _GalleryEditorState();
}

class _GalleryEditorState extends State<_GalleryEditor> {
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    final service = context.read<EventService>();

    return _Section(
      title: 'Gallery',
      children: [
        StreamBuilder<List<EventImage>>(
          stream: service.watchImages(widget.eventId),
          builder: (context, snapshot) {
            final images = snapshot.data ?? const <EventImage>[];
            if (images.isEmpty) {
              return const EmptyState(
                icon: Icons.photo_library_outlined,
                title: 'No extra photos',
                message: 'Add a few and they show as a strip on the event.',
                compact: true,
              );
            }
            return SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, _) => Gap.w8,
                itemBuilder: (context, index) => _GalleryThumb(
                  image: images[index],
                  onRemove: () => service.removeGalleryImage(images[index].id),
                ),
              ),
            );
          },
        ),
        Gap.h12,
        OutlinedButton.icon(
          onPressed: _uploading ? null : _addImage,
          icon: _uploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_photo_alternate_outlined, size: 18),
          label: Text(_uploading ? 'Uploading…' : 'Add photo'),
        ),
      ],
    );
  }

  Future<void> _addImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;

    final service = context.read<EventService>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _uploading = true);
    try {
      final bytes = await file.readAsBytes();
      final name = file.name;
      final extension = name.contains('.')
          ? name.split('.').last.toLowerCase()
          : 'jpg';
      final url = await service.uploadCoverImage(
        bytes: bytes,
        fileExtension: extension,
      );
      await service.addGalleryImage(
        eventId: widget.eventId,
        imageUrl: url,
        // Ordered by upload time; the stream re-sorts by position anyway.
        position: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not add that photo: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
}

class _GalleryThumb extends StatelessWidget {
  const _GalleryThumb({required this.image, required this.onRemove});

  final EventImage image;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 128,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: Corner.mdAll,
            child: Image.network(
              image.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, _, _) => ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: IconButton(
              tooltip: 'Remove',
              iconSize: 16,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.close_rounded),
              onPressed: onRemove,
            ),
          ),
        ],
      ),
    );
  }
}

/// The running order, also saved per row.
class _AgendaEditor extends StatelessWidget {
  const _AgendaEditor({required this.eventId, required this.eventStart});

  final String eventId;
  final DateTime eventStart;

  @override
  Widget build(BuildContext context) {
    final service = context.read<EventService>();

    return _Section(
      title: 'Running order',
      children: [
        StreamBuilder<List<AgendaItem>>(
          stream: service.watchAgenda(eventId),
          builder: (context, snapshot) {
            final items = snapshot.data ?? const <AgendaItem>[];
            if (items.isEmpty) {
              return const EmptyState(
                icon: Icons.list_alt_rounded,
                title: 'No schedule',
                message: 'Optional - add slots for a multi-part event.',
                compact: true,
              );
            }
            return Column(
              children: [
                for (final item in items)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Text(
                      Formatters.timeOnly.format(item.startsAt),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    title: Text(item.title),
                    subtitle: item.hasSpeaker ? Text(item.speaker!) : null,
                    trailing: IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => service.removeAgendaItem(item.id),
                    ),
                  ),
              ],
            );
          },
        ),
        Gap.h12,
        OutlinedButton.icon(
          onPressed: () => _addItem(context, service),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add a slot'),
        ),
      ],
    );
  }

  Future<void> _addItem(BuildContext context, EventService service) async {
    final result = await showModalBottomSheet<_AgendaDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AgendaSheet(defaultStart: eventStart),
    );
    if (result == null) return;
    await service.addAgendaItem(
      eventId: eventId,
      title: result.title,
      speaker: result.speaker,
      startsAt: result.startsAt,
      endsAt: result.endsAt,
    );
  }
}

class _AgendaDraft {
  const _AgendaDraft({
    required this.title,
    required this.startsAt,
    this.speaker,
    this.endsAt,
  });

  final String title;
  final DateTime startsAt;
  final String? speaker;
  final DateTime? endsAt;
}

class _AgendaSheet extends StatefulWidget {
  const _AgendaSheet({required this.defaultStart});

  final DateTime defaultStart;

  @override
  State<_AgendaSheet> createState() => _AgendaSheetState();
}

class _AgendaSheetState extends State<_AgendaSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _speaker = TextEditingController();
  late DateTime _startsAt = widget.defaultStart;

  /// Null means open-ended, which is fine - it just means the event page
  /// cannot mark the slot as currently running.
  int? _durationMinutes = 30;

  @override
  void dispose() {
    _title.dispose();
    _speaker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: Gap.xl,
          right: Gap.xl,
          bottom: MediaQuery.viewInsetsOf(context).bottom + Gap.xl,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Add a slot', style: Theme.of(context).textTheme.titleLarge),
              Gap.h20,
              TextFormField(
                controller: _title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'What happens',
                  hintText: 'Prize distribution',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              Gap.h16,
              TextFormField(
                controller: _speaker,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Who (optional)',
                  hintText: 'Chief guest',
                ),
              ),
              Gap.h16,
              _DateTimeRow(label: 'Starts', value: _startsAt, onTap: _pickTime),
              const Divider(height: Gap.xl),
              // An end time is what makes the "running now" highlight on the
              // event page possible: with no end, a slot can never be known
              // to be in progress. Offered as durations rather than a second
              // clock, since the answer is nearly always a round number.
              Text(
                'RUNS FOR',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Gap.h8,
              Wrap(
                spacing: Gap.sm,
                children: [
                  for (final minutes in const [15, 30, 45, 60, 90, 120])
                    ChoiceChip(
                      label: Text(
                        minutes < 60 ? '${minutes}m' : '${minutes ~/ 60}h',
                      ),
                      selected: _durationMinutes == minutes,
                      onSelected: (selected) => setState(
                        () => _durationMinutes = selected ? minutes : null,
                      ),
                    ),
                ],
              ),
              Gap.h20,
              FilledButton(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  final minutes = _durationMinutes;
                  Navigator.of(context).pop(
                    _AgendaDraft(
                      title: _title.text,
                      speaker: _speaker.text,
                      startsAt: _startsAt,
                      endsAt: minutes == null
                          ? null
                          : _startsAt.add(Duration(minutes: minutes)),
                    ),
                  );
                },
                child: const Text('Add slot'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: _startsAt.subtract(const Duration(days: 1)),
      lastDate: _startsAt.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startsAt),
    );
    if (time == null || !mounted) return;
    setState(
      () => _startsAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }
}
