import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/formatters.dart';
import '../../models/event.dart';
import '../../models/event_draft.dart';
import '../../services/event_service.dart';
import '../../theme/app_colors.dart';

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
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _chargesController;
  late EventCategory _category;
  late DateTime _eventDate;
  late DateTime _endDate;

  Uint8List? _pickedImageBytes;
  String? _pickedImageExtension;
  String? _existingImageUrl;
  bool _submitting = false;

  bool get _isEditing => widget.existingEvent != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existingEvent;
    _nameController = TextEditingController(text: e?.name ?? '');
    _descriptionController = TextEditingController(text: e?.description ?? '');
    _chargesController = TextEditingController(
      text: e == null ? '0' : e.charges.toStringAsFixed(0),
    );
    _category = e?.category ?? EventCategory.general;
    _eventDate = e?.eventDate ?? DateTime.now().add(const Duration(days: 1));
    _endDate = e?.endDate ?? _eventDate.add(const Duration(hours: 3));
    _existingImageUrl = e?.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _chargesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    // `file.path` is a blob: URL on web with no real extension - use `name`
    // instead, which holds the original filename on every platform.
    final name = file.name;
    final extension = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : 'jpg';
    setState(() {
      _pickedImageBytes = bytes;
      _pickedImageExtension = extension;
    });
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final initial = isStart ? _eventDate : _endDate;
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
    if (time == null) return;
    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        _eventDate = combined;
        if (_endDate.isBefore(_eventDate)) {
          _endDate = _eventDate.add(const Duration(hours: 3));
        }
      } else {
        _endDate = combined;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_endDate.isBefore(_eventDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }
    // Captured before the first await. Reaching for context across an async
    // gap is exactly what use_build_context_synchronously exists to catch.
    final service = context.read<EventService>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _submitting = true);
    try {
      String? imageUrl = _existingImageUrl;
      if (_pickedImageBytes != null && _pickedImageExtension != null) {
        imageUrl = await service.uploadCoverImage(
          bytes: _pickedImageBytes!,
          fileExtension: _pickedImageExtension!,
        );
      }

      final charges = double.tryParse(_chargesController.text.trim()) ?? 0;
      final existing = widget.existingEvent;

      // The venue, capacity and tag fields are not on this form yet, so they
      // are carried straight over from the stored row - a draft writes every
      // column, and rebuilding one from the form alone would blank them.
      final draft = EventDraft(
        name: _nameController.text,
        description: _descriptionController.text,
        charges: charges,
        category: _category,
        eventDate: _eventDate,
        endDate: _endDate,
        imageUrl: imageUrl,
        venueName: existing?.venueName,
        venueAddress: existing?.venueAddress,
        latitude: existing?.latitude,
        longitude: existing?.longitude,
        organizerName: existing?.organizerName,
        organizerPhone: existing?.organizerPhone,
        organizerEmail: existing?.organizerEmail,
        capacity: existing?.capacity,
        tags: existing?.tags ?? const [],
        isPublished: existing?.isPublished ?? true,
      );

      if (existing != null) {
        await service.updateEvent(existing.id, draft);
      } else {
        await service.createEvent(draft, createdBy: widget.createdBy);
      }
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save the event: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Event' : 'New Event')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.hitRed.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _buildImagePreview(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(
                      _pickedImageBytes == null && _existingImageUrl == null
                          ? 'Add cover image'
                          : 'Change cover image',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Event name'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 4,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Description is required'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _chargesController,
                  decoration: const InputDecoration(
                    labelText: 'Charges (PKR, 0 = free)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Charges is required';
                    }
                    if (double.tryParse(v.trim()) == null) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<EventCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: EventCategory.values
                      .map(
                        (c) => DropdownMenuItem(value: c, child: Text(c.label)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _category = value);
                  },
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Starts'),
                  subtitle: Text(Formatters.mediumDateTime.format(_eventDate)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () => _pickDateTime(isStart: true),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ends'),
                  subtitle: Text(Formatters.mediumDateTime.format(_endDate)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () => _pickDateTime(isStart: false),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Text(_isEditing ? 'Save Changes' : 'Publish Event'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_pickedImageBytes != null) {
      return Image.memory(_pickedImageBytes!, fit: BoxFit.cover);
    }
    if (_existingImageUrl != null) {
      return CachedNetworkImage(
        imageUrl: _existingImageUrl!,
        fit: BoxFit.cover,
      );
    }
    return const Center(
      child: Icon(
        Icons.add_photo_alternate_outlined,
        size: 40,
        color: AppColors.hitRed,
      ),
    );
  }
}
